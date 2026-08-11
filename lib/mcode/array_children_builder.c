/*
 * x64 native AHK Array parent filler.
 *
 * Fills an existing empty AHK Array() with child Array pointers.  Each child
 * is AddRef'd (vtable slot 1) when stored, matching Object::Variant::Assign;
 * the AHK caller keeps temporary references until after this call and then
 * drops them, leaving the parent Variant as the surviving owner.
 *
 * Layout is identical to mcode/array_builder.c (see script_object.h):
 *   Array  : mItem(8) at 32, mLength(4) at 40, mCapacity(4) at 44
 *   Variant: value(8) symbol(4) key_c(2) pad(2) = 16 bytes
 */

typedef unsigned long long u64;
typedef long long i64;
typedef unsigned int u32;
typedef unsigned short u16;
typedef unsigned char u8;

#define SYM_OBJECT 5

#define ARRAY_MITEM_OFF 32
#define ARRAY_MLENGTH_OFF 40
#define ARRAY_MCAPACITY_OFF 44
#define VARIANT_SIZE 16
#define VTABLE_ADDREF_OFF 8

int AhkBuildArrayChildren(u64 arr, u64 child_ptr_array, u64 count)
{
    u64 item;
    u64 i;
    if (arr == 0 || count > 0 && child_ptr_array == 0)
        return 1;
    item = *(u64 *)(arr + ARRAY_MITEM_OFF);
    if (item == 0)
        return 2;
    *(u32 *)(arr + ARRAY_MLENGTH_OFF) = (u32)count;
    *(u32 *)(arr + ARRAY_MCAPACITY_OFF) = (u32)count;
    for (i = 0; i < count; ++i)
    {
        u64 v = item + i * VARIANT_SIZE;
        u64 child = *(u64 *)(child_ptr_array + i * 8);
        if (child == 0)
            return 3;
        /* child->AddRef() via IObject vtable slot 1. */
        {
            u64 vtable = *(u64 *)child;
            u64 addref = *(u64 *)(vtable + VTABLE_ADDREF_OFF);
            ((u64 (*)(u64))addref)(child);
        }
        *(u64 *)v = child;
        *(u32 *)(v + 8) = SYM_OBJECT;
        *(u16 *)(v + 12) = 0;
        *(u16 *)(v + 14) = 0;
    }
    return 0;
}
