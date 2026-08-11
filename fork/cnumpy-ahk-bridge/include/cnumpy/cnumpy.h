/**
 * cnumpy - Pure C implementation of NumPy (Python 3.10 compatible)
 * Core type definitions, macros, and DLL export declarations
 */
#ifndef CNUMPY_H
#define CNUMPY_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

/* DLL Export/Import macros for Visual Studio */
#ifdef CNUMPY_EXPORTS
    #define CNP_API __declspec(dllexport)
#else
    #define CNP_API __declspec(dllimport)
#endif

/* Calling convention */
#define CNP_CALL __cdecl

/* Version info - matching NumPy 1.21.x (Python 3.10 default) */
#define CNUMPY_VERSION_MAJOR 1
#define CNUMPY_VERSION_MINOR 21
#define CNUMPY_VERSION_MICRO 0
#define CNUMPY_VERSION_STRING "1.21.0-cnumpy"

/* Maximum number of dimensions supported */
#define CNP_MAXDIMS 64
#define CNP_MAXARGS 32

/* =========================================================================
 * Data Types (corresponding to numpy dtype type numbers)
 * ========================================================================= */
typedef enum {
    CNP_NOTYPE = 0,
    CNP_BOOL = 1,
    CNP_BYTE = 2,       /* int8 */
    CNP_UBYTE = 3,      /* uint8 */
    CNP_SHORT = 4,      /* int16 */
    CNP_USHORT = 5,     /* uint16 */
    CNP_INT = 6,        /* int32 */
    CNP_UINT = 7,       /* uint32 */
    CNP_LONG = 8,       /* int64 (platform dependent) */
    CNP_ULONG = 9,      /* uint64 */
    CNP_LONGLONG = 10,  /* int64 */
    CNP_ULONGLONG = 11, /* uint64 */
    CNP_FLOAT = 12,     /* float32 */
    CNP_DOUBLE = 13,    /* float64 */
    CNP_LONGDOUBLE = 14,/* long double */
    CNP_CFLOAT = 15,    /* complex64 */
    CNP_CDOUBLE = 16,   /* complex128 */
    CNP_CLONGDOUBLE = 17,
    CNP_OBJECT = 18,
    CNP_STRING = 19,    /* bytes */
    CNP_UNICODE = 20,   /* str */
    CNP_VOID = 21,
    CNP_DATETIME = 22,
    CNP_TIMEDELTA = 23,
    CNP_HALF = 24,      /* float16 */
    CNP_NTYPES = 25
} CNP_TYPE;

/* Convenience type aliases matching numpy naming */
typedef int8_t   cnp_bool;
typedef int8_t   cnp_byte;
typedef uint8_t  cnp_ubyte;
typedef int16_t  cnp_short;
typedef uint16_t cnp_ushort;
typedef int32_t  cnp_int;
typedef uint32_t cnp_uint;
typedef int64_t  cnp_long;
typedef uint64_t cnp_ulong;
typedef int64_t  cnp_longlong;
typedef uint64_t cnp_ulonglong;
typedef float    cnp_float;
typedef double   cnp_double;
typedef long double cnp_longdouble;
typedef uint16_t cnp_half;

/* Complex number types */
typedef struct { float real; float imag; } cnp_cfloat;
typedef struct { double real; double imag; } cnp_cdouble;
typedef struct { long double real; long double imag; } cnp_clongdouble;

/* =========================================================================
 * Array flags
 * ========================================================================= */
#define CNP_ARRAY_C_CONTIGUOUS    0x0001
#define CNP_ARRAY_F_CONTIGUOUS    0x0002
#define CNP_ARRAY_OWNDATA         0x0004
#define CNP_ARRAY_FORCECAST       0x0010
#define CNP_ARRAY_ENSURECOPY      0x0020
#define CNP_ARRAY_ENSUREARRAY     0x0040
#define CNP_ARRAY_ELEMENTSTRIDES  0x0080
#define CNP_ARRAY_ALIGNED         0x0100
#define CNP_ARRAY_NOTSWAPPED      0x0200
#define CNP_ARRAY_WRITEABLE       0x0400
#define CNP_ARRAY_VIRTUAL_ALLOC   0x0800
#define CNP_ARRAY_MEMMAP          0x1000
#define CNP_ARRAY_BEHAVED         (CNP_ARRAY_ALIGNED | CNP_ARRAY_WRITEABLE)
#define CNP_ARRAY_CARRAY          (CNP_ARRAY_C_CONTIGUOUS | CNP_ARRAY_ALIGNED | CNP_ARRAY_WRITEABLE)
#define CNP_ARRAY_FARRAY          (CNP_ARRAY_F_CONTIGUOUS | CNP_ARRAY_ALIGNED | CNP_ARRAY_WRITEABLE)
#define CNP_ARRAY_DEFAULT         CNP_ARRAY_CARRAY

/* Array order */
typedef enum {
    CNP_ORDER_C = 0,     /* C (row-major) order */
    CNP_ORDER_F = 1,     /* Fortran (column-major) order */
    CNP_ORDER_A = 2,     /* Any (preserve input order) */
    CNP_ORDER_K = 3      /* Keep (as close to input as possible) */
} CNP_ORDER;

/* Casting rules */
typedef enum {
    CNP_CAST_NO = 0,
    CNP_CAST_EQUIV = 1,
    CNP_CAST_SAFE = 2,
    CNP_CAST_SAME_KIND = 3,
    CNP_CAST_UNSAFE = 4
} CNP_CASTING;

/* Axis constants */
#define CNP_AXIS_NONE (-1)

/* =========================================================================
 * Dtype descriptor structure
 * ========================================================================= */
typedef struct _CnpDtype {
    CNP_TYPE type_num;      /* Type number */
    int      elsize;        /* Element size in bytes */
    int      alignment;     /* Alignment requirement */
    char     kind;          /* Type kind: 'b','i','u','f','c','O','S','U','V','M','m' */
    char     byteorder;     /* '<', '>', '=' */
    char     name[32];      /* Type name string */
    int      refcount;      /* Reference count */
} CnpDtype;

typedef void (*CnpArrayOwnerRelease)(void *owner);
typedef struct CnpStringListResult CnpStringListResult;
typedef struct CnpRegexResult CnpRegexResult;

/* =========================================================================
 * NDArray - Core N-dimensional array structure
 * ========================================================================= */
typedef struct _CnpArray {
    int         ndim;                   /* Number of dimensions */
    int64_t    *shape;                  /* Array shape (ndim elements) */
    int64_t    *strides;                /* Strides in bytes (ndim elements) */
    int64_t     size;                   /* Total number of elements */
    void       *data;                   /* Pointer to data buffer */
    CnpDtype   *dtype;                  /* Data type descriptor */
    uint32_t    flags;                  /* Array flags */
    int         refcount;               /* Reference count */
    struct _CnpArray *base;            /* Base array (for views) */
    int64_t     offset;                 /* Byte offset into base data */
    void       *owner;                  /* Optional root storage owner */
    CnpArrayOwnerRelease owner_release; /* Releases owner exactly once */
} CnpArray;

/* Borrowed UTF-8 result is copied by cnumpy before the callback returns. */
typedef const char* (CNP_CALL *CnpStringFunction)(
    const CnpArray *arr, void *userdata);

/* =========================================================================
 * Iterator structure for traversing arrays
 * ========================================================================= */
typedef struct {
    CnpArray   *array;                  /* Array being iterated */
    int64_t    *coordinates;            /* Current multi-index */
    int64_t     index;                  /* Flat index */
    int64_t     size;                   /* Total size */
    bool        done;                   /* Iteration complete flag */
} CnpIter;

/* Multi-array iterator for broadcasting */
typedef struct {
    int         num_arrays;             /* Number of arrays */
    CnpArray  **arrays;                 /* Array pointers */
    CnpIter    *iters;                  /* Individual iterators */
    int         ndim;                   /* Broadcast dimensions */
    int64_t    *shape;                  /* Broadcast shape */
    int64_t     size;                   /* Total broadcast size */
    int64_t    *coordinates;            /* Current position */
    void       **data_pointers;          /* Per-instance current data pointers */
    int64_t     index;                  /* Current flat index */
    bool        done;                   /* Done flag */
} CnpMultiIter;

/* =========================================================================
 * Slice object
 * ========================================================================= */
typedef struct {
    int64_t start;
    int64_t stop;
    int64_t step;
    bool    has_start;
    bool    has_stop;
    bool    has_step;
} CnpSlice;

/* =========================================================================
 * Error handling
 * ========================================================================= */
typedef enum {
    CNP_OK = 0,
    CNP_ERR_GENERIC = -1,
    CNP_ERR_MEMORY = -2,
    CNP_ERR_TYPE = -3,
    CNP_ERR_SHAPE = -4,
    CNP_ERR_AXIS = -5,
    CNP_ERR_INDEX = -6,
    CNP_ERR_BROADCAST = -7,
    CNP_ERR_CONVERSION = -8,
    CNP_ERR_SINGULAR = -9,
    CNP_ERR_CONVERGENCE = -10,
    CNP_ERR_IO = -11,
    CNP_ERR_NOT_IMPLEMENTED = -12,
    CNP_ERR_VALUE = -13
} CNP_STATUS;

/* Error state */
typedef struct {
    CNP_STATUS  status;
    char        message[256];
    char        func[64];
} CnpErrorState;

/* =========================================================================
 * UFunc (Universal Function) structure
 * ========================================================================= */
typedef void (*CnpUFuncLoop)(char **args, int64_t *dimensions, int64_t *steps, void *funcdata);

typedef struct {
    const char *name;
    int         nin;            /* Number of inputs */
    int         nout;           /* Number of outputs */
    int         ntypes;         /* Number of type loops */
    CNP_TYPE   *types;          /* Type signature array */
    CnpUFuncLoop *loops;       /* Loop functions */
    const char *doc;
} CnpUFunc;

/* =========================================================================
 * Reduction operation types
 * ========================================================================= */
typedef enum {
    CNP_REDUCE_SUM = 0,
    CNP_REDUCE_PROD,
    CNP_REDUCE_MAX,
    CNP_REDUCE_MIN,
    CNP_REDUCE_ANY,
    CNP_REDUCE_ALL
} CNP_REDUCE_OP;

/* =========================================================================
 * Sort kinds
 * ========================================================================= */
typedef enum {
    CNP_SORT_QUICKSORT = 0,
    CNP_SORT_MERGESORT = 1,
    CNP_SORT_HEAPSORT = 2,
    CNP_SORT_STABLE = 3
} CNP_SORT_KIND;

typedef enum {
    CNP_BITORDER_BIG = 0,
    CNP_BITORDER_LITTLE = 1
} CNP_BITORDER;

/* =========================================================================
 * Random number generator state
 * ========================================================================= */
typedef struct {
    uint64_t state[4];
    int      has_gauss;
    double   gauss;
} CnpRandomState;

/* =========================================================================
 * Function declarations - Core
 * ========================================================================= */

/* Library initialization and cleanup */
CNP_API CNP_STATUS CNP_CALL cnp_init(void);
CNP_API void CNP_CALL cnp_cleanup(void);
CNP_API const char* CNP_CALL cnp_version(void);
CNP_API CNP_STATUS CNP_CALL cnp_set_num_threads(int count);
CNP_API int CNP_CALL cnp_get_num_threads(void);

/* Error handling */
CNP_API CNP_STATUS CNP_CALL cnp_get_error(CnpErrorState *state);
CNP_API void CNP_CALL cnp_clear_error(void);
CNP_API const char* CNP_CALL cnp_get_error_message(void);

/* =========================================================================
 * Function declarations - Dtype
 * ========================================================================= */
