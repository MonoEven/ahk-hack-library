/*
 * mem_script.c - load script text from memory without a temp file.
 *
 * Builds a TextMem-compatible TextStream object and passes it directly to
 * Script::LoadIncludedFile(TextStream*, int).  The object is constructed by
 * hand in a caller-provided scratch buffer.
 *
 * TextStream gained linked-list members in 2.0.26, which moves TextMem::mData
 * from 0x40 to 0x50.  Instead of choosing one layout, both mData regions are
 * populated with the same buffer and every accessor advances both positions,
 * so the same blob works on either layout.
 *
 * The two mData slots are validated constants, not version tags: every load
 * is checked by the caller against its result (rc == 1 plus, for the layout
 * probe, a function-count increase).  An interpreter whose TextStream layout
 * differs from both slots fails that check loudly at probe time instead of
 * silently misparsing injected text.
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
#define TS_LASTWRITECHAR_OFF 44
#define TS_POS_OFF 48
#define TS_BUFFER_OFF 56

#define MDATA_OLD 0x40
#define MDATA_NEW 0x50

static u32 ts_read(u64 ts, u64 buf, u32 size)
{
    u64 data_old = *(u64 *)(ts + MDATA_OLD);
    u64 data_new = *(u64 *)(ts + MDATA_NEW);
    u64 pos_old = *(u64 *)(ts + MDATA_OLD + 16);
    u64 pos_new = *(u64 *)(ts + MDATA_NEW + 16);
    u32 len = *(u32 *)(ts + MDATA_OLD + 8);
    u64 rem = data_old + len - pos_old;
    u32 i;
    if ((u64)size > rem)
        size = (u32)rem;
    for (i = 0; i < size; ++i)
        ((u8 *)buf)[i] = ((u8 *)pos_old)[i];
    *(u64 *)(ts + MDATA_OLD + 16) = pos_old + size;
    *(u64 *)(ts + MDATA_NEW + 16) = pos_new + size;
    (void)data_new;
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
    return (i64)(*(u64 *)(ts + MDATA_OLD + 16) - *(u64 *)(ts + MDATA_OLD));
}

static i64 ts_length(u64 ts)
{
    return (i64)*(u32 *)(ts + MDATA_OLD + 8);
}

static void ts_close(u64 ts)
{
    u32 i;
    for (i = 0; i < 2; ++i)
    {
        u64 doff = i ? MDATA_NEW : MDATA_OLD;
        *(u64 *)(ts + doff) = 0;
        *(u32 *)(ts + doff + 8) = 0;
        *(u8 *)(ts + doff + 12) = 0;
        *(u64 *)(ts + doff + 16) = 0;
    }
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
                            u64 text, u32 text_len, u64 scratch)
{
    u64 vt;
    u64 ts;
    i32 idx;
    i32 rc;
    u32 i;
    if (!load_ts || !script || !text || !scratch)
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
    *(u16 *)(ts + TS_LASTWRITECHAR_OFF) = 0;
    *(u64 *)(ts + TS_POS_OFF) = 0;
    *(u64 *)(ts + TS_BUFFER_OFF) = 0;
    for (i = 0; i < 2; ++i)
    {
        u64 doff = i ? MDATA_NEW : MDATA_OLD;
        *(u64 *)(ts + doff) = text;
        *(u32 *)(ts + doff + 8) = text_len;
        *(u8 *)(ts + doff + 12) = 0;
        *(u64 *)(ts + doff + 16) = text;
    }
    idx = source_count ? *(i32 *)source_count : 0;
    rc = ((i32 (*)(u64, u64, i32))load_ts)(script, ts, idx);
    if (rc != 1)
        return 2;
    if (source_count)
        *(i32 *)source_count = idx + 1;
    return 0;
}
