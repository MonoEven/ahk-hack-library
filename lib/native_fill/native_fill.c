/*
 * native_fill.c - proof-of-concept leaf filler compiled as a normal DLL.
 *
 * This is the same logic as lib/mcode/array_builder.c, but every AHK
 * layout offset is passed in from runtime discovery instead of being
 * hardcoded, and there is no embedded machine code.
 */

#include <stdint.h>

typedef uint64_t u64;
typedef int64_t i64;
typedef uint32_t u32;
typedef uint16_t u16;
typedef uint8_t u8;
typedef int8_t i8;
typedef int16_t i16;
typedef int32_t i32;
typedef float f32;
typedef double f64;

__declspec(dllexport) int cnp_fill_leaf(
    u64 arr, u64 item, const u8 *data, i64 count,
    u32 item_size, u32 type_code,
    u32 m_length_off, u32 m_capacity_off,
    u32 variant_size, u32 value_off, u32 symbol_off,
    u32 sym_int, u32 sym_float)
{
    u32 symbol;
    i64 i;
    if (arr == 0 || item == 0 || count < 0)
        return 1;
    if (count > 0 && data == 0)
        return 1;
    if (item_size == 0 || variant_size < 16
        || value_off + 8 > variant_size || symbol_off + 4 > variant_size)
        return 2;
    symbol = (type_code == 0 || type_code == 2) ? sym_float : sym_int;

    for (i = 0; i < count; ++i)
    {
        u8 *v = (u8 *)item + (u64)i * variant_size;
        const u8 *src = data + (u64)i * item_size;
        i64 n = 0;
        f64 d = 0;

        if (type_code == 0)
            d = *(const f64 *)src;
        else if (type_code == 1)
            n = *(const i64 *)src;
        else if (type_code == 2)
            d = (f64)(*(const f32 *)src);
        else if (type_code == 3)
            n = *(const i32 *)src;
        else if (type_code == 4)
            n = (i64)(*(const u64 *)src);
        else if (type_code == 5)
            n = (i64)(*(const u32 *)src);
        else if (type_code == 6)
            n = *(const i16 *)src;
        else if (type_code == 7)
            n = (i64)(*(const u16 *)src);
        else if (type_code == 8)
            n = *(const i8 *)src;
        else if (type_code == 9)
            n = (i64)(*(const u8 *)src);
        else
            return 3;

        if (type_code == 0 || type_code == 2)
            *(f64 *)(v + value_off) = d;
        else
            *(i64 *)(v + value_off) = n;
        *(u32 *)(v + symbol_off) = symbol;
        for (u32 p = symbol_off + 4; p + 2 <= variant_size; p += 2)
            *(u16 *)(v + p) = 0;
    }

    *(u32 *)((u8 *)arr + m_length_off) = (u32)count;
    *(u32 *)((u8 *)arr + m_capacity_off) = (u32)count;
    return 0;
}
