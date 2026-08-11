#Requires AutoHotkey v2.0

class NumpyKeyError extends Error {
}

NumpyStringFunctionCallback(nativeHandle, userdata) {
    return Numpy._InvokeStringFunction(nativeHandle, userdata)
}

NumpyLineFunctionCallback(linePointer, length, userdata, resultPointer) {
    return Numpy._InvokeLineFunction(
        linePointer, length, userdata, resultPointer)
}

NumpyCoordinateFunctionCallback(
    coordinatesPointer, ndim, userdata, resultPointer
) {
    return Numpy._InvokeCoordinateFunction(
        coordinatesPointer, ndim, userdata, resultPointer)
}

NumpyIteratorFunctionCallback(userdata, resultPointer) {
    return Numpy._InvokeIteratorFunction(userdata, resultPointer)
}

NumpyUnaryFunctionCallback(valuePointer, userdata, resultPointer) {
    return Numpy._InvokeUnaryFunction(
        valuePointer, userdata, resultPointer)
}

NumpyLineBatchCallback(
    linesPointer, lineCount, lineLength, resultsPointer,
    resultCapacity, producedPointer, userdata
) {
    return Numpy._InvokeLineBatch(
        linesPointer, lineCount, lineLength, resultsPointer,
        resultCapacity, producedPointer, userdata)
}

NumpyCoordinateBatchCallback(
    coordinatesPointer, pointCount, ndim, resultsPointer,
    resultCapacity, producedPointer, userdata
) {
    return Numpy._InvokeCoordinateBatch(
        coordinatesPointer, pointCount, ndim, resultsPointer,
        resultCapacity, producedPointer, userdata)
}

NumpyIteratorBatchCallback(
    resultsPointer, resultCapacity, producedPointer, userdata
) {
    return Numpy._InvokeIteratorBatch(
        resultsPointer, resultCapacity, producedPointer, userdata)
}

NumpyUnaryBatchCallback(
    valuesPointer, valueCount, resultsPointer,
    resultCapacity, producedPointer, userdata
) {
    return Numpy._InvokeUnaryBatch(
        valuesPointer, valueCount, resultsPointer,
        resultCapacity, producedPointer, userdata)
}

/**
 * Numpy - AHK v2 wrapper for cnumpy_ahk.dll
 *
 * Provides numpy-like N-dimensional array operations via DllCall.
 * All arrays are opaque handles managed by the C library.
 *
 * Usage:
 *   np := Numpy
 *   a := np.array([1.0, 2.0, 3.0, 4.0], [2, 2])
 *   b := np.ones([2, 2])
 *   out := np.zeros([2, 2])
 *   np.add(a, b, out)
 *   result := np.matmul(a, b)
 *   MsgBox result.ToString()
 */
class Numpy {
    static DllPath := ""
    static DllHandle := 0
    static ProcCache := Map()
    static ProcCacheHandle := 0
    static Initialized := false
    static MetadataAbiVersion := 1
    static MetadataSize := 544
    static MetadataMaxDims := 64
    static ARRAY_C_CONTIGUOUS := 0x0001
    static ARRAY_F_CONTIGUOUS := 0x0002
    static StringFunctionContexts := Map()
    static CallbackContexts := Map()
    static NextCallbackToken := 1

    ; Dtype constants (matching CNP_TYPE enum in cnumpy.h)
    static DT_BOOL := 1
    static DT_INT8 := 2
    static DT_UINT8 := 3
    static DT_INT16 := 4
    static DT_UINT16 := 5
    static DT_INT32 := 6
    static DT_UINT32 := 7
    static DT_INT64 := 8       ; CNP_LONG
    static DT_UINT64 := 9      ; CNP_ULONG
    static DT_LONGLONG := 10   ; CNP_LONGLONG (int64)
    static DT_ULONGLONG := 11  ; CNP_ULONGLONG (uint64)
    static DT_FLOAT32 := 12
    static DT_FLOAT64 := 13
    static DT_LONGDOUBLE := 14
    static DT_COMPLEX64 := 15
    static DT_COMPLEX128 := 16
    static DT_COMPLEX_LONGDOUBLE := 17
    static DT_OBJECT := 18
    static DT_STRING := 19
    static DT_UNICODE := 20
    static DT_VOID := 21
    static DT_DATETIME := 22
    static DT_TIMEDELTA := 23
    static DT_FLOAT16 := 24

    ; =========================================================================
    ; DLL loading
    ; =========================================================================

    static RequireDllPath() {
        if Numpy.DllPath = "" {
            SplitPath A_LineFile, , &ahkDir
            Numpy.DllPath := ahkDir "\..\build\x64\Release\cnumpy_ahk.dll"
        }
        Numpy.EnsureDllLoaded()
        return Numpy.DllPath
    }

    static EnsureDllLoaded() {
        if Numpy.DllHandle
            return Numpy.DllHandle
        handle := DllCall("kernel32\LoadLibraryW", "Str", Numpy.DllPath, "Ptr")
        if !handle
            throw Error("cnumpy_ahk: failed to load DLL " Numpy.DllPath " (GetLastError " A_LastError ")", -1)
        Numpy.DllHandle := handle
        return handle
    }

    static Proc(name) {
        if !Numpy.DllHandle
            Numpy.RequireDllPath()
        if Numpy.ProcCacheHandle != Numpy.DllHandle {
            Numpy.ProcCache := Map()
            Numpy.ProcCacheHandle := Numpy.DllHandle
        }
        if Numpy.ProcCache.Has(name)
            return Numpy.ProcCache[name]
        address := DllCall("kernel32\GetProcAddress",
            "Ptr", Numpy.DllHandle, "AStr", name, "Ptr")
        if !address
            throw Error("cnumpy_ahk: missing native export " name, -1)
        Numpy.ProcCache[name] := address
        return address
    }

    static Init() {
        if Numpy.Initialized
            return
        status := DllCall(Numpy.Proc("cnp_ahk_init"), "Int")
        Numpy.CheckStatus(status, "Numpy.Init")
        Numpy.Initialized := true
    }

    static Cleanup() {
        if !Numpy.Initialized
            return
        if Numpy.StringFunctionContexts.Has("repr")
            Numpy.Set_String_Function(, true)
        if Numpy.StringFunctionContexts.Has("str")
            Numpy.Set_String_Function(, false)
        status := DllCall(Numpy.Proc("cnp_ahk_cleanup"), "Int")
        Numpy.CheckStatus(status, "Numpy.Cleanup")
        Numpy.Initialized := false
    }

    static SetNumThreads(count) {
        Numpy.Init()
        status := DllCall(Numpy.Proc("cnp_ahk_set_num_threads"),
            "Int", count, "Int")
        Numpy.CheckStatus(status, "Numpy.SetNumThreads")
        return count
    }

    static GetNumThreads() {
        Numpy.Init()
        count := DllCall(Numpy.Proc("cnp_ahk_get_num_threads"), "Int")
        if count < 0
            Numpy.CheckStatus(count, "Numpy.GetNumThreads")
        return count
    }

    static Version() {
        return StrGet(DllCall(Numpy.Proc("cnp_ahk_version"), "Ptr"), "UTF-8")
    }

    ; =========================================================================
    ; Array creation (static factory methods)
    ; =========================================================================

    /**
     * Create array from flat AHK array of numbers.
     * shape: optional AHK array of dimensions. Default: 1D with data.Length elements.
     */
    static Array(data, shape := unset, dtype := 13) {
        Numpy.Init()
        count := data.Length
        if !IsSet(shape)
            shape := [count]

        shapeBuf := Numpy.ShapeBuffer(shape)
        dataBuf := Buffer(count * 8, 0)
        for i, v in data
            NumPut("Double", v, dataBuf, (i - 1) * 8)

        if dtype = 13 {
            handle := DllCall(Numpy.Proc("cnp_ahk_from_doubles"),
                "Int", shape.Length, "Ptr", shapeBuf, "Ptr", dataBuf,
                "Int64", count, "Ptr")
        } else {
            handle := DllCall(Numpy.Proc("cnp_ahk_create"),
                "Int", shape.Length, "Ptr", shapeBuf, "Int", dtype, "Ptr")
            if handle {
                written := DllCall(Numpy.Proc("cnp_ahk_set_doubles"),
                    "Ptr", handle, "Ptr", dataBuf,
                    "Int64", count, "Int64")
                if written != count {
                    DllCall(Numpy.Proc("cnp_ahk_free"), "Ptr", handle, "Int")
                    handle := 0
                }
            }
        }
        if !handle
            throw Error("Numpy.Array: creation failed", -1)
        return Numpy.NdArray.FromHandle(handle)
    }

    /** Create array from flat AHK array of integers (int64). */
    static IntArray(data, shape := unset) {
        Numpy.Init()
        count := data.Length
        if !IsSet(shape)
            shape := [count]

        shapeBuf := Numpy.ShapeBuffer(shape)
        dataBuf := Buffer(count * 8, 0)
        for i, v in data
            NumPut("Int64", v, dataBuf, (i - 1) * 8)

        handle := DllCall(Numpy.Proc("cnp_ahk_from_ints"),
            "Int", shape.Length, "Ptr", shapeBuf, "Ptr", dataBuf, "Int64", count, "Ptr")
        if !handle
            throw Error("Numpy.IntArray: creation failed", -1)
        return Numpy.NdArray.FromHandle(handle)
    }

