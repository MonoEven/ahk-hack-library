/*
 * Generic remote thread stub: call one function pointer with six arguments
 * and store the integer return code in the shared parameter block.
 */

typedef unsigned long long u64;
typedef unsigned int u32;
typedef int i32;

typedef struct {
    u64 fn;
    u64 a1;
    u64 a2;
    u64 a3;
    u64 a4;
    u64 a5;
    u64 a6;
    i32 rc;
    u64 reserved;
} RemoteCallParam;

typedef int (*CallFn)(u64 a1, u64 a2, u64 a3, u64 a4, u64 a5, u64 a6);

u32 __stdcall RemoteCallThread(void *param)
{
    RemoteCallParam *p = (RemoteCallParam *)param;
    p->rc = ((CallFn)p->fn)(p->a1, p->a2, p->a3, p->a4, p->a5, p->a6);
    return 0;
}
