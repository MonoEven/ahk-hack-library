/*
 * internal_locator.c - runtime locator for EvalNative internals.
 *
 * Scans the running AutoHotkey image for the interpreter functions that
 * EvalNative needs, without a per-version RVA table:
 *
 *   g_script            most frequent `lea rcx, [rip+disp]` in ExpressionToPostfix
 *   FindOrAddVar        call target after a `lea rcx, g_script` whose prologue
 *                       contains `cmpw $0, (%rdx)`
 *   FinalizeExpression  function between ExpressionToPostfix and ExpandExpression
 *                       with the standard ArgStruct prologue
 *   CRT free            next call after the direct caller of ExpressionToPostfix
 *   SYM_INVALID         postfix terminator immediate in ExpandExpression
 */

typedef unsigned long long u64;
typedef long long i64;
typedef unsigned int u32;
typedef unsigned short u16;
typedef unsigned char u8;
typedef int i32;

#define OUT_GSCRIPT 0
#define OUT_FINALIZE 8
#define OUT_FINDVAR 16
#define OUT_CRTFREE 24
#define OUT_SYMINVALID 32

static u32 rd32(u8 *p)
{
    return (u32)p[0] | ((u32)p[1] << 8)
        | ((u32)p[2] << 16) | ((u32)p[3] << 24);
}

static i32 rds32(u8 *p)
{
    return (i32)rd32(p);
}

static int find_gscript(u8 *p, u64 start, u64 end, u64 base, u64 *out)
{
    u64 targets[64];
    u32 counts[64];
    u32 n = 0;
    u64 best = 0;
    u32 best_count = 0;
    u64 i;

    for (i = start; i + 7 <= end; ++i)
    {
        if (p[i] != 0x48 || p[i + 1] != 0x8D || p[i + 2] != 0x0D)
            continue;
        {
            i32 disp = rds32(p + i + 3);
            u64 target = (u64)(p + i + 7) + (i64)disp;
            u32 j;
            if (target < base + 0x10000)
                continue;
            for (j = 0; j < n; ++j)
                if (targets[j] == target)
                    break;
            if (j == n && n < 64)
            {
                targets[n] = target;
                counts[n] = 0;
                ++n;
            }
            if (j < n)
                ++counts[j];
        }
    }
    for (i = 0; i < n; ++i)
        if (counts[i] > best_count)
        {
            best = targets[i];
            best_count = counts[i];
        }
    *out = best;
    return best != 0;
}

static int target_has_cmp_null_name(u8 *p, u64 size, u64 target_off)
{
    u64 i;
    if (target_off + 0x100 > size)
        return 0;
    for (i = 0; i + 4 <= 0x100; ++i)
        if (p[target_off + i] == 0x66
            && p[target_off + i + 1] == 0x83
            && p[target_off + i + 2] == 0x3A
            && p[target_off + i + 3] == 0x00)
            return 1;
    return 0;
}

static int find_find_or_add_var(u8 *p, u64 size, u64 start, u64 end,
                                u64 gscript, u64 *out)
{
    u64 i;
    for (i = start; i + 7 <= end; ++i)
    {
        if (p[i] != 0x48 || p[i + 1] != 0x8D || p[i + 2] != 0x0D)
            continue;
        {
            i32 disp = rds32(p + i + 3);
            if ((u64)(p + i + 7) + (i64)disp != gscript)
                continue;
            {
                u64 j;
                for (j = i + 7; j + 5 <= end && j < i + 23; ++j)
                {
                    if (p[j] != 0xE8)
                        continue;
                    {
                        i32 d2 = rds32(p + j + 1);
                        u64 target = (u64)(p + j + 5) + (i64)d2;
                        if (target_has_cmp_null_name(p, size, target - (u64)p))
                        {
                            *out = target;
                            return 1;
                        }
                    }
                }
            }
        }
    }
    return 0;
}

