/*
 * x64 native AHK Array builder.
 *
 * Fills the internal fields of an existing empty AHK Array() object so that
 * element-level work happens in machine code instead of an AHK loop.
 *
 * The layout comes from the AutoHotkey v2 source (script_object.h):
 *   ObjectBase : vtable(8) mRefCount(4) mFlags(4)          -> offset 0..15
 *   Object     : mBase(8) mFields.data(8)                  -> offset 16..31
 *   Array      : mItem(8) mLength(4) mCapacity(4)          -> offset 32..47
 *   Variant    : value(8) symbol(4) key_c(2) pad(2)        -> 16 bytes
 */

typedef unsigned long long u64;
typedef long long i64;
typedef unsigned int u32;
typedef unsigned short u16;
typedef unsigned char u8;
typedef signed char i8;
typedef short i16;
typedef int i32;
typedef double f64;
typedef float f32;

#define SYM_INTEGER 1
#define SYM_FLOAT 2

#define ARRAY_MITEM_OFF 32
#define ARRAY_MLENGTH_OFF 40
#define ARRAY_MCAPACITY_OFF 44
#define VARIANT_SIZE 16

int AhkBuildArrayFlat(u64 arr, u64 item, u64 data, i64 count,
                      u32 item_size, u32 type_code)
{
    i64 i;
    if (arr == 0 || item == 0 || count < 0)
        return 1;
    if (count > 0 && data == 0)
        return 1;
    if (item_size == 0)
        return 2;

    *(u64 *)(arr + ARRAY_MITEM_OFF) = item;
    *(u32 *)(arr + ARRAY_MLENGTH_OFF) = (u32)count;
    *(u32 *)(arr + ARRAY_MCAPACITY_OFF) = (u32)count;

    for (i = 0; i < count; ++i)
    {
        u64 v = item + (u64)i * VARIANT_SIZE;
        u8 *src = (u8 *)data + (u64)i * item_size;
        u32 symbol = SYM_INTEGER;
        i64 n = 0;
        f64 d = 0;

        if (type_code == 0)
        {
            /* float64 */
            d = *(f64 *)src;
            symbol = SYM_FLOAT;
        }
        else if (type_code == 1)
        {
            /* int64 */
            n = *(i64 *)src;
        }
        else if (type_code == 2)
        {
            /* float32 */
            d = (f64)(*(f32 *)src);
            symbol = SYM_FLOAT;
        }
        else if (type_code == 3)
        {
            /* int32 */
            n = *(i32 *)src;
        }
        else if (type_code == 4)
        {
            /* uint64 */
            n = (i64)(*(u64 *)src);
        }
        else if (type_code == 5)
        {
            /* uint32 */
            n = (i64)(*(u32 *)src);
        }
        else if (type_code == 6)
        {
            /* int16 */
            n = *(i16 *)src;
        }
        else if (type_code == 7)
        {
            /* uint16 */
            n = (i64)(*(u16 *)src);
        }
        else if (type_code == 8)
        {
            /* int8 */
            n = *(i8 *)src;
        }
        else if (type_code == 9)
        {
            /* uint8 / bool */
            n = (i64)(*(u8 *)src);
        }
        else
        {
            return 3;
        }

        if (symbol == SYM_FLOAT)
            *(f64 *)v = d;
        else
            *(i64 *)v = n;
        *(u32 *)(v + 8) = symbol;
        *(u16 *)(v + 12) = 0;
        *(u16 *)(v + 14) = 0;
    }
    return 0;
}
