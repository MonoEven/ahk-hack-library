/*
 * Remote thread stub for Eval-level hooking.
 *
 * Runs inside the target AutoHotkey process. It first calls the embedded
 * internal locator to discover gScript/finalize/findOrAddVar/crtFree/
 * symInvalid, then calls the in-process expression evaluator blob and
 * stores the return codes in the shared parameter block.
 */

typedef unsigned long long u64;
typedef unsigned int u32;
typedef int i32;

typedef struct {
    u64 locator;
    u64 eval;
    u64 base;
    u64 text_rva;
    u64 text_size;
    u64 postfix_rva;
    u64 expand_rva;
    u64 loc_out;
    u64 postfix_fn;
    u64 expand_fn;
    u64 curr_line_slot;
    u64 scratch;
    u64 expr;
    u64 out;
    u64 sym_invalid;
    i32 loc_rc;
    i32 eval_rc;
    u64 layout;
} RemoteEvalParam;

typedef int (*LocatorFn)(u64 base, u64 text_rva, u64 text_size,
                         u64 postfix_rva, u64 expand_rva, u64 loc_out);
typedef int (*EvalFn)(u64 postfix_fn, u64 expand_fn, u64 curr_line_slot,
                      u64 scratch, u64 expr, u64 out, i32 stage,
                      u64 line_override, u64 arg_override,
                      u64 g_script, u64 finalize_fn, u64 find_var_fn,
                      u64 free_fn, u64 sym_invalid, u64 layout);

u32 __stdcall RemoteEvalThread(void *param)
{
    RemoteEvalParam *p = (RemoteEvalParam *)param;
    u64 g_script;
    u64 finalize_fn;
    u64 find_var_fn;
    u64 free_fn;
    u64 sym_invalid;

    p->loc_rc = ((LocatorFn)p->locator)(p->base, p->text_rva, p->text_size,
                                        p->postfix_rva, p->expand_rva,
                                        p->loc_out);
    if (p->loc_rc != 0)
        return 1;

    g_script = *(u64 *)(p->loc_out + 0);
    finalize_fn = *(u64 *)(p->loc_out + 8);
    find_var_fn = *(u64 *)(p->loc_out + 16);
    free_fn = *(u64 *)(p->loc_out + 24);
    sym_invalid = *(u64 *)(p->loc_out + 32);

    p->eval_rc = ((EvalFn)p->eval)(p->postfix_fn, p->expand_fn,
                                   p->curr_line_slot, p->scratch, p->expr,
                                   p->out, 1, 0, 0, g_script, finalize_fn,
                                   find_var_fn, free_fn, sym_invalid,
                                   p->layout);
    return 0;
}