static int find_finalize(u8 *p, u64 size, u64 start, u64 end, u64 *out)
{
    static const u8 prologue[] = {
        0x48, 0x89, 0x54, 0x24, 0x10,
        0x55, 0x56, 0x57, 0x41, 0x54,
        0x41, 0x55, 0x41, 0x56, 0x41, 0x57
    };
    u64 i;
    for (i = start; i + sizeof(prologue) <= end; ++i)
    {
        u64 j;
        for (j = 0; j < sizeof(prologue); ++j)
            if (p[i + j] != prologue[j])
                break;
        if (j == sizeof(prologue)
            && i >= 2 && p[i - 1] == 0xCC && p[i - 2] == 0xCC)
        {
            *out = (u64)(p + i);
            return 1;
        }
    }
    return 0;
}

static int find_crt_free(u8 *p, u64 size, u64 expr_off, u64 *out)
{
    u64 i;
    for (i = 0; i + 5 <= size; ++i)
    {
        if (p[i] != 0xE8)
            continue;
        {
            i32 disp = rds32(p + i + 1);
            u64 target = (u64)(p + i + 5) + (i64)disp;
            if (target - (u64)p != expr_off)
                continue;
            {
                u64 j;
                for (j = i + 5; j + 5 <= size && j < i + 101; ++j)
                {
                    if (p[j] != 0xE8)
                        continue;
                    {
                        i32 d2 = rds32(p + j + 1);
                        u64 t2 = (u64)(p + j + 5) + (i64)d2;
                        if (t2 != target)
                        {
                            *out = t2;
                            return 1;
                        }
                    }
                }
            }
        }
    }
    return 0;
}

static int find_sym_invalid(u8 *p, u64 size, u64 expand_off, u32 *out)
{
    u64 end = expand_off + 0x800;
    u64 i;
    if (end > size)
        end = size;
    for (i = expand_off; i + 4 <= end; ++i)
    {
        if (p[i] != 0x83)
            continue;
        if (p[i + 2] != 0x10)
            continue;
        if (p[i + 3] >= 50 && p[i + 3] <= 100)
        {
            *out = p[i + 3];
            return 1;
        }
    }
    return 0;
}

int AhkLocateInternal(u64 base, u64 text_rva, u64 text_size,
                      u64 expr_rva, u64 expand_rva, u64 out)
{
    u8 *p;
    u64 size;
    u64 expr_off;
    u64 expand_off;
    u64 gscript = 0;
    u64 findvar = 0;
    u64 finalize = 0;
    u64 crtfree = 0;
    u32 sym_invalid = 0;

    if (!base || !text_rva || !text_size || !out)
        return 1;
    if (expr_rva < text_rva || expand_rva < text_rva)
        return 2;
    p = (u8 *)(base + text_rva);
    size = text_size;
    expr_off = expr_rva - text_rva;
    expand_off = expand_rva - text_rva;
    if (expr_off + 0x20000 > size)
        return 3;

    if (!find_gscript(p, expr_off, expr_off + 0x20000, base, &gscript))
        return 4;
    if (!find_find_or_add_var(p, size, expr_off, expr_off + 0x20000,
                              gscript, &findvar))
        return 5;
    if (expand_off > expr_off + 0x20000)
        expand_off = expr_off + 0x20000;
    find_finalize(p, size, expr_off, expand_off, &finalize);
    if (!find_crt_free(p, size, expr_off, &crtfree))
        return 6;
    if (!find_sym_invalid(p, size, expand_off, &sym_invalid))
        return 7;

    *(u64 *)(out + OUT_GSCRIPT) = gscript;
    *(u64 *)(out + OUT_FINALIZE) = finalize;
    *(u64 *)(out + OUT_FINDVAR) = findvar;
    *(u64 *)(out + OUT_CRTFREE) = crtfree;
    *(u32 *)(out + OUT_SYMINVALID) = sym_invalid;
    return 0;
}
