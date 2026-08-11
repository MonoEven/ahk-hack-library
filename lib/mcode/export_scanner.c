/*
 * x64 PE export-table scanner for arbitrary DLL/EXE modules.
 *
 * Same build discipline as mcode/scanner.c: freestanding, no CRT, no
 * globals.  Given a loaded module base it parses the PE export directory
 * and copies named exports (name pointer, function RVA, ordinal) into a
 * caller-provided buffer.
 */

typedef unsigned long long u64;
typedef unsigned int u32;
typedef unsigned short u16;
typedef unsigned char u8;

#define IMAGE_DOS_SIGNATURE 0x5A4D
#define IMAGE_NT_SIGNATURE 0x00004550
#define IMAGE_NT_OPTIONAL_HDR64_MAGIC 0x20B

typedef struct {
    u64 name_ptr;
    u64 fn_rva;
    u32 ordinal;
    u32 pad;
} ExportEntry;

typedef struct {
    u64 dir_ptr;
    u64 count;
    u64 reserved;
    ExportEntry entries[4096];
} ExportScanOut;

int AhkScanExports(u64 base, ExportScanOut *out)
{
    u32 pe_offset;
    u32 nt_signature;
    u16 opt_magic;
    u64 opt;
    u32 export_rva;
    u32 export_size;
    u64 ed;
    u32 num_names;
    u32 name_vas;
    u32 ordinal_vas;
    u32 func_vas;
    u32 base_ordinal;
    u64 n = 0;
    u32 i;

    if (base == 0 || out == 0)
        return 1;
    if (*(u16 *)base != IMAGE_DOS_SIGNATURE)
        return 1;
    pe_offset = *(u32 *)(base + 0x3C);
    nt_signature = *(u32 *)(base + pe_offset);
    if (nt_signature != IMAGE_NT_SIGNATURE)
        return 1;
    opt_magic = *(u16 *)(base + pe_offset + 24);
    if (opt_magic != IMAGE_NT_OPTIONAL_HDR64_MAGIC)
        return 1;

    opt = base + pe_offset + 24;
    export_rva = *(u32 *)(opt + 112);   /* DataDirectory[0].VirtualAddress */
    export_size = *(u32 *)(opt + 116);  /* DataDirectory[0].Size */
    if (export_rva == 0 || export_size == 0)
    {
        out->dir_ptr = 0;
        out->count = 0;
        out->reserved = 0;
        return 0;
    }

    ed = base + export_rva;
    num_names = *(u32 *)(ed + 24);          /* NumberOfNames */
    name_vas = *(u32 *)(ed + 32);           /* AddressOfNames */
    ordinal_vas = *(u32 *)(ed + 36);        /* AddressOfNameOrdinals */
    func_vas = *(u32 *)(ed + 28);           /* AddressOfFunctions */
    base_ordinal = *(u32 *)(ed + 16);       /* Base */
    if (num_names > 4096)
        num_names = 4096;

    out->dir_ptr = ed;
    out->reserved = 0;
    for (i = 0; i < num_names; ++i)
    {
        u32 name_rva = *(u32 *)(base + name_vas + 4 * i);
        u16 ord_index = *(u16 *)(base + ordinal_vas + 2 * i);
        u32 fn_rva = *(u32 *)(base + func_vas + 4 * ord_index);
        ExportEntry *e = &out->entries[n];
        e->name_ptr = base + name_rva;
        e->fn_rva = fn_rva;
        e->ordinal = base_ordinal + ord_index;
        e->pad = 0;
        ++n;
    }
    out->count = n;
    return 0;
}
