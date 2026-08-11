/*
 * mem_script.c - load script text from memory without a temp file.
 *
 * Builds a minimal TextMem-compatible TextStream object and passes it
 * directly to Script::LoadIncludedFile(TextStream*, int).  The object is
 * constructed by hand in a caller-provided scratch buffer; only the fields
 * needed for buffered reading are initialized.
 *
 * Layout is version-dependent:
 *   pre-2.0.26 TextStream: mData at 0x40, mDataPos at 0x50
 *   2.0.26+ TextStream:    mData at 0x50, mDataPos at 0x60
 * The caller passes the mData offset; vtable order follows MSVC.
 */

typedef unsigned long long u64;
typedef long long i64;
typedef unsigned int u32;
typedef unsigned short u16;
typedef unsigned char u8;
typedef int i32;

#define TS_FLAGS_OFF 8
#define TS_LENGTH_OFF 12
#define TS_LASTREAD_OFF 16
#define TS_CODEPAGE_OFF 20
#define TS_MAXCHAR_OFF 24
#define TS_DATA_OFF_OFF 36
#define TS_LASTWRITECHAR_OFF 44
#define TS_POS_OFF 48
#define TS_BUFFER_OFF 56

static u32 ts_read(u64 ts, u64 buf, u32 size)
{
    u32 doff = *(u32 *)(ts + TS_DATA_OFF_OFF);
    u64 data = *(u64 *)(ts + doff);
    u64 pos = *(u64 *)(ts + doff + 16);
    u32 len = *(u32 *)(ts + doff + 8);
    u64 rem = data + len - pos;
    u32 i;
    if ((u64)size > rem)
        size = (u32)rem;
    for (i = 0; i < size; ++i)
        ((u8 *)buf)[i] = ((u8 *)pos)[i];
    *(u64 *)(ts + doff + 16) = pos + size;
    return size;
}

static u32 ts_write(u64 ts, u64 buf, u32 size)
{
    (void)ts; (void)buf; (void)size;
    return 0;
}

static u8 ts_seek(u64 ts, i64 distance, i32 origin)
{
    (void)ts; (void)distance; (void)origin;
    return 0;
}

static i64 ts_tell(u64 ts)
{
    u32 doff = *(u32 *)(ts + TS_DATA_OFF_OFF);
    return (i64)(*(u64 *)(ts + doff + 16) - *(u64 *)(ts + doff));
}

static i64 ts_length(u64 ts)
{
    u32 doff = *(u32 *)(ts + TS_DATA_OFF_OFF);
    return (i64)*(u32 *)(ts + doff + 8);
}

static void ts_close(u64 ts)
{
    u32 doff = *(u32 *)(ts + TS_DATA_OFF_OFF);
    *(u64 *)(ts + doff) = 0;
    *(u32 *)(ts + doff + 8) = 0;
    *(u8 *)(ts + doff + 12) = 0;
    *(u64 *)(ts + doff + 16) = 0;
}

static u8 ts_open(u64 ts, u64 spec, u64 flags)
{
    (void)ts; (void)spec; (void)flags;
    return 1;
}

static void ts_dtor(u64 ts, u32 flags)
{
    (void)flags;
    ts_close(ts);
}

static void build_vt(u64 vt)
{
    *(u64 *)(vt + 0) = (u64)ts_dtor;
    *(u64 *)(vt + 8) = (u64)ts_open;
    *(u64 *)(vt + 16) = (u64)ts_close;
    *(u64 *)(vt + 24) = (u64)ts_read;
    *(u64 *)(vt + 32) = (u64)ts_write;
    *(u64 *)(vt + 40) = (u64)ts_seek;
    *(u64 *)(vt + 48) = (u64)ts_tell;
    *(u64 *)(vt + 56) = (u64)ts_length;
}

int AhkLoadScriptFromMemory(u64 load_ts, u64 script, u64 source_count,
                            u64 text, u32 text_len, u64 scratch,
                            u32 data_off)
{
    u64 vt;
    u64 ts;
    i32 idx;
    i32 rc;
    u32 i;
    if (!load_ts || !script || !text || !scratch || !data_off)
        return 1;
    for (i = 0; i < 0x200; ++i)
        ((u8 *)scratch)[i] = 0;
    vt = scratch;
    ts = scratch + 0x100;
    build_vt(vt);
    *(u64 *)ts = vt;
    *(u32 *)(ts + TS_FLAGS_OFF) = 0xC;
    *(u32 *)(ts + TS_LENGTH_OFF) = 0;
    *(u32 *)(ts + TS_LASTREAD_OFF) = 0;
    *(u32 *)(ts + TS_CODEPAGE_OFF) = 1200;
    *(u32 *)(ts + TS_MAXCHAR_OFF) = 2;
    *(u32 *)(ts + TS_DATA_OFF_OFF) = data_off;
    *(u16 *)(ts + TS_LASTWRITECHAR_OFF) = 0;
    *(u64 *)(ts + TS_POS_OFF) = 0;
    *(u64 *)(ts + TS_BUFFER_OFF) = 0;
    *(u64 *)(ts + data_off) = text;
    *(u32 *)(ts + data_off + 8) = text_len;
    *(u8 *)(ts + data_off + 12) = 0;
    *(u64 *)(ts + data_off + 16) = text;
    idx = source_count ? *(i32 *)source_count : 0;
    rc = ((i32 (*)(u64, u64, i32))load_ts)(script, ts, idx);
    if (rc != 1)
        return 2;
    if (source_count)
        *(i32 *)source_count = idx + 1;
    return 0;
}
