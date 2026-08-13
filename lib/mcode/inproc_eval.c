/*
 * x64 in-process expression evaluator for AutoHotkey.
 *
 * Calls the interpreter's own pipeline on a temporary Line:
 *   Lightweight deref scan           -> marks identifiers for resolution
 *   Line::ExpressionToPostfix()      -> builds the postfix expression
 *   Line::FinalizeExpression()       -> validates calls/params (when separate)
 *   Script::FindOrAddVar()           -> resolves read variables/functions
 *   Line::ExpandExpression()         -> evaluates it
 *
 * No interpreter layout offset is hardcoded here.  The caller passes a
 * 21-slot u64 array (`layout`) with every Line/ArgStruct/ExprTokenType/
 * DerefType field offset and the token stride, discovered at runtime by the
 * AHK layer.  Before anything is written the token walk validates the
 * assumed layout (symbol sanity, bounded sentinel search, deref pointer
 * range); a mismatch returns an explicit error code instead of corrupting
 * memory.  Layout slot meaning:
 *
 *   0 LINE_TYPE   1 LINE_ARGC   2 LINE_NUM   3 LINE_ARG
 *   4 ARG_TYPE    5 ARG_ISEXPR  6 ARG_LEN    7 ARG_TEXT
 *   8 ARG_DEREF   9 ARG_POSTFIX 10 ARG_MAX_STACK 11 ARG_MAX_ALLOC
 *   12 TOKEN_VALUE 13 TOKEN_SYMBOL 14 TOKEN_STRIDE 15 TOKEN_USAGE
 *   16 DEREF_MARKER 17 DEREF_VALUE 18 DEREF_TYPE 19 DEREF_LEN 20 DEREF_SIZE
 */

typedef unsigned long long u64;
typedef long long i64;
typedef unsigned int u32;
typedef unsigned short u16;
typedef unsigned char u8;
typedef int i32;

#define LO_LINE_TYPE 0
#define LO_LINE_ARGC 1
#define LO_LINE_NUM 2
#define LO_LINE_ARG 3
#define LO_ARG_TYPE 4
#define LO_ARG_ISEXPR 5
#define LO_ARG_LEN 6
#define LO_ARG_TEXT 7
#define LO_ARG_DEREF 8
#define LO_ARG_POSTFIX 9
#define LO_ARG_MAX_STACK 10
#define LO_ARG_MAX_ALLOC 11
#define LO_TOKEN_VALUE 12
#define LO_TOKEN_SYMBOL 13
#define LO_TOKEN_STRIDE 14
#define LO_TOKEN_USAGE 15
#define LO_DEREF_MARKER 16
#define LO_DEREF_VALUE 17
#define LO_DEREF_TYPE 18
#define LO_DEREF_LEN 19
#define LO_DEREF_SIZE 20

#define DT_VAR 0
#define DT_QSTRING 3
#define DT_FUNCREF 7

#define VARREF_REF 3
#define FINDVAR_FOR_READ 0x103

#define FINAL_DEREF_ADDR 0x100800

#define ACT_BLOCK_BEGIN 3
#define ARG_TYPE_NORMAL 0
#define RESULT_OK 1
#define SYM_VAR 4

typedef int (*PostfixFn)(u64 line, u64 arg, u64 *infix);
typedef int (*FinalizeFn)(u64 line, u64 arg);
typedef u64 (*FindVarFn)(u64 script, u64 name, u64 len, u32 scope);
typedef u64 (*ExpandFn)(u64 line, i32 idx, i32 *result_out,
                        u64 result_token, u64 *target, u64 *deref_buf,
                        u64 *deref_size, u64 arg_deref, u64 extra_size);
typedef void (*FreeFn)(u64 ptr);

static int is_ident_start(u16 c)
{
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
        || c == '_' || c >= 0x80;
}

static int is_ident_char(u16 c)
{
    return is_ident_start(c) || (c >= '0' && c <= '9');
}