    static Empty(shape, dtype := 13, order := "C") {
        Numpy.Init()
        shapeBuf := Numpy.ShapeBuffer(shape)
        orderCode := Numpy.ResolveOrder(order, "Numpy.Empty")
        handle := DllCall(Numpy.Proc("cnp_array_empty"),
            "Int", shape.Length, "Ptr", shapeBuf,
            "Int", dtype, "Int", orderCode, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Empty")
    }

    static Zeros(shape, dtype := 13, order := "C") {
        Numpy.Init()
        shapeBuf := Numpy.ShapeBuffer(shape)
        orderCode := Numpy.ResolveOrder(order, "Numpy.Zeros")
        handle := DllCall(Numpy.Proc("cnp_array_zeros"),
            "Int", shape.Length, "Ptr", shapeBuf,
            "Int", dtype, "Int", orderCode, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Zeros")
    }

    static Ones(shape, dtype := 13, order := "C") {
        Numpy.Init()
        shapeBuf := Numpy.ShapeBuffer(shape)
        orderCode := Numpy.ResolveOrder(order, "Numpy.Ones")
        handle := DllCall(Numpy.Proc("cnp_array_ones"),
            "Int", shape.Length, "Ptr", shapeBuf,
            "Int", dtype, "Int", orderCode, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Ones")
    }

    static Full(shape, value, dtype := 13, order := "C") {
        Numpy.Init()
        shapeBuf := Numpy.ShapeBuffer(shape)
        orderCode := Numpy.ResolveOrder(order, "Numpy.Full")
        handle := DllCall(Numpy.Proc("cnp_array_full"),
            "Int", shape.Length, "Ptr", shapeBuf, "Double", value,
            "Int", dtype, "Int", orderCode, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Full")
    }

    static Arange(start, stop, step := 1.0, dtype := 13) {
        Numpy.Init()
        handle := DllCall(Numpy.Proc("cnp_arange"),
            "Double", start, "Double", stop, "Double", step,
            "Int", dtype, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Arange")
    }

    static Linspace(
        start, stop, num := 50, endpoint := true, dtype := 13
    ) {
        Numpy.Init()
        handle := DllCall(Numpy.Proc("cnp_linspace"),
            "Double", start, "Double", stop, "Int64", num,
            "Int", endpoint ? 1 : 0, "Int", dtype, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Linspace")
    }

    static Logspace(
        start, stop, num := 50, endpoint := true,
        base := 10.0, dtype := 13
    ) {
        Numpy.Init()
        handle := DllCall(Numpy.Proc("cnp_logspace"),
            "Double", start, "Double", stop, "Int64", num,
            "Int", endpoint ? 1 : 0, "Double", base,
            "Int", dtype, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Logspace")
    }

    static Geomspace(
        start, stop, num := 50, endpoint := true, dtype := 13
    ) {
        Numpy.Init()
        handle := DllCall(Numpy.Proc("cnp_geomspace"),
            "Double", start, "Double", stop, "Int64", num,
            "Int", endpoint ? 1 : 0, "Int", dtype, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Geomspace")
    }

    static Bartlett(length) => Numpy._Window(
        "cnp_bartlett", "Numpy.Bartlett", length)

    static Blackman(length) => Numpy._Window(
        "cnp_blackman", "Numpy.Blackman", length)

    static Hamming(length) => Numpy._Window(
        "cnp_hamming", "Numpy.Hamming", length)

    static Hanning(length) => Numpy._Window(
        "cnp_hanning", "Numpy.Hanning", length)

    static Kaiser(length, beta) {
        handle := DllCall(Numpy.Proc("cnp_kaiser"),
            "Int64", length, "Double", beta, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Kaiser")
    }

    static _Window(symbol, operation, length) {
        handle := DllCall(Numpy.Proc(symbol), "Int64", length, "Ptr")
        return Numpy.WrapHandle(handle, operation)
    }

    static Fv(rate, nper, payment, present, when := 0) {
        DllCall(Numpy.Proc("cnp_clear_error"))
        value := DllCall(Numpy.Proc("cnp_fv"),
            "Double", rate, "Int64", nper, "Double", payment,
            "Double", present, "Int", when, "Double")
        return Numpy._FinancialResult(value, "Numpy.Fv")
    }

    static Pv(rate, nper, payment, future, when := 0) {
        DllCall(Numpy.Proc("cnp_clear_error"))
        value := DllCall(Numpy.Proc("cnp_pv"),
            "Double", rate, "Int64", nper, "Double", payment,
            "Double", future, "Int", when, "Double")
        return Numpy._FinancialResult(value, "Numpy.Pv")
    }

    static Pmt(rate, nper, present, future := 0.0, when := 0) {
        DllCall(Numpy.Proc("cnp_clear_error"))
        value := DllCall(Numpy.Proc("cnp_pmt"),
            "Double", rate, "Int64", nper, "Double", present,
            "Double", future, "Int", when, "Double")
        return Numpy._FinancialResult(value, "Numpy.Pmt")
    }

    static Nper(rate, payment, present, future := 0.0, when := 0) {
        DllCall(Numpy.Proc("cnp_clear_error"))
        value := DllCall(Numpy.Proc("cnp_nper"),
            "Double", rate, "Double", payment, "Double", present,
            "Double", future, "Int", when, "Double")
        return Numpy._FinancialResult(value, "Numpy.Nper")
    }

    static Rate(nper, payment, present, future := 0.0, when := 0) {
        DllCall(Numpy.Proc("cnp_clear_error"))
        value := DllCall(Numpy.Proc("cnp_rate"),
            "Int64", nper, "Double", payment, "Double", present,
            "Double", future, "Int", when, "Double")
        return Numpy._FinancialResult(value, "Numpy.Rate")
    }

    static Npv(rate, values) {
        buffer := Numpy._FinancialValues(values, "Numpy.Npv")
        DllCall(Numpy.Proc("cnp_clear_error"))
        value := DllCall(Numpy.Proc("cnp_npv"),
            "Double", rate, "Ptr", buffer,
            "Int64", values.Length, "Double")
        return Numpy._FinancialResult(value, "Numpy.Npv")
    }

    static Irr(values) {
        buffer := Numpy._FinancialValues(values, "Numpy.Irr")
        DllCall(Numpy.Proc("cnp_clear_error"))
        value := DllCall(Numpy.Proc("cnp_irr"),
            "Ptr", buffer, "Int64", values.Length, "Double")
        return Numpy._FinancialResult(value, "Numpy.Irr")
    }

    static DatetimeFromDate(year, month, day, unit) {
        unitCode := Numpy._DatetimeUnit(unit, "Numpy.DatetimeFromDate")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        value := DllCall(Numpy.Proc("cnp_datetime64_from_date"),
            "Int64", year, "Int", month, "Int", day,
            "Int", unitCode, "Int64")
        return Numpy._DatetimeScalarResult(
            value, "Numpy.DatetimeFromDate (cnp_datetime64_from_date)")
    }

    static DatetimeFromTime(
        year, month, day, hour, minute, second, unit
    ) {
        unitCode := Numpy._DatetimeUnit(unit, "Numpy.DatetimeFromTime")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        value := DllCall(Numpy.Proc("cnp_datetime64_from_time"),
            "Int64", year, "Int", month, "Int", day,
            "Int", hour, "Int", minute, "Int", second,
            "Int", unitCode, "Int64")
        return Numpy._DatetimeScalarResult(
            value, "Numpy.DatetimeFromTime (cnp_datetime64_from_time)")
    }

    static DatetimeFromString(text, unit) {
        unitCode := Numpy._DatetimeUnit(unit, "Numpy.DatetimeFromString")
        textBuffer := Numpy.Utf8Buffer(text, "Numpy.DatetimeFromString text")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        value := DllCall(Numpy.Proc("cnp_datetime64_from_string"),
            "Ptr", textBuffer, "Int", unitCode, "Int64")
        return Numpy._DatetimeScalarResult(
            value, "Numpy.DatetimeFromString (cnp_datetime64_from_string)")
    }

    static DatetimeNow(unit) {
        unitCode := Numpy._DatetimeUnit(unit, "Numpy.DatetimeNow")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        value := DllCall(Numpy.Proc("cnp_datetime64_now"),
            "Int", unitCode, "Int64")
        return Numpy._DatetimeScalarResult(
            value, "Numpy.DatetimeNow (cnp_datetime64_now)")
    }

    static DatetimeToDate(value, unit) {
        unitCode := Numpy._DatetimeUnit(unit, "Numpy.DatetimeToDate")
        year := Buffer(8, 0)
        month := Buffer(4, 0)
        day := Buffer(4, 0)
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        DllCall(Numpy.Proc("cnp_datetime64_to_date"),
            "Int64", value, "Int", unitCode,
            "Ptr", year, "Ptr", month, "Ptr", day)
        Numpy._DatetimeCheckError(
            "Numpy.DatetimeToDate (cnp_datetime64_to_date)")
        return [NumGet(year, 0, "Int64"),
            NumGet(month, 0, "Int"), NumGet(day, 0, "Int")]
    }

    static DatetimeToTime(value, unit) {
        unitCode := Numpy._DatetimeUnit(unit, "Numpy.DatetimeToTime")
        hour := Buffer(4, 0)
        minute := Buffer(4, 0)
        second := Buffer(4, 0)
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        DllCall(Numpy.Proc("cnp_datetime64_to_time"),
            "Int64", value, "Int", unitCode,
            "Ptr", hour, "Ptr", minute, "Ptr", second)
        Numpy._DatetimeCheckError(
            "Numpy.DatetimeToTime (cnp_datetime64_to_time)")
        return [NumGet(hour, 0, "Int"),
            NumGet(minute, 0, "Int"), NumGet(second, 0, "Int")]
    }

    static DatetimeToString(value, unit) {
        unitCode := Numpy._DatetimeUnit(unit, "Numpy.DatetimeToString")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        pointer := DllCall(Numpy.Proc("cnp_datetime64_to_string"),
            "Int64", value, "Int", unitCode, "Ptr")
        if !pointer {
            Numpy._DatetimeCheckError(
                "Numpy.DatetimeToString (cnp_datetime64_to_string)")
            throw Error(
                "Numpy.DatetimeToString returned a null native string", -1)
        }
        try return StrGet(pointer, "UTF-8")
        finally DllCall(Numpy.Proc("cnp_char_free_string"), "Ptr", pointer)
    }

    static Timedelta64(value, unit) {
        unitCode := Numpy._DatetimeUnit(unit, "Numpy.Timedelta64")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        result := DllCall(Numpy.Proc("cnp_timedelta64_create"),
            "Int64", value, "Int", unitCode, "Int64")
        return Numpy._DatetimeScalarResult(
            result, "Numpy.Timedelta64 (cnp_timedelta64_create)")
    }

    static DatetimeAdd(value, delta, unit) {
        unitCode := Numpy._DatetimeUnit(unit, "Numpy.DatetimeAdd")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        result := DllCall(Numpy.Proc("cnp_datetime64_add"),
            "Int64", value, "Int64", delta, "Int", unitCode, "Int64")
        return Numpy._DatetimeScalarResult(
            result, "Numpy.DatetimeAdd (cnp_datetime64_add)")
    }

    static DatetimeSubtract(left, right, unit) {
        unitCode := Numpy._DatetimeUnit(unit, "Numpy.DatetimeSubtract")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        result := DllCall(Numpy.Proc("cnp_datetime64_subtract"),
            "Int64", left, "Int64", right, "Int", unitCode, "Int64")
        return Numpy._DatetimeScalarResult(
            result, "Numpy.DatetimeSubtract (cnp_datetime64_subtract)")
    }

    static DatetimeCompare(left, right) {
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        result := DllCall(Numpy.Proc("cnp_datetime64_compare"),
            "Int64", left, "Int64", right, "Int")
        Numpy._DatetimeCheckError(
            "Numpy.DatetimeCompare (cnp_datetime64_compare)")
        return result
    }

    static IsBusday(value) {
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        return DllCall(Numpy.Proc("cnp_is_busday"),
            "Int64", value, "Char") != 0
    }

    static BusdayCount(start, stop) {
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        result := DllCall(Numpy.Proc("cnp_busday_count"),
            "Int64", start, "Int64", stop, "Int64")
        return Numpy._DatetimeScalarResult(
            result, "Numpy.BusdayCount (cnp_busday_count)")
    }

    static BusdayOffset(value, offset) {
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        result := DllCall(Numpy.Proc("cnp_busday_offset"),
            "Int64", value, "Int64", offset, "Int64")
        return Numpy._DatetimeScalarResult(
            result, "Numpy.BusdayOffset (cnp_busday_offset)")
    }

    static DatetimeUnitName(unit) {
        unitCode := Numpy._DatetimeUnit(unit, "Numpy.DatetimeUnitName")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        pointer := DllCall(Numpy.Proc("cnp_datetime_unit_name"),
            "Int", unitCode, "Ptr")
        if !pointer {
            Numpy._DatetimeCheckError(
                "Numpy.DatetimeUnitName (cnp_datetime_unit_name)")
            throw Error(
                "Numpy.DatetimeUnitName returned a null native string", -1)
        }
        return StrGet(pointer, "UTF-8")
    }

    static DatetimeArray(values, shape, unit) {
        if !(values is Array)
            throw TypeError("Numpy.DatetimeArray values must be an Array")
        if !(shape is Array)
            throw TypeError("Numpy.DatetimeArray shape must be an Array")
        unitCode := Numpy._DatetimeUnit(unit, "Numpy.DatetimeArray")
        shapeBuffer := Numpy.ShapeBuffer(shape)
        valuesBuffer := Buffer(Max(values.Length, 1) * 8, 0)
        for index, value in values
            NumPut("Int64", value, valuesBuffer, (index - 1) * 8)
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_datetime64_array_create"),
            "Int", shape.Length, "Ptr", shapeBuffer,
            "Ptr", valuesBuffer, "Int", unitCode, "Ptr")
        return Numpy.WrapHandle(
            handle, "Numpy.DatetimeArray (cnp_datetime64_array_create)")
    }

    static ArangeDatetime(start, stop, step, unit) {
        unitCode := Numpy._DatetimeUnit(unit, "Numpy.ArangeDatetime")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_arange_datetime"),
            "Int64", start, "Int64", stop, "Int64", step,
            "Int", unitCode, "Ptr")
        return Numpy.WrapHandle(
            handle, "Numpy.ArangeDatetime (cnp_arange_datetime)")
    }

    static DatetimeAsString(source, unit) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.DatetimeAsString source must be an NdArray")
        unitCode := Numpy._DatetimeUnit(unit, "Numpy.DatetimeAsString")
        count := source.Size
        outputs := Buffer(Max(count, 1) * A_PtrSize, 0)
        try {
            DllCall(Numpy.Proc("cnp_clear_error"), "Int")
            status := DllCall(Numpy.Proc("cnp_datetime_as_string_v2"),
                "Ptr", source.Handle, "Int", unitCode,
                "Ptr", outputs, "Int64", count, "Int")
            Numpy.CheckStatus(
                status,
                "Numpy.DatetimeAsString (cnp_datetime_as_string_v2)")
            result := []
            loop count {
                pointer := NumGet(outputs, (A_Index - 1) * A_PtrSize, "Ptr")
                if !pointer
                    throw Error(
                        "Numpy.DatetimeAsString returned a null native string at index "
                        (A_Index - 1), -1)
                result.Push(StrGet(pointer, "UTF-8"))
            }
            return result
        } finally {
            loop count {
                pointer := NumGet(outputs, (A_Index - 1) * A_PtrSize, "Ptr")
                if pointer
                    DllCall(Numpy.Proc("cnp_char_free_string"),
                        "Ptr", pointer)
            }
        }
    }

    static Ndenumerate(source) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.Ndenumerate source must be an NdArray")
        ndim := source.Ndim
        state := Buffer(8, 0)
        coordinates := Buffer(Max(ndim, 1) * 8, 0)
        value := Buffer(8, 0)
        result := []
        loop {
            DllCall(Numpy.Proc("cnp_clear_error"), "Int")
            hasValue := DllCall(Numpy.Proc("cnp_ndenumerate_next"),
                "Ptr", source.Handle,
                "Ptr", state,
                "Ptr", coordinates,
                "Ptr", value,
                "Char")
            if !hasValue {
                status := DllCall(
                    Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
                Numpy.CheckStatus(
                    status, "Numpy.Ndenumerate (cnp_ndenumerate_next)")
                break
            }
            index := []
            loop ndim
                index.Push(NumGet(
                    coordinates, (A_Index - 1) * 8, "Int64"))
            result.Push([index, NumGet(value, 0, "Double")])
        }
        return result
    }

    static Ndindex(shape) {
        if !(shape is Array)
            throw TypeError("Numpy.Ndindex shape must be an Array")
        if shape.Length = 0
            return [[]]
        shapeBuffer := Numpy.ShapeBuffer(shape)
        coordinates := Buffer(shape.Length * 8, 0)
        NumPut("Int64", -1, coordinates, (shape.Length - 1) * 8)
        result := []
        loop {
            DllCall(Numpy.Proc("cnp_clear_error"), "Int")
            hasValue := DllCall(Numpy.Proc("cnp_ndindex_next"),
                "Int", shape.Length,
                "Ptr", shapeBuffer,
                "Ptr", coordinates,
                "Char")
            if !hasValue {
                status := DllCall(
                    Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
                Numpy.CheckStatus(
                    status, "Numpy.Ndindex (cnp_ndindex_next)")
                break
            }
            index := []
            loop shape.Length
                index.Push(NumGet(
                    coordinates, (A_Index - 1) * 8, "Int64"))
            result.Push(index)
        }
        return result
    }

    static ToBytes(source) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.ToBytes source must be an NdArray")
        sizeBuffer := Buffer(8, 0)
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        pointer := DllCall(Numpy.Proc("cnp_tobytes"),
            "Ptr", source.Handle, "Ptr", sizeBuffer, "Ptr")
        if !pointer {
            status := DllCall(
                Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
            Numpy.CheckStatus(status, "Numpy.ToBytes (cnp_tobytes)")
            throw Error("Numpy.ToBytes returned a null native buffer", -1)
        }
        try {
            size := NumGet(sizeBuffer, 0, "Int64")
            if size < 0
                throw Error("Numpy.ToBytes returned a negative byte size", -1)
            result := Buffer(size, 0)
            if size > 0
                DllCall("ntdll\RtlMoveMemory",
                    "Ptr", result.Ptr, "Ptr", pointer,
                    "UPtr", size, "Ptr")
            return result
        } finally {
            DllCall(Numpy.Proc("cnp_buffer_free"), "Ptr", pointer)
        }
    }

    static ToList(source) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.ToList source must be an NdArray")
        sizeBuffer := Buffer(8, 0)
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        pointer := DllCall(Numpy.Proc("cnp_tolist"),
            "Ptr", source.Handle, "Ptr", sizeBuffer, "Ptr")
        if !pointer {
            status := DllCall(
                Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
            Numpy.CheckStatus(status, "Numpy.ToList (cnp_tolist)")
            throw Error("Numpy.ToList returned a null native buffer", -1)
        }
        try {
            count := NumGet(sizeBuffer, 0, "Int64")
            if count < 0
                throw Error("Numpy.ToList returned a negative item count", -1)
            result := []
            loop count
                result.Push(NumGet(pointer, (A_Index - 1) * 8, "Double"))
            return result
        } finally {
            DllCall(Numpy.Proc("cnp_buffer_free"), "Ptr", pointer)
        }
    }

    static FromBuffer(buffer, dtype) {
        if Type(buffer) != "Buffer"
            throw TypeError("Numpy.FromBuffer buffer must be a Buffer")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_frombuffer"),
            "Ptr", buffer.Ptr, "Int64", buffer.Size,
            "Int", dtype, "Ptr")
        return Numpy.WrapHandle(
            handle, "Numpy.FromBuffer (cnp_frombuffer)")
    }

    static BaseRepr(number, base := 2, padding := 0) {
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        pointer := DllCall(Numpy.Proc("cnp_base_repr"),
            "Int64", number, "Int", base, "Int", padding, "Ptr")
        return Numpy._OwnedNativeString(
            pointer, "Numpy.BaseRepr (cnp_base_repr)")
    }

    static BinaryRepr(number, width := -1) {
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        pointer := DllCall(Numpy.Proc("cnp_binary_repr"),
            "Int64", number, "Int", width, "Ptr")
        return Numpy._OwnedNativeString(
            pointer, "Numpy.BinaryRepr (cnp_binary_repr)")
    }

    static _OwnedNativeString(pointer, operation) {
        if !pointer {
            status := DllCall(
                Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
            Numpy.CheckStatus(status, operation)
            throw Error(operation " returned a null native string", -1)
        }
        try return StrGet(pointer, "UTF-8")
        finally DllCall(Numpy.Proc("cnp_char_free_string"), "Ptr", pointer)
    }

    static _DatetimeUnit(unit, operation) {
        static units := Map(
            "Y", 0, "M", 1, "W", 2, "D", 3,
            "h", 4, "m", 5, "s", 6, "ms", 7,
            "us", 8, "ns", 9, "ps", 10, "fs", 11, "as", 12)
        if Type(unit) = "Integer"
            return unit
        if Type(unit) != "String"
            throw TypeError(operation " unit must be a string or integer")
        if !units.Has(unit)
            throw ValueError(operation " unit is not a supported datetime unit: " unit)
        return units[unit]
    }

    static _DatetimeCheckError(operation) {
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        Numpy.CheckStatus(status, operation)
    }

    static _DatetimeScalarResult(value, operation) {
        Numpy._DatetimeCheckError(operation)
        return value
    }

    static _FinancialValues(values, operation) {
        if !(values is Array)
            throw TypeError(operation " values must be an Array")
        resultBuffer := Buffer(Max(values.Length, 1) * 8, 0)
        for index, value in values
            NumPut("Double", value, resultBuffer, (index - 1) * 8)
        return resultBuffer
    }

    static _FinancialResult(value, operation) {
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        Numpy.CheckStatus(status, operation)
        return value
    }

    static Eye(n, m := 0, k := 0, dtype := 13) {
        Numpy.Init()
        handle := DllCall(Numpy.Proc("cnp_eye"),
            "Int64", n, "Int64", m, "Int64", k,
            "Int", dtype, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Eye")
    }

    static Identity(n, dtype := 13) {
        Numpy.Init()
        handle := DllCall(Numpy.Proc("cnp_identity"),
            "Int64", n, "Int", dtype, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Identity")
    }

    static Tri(n, m := 0, k := 0, dtype := 13) {
        Numpy.Init()
        handle := DllCall(Numpy.Proc("cnp_tri"),
            "Int64", n, "Int64", m, "Int64", k,
            "Int", dtype, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Tri")
    }

    static Diag(source, k := 0) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.Diag source must be an NdArray")
        handle := DllCall(Numpy.Proc("cnp_diag"),
            "Ptr", source.Handle, "Int64", k, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Diag")
    }

    static ZerosLike(source) {
        return Numpy._Like("cnp_zeros_like", "Numpy.ZerosLike", source)
    }

    static OnesLike(source) {
        return Numpy._Like("cnp_ones_like", "Numpy.OnesLike", source)
    }

    static EmptyLike(source) {
        return Numpy._Like("cnp_empty_like", "Numpy.EmptyLike", source)
    }

    static FullLike(source, fillValue) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.FullLike source must be an NdArray")
        handle := DllCall(Numpy.Proc("cnp_full_like"),
            "Ptr", source.Handle, "Double", fillValue, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.FullLike")
    }

    static View(source) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.View source must be an NdArray")
        handle := DllCall(Numpy.Proc("cnp_array_view"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.View")
    }

    static ReinterpretView(source, dtype) {
        Numpy.Init()
        if !(source is Numpy.NdArray)
            throw TypeError(
                "Numpy.ReinterpretView source must be an NdArray")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_view"),
            "Ptr", source.Handle, "Int", dtype, "Ptr")
        return Numpy.WrapHandle(
            handle, "Numpy.ReinterpretView (cnp_view)")
    }

    static GetField(source, dtype, offset := 0) {
        Numpy.Init()
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.GetField source must be an NdArray")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_getfield"),
            "Ptr", source.Handle, "Int", dtype,
            "Int64", offset, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.GetField (cnp_getfield)")
    }

    static SetField(destination, values, dtype, offset := 0) {
        Numpy.Init()
        if !(destination is Numpy.NdArray)
            throw TypeError(
                "Numpy.SetField destination must be an NdArray")
        if !(values is Numpy.NdArray)
            throw TypeError("Numpy.SetField values must be an NdArray")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        status := DllCall(Numpy.Proc("cnp_setfield"),
            "Ptr", destination.Handle, "Ptr", values.Handle,
            "Int", dtype, "Int64", offset, "Int")
        Numpy.CheckStatus(status, "Numpy.SetField (cnp_setfield)")
    }

    static NewByteOrder(source) {
        Numpy.Init()
        if !(source is Numpy.NdArray)
            throw TypeError(
                "Numpy.NewByteOrder source must be an NdArray")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_newbyteorder"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(
            handle, "Numpy.NewByteOrder (cnp_newbyteorder)")
    }

    static StructDtypeCreate(names, dtypes) {
        Numpy.Init()
        if !(names is Array) || !(dtypes is Array)
            throw TypeError(
                "Numpy.StructDtypeCreate names and dtypes must be Arrays")
        if names.Length != dtypes.Length
            throw ValueError(
                "Numpy.StructDtypeCreate names and dtypes must have equal lengths")
        namePointers := Buffer(Max(names.Length, 1) * A_PtrSize, 0)
        typeBuffer := Buffer(Max(dtypes.Length, 1) * 4, 0)
        nameBuffers := []
        for index, name in names {
            nameBuffer := Numpy.Utf8Buffer(
                name, "Numpy.StructDtypeCreate field name " index)
            nameBuffers.Push(nameBuffer)
            NumPut("Ptr", nameBuffer.Ptr,
                namePointers, (index - 1) * A_PtrSize)
            NumPut("Int", dtypes[index], typeBuffer, (index - 1) * 4)
        }
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        dtypeId := DllCall(Numpy.Proc("cnp_struct_dtype_create"),
            "Ptr", namePointers, "Ptr", typeBuffer,
            "Int", names.Length, "Int")
        return Numpy._StructuredScalarResult(
            dtypeId, "Numpy.StructDtypeCreate (cnp_struct_dtype_create)")
    }

    static StructDtypeItemsize(dtypeId) {
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        itemsize := DllCall(Numpy.Proc("cnp_struct_dtype_itemsize"),
            "Int", dtypeId, "Int64")
        return Numpy._StructuredScalarResult(
            itemsize,
            "Numpy.StructDtypeItemsize (cnp_struct_dtype_itemsize)")
    }

    static StructDtypeNfields(dtypeId) {
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        count := DllCall(Numpy.Proc("cnp_struct_dtype_nfields"),
            "Int", dtypeId, "Int")
        return Numpy._StructuredScalarResult(
            count, "Numpy.StructDtypeNfields (cnp_struct_dtype_nfields)")
    }

    static StructDtypeFieldName(dtypeId, fieldIndex) {
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        pointer := DllCall(Numpy.Proc("cnp_struct_dtype_field_name"),
            "Int", dtypeId, "Int", fieldIndex, "Ptr")
        return Numpy._StructuredStringResult(
            pointer,
            "Numpy.StructDtypeFieldName (cnp_struct_dtype_field_name)")
    }

    static StructDtypeFieldOffset(dtypeId, fieldIndex) {
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        offset := DllCall(Numpy.Proc("cnp_struct_dtype_field_offset"),
            "Int", dtypeId, "Int", fieldIndex, "Int64")
        return Numpy._StructuredScalarResult(
            offset,
            "Numpy.StructDtypeFieldOffset (cnp_struct_dtype_field_offset)")
    }

    static StructDtypeFindField(dtypeId, name) {
        nameBuffer := Numpy.Utf8Buffer(
            name, "Numpy.StructDtypeFindField name")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        fieldIndex := DllCall(Numpy.Proc("cnp_struct_dtype_find_field"),
            "Int", dtypeId, "Ptr", nameBuffer, "Int")
        return Numpy._StructuredScalarResult(
            fieldIndex,
            "Numpy.StructDtypeFindField (cnp_struct_dtype_find_field)")
    }

    static RecarrayNew(shape, dtypeId) {
        Numpy.Init()
        if !(shape is Array)
            throw TypeError("Numpy.RecarrayNew shape must be an Array")
        shapeBuffer := Numpy.ShapeBuffer(shape)
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_recarray_new"),
            "Int", shape.Length, "Ptr", shapeBuffer,
            "Int", dtypeId, "Ptr")
        return Numpy.WrapHandle(
            handle, "Numpy.RecarrayNew (cnp_recarray_new)")
    }

    static RecarrayGetField(records, name, dtypeId) {
        Numpy.Init()
        if !(records is Numpy.NdArray)
            throw TypeError(
                "Numpy.RecarrayGetField records must be an NdArray")
        nameBuffer := Numpy.Utf8Buffer(
            name, "Numpy.RecarrayGetField name")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_recarray_get_field"),
            "Ptr", records.Handle, "Ptr", nameBuffer,
            "Int", dtypeId, "Ptr")
        return Numpy.WrapHandle(
            handle, "Numpy.RecarrayGetField (cnp_recarray_get_field)")
    }

    static RecarraySetField(records, name, dtypeId, values) {
        Numpy.Init()
        if !(records is Numpy.NdArray)
            throw TypeError(
                "Numpy.RecarraySetField records must be an NdArray")
        if !(values is Numpy.NdArray)
            throw TypeError(
                "Numpy.RecarraySetField values must be an NdArray")
        nameBuffer := Numpy.Utf8Buffer(
            name, "Numpy.RecarraySetField name")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        status := DllCall(Numpy.Proc("cnp_recarray_set_field"),
            "Ptr", records.Handle, "Ptr", nameBuffer,
            "Int", dtypeId, "Ptr", values.Handle, "Int")
        Numpy.CheckStatus(
            status, "Numpy.RecarraySetField (cnp_recarray_set_field)")
    }

    static RecarrayGetRecord(records, index, dtypeId) {
        Numpy.Init()
        if !(records is Numpy.NdArray)
            throw TypeError(
                "Numpy.RecarrayGetRecord records must be an NdArray")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_recarray_get_record"),
            "Ptr", records.Handle, "Int64", index,
            "Int", dtypeId, "Ptr")
        return Numpy.WrapHandle(
            handle, "Numpy.RecarrayGetRecord (cnp_recarray_get_record)")
    }

    static RecarraySetRecord(records, index, dtypeId, values) {
        Numpy.Init()
        if !(records is Numpy.NdArray)
            throw TypeError(
                "Numpy.RecarraySetRecord records must be an NdArray")
        if !(values is Numpy.NdArray)
            throw TypeError(
                "Numpy.RecarraySetRecord values must be an NdArray")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        status := DllCall(Numpy.Proc("cnp_recarray_set_record"),
            "Ptr", records.Handle, "Int64", index,
            "Int", dtypeId, "Ptr", values.Handle, "Int")
        Numpy.CheckStatus(
            status, "Numpy.RecarraySetRecord (cnp_recarray_set_record)")
    }

    static RecarrayNames(dtypeId) {
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        pointer := DllCall(Numpy.Proc("cnp_recarray_names"),
            "Int", dtypeId, "Ptr")
        return Numpy._StructuredStringResult(
            pointer, "Numpy.RecarrayNames (cnp_recarray_names)")
    }

    static Recfromtxt(
        filename, delimiter := " ", skipHeader := 0, dtype := 13
    ) {
        Numpy.Init()
        path := Numpy.Utf8Buffer(filename, "Numpy.Recfromtxt filename")
        separator := Numpy.Utf8Buffer(
            delimiter, "Numpy.Recfromtxt delimiter")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_recfromtxt"),
            "Ptr", path, "Ptr", separator,
            "Int", skipHeader, "Int", dtype, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Recfromtxt (cnp_recfromtxt)")
    }

    static _StructuredScalarResult(value, operation) {
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        Numpy.CheckStatus(status, operation)
        return value
    }

    static _StructuredStringResult(pointer, operation) {
        if pointer
            return StrGet(pointer, "UTF-8")
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        Numpy.CheckStatus(status, operation)
        throw Error(operation " returned a null native string", -1)
    }

    static _Like(exportName, operation, source) {
        if !(source is Numpy.NdArray)
            throw TypeError(operation " source must be an NdArray")
        handle := DllCall(Numpy.Proc(exportName),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, operation)
    }

    static Masked(data, mask := unset, fillValue := 0.0) {
        if !(data is Numpy.NdArray)
            throw TypeError("Numpy.Masked data must be an NdArray")
        maskHandle := 0
        if IsSet(mask) {
            if !(mask is Numpy.NdArray)
                throw TypeError("Numpy.Masked mask must be an NdArray")
            maskHandle := mask.Handle
        }
        handle := DllCall(Numpy.Proc("cnp_masked_array_create"),
            "Ptr", data.Handle, "Ptr", maskHandle,
            "Double", fillValue, "Ptr")
        return Numpy.WrapMaskedHandle(handle, "Numpy.Masked", fillValue)
    }

    static MaskedWhere(condition, data, fillValue := 0.0) {
        if !(condition is Numpy.NdArray)
            throw TypeError("Numpy.MaskedWhere condition must be an NdArray")
        if !(data is Numpy.NdArray)
            throw TypeError("Numpy.MaskedWhere data must be an NdArray")
        handle := DllCall(Numpy.Proc("cnp_masked_where"),
            "Ptr", condition.Handle, "Ptr", data.Handle,
            "Double", fillValue, "Ptr")
        return Numpy.WrapMaskedHandle(handle, "Numpy.MaskedWhere", fillValue)
    }

    static MaskedInvalid(data, fillValue := 0.0) {
        return Numpy._MaskedValueConstructor(
            "cnp_masked_invalid", "Numpy.MaskedInvalid",
            data, fillValue)
    }

    static MaskedGreater(data, value, fillValue := 0.0) {
        return Numpy._MaskedComparisonConstructor(
            "cnp_masked_greater", "Numpy.MaskedGreater",
            data, value, fillValue)
    }

    static MaskedLess(data, value, fillValue := 0.0) {
        return Numpy._MaskedComparisonConstructor(
            "cnp_masked_less", "Numpy.MaskedLess",
            data, value, fillValue)
    }

    static MaskedEqual(data, value, fillValue := 0.0) {
        return Numpy._MaskedComparisonConstructor(
            "cnp_masked_equal", "Numpy.MaskedEqual",
            data, value, fillValue)
    }

    static MaskedNotEqual(data, value, fillValue := 0.0) {
        return Numpy._MaskedComparisonConstructor(
            "cnp_masked_not_equal", "Numpy.MaskedNotEqual",
            data, value, fillValue)
    }

    static MaskedInside(data, lower, upper, fillValue := 0.0) {
        return Numpy._MaskedRangeConstructor(
            "cnp_masked_inside", "Numpy.MaskedInside",
            data, lower, upper, fillValue)
    }

    static MaskedOutside(data, lower, upper, fillValue := 0.0) {
        return Numpy._MaskedRangeConstructor(
            "cnp_masked_outside", "Numpy.MaskedOutside",
            data, lower, upper, fillValue)
    }

    static _MaskedValueConstructor(symbol, operation, data, fillValue) {
        if !(data is Numpy.NdArray)
            throw TypeError(operation " data must be an NdArray")
        handle := DllCall(Numpy.Proc(symbol),
            "Ptr", data.Handle, "Double", fillValue, "Ptr")
        return Numpy.WrapMaskedHandle(handle, operation, fillValue)
    }

    static _MaskedComparisonConstructor(
        symbol, operation, data, value, fillValue
    ) {
        if !(data is Numpy.NdArray)
            throw TypeError(operation " data must be an NdArray")
        handle := DllCall(Numpy.Proc(symbol),
            "Ptr", data.Handle, "Double", value,
            "Double", fillValue, "Ptr")
        return Numpy.WrapMaskedHandle(handle, operation, fillValue)
    }

    static _MaskedRangeConstructor(
        symbol, operation, data, lower, upper, fillValue
    ) {
        if !(data is Numpy.NdArray)
            throw TypeError(operation " data must be an NdArray")
        handle := DllCall(Numpy.Proc(symbol),
            "Ptr", data.Handle, "Double", lower, "Double", upper,
            "Double", fillValue, "Ptr")
        return Numpy.WrapMaskedHandle(handle, operation, fillValue)
    }

    ; =========================================================================
    ; NumPy binary I/O
    ; =========================================================================

    static Save(filename, source) {
        Numpy.Init()
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.Save source must be an NdArray")
        path := Numpy.Utf8Buffer(filename, "Numpy.Save filename")
        status := DllCall(Numpy.Proc("cnp_save"),
            "Ptr", path, "Ptr", source.Handle, "Int")
        Numpy.CheckStatus(status, "Numpy.Save")
    }

    static Load(filename) {
        Numpy.Init()
        path := Numpy.Utf8Buffer(filename, "Numpy.Load filename")
        handle := DllCall(Numpy.Proc("cnp_load"), "Ptr", path, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Load")
    }

    static FromFile(filename, dtype := 13, count := -1, offset := 0) {
        Numpy.Init()
        if Type(dtype) != "Integer"
            throw TypeError("Numpy.FromFile dtype must be an integer dtype id")
        if Type(count) != "Integer"
            throw TypeError("Numpy.FromFile count must be an integer")
        if Type(offset) != "Integer"
            throw TypeError("Numpy.FromFile offset must be an integer")
        path := Numpy.Utf8Buffer(filename, "Numpy.FromFile filename")
        handle := DllCall(Numpy.Proc("cnp_fromfile"),
            "Ptr", path, "Int", dtype,
            "Int64", count, "Int64", offset, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.FromFile")
    }

    static ToFile(source, filename) {
        Numpy.Init()
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.ToFile source must be an NdArray")
        path := Numpy.Utf8Buffer(filename, "Numpy.ToFile filename")
        status := DllCall(Numpy.Proc("cnp_tofile"),
            "Ptr", source.Handle, "Ptr", path, "Int")
        Numpy.CheckStatus(status, "Numpy.ToFile")
    }

    static Array2String(source, bufferSize) {
        Numpy.Init()
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.Array2String source must be an NdArray")
        if Type(bufferSize) != "Integer" || bufferSize <= 0
            throw ValueError(
                "Numpy.Array2String bufferSize must be a positive Integer")
        outputBuffer := Buffer(bufferSize, 0)
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        length := DllCall(Numpy.Proc("cnp_array2string"),
            "Ptr", source.Handle, "Ptr", outputBuffer,
            "Int64", bufferSize, "Int")
        if length < 0 {
            status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
            Numpy.CheckStatus(
                status, "Numpy.Array2String (cnp_array2string)")
            throw Error(
                "Numpy.Array2String (cnp_array2string) returned -1", -1)
        }
        return StrGet(outputBuffer, length, "UTF-8")
    }

    static ArrayToString(source, format := "%g") {
        Numpy.Init()
        if !(source is Numpy.NdArray)
            throw TypeError(
                "Numpy.ArrayToString source must be an NdArray")
        formatBuffer := Numpy.Utf8Buffer(
            format, "Numpy.ArrayToString format")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        pointer := DllCall(Numpy.Proc("cnp_array_to_string"),
            "Ptr", source.Handle, "Ptr", formatBuffer, "Ptr")
        if !pointer {
            status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
            Numpy.CheckStatus(
                status, "Numpy.ArrayToString (cnp_array_to_string)")
            throw Error(
                "Numpy.ArrayToString returned a null native string", -1)
        }
        try return StrGet(pointer, "UTF-8")
        finally DllCall(Numpy.Proc("cnp_char_free_string"),
            "Ptr", pointer)
    }

    static ArrayPrint(source) {
        Numpy.Init()
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.ArrayPrint source must be an NdArray")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        DllCall(Numpy.Proc("cnp_array_print"),
            "Ptr", source.Handle)
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        Numpy.CheckStatus(status, "Numpy.ArrayPrint (cnp_array_print)")
    }

    static ArrayToCsv(source, bufferSize, delimiter := ",") {
        Numpy.Init()
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.ArrayToCsv source must be an NdArray")
        if Type(bufferSize) != "Integer" || bufferSize <= 0
            throw ValueError(
                "Numpy.ArrayToCsv bufferSize must be a positive Integer")
        separator := Numpy.Utf8Buffer(
            delimiter, "Numpy.ArrayToCsv delimiter")
        outputBuffer := Buffer(bufferSize, 0)
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        status := DllCall(Numpy.Proc("cnp_array_to_csv"),
            "Ptr", source.Handle, "Ptr", outputBuffer,
            "UPtr", bufferSize, "Ptr", separator, "Int")
        Numpy.CheckStatus(
            status, "Numpy.ArrayToCsv (cnp_array_to_csv)")
        return StrGet(outputBuffer, "UTF-8")
    }

    static Savetxt(
        filename, source, delimiter := " ", format := "%.18e"
    ) {
        Numpy.Init()
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.Savetxt source must be an NdArray")
        path := Numpy.Utf8Buffer(filename, "Numpy.Savetxt filename")
        separator := Numpy.Utf8Buffer(
            delimiter, "Numpy.Savetxt delimiter")
        formatBuffer := Numpy.Utf8Buffer(
            format, "Numpy.Savetxt format")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        status := DllCall(Numpy.Proc("cnp_savetxt"),
            "Ptr", path, "Ptr", source.Handle,
            "Ptr", separator, "Ptr", formatBuffer, "Int")
        Numpy.CheckStatus(status, "Numpy.Savetxt (cnp_savetxt)")
    }

    static Loadtxt(filename, delimiter := unset, dtype := 13) {
        Numpy.Init()
        path := Numpy.Utf8Buffer(filename, "Numpy.Loadtxt filename")
        separatorPointer := 0
        if IsSet(delimiter) {
            separator := Numpy.Utf8Buffer(
                delimiter, "Numpy.Loadtxt delimiter")
            separatorPointer := separator.Ptr
        }
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_loadtxt"),
            "Ptr", path, "Ptr", separatorPointer,
            "Int", dtype, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Loadtxt (cnp_loadtxt)")
    }

    static Genfromtxt(
        filename, delimiter := unset, skipHeader := 0,
        maxRows := -1, dtype := 13
    ) {
        Numpy.Init()
        path := Numpy.Utf8Buffer(filename, "Numpy.Genfromtxt filename")
        separatorPointer := 0
        if IsSet(delimiter) {
            separator := Numpy.Utf8Buffer(
                delimiter, "Numpy.Genfromtxt delimiter")
            separatorPointer := separator.Ptr
        }
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_genfromtxt"),
            "Ptr", path, "Ptr", separatorPointer,
            "Int", skipHeader, "Int", maxRows,
            "Int", dtype, "Ptr")
        return Numpy.WrapHandle(
            handle, "Numpy.Genfromtxt (cnp_genfromtxt)")
    }

    static Disp(message) {
        Numpy.Init()
        encoded := Numpy.Utf8Buffer(message, "Numpy.Disp message")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        status := DllCall(Numpy.Proc("cnp_disp"),
            "Ptr", encoded, "Int")
        Numpy.CheckStatus(status, "Numpy.Disp (cnp_disp)")
    }

    static Savez(filename, arrays, names := unset) {
        Numpy.Init()
        handles := Numpy.HandleBuffer(arrays, "Numpy.Savez")
        path := Numpy.Utf8Buffer(filename, "Numpy.Savez filename")
        count := arrays.Length
        if !IsSet(names) {
            status := DllCall(Numpy.Proc("cnp_savez_auto"),
                "Ptr", path, "Int", count, "Ptr", handles, "Int")
            Numpy.CheckStatus(status, "Numpy.Savez")
            return
        }
        if !(names is Array)
            throw TypeError("Numpy.Savez names must be an Array")
        if names.Length != count
            throw ValueError(
                "Numpy.Savez names and arrays must have equal lengths")

        namePointers := Buffer(Max(count, 1) * A_PtrSize, 0)
        nameBuffers := []
        for index, name in names {
            nameBuffer := Numpy.Utf8Buffer(
                name, "Numpy.Savez member name " index)
            nameBuffers.Push(nameBuffer)
            NumPut("Ptr", nameBuffer.Ptr,
                namePointers, (index - 1) * A_PtrSize)
        }
        status := DllCall(Numpy.Proc("cnp_savez"),
            "Ptr", path, "Int", count,
            "Ptr", namePointers, "Ptr", handles, "Int")
        Numpy.CheckStatus(status, "Numpy.Savez")
    }

    static Loadz(filename, maxArrays) {
        Numpy.Init()
        if maxArrays <= 0
            throw ValueError("Numpy.Loadz maxArrays must be positive")
        path := Numpy.Utf8Buffer(filename, "Numpy.Loadz filename")
        names := Buffer(maxArrays * 64, 0)
        handles := Buffer(maxArrays * A_PtrSize, 0)
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        count := DllCall(Numpy.Proc("cnp_loadz"),
            "Ptr", path, "Ptr", names, "Ptr", handles,
            "Int", maxArrays, "Int")
        if count = 0 {
            status := DllCall(Numpy.Proc("cnp_get_error"),
                "Ptr", 0, "Int")
            if status != 0
                Numpy.CheckStatus(status, "Numpy.Loadz")
            return Map()
        }

        arrays := Numpy.WrapHandleBuffer(handles, count, "Numpy.Loadz")
        result := Map()
        for index, array in arrays {
            name := StrGet(names.Ptr + (index - 1) * 64, "UTF-8")
            if result.Has(name)
                throw ValueError(
                    "Numpy.Loadz duplicate member name: " name)
            result[name] := array
        }
        return result
    }

    static Memmap(filename, dtype, mode, offset, shape) {
        Numpy.Init()
        if !(shape is Array)
            throw TypeError("Numpy.Memmap shape must be an Array")
        modeCode := mode = "r" ? 0
            : mode = "r+" ? 1
            : mode = "c" ? 2
            : mode = "w+" ? 3
            : -1
        if modeCode < 0
            throw ValueError(
                "Numpy.Memmap mode must be r, r+, c, or w+")
        path := Numpy.Utf8Buffer(filename, "Numpy.Memmap filename")
        shapeBuffer := Numpy.ShapeBuffer(shape)
        handle := DllCall(Numpy.Proc("cnp_memmap_create"),
            "Ptr", path,
            "Int", shape.Length, "Ptr", shapeBuffer,
            "Int", dtype, "Int", modeCode, "Int64", offset, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Memmap")
    }

    static FromString(text, dtype := 13, count := -1, sep := " ") {
        Numpy.Init()
        if Type(dtype) != "Integer"
            throw TypeError("Numpy.FromString dtype must be an integer dtype id")
        if Type(count) != "Integer"
            throw TypeError("Numpy.FromString count must be an integer")
        textBuffer := Numpy.Utf8Buffer(text, "Numpy.FromString text")
        separatorBuffer := Numpy.Utf8Buffer(
            sep, "Numpy.FromString separator")
        handle := DllCall(Numpy.Proc("cnp_fromstring_v2"),
            "Ptr", textBuffer,
            "Int64", textBuffer.Size - 1,
            "Int", dtype,
            "Int64", count,
            "Ptr", separatorBuffer,
            "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.FromString")
    }

    static FromRegex(
        text, pattern, fieldNames, fieldDtypes, maxMatches := -1
    ) {
        Numpy.Init()
        if !(fieldNames is Array)
            throw TypeError("Numpy.FromRegex fieldNames must be an Array")
        if !(fieldDtypes is Array)
            throw TypeError("Numpy.FromRegex fieldDtypes must be an Array")
        if fieldNames.Length = 0
            throw ValueError("Numpy.FromRegex requires at least one field")
        if fieldNames.Length != fieldDtypes.Length
            throw ValueError(
                "Numpy.FromRegex fieldNames and fieldDtypes must have equal lengths")
        if Type(maxMatches) != "Integer"
            throw TypeError("Numpy.FromRegex maxMatches must be an integer")

        textBuffer := Numpy.Utf8Buffer(text, "Numpy.FromRegex text")
        patternBuffer := Numpy.Utf8Buffer(
            pattern, "Numpy.FromRegex pattern")
        count := fieldNames.Length
        namePointers := Buffer(count * A_PtrSize, 0)
        nameBuffers := []
        dtypeBuffer := Buffer(count * 4, 0)
        for index, name in fieldNames {
            nameBuffer := Numpy.Utf8Buffer(
                name, "Numpy.FromRegex field name " index)
            nameBuffers.Push(nameBuffer)
            NumPut("Ptr", nameBuffer.Ptr,
                namePointers, (index - 1) * A_PtrSize)
            dtype := fieldDtypes[index]
            if Type(dtype) != "Integer"
                throw TypeError(
                    "Numpy.FromRegex field dtype " index " must be an integer")
            NumPut("Int", dtype, dtypeBuffer, (index - 1) * 4)
        }

        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        nativeResult := DllCall(Numpy.Proc("cnp_fromregex_v2"),
            "Ptr", textBuffer,
            "Ptr", patternBuffer,
            "Ptr", namePointers,
            "Ptr", dtypeBuffer,
            "Int", count,
            "Int64", maxMatches,
            "Ptr")
        if !nativeResult {
            status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
            if status != 0
                Numpy.CheckStatus(status, "Numpy.FromRegex")
            throw Error(
                "Numpy.FromRegex returned null without a native error", -1)
        }

        handles := Buffer(count * A_PtrSize, 0)
        nativeNames := []
        extracted := 0
        try {
            returnedCount := DllCall(
                Numpy.Proc("cnp_regex_result_nfields"),
                "Ptr", nativeResult, "Int")
            if returnedCount != count {
                if returnedCount < 0 {
                    status := DllCall(
                        Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
                    Numpy.CheckStatus(status, "Numpy.FromRegex")
                }
                throw Error(
                    "Numpy.FromRegex returned an invalid field count", -1)
            }
            loop count {
                zeroIndex := A_Index - 1
                namePointer := DllCall(
                    Numpy.Proc("cnp_regex_result_field_name"),
                    "Ptr", nativeResult, "Int", zeroIndex, "Ptr")
                if !namePointer {
                    status := DllCall(
                        Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
                    Numpy.CheckStatus(status, "Numpy.FromRegex")
                }
                nativeNames.Push(StrGet(namePointer, "UTF-8"))
                handle := DllCall(
                    Numpy.Proc("cnp_regex_result_field"),
                    "Ptr", nativeResult, "Int", zeroIndex, "Ptr")
                if !handle {
                    status := DllCall(
                        Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
                    if status != 0
                        Numpy.CheckStatus(status, "Numpy.FromRegex")
                    throw Error(
                        "Numpy.FromRegex returned a null field handle", -1)
                }
                NumPut("Ptr", handle, handles, zeroIndex * A_PtrSize)
                extracted += 1
            }
        } catch Error as err {
            loop extracted {
                handle := NumGet(handles, (A_Index - 1) * A_PtrSize, "Ptr")
                if handle
                    DllCall(Numpy.Proc("cnp_ahk_free"), "Ptr", handle, "Int")
            }
            throw err
        } finally {
            DllCall(Numpy.Proc("cnp_regex_result_free"),
                "Ptr", nativeResult)
        }

        arrays := Numpy.WrapHandleBuffer(handles, count, "Numpy.FromRegex")
        result := Map()
        for index, fieldArray in arrays
            result[nativeNames[index]] := fieldArray
        return result
    }

    static SafeEval(expression) {
        Numpy.Init()
        expressionBuffer := Numpy.Utf8Buffer(
            expression, "Numpy.SafeEval expression")
        output := Buffer(8, 0)
        status := DllCall(Numpy.Proc("cnp_safe_eval_v2"),
            "Ptr", expressionBuffer, "Ptr", output, "Int")
        Numpy.CheckStatus(status, "Numpy.SafeEval")
        return NumGet(output, 0, "Double")
    }

    static Char_Add(left, right) {
        Numpy.Init()
        leftInput := Numpy._CharInputPointers(left, "Numpy.Char_Add left")
        rightInput := Numpy._CharInputPointers(right, "Numpy.Char_Add right")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_char_add"),
            "Ptr", leftInput[1], "Int64", left.Length,
            "Ptr", rightInput[1], "Int64", right.Length, "Ptr")
        return Numpy._CharStringResult(
            handle, "Numpy.Char_Add (cnp_char_add)")
    }

    static Char_Multiply(values, repeats) {
        Numpy.Init()
        input := Numpy._CharInputPointers(
            values, "Numpy.Char_Multiply values")
        repeatBuffer := Numpy._CharRepeatBuffer(
            repeats, "Numpy.Char_Multiply repeats")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_char_multiply"),
            "Ptr", input[1], "Int64", values.Length,
            "Ptr", repeatBuffer, "Int64", repeats.Length, "Ptr")
        return Numpy._CharStringResult(
            handle, "Numpy.Char_Multiply (cnp_char_multiply)")
    }

    static Char_Upper(values) =>
        Numpy._CharUnaryString(values, "cnp_char_upper", "Numpy.Char_Upper")

    static Char_Lower(values) =>
        Numpy._CharUnaryString(values, "cnp_char_lower", "Numpy.Char_Lower")

    static Char_Strip(values, chars := unset) =>
        IsSet(chars)
            ? Numpy._CharStrip(values, chars, "cnp_char_strip", "Numpy.Char_Strip")
            : Numpy._CharStrip(values, unset, "cnp_char_strip", "Numpy.Char_Strip")

    static Char_Lstrip(values, chars := unset) =>
        IsSet(chars)
            ? Numpy._CharStrip(values, chars, "cnp_char_lstrip", "Numpy.Char_Lstrip")
            : Numpy._CharStrip(values, unset, "cnp_char_lstrip", "Numpy.Char_Lstrip")

    static Char_Rstrip(values, chars := unset) =>
        IsSet(chars)
            ? Numpy._CharStrip(values, chars, "cnp_char_rstrip", "Numpy.Char_Rstrip")
            : Numpy._CharStrip(values, unset, "cnp_char_rstrip", "Numpy.Char_Rstrip")

    static Char_Center(values, width, fillchar := " ") =>
        Numpy._CharJustify(
            values, width, fillchar, "cnp_char_center", "Numpy.Char_Center")

    static Char_Ljust(values, width, fillchar := " ") =>
        Numpy._CharJustify(
            values, width, fillchar, "cnp_char_ljust", "Numpy.Char_Ljust")

    static Char_Rjust(values, width, fillchar := " ") =>
        Numpy._CharJustify(
            values, width, fillchar, "cnp_char_rjust", "Numpy.Char_Rjust")

    static Char_Zfill(values, width) {
        Numpy.Init()
        Numpy._CharRequireInteger(width, "Numpy.Char_Zfill width")
        input := Numpy._CharInputPointers(values, "Numpy.Char_Zfill values")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_char_zfill"),
            "Ptr", input[1], "Int64", values.Length,
            "Int64", width, "Ptr")
        return Numpy._CharStringResult(
            handle, "Numpy.Char_Zfill (cnp_char_zfill)")
    }

    static Char_Strlen(values) =>
        Numpy._CharUnaryInteger(values, "cnp_char_strlen", "Numpy.Char_Strlen")

    static Char_Count(values, substring) =>
        Numpy._CharSubstringInteger(
            values, substring, "cnp_char_count", "Numpy.Char_Count")

    static Char_Find(values, substring) =>
        Numpy._CharSubstringInteger(
            values, substring, "cnp_char_find", "Numpy.Char_Find")

    static Char_Replace(values, oldString, newString, count := -1) {
        Numpy.Init()
        Numpy._CharRequireInteger(count, "Numpy.Char_Replace count")
        input := Numpy._CharInputPointers(
            values, "Numpy.Char_Replace values")
        oldBuffer := Numpy.Utf8Buffer(
            oldString, "Numpy.Char_Replace oldString")
        newBuffer := Numpy.Utf8Buffer(
            newString, "Numpy.Char_Replace newString")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_char_replace"),
            "Ptr", input[1], "Int64", values.Length,
            "Ptr", oldBuffer, "Ptr", newBuffer, "Int64", count, "Ptr")
        return Numpy._CharStringResult(
            handle, "Numpy.Char_Replace (cnp_char_replace)")
    }

    static Char_Join(values, separator) {
        Numpy.Init()
        input := Numpy._CharInputPointers(values, "Numpy.Char_Join values")
        separatorBuffer := Numpy.Utf8Buffer(
            separator, "Numpy.Char_Join separator")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_char_join_v2"),
            "Ptr", input[1], "Int64", values.Length,
            "Ptr", separatorBuffer, "Ptr")
        return Numpy._CharStringResult(
            handle, "Numpy.Char_Join (cnp_char_join_v2)")
    }

    static Char_Split(values, sep := unset, maxsplit := -1) {
        Numpy.Init()
        if !(values is Array)
            throw TypeError("Numpy.Char_Split values must be an Array")

        count := values.Length
        inputPointers := Buffer(Max(count, 1) * A_PtrSize, 0)
        inputBuffers := []
        for index, value in values {
            inputBuffer := Numpy.Utf8Buffer(
                value, "Numpy.Char_Split value " index)
            inputBuffers.Push(inputBuffer)
            NumPut("Ptr", inputBuffer.Ptr,
                inputPointers, (index - 1) * A_PtrSize)
        }

        separatorPointer := 0
        if IsSet(sep) {
            separatorBuffer := Numpy.Utf8Buffer(
                sep, "Numpy.Char_Split separator")
            separatorPointer := separatorBuffer.Ptr
        }

        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        nativeResult := DllCall(Numpy.Proc("cnp_char_split_v2"),
            "Ptr", inputPointers, "Int64", count,
            "Ptr", separatorPointer, "Int64", maxsplit, "Ptr")
        if !nativeResult {
            status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
            if status != 0
                Numpy.CheckStatus(status, "Numpy.Char_Split")
            throw Error(
                "Numpy.Char_Split returned null without a native error", -1)
        }

        try {
            outerCount := DllCall(
                Numpy.Proc("cnp_string_list_outer_count"),
                "Ptr", nativeResult, "Int64")
            if outerCount < 0 {
                status := DllCall(
                    Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
                Numpy.CheckStatus(status, "Numpy.Char_Split")
            }
            if outerCount != count
                throw Error(
                    "Numpy.Char_Split returned an invalid outer count", -1)

            result := []
            loop outerCount {
                row := A_Index - 1
                tokenCount := DllCall(
                    Numpy.Proc("cnp_string_list_token_count"),
                    "Ptr", nativeResult, "Int64", row, "Int64")
                if tokenCount < 0 {
                    status := DllCall(
                        Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
                    Numpy.CheckStatus(status, "Numpy.Char_Split")
                }
                tokens := []
                loop tokenCount {
                    tokenPointer := DllCall(
                        Numpy.Proc("cnp_string_list_get"),
                        "Ptr", nativeResult,
                        "Int64", row, "Int64", A_Index - 1, "Ptr")
                    if !tokenPointer {
                        status := DllCall(
                            Numpy.Proc("cnp_get_error"),
                            "Ptr", 0, "Int")
                        if status != 0
                            Numpy.CheckStatus(status, "Numpy.Char_Split")
                        throw Error(
                            "Numpy.Char_Split returned a null token", -1)
                    }
                    tokens.Push(StrGet(tokenPointer, "UTF-8"))
                }
                result.Push(tokens)
            }
            return result
        } finally {
            DllCall(Numpy.Proc("cnp_string_list_free"),
                "Ptr", nativeResult)
        }
    }

    ; =========================================================================
    ; NumPy-style static facade
    ; =========================================================================

    static Add(left, right, out := unset) {
        static allocatingProc := 0
        static intoProc := 0
        static cachedHandle := 0
        if !allocatingProc || cachedHandle != Numpy.DllHandle {
            allocatingProc := Numpy.Proc("cnp_ahk_add")
            intoProc := Numpy.Proc("cnp_ahk_add_into")
            cachedHandle := Numpy.DllHandle
        }
        if IsSet(out) {
            status := DllCall(intoProc,
                "Ptr", left.Handle, "Ptr", right.Handle,
                "Ptr", out.Handle, "Int")
            Numpy.CheckStatus(status, "Numpy.Add")
            return out
        }
        handle := DllCall(allocatingProc,
            "Ptr", left.Handle, "Ptr", right.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Add")
    }

    static Subtract(left, right) {
        Numpy._RequireSetPair(left, right, "Numpy.Subtract")
        handle := DllCall(Numpy.Proc("cnp_ahk_subtract"),
            "Ptr", left.Handle, "Ptr", right.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Subtract")
    }

    static Multiply(left, right) {
        Numpy._RequireSetPair(left, right, "Numpy.Multiply")
        handle := DllCall(Numpy.Proc("cnp_ahk_multiply"),
            "Ptr", left.Handle, "Ptr", right.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Multiply")
    }

    static Divide(left, right) {
        Numpy._RequireSetPair(left, right, "Numpy.Divide")
        handle := DllCall(Numpy.Proc("cnp_ahk_divide"),
            "Ptr", left.Handle, "Ptr", right.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Divide")
    }

    static TrueDivide(left, right) {
        Numpy._RequireSetPair(left, right, "Numpy.TrueDivide")
        handle := DllCall(Numpy.Proc("cnp_ahk_true_divide"),
            "Ptr", left.Handle, "Ptr", right.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.TrueDivide")
    }

    static FloorDivide(left, right) {
        Numpy._RequireSetPair(left, right, "Numpy.FloorDivide")
        handle := DllCall(Numpy.Proc("cnp_ahk_floor_divide"),
            "Ptr", left.Handle, "Ptr", right.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.FloorDivide")
    }

    static Divmod(left, right) {
        Numpy._RequireSetPair(left, right, "Numpy.Divmod")
        results := Buffer(2 * A_PtrSize, 0)
        status := DllCall(Numpy.Proc("cnp_ahk_divmod"),
            "Ptr", left.Handle, "Ptr", right.Handle,
            "Ptr", results.Ptr, "Int", 2, "Int")
        Numpy.CheckStatus(status, "Numpy.Divmod")
        return Numpy.WrapHandleBuffer(results, 2, "Numpy.Divmod")
    }

    static Power(left, right) {
        Numpy._RequireSetPair(left, right, "Numpy.Power")
        handle := DllCall(Numpy.Proc("cnp_ahk_power"),
            "Ptr", left.Handle, "Ptr", right.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Power")
    }

    static FloatPower(left, right) {
        Numpy._RequireSetPair(left, right, "Numpy.FloatPower")
        handle := DllCall(Numpy.Proc("cnp_ahk_float_power"),
            "Ptr", left.Handle, "Ptr", right.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.FloatPower")
    }

    static Heaviside(left, right) {
        Numpy._RequireSetPair(left, right, "Numpy.Heaviside")
        handle := DllCall(Numpy.Proc("cnp_ahk_heaviside"),
            "Ptr", left.Handle, "Ptr", right.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Heaviside")
    }

    static Gcd(left, right) {
        Numpy._RequireSetPair(left, right, "Numpy.Gcd")
        handle := DllCall(Numpy.Proc("cnp_ahk_gcd"),
            "Ptr", left.Handle, "Ptr", right.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Gcd")
    }

    static Lcm(left, right) {
        Numpy._RequireSetPair(left, right, "Numpy.Lcm")
        handle := DllCall(Numpy.Proc("cnp_ahk_lcm"),
            "Ptr", left.Handle, "Ptr", right.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Lcm")
    }

    static Mod(left, right) {
        Numpy._RequireSetPair(left, right, "Numpy.Mod")
        handle := DllCall(Numpy.Proc("cnp_ahk_mod"),
            "Ptr", left.Handle, "Ptr", right.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Mod")
    }

    static Remainder(left, right) {
        Numpy._RequireSetPair(left, right, "Numpy.Remainder")
        handle := DllCall(Numpy.Proc("cnp_ahk_remainder"),
            "Ptr", left.Handle, "Ptr", right.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Remainder")
    }

    static Fmod(left, right) {
        Numpy._RequireSetPair(left, right, "Numpy.Fmod")
        handle := DllCall(Numpy.Proc("cnp_ahk_fmod"),
            "Ptr", left.Handle, "Ptr", right.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Fmod")
    }

    static Negative(source) {
        Numpy._RequireSplitSource(source, "Numpy.Negative")
        handle := DllCall(Numpy.Proc("cnp_ahk_negative"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Negative")
    }

    static Positive(source) {
        Numpy._RequireSplitSource(source, "Numpy.Positive")
        handle := DllCall(Numpy.Proc("cnp_ahk_positive"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Positive")
    }

    static Sign(source) {
        Numpy._RequireSplitSource(source, "Numpy.Sign")
        handle := DllCall(Numpy.Proc("cnp_ahk_sign"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Sign")
    }

    static IsNan(source) {
        Numpy._RequireSplitSource(source, "Numpy.IsNan")
        handle := DllCall(Numpy.Proc("cnp_ahk_isnan"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.IsNan")
    }

    static IsInf(source) {
        Numpy._RequireSplitSource(source, "Numpy.IsInf")
        handle := DllCall(Numpy.Proc("cnp_ahk_isinf"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.IsInf")
    }

    static IsFinite(source) {
        Numpy._RequireSplitSource(source, "Numpy.IsFinite")
        handle := DllCall(Numpy.Proc("cnp_ahk_isfinite"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.IsFinite")
    }

    static Signbit(source) {
        Numpy._RequireSplitSource(source, "Numpy.Signbit")
        handle := DllCall(Numpy.Proc("cnp_ahk_signbit"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Signbit")
    }

    static IsComplexObj(source) {
        return Numpy._ObjectKindPredicate(
            source, "Numpy.IsComplexObj", "cnp_ahk_iscomplexobj")
    }

    static IsRealObj(source) {
        return Numpy._ObjectKindPredicate(
            source, "Numpy.IsRealObj", "cnp_ahk_isrealobj")
    }

    static IsScalar(source) {
        if source is Numpy.NdArray
            return Numpy._ObjectKindPredicate(
                source, "Numpy.IsScalar", "cnp_ahk_isscalar")
        sourceType := Type(source)
        return sourceType = "Integer" || sourceType = "Float"
            || sourceType = "String" || sourceType = "Buffer"
    }

    static _ObjectKindPredicate(source, operation, nativeName) {
        Numpy._RequireSplitSource(source, operation)
        Numpy.Init()
        result := DllCall(Numpy.Proc(nativeName),
            "Ptr", source.Handle, "Int")
        if result < 0
            Numpy.CheckStatus(result, operation)
        return result != 0
    }

    static Reciprocal(source) {
        Numpy._RequireSplitSource(source, "Numpy.Reciprocal")
        handle := DllCall(Numpy.Proc("cnp_ahk_reciprocal"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Reciprocal")
    }

    static Square(source) {
        Numpy._RequireSplitSource(source, "Numpy.Square")
        handle := DllCall(Numpy.Proc("cnp_ahk_square"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Square")
    }

    static Conj(source) {
        Numpy._RequireSplitSource(source, "Numpy.Conj")
        handle := DllCall(Numpy.Proc("cnp_ahk_conj"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Conj")
    }

    static Conjugate(source) {
        Numpy._RequireSplitSource(source, "Numpy.Conjugate")
        handle := DllCall(Numpy.Proc("cnp_ahk_conjugate"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Conjugate")
    }

    static Clip(source, aMin := unset, aMax := unset) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.Clip source must be an NdArray")

        minimumBound := [0, 0]
        maximumBound := [0, 0]
        try {
            if IsSet(aMin)
                minimumBound := Numpy._ClipBound(
                    aMin, "Numpy.Clip a_min")
            if IsSet(aMax)
                maximumBound := Numpy._ClipBound(
                    aMax, "Numpy.Clip a_max")
            handle := DllCall(Numpy.Proc("cnp_ahk_clip_array"),
                "Ptr", source.Handle,
                "Ptr", minimumBound[1],
                "Ptr", maximumBound[1], "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Clip")
        } finally {
            maximumBound := 0
            minimumBound := 0
        }
    }

    static BitwiseCount(source) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.BitwiseCount source must be an NdArray")
        Numpy.Init()
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_bitwise_count"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.BitwiseCount (cnp_bitwise_count)")
    }

    static Item(source, flatIndex := 0) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.Item source must be an NdArray")
        if Type(flatIndex) != "Integer"
            throw TypeError("Numpy.Item flat index must be an Integer")
        Numpy.Init()
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        value := DllCall(Numpy.Proc("cnp_item"),
            "Ptr", source.Handle, "Int64", flatIndex, "Double")
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        Numpy.CheckStatus(status, "Numpy.Item (cnp_item)")
        return value
    }

    static Histogram(source, bins := 10, rangeMin := 0.0, rangeMax := 0.0) {
        Numpy._RequireSplitSource(source, "Numpy.Histogram")
        if Type(bins) != "Integer"
            throw TypeError("Numpy.Histogram bins must be an Integer")
        if (Type(rangeMin) != "Integer" && Type(rangeMin) != "Float")
            || (Type(rangeMax) != "Integer" && Type(rangeMax) != "Float")
            throw TypeError("Numpy.Histogram range endpoints must be numeric")
        Numpy.Init()
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_histogram"),
            "Ptr", source.Handle, "Int64", bins,
            "Double", rangeMin, "Double", rangeMax, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Histogram (cnp_histogram)")
    }

    static Histogram2d(x, y, bins := 10) {
        Numpy._RequireSetPair(x, y, "Numpy.Histogram2d")
        if Type(bins) != "Integer"
            throw TypeError("Numpy.Histogram2d bins must be an Integer")
        Numpy.Init()
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_histogram2d"),
            "Ptr", x.Handle, "Ptr", y.Handle, "Int64", bins, "Ptr")
        return Numpy.WrapHandle(handle,
            "Numpy.Histogram2d (cnp_histogram2d)")
    }

    static Interp(x, xp, fp) {
        Numpy._RequireSplitSource(x, "Numpy.Interp x")
        Numpy._RequireSplitSource(xp, "Numpy.Interp xp")
        Numpy._RequireSplitSource(fp, "Numpy.Interp fp")
        Numpy.Init()
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_interp"),
            "Ptr", x.Handle, "Ptr", xp.Handle, "Ptr", fp.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Interp (cnp_interp)")
    }

    static InterpNd(x, xp, fp, left, right) {
        Numpy._RequireSplitSource(x, "Numpy.InterpNd x")
        Numpy._RequireSplitSource(xp, "Numpy.InterpNd xp")
        Numpy._RequireSplitSource(fp, "Numpy.InterpNd fp")
        if (Type(left) != "Integer" && Type(left) != "Float")
            || (Type(right) != "Integer" && Type(right) != "Float")
            throw TypeError("Numpy.InterpNd bounds must be numeric")
        Numpy.Init()
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_interp_nd"),
            "Ptr", x.Handle, "Ptr", xp.Handle, "Ptr", fp.Handle,
            "Double", left, "Double", right, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.InterpNd (cnp_interp_nd)")
    }

    static NanToNum(source, nanValue, positiveInfinity, negativeInfinity) {
        Numpy._RequireSplitSource(source, "Numpy.NanToNum")
        for value in [nanValue, positiveInfinity, negativeInfinity] {
            if Type(value) != "Integer" && Type(value) != "Float"
                throw TypeError("Numpy.NanToNum replacements must be numeric")
        }
        Numpy.Init()
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_nan_to_num"),
            "Ptr", source.Handle,
            "Double", nanValue,
            "Double", positiveInfinity,
            "Double", negativeInfinity, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.NanToNum (cnp_nan_to_num)")
    }

    static Vander(source, columns := -1, increasing := false) {
        Numpy._RequireSplitSource(source, "Numpy.Vander")
        if Type(columns) != "Integer"
            throw TypeError("Numpy.Vander columns must be an Integer")
        if Type(increasing) != "Integer"
            throw TypeError("Numpy.Vander increasing must be Boolean")
        Numpy.Init()
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_vander"),
            "Ptr", source.Handle, "Int64", columns,
            "Char", increasing ? 1 : 0, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Vander (cnp_vander)")
    }

    static Diff(source, n := 1, axis := -1) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.Diff source must be an NdArray")
        if Type(n) != "Integer" || Type(axis) != "Integer"
            throw TypeError("Numpy.Diff n and axis must be Integers")
        Numpy.Init()
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_diff"),
            "Ptr", source.Handle, "Int", n, "Int", axis, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Diff (cnp_diff)")
    }

    static Gradient(source, axis := -1) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.Gradient source must be an NdArray")
        if Type(axis) != "Integer"
            throw TypeError("Numpy.Gradient axis must be an Integer")
        Numpy.Init()
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_gradient"),
            "Ptr", source.Handle, "Int", axis, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Gradient (cnp_gradient)")
    }

    static Unwrap(source, discont := 3.141592653589793) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.Unwrap source must be an NdArray")
        if Type(discont) != "Integer" && Type(discont) != "Float"
            throw TypeError("Numpy.Unwrap discont must be numeric")
        Numpy.Init()
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_unwrap"),
            "Ptr", source.Handle, "Double", discont, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Unwrap (cnp_unwrap)")
    }

    static Around(source, decimals := 0) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.Around source must be an NdArray")
        if Type(decimals) != "Integer"
            throw TypeError("Numpy.Around decimals must be an integer")
        Numpy.Init()
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_around"),
                "Ptr", source.Handle, "Int", decimals, "Ptr"),
            "Numpy.Around")
    }

    static Round(source, decimals := 0) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.Round source must be an NdArray")
        if Type(decimals) != "Integer"
            throw TypeError("Numpy.Round decimals must be an integer")
        Numpy.Init()
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_round"),
                "Ptr", source.Handle, "Int", decimals, "Ptr"),
            "Numpy.Round")
    }

    static _UnaryRounding(source, symbol, operation) {
        if !(source is Numpy.NdArray)
            throw TypeError(operation " source must be an NdArray")
        Numpy.Init()
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc(symbol),
                "Ptr", source.Handle, "Ptr"),
            operation)
    }

    static Rint(source) => Numpy._UnaryRounding(
        source, "cnp_rint", "Numpy.Rint")
    static Fix(source) => Numpy._UnaryRounding(
        source, "cnp_fix", "Numpy.Fix")
    static Trunc(source) => Numpy._UnaryRounding(
        source, "cnp_trunc", "Numpy.Trunc")
    static Floor(source) => Numpy._UnaryRounding(
        source, "cnp_floor", "Numpy.Floor")
    static Ceil(source) => Numpy._UnaryRounding(
        source, "cnp_ceil", "Numpy.Ceil")

    static Sqrt(source, out := unset) {
        Numpy._RequireSplitSource(source, "Numpy.Sqrt")
        if IsSet(out)
            return source.SqrtInto(out)
        handle := DllCall(Numpy.Proc("cnp_ahk_sqrt"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Sqrt")
    }

    static Cbrt(source) {
        Numpy._RequireSplitSource(source, "Numpy.Cbrt")
        handle := DllCall(Numpy.Proc("cnp_ahk_cbrt"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Cbrt")
    }

    static Cos(source) {
        Numpy._RequireSplitSource(source, "Numpy.Cos")
        handle := DllCall(Numpy.Proc("cnp_ahk_cos"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Cos")
    }

    static Sin(source) {
        Numpy._RequireSplitSource(source, "Numpy.Sin")
        handle := DllCall(Numpy.Proc("cnp_ahk_sin"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Sin")
    }

    static Tan(source) {
        Numpy._RequireSplitSource(source, "Numpy.Tan")
        handle := DllCall(Numpy.Proc("cnp_ahk_tan"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Tan")
    }

    static Arcsin(source) {
        Numpy._RequireSplitSource(source, "Numpy.Arcsin")
        handle := DllCall(Numpy.Proc("cnp_ahk_arcsin"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Arcsin")
    }

    static Arccos(source) {
        Numpy._RequireSplitSource(source, "Numpy.Arccos")
        handle := DllCall(Numpy.Proc("cnp_ahk_arccos"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Arccos")
    }

    static Arctan(source) {
        Numpy._RequireSplitSource(source, "Numpy.Arctan")
        handle := DllCall(Numpy.Proc("cnp_ahk_arctan"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Arctan")
    }

    static Arctan2(y, x) {
        Numpy._RequireSplitSource(y, "Numpy.Arctan2 y")
        Numpy._RequireSplitSource(x, "Numpy.Arctan2 x")
        handle := DllCall(Numpy.Proc("cnp_ahk_arctan2"),
            "Ptr", y.Handle, "Ptr", x.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Arctan2")
    }

    static Hypot(x, y) {
        Numpy._RequireSplitSource(x, "Numpy.Hypot x")
        Numpy._RequireSplitSource(y, "Numpy.Hypot y")
        handle := DllCall(Numpy.Proc("cnp_ahk_hypot"),
            "Ptr", x.Handle, "Ptr", y.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Hypot")
    }

    static _AngleConversion(source, symbol, operation) {
        Numpy._RequireSplitSource(source, operation " source")
        handle := DllCall(Numpy.Proc(symbol),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, operation)
    }

    static Degrees(source) => Numpy._AngleConversion(
        source, "cnp_ahk_degrees", "Numpy.Degrees")
    static Radians(source) => Numpy._AngleConversion(
        source, "cnp_ahk_radians", "Numpy.Radians")
    static Deg2rad(source) => Numpy._AngleConversion(
        source, "cnp_ahk_deg2rad", "Numpy.Deg2rad")
    static Rad2deg(source) => Numpy._AngleConversion(
        source, "cnp_ahk_rad2deg", "Numpy.Rad2deg")

    static Sinh(source) {
        Numpy._RequireSplitSource(source, "Numpy.Sinh")
        handle := DllCall(Numpy.Proc("cnp_ahk_sinh"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Sinh")
    }

    static Cosh(source) {
        Numpy._RequireSplitSource(source, "Numpy.Cosh")
        handle := DllCall(Numpy.Proc("cnp_ahk_cosh"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Cosh")
    }

    static Tanh(source) {
        Numpy._RequireSplitSource(source, "Numpy.Tanh")
        handle := DllCall(Numpy.Proc("cnp_ahk_tanh"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Tanh")
    }

    static Arcsinh(source) {
        Numpy._RequireSplitSource(source, "Numpy.Arcsinh")
        handle := DllCall(Numpy.Proc("cnp_ahk_arcsinh"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Arcsinh")
    }

    static Arccosh(source) {
        Numpy._RequireSplitSource(source, "Numpy.Arccosh")
        handle := DllCall(Numpy.Proc("cnp_ahk_arccosh"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Arccosh")
    }

    static Arctanh(source) {
        Numpy._RequireSplitSource(source, "Numpy.Arctanh")
        handle := DllCall(Numpy.Proc("cnp_ahk_arctanh"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Arctanh")
    }

    static Exp(source) {
        Numpy._RequireSplitSource(source, "Numpy.Exp")
        handle := DllCall(Numpy.Proc("cnp_ahk_exp"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Exp")
    }

    static Exp2(source) {
        Numpy._RequireSplitSource(source, "Numpy.Exp2")
        handle := DllCall(Numpy.Proc("cnp_ahk_exp2"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Exp2")
    }

    static Expm1(source) {
        Numpy._RequireSplitSource(source, "Numpy.Expm1")
        handle := DllCall(Numpy.Proc("cnp_ahk_expm1"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Expm1")
    }

    static Log(source) {
        Numpy._RequireSplitSource(source, "Numpy.Log")
        handle := DllCall(Numpy.Proc("cnp_ahk_log"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Log")
    }

    static Log2(source) {
        Numpy._RequireSplitSource(source, "Numpy.Log2")
        handle := DllCall(Numpy.Proc("cnp_ahk_log2"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Log2")
    }

    static Log10(source) {
        Numpy._RequireSplitSource(source, "Numpy.Log10")
        handle := DllCall(Numpy.Proc("cnp_ahk_log10"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Log10")
    }

    static Log1p(source) {
        Numpy._RequireSplitSource(source, "Numpy.Log1p")
        handle := DllCall(Numpy.Proc("cnp_ahk_log1p"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Log1p")
    }

    static Logaddexp(left, right) {
        Numpy._RequireSplitSource(left, "Numpy.Logaddexp left")
        Numpy._RequireSplitSource(right, "Numpy.Logaddexp right")
        handle := DllCall(Numpy.Proc("cnp_ahk_logaddexp"),
            "Ptr", left.Handle, "Ptr", right.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Logaddexp")
    }

    static Logaddexp2(left, right) {
        Numpy._RequireSplitSource(left, "Numpy.Logaddexp2 left")
        Numpy._RequireSplitSource(right, "Numpy.Logaddexp2 right")
        handle := DllCall(Numpy.Proc("cnp_ahk_logaddexp2"),
            "Ptr", left.Handle, "Ptr", right.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Logaddexp2")
    }

    static _Comparison(left, right, symbol, operation) {
        Numpy._RequireSetPair(left, right, operation)
        handle := DllCall(Numpy.Proc(symbol),
            "Ptr", left.Handle, "Ptr", right.Handle, "Ptr")
        return Numpy.WrapHandle(handle, operation)
    }

    static Equal(left, right) => Numpy._Comparison(
        left, right, "cnp_ahk_equal", "Numpy.Equal")
    static NotEqual(left, right) => Numpy._Comparison(
        left, right, "cnp_ahk_not_equal", "Numpy.NotEqual")
    static Less(left, right) => Numpy._Comparison(
        left, right, "cnp_ahk_less", "Numpy.Less")
    static LessEqual(left, right) => Numpy._Comparison(
        left, right, "cnp_ahk_less_equal", "Numpy.LessEqual")
    static Greater(left, right) => Numpy._Comparison(
        left, right, "cnp_ahk_greater", "Numpy.Greater")
    static GreaterEqual(left, right) => Numpy._Comparison(
        left, right, "cnp_ahk_greater_equal", "Numpy.GreaterEqual")

    static _Extrema(left, right, symbol, operation) {
        Numpy._RequireSetPair(left, right, operation)
        handle := DllCall(Numpy.Proc(symbol),
            "Ptr", left.Handle, "Ptr", right.Handle, "Ptr")
        return Numpy.WrapHandle(handle, operation)
    }

    static Maximum(left, right) => Numpy._Extrema(
        left, right, "cnp_ahk_maximum", "Numpy.Maximum")
    static Minimum(left, right) => Numpy._Extrema(
        left, right, "cnp_ahk_minimum", "Numpy.Minimum")
    static Fmax(left, right) => Numpy._Extrema(
        left, right, "cnp_ahk_fmax", "Numpy.Fmax")
    static Fmin(left, right) => Numpy._Extrema(
        left, right, "cnp_ahk_fmin", "Numpy.Fmin")

    static _LogicalBinary(left, right, symbol, operation) {
        Numpy._RequireSetPair(left, right, operation)
        handle := DllCall(Numpy.Proc(symbol),
            "Ptr", left.Handle, "Ptr", right.Handle, "Ptr")
        return Numpy.WrapHandle(handle, operation)
    }

    static LogicalAnd(left, right) => Numpy._LogicalBinary(
        left, right, "cnp_ahk_logical_and", "Numpy.LogicalAnd")
    static LogicalOr(left, right) => Numpy._LogicalBinary(
        left, right, "cnp_ahk_logical_or", "Numpy.LogicalOr")
    static LogicalXor(left, right) => Numpy._LogicalBinary(
        left, right, "cnp_ahk_logical_xor", "Numpy.LogicalXor")
    static LogicalNot(source) {
        Numpy._RequireSplitSource(source, "Numpy.LogicalNot")
        handle := DllCall(Numpy.Proc("cnp_ahk_logical_not"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.LogicalNot")
    }

    static _BitwiseBinary(left, right, symbol, operation) {
        Numpy._RequireSetPair(left, right, operation)
        handle := DllCall(Numpy.Proc(symbol),
            "Ptr", left.Handle, "Ptr", right.Handle, "Ptr")
        return Numpy.WrapHandle(handle, operation)
    }

    static _BitwiseUnary(source, symbol, operation) {
        Numpy._RequireSplitSource(source, operation)
        handle := DllCall(Numpy.Proc(symbol), "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, operation)
    }

    static BitwiseAnd(left, right) => Numpy._BitwiseBinary(
        left, right, "cnp_ahk_bitwise_and", "Numpy.BitwiseAnd")
    static BitwiseOr(left, right) => Numpy._BitwiseBinary(
        left, right, "cnp_ahk_bitwise_or", "Numpy.BitwiseOr")
    static BitwiseXor(left, right) => Numpy._BitwiseBinary(
        left, right, "cnp_ahk_bitwise_xor", "Numpy.BitwiseXor")
    static LeftShift(left, right) => Numpy._BitwiseBinary(
        left, right, "cnp_ahk_left_shift", "Numpy.LeftShift")
    static RightShift(left, right) => Numpy._BitwiseBinary(
        left, right, "cnp_ahk_right_shift", "Numpy.RightShift")
    static Invert(source) => Numpy._BitwiseUnary(
        source, "cnp_ahk_invert", "Numpy.Invert")
    static BitwiseNot(source) => Numpy._BitwiseUnary(
        source, "cnp_ahk_bitwise_not", "Numpy.BitwiseNot")

    static Absolute(source) => source.Absolute()
    static Fabs(source) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.Fabs source must be an NdArray")
        return source.Fabs()
    }
    static Sum(source, axis := unset) =>
        IsSet(axis) ? source.Sum(axis) : source.Sum()
    static Prod(source, axis := unset) =>
        IsSet(axis) ? source.Prod(axis) : source.Prod()
    static Mean(source, axis := unset) =>
        IsSet(axis) ? source.Mean(axis) : source.Mean()
    static Average(source, axis := unset, weights := unset) {
        Numpy._RequireSplitSource(source, "Numpy.Average")
        if IsSet(axis) {
            if IsSet(weights)
                return source.Average(axis, weights)
            return source.Average(axis)
        }
        if IsSet(weights)
            return source.Average(, weights)
        return source.Average()
    }
    static Var(source, axis := unset, ddof := 0) {
        if IsSet(axis)
            return source.Var(axis, ddof)
        return source.Var(, ddof)
    }
    static Std(source, axis := unset, ddof := 0) {
        if IsSet(axis)
            return source.Std(axis, ddof)
        return source.Std(, ddof)
    }
    static Max(source, axis := unset) =>
        IsSet(axis) ? source.Max(axis) : source.Max()
    static Min(source, axis := unset) =>
        IsSet(axis) ? source.Min(axis) : source.Min()
    static Argmax(source, axis := unset) =>
        IsSet(axis) ? source.Argmax(axis) : source.Argmax()
    static Argmin(source, axis := unset) =>
        IsSet(axis) ? source.Argmin(axis) : source.Argmin()
    static Any(source, axis := unset) =>
        IsSet(axis) ? source.Any(axis) : source.Any()
    static All(source, axis := unset) =>
        IsSet(axis) ? source.All(axis) : source.All()
    static Ptp(source, axis := unset) =>
        IsSet(axis) ? source.Ptp(axis) : source.Ptp()

    static Cumsum(source, axis := unset, out := unset) {
        if IsSet(out)
            return IsSet(axis) ? source.CumsumInto(out, axis) :
                source.CumsumInto(out)
        return IsSet(axis) ? source.Cumsum(axis) : source.Cumsum()
    }

    static Cumprod(source, axis := unset) =>
        IsSet(axis) ? source.Cumprod(axis) : source.Cumprod()
    static Nansum(source, axis := unset) =>
        IsSet(axis) ? source.Nansum(axis) : source.Nansum()
    static Nanprod(source, axis := unset) =>
        IsSet(axis) ? source.Nanprod(axis) : source.Nanprod()
    static Nanmean(source, axis := unset) =>
        IsSet(axis) ? source.Nanmean(axis) : source.Nanmean()
    static Nanvar(source, axis := unset, ddof := 0) {
        if IsSet(axis)
            return source.Nanvar(axis, ddof)
        return source.Nanvar(, ddof)
    }
    static Nanstd(source, axis := unset, ddof := 0) {
        if IsSet(axis)
            return source.Nanstd(axis, ddof)
        return source.Nanstd(, ddof)
    }
    static Nanmax(source, axis := unset) =>
        IsSet(axis) ? source.Nanmax(axis) : source.Nanmax()
    static Nanmin(source, axis := unset) =>
        IsSet(axis) ? source.Nanmin(axis) : source.Nanmin()
    static Nanargmax(source, axis := unset) =>
        IsSet(axis) ? source.Nanargmax(axis) : source.Nanargmax()
    static Nanargmin(source, axis := unset) =>
        IsSet(axis) ? source.Nanargmin(axis) : source.Nanargmin()
    static Median(source, axis := unset) =>
        IsSet(axis) ? source.Median(axis) : source.Median()
    static Corrcoef(source, other := unset) {
        Numpy._RequireSplitSource(source, "Numpy.Corrcoef source")
        otherPointer := 0
        if IsSet(other) {
            Numpy._RequireSplitSource(other, "Numpy.Corrcoef other")
            otherPointer := other.Handle
        }
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_corrcoef"),
            "Ptr", source.Handle, "Ptr", otherPointer, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Corrcoef")
    }

    static Cov(source, other := unset, rowvar := true, ddof := 1) {
        Numpy._RequireSplitSource(source, "Numpy.Cov source")
        otherPointer := 0
        if IsSet(other) {
            Numpy._RequireSplitSource(other, "Numpy.Cov other")
            otherPointer := other.Handle
        }
        if Type(rowvar) != "Integer"
            throw TypeError("Numpy.Cov rowvar must be a Boolean")
        if Type(ddof) != "Integer"
            throw TypeError("Numpy.Cov ddof must be an Integer")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_cov"),
            "Ptr", source.Handle, "Ptr", otherPointer,
            "Int", rowvar, "Int", ddof, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Cov")
    }

    static Nanmedian(source, axis := unset) =>
        IsSet(axis) ? source.Nanmedian(axis) : source.Nanmedian()
    static Percentile(source, q, axis := unset) => IsSet(axis) ?
        source.Percentile(q, axis) : source.Percentile(q)
    static Nanpercentile(source, q, axis := unset) => IsSet(axis) ?
        source.Nanpercentile(q, axis) : source.Nanpercentile(q)
    static Quantile(source, q, axis := unset) => IsSet(axis) ?
        source.Quantile(q, axis) : source.Quantile(q)
    static Nanquantile(source, q, axis := unset) => IsSet(axis) ?
        source.Nanquantile(q, axis) : source.Nanquantile(q)
    static Nancumsum(source, axis := unset) =>
        IsSet(axis) ? source.Nancumsum(axis) : source.Nancumsum()
    static Nancumprod(source, axis := unset) =>
        IsSet(axis) ? source.Nancumprod(axis) : source.Nancumprod()

    static Softmax(source, axis := -1) {
        Numpy._RequireSplitSource(source, "Numpy.Softmax")
        if Type(axis) != "Integer"
            throw TypeError("Numpy.Softmax axis must be an Integer")
        handle := DllCall(Numpy.Proc("cnp_ahk_softmax"),
            "Ptr", source.Handle, "Int", axis, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Softmax")
    }

    static LogSoftmax(source, axis := -1) {
        Numpy._RequireSplitSource(source, "Numpy.LogSoftmax")
        if Type(axis) != "Integer"
            throw TypeError("Numpy.LogSoftmax axis must be an Integer")
        handle := DllCall(Numpy.Proc("cnp_ahk_log_softmax"),
            "Ptr", source.Handle, "Int", axis, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.LogSoftmax")
    }

    static Log_Softmax(source, axis := -1) =>
        Numpy.LogSoftmax(source, axis)

    static Trapz(y, x := unset, dx := 1.0, axis := -1) {
        Numpy._RequireSplitSource(y, "Numpy.Trapz")
        if IsSet(x) && !(x is Numpy.NdArray)
            throw TypeError("Numpy.Trapz x must be an NdArray")
        if Type(dx) != "Integer" && Type(dx) != "Float"
            throw TypeError("Numpy.Trapz dx must be numeric")
        if Type(axis) != "Integer"
            throw TypeError("Numpy.Trapz axis must be an Integer")
        handle := DllCall(Numpy.Proc("cnp_ahk_trapz"),
            "Ptr", y.Handle,
            "Ptr", IsSet(x) ? x.Handle : 0,
            "Double", dx, "Int", axis, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Trapz")
    }

    static Angle(source, degrees := false) {
        Numpy._RequireSplitSource(source, "Numpy.Angle")
        handle := DllCall(Numpy.Proc("cnp_ahk_angle"),
            "Ptr", source.Handle, "Int", degrees ? 1 : 0, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Angle")
    }

    static Real(source) {
        Numpy._RequireSplitSource(source, "Numpy.Real")
        handle := DllCall(Numpy.Proc("cnp_ahk_real"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Real")
    }

    static Imag(source) {
        Numpy._RequireSplitSource(source, "Numpy.Imag")
        handle := DllCall(Numpy.Proc("cnp_ahk_imag"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Imag")
    }

    static RealIfClose(source, tol := 100.0) {
        Numpy._RequireSplitSource(source, "Numpy.RealIfClose")
        if Type(tol) != "Integer" && Type(tol) != "Float"
            throw TypeError("Numpy.RealIfClose tol must be numeric")
        handle := DllCall(Numpy.Proc("cnp_ahk_real_if_close"),
            "Ptr", source.Handle, "Double", tol, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.RealIfClose")
    }

    static Convolve(left, right, mode := "full") {
        Numpy._RequireSetPair(left, right, "Numpy.Convolve")
        modeCode := Numpy._ResolveSignalMode(mode, "Numpy.Convolve")
        handle := DllCall(Numpy.Proc("cnp_ahk_convolve"),
            "Ptr", left.Handle, "Ptr", right.Handle,
            "Int", modeCode, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Convolve")
    }

    static Correlate(left, right, mode := "valid") {
        Numpy._RequireSetPair(left, right, "Numpy.Correlate")
        modeCode := Numpy._ResolveSignalMode(mode, "Numpy.Correlate")
        handle := DllCall(Numpy.Proc("cnp_ahk_correlate"),
            "Ptr", left.Handle, "Ptr", right.Handle,
            "Int", modeCode, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Correlate")
    }

    static Packbits(source, axis := unset, bitorder := "big") {
        Numpy._RequireSplitSource(source, "Numpy.Packbits")
        axisNone := !IsSet(axis)
        if !axisNone && Type(axis) != "Integer"
            throw TypeError("Numpy.Packbits axis must be an Integer")
        bitorderCode := Numpy._ResolveBitorder(
            bitorder, "Numpy.Packbits")
        handle := DllCall(Numpy.Proc("cnp_ahk_packbits_v2"),
            "Ptr", source.Handle,
            "Int", axisNone ? 0 : axis,
            "Int", axisNone ? 1 : 0,
            "Int", bitorderCode, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Packbits")
    }

    static Unpackbits(
        source, axis := unset, count := unset, bitorder := "big"
    ) {
        Numpy._RequireSplitSource(source, "Numpy.Unpackbits")
        axisNone := !IsSet(axis)
        countNone := !IsSet(count)
        if !axisNone && Type(axis) != "Integer"
            throw TypeError("Numpy.Unpackbits axis must be an Integer")
        if !countNone && Type(count) != "Integer"
            throw TypeError("Numpy.Unpackbits count must be an Integer")
        bitorderCode := Numpy._ResolveBitorder(
            bitorder, "Numpy.Unpackbits")
        handle := DllCall(Numpy.Proc("cnp_ahk_unpackbits_v2"),
            "Ptr", source.Handle,
            "Int", axisNone ? 0 : axis,
            "Int", axisNone ? 1 : 0,
            "Int64", countNone ? 0 : count,
            "Int", countNone ? 1 : 0,
            "Int", bitorderCode, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Unpackbits")
    }

    static Sort(source, axis := -1, kind := "quicksort") {
        Numpy._RequireSplitSource(source, "Numpy.Sort")
        return source.Sort(axis, kind)
    }

    static Msort(source) {
        Numpy._RequireSplitSource(source, "Numpy.Msort")
        handle := DllCall(Numpy.Proc("cnp_ahk_msort"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "cnp_ahk_msort")
    }

    static SortComplex(source) {
        Numpy._RequireSplitSource(source, "Numpy.SortComplex")
        handle := DllCall(Numpy.Proc("cnp_ahk_sort_complex"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "cnp_ahk_sort_complex")
    }

    static Argsort(source, axis := -1, kind := "quicksort") {
        Numpy._RequireSplitSource(source, "Numpy.Argsort")
        return source.Argsort(axis, kind)
    }

    static Partition(
        source, kth, axis := -1, kind := "introselect"
    ) {
        Numpy._RequireSplitSource(source, "Numpy.Partition")
        return source.Partition(kth, axis, kind)
    }

    static Argpartition(
        source, kth, axis := -1, kind := "introselect"
    ) {
        Numpy._RequireSplitSource(source, "Numpy.Argpartition")
        return source.Argpartition(kth, axis, kind)
    }

    static Searchsorted(
        source, values, side := "left", sorter := unset
    ) {
        Numpy._RequireSplitSource(source, "Numpy.Searchsorted")
        Numpy._RequireSplitSource(values, "Numpy.Searchsorted")
        if Type(side) != "String"
            throw TypeError("Numpy.Searchsorted side must be a String")
        sorterHandle := 0
        if IsSet(sorter) {
            Numpy._RequireSplitSource(sorter, "Numpy.Searchsorted")
            sorterHandle := sorter.Handle
        }
        handle := DllCall(Numpy.Proc("cnp_ahk_searchsorted_v2"),
            "Ptr", source.Handle,
            "Ptr", values.Handle,
            "AStr", side,
            "Ptr", sorterHandle,
            "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Searchsorted")
    }

    static Digitize(source, bins, right := false) {
        Numpy._RequireSplitSource(source, "Numpy.Digitize")
        Numpy._RequireSplitSource(bins, "Numpy.Digitize")
        if right != false && right != true
            throw TypeError("Numpy.Digitize right must be a Boolean")
        handle := DllCall(Numpy.Proc("cnp_ahk_digitize"),
            "Ptr", source.Handle,
            "Ptr", bins.Handle,
            "Int", right ? 1 : 0,
            "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Digitize")
    }

    static Lexsort(keys, axis := -1) {
        Numpy.Init()
        if Type(axis) != "Integer"
            throw TypeError("Numpy.Lexsort axis must be an Integer")
        handles := Numpy.HandleBuffer(keys, "Numpy.Lexsort")
        handle := DllCall(Numpy.Proc("cnp_ahk_lexsort_v2"),
            "Ptr", handles.Ptr,
            "Int", keys.Length,
            "Int", axis,
            "Ptr")
        return Numpy.WrapHandle(handle, "cnp_ahk_lexsort_v2")
    }

    static Unique(
        source, returnIndex := false,
        returnInverse := false, returnCounts := false
    ) {
        Numpy._RequireSplitSource(source, "Numpy.Unique")
        resultCount := 1 + (returnIndex ? 1 : 0) +
            (returnInverse ? 1 : 0) + (returnCounts ? 1 : 0)
        results := Buffer(resultCount * A_PtrSize, 0)
        status := DllCall(Numpy.Proc("cnp_ahk_unique_v2"),
            "Ptr", source.Handle,
            "Int", returnIndex ? 1 : 0,
            "Int", returnInverse ? 1 : 0,
            "Int", returnCounts ? 1 : 0,
            "Ptr", results.Ptr, "Int", resultCount, "Int")
        Numpy.CheckStatus(status, "Numpy.Unique")
        wrapped := Numpy.WrapHandleBuffer(
            results, resultCount, "Numpy.Unique")
        return resultCount = 1 ? wrapped[1] : wrapped
    }

    static Intersect1d(left, right, assumeUnique := false) {
        Numpy._RequireSetPair(left, right, "Numpy.Intersect1d")
        handle := DllCall(Numpy.Proc("cnp_ahk_intersect1d"),
            "Ptr", left.Handle, "Ptr", right.Handle,
            "Int", assumeUnique ? 1 : 0, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Intersect1d")
    }

    static Union1d(left, right) {
        Numpy._RequireSetPair(left, right, "Numpy.Union1d")
        handle := DllCall(Numpy.Proc("cnp_ahk_union1d"),
            "Ptr", left.Handle, "Ptr", right.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Union1d")
    }

    static Setdiff1d(left, right, assumeUnique := false) {
        Numpy._RequireSetPair(left, right, "Numpy.Setdiff1d")
        handle := DllCall(Numpy.Proc("cnp_ahk_setdiff1d"),
            "Ptr", left.Handle, "Ptr", right.Handle,
            "Int", assumeUnique ? 1 : 0, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Setdiff1d")
    }

    static Setxor1d(left, right, assumeUnique := false) {
        Numpy._RequireSetPair(left, right, "Numpy.Setxor1d")
        handle := DllCall(Numpy.Proc("cnp_ahk_setxor1d"),
            "Ptr", left.Handle, "Ptr", right.Handle,
            "Int", assumeUnique ? 1 : 0, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Setxor1d")
    }

    static In1d(
        left, right, assumeUnique := false, invert := false
    ) {
        Numpy._RequireSetPair(left, right, "Numpy.In1d")
        handle := DllCall(Numpy.Proc("cnp_ahk_in1d"),
            "Ptr", left.Handle, "Ptr", right.Handle,
            "Int", assumeUnique ? 1 : 0,
            "Int", invert ? 1 : 0, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.In1d")
    }

    static Isin(
        element, testElements, assumeUnique := false, invert := false
    ) {
        Numpy._RequireSetPair(element, testElements, "Numpy.Isin")
        handle := DllCall(Numpy.Proc("cnp_ahk_isin"),
            "Ptr", element.Handle, "Ptr", testElements.Handle,
            "Int", assumeUnique ? 1 : 0,
            "Int", invert ? 1 : 0, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Isin")
    }

    static Dot(left, right) => Numpy._ProductBinary(
        left, right, "cnp_dot", "Numpy.Dot")

    static DotGeneral(left, right) => Numpy._ProductBinary(
        left, right, "cnp_dot_general", "Numpy.DotGeneral")

    static Dot1D(left, right) => Numpy._ProductBinary(
        left, right, "cnp_dot_1d", "Numpy.Dot1D")

    static Matmul(left, right) => Numpy._ProductBinary(
        left, right, "cnp_matmul", "Numpy.Matmul")

    static Inner(left, right) => Numpy._ProductBinary(
        left, right, "cnp_inner", "Numpy.Inner")

    static Outer(left, right) => Numpy._ProductBinary(
        left, right, "cnp_outer", "Numpy.Outer")

    static Kron(left, right) => Numpy._ProductBinary(
        left, right, "cnp_kron", "Numpy.Kron")

    static Cross(left, right, axis := -1) {
        Numpy._RequireProductPair(left, right, "Numpy.Cross")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_cross"),
            "Ptr", left.Handle, "Ptr", right.Handle, "Int", axis, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Cross")
    }

    static Tensordot(left, right, axesA := 2, axesB := 2) {
        Numpy._RequireProductPair(left, right, "Numpy.Tensordot")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_tensordot"),
            "Ptr", left.Handle, "Ptr", right.Handle,
            "Int", axesA, "Int", axesB, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Tensordot")
    }

    static TensordotDefault(left, right, axes := 2) {
        Numpy._RequireProductPair(left, right, "Numpy.TensordotDefault")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_tensordot_default"),
            "Ptr", left.Handle, "Ptr", right.Handle,
            "Int", axes, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.TensordotDefault")
    }

    static Trace(source, offset := 0, axis1 := 0, axis2 := 1) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.Trace source must be an NdArray")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_trace"),
            "Ptr", source.Handle,
            "Int", offset, "Int", axis1, "Int", axis2, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Trace")
    }

    static TraceExt(source, offset := 0) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.TraceExt source must be an NdArray")
        Numpy.Init()
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        result := DllCall(Numpy.Proc("cnp_trace_ext"),
            "Ptr", source.Handle, "Int", offset, "Double")
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        if status != 0
            Numpy.CheckStatus(status, "Numpy.TraceExt")
        return result
    }

    static Vdot(left, right) {
        Numpy._RequireProductPair(left, right, "Numpy.Vdot")
        Numpy.Init()
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        result := DllCall(Numpy.Proc("cnp_vdot"),
            "Ptr", left.Handle, "Ptr", right.Handle, "Double")
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        if status != 0
            Numpy.CheckStatus(status, "Numpy.Vdot")
        return result
    }

    static MultiDot(arrays) {
        if !(arrays is Array)
            throw TypeError("Numpy.MultiDot arrays must be an Array")
        handles := Numpy.HandleBuffer(arrays, "Numpy.MultiDot")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_multi_dot"),
            "Int", arrays.Length, "Ptr", handles.Ptr, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.MultiDot")
    }

    static Pinv(source, rcond := 1e-15) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.Pinv source must be an NdArray")
        if Type(rcond) != "Integer" && Type(rcond) != "Float"
            throw TypeError("Numpy.Pinv rcond must be numeric")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_pinv"),
            "Ptr", source.Handle, "Double", rcond, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Pinv")
    }

    static EinsumDiag(source) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.EinsumDiag source must be an NdArray")
        handle := DllCall(Numpy.Proc("cnp_einsum_diag"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.EinsumDiag")
    }

    static EinsumTranspose(source) {
        if !(source is Numpy.NdArray)
            throw TypeError(
                "Numpy.EinsumTranspose source must be an NdArray")
        handle := DllCall(Numpy.Proc("cnp_einsum_transpose"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.EinsumTranspose")
    }

    static EinsumOuter(left, right) {
        if !(left is Numpy.NdArray) || !(right is Numpy.NdArray)
            throw TypeError(
                "Numpy.EinsumOuter inputs must be NdArray values")
        handle := DllCall(Numpy.Proc("cnp_einsum_outer"),
            "Ptr", left.Handle, "Ptr", right.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.EinsumOuter")
    }

    static EinsumMatmul(left, right) {
        if !(left is Numpy.NdArray) || !(right is Numpy.NdArray)
            throw TypeError(
                "Numpy.EinsumMatmul inputs must be NdArray values")
        handle := DllCall(Numpy.Proc("cnp_einsum_matmul"),
            "Ptr", left.Handle, "Ptr", right.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.EinsumMatmul")
    }

    static EinsumMatvec(left, right) {
        if !(left is Numpy.NdArray) || !(right is Numpy.NdArray)
            throw TypeError(
                "Numpy.EinsumMatvec inputs must be NdArray values")
        handle := DllCall(Numpy.Proc("cnp_einsum_matvec"),
            "Ptr", left.Handle, "Ptr", right.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.EinsumMatvec")
    }

    static EinsumDot(left, right) {
        if !(left is Numpy.NdArray) || !(right is Numpy.NdArray)
            throw TypeError(
                "Numpy.EinsumDot inputs must be NdArray values")
        Numpy.Init()
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        result := DllCall(Numpy.Proc("cnp_einsum_dot"),
            "Ptr", left.Handle, "Ptr", right.Handle, "Double")
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        if status != 0
            Numpy.CheckStatus(status, "Numpy.EinsumDot")
        return result
    }

    static EinsumTrace(source) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.EinsumTrace source must be an NdArray")
        Numpy.Init()
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        result := DllCall(Numpy.Proc("cnp_einsum_trace"),
            "Ptr", source.Handle, "Double")
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        if status != 0
            Numpy.CheckStatus(status, "Numpy.EinsumTrace")
        return result
    }

    static EinsumSum(source) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.EinsumSum source must be an NdArray")
        Numpy.Init()
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        result := DllCall(Numpy.Proc("cnp_einsum_sum"),
            "Ptr", source.Handle, "Double")
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        if status != 0
            Numpy.CheckStatus(status, "Numpy.EinsumSum")
        return result
    }

    static Einsum(subscripts, operands*) {
        if Type(subscripts) != "String"
            throw TypeError("Numpy.Einsum subscripts must be a String")
        if operands.Length = 0
            throw ValueError("Numpy.Einsum requires at least one operand")
        handles := Numpy.HandleBuffer(operands, "Numpy.Einsum")
        handle := DllCall(Numpy.Proc("cnp_ahk_einsum"),
            "AStr", subscripts,
            "Int", operands.Length,
            "Ptr", handles.Ptr,
            "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Einsum")
    }

    static Eig(source) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.Eig source must be an NdArray")
        results := Buffer(2 * A_PtrSize, 0)
        status := DllCall(Numpy.Proc("cnp_ahk_linalg_eig"),
            "Ptr", source.Handle,
            "Ptr", results.Ptr, "Int", 2, "Int")
        Numpy.CheckStatus(status, "Numpy.Eig")
        return Numpy.WrapHandleBuffer(results, 2, "Numpy.Eig")
    }

    static Eigvals(source) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.Eigvals source must be an NdArray")
        handle := DllCall(Numpy.Proc("cnp_eigvals"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Eigvals")
    }

    static Cholesky(source) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.Cholesky source must be an NdArray")
        handle := DllCall(Numpy.Proc("cnp_ahk_linalg_cholesky"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Cholesky")
    }

    static Det(source) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.Det source must be an NdArray")
        handle := DllCall(Numpy.Proc("cnp_ahk_linalg_det_v2"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Det")
    }

    static Slogdet(source) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.Slogdet source must be an NdArray")
        results := Buffer(2 * A_PtrSize, 0)
        status := DllCall(Numpy.Proc("cnp_ahk_linalg_slogdet_v2"),
            "Ptr", source.Handle,
            "Ptr", results.Ptr, "Int", 2, "Int")
        Numpy.CheckStatus(status, "Numpy.Slogdet")
        return Numpy.WrapHandleBuffer(results, 2, "Numpy.Slogdet")
    }

    static Eigh(source, uplo := "L") {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.Eigh source must be an NdArray")
        upper := Numpy._ResolveUplo(uplo, "Numpy.Eigh")
        results := Buffer(2 * A_PtrSize, 0)
        status := DllCall(Numpy.Proc("cnp_ahk_linalg_eigh_v2"),
            "Ptr", source.Handle,
            "Int", upper ? 1 : 0,
            "Ptr", results.Ptr, "Int", 2, "Int")
        Numpy.CheckStatus(status, "Numpy.Eigh")
        return Numpy.WrapHandleBuffer(results, 2, "Numpy.Eigh")
    }

    static Eigvalsh(source, uplo := "L") {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.Eigvalsh source must be an NdArray")
        upper := Numpy._ResolveUplo(uplo, "Numpy.Eigvalsh")
        handle := DllCall(Numpy.Proc("cnp_ahk_eigvalsh_v2"),
            "Ptr", source.Handle,
            "Int", upper ? 1 : 0,
            "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Eigvalsh")
    }

    static Svd(
        source, fullMatrices := true, computeUV := true, hermitian := false
    ) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.Svd source must be an NdArray")
        resultCount := computeUV ? 3 : 1
        results := Buffer(resultCount * A_PtrSize, 0)
        status := DllCall(Numpy.Proc("cnp_ahk_linalg_svd_v2"),
            "Ptr", source.Handle,
            "Int", fullMatrices ? 1 : 0,
            "Int", computeUV ? 1 : 0,
            "Int", hermitian ? 1 : 0,
            "Ptr", results.Ptr, "Int", resultCount, "Int")
        Numpy.CheckStatus(status, "Numpy.Svd")
        wrapped := Numpy.WrapHandleBuffer(results, resultCount, "Numpy.Svd")
        return computeUV ? wrapped : wrapped[1]
    }

    static Solve(a, b) {
        if !(a is Numpy.NdArray) || !(b is Numpy.NdArray)
            throw TypeError("Numpy.Solve inputs must be NdArray values")
        handle := DllCall(Numpy.Proc("cnp_ahk_linalg_solve"),
            "Ptr", a.Handle, "Ptr", b.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Solve")
    }

    static Lstsq(a, b, rcond := unset) {
        if !(a is Numpy.NdArray) || !(b is Numpy.NdArray)
            throw TypeError("Numpy.Lstsq inputs must be NdArray values")
        rcondNone := !IsSet(rcond)
        rcondValue := 0.0
        if !rcondNone {
            if Type(rcond) != "Integer" && Type(rcond) != "Float"
                throw TypeError("Numpy.Lstsq rcond must be numeric")
            rcondValue := rcond
        }
        results := Buffer(4 * A_PtrSize, 0)
        status := DllCall(Numpy.Proc("cnp_ahk_linalg_lstsq_v2"),
            "Ptr", a.Handle, "Ptr", b.Handle,
            "Double", rcondValue, "Int", rcondNone ? 1 : 0,
            "Ptr", results.Ptr, "Int", 4, "Int")
        Numpy.CheckStatus(status, "Numpy.Lstsq")
        wrapped := Numpy.WrapHandleBuffer(results, 4, "Numpy.Lstsq")
        rankArray := wrapped[3]
        rankValue := DllCall(Numpy.Proc("cnp_array_get_int"),
            "Ptr", rankArray.Handle, "Ptr", 0, "Int64")
        wrapped[3] := rankValue
        rankArray := 0
        return wrapped
    }

    static Cond(source) {
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.Cond source must be an NdArray")
        handle := DllCall(Numpy.Proc("cnp_ahk_linalg_cond_v2"),
            "Ptr", source.Handle, "Ptr")
        result := Numpy.WrapHandle(handle, "Numpy.Cond")
        if result.Ndim != 0
            return result
        value := DllCall(Numpy.Proc("cnp_array_get_double"),
            "Ptr", result.Handle, "Ptr", 0, "Double")
        result := 0
        return value
    }

    static Reshape(source, shape) => source.Reshape(shape)
    static Transpose(source) => source.Transpose()
    static Flatten(source) => source.Flatten()
    static Ravel(source) => source.Ravel()
    static AsContiguousArray(source) {
        Numpy._RequireSplitSource(source, "Numpy.AsContiguousArray")
        handle := DllCall(Numpy.Proc("cnp_ascontiguousarray"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.AsContiguousArray")
    }

    static AsFortranArray(source) {
        Numpy._RequireSplitSource(source, "Numpy.AsFortranArray")
        handle := DllCall(Numpy.Proc("cnp_asfortranarray"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.AsFortranArray")
    }

    static Resize(source, shape) {
        Numpy._RequireSplitSource(source, "Numpy.Resize")
        shapeBuffer := Numpy.ShapeBuffer(shape)
        handle := DllCall(Numpy.Proc("cnp_resize"),
            "Ptr", source.Handle, "Int", shape.Length,
            "Ptr", shapeBuffer, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Resize")
    }

    static Require(source, dtype := 0, cContiguous := false) {
        Numpy._RequireSplitSource(source, "Numpy.Require")
        handle := DllCall(Numpy.Proc("cnp_require"),
            "Ptr", source.Handle, "Int", dtype,
            "Char", cContiguous ? 1 : 0, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Require")
    }

    static AsArrayChkFinite(source, dtype := 0) {
        Numpy._RequireSplitSource(source, "Numpy.AsArrayChkFinite")
        handle := DllCall(Numpy.Proc("cnp_asarray_chkfinite"),
            "Ptr", source.Handle, "Int", dtype, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.AsArrayChkFinite")
    }

    static Swapaxes(source, axis1, axis2) {
        Numpy._RequireSplitSource(source, "Numpy.Swapaxes")
        handle := DllCall(Numpy.Proc("cnp_swapaxes"),
            "Ptr", source.Handle, "Int", axis1, "Int", axis2, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Swapaxes")
    }

    static Moveaxis(source, sourceAxis, destinationAxis) {
        Numpy._RequireSplitSource(source, "Numpy.Moveaxis")
        handle := DllCall(Numpy.Proc("cnp_moveaxis"),
            "Ptr", source.Handle, "Int", sourceAxis,
            "Int", destinationAxis, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Moveaxis")
    }

    static Squeeze(source, axis := unset) {
        Numpy._RequireSplitSource(source, "Numpy.Squeeze")
        resolvedAxis := IsSet(axis) ? axis : -1
        handle := DllCall(Numpy.Proc("cnp_squeeze"),
            "Ptr", source.Handle, "Int", resolvedAxis, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Squeeze")
    }

    static ExpandDims(source, axis) {
        Numpy._RequireSplitSource(source, "Numpy.ExpandDims")
        handle := DllCall(Numpy.Proc("cnp_expand_dims"),
            "Ptr", source.Handle, "Int", axis, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.ExpandDims")
    }

    static BroadcastTo(source, shape) {
        Numpy._RequireSplitSource(source, "Numpy.BroadcastTo")
        shapeBuffer := Numpy.ShapeBuffer(shape)
        handle := DllCall(Numpy.Proc("cnp_broadcast_to"),
            "Ptr", source.Handle, "Int", shape.Length,
            "Ptr", shapeBuffer, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.BroadcastTo")
    }

    static Stack(arrays, axis := 0) {
        handles := Numpy.HandleBuffer(arrays, "Numpy.Stack")
        handle := DllCall(Numpy.Proc("cnp_stack"),
            "Int", arrays.Length, "Ptr", handles,
            "Int", axis, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Stack")
    }

    static Vstack(arrays) {
        return Numpy._ShapeJoin("cnp_vstack", "Numpy.Vstack", arrays)
    }

    static RowStack(arrays) {
        return Numpy._ShapeJoin("cnp_row_stack", "Numpy.RowStack", arrays)
    }

    static Mat(source) {
        Numpy._RequireSplitSource(source, "Numpy.Mat")
        handle := DllCall(Numpy.Proc("cnp_mat"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Mat")
    }

    static MatlibEye(n, m := 0, k := 0) {
        handle := DllCall(Numpy.Proc("cnp_matlib_eye"),
            "Int64", n, "Int64", m, "Int", k, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.MatlibEye")
    }

    static MatlibOnes(rows, cols) {
        handle := DllCall(Numpy.Proc("cnp_matlib_ones"),
            "Int64", rows, "Int64", cols, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.MatlibOnes")
    }

    static MatlibZeros(rows, cols) {
        handle := DllCall(Numpy.Proc("cnp_matlib_zeros"),
            "Int64", rows, "Int64", cols, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.MatlibZeros")
    }

    static MatlibRepmat(source, m, n) {
        Numpy._RequireSplitSource(source, "Numpy.MatlibRepmat")
        handle := DllCall(Numpy.Proc("cnp_matlib_repmat"),
            "Ptr", source.Handle,
            "Int64", m, "Int64", n, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.MatlibRepmat")
    }

    static MatlibRand(rows, cols) {
        Numpy.Init()
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_matlib_rand"),
            "Int64", rows, "Int64", cols, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.MatlibRand (cnp_matlib_rand)")
    }

    static MatlibRandn(rows, cols) {
        Numpy.Init()
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_matlib_randn"),
            "Int64", rows, "Int64", cols, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.MatlibRandn (cnp_matlib_randn)")
    }

    static Hstack(arrays) {
        return Numpy._ShapeJoin("cnp_hstack", "Numpy.Hstack", arrays)
    }

    static Dstack(arrays) {
        return Numpy._ShapeJoin("cnp_dstack", "Numpy.Dstack", arrays)
    }

    static ColumnStack(arrays) {
        return Numpy._ShapeJoin(
            "cnp_column_stack", "Numpy.ColumnStack", arrays)
    }

    static _ShapeJoin(exportName, operation, arrays) {
        handles := Numpy.HandleBuffer(arrays, operation)
        handle := DllCall(Numpy.Proc(exportName),
            "Int", arrays.Length, "Ptr", handles, "Ptr")
        return Numpy.WrapHandle(handle, operation)
    }

    static Tile(source, reps) {
        Numpy._RequireSplitSource(source, "Numpy.Tile")
        repsBuffer := Numpy.ShapeBuffer(reps)
        handle := DllCall(Numpy.Proc("cnp_tile"),
            "Ptr", source.Handle, "Int", reps.Length,
            "Ptr", repsBuffer, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Tile")
    }

    static Repeat(source, repeats, axis := -1) {
        Numpy._RequireSplitSource(source, "Numpy.Repeat")
        handle := DllCall(Numpy.Proc("cnp_repeat"),
            "Ptr", source.Handle, "Int64", repeats,
            "Int", axis, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Repeat")
    }

    static Place(destination, mask, values) {
        Numpy._RequireSplitSource(destination, "Numpy.Place destination")
        Numpy._RequireSplitSource(mask, "Numpy.Place mask")
        Numpy._RequireSplitSource(values, "Numpy.Place values")
        status := DllCall(Numpy.Proc("cnp_place"),
            "Ptr", destination.Handle,
            "Ptr", mask.Handle,
            "Ptr", values.Handle,
            "Int")
        Numpy.CheckStatus(status, "Numpy.Place")
        return destination
    }

    static PutMask(destination, mask, values) {
        Numpy._RequireSplitSource(destination, "Numpy.PutMask destination")
        Numpy._RequireSplitSource(mask, "Numpy.PutMask mask")
        Numpy._RequireSplitSource(values, "Numpy.PutMask values")
        status := DllCall(Numpy.Proc("cnp_putmask"),
            "Ptr", destination.Handle,
            "Ptr", mask.Handle,
            "Ptr", values.Handle,
            "Int")
        Numpy.CheckStatus(status, "Numpy.PutMask")
        return destination
    }

    static Put(destination, indices, values, mode := "raise") {
        Numpy._RequireSplitSource(destination, "Numpy.Put destination")
        Numpy._RequireSplitSource(indices, "Numpy.Put indices")
        Numpy._RequireSplitSource(values, "Numpy.Put values")
        modeBuffer := Numpy.Utf8Buffer(mode, "Numpy.Put mode")
        status := DllCall(Numpy.Proc("cnp_put"),
            "Ptr", destination.Handle,
            "Ptr", indices.Handle,
            "Ptr", values.Handle,
            "Ptr", modeBuffer,
            "Int")
        Numpy.CheckStatus(status, "Numpy.Put")
        return destination
    }

    static Choose(indices, choices) {
        Numpy._RequireSplitSource(indices, "Numpy.Choose indices")
        handles := Numpy.HandleBuffer(choices, "Numpy.Choose")
        if choices.Length = 0
            throw ValueError("Numpy.Choose choices must not be empty")
        handle := DllCall(Numpy.Proc("cnp_choose"),
            "Ptr", indices.Handle,
            "Int", choices.Length,
            "Ptr", handles,
            "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Choose")
    }

    static Flip(source, axis := -1) {
        Numpy._RequireSplitSource(source, "Numpy.Flip")
        handle := DllCall(Numpy.Proc("cnp_flip"),
            "Ptr", source.Handle, "Int", axis, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Flip")
    }

    static Fliplr(source) {
        Numpy._RequireSplitSource(source, "Numpy.Fliplr")
        handle := DllCall(Numpy.Proc("cnp_fliplr"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Fliplr")
    }

    static Flipud(source) {
        Numpy._RequireSplitSource(source, "Numpy.Flipud")
        handle := DllCall(Numpy.Proc("cnp_flipud"),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Flipud")
    }

    static IsClose(left, right, rtol := 1e-5, atol := 1e-8) {
        Numpy._RequireSplitSource(left, "Numpy.IsClose left")
        Numpy._RequireSplitSource(right, "Numpy.IsClose right")
        handle := DllCall(Numpy.Proc("cnp_isclose"),
            "Ptr", left.Handle, "Ptr", right.Handle,
            "Double", rtol, "Double", atol, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.IsClose")
    }

    static ArrayEqual(left, right) {
        return Numpy._ArrayRelationBool(
            "cnp_array_equal", "Numpy.ArrayEqual", left, right)
    }

    static ArrayEquiv(left, right) {
        return Numpy._ArrayRelationBool(
            "cnp_array_equiv", "Numpy.ArrayEquiv", left, right)
    }

    static SharesMemory(left, right) {
        return Numpy._ArrayRelationBool(
            "cnp_shares_memory", "Numpy.SharesMemory", left, right)
    }

    static MayShareMemory(left, right) {
        return Numpy._ArrayRelationBool(
            "cnp_may_share_memory", "Numpy.MayShareMemory", left, right)
    }

    static _ArrayRelationBool(exportName, operation, left, right) {
        Numpy._RequireSplitSource(left, operation " left")
        Numpy._RequireSplitSource(right, operation " right")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        result := DllCall(Numpy.Proc(exportName),
            "Ptr", left.Handle, "Ptr", right.Handle, "Char")
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        Numpy.CheckStatus(status, operation)
        return result != 0
    }

    static ByteBounds(source) {
        Numpy._RequireSplitSource(source, "Numpy.ByteBounds")
        low := Buffer(A_PtrSize, 0)
        high := Buffer(A_PtrSize, 0)
        status := DllCall(Numpy.Proc("cnp_byte_bounds"),
            "Ptr", source.Handle,
            "Ptr", low.Ptr, "Ptr", high.Ptr, "Int")
        Numpy.CheckStatus(status, "Numpy.ByteBounds")
        return [NumGet(low, 0, "Ptr"), NumGet(high, 0, "Ptr")]
    }

    static Rot90(source, k := 1, axis1 := 0, axis2 := 1) {
        Numpy._RequireSplitSource(source, "Numpy.Rot90")
        handle := DllCall(Numpy.Proc("cnp_rot90"),
            "Ptr", source.Handle, "Int", k,
            "Int", axis1, "Int", axis2, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Rot90")
    }

    static Roll(source, shift, axis := -1) {
        Numpy._RequireSplitSource(source, "Numpy.Roll")
        handle := DllCall(Numpy.Proc("cnp_roll"),
            "Ptr", source.Handle, "Int64", shift,
            "Int", axis, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Roll")
    }

    static Append(source, values, axis := -1) {
        Numpy._RequireSplitSource(source, "Numpy.Append")
        Numpy._RequireSplitSource(values, "Numpy.Append")
        handle := DllCall(Numpy.Proc("cnp_append"),
            "Ptr", source.Handle, "Ptr", values.Handle,
            "Int", axis, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Append")
    }

    static Pad(source, padWidth, constantValue := 0.0) {
        Numpy._RequireSplitSource(source, "Numpy.Pad")
        handle := DllCall(Numpy.Proc("cnp_pad"),
            "Ptr", source.Handle, "Int64", padWidth,
            "Double", constantValue, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Pad")
    }

    static Slice(source, start, stop, step := 1, axis := 0) {
        Numpy._RequireSplitSource(source, "Numpy.Slice")
        ndim := source.Ndim
        resolvedAxis := axis < 0 ? axis + ndim : axis
        if resolvedAxis < 0 || resolvedAxis >= ndim
            throw ValueError("Numpy.Slice axis is out of bounds")
        slices := Buffer(Max(ndim, 1) * 32, 0)
        loop ndim {
            offset := (A_Index - 1) * 32
            NumPut("Int64", 1, slices, offset + 16)
        }
        selectedOffset := resolvedAxis * 32
        NumPut("Int64", start, slices, selectedOffset)
        NumPut("Int64", stop, slices, selectedOffset + 8)
        NumPut("Int64", step, slices, selectedOffset + 16)
        NumPut("UChar", 1, slices, selectedOffset + 24)
        NumPut("UChar", 1, slices, selectedOffset + 25)
        NumPut("UChar", 1, slices, selectedOffset + 26)
        handle := DllCall(Numpy.Proc("cnp_array_slice"),
            "Ptr", source.Handle, "Int", ndim,
            "Ptr", slices, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Slice")
    }

    static Atleast1d(source) {
        Numpy._RequireSplitSource(source, "Numpy.Atleast1d")
        return source.Atleast1d()
    }

    static Atleast2d(source) {
        Numpy._RequireSplitSource(source, "Numpy.Atleast2d")
        return source.Atleast2d()
    }

    static Atleast3d(source) {
        Numpy._RequireSplitSource(source, "Numpy.Atleast3d")
        return source.Atleast3d()
    }

    static Atleast_1d(source) => Numpy.Atleast1d(source)
    static Atleast_2d(source) => Numpy.Atleast2d(source)
    static Atleast_3d(source) => Numpy.Atleast3d(source)

    static Concatenate(arrays, axis := 0) {
        if !(arrays is Array)
            throw TypeError("Numpy.Concatenate arrays must be an Array")
        if arrays.Length = 0
            throw ValueError("Numpy.Concatenate arrays must not be empty")
        handles := Buffer(arrays.Length * A_PtrSize, 0)
        for index, item in arrays {
            if !(item is Numpy.NdArray)
                throw TypeError(
                    "Numpy.Concatenate item " index " must be an NdArray")
            NumPut("Ptr", item.Handle, handles, (index - 1) * A_PtrSize)
        }
        handle := DllCall(Numpy.Proc("cnp_ahk_concatenate_many"),
            "Ptr", handles.Ptr,
            "Int", arrays.Length, "Int", axis, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Concatenate")
    }

    static BroadcastArrays(arrays) {
        Numpy.Init()
        handles := Numpy.HandleBuffer(arrays, "Numpy.BroadcastArrays")
        if arrays.Length = 0
            return []
        results := Buffer(arrays.Length * A_PtrSize, 0)
        status := DllCall(Numpy.Proc("cnp_ahk_broadcast_arrays_v2"),
            "Ptr", handles.Ptr, "Int", arrays.Length,
            "Ptr", results.Ptr, "Int", arrays.Length, "Int")
        Numpy.CheckStatus(status, "Numpy.BroadcastArrays")
        return Numpy.WrapHandleBuffer(
            results, arrays.Length, "Numpy.BroadcastArrays")
    }

    static Broadcast_Arrays(arrays) => Numpy.BroadcastArrays(arrays)

    static Meshgrid(arrays, indexing := "xy", sparse := false, copy := true) {
        Numpy.Init()
        if indexing != "xy" && indexing != "ij"
            throw ValueError("Numpy.Meshgrid indexing must be 'xy' or 'ij'")
        handles := Numpy.HandleBuffer(arrays, "Numpy.Meshgrid")
        if arrays.Length = 0
            return []
        results := Buffer(arrays.Length * A_PtrSize, 0)
        status := DllCall(Numpy.Proc("cnp_ahk_meshgrid_v2"),
            "Ptr", handles.Ptr, "Int", arrays.Length,
            "Int", sparse ? 1 : 0,
            "Int", indexing = "ij" ? 1 : 0,
            "Int", copy ? 1 : 0,
            "Ptr", results.Ptr, "Int", arrays.Length, "Int")
        Numpy.CheckStatus(status, "Numpy.Meshgrid")
        return Numpy.WrapHandleBuffer(
            results, arrays.Length, "Numpy.Meshgrid")
    }

    static BroadcastShapes(shapes) {
        if !(shapes is Array)
            throw TypeError("Numpy.BroadcastShapes shapes must be an Array")
        if shapes.Length = 0
            throw ValueError("Numpy.BroadcastShapes requires at least one shape")
        pointers := Buffer(shapes.Length * A_PtrSize, 0)
        ndims := Buffer(shapes.Length * 4, 0)
        shapeBuffers := []
        for index, shape in shapes {
            if !(shape is Array)
                throw TypeError(
                    "Numpy.BroadcastShapes shape " index " must be an Array")
            storage := Buffer(Max(shape.Length, 1) * 8, 0)
            for dimension, length in shape
                NumPut("Int64", length, storage, (dimension - 1) * 8)
            shapeBuffers.Push(storage)
            NumPut("Ptr", storage.Ptr, pointers, (index - 1) * A_PtrSize)
            NumPut("Int", shape.Length, ndims, (index - 1) * 4)
        }
        outNdim := Buffer(4, 0)
        outShape := Buffer(A_PtrSize, 0)
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        status := DllCall(Numpy.Proc("cnp_broadcast_shapes"),
            "Int", shapes.Length,
            "Ptr", pointers,
            "Ptr", ndims,
            "Ptr", outNdim,
            "Ptr", outShape,
            "Int")
        pointer := NumGet(outShape, 0, "Ptr")
        ndim := NumGet(outNdim, 0, "Int")
        try {
            Numpy.CheckStatus(
                status, "Numpy.BroadcastShapes (cnp_broadcast_shapes)")
            result := []
            loop ndim
                result.Push(NumGet(pointer, (A_Index - 1) * 8, "Int64"))
            return result
        } finally {
            if pointer
                DllCall(Numpy.Proc("cnp_broadcast_shape_free"),
                    "Ptr", pointer, "Int", ndim)
        }
    }

    static ApplyAlongAxis(callback, axis, source) {
        operation := "Numpy.ApplyAlongAxis (cnp_ahk_apply_along_axis_v2)"
        if !(source is Numpy.NdArray)
            throw TypeError(operation " source must be an NdArray")
        context := Numpy._RegisterCallback(
            callback, NumpyLineBatchCallback, 7, operation)
        try {
            handle := DllCall(Numpy.Proc("cnp_ahk_apply_along_axis_v2"),
                "Ptr", context.Native, "Ptr", context.Token,
                "Int", axis, "Ptr", source.Handle,
                "Int", 0, "Ptr", 0, "Ptr")
            return Numpy._CallbackResult(handle, context, operation)
        } finally Numpy._ReleaseCallback(context)
    }

    static ApplyOverAxes(callback, source, axes) {
        operation := "Numpy.ApplyOverAxes (cnp_ahk_apply_over_axes_v2)"
        if !(source is Numpy.NdArray)
            throw TypeError(operation " source must be an NdArray")
        if !(axes is Array)
            throw TypeError(operation " axes must be an Array")
        axisBuffer := Buffer(Max(axes.Length, 1) * 4, 0)
        for index, axis in axes {
            if Type(axis) != "Integer"
                throw TypeError(operation " axis " index " must be an Integer")
            NumPut("Int", axis, axisBuffer, (index - 1) * 4)
        }
        context := Numpy._RegisterCallback(
            callback, NumpyLineBatchCallback, 7, operation)
        try {
            handle := DllCall(Numpy.Proc("cnp_ahk_apply_over_axes_v2"),
                "Ptr", context.Native, "Ptr", context.Token,
                "Int", axes.Length, "Ptr", axisBuffer,
                "Ptr", source.Handle, "Ptr")
            return Numpy._CallbackResult(handle, context, operation)
        } finally Numpy._ReleaseCallback(context)
    }

    static FromFunction(callback, shape) {
        operation := "Numpy.FromFunction (cnp_ahk_fromfunction_v2)"
        if !(shape is Array)
            throw TypeError(operation " shape must be an Array")
        shapeBuffer := Numpy.ShapeBuffer(shape)
        context := Numpy._RegisterCallback(
            callback, NumpyCoordinateBatchCallback, 7, operation)
        try {
            handle := DllCall(Numpy.Proc("cnp_ahk_fromfunction_v2"),
                "Ptr", context.Native, "Ptr", context.Token,
                "Int", shape.Length, "Ptr", shapeBuffer, "Ptr")
            return Numpy._CallbackResult(handle, context, operation)
        } finally Numpy._ReleaseCallback(context)
    }

    static FromIter(callback, count, dtype := 13) {
        operation := "Numpy.FromIter (cnp_ahk_fromiter_v2)"
        if Type(count) != "Integer"
            throw TypeError(operation " count must be an Integer")
        if count < 0
            throw ValueError(operation " count must be non-negative")
        if Type(dtype) != "Integer"
            throw TypeError(operation " dtype must be an Integer")
        context := Numpy._RegisterCallback(
            callback, NumpyIteratorBatchCallback, 4, operation)
        try {
            handle := DllCall(Numpy.Proc("cnp_ahk_fromiter_v2"),
                "Ptr", context.Native, "Ptr", context.Token,
                "Int64", count, "Int", dtype, "Ptr")
            return Numpy._CallbackResult(handle, context, operation)
        } finally Numpy._ReleaseCallback(context)
    }

    static FromPyFunc(callback, source) {
        return Numpy._UnaryCallbackArray(
            callback, source, "cnp_ahk_frompyfunc_v2",
            "Numpy.FromPyFunc (cnp_ahk_frompyfunc_v2)")
    }

    static Vectorize(callback, source) {
        return Numpy._UnaryCallbackArray(
            callback, source, "cnp_ahk_vectorize_v2",
            "Numpy.Vectorize (cnp_ahk_vectorize_v2)")
    }

    static Select(conditions, choices, defaultValue := 0.0) {
        operation := "Numpy.Select (cnp_select)"
        if !(conditions is Array) || !(choices is Array)
            throw TypeError(operation " conditions and choices must be Arrays")
        if conditions.Length = 0 || conditions.Length != choices.Length
            throw ValueError(
                operation " requires equal non-empty conditions and choices")
        conditionHandles := Numpy.HandleBuffer(conditions, operation " conditions")
        choiceHandles := Numpy.HandleBuffer(choices, operation " choices")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_select"),
            "Int", conditions.Length,
            "Ptr", conditionHandles, "Ptr", choiceHandles,
            "Double", defaultValue, "Ptr")
        return Numpy.WrapHandle(handle, operation)
    }

    static Piecewise(source, conditions, callback) {
        operation := "Numpy.Piecewise (cnp_ahk_piecewise_v2)"
        if !(source is Numpy.NdArray)
            throw TypeError(operation " source must be an NdArray")
        conditionHandles := Numpy.HandleBuffer(
            conditions, operation " conditions")
        context := Numpy._RegisterCallback(
            callback, NumpyUnaryBatchCallback, 6, operation)
        try {
            handle := DllCall(Numpy.Proc("cnp_ahk_piecewise_v2"),
                "Ptr", source.Handle, "Int", conditions.Length,
                "Ptr", conditionHandles,
                "Ptr", context.Native, "Ptr", context.Token, "Ptr")
            return Numpy._CallbackResult(handle, context, operation)
        } finally Numpy._ReleaseCallback(context)
    }

    static PutAlongAxis(destination, indices, values, axis) {
        operation := "Numpy.PutAlongAxis (cnp_put_along_axis)"
        if !(destination is Numpy.NdArray) ||
                !(indices is Numpy.NdArray) || !(values is Numpy.NdArray)
            throw TypeError(operation " inputs must be NdArray values")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        status := DllCall(Numpy.Proc("cnp_put_along_axis"),
            "Ptr", destination.Handle,
            "Ptr", indices.Handle, "Ptr", values.Handle,
            "Int", axis, "Int")
        Numpy.CheckStatus(status, operation)
    }

    static CanBroadcast(left, right) {
        if !(left is Numpy.NdArray) || !(right is Numpy.NdArray)
            throw TypeError("Numpy.CanBroadcast operands must be NdArray values")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        result := DllCall(Numpy.Proc("cnp_can_broadcast"),
            "Ptr", left.Handle, "Ptr", right.Handle, "Char") != 0
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        Numpy.CheckStatus(status, "Numpy.CanBroadcast (cnp_can_broadcast)")
        return result
    }

    static Indices(dimensions) {
        if !(dimensions is Array)
            throw TypeError("Numpy.Indices dimensions must be an Array")
        storage := Numpy.ShapeBuffer(dimensions)
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_indices"),
            "Int", dimensions.Length, "Ptr", storage, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Indices (cnp_indices)")
    }

    static Mgrid(starts, stops, steps) =>
        Numpy._GridResult("cnp_mgrid", "Numpy.Mgrid", starts, stops, steps)

    static Ogrid(starts, stops, steps) =>
        Numpy._GridResult("cnp_ogrid", "Numpy.Ogrid", starts, stops, steps)

    static _GridResult(symbol, operation, starts, stops, steps) {
        if !(starts is Array) || !(stops is Array) || !(steps is Array)
            throw TypeError(operation " start, stop, and step values must be Arrays")
        if starts.Length = 0 || stops.Length != starts.Length
                || steps.Length != starts.Length
            throw ValueError(operation " requires equal non-empty start, stop, and step Arrays")
        startBuffer := Numpy.ShapeBuffer(starts)
        stopBuffer := Numpy.ShapeBuffer(stops)
        stepBuffer := Numpy.ShapeBuffer(steps)
        outputs := Buffer(starts.Length * A_PtrSize, 0)
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        status := DllCall(Numpy.Proc(symbol),
            "Int", starts.Length,
            "Ptr", startBuffer,
            "Ptr", stopBuffer,
            "Ptr", stepBuffer,
            "Ptr", outputs,
            "Int")
        Numpy.CheckStatus(status, operation " (" symbol ")")
        return Numpy.WrapHandleBuffer(outputs, starts.Length, operation)
    }

    static Block(rows) => Numpy._BlockResult("cnp_block", "Numpy.Block", rows)

    static Bmat(rows) => Numpy._BlockResult("cnp_bmat", "Numpy.Bmat", rows)

    static _BlockResult(symbol, operation, rows) {
        if !(rows is Array) || rows.Length = 0
            throw ValueError(operation " requires a non-empty Array of rows")
        if !(rows[1] is Array) || rows[1].Length = 0
            throw ValueError(operation " requires non-empty block rows")
        columnCount := rows[1].Length
        flat := []
        for rowIndex, row in rows {
            if !(row is Array)
                throw TypeError(operation " row " rowIndex " must be an Array")
            if row.Length != columnCount
                throw ValueError(operation " block rows must have equal lengths")
            for block in row
                flat.Push(block)
        }
        handles := Numpy.HandleBuffer(flat, operation)
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc(symbol),
            "Int", rows.Length, "Int", columnCount,
            "Ptr", handles, "Ptr")
        return Numpy.WrapHandle(handle, operation " (" symbol ")")
    }

    static Split(source, indicesOrSections, axis := 0) {
        return Numpy._SplitResult(
            "split", "Numpy.Split", source, indicesOrSections, axis)
    }

    static ArraySplit(source, indicesOrSections, axis := 0) {
        return Numpy._SplitResult(
            "array_split", "Numpy.ArraySplit",
            source, indicesOrSections, axis)
    }

    static Array_Split(source, indicesOrSections, axis := 0) {
        return Numpy.ArraySplit(source, indicesOrSections, axis)
    }

    static Hsplit(source, indicesOrSections) {
        Numpy._RequireSplitSource(source, "Numpy.Hsplit")
        if source.Ndim < 1
            throw ValueError(
                "Numpy.Hsplit only works on arrays of 1 or more dimensions")
        axis := source.Ndim = 1 ? 0 : 1
        return Numpy._SplitResult(
            "split", "Numpy.Hsplit", source, indicesOrSections, axis)
    }

    static Vsplit(source, indicesOrSections) {
        Numpy._RequireSplitSource(source, "Numpy.Vsplit")
        if source.Ndim < 2
            throw ValueError(
                "Numpy.Vsplit only works on arrays of 2 or more dimensions")
        return Numpy._SplitResult(
            "split", "Numpy.Vsplit", source, indicesOrSections, 0)
    }

    static Dsplit(source, indicesOrSections) {
        Numpy._RequireSplitSource(source, "Numpy.Dsplit")
        if source.Ndim < 3
            throw ValueError(
                "Numpy.Dsplit only works on arrays of 3 or more dimensions")
        return Numpy._SplitResult(
            "split", "Numpy.Dsplit", source, indicesOrSections, 2)
    }

    static _RequireSplitSource(source, operation) {
        if !(source is Numpy.NdArray)
            throw TypeError(operation " source must be an NdArray")
    }

    static _RequireSetPair(left, right, operation) {
        if !(left is Numpy.NdArray)
            throw TypeError(operation " left input must be an NdArray")
        if !(right is Numpy.NdArray)
            throw TypeError(operation " right input must be an NdArray")
    }

    static _ResolveSortAxis(axis, operation) {
        if Type(axis) = "String" {
            if StrLower(axis) != "none"
                throw TypeError(
                    operation " axis must be an Integer or 'none'")
            return [0, 1]
        }
        if Type(axis) != "Integer"
            throw TypeError(operation " axis must be an Integer or 'none'")
        return [axis, 0]
    }

    static _ResolveSortKind(kind, operation) {
        if Type(kind) != "String"
            throw TypeError(operation " kind must be a String")
        normalized := StrLower(kind)
        if normalized = "quicksort"
            return 0
        if normalized = "mergesort"
            return 1
        if normalized = "heapsort"
            return 2
        if normalized = "stable"
            return 3
        throw ValueError(operation " invalid kind: " kind)
    }

    static _ResolvePartitionKind(kind, operation) {
        if Type(kind) != "String"
            throw TypeError(operation " kind must be a String")
        if StrLower(kind) != "introselect"
            throw ValueError(
                operation " kind must be 'introselect'")
    }

    static _PartitionResult(
        nativeName, operation, source, kth, axis, kind
    ) {
        Numpy.Init()
        Numpy._RequireSplitSource(source, operation)
        Numpy._ResolvePartitionKind(kind, operation)
        resolvedAxis := Numpy._ResolveSortAxis(axis, operation)

        if Type(kth) = "Integer" {
            kthCount := 1
            kthBuffer := Buffer(8, 0)
            NumPut("Int64", kth, kthBuffer, 0)
        } else if kth is Array {
            kthCount := kth.Length
            kthBuffer := Buffer(Max(kthCount, 1) * 8, 0)
            for index, value in kth {
                if Type(value) != "Integer"
                    throw TypeError(
                        operation " kth value " index " must be an Integer")
                NumPut("Int64", value, kthBuffer, (index - 1) * 8)
            }
        } else {
            throw TypeError(operation " kth must be an Integer or Array")
        }

        handle := DllCall(Numpy.Proc(nativeName),
            "Ptr", source.Handle,
            "Ptr", kthBuffer.Ptr, "Int", kthCount,
            "Int", resolvedAxis[1], "Int", resolvedAxis[2], "Ptr")
        return Numpy.WrapHandle(handle, operation)
    }

    static _ResolveBitorder(bitorder, operation) {
        if Type(bitorder) != "String"
            throw TypeError(operation " bitorder must be a String")
        normalized := StrLower(bitorder)
        if normalized = "big"
            return 0
        if normalized = "little"
            return 1
        throw ValueError(
            operation " bitorder must be 'big' or 'little'")
    }

    static _ResolveSignalMode(mode, operation) {
        if Type(mode) != "String"
            throw TypeError(operation " mode must be a String")
        normalized := StrLower(mode)
        if normalized = "full"
            return 0
        if normalized = "same"
            return 1
        if normalized = "valid"
            return 2
        throw ValueError(
            operation " mode must be 'full', 'same', or 'valid'")
    }

    static _SplitResult(
        nativeFamily, operation, source, indicesOrSections, axis
    ) {
        Numpy.Init()
        Numpy._RequireSplitSource(source, operation)
        if Type(axis) != "Integer"
            throw TypeError(operation " axis must be an Integer")

        if indicesOrSections is Array {
            indexCount := indicesOrSections.Length
            indices := Buffer(Max(indexCount, 1) * 8, 0)
            for index, boundary in indicesOrSections {
                if Type(boundary) != "Integer"
                    throw TypeError(
                        operation " boundary " index " must be an Integer")
                NumPut("Int64", boundary, indices, (index - 1) * 8)
            }
            resultCount := indexCount + 1
            results := Buffer(resultCount * A_PtrSize, 0)
            status := DllCall(
                Numpy.Proc("cnp_ahk_" nativeFamily "_indices_v2"),
                "Ptr", source.Handle,
                "Int", indexCount, "Ptr", indices.Ptr, "Int", axis,
                "Ptr", results.Ptr, "Int", resultCount, "Int")
        } else {
            if Type(indicesOrSections) != "Integer"
                throw TypeError(
                    operation " indices_or_sections must be an Integer or Array")
            if indicesOrSections <= 0
                throw ValueError(
                    operation " number of sections must be greater than zero")
            resultCount := indicesOrSections
            results := Buffer(resultCount * A_PtrSize, 0)
            status := DllCall(
                Numpy.Proc("cnp_ahk_" nativeFamily "_sections_v2"),
                "Ptr", source.Handle,
                "Int", indicesOrSections, "Int", axis,
                "Ptr", results.Ptr, "Int", resultCount, "Int")
        }
        Numpy.CheckStatus(status, operation)
        return Numpy.WrapHandleBuffer(results, resultCount, operation)
    }

    static Take(source, indices, axis := unset) {
        Numpy._RequireSplitSource(source, "Numpy.Take")
        indexArray := Numpy._AsIndexArray(indices, "Numpy.Take")
        axisNone := !IsSet(axis)
        resolvedAxis := axisNone ? 0 : axis
        if Type(resolvedAxis) != "Integer"
            throw TypeError("Numpy.Take axis must be an Integer")
        handle := DllCall(Numpy.Proc("cnp_ahk_take_v2"),
            "Ptr", source.Handle, "Ptr", indexArray.Handle,
            "Int", resolvedAxis, "Int", axisNone ? 1 : 0, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Take")
    }

    static TakeAlongAxis(source, indices, axis := unset) {
        Numpy._RequireSplitSource(source, "Numpy.TakeAlongAxis")
        indexArray := Numpy._AsIndexArray(indices, "Numpy.TakeAlongAxis")
        axisNone := !IsSet(axis)
        resolvedAxis := axisNone ? 0 : axis
        if Type(resolvedAxis) != "Integer"
            throw TypeError("Numpy.TakeAlongAxis axis must be an Integer")
        handle := DllCall(Numpy.Proc("cnp_ahk_take_along_axis_v2"),
            "Ptr", source.Handle, "Ptr", indexArray.Handle,
            "Int", resolvedAxis, "Int", axisNone ? 1 : 0, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.TakeAlongAxis")
    }

    static Take_Along_Axis(source, indices, axis := unset) {
        if IsSet(axis)
            return Numpy.TakeAlongAxis(source, indices, axis)
        return Numpy.TakeAlongAxis(source, indices)
    }

    static Compress(condition, source, axis := unset) {
        Numpy._RequireSplitSource(source, "Numpy.Compress")
        conditionArray := Numpy._AsIndexArray(condition, "Numpy.Compress")
        axisNone := !IsSet(axis)
        resolvedAxis := axisNone ? 0 : axis
        if Type(resolvedAxis) != "Integer"
            throw TypeError("Numpy.Compress axis must be an Integer")
        handle := DllCall(Numpy.Proc("cnp_ahk_compress_v2"),
            "Ptr", conditionArray.Handle, "Ptr", source.Handle,
            "Int", resolvedAxis, "Int", axisNone ? 1 : 0, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Compress")
    }

    static Delete(source, obj, axis := unset) {
        Numpy._RequireSplitSource(source, "Numpy.Delete")
        objArray := Numpy._AsIndexArray(obj, "Numpy.Delete")
        axisNone := !IsSet(axis)
        resolvedAxis := axisNone ? 0 : axis
        if Type(resolvedAxis) != "Integer"
            throw TypeError("Numpy.Delete axis must be an Integer")
        handle := DllCall(Numpy.Proc("cnp_ahk_delete_v2"),
            "Ptr", source.Handle, "Ptr", objArray.Handle,
            "Int", resolvedAxis, "Int", axisNone ? 1 : 0, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Delete")
    }

    static Insert(source, obj, values, axis := unset) {
        Numpy._RequireSplitSource(source, "Numpy.Insert")
        valueArray := values is Numpy.NdArray
            ? values
            : (values is Array
                ? Numpy.Array(values)
                : Numpy.Array([values]))
        axisNone := !IsSet(axis)
        resolvedAxis := axisNone ? 0 : axis
        if Type(resolvedAxis) != "Integer"
            throw TypeError("Numpy.Insert axis must be an Integer")
        if obj is Numpy.NdArray || obj is Array {
            objArray := Numpy._AsIndexArray(obj, "Numpy.Insert")
            handle := DllCall(Numpy.Proc("cnp_ahk_insert_array_v2"),
                "Ptr", source.Handle, "Ptr", objArray.Handle,
                "Ptr", valueArray.Handle, "Int", resolvedAxis,
                "Int", axisNone ? 1 : 0, "Ptr")
        } else if Type(obj) = "Integer" {
            handle := DllCall(Numpy.Proc("cnp_ahk_insert_v2"),
                "Ptr", source.Handle, "Int64", obj,
                "Ptr", valueArray.Handle, "Int", resolvedAxis,
                "Int", axisNone ? 1 : 0, "Ptr")
        } else {
            throw TypeError(
                "Numpy.Insert obj must be an Integer, Array, or NdArray")
        }
        return Numpy.WrapHandle(handle, "Numpy.Insert")
    }

    static _AsIndexArray(value, operation) {
        if value is Numpy.NdArray
            return value
        if value is Array
            return Numpy.IntArray(value)
        if Type(value) = "Integer"
            return Numpy.IntArray([value])
        throw TypeError(operation " indices must be an Integer, Array, or NdArray")
    }

    ; =========================================================================
    ; Random module
    ; =========================================================================

    class Random {
        static Seed(seed) {
            Numpy.Init()
            DllCall(Numpy.Proc("cnp_ahk_random_seed_v2"), "UInt64", seed)
        }

        static Choice(source, size := unset, replace := true,
                probabilities := unset) {
            Numpy.Init()
            if source is Numpy.NdArray {
                population := source
            } else if Type(source) = "Integer" {
                if source <= 0
                    throw ValueError(
                        "Numpy.Random.Choice integer source must be positive")
                populationData := []
                loop source
                    populationData.Push(A_Index - 1)
                population := Numpy.IntArray(populationData)
            } else {
                throw TypeError(
                    "Numpy.Random.Choice source must be an NdArray or Integer")
            }

            sizeNone := !IsSet(size)
            if sizeNone {
                sizeNdim := 0
                sizeBuf := 0
            } else if Type(size) = "Integer" {
                sizeNdim := 1
                sizeBuf := Numpy.ShapeBuffer([size])
            } else if size is Array {
                sizeNdim := size.Length
                sizeBuf := Numpy.ShapeBuffer(size)
            } else {
                throw TypeError(
                    "Numpy.Random.Choice size must be an Integer or Array")
            }

            probabilityArray := 0
            if IsSet(probabilities) {
                if probabilities is Numpy.NdArray
                    probabilityArray := probabilities
                else if probabilities is Array
                    probabilityArray := Numpy.Array(probabilities)
                else
                    throw TypeError(
                        "Numpy.Random.Choice probabilities must be an NdArray or Array")
            }

            handle := DllCall(Numpy.Proc("cnp_ahk_random_choice_v2"),
                "Ptr", population.Handle,
                "Int", sizeNdim,
                "Ptr", sizeBuf,
                "Int", sizeNone ? 1 : 0,
                "Int", replace ? 1 : 0,
                "Ptr", probabilityArray ? probabilityArray.Handle : 0,
                "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Random.Choice")
        }

        static Permutation(source) {
            Numpy.Init()
            if !(source is Numpy.NdArray)
                throw TypeError(
                    "Numpy.Random.Permutation source must be an NdArray")
            handle := DllCall(Numpy.Proc("cnp_ahk_random_permutation"),
                "Ptr", source.Handle, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Random.Permutation")
        }

        static Shuffle(source) {
            Numpy.Init()
            if !(source is Numpy.NdArray)
                throw TypeError("Numpy.Random.Shuffle source must be an NdArray")
            status := DllCall(Numpy.Proc("cnp_ahk_random_shuffle"),
                "Ptr", source.Handle, "Int")
            Numpy.CheckStatus(status, "Numpy.Random.Shuffle")
        }

        static _Shape(shape, operation) {
            if !(shape is Array)
                throw TypeError(operation " shape must be an Array")
            return Numpy.ShapeBuffer(shape)
        }

        static _NoParameter(functionName, operation, shape) {
            Numpy.Init()
            shapeBuf := Numpy.Random._Shape(shape, operation)
            handle := DllCall(Numpy.Proc(functionName),
                "Int", shape.Length, "Ptr", shapeBuf.Ptr, "Ptr")
            return Numpy.WrapHandle(handle, operation)
        }

        static _OneParameter(functionName, operation, shape, value) {
            Numpy.Init()
            shapeBuf := Numpy.Random._Shape(shape, operation)
            handle := DllCall(Numpy.Proc(functionName),
                "Double", value,
                "Int", shape.Length, "Ptr", shapeBuf.Ptr, "Ptr")
            return Numpy.WrapHandle(handle, operation)
        }

        static _TwoParameters(
            functionName, operation, shape, first, second
        ) {
            Numpy.Init()
            shapeBuf := Numpy.Random._Shape(shape, operation)
            handle := DllCall(Numpy.Proc(functionName),
                "Double", first, "Double", second,
                "Int", shape.Length, "Ptr", shapeBuf.Ptr, "Ptr")
            return Numpy.WrapHandle(handle, operation)
        }

        static _ThreeParameters(
            functionName, operation, shape, first, second, third
        ) {
            Numpy.Init()
            shapeBuf := Numpy.Random._Shape(shape, operation)
            handle := DllCall(Numpy.Proc(functionName),
                "Double", first, "Double", second, "Double", third,
                "Int", shape.Length, "Ptr", shapeBuf.Ptr, "Ptr")
            return Numpy.WrapHandle(handle, operation)
        }

        static _DoubleBuffer(values, operation) {
            if !(values is Array) || values.Length = 0
                throw TypeError(operation " values must be a non-empty Array")
            result := Buffer(values.Length * 8, 0)
            for index, value in values {
                if Type(value) != "Integer" && Type(value) != "Float"
                    throw TypeError(operation " values must be numeric")
                NumPut("Double", value, result, (index - 1) * 8)
            }
            return result
        }

        static Random(shape) {
            Numpy.Init()
            shapeBuf := Numpy.Random._Shape(shape, "Numpy.Random.Random")
            handle := DllCall(Numpy.Proc("cnp_random_random"),
                "Int", shape.Length, "Ptr", shapeBuf.Ptr, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Random.Random")
        }

        static Normal(shape, mean := 0.0, std := 1.0) {
            Numpy.Init()
            shapeBuf := Numpy.Random._Shape(shape, "Numpy.Random.Normal")
            handle := DllCall(Numpy.Proc("cnp_random_normal"),
                "Double", mean, "Double", std,
                "Int", shape.Length, "Ptr", shapeBuf.Ptr, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Random.Normal")
        }

        static Uniform(shape, lo := 0.0, hi := 1.0) {
            Numpy.Init()
            shapeBuf := Numpy.Random._Shape(shape, "Numpy.Random.Uniform")
            handle := DllCall(Numpy.Proc("cnp_random_uniform"),
                "Double", lo, "Double", hi,
                "Int", shape.Length, "Ptr", shapeBuf.Ptr, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Random.Uniform")
        }

        static StandardNormal(shape) {
            Numpy.Init()
            shapeBuf := Numpy.Random._Shape(
                shape, "Numpy.Random.StandardNormal")
            handle := DllCall(Numpy.Proc("cnp_random_standard_normal"),
                "Int", shape.Length, "Ptr", shapeBuf.Ptr, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Random.StandardNormal")
        }

        static Randint(shape, lo, hi) {
            Numpy.Init()
            shapeBuf := Numpy.Random._Shape(shape, "Numpy.Random.Randint")
            handle := DllCall(Numpy.Proc("cnp_random_randint"),
                "Int64", lo, "Int64", hi,
                "Int", shape.Length, "Ptr", shapeBuf.Ptr, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Random.Randint")
        }

        static Integers(shape, lo, hi) {
            Numpy.Init()
            shapeBuf := Numpy.Random._Shape(shape, "Numpy.Random.Integers")
            handle := DllCall(Numpy.Proc("cnp_random_integers"),
                "Int64", lo, "Int64", hi,
                "Int", shape.Length, "Ptr", shapeBuf.Ptr, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Random.Integers")
        }

        static Binomial(shape, n, p) {
            Numpy.Init()
            shapeBuf := Numpy.Random._Shape(shape, "Numpy.Random.Binomial")
            handle := DllCall(Numpy.Proc("cnp_random_binomial"),
                "Int64", n, "Double", p,
                "Int", shape.Length, "Ptr", shapeBuf.Ptr, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Random.Binomial")
        }

        static Poisson(shape, lam) {
            Numpy.Init()
            shapeBuf := Numpy.Random._Shape(shape, "Numpy.Random.Poisson")
            handle := DllCall(Numpy.Proc("cnp_random_poisson"),
                "Double", lam,
                "Int", shape.Length, "Ptr", shapeBuf.Ptr, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Random.Poisson")
        }

        static Exponential(shape, scale := 1.0) {
            Numpy.Init()
            shapeBuf := Numpy.Random._Shape(
                shape, "Numpy.Random.Exponential")
            handle := DllCall(Numpy.Proc("cnp_random_exponential"),
                "Double", scale,
                "Int", shape.Length, "Ptr", shapeBuf.Ptr, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Random.Exponential")
        }

        static Gamma(shape, shapeParam, scale := 1.0) {
            Numpy.Init()
            shapeBuf := Numpy.Random._Shape(shape, "Numpy.Random.Gamma")
            handle := DllCall(Numpy.Proc("cnp_random_gamma"),
                "Double", shapeParam, "Double", scale,
                "Int", shape.Length, "Ptr", shapeBuf.Ptr, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Random.Gamma")
        }

        static Beta(shape, a, b) {
            Numpy.Init()
            shapeBuf := Numpy.Random._Shape(shape, "Numpy.Random.Beta")
            handle := DllCall(Numpy.Proc("cnp_random_beta"),
                "Double", a, "Double", b,
                "Int", shape.Length, "Ptr", shapeBuf.Ptr, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Random.Beta")
        }

        static Logseries(shape, p) => Numpy.Random._OneParameter(
            "cnp_random_logseries", "Numpy.Random.Logseries", shape, p)

        static NegativeBinomial(shape, n, p) =>
            Numpy.Random._TwoParameters(
                "cnp_random_negative_binomial",
                "Numpy.Random.NegativeBinomial", shape, n, p)

        static Pareto(shape, a) => Numpy.Random._OneParameter(
            "cnp_random_pareto", "Numpy.Random.Pareto", shape, a)

        static Power(shape, a) => Numpy.Random._OneParameter(
            "cnp_random_power", "Numpy.Random.Power", shape, a)

        static Rayleigh(shape, scale := 1.0) =>
            Numpy.Random._OneParameter(
                "cnp_random_rayleigh", "Numpy.Random.Rayleigh",
                shape, scale)

        static StandardCauchy(shape) => Numpy.Random._NoParameter(
            "cnp_random_standard_cauchy",
            "Numpy.Random.StandardCauchy", shape)

        static StandardT(shape, df) => Numpy.Random._OneParameter(
            "cnp_random_standard_t", "Numpy.Random.StandardT", shape, df)

        static Triangular(shape, left, mode, right) =>
            Numpy.Random._ThreeParameters(
                "cnp_random_triangular", "Numpy.Random.Triangular",
                shape, left, mode, right)

        static Vonmises(shape, mu, kappa) =>
            Numpy.Random._TwoParameters(
                "cnp_random_vonmises", "Numpy.Random.Vonmises",
                shape, mu, kappa)

        static NoncentralChisquare(shape, df, nonc) =>
            Numpy.Random._TwoParameters(
                "cnp_random_noncentral_chisquare",
                "Numpy.Random.NoncentralChisquare", shape, df, nonc)

        static NoncentralF(shape, dfnum, dfden, nonc) =>
            Numpy.Random._ThreeParameters(
                "cnp_random_noncentral_f", "Numpy.Random.NoncentralF",
                shape, dfnum, dfden, nonc)

        static F(shape, dfnum, dfden) => Numpy.Random._TwoParameters(
            "cnp_random_f", "Numpy.Random.F", shape, dfnum, dfden)

        static Laplace(shape, loc := 0.0, scale := 1.0) =>
            Numpy.Random._TwoParameters(
                "cnp_random_laplace", "Numpy.Random.Laplace",
                shape, loc, scale)

        static Logistic(shape, loc := 0.0, scale := 1.0) =>
            Numpy.Random._TwoParameters(
                "cnp_random_logistic", "Numpy.Random.Logistic",
                shape, loc, scale)

        static Gumbel(shape, loc := 0.0, scale := 1.0) =>
            Numpy.Random._TwoParameters(
                "cnp_random_gumbel", "Numpy.Random.Gumbel",
                shape, loc, scale)

        static Dirichlet(alpha, samples := 1) {
            Numpy.Init()
            values := Numpy.Random._DoubleBuffer(
                alpha, "Numpy.Random.Dirichlet")
            handle := DllCall(Numpy.Proc("cnp_random_dirichlet"),
                "Ptr", values.Ptr, "Int", alpha.Length,
                "Int64", samples, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Random.Dirichlet")
        }

        static Multinomial(n, probabilities, samples := 1) {
            Numpy.Init()
            values := Numpy.Random._DoubleBuffer(
                probabilities, "Numpy.Random.Multinomial")
            handle := DllCall(Numpy.Proc("cnp_random_multinomial"),
                "Int64", n, "Ptr", values.Ptr,
                "Int", probabilities.Length, "Int64", samples, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Random.Multinomial")
        }

        static Weibull(shape, a) => Numpy.Random._OneParameter(
            "cnp_random_weibull", "Numpy.Random.Weibull", shape, a)

        static Chisquare(shape, df) => Numpy.Random._OneParameter(
            "cnp_random_chisquare", "Numpy.Random.Chisquare", shape, df)

        static Geometric(shape, p) => Numpy.Random._OneParameter(
            "cnp_random_geometric", "Numpy.Random.Geometric", shape, p)

        static Zipf(shape, a) => Numpy.Random._OneParameter(
            "cnp_random_zipf", "Numpy.Random.Zipf", shape, a)

        static Wald(shape, mean, scale) => Numpy.Random._TwoParameters(
            "cnp_random_wald", "Numpy.Random.Wald", shape, mean, scale)

        static Hypergeometric(shape, ngood, nbad, nsample) {
            Numpy.Init()
            shapeBuf := Numpy.Random._Shape(
                shape, "Numpy.Random.Hypergeometric")
            handle := DllCall(Numpy.Proc("cnp_random_hypergeometric"),
                "Int64", ngood, "Int64", nbad, "Int64", nsample,
                "Int", shape.Length, "Ptr", shapeBuf.Ptr, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Random.Hypergeometric")
        }

        static MultivariateNormal(mean, covariance, samples := 1) {
            if !(mean is Numpy.NdArray) || !(covariance is Numpy.NdArray)
                throw TypeError(
                    "Numpy.Random.MultivariateNormal inputs must be NdArray values")
            Numpy.Init()
            handle := DllCall(
                Numpy.Proc("cnp_random_multivariate_normal"),
                "Ptr", mean.Handle, "Ptr", covariance.Handle,
                "Int64", samples, "Ptr")
            return Numpy.WrapHandle(
                handle, "Numpy.Random.MultivariateNormal")
        }

        static Bytes(length) {
            if Type(length) != "Integer"
                throw TypeError("Numpy.Random.Bytes length must be an Integer")
            Numpy.Init()
            pointer := DllCall(Numpy.Proc("cnp_random_bytes"),
                "Int64", length, "Ptr")
            if !pointer {
                status := DllCall(
                    Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
                if status != 0
                    Numpy.CheckStatus(status, "Numpy.Random.Bytes")
                throw Error(
                    "Numpy.Random.Bytes returned a null native buffer", -1)
            }
            try {
                result := Buffer(length, 0)
                if length > 0
                    DllCall("ntdll\RtlMoveMemory",
                        "Ptr", result.Ptr, "Ptr", pointer,
                        "UPtr", length, "Ptr")
                return result
            } finally {
                DllCall(Numpy.Proc("cnp_random_bytes_free"),
                    "Ptr", pointer)
            }
        }
    }

    ; =========================================================================
    ; Linear algebra module
    ; =========================================================================

    class Linalg {
        static Cholesky(arr) => Numpy.Cholesky(arr)
        static Det(arr) => Numpy.Det(arr)
        static Slogdet(arr) => Numpy.Slogdet(arr)
        static Eig(source) => Numpy.Eig(source)
        static Eigvals(source) => Numpy.Eigvals(source)
        static Eigh(source, uplo := "L") => Numpy.Eigh(source, uplo)
        static Eigvalsh(source, uplo := "L") => Numpy.Eigvalsh(source, uplo)
        static Svd(
            source, fullMatrices := true,
            computeUV := true, hermitian := false
        ) => Numpy.Svd(source, fullMatrices, computeUV, hermitian)

        static Inv(source) {
            if !(source is Numpy.NdArray)
                throw TypeError(
                    "Numpy.Linalg.Inv source must be an NdArray")
            DllCall(Numpy.Proc("cnp_clear_error"), "Int")
            handle := DllCall(Numpy.Proc("cnp_linalg_inv"),
                "Ptr", source.Handle, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Linalg.Inv")
        }

        static MatrixPower(arr, exponent) {
            Numpy.Init()
            if !(arr is Numpy.NdArray)
                throw TypeError(
                    "Numpy.Linalg.MatrixPower input must be an NdArray")
            if Type(exponent) != "Integer"
                throw TypeError(
                    "Numpy.Linalg.MatrixPower exponent must be an Integer")
            DllCall(Numpy.Proc("cnp_clear_error"), "Int")
            handle := DllCall(Numpy.Proc("cnp_linalg_matrix_power"),
                "Ptr", arr.Handle, "Int64", exponent, "Ptr")
            if handle
                return Numpy.NdArray.FromHandle(handle)
            status := DllCall(Numpy.Proc("cnp_get_error"),
                "Ptr", 0, "Int")
            if status != 0
                Numpy.CheckStatus(status, "Numpy.Linalg.MatrixPower")
            throw Error(
                "Numpy.Linalg.MatrixPower returned null without a native error",
                -1)
        }

        static MatrixRank(arr, tolerance := unset, hermitian := false) {
            Numpy.Init()
            if !(arr is Numpy.NdArray)
                throw TypeError(
                    "Numpy.Linalg.MatrixRank input must be an NdArray")
            if Type(hermitian) != "Integer"
                throw TypeError(
                    "Numpy.Linalg.MatrixRank hermitian must be a Boolean")
            if hermitian != 0 && hermitian != 1
                throw ValueError(
                    "Numpy.Linalg.MatrixRank hermitian must be true or false")

            toleranceArray := 0
            tolerancePointer := 0
            if IsSet(tolerance) {
                if tolerance is Numpy.NdArray {
                    tolerancePointer := tolerance.Handle
                } else if Type(tolerance) = "Integer" ||
                        Type(tolerance) = "Float" {
                    toleranceArray := Numpy.Array([tolerance], [])
                    tolerancePointer := toleranceArray.Handle
                } else {
                    throw TypeError(
                        "Numpy.Linalg.MatrixRank tolerance must be numeric or an NdArray")
                }
            }
            DllCall(Numpy.Proc("cnp_clear_error"), "Int")
            handle := DllCall(Numpy.Proc("cnp_linalg_matrix_rank_v2"),
                "Ptr", arr.Handle, "Ptr", tolerancePointer,
                "Int", hermitian, "Ptr")
            toleranceArray := 0
            if !handle {
                status := DllCall(Numpy.Proc("cnp_get_error"),
                    "Ptr", 0, "Int")
                if status != 0
                    Numpy.CheckStatus(status, "Numpy.Linalg.MatrixRank")
                throw Error(
                    "Numpy.Linalg.MatrixRank returned null without a native error",
                    -1)
            }
            result := Numpy.NdArray.FromHandle(handle)
            if result.Ndim != 0
                return result
            rank := DllCall(Numpy.Proc("cnp_array_get_int"),
                "Ptr", result.Handle, "Ptr", 0, "Int64")
            result := 0
            return rank
        }

        static Norm(source, ord := unset, axis := 0) {
            if !(source is Numpy.NdArray)
                throw TypeError(
                    "Numpy.Linalg.Norm source must be an NdArray")
            if Type(axis) != "Integer"
                throw TypeError("Numpy.Linalg.Norm axis must be an Integer")
            orderBuffer := 0
            orderPointer := 0
            if IsSet(ord) {
                orderType := Type(ord)
                if orderType != "String" && orderType != "Integer"
                        && orderType != "Float"
                    throw TypeError(
                        "Numpy.Linalg.Norm ord must be numeric or a String")
                orderBuffer := Numpy.Utf8Buffer(ord "", "Numpy.Linalg.Norm ord")
                orderPointer := orderBuffer.Ptr
            }
            DllCall(Numpy.Proc("cnp_clear_error"), "Int")
            handle := DllCall(Numpy.Proc("cnp_linalg_norm"),
                "Ptr", source.Handle,
                "Ptr", orderPointer, "Int", axis, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Linalg.Norm")
        }

        static NormExt(source, ord, axis := 0) {
            if !(source is Numpy.NdArray)
                throw TypeError(
                    "Numpy.Linalg.NormExt source must be an NdArray")
            if Type(ord) != "Integer" && Type(ord) != "Float"
                throw TypeError("Numpy.Linalg.NormExt ord must be numeric")
            if Type(axis) != "Integer"
                throw TypeError("Numpy.Linalg.NormExt axis must be an Integer")
            DllCall(Numpy.Proc("cnp_clear_error"), "Int")
            result := DllCall(Numpy.Proc("cnp_linalg_norm_ext"),
                "Ptr", source.Handle,
                "Double", ord, "Int", axis, "Double")
            status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
            Numpy.CheckStatus(status, "Numpy.Linalg.NormExt")
            return result
        }

        static Pinv(source, rcond := 1e-15) {
            if !(source is Numpy.NdArray)
                throw TypeError(
                    "Numpy.Linalg.Pinv source must be an NdArray")
            if Type(rcond) != "Integer" && Type(rcond) != "Float"
                throw TypeError("Numpy.Linalg.Pinv rcond must be numeric")
            DllCall(Numpy.Proc("cnp_clear_error"), "Int")
            handle := DllCall(Numpy.Proc("cnp_linalg_pinv"),
                "Ptr", source.Handle, "Double", rcond, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Linalg.Pinv")
        }

        static Qr(source) {
            if !(source is Numpy.NdArray)
                throw TypeError(
                    "Numpy.Linalg.Qr source must be an NdArray")
            outputs := Buffer(2 * A_PtrSize, 0)
            DllCall(Numpy.Proc("cnp_clear_error"), "Int")
            status := DllCall(Numpy.Proc("cnp_linalg_qr"),
                "Ptr", source.Handle,
                "Ptr", outputs.Ptr,
                "Ptr", outputs.Ptr + A_PtrSize,
                "Int")
            Numpy.CheckStatus(status, "Numpy.Linalg.Qr")
            return Numpy.WrapHandleBuffer(outputs, 2, "Numpy.Linalg.Qr")
        }

        static Tensorinv(source, ind := 2) {
            if !(source is Numpy.NdArray)
                throw TypeError(
                    "Numpy.Linalg.Tensorinv source must be an NdArray")
            if Type(ind) != "Integer"
                throw TypeError("Numpy.Linalg.Tensorinv ind must be an Integer")
            DllCall(Numpy.Proc("cnp_clear_error"), "Int")
            handle := DllCall(Numpy.Proc("cnp_linalg_tensorinv"),
                "Ptr", source.Handle, "Int", ind, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Linalg.Tensorinv")
        }

        static Tensorsolve(left, right, axes := unset) {
            if !(left is Numpy.NdArray) || !(right is Numpy.NdArray)
                throw TypeError(
                    "Numpy.Linalg.Tensorsolve operands must be NdArray values")
            axesBuffer := 0
            axesPointer := 0
            if IsSet(axes) {
                if !(axes is Array)
                    throw TypeError(
                        "Numpy.Linalg.Tensorsolve axes must be an Array")
                axesBuffer := Buffer(Max(axes.Length, 1) * 4, 0)
                for index, value in axes {
                    if Type(value) != "Integer"
                        throw TypeError(
                            "Numpy.Linalg.Tensorsolve axes must contain Integers")
                    NumPut("Int", value, axesBuffer, (index - 1) * 4)
                }
                axesPointer := axesBuffer.Ptr
            }
            DllCall(Numpy.Proc("cnp_clear_error"), "Int")
            handle := DllCall(Numpy.Proc("cnp_linalg_tensorsolve_v2"),
                "Ptr", left.Handle, "Ptr", right.Handle,
                "Int", IsSet(axes) ? axes.Length : 0,
                "Ptr", axesPointer, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Linalg.Tensorsolve")
        }

        static Solve(a, b) => Numpy.Solve(a, b)
        static Lstsq(a, b, rcond := unset) => IsSet(rcond)
            ? Numpy.Lstsq(a, b, rcond) : Numpy.Lstsq(a, b)
        static Cond(source) => Numpy.Cond(source)
    }

    ; =========================================================================
    ; Complex-domain-aware mathematical functions
    ; =========================================================================

    class Emath {
        static _Unary(source, symbol, operation) {
            Numpy.Init()
            if !(source is Numpy.NdArray)
                throw TypeError(operation " source must be an NdArray")
            DllCall(Numpy.Proc("cnp_clear_error"), "Int")
            handle := DllCall(Numpy.Proc(symbol),
                "Ptr", source.Handle, "Ptr")
            return Numpy.WrapHandle(handle, operation)
        }

        static Sqrt(source) => Numpy.Emath._Unary(
            source, "cnp_emath_sqrt", "Numpy.Emath.Sqrt")
        static Log(source) => Numpy.Emath._Unary(
            source, "cnp_emath_log", "Numpy.Emath.Log")
        static Log10(source) => Numpy.Emath._Unary(
            source, "cnp_emath_log10", "Numpy.Emath.Log10")
        static Log2(source) => Numpy.Emath._Unary(
            source, "cnp_emath_log2", "Numpy.Emath.Log2")
        static Arcsin(source) => Numpy.Emath._Unary(
            source, "cnp_emath_arcsin", "Numpy.Emath.Arcsin")
        static Arccos(source) => Numpy.Emath._Unary(
            source, "cnp_emath_arccos", "Numpy.Emath.Arccos")
        static Arctanh(source) => Numpy.Emath._Unary(
            source, "cnp_emath_arctanh", "Numpy.Emath.Arctanh")

        static Power(base, exponent) {
            Numpy.Init()
            if !(base is Numpy.NdArray) || !(exponent is Numpy.NdArray)
                throw TypeError(
                    "Numpy.Emath.Power inputs must be NdArray values")
            DllCall(Numpy.Proc("cnp_clear_error"), "Int")
            handle := DllCall(Numpy.Proc("cnp_emath_power"),
                "Ptr", base.Handle, "Ptr", exponent.Handle, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Emath.Power")
        }
    }

    ; =========================================================================
    ; FFT module
    ; =========================================================================

    class Fft {
        static _RequireArray(source, operation) {
            if !(source is Numpy.NdArray)
                throw TypeError(operation " source must be an NdArray")
        }

        static _RequireInteger(value, operation) {
            if Type(value) != "Integer"
                throw TypeError(operation " must be an Integer")
        }

        static _RequireNumber(value, operation) {
            if Type(value) != "Integer" && Type(value) != "Float"
                throw TypeError(operation " must be numeric")
        }

        static _AxesBuffer(axes, operation) {
            if !(axes is Array)
                throw TypeError(operation " axes must be an Array")
            if axes.Length = 0
                throw ValueError(operation
                    " cannot represent an explicitly empty axes tuple")
            result := Buffer(axes.Length * 4, 0)
            for index, axis in axes {
                Numpy.Fft._RequireInteger(axis, operation " axis " index)
                NumPut("Int", axis, result, (index - 1) * 4)
            }
            return result
        }

        static _ShapeBuffer(shape, operation) {
            if !(shape is Array)
                throw TypeError(operation " shape must be an Array")
            if shape.Length = 0
                throw ValueError(operation " shape must not be empty")
            for index, extent in shape
                Numpy.Fft._RequireInteger(extent,
                    operation " shape item " index)
            return Numpy.ShapeBuffer(shape)
        }

        static Fft(source, n := -1) {
            Numpy.Fft._RequireArray(source, "Numpy.Fft.Fft")
            Numpy.Fft._RequireInteger(n, "Numpy.Fft.Fft n")
            Numpy.Init()
            DllCall(Numpy.Proc("cnp_clear_error"), "Int")
            handle := DllCall(Numpy.Proc("cnp_fft"),
                "Ptr", source.Handle, "Int64", n, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Fft.Fft (cnp_fft)")
        }

        static Ifft(source, n := -1) {
            Numpy.Fft._RequireArray(source, "Numpy.Fft.Ifft")
            Numpy.Fft._RequireInteger(n, "Numpy.Fft.Ifft n")
            Numpy.Init()
            DllCall(Numpy.Proc("cnp_clear_error"), "Int")
            handle := DllCall(Numpy.Proc("cnp_ifft"),
                "Ptr", source.Handle, "Int64", n, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Fft.Ifft (cnp_ifft)")
        }

        static Rfft(source, n := -1) {
            Numpy.Fft._RequireArray(source, "Numpy.Fft.Rfft")
            Numpy.Fft._RequireInteger(n, "Numpy.Fft.Rfft n")
            Numpy.Init()
            DllCall(Numpy.Proc("cnp_clear_error"), "Int")
            handle := DllCall(Numpy.Proc("cnp_rfft"),
                "Ptr", source.Handle, "Int64", n, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Fft.Rfft (cnp_rfft)")
        }

        static Irfft(source, n := -1) {
            Numpy.Fft._RequireArray(source, "Numpy.Fft.Irfft")
            Numpy.Fft._RequireInteger(n, "Numpy.Fft.Irfft n")
            Numpy.Init()
            DllCall(Numpy.Proc("cnp_clear_error"), "Int")
            handle := DllCall(Numpy.Proc("cnp_irfft"),
                "Ptr", source.Handle, "Int64", n, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Fft.Irfft (cnp_irfft)")
        }

        static Fft2(source) {
            Numpy.Fft._RequireArray(source, "Numpy.Fft.Fft2")
            Numpy.Init()
            DllCall(Numpy.Proc("cnp_clear_error"), "Int")
            handle := DllCall(Numpy.Proc("cnp_fft2"),
                "Ptr", source.Handle, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Fft.Fft2 (cnp_fft2)")
        }

        static Ifft2(source) {
            Numpy.Fft._RequireArray(source, "Numpy.Fft.Ifft2")
            Numpy.Init()
            DllCall(Numpy.Proc("cnp_clear_error"), "Int")
            handle := DllCall(Numpy.Proc("cnp_ifft2"),
                "Ptr", source.Handle, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Fft.Ifft2 (cnp_ifft2)")
        }

        static Fftfreq(n, d := 1.0) {
            Numpy.Fft._RequireInteger(n, "Numpy.Fft.Fftfreq n")
            Numpy.Fft._RequireNumber(d, "Numpy.Fft.Fftfreq d")
            Numpy.Init()
            DllCall(Numpy.Proc("cnp_clear_error"), "Int")
            handle := DllCall(Numpy.Proc("cnp_fftfreq"),
                "Int64", n, "Double", d, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Fft.Fftfreq (cnp_fftfreq)")
        }

        static Rfftfreq(n, d := 1.0) {
            Numpy.Fft._RequireInteger(n, "Numpy.Fft.Rfftfreq n")
            Numpy.Fft._RequireNumber(d, "Numpy.Fft.Rfftfreq d")
            Numpy.Init()
            DllCall(Numpy.Proc("cnp_clear_error"), "Int")
            handle := DllCall(Numpy.Proc("cnp_rfftfreq"),
                "Int64", n, "Double", d, "Ptr")
            return Numpy.WrapHandle(handle,
                "Numpy.Fft.Rfftfreq (cnp_rfftfreq)")
        }

        static Fftshift(source) {
            Numpy.Fft._RequireArray(source, "Numpy.Fft.Fftshift")
            Numpy.Init()
            DllCall(Numpy.Proc("cnp_clear_error"), "Int")
            handle := DllCall(Numpy.Proc("cnp_fftshift"),
                "Ptr", source.Handle, "Ptr")
            return Numpy.WrapHandle(handle,
                "Numpy.Fft.Fftshift (cnp_fftshift)")
        }

        static Ifftshift(source) {
            Numpy.Fft._RequireArray(source, "Numpy.Fft.Ifftshift")
            Numpy.Init()
            DllCall(Numpy.Proc("cnp_clear_error"), "Int")
            handle := DllCall(Numpy.Proc("cnp_ifftshift"),
                "Ptr", source.Handle, "Ptr")
            return Numpy.WrapHandle(handle,
                "Numpy.Fft.Ifftshift (cnp_ifftshift)")
        }

        static _NdTransform(symbol, operation, source, axes := unset) {
            Numpy.Fft._RequireArray(source, operation)
            axesBuffer := 0
            axesCount := 0
            if IsSet(axes) {
                axesBuffer := Numpy.Fft._AxesBuffer(axes, operation)
                axesCount := axes.Length
            }
            Numpy.Init()
            DllCall(Numpy.Proc("cnp_clear_error"), "Int")
            handle := DllCall(Numpy.Proc(symbol),
                "Ptr", source.Handle,
                "Int", axesCount,
                "Ptr", axesBuffer ? axesBuffer.Ptr : 0, "Ptr")
            return Numpy.WrapHandle(handle, operation " (" symbol ")")
        }

        static Fftn(source, axes := unset) => IsSet(axes)
            ? Numpy.Fft._NdTransform(
                "cnp_fftn", "Numpy.Fft.Fftn", source, axes)
            : Numpy.Fft._NdTransform(
                "cnp_fftn", "Numpy.Fft.Fftn", source)

        static Ifftn(source, axes := unset) => IsSet(axes)
            ? Numpy.Fft._NdTransform(
                "cnp_ifftn", "Numpy.Fft.Ifftn", source, axes)
            : Numpy.Fft._NdTransform(
                "cnp_ifftn", "Numpy.Fft.Ifftn", source)

        static Rfftn(source, axes := unset) => IsSet(axes)
            ? Numpy.Fft._NdTransform(
                "cnp_rfftn", "Numpy.Fft.Rfftn", source, axes)
            : Numpy.Fft._NdTransform(
                "cnp_rfftn", "Numpy.Fft.Rfftn", source)

        static Irfftn(source, axes := unset, shape := unset) {
            operation := "Numpy.Fft.Irfftn"
            Numpy.Fft._RequireArray(source, operation)
            axesBuffer := 0
            axesCount := 0
            if IsSet(axes) {
                axesBuffer := Numpy.Fft._AxesBuffer(axes, operation)
                axesCount := axes.Length
            }
            shapeBuffer := 0
            shapeCount := 0
            if IsSet(shape) {
                shapeBuffer := Numpy.Fft._ShapeBuffer(shape, operation)
                shapeCount := shape.Length
            }
            Numpy.Init()
            DllCall(Numpy.Proc("cnp_clear_error"), "Int")
            handle := DllCall(Numpy.Proc("cnp_irfftn"),
                "Ptr", source.Handle,
                "Int", axesCount,
                "Ptr", axesBuffer ? axesBuffer.Ptr : 0,
                "Int", shapeCount,
                "Ptr", shapeBuffer ? shapeBuffer.Ptr : 0, "Ptr")
            return Numpy.WrapHandle(handle, operation " (cnp_irfftn)")
        }

        static Hfft(source, n := -1) {
            Numpy.Fft._RequireArray(source, "Numpy.Fft.Hfft")
            Numpy.Fft._RequireInteger(n, "Numpy.Fft.Hfft n")
            Numpy.Init()
            DllCall(Numpy.Proc("cnp_clear_error"), "Int")
            handle := DllCall(Numpy.Proc("cnp_hfft"),
                "Ptr", source.Handle, "Int64", n, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Fft.Hfft (cnp_hfft)")
        }

        static Ihfft(source) {
            Numpy.Fft._RequireArray(source, "Numpy.Fft.Ihfft")
            Numpy.Init()
            DllCall(Numpy.Proc("cnp_clear_error"), "Int")
            handle := DllCall(Numpy.Proc("cnp_ihfft"),
                "Ptr", source.Handle, "Ptr")
            return Numpy.WrapHandle(handle, "Numpy.Fft.Ihfft (cnp_ihfft)")
        }
    }

    ; =========================================================================
    ; Utility
    ; =========================================================================

    static Allclose(a, b, rtol := 1e-05, atol := 1e-08, equalNan := false) {
        Numpy.Init()
        result := Buffer(4, 0)
        status := DllCall(Numpy.Proc("cnp_ahk_allclose_v2"),
            "Ptr", a.Handle, "Ptr", b.Handle,
            "Double", rtol, "Double", atol,
            "Int", equalNan ? 1 : 0, "Ptr", result.Ptr, "Int")
        Numpy.CheckStatus(status, "Numpy.Allclose")
        return NumGet(result, 0, "Int") != 0
    }

    static AssertArrayEqual(actual, desired) {
        if !(actual is Numpy.NdArray) || !(desired is Numpy.NdArray)
            throw TypeError(
                "Numpy.AssertArrayEqual inputs must be NdArray values")
        Numpy.Init()
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        result := DllCall(Numpy.Proc("cnp_assert_array_equal"),
            "Ptr", actual.Handle, "Ptr", desired.Handle, "Char")
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        if status != 0
            Numpy.CheckStatus(status, "Numpy.AssertArrayEqual")
        return result != 0
    }

    static AssertArrayAlmostEqual(actual, desired, decimal := 6) {
        if !(actual is Numpy.NdArray) || !(desired is Numpy.NdArray)
            throw TypeError(
                "Numpy.AssertArrayAlmostEqual inputs must be NdArray values")
        Numpy.Init()
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        result := DllCall(Numpy.Proc("cnp_assert_array_almost_equal"),
            "Ptr", actual.Handle, "Ptr", desired.Handle,
            "Int", decimal, "Char")
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        if status != 0
            Numpy.CheckStatus(status, "Numpy.AssertArrayAlmostEqual")
        return result != 0
    }

    static AssertAllclose(actual, desired, rtol := 1e-07, atol := 0.0) {
        if !(actual is Numpy.NdArray) || !(desired is Numpy.NdArray)
            throw TypeError(
                "Numpy.AssertAllclose inputs must be NdArray values")
        Numpy.Init()
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        result := DllCall(Numpy.Proc("cnp_assert_allclose"),
            "Ptr", actual.Handle, "Ptr", desired.Handle,
            "Double", rtol, "Double", atol, "Char")
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        if status != 0
            Numpy.CheckStatus(status, "Numpy.AssertAllclose")
        return result != 0
    }

    static MinScalarType(value) {
        Numpy.Init()
        return DllCall(Numpy.Proc("cnp_min_scalar_type"),
            "Double", value, "Int")
    }

    static CommonType(arrays*) {
        Numpy.Init()
        handles := Numpy.HandleBuffer(arrays, "Numpy.CommonType")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        dtype := DllCall(Numpy.Proc("cnp_common_type"),
            "Int", arrays.Length, "Ptr", handles.Ptr, "Int")
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        if status != 0
            Numpy.CheckStatus(status, "Numpy.CommonType")
        return dtype
    }

    static _ResolveErrorMode(mode, operation) {
        if Type(mode) != "String"
            throw TypeError(operation " mode must be a String")
        normalized := StrLower(mode)
        if normalized = "warn"
            return 0
        if normalized = "raise"
            return 1
        if normalized = "ignore"
            return 2
        if normalized = "call"
            return 3
        throw ValueError(operation
            " mode must be warn, raise, ignore, or call")
    }

    static _ErrorModeName(code) {
        if code = 0
            return "warn"
        if code = 1
            return "raise"
        if code = 2
            return "ignore"
        if code = 3
            return "call"
        throw ValueError("Numpy.GetErr received an invalid native mode")
    }

    static GetErr() {
        Numpy.Init()
        divide := Buffer(4, 0)
        over := Buffer(4, 0)
        under := Buffer(4, 0)
        invalid := Buffer(4, 0)
        DllCall(Numpy.Proc("cnp_geterr"),
            "Ptr", divide.Ptr, "Ptr", over.Ptr,
            "Ptr", under.Ptr, "Ptr", invalid.Ptr)
        return Map(
            "divide", Numpy._ErrorModeName(NumGet(divide, 0, "Int")),
            "over", Numpy._ErrorModeName(NumGet(over, 0, "Int")),
            "under", Numpy._ErrorModeName(NumGet(under, 0, "Int")),
            "invalid", Numpy._ErrorModeName(NumGet(invalid, 0, "Int")))
    }

    static SetErr(divide := "warn", over := "warn",
            under := "ignore", invalid := "warn") {
        previous := Numpy.GetErr()
        modes := [
            Numpy._ResolveErrorMode(divide, "Numpy.SetErr divide"),
            Numpy._ResolveErrorMode(over, "Numpy.SetErr over"),
            Numpy._ResolveErrorMode(under, "Numpy.SetErr under"),
            Numpy._ResolveErrorMode(invalid, "Numpy.SetErr invalid")]
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        DllCall(Numpy.Proc("cnp_seterr"),
            "Int", modes[1], "Int", modes[2],
            "Int", modes[3], "Int", modes[4])
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        if status != 0
            Numpy.CheckStatus(status, "Numpy.SetErr")
        return previous
    }

    static GetPrintOptions() {
        Numpy.Init()
        precision := Buffer(4, 0)
        threshold := Buffer(4, 0)
        edgeitems := Buffer(4, 0)
        linewidth := Buffer(4, 0)
        suppress := Buffer(4, 0)
        DllCall(Numpy.Proc("cnp_get_printoptions"),
            "Ptr", precision.Ptr, "Ptr", threshold.Ptr,
            "Ptr", edgeitems.Ptr, "Ptr", linewidth.Ptr,
            "Ptr", suppress.Ptr)
        return Map(
            "precision", NumGet(precision, 0, "Int"),
            "threshold", NumGet(threshold, 0, "Int"),
            "edgeitems", NumGet(edgeitems, 0, "Int"),
            "linewidth", NumGet(linewidth, 0, "Int"),
            "suppress", NumGet(suppress, 0, "Int") != 0)
    }

    static SetPrintOptions(precision := unset, threshold := unset,
            edgeitems := unset, linewidth := unset, suppress := unset) {
        previous := Numpy.GetPrintOptions()
        resolvedPrecision := IsSet(precision)
            ? precision : previous["precision"]
        resolvedThreshold := IsSet(threshold)
            ? threshold : previous["threshold"]
        resolvedEdgeitems := IsSet(edgeitems)
            ? edgeitems : previous["edgeitems"]
        resolvedLinewidth := IsSet(linewidth)
            ? linewidth : previous["linewidth"]
        resolvedSuppress := IsSet(suppress)
            ? (suppress ? 1 : 0) : (previous["suppress"] ? 1 : 0)
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        DllCall(Numpy.Proc("cnp_set_printoptions"),
            "Int", resolvedPrecision, "Int", resolvedThreshold,
            "Int", resolvedEdgeitems, "Int", resolvedLinewidth,
            "Int", resolvedSuppress)
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        if status != 0
            Numpy.CheckStatus(status, "Numpy.SetPrintOptions")
        return previous
    }

    static GetBufsize() {
        Numpy.Init()
        return DllCall(Numpy.Proc("cnp_getbufsize"), "Int64")
    }

    static SetBufsize(size) {
        previous := Numpy.GetBufsize()
        status := DllCall(Numpy.Proc("cnp_setbufsize"),
            "Int64", size, "Int")
        Numpy.CheckStatus(status, "Numpy.SetBufsize")
        return previous
    }

    static FormatFloat(value, precision := 8, scientific := false) {
        Numpy.Init()
        outputBuffer := Buffer(Numpy.GetBufsize(), 0)
        status := DllCall(Numpy.Proc("cnp_format_float"),
            "Double", value, "Ptr", outputBuffer.Ptr,
            "Int64", outputBuffer.Size, "Int", precision,
            "Char", scientific ? 1 : 0, "Int")
        Numpy.CheckStatus(status, "Numpy.FormatFloat")
        return StrGet(outputBuffer, "UTF-8")
    }

    static AllocatedMemory() {
        return DllCall(Numpy.Proc("cnp_ahk_allocated_memory"), "Int64")
    }

    static Poly2Cheb(coefficients) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_poly2cheb"),
                "Ptr", coefficients.Handle, "Ptr"),
            "Numpy.Poly2Cheb")
    }

    static Cheb2Poly(coefficients) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_cheb2poly"),
                "Ptr", coefficients.Handle, "Ptr"),
            "Numpy.Cheb2Poly")
    }

    static Poly2Leg(coefficients) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_poly2leg"),
                "Ptr", coefficients.Handle, "Ptr"),
            "Numpy.Poly2Leg")
    }

    static Leg2Poly(coefficients) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_leg2poly"),
                "Ptr", coefficients.Handle, "Ptr"),
            "Numpy.Leg2Poly")
    }

    static ChebAdd(left, right) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_chebadd"),
                "Ptr", left.Handle, "Ptr", right.Handle, "Ptr"),
            "Numpy.ChebAdd")
    }

    static ChebSub(left, right) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_chebsub"),
                "Ptr", left.Handle, "Ptr", right.Handle, "Ptr"),
            "Numpy.ChebSub")
    }

    static ChebVal(points, coefficients) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_chebval"),
                "Ptr", points.Handle, "Ptr", coefficients.Handle, "Ptr"),
            "Numpy.ChebVal")
    }

    static LegVal(points, coefficients) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_legval"),
                "Ptr", points.Handle, "Ptr", coefficients.Handle, "Ptr"),
            "Numpy.LegVal")
    }

    static HermVal(points, coefficients) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_hermval"),
                "Ptr", points.Handle, "Ptr", coefficients.Handle, "Ptr"),
            "Numpy.HermVal")
    }

    static LagVal(points, coefficients) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_lagval"),
                "Ptr", points.Handle, "Ptr", coefficients.Handle, "Ptr"),
            "Numpy.LagVal")
    }

    static ChebFit(x, y, degree) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_chebfit"),
                "Ptr", x.Handle, "Ptr", y.Handle,
                "Int", degree, "Ptr"),
            "Numpy.ChebFit")
    }

    static LegFit(x, y, degree) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_legfit"),
                "Ptr", x.Handle, "Ptr", y.Handle,
                "Int", degree, "Ptr"),
            "Numpy.LegFit")
    }

    static HermFit(x, y, degree) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_hermfit"),
                "Ptr", x.Handle, "Ptr", y.Handle,
                "Int", degree, "Ptr"),
            "Numpy.HermFit")
    }

    static LagFit(x, y, degree) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_lagfit"),
                "Ptr", x.Handle, "Ptr", y.Handle,
                "Int", degree, "Ptr"),
            "Numpy.LagFit")
    }

    static ChebMul(left, right) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_chebmul"),
                "Ptr", left.Handle, "Ptr", right.Handle, "Ptr"),
            "Numpy.ChebMul")
    }

    static LegMul(left, right) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_legmul"),
                "Ptr", left.Handle, "Ptr", right.Handle, "Ptr"),
            "Numpy.LegMul")
    }

    static HermMul(left, right) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_hermmul"),
                "Ptr", left.Handle, "Ptr", right.Handle, "Ptr"),
            "Numpy.HermMul")
    }

    static LagMul(left, right) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_lagmul"),
                "Ptr", left.Handle, "Ptr", right.Handle, "Ptr"),
            "Numpy.LagMul")
    }

    static ChebPts1(count) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_chebpts1"),
                "Int64", count, "Ptr"),
            "Numpy.ChebPts1")
    }

    static ChebPts2(count) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_chebpts2"),
                "Int64", count, "Ptr"),
            "Numpy.ChebPts2")
    }

    static PolyAdd(left, right) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_polyadd"),
                "Ptr", left.Handle, "Ptr", right.Handle, "Ptr"),
            "Numpy.PolyAdd")
    }

    static PolySub(left, right) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_polysub"),
                "Ptr", left.Handle, "Ptr", right.Handle, "Ptr"),
            "Numpy.PolySub")
    }

    static PolyMul(left, right) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_polymul"),
                "Ptr", left.Handle, "Ptr", right.Handle, "Ptr"),
            "Numpy.PolyMul")
    }

    static PolyDiv(dividend, divisor) {
        results := Buffer(2 * A_PtrSize, 0)
        status := DllCall(Numpy.Proc("cnp_polydiv"),
            "Ptr", dividend.Handle, "Ptr", divisor.Handle,
            "Ptr", results.Ptr,
            "Ptr", results.Ptr + A_PtrSize,
            "Int")
        Numpy.CheckStatus(status, "Numpy.PolyDiv")
        return Numpy.WrapHandleBuffer(results, 2, "Numpy.PolyDiv")
    }

    static PolyVal(coefficients, points) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_polyval"),
                "Ptr", coefficients.Handle, "Ptr", points.Handle, "Ptr"),
            "Numpy.PolyVal")
    }

    static PolyFit(x, y, degree) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_polyfit"),
                "Ptr", x.Handle, "Ptr", y.Handle,
                "Int", degree, "Ptr"),
            "Numpy.PolyFit")
    }

    static Poly(roots) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_poly"),
                "Ptr", roots.Handle, "Ptr"),
            "Numpy.Poly")
    }

    static PolyFromRoots(roots) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_polyfromroots"),
                "Ptr", roots.Handle, "Ptr"),
            "Numpy.PolyFromRoots")
    }

    static PolyRoots(coefficients) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_polyroots"),
                "Ptr", coefficients.Handle, "Ptr"),
            "Numpy.PolyRoots")
    }

    static Roots(coefficients) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_roots"),
                "Ptr", coefficients.Handle, "Ptr"),
            "Numpy.Roots")
    }

    static PolyDer(coefficients, m := 1) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_polyder"),
                "Ptr", coefficients.Handle, "Int", m, "Ptr"),
            "Numpy.PolyDer")
    }

    static PolyInt(coefficients, m := 1, constants := unset) {
        constantsHandle := IsSet(constants) ? constants.Handle : 0
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_polyint"),
                "Ptr", coefficients.Handle, "Int", m,
                "Ptr", constantsHandle, "Ptr"),
            "Numpy.PolyInt")
    }

    static ChebDer(coefficients, m := 1) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_chebder"),
                "Ptr", coefficients.Handle, "Int", m, "Ptr"),
            "Numpy.ChebDer")
    }

    static ChebInt(coefficients, m := 1, lbnd := 0.0) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_chebint"),
                "Ptr", coefficients.Handle, "Int", m,
                "Double", lbnd, "Ptr"),
            "Numpy.ChebInt")
    }

    static LegDer(coefficients, m := 1) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_legder"),
                "Ptr", coefficients.Handle, "Int", m, "Ptr"),
            "Numpy.LegDer")
    }

    static HermDer(coefficients, m := 1) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_hermder"),
                "Ptr", coefficients.Handle, "Int", m, "Ptr"),
            "Numpy.HermDer")
    }

    static LagDer(coefficients, m := 1) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_lagder"),
                "Ptr", coefficients.Handle, "Int", m, "Ptr"),
            "Numpy.LagDer")
    }

    static Erf(values) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_erf"),
                "Ptr", values.Handle, "Ptr"),
            "Numpy.Erf")
    }

    static Erfc(values) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_erfc"),
                "Ptr", values.Handle, "Ptr"),
            "Numpy.Erfc")
    }

    static ErfInv(values) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_erfinv"),
                "Ptr", values.Handle, "Ptr"),
            "Numpy.ErfInv")
    }

    static Factorial(values, exact := false) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_factorial"),
                "Ptr", values.Handle, "Int", exact ? 1 : 0, "Ptr"),
            "Numpy.Factorial")
    }

    static Comb(left, right, exact := false) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_comb"),
                "Ptr", left.Handle, "Ptr", right.Handle,
                "Int", exact ? 1 : 0, "Ptr"),
            "Numpy.Comb")
    }

    static Perm(left, right, exact := false) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_perm"),
                "Ptr", left.Handle, "Ptr", right.Handle,
                "Int", exact ? 1 : 0, "Ptr"),
            "Numpy.Perm")
    }

    static FloatToHalf(value) {
        return DllCall(Numpy.Proc("cnp_float_to_half"),
            "Double", value, "UShort")
    }

    static HalfToFloat(bits) {
        if Type(bits) != "Integer" || bits < 0 || bits > 0xFFFF
            throw ValueError(
                "HalfToFloat requires a 16-bit unsigned integer")
        return DllCall(Numpy.Proc("cnp_half_to_float"),
            "UShort", bits, "Double")
    }

    static FinfoEps(dtype) {
        return Numpy._FinfoValue("eps", dtype, "Numpy.FinfoEps")
    }

    static DtypeItemsize(dtype) {
        return Numpy._DtypeMetadata(
            "cnp_dtype_itemsize", dtype, "Int", "Numpy.DtypeItemsize")
    }

    static DtypeKind(dtype) {
        code := Numpy._DtypeMetadata(
            "cnp_dtype_kind", dtype, "Char", "Numpy.DtypeKind")
        return Chr(code)
    }

    static DtypeNew(dtype) {
        DllCall(Numpy.Proc("cnp_clear_error"))
        descriptor := DllCall(Numpy.Proc("cnp_dtype_new"),
            "Int", dtype, "Ptr")
        return Numpy._DtypeDescriptorNumber(descriptor, "Numpy.DtypeNew")
    }

    static DtypeFromChar(character) {
        if Type(character) != "String" || StrLen(character) != 1
            throw TypeError("Numpy.DtypeFromChar requires one character")
        DllCall(Numpy.Proc("cnp_clear_error"))
        descriptor := DllCall(Numpy.Proc("cnp_dtype_from_char"),
            "Char", Ord(character), "Ptr")
        return Numpy._DtypeDescriptorNumber(
            descriptor, "Numpy.DtypeFromChar")
    }

    static DtypeFromString(name) {
        encoded := Numpy.Utf8Buffer(name, "Numpy.DtypeFromString name")
        DllCall(Numpy.Proc("cnp_clear_error"))
        descriptor := DllCall(Numpy.Proc("cnp_dtype_from_string"),
            "Ptr", encoded, "Ptr")
        return Numpy._DtypeDescriptorNumber(
            descriptor, "Numpy.DtypeFromString")
    }

    static _DtypeDescriptorNumber(descriptor, operation) {
        if !descriptor {
            status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
            Numpy.CheckStatus(status, operation)
            throw Error(operation " returned a null dtype descriptor")
        }
        return NumGet(descriptor, 0, "Int")
    }

    static CanCast(fromType, toType, casting := "safe") {
        Numpy.Init()
        if Type(fromType) != "Integer" || Type(toType) != "Integer"
            throw TypeError(
                "Numpy.CanCast dtypes must be integer constants")
        castingMode := Numpy._ResolveCasting(casting, "Numpy.CanCast")

        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        result := DllCall(Numpy.Proc("cnp_dtype_can_cast"),
            "Int", fromType, "Int", toType, "Int", castingMode, "Char")
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        Numpy.CheckStatus(status, "Numpy.CanCast")
        return result != 0
    }

    static CopyTo(destination, source, casting := "same_kind") {
        Numpy.Init()
        if !(destination is Numpy.NdArray)
            throw TypeError("Numpy.CopyTo destination must be an NdArray")
        if !(source is Numpy.NdArray)
            throw TypeError("Numpy.CopyTo source must be an NdArray")
        castingMode := Numpy._ResolveCasting(casting, "Numpy.CopyTo")
        status := DllCall(Numpy.Proc("cnp_copyto"),
            "Ptr", destination.Handle, "Ptr", source.Handle,
            "Int", castingMode, "Int")
        Numpy.CheckStatus(status, "Numpy.CopyTo")
        return destination
    }

    static Where(condition, x := unset, y := unset) {
        Numpy.Init()
        if !(condition is Numpy.NdArray)
            throw TypeError("Numpy.Where condition must be an NdArray")
        hasX := IsSet(x)
        hasY := IsSet(y)
        if hasX != hasY
            throw ValueError("Numpy.Where requires x and y together")

        if !hasX {
            resultCount := Max(condition.Ndim, 1)
            results := Buffer(resultCount * A_PtrSize, 0)
            status := DllCall(Numpy.Proc("cnp_where_indices_v2"),
                "Ptr", condition.Handle,
                "Ptr", results.Ptr, "Int", resultCount, "Int")
            Numpy.CheckStatus(status, "Numpy.Where")
            return Numpy.WrapHandleBuffer(
                results, resultCount, "Numpy.Where")
        }

        if !(x is Numpy.NdArray)
            throw TypeError("Numpy.Where x must be an NdArray")
        if !(y is Numpy.NdArray)
            throw TypeError("Numpy.Where y must be an NdArray")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_where"),
            "Ptr", condition.Handle,
            "Ptr", x.Handle, "Ptr", y.Handle, "Ptr")
        if handle
            return Numpy.NdArray.FromHandle(handle)
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        if status != 0
            Numpy.CheckStatus(status, "Numpy.Where")
        throw Error("Numpy.Where returned null without a native error", -1)
    }

    static ArrayGetItem(source, indices) {
        Numpy._RequireSplitSource(source, "Numpy.ArrayGetItem")
        if !(indices is Array) || indices.Length != source.Ndim
            throw ValueError(
                "Numpy.ArrayGetItem requires one index per dimension")
        indexBuffer := Numpy.ShapeBuffer(indices)
        handle := DllCall(Numpy.Proc("cnp_array_getitem"),
            "Ptr", source.Handle, "Ptr", indexBuffer, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.ArrayGetItem")
    }

    static BooleanIndex(source, mask) {
        Numpy._RequireSplitSource(source, "Numpy.BooleanIndex source")
        Numpy._RequireSplitSource(mask, "Numpy.BooleanIndex mask")
        handle := DllCall(Numpy.Proc("cnp_array_boolean_index"),
            "Ptr", source.Handle, "Ptr", mask.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.BooleanIndex")
    }

    static FancyIndex(source, indices, axis := -1) {
        Numpy._RequireSplitSource(source, "Numpy.FancyIndex source")
        Numpy._RequireSplitSource(indices, "Numpy.FancyIndex indices")
        handle := DllCall(Numpy.Proc("cnp_array_fancy_index"),
            "Ptr", source.Handle, "Ptr", indices.Handle,
            "Int", axis, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.FancyIndex")
    }

    static ArrayWhere(condition, x, y) {
        Numpy._RequireSplitSource(condition, "Numpy.ArrayWhere condition")
        Numpy._RequireSplitSource(x, "Numpy.ArrayWhere x")
        Numpy._RequireSplitSource(y, "Numpy.ArrayWhere y")
        handle := DllCall(Numpy.Proc("cnp_array_where"),
            "Ptr", condition.Handle, "Ptr", x.Handle,
            "Ptr", y.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.ArrayWhere")
    }

    static ArrayNonzero(source) {
        return Numpy._UnaryArrayExport(
            "cnp_array_nonzero", "Numpy.ArrayNonzero", source)
    }

    static ArgWhere(source) {
        return Numpy._UnaryArrayExport(
            "cnp_argwhere", "Numpy.ArgWhere", source)
    }

    static FlatNonzero(source) {
        return Numpy._UnaryArrayExport(
            "cnp_flatnonzero", "Numpy.FlatNonzero", source)
    }

    static _UnaryArrayExport(exportName, operation, source) {
        Numpy._RequireSplitSource(source, operation)
        handle := DllCall(Numpy.Proc(exportName),
            "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, operation)
    }

    static CountNonzero(source, axis := unset, keepdims := false) {
        Numpy._RequireSplitSource(source, "Numpy.CountNonzero")
        axisNone := !IsSet(axis)
        if !axisNone && Type(axis) != "Integer"
            throw TypeError("Numpy.CountNonzero axis must be an Integer")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_count_nonzero_v2"),
            "Ptr", source.Handle,
            "Int", axisNone ? 0 : axis,
            "Int", axisNone, "Int", keepdims, "Ptr")
        result := Numpy.WrapHandle(handle, "Numpy.CountNonzero")
        if !axisNone || keepdims
            return result
        try return result.Item()
        finally result := 0
    }

    static Bincount(values, weights := unset, minlength := 0) {
        Numpy._RequireSplitSource(values, "Numpy.Bincount values")
        weightHandle := 0
        if IsSet(weights) {
            Numpy._RequireSplitSource(weights, "Numpy.Bincount weights")
            weightHandle := weights.Handle
        }
        handle := DllCall(Numpy.Proc("cnp_bincount"),
            "Ptr", values.Handle,
            "Ptr", weightHandle,
            "Int64", minlength,
            "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Bincount")
    }

    static Ediff1d(source, toBegin := unset, toEnd := unset) {
        Numpy._RequireSplitSource(source, "Numpy.Ediff1d")
        hasBegin := IsSet(toBegin)
        hasEnd := IsSet(toEnd)
        beginValue := hasBegin ? toBegin : 0.0
        endValue := hasEnd ? toEnd : 0.0
        handle := DllCall(Numpy.Proc("cnp_ediff1d"),
            "Ptr", source.Handle,
            "Double", beginValue,
            "Double", endValue,
            "Char", hasBegin,
            "Char", hasEnd,
            "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Ediff1d")
    }

    static UnravelIndex(indices, shape) {
        Numpy._RequireSplitSource(indices, "Numpy.UnravelIndex")
        if !(shape is Array)
            throw TypeError("Numpy.UnravelIndex shape must be an Array")
        shapeBuffer := Numpy.ShapeBuffer(shape)
        handle := DllCall(Numpy.Proc("cnp_unravel_index"),
            "Ptr", indices.Handle,
            "Int", shape.Length,
            "Ptr", shapeBuffer,
            "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.UnravelIndex")
    }

    static RavelMultiIndex(multiIndex, shape) {
        Numpy._RequireSplitSource(
            multiIndex, "Numpy.RavelMultiIndex")
        if !(shape is Array)
            throw TypeError("Numpy.RavelMultiIndex shape must be an Array")
        shapeBuffer := Numpy.ShapeBuffer(shape)
        handle := DllCall(Numpy.Proc("cnp_ravel_multi_index"),
            "Ptr", multiIndex.Handle,
            "Int", shape.Length,
            "Ptr", shapeBuffer,
            "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.RavelMultiIndex")
    }

    static TriuIndices(n, k := 0, m := 0) {
        handle := DllCall(Numpy.Proc("cnp_triu_indices"),
            "Int64", n, "Int64", k, "Int64", m, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.TriuIndices")
    }

    static TrilIndices(n, k := 0, m := 0) {
        handle := DllCall(Numpy.Proc("cnp_tril_indices"),
            "Int64", n, "Int64", k, "Int64", m, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.TrilIndices")
    }

    static Sinc(source) {
        return Numpy._UnaryArrayExport(
            "cnp_sinc", "Numpy.Sinc", source)
    }

    static Tril(source, k := 0) {
        Numpy._RequireSplitSource(source, "Numpy.Tril")
        handle := DllCall(Numpy.Proc("cnp_tril"),
            "Ptr", source.Handle, "Int", k, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Tril")
    }

    static Triu(source, k := 0) {
        Numpy._RequireSplitSource(source, "Numpy.Triu")
        handle := DllCall(Numpy.Proc("cnp_triu"),
            "Ptr", source.Handle, "Int", k, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Triu")
    }

    static Diagflat(source, k := 0) {
        Numpy._RequireSplitSource(source, "Numpy.Diagflat")
        handle := DllCall(Numpy.Proc("cnp_diagflat"),
            "Ptr", source.Handle, "Int", k, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Diagflat")
    }

    static Diagonal(source, offset := 0, axis1 := 0, axis2 := 1) {
        Numpy._RequireSplitSource(source, "Numpy.Diagonal")
        handle := DllCall(Numpy.Proc("cnp_diagonal"),
            "Ptr", source.Handle,
            "Int", offset,
            "Int", axis1,
            "Int", axis2,
            "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Diagonal")
    }

    static FillDiagonal(destination, value) {
        Numpy._RequireSplitSource(destination, "Numpy.FillDiagonal")
        status := DllCall(Numpy.Proc("cnp_fill_diagonal"),
            "Ptr", destination.Handle, "Double", value, "Int")
        Numpy.CheckStatus(status, "Numpy.FillDiagonal")
        return destination
    }

    static Extract(condition, source) {
        Numpy._RequireSplitSource(condition, "Numpy.Extract condition")
        Numpy._RequireSplitSource(source, "Numpy.Extract source")
        handle := DllCall(Numpy.Proc("cnp_extract"),
            "Ptr", condition.Handle, "Ptr", source.Handle, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Extract")
    }

    static Nonzero(source) {
        return Numpy._UnaryArrayExport(
            "cnp_nonzero", "Numpy.Nonzero", source)
    }

    static TrimZeros(source, trim := "fb") {
        Numpy._RequireSplitSource(source, "Numpy.TrimZeros")
        trimBuffer := Numpy.Utf8Buffer(trim, "Numpy.TrimZeros trim")
        handle := DllCall(Numpy.Proc("cnp_trim_zeros"),
            "Ptr", source.Handle, "Ptr", trimBuffer, "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.TrimZeros")
    }

    static AsStrided(source, shape, strides := unset) {
        Numpy._RequireSplitSource(source, "Numpy.AsStrided")
        if !(shape is Array)
            throw TypeError("Numpy.AsStrided shape must be an Array")
        shapeBuffer := Numpy.ShapeBuffer(shape)
        stridePointer := 0
        if IsSet(strides) {
            if !(strides is Array)
                throw TypeError("Numpy.AsStrided strides must be an Array")
            if strides.Length != shape.Length
                throw ValueError(
                    "Numpy.AsStrided shape and strides must have equal lengths")
            strideBuffer := Numpy.ShapeBuffer(strides)
            stridePointer := strideBuffer.Ptr
        }
        handle := DllCall(Numpy.Proc("cnp_as_strided"),
            "Ptr", source.Handle,
            "Int", shape.Length,
            "Ptr", shapeBuffer,
            "Ptr", stridePointer,
            "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.AsStrided")
    }

    static SlidingWindowView(source, windowSize, axis := 0) {
        Numpy._RequireSplitSource(source, "Numpy.SlidingWindowView")
        handle := DllCall(Numpy.Proc("cnp_sliding_window_view"),
            "Ptr", source.Handle,
            "Int64", windowSize,
            "Int", axis,
            "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.SlidingWindowView")
    }

    static Rollaxis(source, axis, start := 0) {
        Numpy._RequireSplitSource(source, "Numpy.Rollaxis")
        handle := DllCall(Numpy.Proc("cnp_rollaxis"),
            "Ptr", source.Handle,
            "Int", axis,
            "Int", start,
            "Ptr")
        return Numpy.WrapHandle(handle, "Numpy.Rollaxis")
    }

    static PromoteTypes(leftType, rightType) {
        Numpy.Init()
        if Type(leftType) != "Integer" || Type(rightType) != "Integer"
            throw TypeError(
                "Numpy.PromoteTypes dtypes must be integer constants")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        resultType := DllCall(Numpy.Proc("cnp_promote_types_public"),
            "Int", leftType, "Int", rightType, "Int")
        if resultType != 0
            return resultType
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        if status != 0
            Numpy.CheckStatus(status, "Numpy.PromoteTypes")
        throw Error(
            "Numpy.PromoteTypes returned CNP_NOTYPE without a native error",
            -1)
    }

    static ResultType(arrays) {
        Numpy.Init()
        handles := Numpy.HandleBuffer(arrays, "Numpy.ResultType")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        resultType := DllCall(Numpy.Proc("cnp_result_type"),
            "Int", arrays.Length, "Ptr", handles.Ptr, "Int")
        if resultType != 0
            return resultType
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        if status != 0
            Numpy.CheckStatus(status, "Numpy.ResultType")
        throw Error(
            "Numpy.ResultType returned CNP_NOTYPE without a native error",
            -1)
    }

    static _DtypeMetadata(functionName, dtype, returnType, operation) {
        if Type(dtype) != "Integer"
            throw TypeError(operation " dtype must be an integer constant")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        value := DllCall(Numpy.Proc(functionName),
            "Int", dtype, returnType)
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        Numpy.CheckStatus(status, operation)
        return value
    }

    static FinfoMax(dtype) {
        return Numpy._FinfoValue("max", dtype, "Numpy.FinfoMax")
    }

    static FinfoMin(dtype) {
        return Numpy._FinfoValue("min", dtype, "Numpy.FinfoMin")
    }

    static _FinfoValue(propertyName, dtype, operation) {
        if Type(dtype) != "Integer"
            throw TypeError(operation " dtype must be an integer constant")
        value := DllCall(Numpy.Proc("cnp_finfo_" propertyName),
            "Int", dtype, "Double")
        if value = value
            return value
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        if status = 0
            throw Error(operation " returned NaN without a native error", -1)
        Numpy.CheckStatus(status, operation)
    }

    static Typename(dtype) {
        operation := "Numpy.Typename"
        if Type(dtype) != "Integer"
            throw TypeError(operation " dtype must be an integer constant")
        pointer := DllCall(Numpy.Proc("cnp_typename"),
            "Int", dtype, "Ptr")
        if pointer
            return StrGet(pointer, "UTF-8")

        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        if status = 0
            throw Error(operation " returned null without a native error", -1)
        messagePointer := DllCall(
            Numpy.Proc("cnp_get_error_message"), "Ptr")
        detail := messagePointer ? StrGet(messagePointer, "UTF-8") : ""
        message := operation " failed with status " status
        if detail != ""
            message .= ": " detail
        if status = -3
            throw NumpyKeyError(message)
        Numpy.CheckStatus(status, operation)
    }

    static IinfoMin(dtype) {
        return Numpy._IinfoValues(dtype, "Numpy.IinfoMin")[1]
    }

    static IinfoMax(dtype) {
        ; Values beyond AHK's signed 64-bit range use exact decimal text.
        return Numpy._IinfoValues(dtype, "Numpy.IinfoMax")[2]
    }

    static _IinfoValues(dtype, operation) {
        if Type(dtype) != "Integer"
            throw TypeError(operation " dtype must be an integer constant")
        minimumBuffer := Buffer(8, 0)
        maximumBuffer := Buffer(8, 0)
        status := DllCall(Numpy.Proc("cnp_iinfo_v2"),
            "Int", dtype,
            "Ptr", minimumBuffer, "Ptr", maximumBuffer, "Int")
        Numpy.CheckStatus(status, operation)
        minimum := NumGet(minimumBuffer, 0, "Int64")
        signedMaximum := NumGet(maximumBuffer, 0, "Int64")
        maximum := signedMaximum >= 0
            ? signedMaximum : Numpy._UInt64Decimal(maximumBuffer)
        return [minimum, maximum]
    }

    static _UInt64Decimal(valueBuffer) {
        digits := [0]
        loop 8 {
            carry := NumGet(valueBuffer, 8 - A_Index, "UChar")
            loop digits.Length {
                combined := digits[A_Index] * 256 + carry
                digits[A_Index] := Mod(combined, 10)
                carry := Floor(combined / 10)
            }
            while carry > 0 {
                digits.Push(Mod(carry, 10))
                carry := Floor(carry / 10)
            }
        }
        decimal := ""
        loop digits.Length
            decimal .= digits[digits.Length - A_Index + 1]
        return decimal
    }

    static Spacing(source) {
        Numpy.Init()
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_spacing"),
            "Ptr", source.Handle, "Ptr")
        if handle
            return Numpy.NdArray.FromHandle(handle)
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        if status != 0
            Numpy.CheckStatus(status, "Numpy.Spacing")
        throw Error("Numpy.Spacing returned null without a native error", -1)
    }

    static Nextafter(left, right) {
        Numpy.Init()
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_nextafter"),
            "Ptr", left.Handle, "Ptr", right.Handle, "Ptr")
        if handle
            return Numpy.NdArray.FromHandle(handle)
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        if status != 0
            Numpy.CheckStatus(status, "Numpy.Nextafter")
        throw Error("Numpy.Nextafter returned null without a native error", -1)
    }

    static Copysign(left, right) {
        Numpy.Init()
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_copysign"),
            "Ptr", left.Handle, "Ptr", right.Handle, "Ptr")
        if handle
            return Numpy.NdArray.FromHandle(handle)
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        if status != 0
            Numpy.CheckStatus(status, "Numpy.Copysign")
        throw Error("Numpy.Copysign returned null without a native error", -1)
    }

    static Frexp(source) {
        Numpy.Init()
        handles := Buffer(2 * A_PtrSize, 0)
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        status := DllCall(Numpy.Proc("cnp_frexp"),
            "Ptr", source.Handle,
            "Ptr", handles.Ptr,
            "Ptr", handles.Ptr + A_PtrSize,
            "Int")
        Numpy.CheckStatus(status, "Numpy.Frexp")
        return Numpy.WrapHandleBuffer(handles, 2, "Numpy.Frexp")
    }

    static Modf(source) {
        Numpy.Init()
        handles := Buffer(2 * A_PtrSize, 0)
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        status := DllCall(Numpy.Proc("cnp_modf"),
            "Ptr", source.Handle,
            "Ptr", handles.Ptr,
            "Ptr", handles.Ptr + A_PtrSize,
            "Int")
        Numpy.CheckStatus(status, "Numpy.Modf")
        return Numpy.WrapHandleBuffer(handles, 2, "Numpy.Modf")
    }

    static Ldexp(values, exponents) {
        Numpy.Init()
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc("cnp_ldexp"),
            "Ptr", values.Handle, "Ptr", exponents.Handle, "Ptr")
        if handle
            return Numpy.NdArray.FromHandle(handle)
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        if status != 0
            Numpy.CheckStatus(status, "Numpy.Ldexp")
        throw Error("Numpy.Ldexp returned null without a native error", -1)
    }

    static I0(values) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_i0"),
                "Ptr", values.Handle, "Ptr"),
            "Numpy.I0")
    }

    static J0(values) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_j0"),
                "Ptr", values.Handle, "Ptr"),
            "Numpy.J0")
    }

    static J1(values) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_j1"),
                "Ptr", values.Handle, "Ptr"),
            "Numpy.J1")
    }

    static Digamma(values) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_digamma"),
                "Ptr", values.Handle, "Ptr"),
            "Numpy.Digamma")
    }

    static Zeta(values) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_zeta"),
                "Ptr", values.Handle, "Ptr"),
            "Numpy.Zeta")
    }

    static Expit(values) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_expit"),
                "Ptr", values.Handle, "Ptr"),
            "Numpy.Expit")
    }

    static Logit(values) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_logit"),
                "Ptr", values.Handle, "Ptr"),
            "Numpy.Logit")
    }

    static Gamma(values) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_gamma"),
                "Ptr", values.Handle, "Ptr"),
            "Numpy.Gamma")
    }

    static GammaLn(values) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_gammaln"),
                "Ptr", values.Handle, "Ptr"),
            "Numpy.GammaLn")
    }

    static Beta(left, right) {
        return Numpy.WrapHandle(
            DllCall(Numpy.Proc("cnp_beta"),
                "Ptr", left.Handle, "Ptr", right.Handle, "Ptr"),
            "Numpy.Beta")
    }

    static Set_String_Function(callback := unset, repr := true) {
        Numpy.Init()
        key := repr ? "repr" : "str"
        oldContext := Numpy.StringFunctionContexts.Has(key)
            ? Numpy.StringFunctionContexts[key] : 0

        if !IsSet(callback) {
            status := DllCall(Numpy.Proc("cnp_set_string_function_v2"),
                "Ptr", 0, "Ptr", 0, "Int", repr ? 1 : 0, "Int")
            Numpy.CheckStatus(status, "Numpy.Set_String_Function")
            if oldContext {
                CallbackFree(oldContext.Native)
                Numpy.StringFunctionContexts.Delete(key)
            }
            return
        }
        if !HasMethod(callback, "Call")
            throw TypeError("Numpy.Set_String_Function callback must be callable")

        context := {
            Callback: callback,
            Buffer: 0,
            Error: 0,
            Native: 0
        }
        context.Native := CallbackCreate(
            NumpyStringFunctionCallback, "C", 2)
        status := DllCall(Numpy.Proc("cnp_set_string_function_v2"),
            "Ptr", context.Native, "Ptr", repr ? 1 : 2,
            "Int", repr ? 1 : 0, "Int")
        if status != 0 {
            CallbackFree(context.Native)
            Numpy.CheckStatus(status, "Numpy.Set_String_Function")
        }
        if oldContext
            CallbackFree(oldContext.Native)
        Numpy.StringFunctionContexts[key] := context
    }

    static _InvokeStringFunction(nativeHandle, userdata) {
        key := userdata = 1 ? "repr" : "str"
        context := Numpy.StringFunctionContexts[key]
        try {
            array := Numpy.NdArray.FromHandle(nativeHandle)
            array._owned := false
            text := context.Callback.Call(array)
            if Type(text) != "String"
                throw TypeError("string callback must return a string")
            context.Buffer := Numpy.Utf8Buffer(
                text, "Numpy.Set_String_Function callback result")
            context.Error := 0
            return context.Buffer.Ptr
        } catch Error as err {
            context.Buffer := 0
            context.Error := err
            return 0
        }
    }

    static _InvokeLineFunction(
        linePointer, length, userdata, resultPointer
    ) {
        context := Numpy.CallbackContexts[userdata]
        try {
            line := []
            loop length
                line.Push(NumGet(
                    linePointer, (A_Index - 1) * 8, "Double"))
            return Numpy._WriteCallbackResult(
                context, context.Callback.Call(line), resultPointer)
        } catch Error as err {
            context.Error := err
            return -1
        }
    }

    static _InvokeCoordinateFunction(
        coordinatesPointer, ndim, userdata, resultPointer
    ) {
        context := Numpy.CallbackContexts[userdata]
        try {
            coordinates := []
            loop ndim
                coordinates.Push(NumGet(
                    coordinatesPointer, (A_Index - 1) * 8, "Int64"))
            return Numpy._WriteCallbackResult(
                context, context.Callback.Call(coordinates*), resultPointer)
        } catch Error as err {
            context.Error := err
            return -1
        }
    }

    static _InvokeIteratorFunction(userdata, resultPointer) {
        context := Numpy.CallbackContexts[userdata]
        try return Numpy._WriteCallbackResult(
            context, context.Callback.Call(), resultPointer)
        catch Error as err {
            context.Error := err
            return -1
        }
    }

    static _InvokeUnaryFunction(valuePointer, userdata, resultPointer) {
        context := Numpy.CallbackContexts[userdata]
        try return Numpy._WriteCallbackResult(
            context,
            context.Callback.Call(NumGet(valuePointer, 0, "Double")),
            resultPointer)
        catch Error as err {
            context.Error := err
            return -1
        }
    }

    static _WriteCallbackResult(context, value, resultPointer) {
        valueType := Type(value)
        if valueType != "Integer" && valueType != "Float"
            throw TypeError("numeric callback must return an Integer or Float")
        NumPut("Double", value, resultPointer)
        context.Error := 0
        return 0
    }

    static _InvokeLineBatch(
        linesPointer, lineCount, lineLength, resultsPointer,
        resultCapacity, producedPointer, userdata
    ) {
        context := Numpy.CallbackContexts[userdata]
        produced := 0
        try {
            if resultCapacity != lineCount
                throw ValueError(
                    "scalar line callback result capacity must equal line count")
            loop lineCount {
                line := []
                lineOffset := (A_Index - 1) * lineLength
                loop lineLength
                    line.Push(NumGet(
                        linesPointer,
                        (lineOffset + A_Index - 1) * 8,
                        "Double"))
                Numpy._WriteCallbackResult(
                    context, context.Callback.Call(line),
                    resultsPointer + produced * 8)
                produced += 1
            }
            NumPut("Int64", produced, producedPointer)
            return 0
        } catch Error as err {
            context.Error := err
            NumPut("Int64", produced, producedPointer)
            return -1
        }
    }

    static _InvokeCoordinateBatch(
        coordinatesPointer, pointCount, ndim, resultsPointer,
        resultCapacity, producedPointer, userdata
    ) {
        context := Numpy.CallbackContexts[userdata]
        produced := 0
        try {
            if resultCapacity != pointCount
                throw ValueError(
                    "coordinate callback result capacity must equal point count")
            loop pointCount {
                coordinates := []
                coordinateOffset := (A_Index - 1) * ndim
                loop ndim
                    coordinates.Push(NumGet(
                        coordinatesPointer,
                        (coordinateOffset + A_Index - 1) * 8,
                        "Int64"))
                Numpy._WriteCallbackResult(
                    context, context.Callback.Call(coordinates*),
                    resultsPointer + produced * 8)
                produced += 1
            }
            NumPut("Int64", produced, producedPointer)
            return 0
        } catch Error as err {
            context.Error := err
            NumPut("Int64", produced, producedPointer)
            return -1
        }
    }

    static _InvokeIteratorBatch(
        resultsPointer, resultCapacity, producedPointer, userdata
    ) {
        context := Numpy.CallbackContexts[userdata]
        produced := 0
        try {
            loop resultCapacity {
                Numpy._WriteCallbackResult(
                    context, context.Callback.Call(),
                    resultsPointer + produced * 8)
                produced += 1
            }
            NumPut("Int64", produced, producedPointer)
            return 0
        } catch Error as err {
            context.Error := err
            NumPut("Int64", produced, producedPointer)
            return -1
        }
    }

    static _InvokeUnaryBatch(
        valuesPointer, valueCount, resultsPointer,
        resultCapacity, producedPointer, userdata
    ) {
        context := Numpy.CallbackContexts[userdata]
        produced := 0
        try {
            if resultCapacity != valueCount
                throw ValueError(
                    "unary callback result capacity must equal value count")
            loop valueCount {
                value := NumGet(
                    valuesPointer, (A_Index - 1) * 8, "Double")
                Numpy._WriteCallbackResult(
                    context, context.Callback.Call(value),
                    resultsPointer + produced * 8)
                produced += 1
            }
            NumPut("Int64", produced, producedPointer)
            return 0
        } catch Error as err {
            context.Error := err
            NumPut("Int64", produced, producedPointer)
            return -1
        }
    }

    static AddSqrtSumBatch(left, right, addDestination, sqrtDestination) {
        commands := Buffer(120, 0)
        scalar := Buffer(8, 0)
        failedIndexBuffer := Buffer(8, 0)
        NumPut("Int64", -1, failedIndexBuffer, 0)

        NumPut("UInt", 1, commands, 0)
        NumPut("Ptr", left.Handle, commands, 8)
        NumPut("Ptr", right.Handle, commands, 16)
        NumPut("Ptr", addDestination.Handle, commands, 24)

        NumPut("UInt", 2, commands, 40)
        NumPut("Ptr", addDestination.Handle, commands, 48)
        NumPut("Ptr", sqrtDestination.Handle, commands, 64)

        NumPut("UInt", 4, commands, 80)
        NumPut("Ptr", sqrtDestination.Handle, commands, 88)
        NumPut("Ptr", scalar.Ptr, commands, 104)
        NumPut("Int64", -1, commands, 112)

        status := DllCall(Numpy.Proc("cnp_ahk_execute_batch"),
            "Ptr", commands, "Int64", 3, "Ptr", failedIndexBuffer, "Int")
        failedIndex := NumGet(failedIndexBuffer, 0, "Int64")
        Numpy.CheckStatus(status,
            "Numpy.AddSqrtSumBatch failed_index=" failedIndex)
        return NumGet(scalar, 0, "Double")
    }

    ; =========================================================================
    ; Internal helpers
    ; =========================================================================

    static CheckStatus(status, operation) {
        if status = 0
            return status
        messagePointer := DllCall(Numpy.Proc("cnp_get_error_message"), "Ptr")
        detail := messagePointer ? StrGet(messagePointer, "UTF-8") : ""
        message := operation " failed with status " status
        if detail != ""
            message .= ": " detail
        if status = -3
            throw TypeError(message)
        if status = -4 || status = -5 || status = -6 || status = -7
                || status = -13
            throw ValueError(message)
        throw Error(message, -1)
    }

    static ResolveOrder(order, operation) {
        if order = 0 || order = "C" || order = "c"
            return 0
        if order = 1 || order = "F" || order = "f"
            return 1
        throw ValueError(operation " order must be 'C' or 'F'")
    }

    static _ResolveCasting(casting, operation) {
        if Type(casting) != "String"
            throw TypeError(operation " casting must be a string")
        if casting == "no"
            return 0
        if casting == "equiv"
            return 1
        if casting == "safe"
            return 2
        if casting == "same_kind"
            return 3
        if casting == "unsafe"
            return 4
        throw ValueError(
            operation " requires a valid casting name: "
            "no, equiv, safe, same_kind, or unsafe")
    }

    static _ResolveUplo(uplo, operation) {
        if Type(uplo) != "String"
            throw TypeError(operation " UPLO must be a String")
        if uplo = "L"
            return false
        if uplo = "U"
            return true
        throw ValueError(operation " UPLO must be 'L' or 'U'")
    }

    static _ClipBound(value, operation) {
        if value is Numpy.NdArray
            return [value.Handle, 0]
        valueType := Type(value)
        if valueType = "Integer" {
            owner := Numpy.IntArray([value], [])
            return [owner.Handle, owner]
        }
        if valueType = "Float" {
            owner := Numpy.Array([value], [])
            return [owner.Handle, owner]
        }
        throw TypeError(operation " must be a number or NdArray")
    }

    static WrapHandle(handle, operation) {
        if handle
            return Numpy.NdArray.FromHandle(handle)
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        if status != 0
            Numpy.CheckStatus(status, operation)
        messagePointer := DllCall(Numpy.Proc("cnp_get_error_message"), "Ptr")
        detail := messagePointer ? StrGet(messagePointer, "UTF-8") : ""
        message := operation " returned a null native handle"
        if detail != ""
            message .= ": " detail
        throw Error(message, -1)
    }

    static WrapMaskedHandle(handle, operation, fillValue := 0.0) {
        if handle
            return Numpy.MaskedArray.FromHandle(handle, fillValue)
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        if status != 0
            Numpy.CheckStatus(status, operation)
        messagePointer := DllCall(Numpy.Proc("cnp_get_error_message"), "Ptr")
        detail := messagePointer ? StrGet(messagePointer, "UTF-8") : ""
        message := operation " returned a null native masked-array handle"
        if detail != ""
            message .= ": " detail
        throw Error(message, -1)
    }

    static ShapeBuffer(shapeArr) {
        buf := Buffer(shapeArr.Length * 8, 0)
        for i, v in shapeArr
            NumPut("Int64", v, buf, (i - 1) * 8)
        return buf
    }

    static Utf8Buffer(value, operation) {
        if Type(value) != "String"
            throw TypeError(operation " must be a string")
        encoded := Buffer(StrPut(value, "UTF-8"), 0)
        StrPut(value, encoded, "UTF-8")
        return encoded
    }

    static _CharRequireInteger(value, operation) {
        if Type(value) != "Integer"
            throw TypeError(operation " must be an Integer")
        return value
    }

    static _CharInputPointers(values, operation) {
        if !(values is Array)
            throw TypeError(operation " must be an Array")
        pointers := Buffer(Max(values.Length, 1) * A_PtrSize, 0)
        owners := []
        for index, value in values {
            owner := Numpy.Utf8Buffer(value, operation " item " index)
            owners.Push(owner)
            NumPut("Ptr", owner.Ptr, pointers, (index - 1) * A_PtrSize)
        }
        return [pointers, owners]
    }

    static _CharRepeatBuffer(repeats, operation) {
        if !(repeats is Array)
            throw TypeError(operation " must be an Array")
        result := Buffer(Max(repeats.Length, 1) * 8, 0)
        for index, value in repeats {
            Numpy._CharRequireInteger(value, operation " item " index)
            NumPut("Int64", value, result, (index - 1) * 8)
        }
        return result
    }

    static _CharRequireResult(handle, operation) {
        if handle
            return handle
        status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
        if status != 0
            Numpy.CheckStatus(status, operation)
        throw Error(operation " returned a null native result without an error", -1)
    }

    static _CharStringResult(handle, operation) {
        handle := Numpy._CharRequireResult(handle, operation)
        try {
            dtype := DllCall(Numpy.Proc("cnp_array_dtype_num"),
                "Ptr", handle, "Int")
            if dtype != Numpy.DT_OBJECT
                throw Error(operation " returned native dtype " dtype
                    " instead of object string storage", -1)
            size := DllCall(Numpy.Proc("cnp_array_size"),
                "Ptr", handle, "Int64")
            if size < 0 {
                status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
                Numpy.CheckStatus(status, operation)
            }
            indexBuffer := Buffer(8, 0)
            result := []
            loop size {
                NumPut("Int64", A_Index - 1, indexBuffer)
                slot := DllCall(Numpy.Proc("cnp_array_at"),
                    "Ptr", handle, "Ptr", indexBuffer, "Ptr")
                if !slot {
                    status := DllCall(
                        Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
                    Numpy.CheckStatus(status, operation)
                }
                valuePointer := NumGet(slot, 0, "Ptr")
                if !valuePointer
                    throw Error(operation " returned a null string slot", -1)
                result.Push(StrGet(valuePointer, "UTF-8"))
            }
            return result
        } finally {
            DllCall(Numpy.Proc("cnp_char_free_result"), "Ptr", handle)
        }
    }

    static _CharIntegerResult(handle, operation) {
        handle := Numpy._CharRequireResult(handle, operation)
        try {
            dtype := DllCall(Numpy.Proc("cnp_array_dtype_num"),
                "Ptr", handle, "Int")
            if dtype != Numpy.DT_INT32
                throw Error(operation " returned native dtype " dtype
                    " instead of int32", -1)
            size := DllCall(Numpy.Proc("cnp_array_size"),
                "Ptr", handle, "Int64")
            if size < 0 {
                status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
                Numpy.CheckStatus(status, operation)
            }
            indexBuffer := Buffer(8, 0)
            result := []
            loop size {
                NumPut("Int64", A_Index - 1, indexBuffer)
                address := DllCall(Numpy.Proc("cnp_array_at"),
                    "Ptr", handle, "Ptr", indexBuffer, "Ptr")
                if !address {
                    status := DllCall(
                        Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
                    Numpy.CheckStatus(status, operation)
                }
                result.Push(NumGet(address, 0, "Int"))
            }
            return result
        } finally {
            DllCall(Numpy.Proc("cnp_char_free_result"), "Ptr", handle)
        }
    }

    static _CharUnaryString(values, symbol, operation) {
        Numpy.Init()
        input := Numpy._CharInputPointers(values, operation " values")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc(symbol),
            "Ptr", input[1], "Int64", values.Length, "Ptr")
        return Numpy._CharStringResult(handle, operation " (" symbol ")")
    }

    static _CharUnaryInteger(values, symbol, operation) {
        Numpy.Init()
        input := Numpy._CharInputPointers(values, operation " values")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc(symbol),
            "Ptr", input[1], "Int64", values.Length, "Ptr")
        return Numpy._CharIntegerResult(handle, operation " (" symbol ")")
    }

    static _CharStrip(values, chars := unset, symbol := "", operation := "") {
        Numpy.Init()
        input := Numpy._CharInputPointers(values, operation " values")
        charsPointer := 0
        if IsSet(chars) {
            charsBuffer := Numpy.Utf8Buffer(chars, operation " chars")
            charsPointer := charsBuffer.Ptr
        }
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc(symbol),
            "Ptr", input[1], "Int64", values.Length,
            "Ptr", charsPointer, "Ptr")
        return Numpy._CharStringResult(handle, operation " (" symbol ")")
    }

    static _CharJustify(values, width, fillchar, symbol, operation) {
        Numpy.Init()
        Numpy._CharRequireInteger(width, operation " width")
        input := Numpy._CharInputPointers(values, operation " values")
        fillBuffer := Numpy.Utf8Buffer(fillchar, operation " fillchar")
        if fillBuffer.Size != 2
            throw ValueError(operation " fillchar must encode to one non-NUL byte")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc(symbol),
            "Ptr", input[1], "Int64", values.Length,
            "Int64", width, "Char", NumGet(fillBuffer, 0, "UChar"), "Ptr")
        return Numpy._CharStringResult(handle, operation " (" symbol ")")
    }

    static _CharSubstringInteger(values, substring, symbol, operation) {
        Numpy.Init()
        input := Numpy._CharInputPointers(values, operation " values")
        substringBuffer := Numpy.Utf8Buffer(
            substring, operation " substring")
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc(symbol),
            "Ptr", input[1], "Int64", values.Length,
            "Ptr", substringBuffer, "Ptr")
        return Numpy._CharIntegerResult(handle, operation " (" symbol ")")
    }

    static _RequireProductPair(left, right, operation) {
        if !(left is Numpy.NdArray) || !(right is Numpy.NdArray)
            throw TypeError(operation " inputs must be NdArray values")
    }

    static _RegisterCallback(
        callback, nativeFunction, parameterCount, operation
    ) {
        if !HasMethod(callback, "Call")
            throw TypeError(operation " callback must be callable")
        token := Numpy.NextCallbackToken
        Numpy.NextCallbackToken += 1
        context := {
            Callback: callback,
            Error: 0,
            Native: 0,
            Token: token
        }
        context.Native := CallbackCreate(
            nativeFunction, "C", parameterCount)
        Numpy.CallbackContexts[token] := context
        return context
    }

    static _ReleaseCallback(context) {
        if context.Native {
            CallbackFree(context.Native)
            context.Native := 0
        }
        if Numpy.CallbackContexts.Has(context.Token)
            Numpy.CallbackContexts.Delete(context.Token)
    }

    static _CallbackResult(handle, context, operation) {
        if context.Error {
            callbackError := context.Error
            context.Error := 0
            if handle
                DllCall(Numpy.Proc("cnp_ahk_free"), "Ptr", handle, "Int")
            throw callbackError
        }
        return Numpy.WrapHandle(handle, operation)
    }

    static _UnaryCallbackArray(callback, source, symbol, operation) {
        if !(source is Numpy.NdArray)
            throw TypeError(operation " source must be an NdArray")
        context := Numpy._RegisterCallback(
            callback, NumpyUnaryBatchCallback, 6, operation)
        try {
            handle := DllCall(Numpy.Proc(symbol),
                "Ptr", context.Native, "Ptr", context.Token,
                "Ptr", source.Handle, "Ptr")
            return Numpy._CallbackResult(handle, context, operation)
        } finally Numpy._ReleaseCallback(context)
    }

    static _ProductBinary(left, right, symbol, operation) {
        Numpy._RequireProductPair(left, right, operation)
        DllCall(Numpy.Proc("cnp_clear_error"), "Int")
        handle := DllCall(Numpy.Proc(symbol),
            "Ptr", left.Handle, "Ptr", right.Handle, "Ptr")
        return Numpy.WrapHandle(handle, operation)
    }

    static HandleBuffer(arrays, operation) {
        if !(arrays is Array)
            throw TypeError(operation " arrays must be an Array")
        handles := Buffer(Max(arrays.Length, 1) * A_PtrSize, 0)
        for index, item in arrays {
            if !(item is Numpy.NdArray)
                throw TypeError(
                    operation " item " index " must be an NdArray")
            NumPut("Ptr", item.Handle, handles, (index - 1) * A_PtrSize)
        }
        return handles
    }

    static WrapHandleBuffer(buffer, count, operation) {
        nativeHandles := []
        missingIndex := 0
        loop count {
            handle := NumGet(buffer, (A_Index - 1) * A_PtrSize, "Ptr")
            if !handle && !missingIndex
                missingIndex := A_Index
            nativeHandles.Push(handle)
        }
        if missingIndex {
            for nativeHandle in nativeHandles {
                if nativeHandle
                    DllCall(Numpy.Proc("cnp_ahk_free"),
                        "Ptr", nativeHandle, "Int")
            }
            throw Error(
                operation " returned a null handle at result " missingIndex, -1)
        }

        wrapped := []
        try {
            for handle in nativeHandles
                wrapped.Push(Numpy.NdArray.FromHandle(handle))
        } catch Error as err {
            for item in wrapped
                item.Handle := 0
            for handle in nativeHandles
                DllCall(Numpy.Proc("cnp_ahk_free"), "Ptr", handle, "Int")
            throw err
        }
        return wrapped
    }

    ; =========================================================================
    ; MaskedArray - owns an opaque C masked-array handle
    ; =========================================================================

    class MaskedArray {
        Handle := 0
        FillValue := 0.0
        _owned := true

        static FromHandle(handle, fillValue := 0.0) {
            owner := Numpy.MaskedArray()
            owner.Handle := handle
            owner.FillValue := fillValue
            owner._owned := true
            return owner
        }

        __Delete() {
            if this.Handle && this._owned {
                DllCall(Numpy.Proc("cnp_masked_array_free"),
                    "Ptr", this.Handle)
                this.Handle := 0
            }
        }

        Data {
            get {
                handle := DllCall(Numpy.Proc("cnp_masked_array_get_data"),
                    "Ptr", this.Handle, "Ptr")
                return Numpy.WrapHandle(handle, "MaskedArray.Data")
            }
        }

        Mask {
            get {
                handle := DllCall(Numpy.Proc("cnp_masked_array_get_mask"),
                    "Ptr", this.Handle, "Ptr")
                return Numpy.WrapHandle(handle, "MaskedArray.Mask")
            }
        }

        SetMask(mask) {
            if !(mask is Numpy.NdArray)
                throw TypeError("MaskedArray.SetMask mask must be an NdArray")
            status := DllCall(Numpy.Proc("cnp_masked_array_set_mask"),
                "Ptr", this.Handle, "Ptr", mask.Handle, "Int")
            Numpy.CheckStatus(status, "MaskedArray.SetMask")
            return this
        }

        Filled(fillValue := unset) {
            resolved := IsSet(fillValue) ? fillValue : this.FillValue
            handle := DllCall(Numpy.Proc("cnp_masked_array_filled"),
                "Ptr", this.Handle, "Double", resolved, "Ptr")
            return Numpy.WrapHandle(handle, "MaskedArray.Filled")
        }

        Compressed() {
            handle := DllCall(Numpy.Proc("cnp_masked_array_compressed"),
                "Ptr", this.Handle, "Ptr")
            return Numpy.WrapHandle(handle, "MaskedArray.Compressed")
        }

        Count() => this._Scalar(
            "cnp_masked_array_count", "MaskedArray.Count", "Int64")
        Sum() => this._Scalar(
            "cnp_masked_array_sum", "MaskedArray.Sum", "Double")
        Mean() => this._Scalar(
            "cnp_masked_array_mean", "MaskedArray.Mean", "Double")
        Std() => this._Scalar(
            "cnp_masked_array_std", "MaskedArray.Std", "Double")
        Min() => this._Scalar(
            "cnp_masked_array_min", "MaskedArray.Min", "Double")
        Max() => this._Scalar(
            "cnp_masked_array_max", "MaskedArray.Max", "Double")

        _Scalar(symbol, operation, returnType) {
            DllCall(Numpy.Proc("cnp_clear_error"))
            value := DllCall(Numpy.Proc(symbol),
                "Ptr", this.Handle, returnType)
            status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
            Numpy.CheckStatus(status, operation)
            return value
        }
    }

    ; =========================================================================
    ; NdArray - wraps an opaque C array handle
    ; =========================================================================

    class NdArray {
        Handle := 0
        _owned := true
        _metadataLoaded := false
        _ndim := 0
        _size := 0
        _dtype := 0
        _itemSize := 0
        _flags := 0
        _shape := 0

        static FromHandle(handle) {
            arr := Numpy.NdArray()
            arr.Handle := handle
            arr._owned := true
            arr._metadataLoaded := false
            arr._shape := []
            return arr
        }

        __Delete() {
            if this.Handle && this._owned {
                DllCall(Numpy.Proc("cnp_ahk_free"), "Ptr", this.Handle, "Int")
                this.Handle := 0
            }
        }

        ; --- Properties ---

        Ndim {
            get {
                this._LoadMetadata()
                return this._ndim
            }
        }

        Size {
            get {
                this._LoadMetadata()
                return this._size
            }
        }

        Dtype {
            get {
                this._LoadMetadata()
                return this._dtype
            }
        }

        ItemSize {
            get {
                this._LoadMetadata()
                return this._itemSize
            }
        }

        Nbytes {
            get {
                this._LoadMetadata()
                return this._size * this._itemSize
            }
        }

        Flags {
            get {
                this._LoadMetadata()
                return this._flags
            }
        }

        CContiguous {
            get {
                this._LoadMetadata()
                return (this._flags & Numpy.ARRAY_C_CONTIGUOUS) != 0
            }
        }

        FContiguous {
            get {
                this._LoadMetadata()
                return (this._flags & Numpy.ARRAY_F_CONTIGUOUS) != 0
            }
        }

        Shape {
            get {
                this._LoadMetadata()
                return this._shape.Clone()
            }
        }

        Strides {
            get {
                ndim := this.Ndim
                if ndim = 0
                    return []
                pointer := DllCall(Numpy.Proc("cnp_array_strides"),
                    "Ptr", this.Handle, "Ptr")
                if !pointer {
                    status := DllCall(Numpy.Proc("cnp_get_error"),
                        "Ptr", 0, "Int")
                    if status != 0
                        Numpy.CheckStatus(status, "NdArray.Strides")
                    throw Error(
                        "NdArray.Strides returned a null native pointer", -1)
                }
                strides := []
                loop ndim
                    strides.Push(NumGet(
                        pointer, (A_Index - 1) * 8, "Int64"))
                return strides
            }
        }

        ; --- Data access ---

        /** Get all elements as flat AHK array of doubles. */
        ToArray() {
            size := this.Size
            if size <= 0
                return []
            buf := Buffer(size * 8, 0)
            DllCall(Numpy.Proc("cnp_ahk_get_doubles"),
                "Ptr", this.Handle, "Ptr", buf, "Int64", size, "Int64")
            result := []
            loop size
                result.Push(NumGet(buf, (A_Index - 1) * 8, "Double"))
            return result
        }

        /** Set data from flat AHK array of doubles. */
        SetData(data) {
            count := data.Length
            buf := Buffer(count * 8, 0)
            for i, v in data
                NumPut("Double", v, buf, (i - 1) * 8)
            written := DllCall(Numpy.Proc("cnp_ahk_set_doubles"),
                "Ptr", this.Handle, "Ptr", buf, "Int64", count, "Int64")
            if written < 0
                Numpy.CheckStatus(written, "NdArray.SetData")
            if written != count
                throw ValueError(
                    "NdArray.SetData wrote " written " of " count " values")
            return this
        }

        /** Get single element by flat index. */
        GetItem(index) {
            DllCall(Numpy.Proc("cnp_clear_error"))
            value := DllCall(Numpy.Proc("cnp_ahk_get_item"),
                "Ptr", this.Handle, "Int64", index, "Double")
            status := DllCall(Numpy.Proc("cnp_get_error"), "Ptr", 0, "Int")
            Numpy.CheckStatus(status, "NdArray.GetItem")
            return value
        }

        /** Set single element by flat index. */
        SetItem(index, value) {
            status := DllCall(Numpy.Proc("cnp_ahk_set_item"),
                "Ptr", this.Handle, "Int64", index, "Double", value, "Int")
            Numpy.CheckStatus(status, "NdArray.SetItem")
            return this
        }

        Flush() {
            status := DllCall(Numpy.Proc("cnp_memmap_flush"),
                "Ptr", this.Handle, "Int")
            Numpy.CheckStatus(status, "NdArray.Flush")
            return this
        }

        __Item[index] {
            get => this.GetItem(index - 1)
            set => this.SetItem(index - 1, value)
        }

        ; --- Unary math (return new NdArray) ---

        Negative() => Numpy.Negative(this)
        Positive() => Numpy.Positive(this)
        IsNan() => Numpy.IsNan(this)
        IsInf() => Numpy.IsInf(this)
        IsFinite() => Numpy.IsFinite(this)
        Signbit() => Numpy.Signbit(this)
        IsComplexObj() => Numpy.IsComplexObj(this)
        IsRealObj() => Numpy.IsRealObj(this)
        IsScalar() => Numpy.IsScalar(this)
        Absolute() => this._Unary("cnp_ahk_absolute")
        Abs() => this._Unary("cnp_ahk_absolute")
        Fabs() => this._Unary("cnp_ahk_fabs")
        Sqrt() => Numpy.Sqrt(this)
        Cbrt() => Numpy.Cbrt(this)
        Conj() => Numpy.Conj(this)
        Conjugate() => Numpy.Conjugate(this)
        Histogram(bins := 10, rangeMin := 0.0, rangeMax := 0.0) =>
            Numpy.Histogram(this, bins, rangeMin, rangeMax)
        Histogram2d(y, bins := 10) => Numpy.Histogram2d(this, y, bins)
        Interp(xp, fp) => Numpy.Interp(this, xp, fp)
        InterpNd(xp, fp, left, right) =>
            Numpy.InterpNd(this, xp, fp, left, right)
        NanToNum(nanValue, positiveInfinity, negativeInfinity) =>
            Numpy.NanToNum(
                this, nanValue, positiveInfinity, negativeInfinity)
        Vander(columns := -1, increasing := false) =>
            Numpy.Vander(this, columns, increasing)
        Diff(n := 1, axis := -1) => Numpy.Diff(this, n, axis)
        Gradient(axis := -1) => Numpy.Gradient(this, axis)
        Unwrap(discont := 3.141592653589793) => Numpy.Unwrap(this, discont)
        SqrtInto(destination) {
            status := DllCall(Numpy.Proc("cnp_ahk_sqrt_into"),
                "Ptr", this.Handle, "Ptr", destination.Handle, "Int")
            Numpy.CheckStatus(status, "NdArray.SqrtInto")
            return destination
        }
        Square() => Numpy.Square(this)
        Exp() => Numpy.Exp(this)
        Exp2() => Numpy.Exp2(this)
        Expm1() => Numpy.Expm1(this)
        Log() => Numpy.Log(this)
        Log2() => Numpy.Log2(this)
        Log10() => Numpy.Log10(this)
        Log1p() => Numpy.Log1p(this)
        Sin() => Numpy.Sin(this)
        Cos() => Numpy.Cos(this)
        Tan() => Numpy.Tan(this)
        Arcsin() => Numpy.Arcsin(this)
        Arccos() => Numpy.Arccos(this)
        Arctan() => Numpy.Arctan(this)
        Degrees() => Numpy.Degrees(this)
        Radians() => Numpy.Radians(this)
        Deg2rad() => Numpy.Deg2rad(this)
        Rad2deg() => Numpy.Rad2deg(this)
        Sinh() => Numpy.Sinh(this)
        Cosh() => Numpy.Cosh(this)
        Tanh() => Numpy.Tanh(this)
        Arcsinh() => Numpy.Arcsinh(this)
        Arccosh() => Numpy.Arccosh(this)
        Arctanh() => Numpy.Arctanh(this)
        Floor() => this._Unary("cnp_ahk_floor")
        Ceil() => this._Unary("cnp_ahk_ceil")
        Rint() => this._Unary("cnp_ahk_rint")
        Fix() => this._Unary("cnp_ahk_fix")
        Trunc() => this._Unary("cnp_ahk_trunc")
        Sign() => Numpy.Sign(this)
        Reciprocal() => Numpy.Reciprocal(this)
        Spacing() => Numpy.Spacing(this)
        Nextafter(other) => Numpy.Nextafter(this, other)
        Copysign(other) => Numpy.Copysign(this, other)
        Frexp() => Numpy.Frexp(this)
        Modf() => Numpy.Modf(this)
        Ldexp(exponents) => Numpy.Ldexp(this, exponents)
        LogicalNot() => Numpy.LogicalNot(this)

        ; --- Binary math (return new NdArray) ---

        Add(other) => this._Binary("cnp_ahk_add", other)
        AddInto(other, destination) {
            status := DllCall(Numpy.Proc("cnp_ahk_add_into"),
                "Ptr", this.Handle, "Ptr", other.Handle,
                "Ptr", destination.Handle, "Int")
            Numpy.CheckStatus(status, "NdArray.AddInto")
            return destination
        }
        Subtract(other) => Numpy.Subtract(this, other)
        Multiply(other) => Numpy.Multiply(this, other)
        Divide(other) => Numpy.Divide(this, other)
        TrueDivide(other) => Numpy.TrueDivide(this, other)
        FloorDivide(other) => Numpy.FloorDivide(this, other)
        Divmod(other) => Numpy.Divmod(this, other)
        Power(other) => Numpy.Power(this, other)
        FloatPower(other) => Numpy.FloatPower(this, other)
        Heaviside(other) => Numpy.Heaviside(this, other)
        Gcd(other) => Numpy.Gcd(this, other)
        Lcm(other) => Numpy.Lcm(this, other)
        Mod(other) => Numpy.Mod(this, other)
        Remainder(other) => Numpy.Remainder(this, other)
        Fmod(other) => Numpy.Fmod(this, other)
        Arctan2(other) => Numpy.Arctan2(this, other)
        Hypot(other) => Numpy.Hypot(this, other)
        Logaddexp(other) => Numpy.Logaddexp(this, other)
        Logaddexp2(other) => Numpy.Logaddexp2(this, other)
        Equal(other) => Numpy.Equal(this, other)
        NotEqual(other) => Numpy.NotEqual(this, other)
        Less(other) => Numpy.Less(this, other)
        LessEqual(other) => Numpy.LessEqual(this, other)
        Greater(other) => Numpy.Greater(this, other)
        GreaterEqual(other) => Numpy.GreaterEqual(this, other)
        Maximum(other) => Numpy.Maximum(this, other)
        Minimum(other) => Numpy.Minimum(this, other)
        Fmax(other) => Numpy.Fmax(this, other)
        Fmin(other) => Numpy.Fmin(this, other)
        LogicalAnd(other) => Numpy.LogicalAnd(this, other)
        LogicalOr(other) => Numpy.LogicalOr(this, other)
        LogicalXor(other) => Numpy.LogicalXor(this, other)
        BitwiseAnd(other) => Numpy.BitwiseAnd(this, other)
        BitwiseOr(other) => Numpy.BitwiseOr(this, other)
        BitwiseXor(other) => Numpy.BitwiseXor(this, other)
        LeftShift(other) => Numpy.LeftShift(this, other)
        RightShift(other) => Numpy.RightShift(this, other)
        Invert() => Numpy.Invert(this)
        BitwiseNot() => Numpy.BitwiseNot(this)
        Dot(other) => this._Binary("cnp_ahk_dot", other)
        Matmul(other) => this._Binary("cnp_ahk_matmul", other)
        Eig() => Numpy.Eig(this)
        Eigvals() => Numpy.Eigvals(this)
        Cholesky() => Numpy.Cholesky(this)
        Det() => Numpy.Det(this)
        Slogdet() => Numpy.Slogdet(this)
        Eigh(uplo := "L") => Numpy.Eigh(this, uplo)
        Eigvalsh(uplo := "L") => Numpy.Eigvalsh(this, uplo)
        ToFile(filename) => Numpy.ToFile(this, filename)
        Svd(fullMatrices := true, computeUV := true, hermitian := false) =>
            Numpy.Svd(this, fullMatrices, computeUV, hermitian)

        ; --- Reductions ---

        Sum(axis := unset) {
            axisNone := !IsSet(axis)
            return this._ReductionV2(
                "cnp_ahk_sum_v2", axisNone ? 0 : axis, axisNone)
        }

        Prod(axis := unset) {
            axisNone := !IsSet(axis)
            return this._ReductionV2(
                "cnp_ahk_prod_v2", axisNone ? 0 : axis, axisNone)
        }

        Mean(axis := unset) {
            axisNone := !IsSet(axis)
            return this._ReductionV2(
                "cnp_ahk_mean_v2", axisNone ? 0 : axis, axisNone)
        }

        Average(axis := unset, weights := unset) {
            axisNone := !IsSet(axis)
            weightsHandle := 0
            if IsSet(weights) {
                Numpy._RequireSplitSource(
                    weights, "NdArray.Average weights")
                weightsHandle := weights.Handle
            }
            handle := DllCall(Numpy.Proc("cnp_ahk_average_v2"),
                "Ptr", this.Handle,
                "Int", axisNone ? 0 : axis,
                "Int", axisNone,
                "Ptr", weightsHandle,
                "Ptr")
            result := Numpy.WrapHandle(handle, "cnp_ahk_average_v2")
            if axisNone {
                value := result.GetItem(0)
                result := 0
                return value
            }
            return result
        }

        Std(axis := unset, ddof := 0) {
            axisNone := !IsSet(axis)
            return this._DeviationReductionV2(
                "cnp_ahk_std_v2", axisNone ? 0 : axis, axisNone, ddof)
        }

        Var(axis := unset, ddof := 0) {
            axisNone := !IsSet(axis)
            return this._DeviationReductionV2(
                "cnp_ahk_var_v2", axisNone ? 0 : axis, axisNone, ddof)
        }

        Max(axis := unset) {
            axisNone := !IsSet(axis)
            return this._ReductionV2(
                "cnp_ahk_max_v2", axisNone ? 0 : axis, axisNone)
        }

        Min(axis := unset) {
            axisNone := !IsSet(axis)
            return this._ReductionV2(
                "cnp_ahk_min_v2", axisNone ? 0 : axis, axisNone)
        }

        Argmax(axis := unset) {
            axisNone := !IsSet(axis)
            return this._ReductionV2(
                "cnp_ahk_argmax_v2", axisNone ? 0 : axis, axisNone)
        }

        Argmin(axis := unset) {
            axisNone := !IsSet(axis)
            return this._ReductionV2(
                "cnp_ahk_argmin_v2", axisNone ? 0 : axis, axisNone)
        }

        Any(axis := unset) {
            axisNone := !IsSet(axis)
            return this._ReductionV2(
                "cnp_ahk_any_v2", axisNone ? 0 : axis, axisNone)
        }

        All(axis := unset) {
            axisNone := !IsSet(axis)
            return this._ReductionV2(
                "cnp_ahk_all_v2", axisNone ? 0 : axis, axisNone)
        }

        Ptp(axis := unset) {
            axisNone := !IsSet(axis)
            return this._ReductionV2(
                "cnp_ahk_ptp_v2", axisNone ? 0 : axis, axisNone)
        }

        Nansum(axis := unset) {
            axisNone := !IsSet(axis)
            return this._ReductionV2(
                "cnp_ahk_nansum_v2", axisNone ? 0 : axis, axisNone)
        }

        Nanprod(axis := unset) {
            axisNone := !IsSet(axis)
            return this._ReductionV2(
                "cnp_ahk_nanprod_v2", axisNone ? 0 : axis, axisNone)
        }

        Nanmean(axis := unset) {
            axisNone := !IsSet(axis)
            return this._ReductionV2(
                "cnp_ahk_nanmean_v2", axisNone ? 0 : axis, axisNone)
        }

        Nanvar(axis := unset, ddof := 0) {
            axisNone := !IsSet(axis)
            return this._DeviationReductionV2(
                "cnp_ahk_nanvar_v2", axisNone ? 0 : axis, axisNone, ddof)
        }

        Nanstd(axis := unset, ddof := 0) {
            axisNone := !IsSet(axis)
            return this._DeviationReductionV2(
                "cnp_ahk_nanstd_v2", axisNone ? 0 : axis, axisNone, ddof)
        }

        Nanmax(axis := unset) {
            axisNone := !IsSet(axis)
            return this._ReductionV2(
                "cnp_ahk_nanmax_v2", axisNone ? 0 : axis, axisNone)
        }

        Nanmin(axis := unset) {
            axisNone := !IsSet(axis)
            return this._ReductionV2(
                "cnp_ahk_nanmin_v2", axisNone ? 0 : axis, axisNone)
        }

        Nanargmax(axis := unset) {
            axisNone := !IsSet(axis)
            return this._ReductionV2(
                "cnp_ahk_nanargmax_v2", axisNone ? 0 : axis, axisNone)
        }

        Nanargmin(axis := unset) {
            axisNone := !IsSet(axis)
            return this._ReductionV2(
                "cnp_ahk_nanargmin_v2", axisNone ? 0 : axis, axisNone)
        }

        Median(axis := unset) {
            axisNone := !IsSet(axis)
            return this._ReductionV2(
                "cnp_ahk_median_v2", axisNone ? 0 : axis, axisNone)
        }

        Nanmedian(axis := unset) {
            axisNone := !IsSet(axis)
            return this._ReductionV2(
                "cnp_ahk_nanmedian_v2", axisNone ? 0 : axis, axisNone)
        }

        Percentile(q, axis := unset) {
            axisNone := !IsSet(axis)
            return this._PercentileReductionV2(
                "cnp_ahk_percentile_v2", q,
                axisNone ? 0 : axis, axisNone)
        }

        Nanpercentile(q, axis := unset) {
            axisNone := !IsSet(axis)
            return this._PercentileReductionV2(
                "cnp_ahk_nanpercentile_v2", q,
                axisNone ? 0 : axis, axisNone)
        }

        Quantile(q, axis := unset) {
            axisNone := !IsSet(axis)
            return this._PercentileReductionV2(
                "cnp_ahk_quantile_v2", q,
                axisNone ? 0 : axis, axisNone)
        }

        Nanquantile(q, axis := unset) {
            axisNone := !IsSet(axis)
            return this._PercentileReductionV2(
                "cnp_ahk_nanquantile_v2", q,
                axisNone ? 0 : axis, axisNone)
        }

        SumIntoScalar() {
            scalar := Buffer(8, 0)
            status := DllCall(Numpy.Proc("cnp_ahk_sum_into_scalar"),
                "Ptr", this.Handle, "Ptr", scalar, "Int")
            Numpy.CheckStatus(status, "NdArray.SumIntoScalar")
            return NumGet(scalar, 0, "Double")
        }

        ; --- Reductions returning arrays ---

        Cumsum(axis := unset) {
            axisNone := !IsSet(axis)
            return this._ReductionV2(
                "cnp_ahk_cumsum_v2", axisNone ? 0 : axis,
                axisNone, false)
        }

        CumsumInto(destination, axis := -1) {
            status := DllCall(Numpy.Proc("cnp_ahk_cumsum_into"),
                "Ptr", this.Handle, "Int", axis,
                "Ptr", destination.Handle, "Int")
            Numpy.CheckStatus(status, "NdArray.CumsumInto")
            return destination
        }

        Cumprod(axis := unset) {
            axisNone := !IsSet(axis)
            return this._ReductionV2(
                "cnp_ahk_cumprod_v2", axisNone ? 0 : axis,
                axisNone, false)
        }

        Nancumsum(axis := unset) {
            axisNone := !IsSet(axis)
            return this._ReductionV2(
                "cnp_ahk_nancumsum_v2", axisNone ? 0 : axis,
                axisNone, false)
        }

        Nancumprod(axis := unset) {
            axisNone := !IsSet(axis)
            return this._ReductionV2(
                "cnp_ahk_nancumprod_v2", axisNone ? 0 : axis,
                axisNone, false)
        }

        Softmax(axis := -1) => Numpy.Softmax(this, axis)
        LogSoftmax(axis := -1) => Numpy.LogSoftmax(this, axis)
        Log_Softmax(axis := -1) => Numpy.LogSoftmax(this, axis)

        Trapz(x := unset, dx := 1.0, axis := -1) {
            if IsSet(x)
                return Numpy.Trapz(this, x, dx, axis)
            return Numpy.Trapz(this, , dx, axis)
        }

        Packbits(axis := unset, bitorder := "big") {
            if IsSet(axis)
                return Numpy.Packbits(this, axis, bitorder)
            return Numpy.Packbits(this, , bitorder)
        }

        Unpackbits(
            axis := unset, count := unset, bitorder := "big"
        ) {
            if IsSet(axis) {
                if IsSet(count)
                    return Numpy.Unpackbits(
                        this, axis, count, bitorder)
                return Numpy.Unpackbits(this, axis, , bitorder)
            }
            if IsSet(count)
                return Numpy.Unpackbits(this, , count, bitorder)
            return Numpy.Unpackbits(this, , , bitorder)
        }

        ; --- Shape manipulation ---

        Reshape(shape) {
            shapeBuf := Numpy.ShapeBuffer(shape)
            handle := DllCall(Numpy.Proc("cnp_ahk_reshape"),
                "Ptr", this.Handle, "Int", shape.Length, "Ptr", shapeBuf, "Ptr")
            return Numpy.WrapHandle(handle, "NdArray.Reshape")
        }

        Transpose() => this._Unary("cnp_ahk_transpose")
        TransposeCopy() => this._Unary("cnp_ahk_transpose_copy")
        AsContiguousArray() => this._Unary("cnp_ahk_copy")
        Flatten() => this._Unary("cnp_ahk_flatten")
        Ravel() => this._Unary("cnp_ahk_ravel")
        Squeeze(axis := unset) {
            if IsSet(axis)
                return Numpy.Squeeze(this, axis)
            return Numpy.Squeeze(this)
        }
        Copy() => this._Unary("cnp_ahk_copy")
        View() => Numpy.View(this)
        Diag(k := 0) => Numpy.Diag(this, k)
        Swapaxes(axis1, axis2) => Numpy.Swapaxes(this, axis1, axis2)
        Moveaxis(sourceAxis, destinationAxis) =>
            Numpy.Moveaxis(this, sourceAxis, destinationAxis)
        ExpandDims(axis) => Numpy.ExpandDims(this, axis)
        BroadcastTo(shape) => Numpy.BroadcastTo(this, shape)
        Tile(reps) => Numpy.Tile(this, reps)
        Repeat(repeats, axis := -1) => Numpy.Repeat(this, repeats, axis)
        Flip(axis := -1) => Numpy.Flip(this, axis)
        Rot90(k := 1, axis1 := 0, axis2 := 1) =>
            Numpy.Rot90(this, k, axis1, axis2)
        Roll(shift, axis := -1) => Numpy.Roll(this, shift, axis)
        Append(values, axis := -1) => Numpy.Append(this, values, axis)
        Pad(padWidth, constantValue := 0.0) =>
            Numpy.Pad(this, padWidth, constantValue)
        Slice(start, stop, step := 1, axis := 0) =>
            Numpy.Slice(this, start, stop, step, axis)
        Atleast1d() => this._Unary("cnp_ahk_atleast_1d")
        Atleast2d() => this._Unary("cnp_ahk_atleast_2d")
        Atleast3d() => this._Unary("cnp_ahk_atleast_3d")
        Atleast_1d() => this.Atleast1d()
        Atleast_2d() => this.Atleast2d()
        Atleast_3d() => this.Atleast3d()

        ; --- Sorting ---

        Sort(axis := -1, kind := "quicksort") {
            resolvedAxis := Numpy._ResolveSortAxis(axis, "NdArray.Sort")
            kindCode := Numpy._ResolveSortKind(kind, "NdArray.Sort")
            handle := DllCall(Numpy.Proc("cnp_ahk_sort_v2"),
                "Ptr", this.Handle,
                "Int", resolvedAxis[1], "Int", resolvedAxis[2],
                "Int", kindCode, "Ptr")
            return Numpy.WrapHandle(handle, "NdArray.Sort")
        }

        Argsort(axis := -1, kind := "quicksort") {
            resolvedAxis := Numpy._ResolveSortAxis(axis, "NdArray.Argsort")
            kindCode := Numpy._ResolveSortKind(kind, "NdArray.Argsort")
            handle := DllCall(Numpy.Proc("cnp_ahk_argsort_v2"),
                "Ptr", this.Handle,
                "Int", resolvedAxis[1], "Int", resolvedAxis[2],
                "Int", kindCode, "Ptr")
            return Numpy.WrapHandle(handle, "NdArray.Argsort")
        }

        Partition(kth, axis := -1, kind := "introselect") {
            return Numpy._PartitionResult(
                "cnp_ahk_partition_v2", "NdArray.Partition",
                this, kth, axis, kind)
        }

        Argpartition(kth, axis := -1, kind := "introselect") {
            return Numpy._PartitionResult(
                "cnp_ahk_argpartition_v2", "NdArray.Argpartition",
                this, kth, axis, kind)
        }

        Searchsorted(values, side := "left", sorter := unset) {
            if IsSet(sorter)
                return Numpy.Searchsorted(this, values, side, sorter)
            return Numpy.Searchsorted(this, values, side)
        }

        Digitize(bins, right := false) {
            return Numpy.Digitize(this, bins, right)
        }

        Unique(
            returnIndex := false,
            returnInverse := false, returnCounts := false
        ) => Numpy.Unique(
            this, returnIndex, returnInverse, returnCounts)

        ; --- Comparison / logic ---

        Clip(aMin := unset, aMax := unset) {
            if IsSet(aMin) {
                if IsSet(aMax)
                    return Numpy.Clip(this, aMin, aMax)
                return Numpy.Clip(this, aMin)
            }
            if IsSet(aMax)
                return Numpy.Clip(this, , aMax)
            return Numpy.Clip(this)
        }

        BitwiseCount() => Numpy.BitwiseCount(this)
        Item(flatIndex := 0) => Numpy.Item(this, flatIndex)

        Around(decimals := 0) => Numpy.Around(this, decimals)
        Round(decimals := 0) => Numpy.Round(this, decimals)

        static Where(cond, x, y) => Numpy.Where(cond, x, y)

        ; --- Concatenation ---

        Concatenate(other, axis := 0) {
            handle := DllCall(Numpy.Proc("cnp_ahk_concatenate"),
                "Ptr", this.Handle, "Ptr", other.Handle, "Int", axis, "Ptr")
            if !handle
                throw Error("Concatenate failed", -1)
            return Numpy.NdArray.FromHandle(handle)
        }

        Vstack(other) {
            handle := DllCall(Numpy.Proc("cnp_ahk_vstack"),
                "Ptr", this.Handle, "Ptr", other.Handle, "Ptr")
            if !handle
                throw Error("Vstack failed", -1)
            return Numpy.NdArray.FromHandle(handle)
        }

        Hstack(other) {
            handle := DllCall(Numpy.Proc("cnp_ahk_hstack"),
                "Ptr", this.Handle, "Ptr", other.Handle, "Ptr")
            if !handle
                throw Error("Hstack failed", -1)
            return Numpy.NdArray.FromHandle(handle)
        }

        ; --- Type conversion ---

        Astype(dtype) {
            handle := DllCall(Numpy.Proc("cnp_ahk_astype"),
                "Ptr", this.Handle, "Int", dtype, "Ptr")
            if !handle
                throw Error("Astype failed", -1)
            return Numpy.NdArray.FromHandle(handle)
        }

        ; --- String representation ---

        ToString() {
            return this._StringRepresentation(false)
        }

        Repr() {
            return this._StringRepresentation(true)
        }

        _StringRepresentation(repr) {
            key := repr ? "repr" : "str"
            context := Numpy.StringFunctionContexts.Has(key)
                ? Numpy.StringFunctionContexts[key] : 0
            if context
                context.Error := 0
            pointer := DllCall(Numpy.Proc("cnp_array_string_v2"),
                "Ptr", this.Handle, "Int", repr ? 1 : 0, "Ptr")
            if !pointer {
                if context && context.Error {
                    callbackError := context.Error
                    context.Error := 0
                    throw callbackError
                }
                messagePointer := DllCall(
                    Numpy.Proc("cnp_get_error_message"), "Ptr")
                detail := messagePointer
                    ? StrGet(messagePointer, "UTF-8") : ""
                message := "Numpy.NdArray string conversion failed"
                if detail != ""
                    message .= ": " detail
                throw Error(message, -1)
            }
            try return StrGet(pointer, "UTF-8")
            finally DllCall(Numpy.Proc("cnp_char_free_string"),
                "Ptr", pointer)
        }

        ; --- Internal helpers ---

        _Unary(funcName) {
            handle := DllCall(Numpy.Proc(funcName),
                "Ptr", this.Handle, "Ptr")
            return Numpy.WrapHandle(handle, funcName)
        }

        _Binary(funcName, other) {
            handle := DllCall(Numpy.Proc(funcName),
                "Ptr", this.Handle, "Ptr", other.Handle, "Ptr")
            return Numpy.WrapHandle(handle, funcName)
        }

        _LoadMetadata() {
            if this._metadataLoaded
                return
            metadata := Buffer(Numpy.MetadataSize, 0)
            status := DllCall(Numpy.Proc("cnp_ahk_get_metadata"),
                "Ptr", this.Handle,
                "Ptr", metadata.Ptr, "UInt", metadata.Size, "Int")
            Numpy.CheckStatus(status, "NdArray._LoadMetadata")

            abiVersion := NumGet(metadata, 0, "UInt")
            structSize := NumGet(metadata, 4, "UInt")
            if abiVersion != Numpy.MetadataAbiVersion
                throw Error("unsupported metadata ABI version " abiVersion, -1)
            if structSize != Numpy.MetadataSize
                throw Error("unexpected metadata size " structSize, -1)
            ndim := NumGet(metadata, 8, "Int")
            if ndim < 0 || ndim > Numpy.MetadataMaxDims
                throw Error("invalid native metadata ndim " ndim, -1)

            shape := []
            loop ndim {
                dimension := NumGet(metadata, 32 + (A_Index - 1) * 8, "Int64")
                if dimension < 0
                    throw Error("negative native shape dimension " dimension, -1)
                shape.Push(dimension)
            }
            this._ndim := ndim
            this._dtype := NumGet(metadata, 12, "Int")
            this._itemSize := NumGet(metadata, 16, "Int")
            this._flags := NumGet(metadata, 20, "UInt")
            this._size := NumGet(metadata, 24, "Int64")
            this._shape := shape
            this._metadataLoaded := true
        }

        _ReductionV2(funcName, axis, axisNone, scalarWhenNone := true) {
            handle := DllCall(Numpy.Proc(funcName),
                "Ptr", this.Handle, "Int", axis,
                "Int", axisNone, "Ptr")
            result := Numpy.WrapHandle(handle, funcName)
            if axisNone && scalarWhenNone {
                value := result.GetItem(0)
                result := 0
                return value
            }
            return result
        }

        _DeviationReductionV2(funcName, axis, axisNone, ddof) {
            handle := DllCall(Numpy.Proc(funcName),
                "Ptr", this.Handle, "Int", axis,
                "Int", axisNone, "Int", ddof, "Ptr")
            result := Numpy.WrapHandle(handle, funcName)
            if axisNone {
                value := result.GetItem(0)
                result := 0
                return value
            }
            return result
        }

        _PercentileReductionV2(funcName, q, axis, axisNone) {
            handle := DllCall(Numpy.Proc(funcName),
                "Ptr", this.Handle, "Double", q,
                "Int", axis, "Int", axisNone, "Ptr")
            result := Numpy.WrapHandle(handle, funcName)
            if axisNone {
                value := result.GetItem(0)
                result := 0
                return value
            }
            return result
        }

        _ReductionArray(funcName, axis) {
            handle := DllCall(Numpy.Proc(funcName),
                "Ptr", this.Handle, "Int", axis, "Ptr")
            if !handle {
                messagePointer := DllCall(Numpy.Proc("cnp_get_error_message"), "Ptr")
                detail := messagePointer ? StrGet(messagePointer, "UTF-8") : ""
                message := funcName ": native reduction returned null"
                if detail != ""
                    message .= ": " detail
                throw Error(message, -1)
            }
            return Numpy.NdArray.FromHandle(handle)
        }
    }
}
