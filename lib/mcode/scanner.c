/*
 * x64 structural scanner for AutoHotkey.exe.
 *
 * This is compiled with clang into a freestanding, position-independent
 * machine code blob that is embedded into ahk_mcode.ahk.  It receives the
 * base address of a loaded AutoHotkey module plus a caller-provided output
 * buffer, locates the g_BIF / sMdFunc / g_BIV_A tables by their known
 * entries ("Abs", "BlockInput", "AhkPath"/"YYYY"), and copies entry metadata
 * into the buffer.
 *
 * The function must not call into the CRT or reference global/static data;
 * every constant used by the scan is encoded as an immediate.
 */

typedef unsigned long long u64;
typedef unsigned int u32;
typedef unsigned short u16;
typedef unsigned char u8;

#define IMAGE_DOS_SIGNATURE 0x5A4D
#define IMAGE_NT_SIGNATURE 0x00004550
#define IMAGE_NT_OPTIONAL_HDR64_MAGIC 0x20B

#define KIND_BIF 0
#define KIND_MDFUNC 1
#define KIND_BIV 2

typedef struct {
    u64 start;
    u64 end;
    u8 is_text;
    u8 is_rdata;
    u8 is_data;
    u8 name[8];
} SecRange;

typedef struct {
    u64 name_ptr;
    u64 fn_ptr;
    u32 min_params;
    u32 max_params;
    u32 fid;
    u32 pad;
} BifEntry;

typedef struct {
    u64 name_ptr;
    u64 fn_ptr;
    u8 ret_type;
    u8 arg_types[23];
} MdFuncEntry;

typedef struct {
    u64 name_ptr;
    u64 getter;
    u64 setter;
} BivEntry;

typedef struct {
    u64 bif_ptr, bif_count, bif_stride;
    u64 mdfunc_ptr, mdfunc_count, mdfunc_stride;
    u64 biv_ptr, biv_count, biv_stride;
    u64 reserved;
    BifEntry bif_entries[512];
    MdFuncEntry mdfunc_entries[512];
    BivEntry biv_entries[256];
} ScanOut;

static u8 lower(u8 c)
{
    return (c >= 'A' && c <= 'Z') ? (u8)(c + 32) : c;
}

static u8 in_range(u64 p, u64 lo, u64 hi)
{
    return p >= lo && p < hi;
}

static u8 ptr_in_text(u64 p, SecRange *secs, int n)
{
    int i;
    for (i = 0; i < n; ++i)
        if (secs[i].is_text && in_range(p, secs[i].start, secs[i].end))
            return 1;
    return 0;
}

/* Upper bound (in u16 units) of a string starting at p: the section end
 * caps every read so a name near the end of a section can never run into
 * the next mapping.  Returns 0 when p lies in no data section. */
static u64 str_limit(u64 p, SecRange *secs, int n)
{
    int i;
    for (i = 0; i < n; ++i)
        if ((secs[i].is_rdata || secs[i].is_data)
            && in_range(p, secs[i].start, secs[i].end))
            return (secs[i].end - p) / 2;
    return 0;
}

static u8 str_valid(u64 p, SecRange *secs, int n)
{
    u64 i;
    u64 limit = str_limit(p, secs, n);
    if (limit == 0)
        return 0;
    if (limit > 64)
        limit = 64;
    for (i = 0; i < limit; ++i)
    {
        u16 ch = *(u16 *)(p + 2 * i);
        if (ch == 0)
            return 1;
        if (ch < 32 || ch > 126)
            return 0;
    }
    return 0;
}

static u8 entry_valid(u64 p, SecRange *secs, int n, int kind)
{
    u64 name_ptr = *(u64 *)p;
    u64 fn_ptr = *(u64 *)(p + 8);
    if (!str_valid(name_ptr, secs, n))
        return 0;
    return ptr_in_text(fn_ptr, secs, n) ? 1 : 0;
}

static u8 is_abs(u64 p)
{
    return *(u16 *)p == 'A' && *(u16 *)(p + 2) == 'b'
        && *(u16 *)(p + 4) == 's' && *(u16 *)(p + 6) == 0;
}

static u8 is_blockinput(u64 p)
{
    return *(u16 *)p == 'B' && *(u16 *)(p + 2) == 'l'
        && *(u16 *)(p + 4) == 'o' && *(u16 *)(p + 6) == 'c'
        && *(u16 *)(p + 8) == 'k' && *(u16 *)(p + 10) == 'I'
        && *(u16 *)(p + 12) == 'n' && *(u16 *)(p + 14) == 'p'
        && *(u16 *)(p + 16) == 'u' && *(u16 *)(p + 18) == 't'
        && *(u16 *)(p + 20) == 0;
}