CNP_API CnpDtype* CNP_CALL cnp_dtype_new(CNP_TYPE type_num);
CNP_API CnpDtype* CNP_CALL cnp_dtype_from_char(char c);
CNP_API CnpDtype* CNP_CALL cnp_dtype_from_string(const char *name);
CNP_API void CNP_CALL cnp_dtype_incref(CnpDtype *dtype);
CNP_API void CNP_CALL cnp_dtype_decref(CnpDtype *dtype);
CNP_API int CNP_CALL cnp_dtype_itemsize(CNP_TYPE type_num);
CNP_API char CNP_CALL cnp_dtype_kind(CNP_TYPE type_num);
CNP_API bool CNP_CALL cnp_dtype_can_cast(CNP_TYPE from, CNP_TYPE to, CNP_CASTING casting);
CNP_API CNP_TYPE CNP_CALL cnp_dtype_result_type(CNP_TYPE a, CNP_TYPE b);

/* =========================================================================
 * Function declarations - Array creation and destruction
 * ========================================================================= */
CNP_API CnpArray* CNP_CALL cnp_array_new(int ndim, const int64_t *shape, CNP_TYPE dtype, CNP_ORDER order);
CNP_API CnpArray* CNP_CALL cnp_array_zeros(int ndim, const int64_t *shape, CNP_TYPE dtype, CNP_ORDER order);
CNP_API CnpArray* CNP_CALL cnp_array_ones(int ndim, const int64_t *shape, CNP_TYPE dtype, CNP_ORDER order);
CNP_API CnpArray* CNP_CALL cnp_array_empty(int ndim, const int64_t *shape, CNP_TYPE dtype, CNP_ORDER order);
CNP_API CnpArray* CNP_CALL cnp_array_full(int ndim, const int64_t *shape, double fill_value, CNP_TYPE dtype, CNP_ORDER order);
CNP_API CnpArray* CNP_CALL cnp_array_from_data(const void *data, int ndim, const int64_t *shape, CNP_TYPE dtype, CNP_ORDER order);
CNP_API CnpArray* CNP_CALL cnp_array_from_scalar(double value, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_array_copy(const CnpArray *src);
CNP_API CnpArray* CNP_CALL cnp_array_view(CnpArray *src);
CNP_API void CNP_CALL cnp_array_incref(CnpArray *arr);
CNP_API void CNP_CALL cnp_array_decref(CnpArray *arr);
CNP_API void CNP_CALL cnp_array_free(CnpArray *arr);

/* Array creation - range functions */
CNP_API CnpArray* CNP_CALL cnp_arange(double start, double stop, double step, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_linspace(double start, double stop, int64_t num, bool endpoint, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_logspace(double start, double stop, int64_t num, bool endpoint, double base, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_geomspace(double start, double stop, int64_t num, bool endpoint, CNP_TYPE dtype);

/* Array creation - special */
CNP_API CnpArray* CNP_CALL cnp_eye(int64_t n, int64_t m, int64_t k, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_identity(int64_t n, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_diag(const CnpArray *v, int64_t k);
CNP_API CnpArray* CNP_CALL cnp_tri(int64_t n, int64_t m, int64_t k, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_zeros_like(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_ones_like(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_empty_like(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_full_like(const CnpArray *arr, double fill_value);

/* =========================================================================
 * Function declarations - Array properties
 * ========================================================================= */
CNP_API int CNP_CALL cnp_array_ndim(const CnpArray *arr);
CNP_API int64_t CNP_CALL cnp_array_size(const CnpArray *arr);
CNP_API int CNP_CALL cnp_array_itemsize(const CnpArray *arr);
CNP_API int64_t CNP_CALL cnp_array_nbytes(const CnpArray *arr);
CNP_API bool CNP_CALL cnp_array_is_c_contiguous(const CnpArray *arr);
CNP_API bool CNP_CALL cnp_array_is_f_contiguous(const CnpArray *arr);
CNP_API CNP_TYPE CNP_CALL cnp_array_dtype_num(const CnpArray *arr);
CNP_API const int64_t* CNP_CALL cnp_array_shape(const CnpArray *arr);
CNP_API const int64_t* CNP_CALL cnp_array_strides(const CnpArray *arr);

/* =========================================================================
 * Function declarations - Element access
 * ========================================================================= */
CNP_API void* CNP_CALL cnp_array_at(const CnpArray *arr, const int64_t *indices);
CNP_API double CNP_CALL cnp_array_get_double(const CnpArray *arr, const int64_t *indices);
CNP_API int64_t CNP_CALL cnp_array_get_int(const CnpArray *arr, const int64_t *indices);
CNP_API CNP_STATUS CNP_CALL cnp_array_set_double(CnpArray *arr, const int64_t *indices, double value);
CNP_API CNP_STATUS CNP_CALL cnp_array_set_int(CnpArray *arr, const int64_t *indices, int64_t value);
CNP_API double CNP_CALL cnp_array_flat_get(const CnpArray *arr, int64_t flat_index);
CNP_API CNP_STATUS CNP_CALL cnp_array_flat_set(CnpArray *arr, int64_t flat_index, double value);

/* =========================================================================
 * Function declarations - Slicing and Indexing
 * ========================================================================= */
CNP_API CnpArray* CNP_CALL cnp_array_slice(CnpArray *arr, int ndim_slices, const CnpSlice *slices);
CNP_API CnpArray* CNP_CALL cnp_array_getitem(CnpArray *arr, const int64_t *indices);
CNP_API CnpArray* CNP_CALL cnp_array_take(const CnpArray *arr, const CnpArray *indices, int axis);
CNP_API CnpArray* CNP_CALL cnp_array_where(const CnpArray *condition, const CnpArray *x, const CnpArray *y);
CNP_API CnpArray* CNP_CALL cnp_array_nonzero(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_array_boolean_index(CnpArray *arr, const CnpArray *mask);
CNP_API CnpArray* CNP_CALL cnp_array_fancy_index(CnpArray *arr, const CnpArray *indices, int axis);

/* =========================================================================
 * Function declarations - Shape manipulation
 * ========================================================================= */
CNP_API CnpArray* CNP_CALL cnp_reshape(const CnpArray *arr, int ndim, const int64_t *newshape, CNP_ORDER order);
CNP_API CnpArray* CNP_CALL cnp_ravel(const CnpArray *arr, CNP_ORDER order);
CNP_API CnpArray* CNP_CALL cnp_flatten(const CnpArray *arr, CNP_ORDER order);
CNP_API CnpArray* CNP_CALL cnp_transpose(const CnpArray *arr, const int *axes);
CNP_API CnpArray* CNP_CALL cnp_swapaxes(const CnpArray *arr, int axis1, int axis2);
CNP_API CnpArray* CNP_CALL cnp_moveaxis(const CnpArray *arr, int src, int dst);
CNP_API CnpArray* CNP_CALL cnp_squeeze(const CnpArray *arr, int axis);
CNP_API CnpArray* CNP_CALL cnp_expand_dims(const CnpArray *arr, int axis);
CNP_API CnpArray* CNP_CALL cnp_broadcast_to(const CnpArray *arr, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_broadcast_arrays(int narrays, CnpArray **arrays);
CNP_API CNP_STATUS CNP_CALL cnp_broadcast_arrays_v2(
    int narrays, CnpArray *const *arrays,
    CnpArray **results, int result_capacity);

/* Joining arrays */
CNP_API CnpArray* CNP_CALL cnp_concatenate(int narrays, CnpArray **arrays, int axis);
CNP_API CnpArray* CNP_CALL cnp_stack(int narrays, CnpArray **arrays, int axis);
CNP_API CnpArray* CNP_CALL cnp_vstack(int narrays, CnpArray **arrays);
CNP_API CnpArray* CNP_CALL cnp_hstack(int narrays, CnpArray **arrays);
CNP_API CnpArray* CNP_CALL cnp_dstack(int narrays, CnpArray **arrays);
CNP_API CnpArray* CNP_CALL cnp_column_stack(int narrays, CnpArray **arrays);

/* Splitting arrays */
CNP_API CNP_STATUS CNP_CALL cnp_split_sections_v2(
    const CnpArray *arr, int sections, int axis,
    CnpArray **results, int result_capacity);
CNP_API CNP_STATUS CNP_CALL cnp_split_indices_v2(
    const CnpArray *arr, int nindices, const int64_t *indices, int axis,
    CnpArray **results, int result_capacity);
CNP_API CNP_STATUS CNP_CALL cnp_array_split_sections_v2(
    const CnpArray *arr, int sections, int axis,
    CnpArray **results, int result_capacity);
CNP_API CNP_STATUS CNP_CALL cnp_array_split_indices_v2(
    const CnpArray *arr, int nindices, const int64_t *indices, int axis,
    CnpArray **results, int result_capacity);
/* Legacy output-count ABI. A non-null indices pointer contains nsections - 1
 * boundaries; a null pointer selects equal sections. New callers use v2. */
CNP_API CNP_STATUS CNP_CALL cnp_split(const CnpArray *arr, int nsections, int64_t *indices_or_sections, int axis, CnpArray **result);
CNP_API CNP_STATUS CNP_CALL cnp_hsplit(const CnpArray *arr, int nsections, int64_t *indices_or_sections, CnpArray **result);
CNP_API CNP_STATUS CNP_CALL cnp_vsplit(const CnpArray *arr, int nsections, int64_t *indices_or_sections, CnpArray **result);

/* Tiling */
CNP_API CnpArray* CNP_CALL cnp_tile(const CnpArray *arr, int nreps, const int64_t *reps);
CNP_API CnpArray* CNP_CALL cnp_repeat(const CnpArray *arr, int64_t repeats, int axis);

/* =========================================================================
 * Function declarations - Mathematical operations (element-wise)
 * ========================================================================= */

/* Arithmetic */
CNP_API CnpArray* CNP_CALL cnp_add(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_subtract(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_multiply(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_divide(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_true_divide(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_floor_divide(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_power(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_float_power(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_mod(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_remainder(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_fmod(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_negative(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_positive(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_absolute(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_fabs(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_sign(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_reciprocal(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_sqrt(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_cbrt(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_square(const CnpArray *a);

/* Rounding */
CNP_API CnpArray* CNP_CALL cnp_ceil(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_floor(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_trunc(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_rint(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_round(const CnpArray *a, int decimals);
CNP_API CnpArray* CNP_CALL cnp_fix(const CnpArray *a);

/* Trigonometric */
CNP_API CnpArray* CNP_CALL cnp_sin(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_cos(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_tan(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_arcsin(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_arccos(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_arctan(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_arctan2(const CnpArray *y, const CnpArray *x);
CNP_API CnpArray* CNP_CALL cnp_hypot(const CnpArray *x, const CnpArray *y);
CNP_API CnpArray* CNP_CALL cnp_degrees(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_radians(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_deg2rad(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_rad2deg(const CnpArray *a);

/* Hyperbolic */
CNP_API CnpArray* CNP_CALL cnp_sinh(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_cosh(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_tanh(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_arcsinh(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_arccosh(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_arctanh(const CnpArray *a);

/* Exponential and logarithmic */
CNP_API CnpArray* CNP_CALL cnp_exp(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_exp2(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_expm1(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_log(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_log2(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_log10(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_log1p(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_logaddexp(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_logaddexp2(const CnpArray *a, const CnpArray *b);

/* Comparison (element-wise, return bool array) */
CNP_API CnpArray* CNP_CALL cnp_equal(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_not_equal(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_less(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_less_equal(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_greater(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_greater_equal(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_maximum(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_minimum(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_fmax(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_fmin(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_clip(const CnpArray *a, double min_val, double max_val);

/* Logical operations */
CNP_API CnpArray* CNP_CALL cnp_logical_and(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_logical_or(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_logical_xor(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_logical_not(const CnpArray *a);

/* Bitwise operations */
CNP_API CnpArray* CNP_CALL cnp_bitwise_and(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_bitwise_or(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_bitwise_xor(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_invert(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_left_shift(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_right_shift(const CnpArray *a, const CnpArray *b);

/* Special functions */
CNP_API CnpArray* CNP_CALL cnp_nan_to_num(const CnpArray *a, double nan_val, double posinf_val, double neginf_val);
CNP_API CnpArray* CNP_CALL cnp_isnan(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_isinf(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_isfinite(const CnpArray *a);

/* =========================================================================
 * Function declarations - Reductions
 * ========================================================================= */
CNP_API CnpArray* CNP_CALL cnp_sum(const CnpArray *arr, int axis, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_sum_v2(
    const CnpArray *arr, int axis, bool axis_none, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_prod(const CnpArray *arr, int axis, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_prod_v2(
    const CnpArray *arr, int axis, bool axis_none, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_cumsum(const CnpArray *arr, int axis, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_cumsum_v2(
    const CnpArray *arr, int axis, bool axis_none, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_cumprod(const CnpArray *arr, int axis, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_cumprod_v2(
    const CnpArray *arr, int axis, bool axis_none, CNP_TYPE dtype);
CNP_API CNP_STATUS CNP_CALL cnp_add_into(
    const CnpArray *left, const CnpArray *right, CnpArray *out);
CNP_API CNP_STATUS CNP_CALL cnp_sqrt_into(
    const CnpArray *source, CnpArray *out);
CNP_API CNP_STATUS CNP_CALL cnp_cumsum_into(
    const CnpArray *source, int axis, CnpArray *out);
CNP_API CNP_STATUS CNP_CALL cnp_sum_into_scalar(
    const CnpArray *source, double *out_value);
CNP_API CnpArray* CNP_CALL cnp_mean(const CnpArray *arr, int axis, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_mean_v2(
    const CnpArray *arr, int axis, bool axis_none, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_std(const CnpArray *arr, int axis, int ddof, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_std_v2(
    const CnpArray *arr, int axis, bool axis_none, int ddof, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_var(const CnpArray *arr, int axis, int ddof, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_var_v2(
    const CnpArray *arr, int axis, bool axis_none, int ddof, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_max(const CnpArray *arr, int axis);
CNP_API CnpArray* CNP_CALL cnp_max_v2(
    const CnpArray *arr, int axis, bool axis_none);
CNP_API CnpArray* CNP_CALL cnp_min(const CnpArray *arr, int axis);
CNP_API CnpArray* CNP_CALL cnp_min_v2(
    const CnpArray *arr, int axis, bool axis_none);
CNP_API CnpArray* CNP_CALL cnp_amax(const CnpArray *arr, int axis);
CNP_API CnpArray* CNP_CALL cnp_amin(const CnpArray *arr, int axis);
CNP_API CnpArray* CNP_CALL cnp_argmax(const CnpArray *arr, int axis);
CNP_API CnpArray* CNP_CALL cnp_argmax_v2(
    const CnpArray *arr, int axis, bool axis_none);
CNP_API CnpArray* CNP_CALL cnp_argmin(const CnpArray *arr, int axis);
CNP_API CnpArray* CNP_CALL cnp_argmin_v2(
    const CnpArray *arr, int axis, bool axis_none);
CNP_API CnpArray* CNP_CALL cnp_ptp(const CnpArray *arr, int axis);
CNP_API CnpArray* CNP_CALL cnp_ptp_v2(
    const CnpArray *arr, int axis, bool axis_none);
CNP_API CnpArray* CNP_CALL cnp_any(const CnpArray *arr, int axis);
CNP_API CnpArray* CNP_CALL cnp_any_v2(
    const CnpArray *arr, int axis, bool axis_none);
CNP_API CnpArray* CNP_CALL cnp_all(const CnpArray *arr, int axis);
CNP_API CnpArray* CNP_CALL cnp_all_v2(
    const CnpArray *arr, int axis, bool axis_none);
CNP_API CnpArray* CNP_CALL cnp_nansum(const CnpArray *arr, int axis, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_nansum_v2(
    const CnpArray *arr, int axis, bool axis_none, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_nanprod(const CnpArray *arr, int axis, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_nanprod_v2(
    const CnpArray *arr, int axis, bool axis_none, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_nanmean(const CnpArray *arr, int axis, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_nanmean_v2(
    const CnpArray *arr, int axis, bool axis_none, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_nanstd(const CnpArray *arr, int axis, int ddof, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_nanstd_v2(
    const CnpArray *arr, int axis, bool axis_none, int ddof, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_nanvar(const CnpArray *arr, int axis, int ddof, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_nanvar_v2(
    const CnpArray *arr, int axis, bool axis_none, int ddof, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_nanmax(const CnpArray *arr, int axis);
CNP_API CnpArray* CNP_CALL cnp_nanmax_v2(
    const CnpArray *arr, int axis, bool axis_none);
CNP_API CnpArray* CNP_CALL cnp_nanmin(const CnpArray *arr, int axis);
CNP_API CnpArray* CNP_CALL cnp_nanmin_v2(
    const CnpArray *arr, int axis, bool axis_none);
CNP_API CnpArray* CNP_CALL cnp_nancumsum_v2(
    const CnpArray *arr, int axis, bool axis_none, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_nancumprod_v2(
    const CnpArray *arr, int axis, bool axis_none, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_trace(const CnpArray *arr, int offset, int axis1, int axis2);
CNP_API double CNP_CALL cnp_sum_scalar(const CnpArray *arr);
CNP_API double CNP_CALL cnp_prod_scalar(const CnpArray *arr);
CNP_API double CNP_CALL cnp_mean_scalar(const CnpArray *arr);

/* =========================================================================
 * Function declarations - Linear Algebra
 * ========================================================================= */
CNP_API CnpArray* CNP_CALL cnp_dot(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_matmul(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_inner(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_outer(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_cross(const CnpArray *a, const CnpArray *b, int axis);
CNP_API CnpArray* CNP_CALL cnp_tensordot(const CnpArray *a, const CnpArray *b, int axes_a, int axes_b);
CNP_API CnpArray* CNP_CALL cnp_einsum(
    const char *subscripts, int narrays,
    const CnpArray *const *arrays);
CNP_API CnpArray* CNP_CALL cnp_linalg_inv(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_linalg_det(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_linalg_slogdet(const CnpArray *a);
CNP_API CNP_STATUS CNP_CALL cnp_linalg_slogdet_v2(
    const CnpArray *a, CnpArray **sign, CnpArray **logabsdet);
CNP_API CNP_STATUS CNP_CALL cnp_linalg_solve(const CnpArray *a, const CnpArray *b, CnpArray **result);
CNP_API CNP_STATUS CNP_CALL cnp_linalg_lstsq_v2(
    const CnpArray *a, const CnpArray *b,
    double rcond, bool rcond_none,
    CnpArray **x, CnpArray **residuals,
    CnpArray **rank, CnpArray **singular_values);
CNP_API CnpArray* CNP_CALL cnp_linalg_cond_v2(const CnpArray *a);
CNP_API CNP_STATUS CNP_CALL cnp_linalg_eig(const CnpArray *a, CnpArray **eigenvalues, CnpArray **eigenvectors);
CNP_API CNP_STATUS CNP_CALL cnp_linalg_eigh(const CnpArray *a, CnpArray **eigenvalues, CnpArray **eigenvectors);
CNP_API CNP_STATUS CNP_CALL cnp_linalg_eigh_v2(
    const CnpArray *a, bool upper,
    CnpArray **eigenvalues, CnpArray **eigenvectors);
CNP_API CNP_STATUS CNP_CALL cnp_linalg_svd(const CnpArray *a, CnpArray **u, CnpArray **s, CnpArray **vh);
CNP_API CNP_STATUS CNP_CALL cnp_linalg_svd_v2(
    const CnpArray *a, bool full_matrices, bool compute_uv, bool hermitian,
    CnpArray **u, CnpArray **s, CnpArray **vh);
CNP_API CNP_STATUS CNP_CALL cnp_linalg_qr(const CnpArray *a, CnpArray **q, CnpArray **r);
CNP_API CNP_STATUS CNP_CALL cnp_linalg_cholesky(const CnpArray *a, CnpArray **result);
CNP_API CnpArray* CNP_CALL cnp_linalg_norm(const CnpArray *a, const char *ord, int axis);
CNP_API CnpArray* CNP_CALL cnp_linalg_matrix_rank(const CnpArray *a, double tol);
CNP_API CnpArray* CNP_CALL cnp_linalg_matrix_rank_v2(
    const CnpArray *a, const CnpArray *tol, bool hermitian);
CNP_API CnpArray* CNP_CALL cnp_linalg_pinv(const CnpArray *a, double rcond);
CNP_API CnpArray* CNP_CALL cnp_linalg_matrix_power(const CnpArray *a, int64_t n);

/* =========================================================================
 * Function declarations - Sorting and Searching
 * ========================================================================= */
CNP_API CnpArray* CNP_CALL cnp_sort(const CnpArray *arr, int axis, CNP_SORT_KIND kind);
CNP_API CnpArray* CNP_CALL cnp_argsort(const CnpArray *arr, int axis, CNP_SORT_KIND kind);
CNP_API CnpArray* CNP_CALL cnp_sort_v2(
    const CnpArray *arr, int axis, bool axis_none, CNP_SORT_KIND kind);
CNP_API CnpArray* CNP_CALL cnp_argsort_v2(
    const CnpArray *arr, int axis, bool axis_none, CNP_SORT_KIND kind);
CNP_API CnpArray* CNP_CALL cnp_partition(const CnpArray *arr, int64_t kth, int axis);
CNP_API CnpArray* CNP_CALL cnp_argpartition(const CnpArray *arr, int64_t kth, int axis);
CNP_API CnpArray* CNP_CALL cnp_partition_v2(
    const CnpArray *arr, const int64_t *kth, int kth_count,
    int axis, bool axis_none);
CNP_API CnpArray* CNP_CALL cnp_argpartition_v2(
    const CnpArray *arr, const int64_t *kth, int kth_count,
    int axis, bool axis_none);
CNP_API CnpArray* CNP_CALL cnp_searchsorted(const CnpArray *arr, const CnpArray *values, const char *side);
CNP_API CnpArray* CNP_CALL cnp_searchsorted_v2(
    const CnpArray *arr, const CnpArray *values,
    const char *side, const CnpArray *sorter);
CNP_API CnpArray* CNP_CALL cnp_unique(const CnpArray *arr, bool return_index, bool return_inverse, bool return_counts);
CNP_API CNP_STATUS CNP_CALL cnp_unique_v2(
    const CnpArray *arr, bool return_index, bool return_inverse,
    bool return_counts, CnpArray **results, int result_capacity);
CNP_API CnpArray* CNP_CALL cnp_argwhere(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_flatnonzero(const CnpArray *arr);
CNP_API int64_t CNP_CALL cnp_count_nonzero(const CnpArray *arr, int axis);
CNP_API CnpArray* CNP_CALL cnp_count_nonzero_v2(
    const CnpArray *arr, int axis, bool axis_none, bool keepdims);

/* =========================================================================
 * Function declarations - Random number generation
 * ========================================================================= */
CNP_API void CNP_CALL cnp_random_seed(uint64_t seed);
CNP_API CnpArray* CNP_CALL cnp_random_random(int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_uniform(double low, double high, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_normal(double mean, double std, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_standard_normal(int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_integers(int64_t low, int64_t high, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_randint(int64_t low, int64_t high, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_binomial(int64_t n, double p, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_poisson(double lam, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_exponential(double scale, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_gamma(double shape_param, double scale, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_beta(double a, double b, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_choice(const CnpArray *a, int64_t size, bool replace, const CnpArray *p);
CNP_API CnpArray* CNP_CALL cnp_random_choice_v2(
    const CnpArray *a, int size_ndim, const int64_t *size_shape,
    bool size_none, bool replace, const CnpArray *p);
CNP_API CnpArray* CNP_CALL cnp_random_permutation(const CnpArray *arr);
CNP_API void CNP_CALL cnp_random_shuffle(CnpArray *arr);

/* =========================================================================
 * Function declarations - Statistics
 * ========================================================================= */
CNP_API CnpArray* CNP_CALL cnp_median(const CnpArray *arr, int axis);
CNP_API CnpArray* CNP_CALL cnp_median_v2(
    const CnpArray *arr, int axis, bool axis_none);
CNP_API CnpArray* CNP_CALL cnp_percentile(const CnpArray *arr, double q, int axis);
CNP_API CnpArray* CNP_CALL cnp_percentile_v2(
    const CnpArray *arr, double q, int axis, bool axis_none);
CNP_API CnpArray* CNP_CALL cnp_quantile(const CnpArray *arr, double q, int axis);
CNP_API CnpArray* CNP_CALL cnp_quantile_v2(
    const CnpArray *arr, double q, int axis, bool axis_none);
CNP_API CnpArray* CNP_CALL cnp_histogram(const CnpArray *arr, int64_t bins, double range_min, double range_max);
CNP_API CnpArray* CNP_CALL cnp_corrcoef(const CnpArray *x, const CnpArray *y);
CNP_API CnpArray* CNP_CALL cnp_cov(const CnpArray *m, const CnpArray *y, int rowvar, int ddof);
CNP_API CnpArray* CNP_CALL cnp_average(const CnpArray *arr, int axis, const CnpArray *weights);
CNP_API CnpArray* CNP_CALL cnp_average_v2(
    const CnpArray *arr, int axis, bool axis_none,
    const CnpArray *weights);
CNP_API CnpArray* CNP_CALL cnp_diff(const CnpArray *arr, int n, int axis);
CNP_API CnpArray* CNP_CALL cnp_gradient(const CnpArray *arr, int axis);
CNP_API CnpArray* CNP_CALL cnp_interp(const CnpArray *x, const CnpArray *xp, const CnpArray *fp);

/* =========================================================================
 * Function declarations - Type conversion
 * ========================================================================= */
CNP_API CnpArray* CNP_CALL cnp_astype(const CnpArray *arr, CNP_TYPE dtype, CNP_CASTING casting);
CNP_API CnpArray* CNP_CALL cnp_array_from_int_array(const int64_t *data, int64_t size);
CNP_API CnpArray* CNP_CALL cnp_array_from_double_array(const double *data, int64_t size);
CNP_API CnpArray* CNP_CALL cnp_array_from_float_array(const float *data, int64_t size);

/* =========================================================================
 * Function declarations - I/O and string conversion
 * ========================================================================= */
CNP_API CNP_STATUS CNP_CALL cnp_save(const char *filename, const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_load(const char *filename);
CNP_API CNP_STATUS CNP_CALL cnp_savetxt(const char *filename, const CnpArray *arr, const char *delimiter, const char *fmt);
CNP_API CnpArray* CNP_CALL cnp_loadtxt(const char *filename, const char *delimiter, CNP_TYPE dtype);
CNP_API char* CNP_CALL cnp_array_to_string(const CnpArray *arr, const char *fmt);
CNP_API void CNP_CALL cnp_array_print(const CnpArray *arr);
CNP_API CNP_STATUS CNP_CALL cnp_array_to_csv(const CnpArray *arr, char *buffer, size_t bufsize, const char *delimiter);

/* =========================================================================
 * Function declarations - Iterator
 * ========================================================================= */
CNP_API CnpIter* CNP_CALL cnp_iter_new(CnpArray *arr);
CNP_API bool CNP_CALL cnp_iter_next(CnpIter *iter);
CNP_API void* CNP_CALL cnp_iter_data(CnpIter *iter);
CNP_API void CNP_CALL cnp_iter_free(CnpIter *iter);
CNP_API void CNP_CALL cnp_iter_reset(CnpIter *iter);

CNP_API CnpMultiIter* CNP_CALL cnp_multi_iter_new(int narrays, CnpArray **arrays);
CNP_API bool CNP_CALL cnp_multi_iter_next(CnpMultiIter *miter);
CNP_API void** CNP_CALL cnp_multi_iter_data(CnpMultiIter *miter);
CNP_API void CNP_CALL cnp_multi_iter_free(CnpMultiIter *miter);

/* =========================================================================
 * Function declarations - Broadcasting
 * ========================================================================= */
CNP_API CNP_STATUS CNP_CALL cnp_broadcast_shapes(int narrays, const int64_t **shapes, const int *ndims, int *out_ndim, int64_t **out_shape);
CNP_API void CNP_CALL cnp_broadcast_shape_free(int64_t *shape, int ndim);
CNP_API bool CNP_CALL cnp_can_broadcast(const CnpArray *a, const CnpArray *b);

/* =========================================================================
 * Function declarations - Miscellaneous
 * ========================================================================= */
CNP_API CnpArray* CNP_CALL cnp_copy(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_meshgrid(int narrays, CnpArray **arrays, bool sparse, bool indexing_ij);
CNP_API CNP_STATUS CNP_CALL cnp_meshgrid_v2(
    int narrays, CnpArray *const *arrays,
    bool sparse, bool indexing_ij, bool copy,
    CnpArray **results, int result_capacity);
CNP_API CnpArray* CNP_CALL cnp_indices(int ndim, const int64_t *dimensions);
CNP_API CnpArray* CNP_CALL cnp_fromfunction(double (*func)(const int64_t*, int, void*), int ndim, const int64_t *shape, void *userdata);
CNP_API CnpArray* CNP_CALL cnp_fromiter(double (*iter_func)(void*), void *state, int64_t count, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_pad(const CnpArray *arr, int64_t pad_width, double constant_value);
CNP_API CnpArray* CNP_CALL cnp_flip(const CnpArray *arr, int axis);
CNP_API CnpArray* CNP_CALL cnp_rot90(const CnpArray *arr, int k, int axis1, int axis2);
CNP_API CnpArray* CNP_CALL cnp_roll(const CnpArray *arr, int64_t shift, int axis);
CNP_API CnpArray* CNP_CALL cnp_delete(const CnpArray *arr, const CnpArray *obj, int axis);
CNP_API CnpArray* CNP_CALL cnp_insert(CnpArray *arr, int64_t obj, const CnpArray *values, int axis);
CNP_API CnpArray* CNP_CALL cnp_append(const CnpArray *arr, const CnpArray *values, int axis);

/* Memory info */
CNP_API size_t CNP_CALL cnp_get_allocated_memory(void);

/* =========================================================================
 * Function declarations - Polynomial operations
 * ========================================================================= */
CNP_API CnpArray* CNP_CALL cnp_polyval(const CnpArray *p, const CnpArray *x);
CNP_API CnpArray* CNP_CALL cnp_polyder(const CnpArray *p, int m);
CNP_API CnpArray* CNP_CALL cnp_polyint(const CnpArray *p, int m, const CnpArray *k);
CNP_API CnpArray* CNP_CALL cnp_polyadd(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_polysub(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_polymul(const CnpArray *a, const CnpArray *b);
CNP_API CNP_STATUS CNP_CALL cnp_polydiv(const CnpArray *a, const CnpArray *b, CnpArray **quotient, CnpArray **remainder);
CNP_API CnpArray* CNP_CALL cnp_polyfit(const CnpArray *x, const CnpArray *y, int deg);
CNP_API CnpArray* CNP_CALL cnp_poly(const CnpArray *roots);
CNP_API CnpArray* CNP_CALL cnp_polyroots(const CnpArray *p);

/* =========================================================================
 * Function declarations - FFT (Fast Fourier Transform)
 * ========================================================================= */
CNP_API CnpArray* CNP_CALL cnp_fft(const CnpArray *a, int64_t n);
CNP_API CnpArray* CNP_CALL cnp_ifft(const CnpArray *a, int64_t n);
CNP_API CnpArray* CNP_CALL cnp_rfft(const CnpArray *a, int64_t n);
CNP_API CnpArray* CNP_CALL cnp_irfft(const CnpArray *a, int64_t n);
CNP_API CnpArray* CNP_CALL cnp_fft2(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_ifft2(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_fftfreq(int64_t n, double d);
CNP_API CnpArray* CNP_CALL cnp_rfftfreq(int64_t n, double d);
CNP_API CnpArray* CNP_CALL cnp_fftshift(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_ifftshift(const CnpArray *a);

/* =========================================================================
 * Function declarations - Set operations
 * ========================================================================= */
CNP_API CnpArray* CNP_CALL cnp_intersect1d(const CnpArray *ar1, const CnpArray *ar2, bool assume_unique);
CNP_API CnpArray* CNP_CALL cnp_union1d(const CnpArray *ar1, const CnpArray *ar2);
CNP_API CnpArray* CNP_CALL cnp_setdiff1d(const CnpArray *ar1, const CnpArray *ar2, bool assume_unique);
CNP_API CnpArray* CNP_CALL cnp_setxor1d(const CnpArray *ar1, const CnpArray *ar2, bool assume_unique);
CNP_API CnpArray* CNP_CALL cnp_in1d(const CnpArray *ar1, const CnpArray *ar2, bool assume_unique, bool invert);
CNP_API CnpArray* CNP_CALL cnp_isin(const CnpArray *element, const CnpArray *test_elements, bool assume_unique, bool invert);

/* =========================================================================
 * Function declarations - Extra utility functions
 * ========================================================================= */
CNP_API CnpArray* CNP_CALL cnp_vander(const CnpArray *x, int64_t N, bool increasing);
CNP_API CnpArray* CNP_CALL cnp_digitize(const CnpArray *x, const CnpArray *bins, bool right);
CNP_API CnpArray* CNP_CALL cnp_bincount(const CnpArray *x, const CnpArray *weights, int64_t minlength);
CNP_API CnpArray* CNP_CALL cnp_select(int nconditions, const CnpArray **condlist, const CnpArray **choicelist, double default_val);
CNP_API CnpArray* CNP_CALL cnp_piecewise(const CnpArray *x, int nconditions, const CnpArray **condlist, double (*func)(double, void*), void *userdata);
CNP_API CnpArray* CNP_CALL cnp_unravel_index(const CnpArray *indices, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_ravel_multi_index(const CnpArray *multi_index, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_triu_indices(int64_t n, int64_t k, int64_t m);
CNP_API CnpArray* CNP_CALL cnp_tril_indices(int64_t n, int64_t k, int64_t m);
CNP_API CnpArray* CNP_CALL cnp_ediff1d(const CnpArray *arr, double to_begin, double to_end, bool has_begin, bool has_end);
CNP_API CnpArray* CNP_CALL cnp_trapz(const CnpArray *y, const CnpArray *x, double dx, int axis);
CNP_API CnpArray* CNP_CALL cnp_sinc(const CnpArray *x);
CNP_API CnpArray* CNP_CALL cnp_angle(const CnpArray *z, bool deg);
CNP_API CnpArray* CNP_CALL cnp_real(const CnpArray *z);
CNP_API CnpArray* CNP_CALL cnp_imag(const CnpArray *z);
CNP_API CnpArray* CNP_CALL cnp_convolve(const CnpArray *a, const CnpArray *v, int mode);
CNP_API CnpArray* CNP_CALL cnp_correlate(const CnpArray *a, const CnpArray *v, int mode);

/* =========================================================================
 * Function declarations - String operations (char module)
 * ========================================================================= */
CNP_API CnpArray* CNP_CALL cnp_char_add(const char **a, int64_t na, const char **b, int64_t nb);
CNP_API CnpArray* CNP_CALL cnp_char_multiply(const char **a, int64_t na, const int64_t *repeats, int64_t nr);
CNP_API CnpArray* CNP_CALL cnp_char_upper(const char **a, int64_t n);
CNP_API CnpArray* CNP_CALL cnp_char_lower(const char **a, int64_t n);
CNP_API CnpArray* CNP_CALL cnp_char_strip(const char **a, int64_t n, const char *chars);
CNP_API CnpArray* CNP_CALL cnp_char_lstrip(const char **a, int64_t n, const char *chars);
CNP_API CnpArray* CNP_CALL cnp_char_rstrip(const char **a, int64_t n, const char *chars);
CNP_API CnpArray* CNP_CALL cnp_char_center(const char **a, int64_t n, int64_t width, char fillchar);
CNP_API CnpArray* CNP_CALL cnp_char_ljust(const char **a, int64_t n, int64_t width, char fillchar);
CNP_API CnpArray* CNP_CALL cnp_char_rjust(const char **a, int64_t n, int64_t width, char fillchar);
CNP_API CnpArray* CNP_CALL cnp_char_zfill(const char **a, int64_t n, int64_t width);
CNP_API CnpArray* CNP_CALL cnp_char_strlen(const char **a, int64_t n);
CNP_API CnpArray* CNP_CALL cnp_char_count(const char **a, int64_t n, const char *sub);
CNP_API CnpArray* CNP_CALL cnp_char_find(const char **a, int64_t n, const char *sub);
CNP_API CnpArray* CNP_CALL cnp_char_replace(const char **a, int64_t n, const char *old_str, const char *new_str, int64_t count);
CNP_API CnpArray* CNP_CALL cnp_char_split(const char **a, int64_t n, const char *sep);
CNP_API CnpStringListResult* CNP_CALL cnp_char_split_v2(
    const char **a, int64_t n, const char *sep, int64_t maxsplit);
CNP_API int64_t CNP_CALL cnp_string_list_outer_count(
    const CnpStringListResult *result);
CNP_API int64_t CNP_CALL cnp_string_list_token_count(
    const CnpStringListResult *result, int64_t row);
CNP_API const char* CNP_CALL cnp_string_list_get(
    const CnpStringListResult *result, int64_t row, int64_t token);
CNP_API void CNP_CALL cnp_string_list_free(CnpStringListResult *result);
CNP_API char* CNP_CALL cnp_char_join(const char **a, int64_t n, const char *sep);
CNP_API CnpArray* CNP_CALL cnp_char_join_v2(const char **a, int64_t n, const char *sep);
CNP_API void CNP_CALL cnp_char_free_result(CnpArray *arr);
CNP_API void CNP_CALL cnp_char_free_string(char *str);

/* =========================================================================
 * Function declarations - Special math functions
 * ========================================================================= */
CNP_API CnpArray* CNP_CALL cnp_gamma(const CnpArray *x);
CNP_API CnpArray* CNP_CALL cnp_gammaln(const CnpArray *x);
CNP_API CnpArray* CNP_CALL cnp_beta(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_erf(const CnpArray *x);
CNP_API CnpArray* CNP_CALL cnp_erfc(const CnpArray *x);
CNP_API CnpArray* CNP_CALL cnp_erfinv(const CnpArray *x);
CNP_API CnpArray* CNP_CALL cnp_factorial(const CnpArray *x, bool exact);
CNP_API CnpArray* CNP_CALL cnp_comb(const CnpArray *n, const CnpArray *k, bool exact);
CNP_API CnpArray* CNP_CALL cnp_perm(const CnpArray *n, const CnpArray *k, bool exact);
CNP_API CnpArray* CNP_CALL cnp_i0(const CnpArray *x);
CNP_API CnpArray* CNP_CALL cnp_j0(const CnpArray *x);
CNP_API CnpArray* CNP_CALL cnp_j1(const CnpArray *x);
CNP_API CnpArray* CNP_CALL cnp_digamma(const CnpArray *x);
CNP_API CnpArray* CNP_CALL cnp_zeta(const CnpArray *x);
CNP_API CnpArray* CNP_CALL cnp_expit(const CnpArray *x);
CNP_API CnpArray* CNP_CALL cnp_logit(const CnpArray *x);
CNP_API CnpArray* CNP_CALL cnp_softmax(const CnpArray *x, int axis);
CNP_API CnpArray* CNP_CALL cnp_log_softmax(const CnpArray *x, int axis);

/* =========================================================================
 * Function declarations - Structured arrays
 * ========================================================================= */
CNP_API int CNP_CALL cnp_struct_dtype_create(const char **names, const CNP_TYPE *types, int nfields);
CNP_API int64_t CNP_CALL cnp_struct_dtype_itemsize(int dtype_id);
CNP_API int CNP_CALL cnp_struct_dtype_nfields(int dtype_id);
CNP_API const char* CNP_CALL cnp_struct_dtype_field_name(int dtype_id, int field_idx);
CNP_API int64_t CNP_CALL cnp_struct_dtype_field_offset(int dtype_id, int field_idx);
CNP_API int CNP_CALL cnp_struct_dtype_find_field(int dtype_id, const char *name);
CNP_API CnpArray* CNP_CALL cnp_recarray_new(int ndim, const int64_t *shape, int struct_dtype_id);
CNP_API CnpArray* CNP_CALL cnp_recarray_get_field(const CnpArray *arr, const char *field_name, int struct_dtype_id);
CNP_API CNP_STATUS CNP_CALL cnp_recarray_set_field(CnpArray *arr, const char *field_name, int struct_dtype_id, const CnpArray *values);
CNP_API CnpArray* CNP_CALL cnp_recarray_get_record(const CnpArray *arr, int64_t index, int struct_dtype_id);
CNP_API CNP_STATUS CNP_CALL cnp_recarray_set_record(CnpArray *arr, int64_t index, int struct_dtype_id, const CnpArray *values);
CNP_API char* CNP_CALL cnp_recarray_names(int struct_dtype_id);

/* =========================================================================
 * Function declarations - Memory-mapped files
 * ========================================================================= */
CNP_API CnpArray* CNP_CALL cnp_memmap_create(const char *filename, int ndim, const int64_t *shape, CNP_TYPE dtype, int mode, int64_t offset);
CNP_API CnpArray* CNP_CALL cnp_memmap_open(const char *filename, int ndim, const int64_t *shape, CNP_TYPE dtype, int64_t offset);
CNP_API CNP_STATUS CNP_CALL cnp_memmap_flush(const CnpArray *arr);
CNP_API void CNP_CALL cnp_memmap_close(CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_fromfile(const char *filename, CNP_TYPE dtype, int64_t count, int64_t offset);
CNP_API CNP_STATUS CNP_CALL cnp_tofile(const CnpArray *arr, const char *filename);
CNP_API CnpArray* CNP_CALL cnp_frombuffer(const void *buffer, int64_t size, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_fromstring(const char *str, int64_t len, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_fromstring_v2(
    const char *str, int64_t len, CNP_TYPE dtype,
    int64_t count, const char *sep);

/* =========================================================================
 * Function declarations - Window functions
 * ========================================================================= */
CNP_API CnpArray* CNP_CALL cnp_bartlett(int64_t M);
CNP_API CnpArray* CNP_CALL cnp_blackman(int64_t M);
CNP_API CnpArray* CNP_CALL cnp_hamming(int64_t M);
CNP_API CnpArray* CNP_CALL cnp_hanning(int64_t M);
CNP_API CnpArray* CNP_CALL cnp_kaiser(int64_t M, double beta);

/* =========================================================================
 * Function declarations - Array manipulation
 * ========================================================================= */
CNP_API CnpArray* CNP_CALL cnp_tile(const CnpArray *arr, int ndim_reps, const int64_t *reps);
CNP_API CnpArray* CNP_CALL cnp_repeat(const CnpArray *arr, int64_t repeats, int axis);
CNP_API CNP_STATUS CNP_CALL cnp_place(CnpArray *arr, const CnpArray *mask, const CnpArray *values);
CNP_API CNP_STATUS CNP_CALL cnp_put(CnpArray *arr, const CnpArray *indices, const CnpArray *values, const char *mode);
CNP_API CnpArray* CNP_CALL cnp_take(const CnpArray *arr, const CnpArray *indices, int axis);
CNP_API CnpArray* CNP_CALL cnp_compress(const CnpArray *condition, const CnpArray *arr, int axis);
CNP_API CnpArray* CNP_CALL cnp_take_v2(
    const CnpArray *arr, const CnpArray *indices, int axis, bool axis_none);
CNP_API CnpArray* CNP_CALL cnp_take_along_axis_v2(
    const CnpArray *arr, const CnpArray *indices, int axis, bool axis_none);
CNP_API CnpArray* CNP_CALL cnp_compress_v2(
    const CnpArray *condition, const CnpArray *arr, int axis, bool axis_none);
CNP_API CnpArray* CNP_CALL cnp_delete_v2(
    const CnpArray *arr, const CnpArray *obj, int axis, bool axis_none);
CNP_API CnpArray* CNP_CALL cnp_insert_v2(
    const CnpArray *arr, int64_t obj, const CnpArray *values,
    int axis, bool axis_none);
CNP_API CnpArray* CNP_CALL cnp_insert_array_v2(
    const CnpArray *arr, const CnpArray *obj, const CnpArray *values,
    int axis, bool axis_none);
CNP_API CnpArray* CNP_CALL cnp_choose(const CnpArray *indices, int nchoices, const CnpArray **choices);

/* =========================================================================
 * Function declarations - Financial functions
 * ========================================================================= */
CNP_API double CNP_CALL cnp_fv(double rate, int64_t nper, double pmt, double pv, int when);
CNP_API double CNP_CALL cnp_pv(double rate, int64_t nper, double pmt, double fv_val, int when);
CNP_API double CNP_CALL cnp_pmt(double rate, int64_t nper, double pv_val, double fv_val, int when);
CNP_API double CNP_CALL cnp_nper(double rate, double pmt, double pv_val, double fv_val, int when);
CNP_API double CNP_CALL cnp_rate(int64_t nper, double pmt, double pv_val, double fv_val, int when);
CNP_API double CNP_CALL cnp_npv(double rate, const double *values, int64_t n);
CNP_API double CNP_CALL cnp_irr(const double *values, int64_t n);

/* =========================================================================
 * Function declarations - Masked arrays
 * ========================================================================= */
typedef struct { CnpArray *data; CnpArray *mask; double fill_value; } CnpMaskedArray;
CNP_API CnpMaskedArray* CNP_CALL cnp_masked_array_create(const CnpArray *data, const CnpArray *mask, double fill_value);
CNP_API void CNP_CALL cnp_masked_array_free(CnpMaskedArray *ma);
CNP_API CnpArray* CNP_CALL cnp_masked_array_get_data(const CnpMaskedArray *ma);
CNP_API CnpArray* CNP_CALL cnp_masked_array_get_mask(const CnpMaskedArray *ma);
CNP_API CNP_STATUS CNP_CALL cnp_masked_array_set_mask(CnpMaskedArray *ma, const CnpArray *mask);
CNP_API CnpArray* CNP_CALL cnp_masked_array_filled(const CnpMaskedArray *ma, double fill_value);
CNP_API CnpArray* CNP_CALL cnp_masked_array_compressed(const CnpMaskedArray *ma);
CNP_API int64_t CNP_CALL cnp_masked_array_count(const CnpMaskedArray *ma);
CNP_API double CNP_CALL cnp_masked_array_sum(const CnpMaskedArray *ma);
CNP_API double CNP_CALL cnp_masked_array_mean(const CnpMaskedArray *ma);
CNP_API double CNP_CALL cnp_masked_array_std(const CnpMaskedArray *ma);
CNP_API double CNP_CALL cnp_masked_array_min(const CnpMaskedArray *ma);
CNP_API double CNP_CALL cnp_masked_array_max(const CnpMaskedArray *ma);
CNP_API CnpMaskedArray* CNP_CALL cnp_masked_where(const CnpArray *condition, const CnpArray *data, double fill_value);
CNP_API CnpMaskedArray* CNP_CALL cnp_masked_invalid(const CnpArray *data, double fill_value);
CNP_API CnpMaskedArray* CNP_CALL cnp_masked_greater(const CnpArray *data, double value, double fill_value);
CNP_API CnpMaskedArray* CNP_CALL cnp_masked_less(const CnpArray *data, double value, double fill_value);
CNP_API CnpMaskedArray* CNP_CALL cnp_masked_equal(const CnpArray *data, double value, double fill_value);
CNP_API CnpMaskedArray* CNP_CALL cnp_masked_not_equal(const CnpArray *data, double value, double fill_value);
CNP_API CnpMaskedArray* CNP_CALL cnp_masked_inside(const CnpArray *data, double v1, double v2, double fill_value);
CNP_API CnpMaskedArray* CNP_CALL cnp_masked_outside(const CnpArray *data, double v1, double v2, double fill_value);

/* =========================================================================
 * Function declarations - Additional I/O
 * ========================================================================= */
CNP_API CNP_STATUS CNP_CALL cnp_savez(const char *filename, int narrays, const char **names, const CnpArray **arrays);
CNP_API int CNP_CALL cnp_loadz(const char *filename, char names[][64], CnpArray **arrays, int max_arrays);
CNP_API CnpArray* CNP_CALL cnp_genfromtxt(const char *filename, const char *delimiter, int skip_header, int max_rows, CNP_TYPE dtype);
CNP_API CnpArray* CNP_CALL cnp_recfromtxt(const char *filename, const char *delimiter, int skip_header, CNP_TYPE dtype);
CNP_API CNP_STATUS CNP_CALL cnp_savez_auto(const char *filename, int narrays, const CnpArray **arrays);
CNP_API CnpArray* CNP_CALL cnp_packbits(const CnpArray *arr, int axis);
CNP_API CnpArray* CNP_CALL cnp_packbits_v2(
    const CnpArray *arr, int axis, bool axis_none, CNP_BITORDER bitorder);
CNP_API CnpArray* CNP_CALL cnp_unpackbits(const CnpArray *arr, int axis, int64_t count);
CNP_API CnpArray* CNP_CALL cnp_unpackbits_v2(
    const CnpArray *arr, int axis, bool axis_none,
    int64_t count, bool count_none, CNP_BITORDER bitorder);
CNP_API char* CNP_CALL cnp_base_repr(int64_t number, int base, int padding);
CNP_API char* CNP_CALL cnp_binary_repr(int64_t number, int width);

/* =========================================================================
 * Function declarations - Universal functions (ufunc)
 * ========================================================================= */
/* Bitwise */
CNP_API CnpArray* CNP_CALL cnp_bitwise_and(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_bitwise_or(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_bitwise_xor(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_bitwise_not(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_left_shift(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_right_shift(const CnpArray *a, const CnpArray *b);
/* Comparison */
CNP_API CnpArray* CNP_CALL cnp_greater(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_greater_equal(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_less(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_less_equal(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_equal(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_not_equal(const CnpArray *a, const CnpArray *b);
/* Logical */
CNP_API CnpArray* CNP_CALL cnp_logical_and(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_logical_or(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_logical_xor(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_logical_not(const CnpArray *a);
/* Trigonometric */
CNP_API CnpArray* CNP_CALL cnp_arcsin(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_arccos(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_arctan(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_arctan2(const CnpArray *y, const CnpArray *x);
CNP_API CnpArray* CNP_CALL cnp_hypot(const CnpArray *x, const CnpArray *y);
CNP_API CnpArray* CNP_CALL cnp_sinh(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_cosh(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_tanh(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_arcsinh(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_arccosh(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_arctanh(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_deg2rad(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_rad2deg(const CnpArray *a);
/* Rounding */
CNP_API CnpArray* CNP_CALL cnp_rint(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_fix(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_trunc(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_floor(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_ceil(const CnpArray *a);
/* Arithmetic */
CNP_API CnpArray* CNP_CALL cnp_floor_divide(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_true_divide(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_remainder(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_fmod(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_power(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_float_power(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_copysign(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_nextafter(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_ldexp(const CnpArray *a, const CnpArray *b);
/* Min/Max ufuncs */
CNP_API CnpArray* CNP_CALL cnp_maximum(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_minimum(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_fmax(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_fmin(const CnpArray *a, const CnpArray *b);
/* Unary math */
CNP_API CnpArray* CNP_CALL cnp_absolute(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_fabs(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_sqrt(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_cbrt(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_square(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_reciprocal(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_sign(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_negative(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_positive(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_exp2(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_expm1(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_log2(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_log10(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_log1p(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_logaddexp(const CnpArray *a, const CnpArray *b);
/* Clip and predicates */
CNP_API CnpArray* CNP_CALL cnp_clip(const CnpArray *a, double a_min, double a_max);
CNP_API CnpArray* CNP_CALL cnp_isnan(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_isinf(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_isfinite(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_where(const CnpArray *condition, const CnpArray *x, const CnpArray *y);
CNP_API CNP_STATUS CNP_CALL cnp_modf(const CnpArray *a, CnpArray **frac, CnpArray **integ);
CNP_API CNP_STATUS CNP_CALL cnp_frexp(const CnpArray *a, CnpArray **mant, CnpArray **exp_out);

/* =========================================================================
 * Function declarations - Stride tricks and array manipulation
 * ========================================================================= */
CNP_API CnpArray* CNP_CALL cnp_as_strided(const CnpArray *arr, int ndim, const int64_t *shape, const int64_t *strides);
CNP_API CnpArray* CNP_CALL cnp_sliding_window_view(const CnpArray *arr, int64_t window_size, int axis);
CNP_API CnpArray* CNP_CALL cnp_broadcast_to(const CnpArray *arr, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_diagonal(const CnpArray *arr, int offset, int axis1, int axis2);
CNP_API CNP_STATUS CNP_CALL cnp_fill_diagonal(CnpArray *arr, double val);
CNP_API CnpArray* CNP_CALL cnp_extract(const CnpArray *condition, const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_nonzero(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_apply_along_axis(double (*func)(const double*, int64_t, void*), int axis, const CnpArray *arr, void *userdata);
CNP_API CnpArray* CNP_CALL cnp_apply_over_axes(double (*func)(const double*, int64_t, void*), int naxes, const int *axes, const CnpArray *arr, void *userdata);
CNP_API CnpArray* CNP_CALL cnp_frompyfunc(double (*func)(double, void*), const CnpArray *arr, void *userdata);
CNP_API CnpArray* CNP_CALL cnp_vectorize(double (*func)(double, void*), const CnpArray *arr, void *userdata);
CNP_API CnpArray* CNP_CALL cnp_trim_zeros(const CnpArray *arr, const char *trim);
CNP_API CnpArray* CNP_CALL cnp_swapaxes(const CnpArray *arr, int axis1, int axis2);
CNP_API CnpArray* CNP_CALL cnp_moveaxis(const CnpArray *arr, int source, int destination);
CNP_API CnpArray* CNP_CALL cnp_rollaxis(const CnpArray *arr, int axis, int start);

/* =========================================================================
 * Function declarations - Extended linear algebra
 * ========================================================================= */
CNP_API double CNP_CALL cnp_linalg_norm_ext(const CnpArray *a, double ord, int axis);
CNP_API double CNP_CALL cnp_linalg_cond(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_linalg_tensorinv(const CnpArray *a, int ind);
CNP_API CnpArray* CNP_CALL cnp_linalg_tensorsolve(const CnpArray *a, const CnpArray *b, int *axes);
CNP_API CnpArray* CNP_CALL cnp_linalg_tensorsolve_v2(
    const CnpArray *a, const CnpArray *b,
    int naxes, const int *axes);
CNP_API CnpArray* CNP_CALL cnp_kron(const CnpArray *a, const CnpArray *b);

/* =========================================================================
 * Function declarations - Datetime support
 * ========================================================================= */
typedef enum {
    CNP_FR_Y = 0, CNP_FR_M = 1, CNP_FR_W = 2, CNP_FR_D = 3,
    CNP_FR_h = 4, CNP_FR_m = 5, CNP_FR_s = 6, CNP_FR_ms = 7,
    CNP_FR_us = 8, CNP_FR_ns = 9, CNP_FR_ps = 10, CNP_FR_fs = 11, CNP_FR_as = 12
} CNP_DATETIME_UNIT;

CNP_API int64_t CNP_CALL cnp_datetime64_from_date(int64_t year, int month, int day, CNP_DATETIME_UNIT unit);
CNP_API int64_t CNP_CALL cnp_datetime64_from_time(int64_t year, int month, int day, int hour, int minute, int second, CNP_DATETIME_UNIT unit);
CNP_API int64_t CNP_CALL cnp_datetime64_now(CNP_DATETIME_UNIT unit);
CNP_API void CNP_CALL cnp_datetime64_to_date(int64_t dt, CNP_DATETIME_UNIT unit, int64_t *year, int *month, int *day);
CNP_API void CNP_CALL cnp_datetime64_to_time(int64_t dt, CNP_DATETIME_UNIT unit, int *hour, int *minute, int *second);
CNP_API char* CNP_CALL cnp_datetime64_to_string(int64_t dt, CNP_DATETIME_UNIT unit);
CNP_API int64_t CNP_CALL cnp_datetime64_from_string(const char *str, CNP_DATETIME_UNIT unit);
CNP_API int64_t CNP_CALL cnp_timedelta64_create(int64_t value, CNP_DATETIME_UNIT unit);
CNP_API int64_t CNP_CALL cnp_datetime64_add(int64_t dt, int64_t delta, CNP_DATETIME_UNIT unit);
CNP_API int64_t CNP_CALL cnp_datetime64_subtract(int64_t dt1, int64_t dt2, CNP_DATETIME_UNIT unit);
CNP_API int CNP_CALL cnp_datetime64_compare(int64_t dt1, int64_t dt2);
CNP_API bool CNP_CALL cnp_is_busday(int64_t dt);
CNP_API int64_t CNP_CALL cnp_busday_count(int64_t start, int64_t end);
CNP_API int64_t CNP_CALL cnp_busday_offset(int64_t dt, int64_t offset);
CNP_API const char* CNP_CALL cnp_datetime_unit_name(CNP_DATETIME_UNIT unit);
CNP_API CnpArray* CNP_CALL cnp_datetime64_array_create(int ndim, const int64_t *shape, const int64_t *values, CNP_DATETIME_UNIT unit);
CNP_API CnpArray* CNP_CALL cnp_arange_datetime(int64_t start, int64_t stop, int64_t step, CNP_DATETIME_UNIT unit);

/* =========================================================================
 * Function declarations - Advanced array operations (unique)
 * Note: outer/inner/matmul/einsum/tensordot already declared above (linalg)
 *       linspace/logspace/geomspace/eye/identity/tri already declared above (array)
 *       cumsum/cumprod already declared above (reduce)
 *       nan_to_num already declared above (math_ops)
 *       trapz/ediff1d (extra.c), diff/gradient (stats.c)
 *       meshgrid/indices/fromfunction (io.c)
 * ========================================================================= */
CNP_API double CNP_CALL cnp_vdot(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_tensordot_default(const CnpArray *a, const CnpArray *b, int axes);
CNP_API CnpArray* CNP_CALL cnp_dot_general(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_tril(const CnpArray *arr, int k);
CNP_API CnpArray* CNP_CALL cnp_triu(const CnpArray *arr, int k);
CNP_API CnpArray* CNP_CALL cnp_nancumsum(const CnpArray *arr, int axis);
CNP_API CnpArray* CNP_CALL cnp_nancumprod(const CnpArray *arr, int axis);
CNP_API CnpArray* CNP_CALL cnp_interp_nd(const CnpArray *x, const CnpArray *xp, const CnpArray *fp, double left, double right);
CNP_API CnpArray* CNP_CALL cnp_dot_1d(const CnpArray *a, const CnpArray *b);
CNP_API double CNP_CALL cnp_trace_ext(const CnpArray *arr, int offset);
CNP_API CnpArray* CNP_CALL cnp_einsum_matmul(const CnpArray *a, const CnpArray *b);
CNP_API double CNP_CALL cnp_einsum_dot(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_einsum_outer(const CnpArray *a, const CnpArray *b);
CNP_API double CNP_CALL cnp_einsum_trace(const CnpArray *arr);
CNP_API double CNP_CALL cnp_einsum_sum(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_einsum_diag(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_einsum_transpose(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_einsum_matvec(const CnpArray *a, const CnpArray *b);

/* =========================================================================
 * Function declarations - Type conversion and extended operations
 * Note: can_cast -> use cnp_dtype_can_cast (core.c)
 *       rint/fix already in math_ops.c
 *       matrix_power -> cnp_linalg_matrix_power (linalg.c)
 * ========================================================================= */
CNP_API CNP_TYPE CNP_CALL cnp_promote_types_public(CNP_TYPE type1, CNP_TYPE type2);
CNP_API CNP_TYPE CNP_CALL cnp_result_type(int narrays, const CnpArray **arrays);
CNP_API CNP_STATUS CNP_CALL cnp_copyto(CnpArray *dst, const CnpArray *src, CNP_CASTING casting);
CNP_API CnpArray* CNP_CALL cnp_where(const CnpArray *condition, const CnpArray *x, const CnpArray *y);
CNP_API CnpArray* CNP_CALL cnp_where_indices(const CnpArray *condition);
CNP_API CNP_STATUS CNP_CALL cnp_where_indices_v2(
    const CnpArray *condition, CnpArray **results, int result_capacity);
CNP_API CnpArray* CNP_CALL cnp_matrix_power(const CnpArray *a, int n);
CNP_API int CNP_CALL cnp_matrix_rank(const CnpArray *a, double tol);
CNP_API double CNP_CALL cnp_nanmedian(const CnpArray *arr, int axis);
CNP_API CnpArray* CNP_CALL cnp_nanmedian_v2(
    const CnpArray *arr, int axis, bool axis_none);
CNP_API double CNP_CALL cnp_nanpercentile(const CnpArray *arr, double q, int axis);
CNP_API CnpArray* CNP_CALL cnp_nanpercentile_v2(
    const CnpArray *arr, double q, int axis, bool axis_none);
CNP_API CnpArray* CNP_CALL cnp_nextafter(const CnpArray *x1, const CnpArray *x2);
CNP_API CnpArray* CNP_CALL cnp_spacing(const CnpArray *x);
CNP_API CnpArray* CNP_CALL cnp_copysign(const CnpArray *x1, const CnpArray *x2);
CNP_API CNP_STATUS CNP_CALL cnp_frexp(const CnpArray *x, CnpArray **mantissa, CnpArray **exponent);
CNP_API CnpArray* CNP_CALL cnp_ldexp(const CnpArray *x1, const CnpArray *x2);
CNP_API CNP_STATUS CNP_CALL cnp_modf(const CnpArray *x, CnpArray **frac, CnpArray **integ);
CNP_API double CNP_CALL cnp_finfo_eps(CNP_TYPE dtype);
CNP_API double CNP_CALL cnp_finfo_max(CNP_TYPE dtype);
CNP_API double CNP_CALL cnp_finfo_min(CNP_TYPE dtype);
/* Legacy signed-return accessors; uint64 maximum sets CNP_ERR_CONVERSION. */
CNP_API int64_t CNP_CALL cnp_iinfo_max(CNP_TYPE dtype);
CNP_API int64_t CNP_CALL cnp_iinfo_min(CNP_TYPE dtype);
/* Exact bounds use a signed minimum and an unsigned maximum. */
CNP_API CNP_STATUS CNP_CALL cnp_iinfo_v2(
    CNP_TYPE dtype, int64_t *minimum, uint64_t *maximum);
CNP_API CnpArray* CNP_CALL cnp_clip_array(const CnpArray *arr, const CnpArray *a_min, const CnpArray *a_max);
CNP_API CnpArray* CNP_CALL cnp_around(const CnpArray *arr, int decimals);

/* =========================================================================
 * Function declarations - Additional array operations
 * ========================================================================= */
CNP_API CnpArray* CNP_CALL cnp_atleast_1d(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_atleast_2d(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_atleast_3d(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_fliplr(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_flipud(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_conj(const CnpArray *arr);
CNP_API bool CNP_CALL cnp_allclose(const CnpArray *a, const CnpArray *b, double rtol, double atol);
CNP_API CNP_STATUS CNP_CALL cnp_allclose_v2(
    const CnpArray *a, const CnpArray *b,
    double rtol, double atol, bool equal_nan, bool *result);
CNP_API CnpArray* CNP_CALL cnp_isclose(const CnpArray *a, const CnpArray *b, double rtol, double atol);
CNP_API bool CNP_CALL cnp_array_equal(const CnpArray *a, const CnpArray *b);
CNP_API bool CNP_CALL cnp_array_equiv(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_lexsort(int nkeys, const CnpArray **keys);
CNP_API CnpArray* CNP_CALL cnp_lexsort_v2(
    int nkeys, const CnpArray **keys, int axis);
CNP_API CnpArray* CNP_CALL cnp_pinv(const CnpArray *a, double rcond);
CNP_API CnpArray* CNP_CALL cnp_lstsq(const CnpArray *a, const CnpArray *b, double rcond);
CNP_API CNP_STATUS CNP_CALL cnp_slogdet(const CnpArray *a, double *sign, double *logdet);
CNP_API CnpArray* CNP_CALL cnp_multi_dot(int narrays, const CnpArray **arrays);
CNP_API bool CNP_CALL cnp_shares_memory(const CnpArray *a, const CnpArray *b);
CNP_API bool CNP_CALL cnp_may_share_memory(const CnpArray *a, const CnpArray *b);
CNP_API CnpArray* CNP_CALL cnp_msort(const CnpArray *arr);

/* =========================================================================
 * Function declarations - Remaining math and array functions
 * ========================================================================= */
CNP_API CnpArray* CNP_CALL cnp_heaviside(const CnpArray *x1, const CnpArray *x2);
CNP_API CnpArray* CNP_CALL cnp_signbit(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_unwrap(const CnpArray *p, double discont);
CNP_API CNP_STATUS CNP_CALL cnp_dsplit(const CnpArray *arr, int nsections, int64_t *indices_or_sections, CnpArray **result);
CNP_API CNP_STATUS CNP_CALL cnp_array_split(const CnpArray *arr, int nsections, int axis, CnpArray **result);
CNP_API CnpArray* CNP_CALL cnp_row_stack(int narrays, CnpArray **arrays);
CNP_API CnpArray* CNP_CALL cnp_block(int nrows, int ncols, CnpArray **blocks);
CNP_API CnpArray* CNP_CALL cnp_histogram2d(const CnpArray *x, const CnpArray *y, int64_t bins);
CNP_API double CNP_CALL cnp_nanquantile(const CnpArray *arr, double q, int axis);
CNP_API CnpArray* CNP_CALL cnp_nanquantile_v2(
    const CnpArray *arr, double q, int axis, bool axis_none);
CNP_API CnpArray* CNP_CALL cnp_lcm(const CnpArray *x1, const CnpArray *x2);
CNP_API CnpArray* CNP_CALL cnp_gcd(const CnpArray *x1, const CnpArray *x2);
CNP_API CnpArray* CNP_CALL cnp_bitwise_count(const CnpArray *arr);

/* =========================================================================
 * Function declarations - Extended numpy functions (numpy_ext.c)
 * ========================================================================= */
CNP_API CnpArray* CNP_CALL cnp_eigvals(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_eigvalsh(const CnpArray *a);
CNP_API CnpArray* CNP_CALL cnp_eigvalsh_v2(
    const CnpArray *a, bool upper);
CNP_API CnpArray* CNP_CALL cnp_take_along_axis(const CnpArray *arr, const CnpArray *indices, int axis);
CNP_API CNP_STATUS CNP_CALL cnp_put_along_axis(CnpArray *arr, const CnpArray *indices, const CnpArray *values, int axis);
CNP_API CNP_STATUS CNP_CALL cnp_divmod(const CnpArray *x1, const CnpArray *x2, CnpArray **quotient, CnpArray **remainder);
CNP_API CnpArray* CNP_CALL cnp_roots(const CnpArray *p);
CNP_API int64_t CNP_CALL cnp_nanargmax(const CnpArray *arr, int axis);
CNP_API CnpArray* CNP_CALL cnp_nanargmax_v2(
    const CnpArray *arr, int axis, bool axis_none);
CNP_API int64_t CNP_CALL cnp_nanargmin(const CnpArray *arr, int axis);
CNP_API CnpArray* CNP_CALL cnp_nanargmin_v2(
    const CnpArray *arr, int axis, bool axis_none);
CNP_API CnpArray* CNP_CALL cnp_sort_complex(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_random_chisquare(double df, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_geometric(double p, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_zipf(double a, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_wald(double mean, double scale, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_hypergeometric(int64_t ngood, int64_t nbad, int64_t nsample, int ndim, const int64_t *shape);

/* =========================================================================
 * Function declarations - Extended random distributions (random_ext.c)
 * ========================================================================= */
CNP_API CnpArray* CNP_CALL cnp_random_logseries(double p, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_negative_binomial(double n, double p, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_pareto(double a, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_power(double a, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_rayleigh(double scale, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_standard_cauchy(int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_standard_t(double df, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_triangular(double left, double mode, double right, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_vonmises(double mu, double kappa, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_noncentral_chisquare(double df, double nonc, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_noncentral_f(double dfnum, double dfden, double nonc, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_f(double dfnum, double dfden, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_laplace(double loc, double scale, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_logistic(double loc, double scale, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_gumbel(double loc, double scale, int ndim, const int64_t *shape);
CNP_API CnpArray* CNP_CALL cnp_random_dirichlet(const double *alpha, int k, int64_t nsamples);
CNP_API CnpArray* CNP_CALL cnp_random_multinomial(int64_t n, const double *pvals, int k, int64_t nsamples);
CNP_API CnpArray* CNP_CALL cnp_random_weibull(double a, int ndim, const int64_t *shape);

/* =========================================================================
 * Function declarations - Extended FFT (fft_ext.c)
 * ========================================================================= */
CNP_API CnpArray* CNP_CALL cnp_fftn(const CnpArray *a, int naxes, const int *axes);
CNP_API CnpArray* CNP_CALL cnp_ifftn(const CnpArray *a, int naxes, const int *axes);
CNP_API CnpArray* CNP_CALL cnp_rfftn(const CnpArray *a, int naxes, const int *axes);
CNP_API CnpArray* CNP_CALL cnp_irfftn(const CnpArray *a, int naxes, const int *axes, int ndims, const int64_t *s);
CNP_API CnpArray* CNP_CALL cnp_hfft(const CnpArray *a, int64_t n);
CNP_API CnpArray* CNP_CALL cnp_ihfft(const CnpArray *a);

/* =========================================================================
 * Function declarations - Utility functions (util_ext.c)
 * ========================================================================= */
CNP_API void CNP_CALL cnp_seterr(int divide, int over, int under, int invalid);
CNP_API void CNP_CALL cnp_geterr(int *divide, int *over, int *under, int *invalid);
CNP_API CNP_TYPE CNP_CALL cnp_min_scalar_type(double value);
CNP_API CNP_TYPE CNP_CALL cnp_common_type(int narrays, const CnpArray **arrays);
CNP_API CnpArray* CNP_CALL cnp_emath_sqrt(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_emath_log(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_emath_log10(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_emath_log2(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_emath_power(const CnpArray *base, const CnpArray *exp_arr);
CNP_API CnpArray* CNP_CALL cnp_emath_arcsin(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_emath_arccos(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_emath_arctanh(const CnpArray *arr);
CNP_API void CNP_CALL cnp_set_printoptions(int precision, int threshold, int edgeitems, int linewidth, int suppress);
CNP_API void CNP_CALL cnp_get_printoptions(int *precision, int *threshold, int *edgeitems, int *linewidth, int *suppress);
CNP_API int CNP_CALL cnp_array2string(const CnpArray *arr, char *buffer, int64_t bufsize);
CNP_API bool CNP_CALL cnp_iscomplexobj(const CnpArray *arr);
CNP_API bool CNP_CALL cnp_isrealobj(const CnpArray *arr);
CNP_API bool CNP_CALL cnp_isscalar(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_isfinite_arr(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_isinf_arr(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_isnan_arr(const CnpArray *arr);
CNP_API const char* CNP_CALL cnp_typename(CNP_TYPE type);
CNP_API bool CNP_CALL cnp_ndenumerate_next(const CnpArray *arr, int64_t *iter_state, int64_t *coords, double *value);
CNP_API bool CNP_CALL cnp_ndindex_next(int ndim, const int64_t *shape, int64_t *coords);

/* =========================================================================
 * Function declarations - Polynomial extensions (poly_ext.c)
 * ========================================================================= */
CNP_API CnpArray* CNP_CALL cnp_chebval(const CnpArray *x, const CnpArray *c);
CNP_API CnpArray* CNP_CALL cnp_chebder(const CnpArray *c, int m);
CNP_API CnpArray* CNP_CALL cnp_chebint(const CnpArray *c, int m, double lbnd);
CNP_API CnpArray* CNP_CALL cnp_chebadd(const CnpArray *c1, const CnpArray *c2);
CNP_API CnpArray* CNP_CALL cnp_chebsub(const CnpArray *c1, const CnpArray *c2);
CNP_API CnpArray* CNP_CALL cnp_legval(const CnpArray *x, const CnpArray *c);
CNP_API CnpArray* CNP_CALL cnp_legder(const CnpArray *c, int m);
CNP_API CnpArray* CNP_CALL cnp_hermval(const CnpArray *x, const CnpArray *c);
CNP_API CnpArray* CNP_CALL cnp_hermder(const CnpArray *c, int m);
CNP_API CnpArray* CNP_CALL cnp_lagval(const CnpArray *x, const CnpArray *c);
CNP_API CnpArray* CNP_CALL cnp_lagder(const CnpArray *c, int m);
CNP_API CnpArray* CNP_CALL cnp_diagflat(const CnpArray *arr, int k);
CNP_API CNP_STATUS CNP_CALL cnp_mgrid(int ndim, const int64_t *start, const int64_t *stop, const int64_t *step, CnpArray **result);
CNP_API CNP_STATUS CNP_CALL cnp_ogrid(int ndim, const int64_t *start, const int64_t *stop, const int64_t *step, CnpArray **result);
CNP_API bool CNP_CALL cnp_assert_array_equal(const CnpArray *a, const CnpArray *b);
CNP_API bool CNP_CALL cnp_assert_array_almost_equal(const CnpArray *a, const CnpArray *b, int decimal);
CNP_API bool CNP_CALL cnp_assert_allclose(const CnpArray *a, const CnpArray *b, double rtol, double atol);

/* =========================================================================
 * Function declarations - Final extensions (final_ext.c)
 * ========================================================================= */
CNP_API CnpArray* CNP_CALL cnp_ascontiguousarray(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_asfortranarray(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_resize(const CnpArray *arr, int ndim, const int64_t *new_shape);
CNP_API CNP_STATUS CNP_CALL cnp_byte_bounds(const CnpArray *arr, void **low, void **high);
CNP_API CNP_STATUS CNP_CALL cnp_putmask(CnpArray *arr, const CnpArray *mask, const CnpArray *values);
CNP_API CnpArray* CNP_CALL cnp_real_if_close(const CnpArray *arr, double tol);
CNP_API CnpArray* CNP_CALL cnp_polyfromroots(const CnpArray *roots);
CNP_API CnpArray* CNP_CALL cnp_mat(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_bmat(int nrows, int ncols, CnpArray **blocks);
CNP_API CnpArray* CNP_CALL cnp_matlib_rand(int64_t rows, int64_t cols);
CNP_API CnpArray* CNP_CALL cnp_matlib_randn(int64_t rows, int64_t cols);
CNP_API CnpArray* CNP_CALL cnp_matlib_eye(int64_t n, int64_t m, int k);
CNP_API CnpArray* CNP_CALL cnp_matlib_ones(int64_t rows, int64_t cols);
CNP_API CnpArray* CNP_CALL cnp_matlib_zeros(int64_t rows, int64_t cols);
CNP_API CnpArray* CNP_CALL cnp_matlib_repmat(const CnpArray *arr, int64_t m, int64_t n);

/* =========================================================================
 * Function declarations - Polynomial extensions 2 (poly_ext2.c)
 * ========================================================================= */
CNP_API CnpArray* CNP_CALL cnp_chebmul(const CnpArray *c1, const CnpArray *c2);
CNP_API CnpArray* CNP_CALL cnp_chebfit(const CnpArray *x, const CnpArray *y, int deg);
CNP_API CnpArray* CNP_CALL cnp_chebpts1(int64_t n);
CNP_API CnpArray* CNP_CALL cnp_chebpts2(int64_t n);
CNP_API CnpArray* CNP_CALL cnp_poly2cheb(const CnpArray *pol);
CNP_API CnpArray* CNP_CALL cnp_cheb2poly(const CnpArray *c);
CNP_API CnpArray* CNP_CALL cnp_legmul(const CnpArray *c1, const CnpArray *c2);
CNP_API CnpArray* CNP_CALL cnp_legfit(const CnpArray *x, const CnpArray *y, int deg);
CNP_API CnpArray* CNP_CALL cnp_leg2poly(const CnpArray *c);
CNP_API CnpArray* CNP_CALL cnp_poly2leg(const CnpArray *pol);
CNP_API CnpArray* CNP_CALL cnp_hermmul(const CnpArray *c1, const CnpArray *c2);
CNP_API CnpArray* CNP_CALL cnp_hermfit(const CnpArray *x, const CnpArray *y, int deg);
CNP_API CnpArray* CNP_CALL cnp_lagmul(const CnpArray *c1, const CnpArray *c2);
CNP_API CnpArray* CNP_CALL cnp_lagfit(const CnpArray *x, const CnpArray *y, int deg);

/* =========================================================================
 * Function declarations - Array extensions (array_ext.c)
 * ========================================================================= */
CNP_API void* CNP_CALL cnp_tobytes(const CnpArray *arr, int64_t *out_size);
CNP_API double* CNP_CALL cnp_tolist(const CnpArray *arr, int64_t *out_size);
CNP_API void CNP_CALL cnp_buffer_free(void *buffer);
CNP_API double CNP_CALL cnp_item(const CnpArray *arr, int64_t flat_index);
CNP_API CnpArray* CNP_CALL cnp_view(const CnpArray *arr, int dtype_num);
CNP_API CnpArray* CNP_CALL cnp_getfield(const CnpArray *arr, int dtype_num, int64_t offset);
CNP_API CNP_STATUS CNP_CALL cnp_setfield(CnpArray *arr, const CnpArray *val, int dtype_num, int64_t offset);
CNP_API CnpArray* CNP_CALL cnp_require(const CnpArray *arr, int dtype_num, bool c_contiguous);
CNP_API CnpArray* CNP_CALL cnp_asarray_chkfinite(const CnpArray *arr, int dtype_num);
CNP_API CnpArray* CNP_CALL cnp_newbyteorder(const CnpArray *arr);
CNP_API CnpArray* CNP_CALL cnp_conjugate(const CnpArray *arr);
CNP_API CNP_STATUS CNP_CALL cnp_format_float(double val, char *buf, int64_t buf_size, int precision, bool scientific);
CNP_API int64_t CNP_CALL cnp_getbufsize(void);
CNP_API CNP_STATUS CNP_CALL cnp_setbufsize(int64_t size);
CNP_API int64_t CNP_CALL cnp_nbytes(const CnpArray *arr);
CNP_API CNP_STATUS CNP_CALL cnp_disp(const char *mesg);
CNP_API CNP_STATUS CNP_CALL cnp_datetime_as_string(const CnpArray *arr, char *buf, int64_t buf_size);
CNP_API CNP_STATUS CNP_CALL cnp_datetime_as_string_v2(
    const CnpArray *arr, CNP_DATETIME_UNIT unit,
    char **outputs, int64_t capacity);
CNP_API CnpArray* CNP_CALL cnp_random_multivariate_normal(const CnpArray *mean, const CnpArray *cov, int64_t size);
CNP_API void* CNP_CALL cnp_random_bytes(int64_t length);
CNP_API void CNP_CALL cnp_random_bytes_free(void *buffer);
CNP_API uint16_t CNP_CALL cnp_float_to_half(double val);
CNP_API double CNP_CALL cnp_half_to_float(uint16_t h);
CNP_API CnpArray* CNP_CALL cnp_fromregex(const char *str, const char *pattern, int dtype_num, int64_t max_matches);
CNP_API CnpRegexResult* CNP_CALL cnp_fromregex_v2(
    const char *str, const char *pattern,
    const char *const *field_names, const CNP_TYPE *field_types,
    int nfields, int64_t max_matches);
CNP_API int64_t CNP_CALL cnp_regex_result_count(
    const CnpRegexResult *result);
CNP_API int CNP_CALL cnp_regex_result_nfields(
    const CnpRegexResult *result);
CNP_API const char* CNP_CALL cnp_regex_result_field_name(
    const CnpRegexResult *result, int field_index);
CNP_API CnpArray* CNP_CALL cnp_regex_result_field(
    const CnpRegexResult *result, int field_index);
CNP_API void CNP_CALL cnp_regex_result_free(CnpRegexResult *result);
CNP_API CNP_STATUS CNP_CALL cnp_set_string_function(void *func);
CNP_API CNP_STATUS CNP_CALL cnp_set_string_function_v2(
    CnpStringFunction func, void *userdata, bool repr);
CNP_API char* CNP_CALL cnp_array_string_v2(
    const CnpArray *arr, bool repr);
CNP_API double CNP_CALL cnp_safe_eval(const char *expr);
CNP_API CNP_STATUS CNP_CALL cnp_safe_eval_v2(
    const char *expr, double *out_value);

#ifdef __cplusplus
}
#endif

#endif /* CNUMPY_H */
