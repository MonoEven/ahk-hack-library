/*
 * x64 in-process expression evaluator for AutoHotkey.
 *
 * Calls the interpreter's own pipeline on a temporary Line:
 *   Line::ExpressionToPostfix(ArgStruct&)  -> builds the postfix expression
 *   Line::ExpandSingleArg(...)             -> evaluates it
 *
 * Layouts are derived from the AutoHotkey v2 source:
 *   Line  : type(1) argc(1) file(2) lineNum(4) mArg(8) ...
 *   ArgStruct: type(1) isExpression(1) length(4) text(8) ...
 *   ResultToken: ExprTokenType(24) + result(4) + buf(8) + memToFree(8)
 */

typedef unsigned long long u64;
typedef long long i64;
typedef unsigned int u32;
typedef unsigned short u16;
typedef unsigned char u8;
typedef int i32;

#define LINE_TYPE_OFF 0
#define LINE_ARGC_OFF 1
#define LINE_NUM_OFF 4
#define LINE_ARG_OFF 8

#define ARG_TYPE_OFF 0
#define ARG_ISEXPR_OFF 1
#define ARG_LEN_OFF 4
#define ARG_TEXT_OFF 8
#define ARG_MAX_STACK_OFF 32
#define ARG_MAX_ALLOC_OFF 36

#define TOKEN_VALUE_OFF 0
#define TOKEN_SYMBOL_OFF 16

#define ACT_BLOCK_BEGIN 3
#define ARG_TYPE_NORMAL 0
#define RESULT_OK 1

typedef int (*PostfixFn)(u64 line, u64 arg, u64 *infix);
typedef u64 (*ExpandFn)(u64 line, i32 idx, i32 *result_out,
                        u64 result_token, u64 *target, u64 *deref_buf,
                        u64 *deref_size, u64 arg_deref, u64 extra_size);

int AhkEvalInProcess(u64 postfix_fn, u64 expand_fn, u64 curr_line_slot,
                     u64 scratch, u64 expr_ptr, u64 out, u64 stage,
                     u64 line_override, u64 arg_override)
{
    u64 line;
    u64 arg;
    u64 result_token;
    u64 deref;
    u64 target;
    u64 deref_size = 0x400000; /* 4 MiB, <= LARGE_DEREF_BUF_SIZE */
    u64 infix = 0;
    u64 saved_line;
    u64 len = 0;
    u8 *cursor;
    i32 status;
    i32 expand_status;
    u64 string_result;
    i32 i;

    if (!postfix_fn || !expand_fn || !curr_line_slot
        || !scratch || !expr_ptr || !out)
        return 1;

    line = line_override ? line_override : scratch;
    arg = arg_override ? arg_override : scratch + 0x100;
    result_token = scratch + 0x180;
    deref = scratch + 0x300;

    if (!line_override)
    {
        for (i = 0; i < 0x100; ++i)
            ((u8 *)line)[i] = 0;
        /* Any non-expression action works: ExpandExpression only discards
         * the result for ACT_EXPRESSION and has special boolean handling
         * for ACT_IF/ACT_WHILE/ACT_UNTIL. */
        *(u8 *)(line + LINE_TYPE_OFF) = ACT_BLOCK_BEGIN;
        *(u8 *)(line + LINE_ARGC_OFF) = 1;
        *(u32 *)(line + LINE_NUM_OFF) = 1;
        *(u64 *)(line + LINE_ARG_OFF) = arg;
    }
    for (i = 0; i < 0x80; ++i)
        ((u8 *)result_token)[i] = 0;

    cursor = (u8 *)expr_ptr;
    while (*(u16 *)cursor)
    {
        cursor += 2;
        ++len;
    }

    if (!arg_override)
    {
        for (i = 0; i < 0x80; ++i)
            ((u8 *)arg)[i] = 0;
        *(u8 *)(arg + ARG_TYPE_OFF) = ARG_TYPE_NORMAL;
        *(u8 *)(arg + ARG_ISEXPR_OFF) = 1;
        *(u32 *)(arg + ARG_LEN_OFF) = (u32)len;
        *(u64 *)(arg + ARG_TEXT_OFF) = expr_ptr;
        *(u32 *)(arg + ARG_MAX_STACK_OFF) = 256;
        *(u32 *)(arg + ARG_MAX_ALLOC_OFF) = 256;
    }

    *(u32 *)(out + 0) = 1; /* status: fail until proven otherwise */
    *(u32 *)(out + 4) = 0;
    *(i64 *)(out + 8) = 0;
    *(u64 *)(out + 16) = 0;

    saved_line = *(u64 *)curr_line_slot;
    *(u64 *)curr_line_slot = line;

    status = ((PostfixFn)postfix_fn)(line, arg, &infix);
    if (status != RESULT_OK)
    {
        *(u64 *)curr_line_slot = saved_line;
        *(u32 *)(out + 0) = 2; /* postfix failed */
        return 0;
    }

    if (stage == 0)
    {
        *(u64 *)curr_line_slot = saved_line;
        *(u32 *)(out + 0) = 0; /* success */
        *(u32 *)(out + 4) = 99; /* postfix-only marker */
        return 0;
    }

    target = deref;

    /* Initialize ResultToken the way ExpandSingleArg does before the call. */
    *(u32 *)(result_token + TOKEN_SYMBOL_OFF) = 0xFFFFFFFF;
    *(u64 *)(result_token + 8) = ~0ull;   /* marker_length = -1 */
    *(u64 *)(result_token + 24) = deref;  /* buf */
    *(u64 *)(result_token + 32) = 0;      /* mem_to_free */

    string_result = ((ExpandFn)expand_fn)(
        line, 0, &expand_status, result_token, &target, &deref, &deref_size,
        deref + 0x3F0000, 0x3F0000);
    *(u64 *)curr_line_slot = saved_line;
    if (!string_result)
    {
        *(u32 *)(out + 0) = 3; /* expand failed */
        return 0;
    }

    *(u32 *)(out + 0) = 0; /* success */
    *(u32 *)(out + 4) = *(u32 *)(result_token + TOKEN_SYMBOL_OFF);
    *(i64 *)(out + 8) = *(i64 *)(result_token + TOKEN_VALUE_OFF);
    *(u64 *)(out + 16) = *(u64 *)(result_token + TOKEN_VALUE_OFF);
    for (i = 0; i < 48; ++i)
        ((u8 *)(out + 32))[i] = ((u8 *)result_token)[i];
    if (*(u32 *)(out + 4) != 0 && *(u32 *)(out + 4) != 1
        && *(u32 *)(out + 4) != 2 && *(u32 *)(out + 4) != 5)
    {
        /* Fallback used by ExpandSingleArg: token was not set, so the
         * returned string is the result. */
        *(u32 *)(out + 4) = 0;
        *(u64 *)(out + 16) = string_result;
    }
    *(u64 *)(out + 80) = *(u64 *)(arg + 24);
    if (*(u64 *)(arg + 24))
        for (i = 0; i < 288; ++i)
            ((u8 *)(out + 88))[i] = ((u8 *)(*(u64 *)(arg + 24)))[i];
    *(u32 *)(out + 200) = (u32)expand_status;
    /* Temporary infix buffer owned by this harness; the caller frees it
     * through the CRT free that ExpressionToPostfix's own callers use. */
    *(u64 *)(out + 208) = infix;
    return 0;
}