static u8 is_ahkpath(u64 p)
{
    return *(u16 *)p == 'A' && *(u16 *)(p + 2) == 'h'
        && *(u16 *)(p + 4) == 'k' && *(u16 *)(p + 6) == 'P'
        && *(u16 *)(p + 8) == 'a' && *(u16 *)(p + 10) == 't'
        && *(u16 *)(p + 12) == 'h' && *(u16 *)(p + 14) == 0;
}

static u8 is_yyyy(u64 p)
{
    return *(u16 *)p == 'Y' && *(u16 *)(p + 2) == 'Y'
        && *(u16 *)(p + 4) == 'Y' && *(u16 *)(p + 6) == 'Y'
        && *(u16 *)(p + 8) == 0;
}

static u8 name_eq(u8 *np, const char *s, int len)
{
    int k;
    for (k = 0; k < len; ++k)
        if (np[k] != (u8)s[k])
            return 0;
    return 1;
}

static u8 is_rsrc_name(u8 *np)
{
    return name_eq(np, ".rsrc", 5);
}

static u8 name_le(u64 a, u64 b, SecRange *secs, int n)
{
    u64 i;
    u64 la = str_limit(a, secs, n);
    u64 lb = str_limit(b, secs, n);
    u64 limit = 64;
    if (la && la < limit)
        limit = la;
    if (lb && lb < limit)
        limit = lb;
    if (limit == 0)
        return 0; /* unreadable name; reject the record */
    for (i = 0; i < limit; ++i)
    {
        u16 ca = *(u16 *)(a + 2 * i);
        u16 cb = *(u16 *)(b + 2 * i);
        u8 lca = lower((u8)ca);
        u8 lcb = lower((u8)cb);
        if (ca == 0 || cb == 0)
            return ca <= cb;
        if (lca != lcb)
            return lca < lcb;
    }
    return 1;
}

static u64 count_run(u64 start, u64 section_end, SecRange *secs, int n,
                     int kind, u64 stride)
{
    u64 count = 1;
    u64 prev = start;
    u64 q = start + stride;
    while (q + 16 <= section_end)
    {
        u64 prev_name;
        u64 curr_name;
        if (!entry_valid(q, secs, n, kind))
            break;
        prev_name = *(u64 *)prev;
        curr_name = *(u64 *)q;
        if (kind == KIND_BIV)
        {
            if (is_yyyy(curr_name))
            {
                ++count;
                break;
            }
        }
        else if (!name_le(prev_name, curr_name, secs, n))
            break;
        ++count;
        prev = q;
        q += stride;
    }
    return count;
}

static u8 is_anchor_name(u64 name_ptr, int kind)
{
    if (kind == KIND_BIF)
        return is_abs(name_ptr);
    if (kind == KIND_MDFUNC)
        return is_blockinput(name_ptr);
    return is_ahkpath(name_ptr);
}

static u64 find_anchor_slot(SecRange *secs, int n, int kind, u64 stride,
                            u64 *best_count)
{
    u64 best_slot = 0;
    u64 best_run = 0;
    int s;
    for (s = 0; s < n; ++s)
    {
        u64 p;
        if (!secs[s].is_rdata && !secs[s].is_data)
            continue;
        for (p = secs[s].start; p + 16 <= secs[s].end; p += 8)
        {
            u64 name_ptr;
            u64 run;
            if (!entry_valid(p, secs, n, kind))
                continue;
            name_ptr = *(u64 *)p;
            if (!is_anchor_name(name_ptr, kind))
                continue;
            run = count_run(p, secs[s].end, secs, n, kind, stride);
            if (run > best_run)
            {
                best_run = run;
                best_slot = p;
            }
        }
    }
    *best_count = best_run;
    return best_slot;
}

static int scan_one(u64 base, SecRange *secs, int n, int kind, u64 stride,
                    u64 *table_ptr, u64 *table_count)
{
    u64 slot;
    u64 count;
    slot = find_anchor_slot(secs, n, kind, stride, &count);
    if (!slot || count < 10)
        return 0;
    *table_ptr = slot;
    *table_count = count;
    return 1;
}

