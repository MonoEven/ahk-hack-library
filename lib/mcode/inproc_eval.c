/*
 * x64 in-process expression evaluator for AutoHotkey.
 *
 * Calls the interpreter's own pipeline on a temporary Line:
 *   Lightweight deref scan           -> marks identifiers for resolution
 *   Line::ExpressionToPostfix()      -> builds the postfix expression
 *   Line::FinalizeExpression()       -> validates calls/params (when separate)
 *   Script::FindOrAddVar()           -> resolves read variables/functions
 *   Line::ExpandExpression()         -> evaluates it
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
#define ARG_DEREF_OFF 16
#define ARG_POSTFIX_OFF 24
#define ARG_MAX_STACK_OFF 32
#define ARG_MAX_ALLOC_OFF 36

#define TOKEN_VALUE_OFF 0
#define TOKEN_SYMBOL_OFF 16
#define TOKEN_VAR_OFF 0
#define TOKEN_VAR_DEREF_OFF 0

#define DEREF_MARKER_OFF 0
#define DEREF_VALUE_OFF 8
#define DEREF_TYPE_OFF 16
#define DEREF_LEN_OFF 20
#define DEREF_SIZE 24
#define DT_VAR 0
#define DT_FUNCREF 7

#define VARREF_REF 3
#define FINDVAR_FOR_READ 0x103

#define FINAL_DEREF_ADDR 0x100800

#define ACT_BLOCK_BEGIN 3
#define ARG_TYPE_NORMAL 0
#define RESULT_OK 1
#define SYM_VAR 4

typedef int (*PostfixFn)(u64 line, u64 arg, u64 *infix);
typedef int (*FinalizeFn)(u64 line, u64 arg);
typedef u64 (*FindVarFn)(u64 script, u64 name, u64 len, u32 scope);
typedef u64 (*ExpandFn)(u64 line, i32 idx, i32 *result_out,
                        u64 result_token, u64 *target, u64 *deref_buf,
                        u64 *deref_size, u64 arg_deref, u64 extra_size);
typedef void (*FreeFn)(u64 ptr);

static int is_ident_start(u16 c)
{
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
        || c == '_' || c >= 0x80;
}

static int is_ident_char(u16 c)
{
    return is_ident_start(c) || (c >= '0' && c <= '9');
}

int AhkEvalInProcess(u64 postfix_fn, u64 expand_fn, u64 curr_line_slot,
                     u64 scratch, u64 expr_ptr, u64 out, u64 stage,
                     u64 line_override, u64 arg_override,
                     u64 g_script, u64 finalize_fn,
                     u64 find_var_fn, u64 free_fn, u64 sym_invalid)
{
    u64 line;
    u64 arg;
    u64 result_token;
    u64 deref;
    u64 target;
    u64 deref_size = 0x400000; /* 4 MiB, <= LARGE_DEREF_BUF_SIZE */
    u64 infix = 0;
    u64 saved_line;
    u64 final_deref;
    u64 token;
    u64 deref_ptr;
    u64 var;
    u32 deref_count;
    u64 len = 0;
    u16 *cp16;
    u8 *cursor;
    i32 status;
    i32 expand_status;
    u64 string_result;
    i32 i;

    if (!postfix_fn || !expand_fn || !curr_line_slot
        || !scratch || !expr_ptr || !out
        || !g_script || !find_var_fn || !free_fn)
        return 1;

    line = line_override ? line_override : scratch;
    arg = arg_override ? arg_override : scratch + 0x100;
    result_token = scratch + 0x180;
    deref = scratch + 0x300;
    final_deref = scratch + FINAL_DEREF_ADDR;

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

    if (!arg_override)
    {
        /* Lightweight deref scan: mark identifiers so the interpreter can
         * resolve variables and function names.  Literals and operators are
         * handled by ExpressionToPostfix's raw-text parser. */
        deref_count = 0;
        cp16 = (u16 *)expr_ptr;
        while (*cp16)
        {
            if (*cp16 == '"' || *cp16 == '\'')
            {
                u16 quote = *cp16++;
                while (*cp16 && *cp16 != quote)
                {
                    if (*cp16 == '`' && cp16[1])
                        ++cp16;
                    ++cp16;
                }
                if (*cp16)
                    ++cp16;
                continue;
            }
            if (is_ident_start(*cp16))
            {
                u16 *start = cp16;
                while (is_ident_char(*cp16))
                    ++cp16;
                if (deref_count < 255)
                {
                    u64 e = final_deref + deref_count * DEREF_SIZE;
                    *(u64 *)(e + DEREF_MARKER_OFF) = (u64)start;
                    *(u64 *)(e + DEREF_VALUE_OFF) = 0;
                    *(u8 *)(e + DEREF_TYPE_OFF) = DT_VAR;
                    *(u8 *)(e + 17) = 0;
                    *(u32 *)(e + DEREF_LEN_OFF) = (u32)(cp16 - start);
                    ++deref_count;
                }
                continue;
            }
            ++cp16;
        }
        if (deref_count)
        {
            *(u64 *)(final_deref + deref_count * DEREF_SIZE) = 0;
            *(u64 *)(arg + ARG_DEREF_OFF) = final_deref;
        }
    }

    *(u32 *)(out + 0) = 1; /* status: fail until proven otherwise */
    *(u32 *)(out + 4) = 0;
    *(i64 *)(out + 8) = 0;
    *(u64 *)(out + 16) = 0;

    saved_line = *(u64 *)curr_line_slot;
    *(u64 *)curr_line_slot = line;

    status = ((PostfixFn)postfix_fn)(line, arg, &infix);
    if (infix)
        ((FreeFn)free_fn)(infix);
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

    /* Resolve read variable/function references before FinalizeExpression,
     * which needs Var* pointers when validating function calls. */
    for (token = *(u64 *)(arg + ARG_POSTFIX_OFF);
         *(u32 *)(token + TOKEN_SYMBOL_OFF) != (u32)sym_invalid; token += 24)
    {
        if (*(u32 *)(token + TOKEN_SYMBOL_OFF) != SYM_VAR)
            continue;
        if (*(u32 *)(token + 8) >= VARREF_REF)
            continue; /* already resolved by ExpressionToPostfix */
        deref_ptr = *(u64 *)(token + TOKEN_VAR_DEREF_OFF);
        if (!deref_ptr)
            continue;
        if (*(u8 *)(deref_ptr + DEREF_TYPE_OFF) == DT_FUNCREF)
        {
            *(u64 *)(token + TOKEN_VAR_OFF) = *(u64 *)(deref_ptr + DEREF_VALUE_OFF);
            continue;
        }
        var = ((FindVarFn)find_var_fn)(
            g_script,
            *(u64 *)(deref_ptr + DEREF_MARKER_OFF),
            *(u32 *)(deref_ptr + DEREF_LEN_OFF),
            FINDVAR_FOR_READ);
        if (!var)
        {
            *(u64 *)curr_line_slot = saved_line;
            *(u32 *)(out + 0) = 5; /* variable resolution failed */
            return 0;
        }
        *(u64 *)(token + TOKEN_VAR_OFF) = var;
    }

    if (finalize_fn && finalize_fn != postfix_fn)
    {
        status = ((FinalizeFn)finalize_fn)(line, arg);
        if (status != RESULT_OK)
        {
            *(u64 *)curr_line_slot = saved_line;
            *(u32 *)(out + 0) = 6; /* finalize failed */
            return 0;
        }
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
    return 0;
}