int AhkEvalInProcess(u64 postfix_fn, u64 expand_fn, u64 curr_line_slot,
                     u64 scratch, u64 expr_ptr, u64 out, u64 stage,
                     u64 line_override, u64 arg_override,
                     u64 g_script, u64 finalize_fn,
                     u64 find_var_fn, u64 free_fn, u64 sym_invalid,
                     u64 *layout)
{
    u64 line;
    u64 arg;
    u64 result_token;
    u64 deref;
    u64 target;
    u64 deref_size = 0x400000; /* 4 MiB, <= LARGE_DEREF_BUF_SIZE */
    u64 infix = 0;
    u64 saved_line;
    u64 final_deref;
    u64 token;
    u64 deref_ptr;
    u64 var;
    u32 deref_count;
    u64 len = 0;
    u16 *cp16;
    u8 *cursor;
    i32 status;
    i32 expand_status;
    u64 string_result;
    i32 i;
    u64 token_count;
    u64 stride;
    u64 sym_off;
    u64 val_off;
    u64 usage_off;
    u64 dmarker;
    u64 dvalue;
    u64 dtype;
    u64 dlen;
    u64 dsize;
    u64 copy_len;

    if (!postfix_fn || !expand_fn || !curr_line_slot
        || !scratch || !expr_ptr || !out
        || !g_script || !find_var_fn || !free_fn || !layout)
        return 1;

    stride = layout[LO_TOKEN_STRIDE];
    sym_off = layout[LO_TOKEN_SYMBOL];
    val_off = layout[LO_TOKEN_VALUE];
    usage_off = layout[LO_TOKEN_USAGE];
    dmarker = layout[LO_DEREF_MARKER];
    dvalue = layout[LO_DEREF_VALUE];
    dtype = layout[LO_DEREF_TYPE];
    dlen = layout[LO_DEREF_LEN];
    dsize = layout[LO_DEREF_SIZE];

    /* Layout sanity before any use: the write path is guarded, so a bad
     * layout fails loudly here instead of corrupting memory. */
    if (stride < 16 || sym_off + 4 > stride || val_off + 8 > stride
        || usage_off + 8 > stride || dsize < 16 || dsize > 64
        || dtype + 1 > dsize || dlen + 4 > dsize)
        return 10;

    line = line_override ? line_override : scratch;
    arg = arg_override ? arg_override : scratch + 0x100;
    result_token = scratch + 0x180;
    deref = scratch + 0x300;
    final_deref = scratch + FINAL_DEREF_ADDR;

    if (!line_override)
    {
        for (i = 0; i < 0x100; ++i)
            ((u8 *)line)[i] = 0;
        /* Any non-expression action works: ExpandExpression only discards
         * the result for ACT_EXPRESSION and has special boolean handling
         * for ACT_IF/ACT_WHILE/ACT_UNTIL. */
        *(u8 *)(line + layout[LO_LINE_TYPE]) = ACT_BLOCK_BEGIN;
        *(u8 *)(line + layout[LO_LINE_ARGC]) = 1;
        if (layout[LO_LINE_NUM])
            *(u32 *)(line + layout[LO_LINE_NUM]) = 1;
        *(u64 *)(line + layout[LO_LINE_ARG]) = arg;
    }
    for (i = 0; i < 0x80; ++i)
        ((u8 *)result_token)[i] = 0;

    cursor = (u8 *)expr_ptr;
    while (*(u16 *)cursor)
    {
        cursor += 2;
        ++len;
    }

    if (!arg_override)
    {
        for (i = 0; i < 0x80; ++i)
            ((u8 *)arg)[i] = 0;
        *(u8 *)(arg + layout[LO_ARG_TYPE]) = ARG_TYPE_NORMAL;
        *(u8 *)(arg + layout[LO_ARG_ISEXPR]) = 1;
        *(u32 *)(arg + layout[LO_ARG_LEN]) = (u32)len;
        *(u64 *)(arg + layout[LO_ARG_TEXT]) = expr_ptr;
        *(u32 *)(arg + layout[LO_ARG_MAX_STACK]) = 256;
        *(u32 *)(arg + layout[LO_ARG_MAX_ALLOC]) = 256;
    }

    if (!arg_override)
    {
        /* Lightweight deref scan: mark identifiers and quoted strings so the
         * interpreter can resolve variables/function names and tokenize string
         * literals.  Literals and operators are handled by
         * ExpressionToPostfix's raw-text parser. */
        deref_count = 0;
        cp16 = (u16 *)expr_ptr;
        while (*cp16)
        {
            if (*cp16 == '"' || *cp16 == '\'')
            {
                u16 quote = *cp16++;
                u16 *start = cp16;
                while (*cp16 && *cp16 != quote)
                {
                    if (*cp16 == '`' && cp16[1])
                        ++cp16;
                    ++cp16;
                }
                if (!*cp16)
                    break; /* unterminated string; let ExpressionToPostfix report it */
                if (deref_count < 255)
                {
                    u64 e = final_deref + deref_count * dsize;
                    *(u64 *)(e + dmarker) = (u64)start;
                    *(u8 *)(e + dvalue) = 1; /* terminal */
                    *(u8 *)(e + dtype) = DT_QSTRING;
                    *(u8 *)(e + dtype + 1) = 1; /* substring_count */
                    *(u32 *)(e + dlen) = (u32)(cp16 - start);
                    ++deref_count;
                }
                ++cp16; /* skip closing quote */
                continue;
            }
            if (is_ident_start(*cp16))
            {
                u16 *start = cp16;
                while (is_ident_char(*cp16))
                    ++cp16;
                /* Identifiers after '.' are member names handled directly by
                 * ExpressionToPostfix; marking them as variables breaks
                 * obj.method() / obj.prop expressions. */
                if ((start == (u16 *)expr_ptr || start[-1] != '.')
                    && deref_count < 255)
                {
                    u64 e = final_deref + deref_count * dsize;
                    *(u64 *)(e + dmarker) = (u64)start;
                    *(u64 *)(e + dvalue) = 0;
                    *(u8 *)(e + dtype) = DT_VAR;
                    *(u8 *)(e + dtype + 1) = 0;
                    *(u32 *)(e + dlen) = (u32)(cp16 - start);
                    ++deref_count;
                }
                continue;
            }
            ++cp16;
        }
        if (deref_count)
        {
            *(u64 *)(final_deref + deref_count * dsize) = 0;
            *(u64 *)(arg + layout[LO_ARG_DEREF]) = final_deref;
        }
    }

    *(u32 *)(out + 0) = 1; /* status: fail until proven otherwise */
    *(u32 *)(out + 4) = 0;
    *(i64 *)(out + 8) = 0;
    *(u64 *)(out + 16) = 0;

    saved_line = *(u64 *)curr_line_slot;
    *(u64 *)curr_line_slot = line;

    status = ((PostfixFn)postfix_fn)(line, arg, &infix);
    if (infix)
        ((FreeFn)free_fn)(infix);
    if (status != RESULT_OK)
    {
        *(u64 *)curr_line_slot = saved_line;
        *(u32 *)(out + 0) = 2; /* postfix failed */
        return 0;
    }
    if (stage == 0)
    {
        *(u64 *)curr_line_slot = saved_line;
        *(u32 *)(out + 0) = 0; /* success */
        *(u32 *)(out + 4) = 99; /* postfix-only marker */
        return 0;
    }

    /* Resolve read variable/function references before FinalizeExpression,
     * which needs Var* pointers when validating function calls.  The loop
     * is bounded and layout-validated: a missing sentinel, a wrong token
     * stride, or a symbol that cannot be a real token stop with an error
     * code before anything is written. */
    token = *(u64 *)(arg + layout[LO_ARG_POSTFIX]);
    if (!token)
    {
        *(u64 *)curr_line_slot = saved_line;
        *(u32 *)(out + 0) = 8; /* no postfix buffer */
        return 0;
    }
    token_count = 0;
    while (*(u32 *)(token + sym_off) != (u32)sym_invalid)
    {
        u32 sym = *(u32 *)(token + sym_off);
        if (++token_count > 65536)
        {
            *(u64 *)curr_line_slot = saved_line;
            *(u32 *)(out + 0) = 7; /* token chain too long */
            return 0;
        }
        if (sym > 0x1000)
        {
            /* Not a plausible interpreter symbol: the assumed token layout
             * does not match this runtime. */
            *(u64 *)curr_line_slot = saved_line;
            *(u32 *)(out + 0) = 9; /* token layout mismatch */
            return 0;
        }
        if (sym == SYM_VAR)
        {
            if (*(u32 *)(token + usage_off) < VARREF_REF)
            {
                deref_ptr = *(u64 *)(token + val_off);
                if (deref_ptr)
                {
                    if (deref_ptr <= 0x10000 || deref_ptr >= 0x7fffffffffff)
                    {
                        *(u64 *)curr_line_slot = saved_line;
                        *(u32 *)(out + 0) = 9; /* deref pointer invalid */
                        return 0;
                    }
                    if (*(u8 *)(deref_ptr + dtype) == DT_FUNCREF)
                    {
                        *(u64 *)(token + val_off)
                            = *(u64 *)(deref_ptr + dvalue);
                        token += stride;
                        continue;
                    }
                    var = ((FindVarFn)find_var_fn)(
                        g_script,
                        *(u64 *)(deref_ptr + dmarker),
                        *(u32 *)(deref_ptr + dlen),
                        FINDVAR_FOR_READ);
                    if (!var)
                    {
                        *(u64 *)curr_line_slot = saved_line;
                        *(u32 *)(out + 0) = 5; /* variable resolution failed */
                        return 0;
                    }
                    *(u64 *)(token + val_off) = var;
                }
            }
        }
        token += stride;
    }

    if (finalize_fn && finalize_fn != postfix_fn)
    {
        status = ((FinalizeFn)finalize_fn)(line, arg);
        if (status != RESULT_OK)
        {
            *(u64 *)curr_line_slot = saved_line;
            *(u32 *)(out + 0) = 6; /* finalize failed */
            return 0;
        }
    }

    target = deref;

    /* Initialize ResultToken the way ExpandSingleArg does before the call.
     * ResultToken = ExprTokenType + result + buf + memToFree: the token
     * fields use the discovered token offsets, and buf/memToFree sit
     * immediately after the token (token_stride and token_stride + 8). */
    *(u32 *)(result_token + sym_off) = 0xFFFFFFFF;
    *(u64 *)(result_token + usage_off) = ~0ull; /* marker_length = -1 */
    *(u64 *)(result_token + stride) = deref;    /* buf */
    *(u64 *)(result_token + stride + 8) = 0;    /* mem_to_free */

    string_result = ((ExpandFn)expand_fn)(
        line, 0, &expand_status, result_token, &target, &deref, &deref_size,
        deref + 0x3F0000, 0x3F0000);
    *(u64 *)curr_line_slot = saved_line;
    if (!string_result)
    {
        *(u32 *)(out + 0) = 3; /* expand failed */
        return 0;
    }

    *(u32 *)(out + 0) = 0; /* success */
    *(u32 *)(out + 4) = *(u32 *)(result_token + sym_off);
    *(i64 *)(out + 8) = *(i64 *)(result_token + val_off);
    *(u64 *)(out + 16) = *(u64 *)(result_token + val_off);
    for (i = 0; i < 48; ++i)
        ((u8 *)(out + 32))[i] = ((u8 *)result_token)[i];
    if (*(u32 *)(out + 4) != 0 && *(u32 *)(out + 4) != 1
        && *(u32 *)(out + 4) != 2 && *(u32 *)(out + 4) != 5)
    {
        /* Fallback used by ExpandSingleArg: token was not set, so the
         * returned string is the result. */
        *(u32 *)(out + 4) = 0;
        *(u64 *)(out + 16) = string_result;
    }
    *(u64 *)(out + 80) = *(u64 *)(arg + layout[LO_ARG_POSTFIX]);
    if (*(u64 *)(arg + layout[LO_ARG_POSTFIX]))
    {
        /* Debug copy of the postfix bytes: copy only the tokens that were
         * actually visited (plus the sentinel), never a fixed size, which
         * would read past the end of a short expression's buffer. */
        copy_len = (token_count + 1) * stride;
        if (copy_len > 288)
            copy_len = 288;
        for (i = 0; i < (i32)copy_len; ++i)
            ((u8 *)(out + 88))[i] = ((u8 *)(*(u64 *)(arg + layout[LO_ARG_POSTFIX])))[i];
    }
    *(u32 *)(out + 200) = (u32)expand_status;
    return 0;
}