int AhkScanTables(u64 base, ScanOut *out)
{
    u16 dos_magic;
    u32 pe_offset;
    u32 nt_signature;
    u16 opt_magic;
    u16 num_sections;
    u16 opt_size;
    u64 section_table;
    SecRange secs[16];
    int n = 0;
    int i;
    u8 has_text = 0;
    u8 has_data = 0;
    u8 strict;
    u64 image_size;
    u64 image_end;

    if (base == 0 || out == 0)
        return 1;
    dos_magic = *(u16 *)base;
    if (dos_magic != IMAGE_DOS_SIGNATURE)
        return 1;
    pe_offset = *(u32 *)(base + 0x3C);
    nt_signature = *(u32 *)(base + pe_offset);
    if (nt_signature != IMAGE_NT_SIGNATURE)
        return 1;
    opt_magic = *(u16 *)(base + pe_offset + 24);
    if (opt_magic != IMAGE_NT_OPTIONAL_HDR64_MAGIC)
        return 1;
    num_sections = *(u16 *)(base + pe_offset + 6);
    opt_size = *(u16 *)(base + pe_offset + 20);
    if (num_sections > 16)
        num_sections = 16;
    section_table = base + pe_offset + 24 + opt_size;
    image_size = *(u32 *)(base + pe_offset + 24 + 56); /* SizeOfImage */
    image_end = image_size ? base + image_size : 0;

    for (i = 0; i < num_sections; ++i)
    {
        u64 hdr = section_table + (u64)i * 40;
        u64 name = hdr;
        u32 vsize = *(u32 *)(hdr + 8);
        u32 va = *(u32 *)(hdr + 12);
        u32 raw_size = *(u32 *)(hdr + 16);
        u8 *np = (u8 *)name;
        int k;
        u64 size = vsize ? vsize : raw_size;
        secs[n].start = base + va;
        secs[n].end = secs[n].start + size;
        /* A corrupt or adversarial header must never extend a section past
         * the mapped image: every scan below walks [start, end). */
        if (image_end && secs[n].end > image_end)
            secs[n].end = image_end;
        for (k = 0; k < 8; ++k)
            secs[n].name[k] = np[k];
        if (name_eq(np, ".text", 5))
            has_text = 1;
        if (name_eq(np, ".rdata", 6) || name_eq(np, ".data", 5))
            has_data = 1;
        ++n;
    }

    // Normal builds expose .text/.rdata/.data by name. Packed executables
    // (UPX, MPRESS) rename them (UPX0/UPX1, .MPRESS1/...), so fall back to
    // scanning every non-resource section and rely on anchor+run validation.
    strict = has_text && has_data;
    for (i = 0; i < n; ++i)
    {
        u8 *np = secs[i].name;
        u8 non_rsrc = !is_rsrc_name(np);
        if (strict)
        {
            secs[i].is_text = name_eq(np, ".text", 5);
            secs[i].is_rdata = name_eq(np, ".rdata", 6);
            secs[i].is_data = name_eq(np, ".data", 5);
        }
        else
        {
            secs[i].is_text = non_rsrc;
            secs[i].is_rdata = non_rsrc;
            secs[i].is_data = non_rsrc;
        }
    }

    if (!scan_one(base, secs, n, KIND_BIF, 0x20, &out->bif_ptr,
                  &out->bif_count))
        return 1;
    if (!scan_one(base, secs, n, KIND_MDFUNC, 0x28, &out->mdfunc_ptr,
                  &out->mdfunc_count))
        return 1;
    if (!scan_one(base, secs, n, KIND_BIV, 0x18, &out->biv_ptr,
                  &out->biv_count))
        return 1;

    out->bif_stride = 0x20;
    out->mdfunc_stride = 0x28;
    out->biv_stride = 0x18;
    out->reserved = 0;

    for (i = 0; i < (int)out->bif_count && i < 512; ++i)
    {
        u64 p = out->bif_ptr + (u64)i * 0x20;
        BifEntry *e = &out->bif_entries[i];
        e->name_ptr = *(u64 *)p;
        e->fn_ptr = *(u64 *)(p + 8);
        e->min_params = *(u8 *)(p + 16);
        e->max_params = *(u8 *)(p + 17);
        e->fid = *(u8 *)(p + 18);
        e->pad = 0;
    }
    for (i = 0; i < (int)out->mdfunc_count && i < 512; ++i)
    {
        u64 p = out->mdfunc_ptr + (u64)i * 0x28;
        MdFuncEntry *e = &out->mdfunc_entries[i];
        int j;
        e->name_ptr = *(u64 *)p;
        e->fn_ptr = *(u64 *)(p + 8);
        e->ret_type = *(u8 *)(p + 16);
        for (j = 0; j < 23; ++j)
            e->arg_types[j] = *(u8 *)(p + 17 + j);
    }
    for (i = 0; i < (int)out->biv_count && i < 256; ++i)
    {
        u64 p = out->biv_ptr + (u64)i * 0x18;
        BivEntry *e = &out->biv_entries[i];
        e->name_ptr = *(u64 *)p;
        e->getter = *(u64 *)(p + 8);
        e->setter = *(u64 *)(p + 16);
    }
    return 0;
}
