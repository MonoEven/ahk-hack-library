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
    u32 num_functions;
    u32 name_vas;
    u32 ordinal_vas;
    u32 func_vas;
    u32 base_ordinal;
    u32 image_size;
    u64 image_end;
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

    image_size = *(u32 *)(opt + 56);    /* SizeOfImage */
    if (!image_size)
        return 1;
    image_end = base + image_size;
    if (export_rva >= image_size
        || (u64)export_rva + export_size > image_size
        || export_size < 40)
        return 1;

    ed = base + export_rva;
    num_names = *(u32 *)(ed + 24);          /* NumberOfNames */
    num_functions = *(u32 *)(ed + 20);      /* NumberOfFunctions */
    name_vas = *(u32 *)(ed + 32);           /* AddressOfNames */
    ordinal_vas = *(u32 *)(ed + 36);        /* AddressOfNameOrdinals */
    func_vas = *(u32 *)(ed + 28);           /* AddressOfFunctions */
    base_ordinal = *(u32 *)(ed + 16);       /* Base */
    if (num_names > 4096)
        num_names = 4096;

    /* Every subtable access below is a raw RVA dereference; bound all of
     * them against the mapped image so a malformed directory cannot read
     * out of bounds. */
    if (num_functions == 0 && num_names != 0)
        return 1;
    if ((u64)name_vas + 4ull * num_names > image_size)
        return 1;
    if ((u64)ordinal_vas + 2ull * num_names > image_size)
        return 1;
    if ((u64)func_vas + 4ull * num_functions > image_size)
        return 1;

    out->dir_ptr = ed;
    out->reserved = 0;
    for (i = 0; i < num_names; ++i)
    {
        u32 name_rva = *(u32 *)(base + name_vas + 4 * i);
        u16 ord_index = *(u16 *)(base + ordinal_vas + 2 * i);
        u32 fn_rva;
        ExportEntry *e = &out->entries[n];
        if (name_rva >= image_size)
            return 1;
        if (ord_index >= num_functions)
            return 1;
        fn_rva = *(u32 *)(base + func_vas + 4 * ord_index);
        if (fn_rva >= image_size)
            return 1;
        e->name_ptr = base + name_rva;
        e->fn_rva = fn_rva;
        e->ordinal = base_ordinal + ord_index;
        e->pad = 0;
        ++n;
    }
    out->count = n;
    return 0;
}
