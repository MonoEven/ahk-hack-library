; cnumpy_bridge.ahk - CnpArray <-> native AHK value bridge.
;
; No hardcoded CnpArray offsets.  Metadata comes from the public NdArray
; wrapper and native exports (cnp_ahk_data_ptr, cnp_dtype_kind), and native
; Array construction uses the runtime-discovered AHK layout (AhkLayout) with
; cnumpy's own fillers.
;
; Caller must #Include ahk_layout.ahk and numpy.ahk before this file
; (lib/cnumpy/init.ahk does this).

#Include ..\ahk_hack.ahk

class CnpBridge {
    static DllPath := ""

    static EnsureDll() {
        if Numpy.DllHandle
            return
        if CnpBridge.DllPath != "" and Numpy.DllPath = ""
            Numpy.DllPath := CnpBridge.DllPath
        Numpy.Init()
    }

    static Metadata(ndarray) {
        CnpBridge.EnsureDll()
        if !(ndarray is Numpy.NdArray)
            throw TypeError("expected Numpy.NdArray, got " Type(ndarray))
        handle := ndarray.Handle
        if !handle
            throw Error("NdArray handle is null")
        dataPtr := DllCall(Numpy.Proc("cnp_ahk_data_ptr"),
            "Ptr", handle, "Ptr")
        if !dataPtr
            throw Error("cnp_ahk_data_ptr returned null")
        dtype := ndarray.Dtype
        kindCode := DllCall(Numpy.Proc("cnp_dtype_kind"),
            "Int", dtype, "Char")
        flags := ndarray.Flags
        return Map(
            "ndim", ndarray.Ndim,
            "shape", ndarray.Shape,
            "strides", ndarray.Strides,
            "size", ndarray.Size,
            "data", dataPtr,
            "dtype", dtype,
            "item_size", ndarray.ItemSize,
            "kind", Chr(kindCode),
            "flags", flags,
            "c_contiguous", ndarray.CContiguous,
            "writeable", (flags & 0x0400) != 0
        )
    }

    ; Deep copy to a nested native AHK Array (C-order).
    static ToAhk(ndarray) {
        CnpBridge.EnsureDll()
        flat := ndarray.ToArray()
        shape := ndarray.Shape
        pos := 0
        return CnpBridge._Reshape(flat, shape, &pos)
    }

    ; Fast deep copy: read raw element bytes directly (numeric dtypes only,
    ; C-contiguous arrays only).
    static ToAhkFast(ndarray) {
        meta := CnpBridge.Metadata(ndarray)
        typeName := CnpBridge._TypeFor(meta)
        if typeName = ""
            throw Error("ToAhkFast supports numeric dtypes only")
        if !meta["c_contiguous"]
            throw Error("ToAhkFast requires a C-contiguous array")
        flat := []
        loop meta["size"] {
            flat.Push(NumGet(
                meta["data"] + (A_Index - 1) * meta["item_size"], typeName))
        }
        pos := 0
        return CnpBridge._Reshape(flat, meta["shape"], &pos)
    }

    ; Native deep copy using the runtime-discovered interpreter layout and
    ; cnumpy's own fillers.  No hardcoded Array or CnpArray offsets.
    static ToAhkNative(ndarray) {
        CnpBridge.EnsureDll()
        if !ndarray.CContiguous
            throw ValueError("ToAhkNative requires a C-contiguous array")
        typeCode := CnpBridge._TypeCode(CnpBridge.Metadata(ndarray))
        if typeCode < 0
            throw TypeError("ToAhkNative supports numeric dtypes only")
        if ndarray.Ndim = 0
            return ndarray.GetItem(0)

        layout := AhkLayout.Discover()
        layoutBuf := AhkLayout.ToBuffer(layout)
        dataPtr := DllCall(Numpy.Proc("cnp_ahk_data_ptr"),
            "Ptr", ndarray.Handle, "Ptr")
        if !dataPtr
            throw Error("cnp_ahk_data_ptr returned null")

        shape := ndarray.Shape
        root := CnpBridge._BuildEmptyNativeTree(shape)
        if ndarray.Ndim = 1 {
            status := DllCall(Numpy.Proc("cnp_ahk_fill_array_flat"),
                "Ptr", ObjPtr(root), "Ptr", dataPtr,
                "Int64", shape[1], "Int", ndarray.ItemSize,
                "Int", typeCode, "Ptr", layoutBuf.Ptr, "Int")
        } else {
            shapeBuf := Numpy.ShapeBuffer(shape)
            status := DllCall(Numpy.Proc("cnp_ahk_fill_array_nd"),
                "Ptr", ObjPtr(root), "Ptr", dataPtr,
                "Int", ndarray.Ndim, "Ptr", shapeBuf,
                "Int", ndarray.ItemSize, "Int", typeCode,
                "Ptr", layoutBuf.Ptr, "Int")
        }
        Numpy.CheckStatus(status, "CnpBridge.ToAhkNative")
        return root
    }

    ; Build the empty nested Array tree.  Parents hold children through the
    ; public Push API; cnumpy's fillers read the object variants.
    static _BuildEmptyNativeTree(shape, dim := 1) {
        count := shape[dim]
        result := Array()
        result.Capacity := count
        if dim = shape.Length
            return result
        loop count {
            child := CnpBridge._BuildEmptyNativeTree(shape, dim + 1)
            result.Push(child)
        }
        return result
    }

    ; Zero-copy read/write view.  The view holds a strong reference to the
    ; owning NdArray, so cnumpy memory cannot be freed while the view lives.
    static View(ndarray) => CnpView(ndarray)

    ; Copy the raw element bytes into an AHK-owned Buffer.
    static ToBuffer(ndarray) {
        meta := CnpBridge.Metadata(ndarray)
        if meta["size"] = 0
            return Buffer(0)
        buf := Buffer(meta["size"] * meta["item_size"])
        DllCall("msvcrt\memcpy", "Ptr", buf.Ptr, "Ptr", meta["data"],
            "UPtr", buf.Size)
        return buf
    }

    ; Build an owned NdArray from a nested native AHK Array (slow path:
    ; conversion happens in cnumpy through doubles).
    static FromAhk(data, dtype := 13) {
        CnpBridge.EnsureDll()
        shape := CnpBridge._ShapeOf(data)
        flat := CnpBridge._Flatten(data)
        return Numpy.Array(flat, shape, dtype)
    }

    ; Fast path: create an empty array and write exact-dtype bytes directly.
    static FromAhkFast(data, dtype := 13) {
        CnpBridge.EnsureDll()
        shape := CnpBridge._ShapeOf(data)
        flat := CnpBridge._Flatten(data)
        arr := Numpy.Empty(shape, dtype, "C")
        return CnpBridge.WriteRaw(arr, flat)
    }

    ; Build an owned NdArray from raw bytes (cnumpy copies the buffer).
    static FromBuffer(buffer, dtype) {
        CnpBridge.EnsureDll()
        return Numpy.FromBuffer(buffer, dtype)
    }

    ; Write flat AHK values directly into a C-contiguous numeric array.
    static WriteRaw(arr, flat) {
        meta := CnpBridge.Metadata(arr)
        typeName := CnpBridge._TypeFor(meta)
        if typeName = ""
            throw Error("WriteRaw supports numeric dtypes only")
        if !meta["writeable"]
            throw Error("array is not writeable")
        if !meta["c_contiguous"]
            throw Error("WriteRaw requires a C-contiguous array")
        count := meta["size"]
        if flat.Length != count
            throw Error("flat length " flat.Length " != array size " count)
        buf := Buffer(count * meta["item_size"])
        loop count {
            NumPut(typeName, flat[A_Index], buf,
                (A_Index - 1) * meta["item_size"])
        }
        DllCall("msvcrt\memcpy", "Ptr", meta["data"], "Ptr", buf.Ptr,
            "UPtr", buf.Size)
        return arr
    }

    static _TypeFor(meta) {
        kind := meta["kind"]
        size := meta["item_size"]
        if kind = "f" or kind = "c" {
            if size = 8
                return "Double"
            if size = 4
                return "Float"
        }
        if kind = "i" or kind = "u" or kind = "b" {
            if size = 8
                return kind = "u" ? "UInt64" : "Int64"
            if size = 4
                return kind = "u" ? "UInt" : "Int"
            if size = 2
                return kind = "u" ? "UShort" : "Short"
            if size = 1
                return kind = "u" ? "UChar" : "Char"
        }
        return ""
    }

    static _TypeCode(meta) {
        kind := meta["kind"]
        size := meta["item_size"]
        if kind = "f" and size = 8
            return 0
        if kind = "i" and size = 8
            return 1
        if kind = "f" and size = 4
            return 2
        if kind = "i" and size = 4
            return 3
        if kind = "u" and size = 8
            return 4
        if kind = "u" and size = 4
            return 5
        if kind = "i" and size = 2
            return 6
        if kind = "u" and size = 2
            return 7
        if kind = "i" and size = 1
            return 8
        if kind = "u" and size = 1
            return 9
        if kind = "b" and size = 1
            return 9
        return -1
    }

    static _Reshape(flat, shape, &pos) {
        if shape.Length = 1 {
            start := pos + 1
            pos += shape[1]
            result := []
            loop shape[1]
                result.Push(flat[start + A_Index - 1])
            return result
        }
        if shape.Length = 0 {
            pos += 1
            return flat[pos]
        }
        result := []
        dim := shape[1]
        rest := shape.Clone()
        rest.RemoveAt(1)
        loop dim
            result.Push(CnpBridge._Reshape(flat, rest, &pos))
        return result
    }

    static _ShapeOf(data) {
        if !(data is Array)
            return []
        shape := [data.Length]
        if data.Length > 0 and (data[1] is Array) {
            child := CnpBridge._ShapeOf(data[1])
            if child.Length = 0
                return shape
            shape.Push(child*)
        }
        return shape
    }

    static _Flatten(data) {
        if !(data is Array)
            return [data]
        result := []
        for value in data {
            if value is Array
                result.Push(CnpBridge._Flatten(value)*)
            else
                result.Push(value)
        }
        return result
    }

    static _DeepEq(a, b) {
        if a is Array or b is Array {
            if !(a is Array) or !(b is Array)
                return false
            if a.Length != b.Length
                return false
            for i, value in a
                if !CnpBridge._DeepEq(value, b[i])
                    return false
            return true
        }
        if a is Number and b is Number
            return Abs(a - b) <= 1e-9
        return a = b
    }
}


; Zero-copy view over a cnumpy array.
;
; Ownership contract:
;   - The view BORROWS cnumpy memory.  It never calls cnp_ahk_free.
;   - The view holds a strong AHK reference to the owning Numpy.NdArray.
;     That wrapper owns the CnpArray and frees it in its __Delete when the
;     last wrapper reference goes away.
;   - Therefore: keep the view (or another NdArray reference) alive for as
;     long as the underlying memory is needed.  Dropping both the original
;     NdArray and the view frees the array normally.
;   - Writes through the view are allowed only when the array is writeable.
class CnpView {
    __New(ndarray) {
        if !(ndarray is Numpy.NdArray)
            throw TypeError("expected Numpy.NdArray, got " Type(ndarray))
        this.Owner := ndarray
        this.Meta := CnpBridge.Metadata(ndarray)
        this.Ptr := this.Meta["data"]
        this.Size := this.Meta["size"] * this.Meta["item_size"]
    }

    Ndim {
        get => this.Meta["ndim"]
    }
    Shape {
        get => this.Meta["shape"].Clone()
    }
    Strides {
        get => this.Meta["strides"].Clone()
    }
    ItemSize {
        get => this.Meta["item_size"]
    }
    Dtype {
        get => this.Meta["dtype"]
    }
    CContiguous {
        get => this.Meta["c_contiguous"]
    }
    Writeable {
        get => this.Meta["writeable"]
    }

    ToBuffer() {
        buf := Buffer(this.Size)
        DllCall("msvcrt\memcpy", "Ptr", buf.Ptr, "Ptr", this.Ptr,
            "UPtr", this.Size)
        return buf
    }

    ToAhk() {
        flat := []
        typeName := CnpBridge._TypeFor(this.Meta)
        if typeName = ""
            throw Error("CnpView.ToAhk supports numeric dtypes only")
        loop this.Meta["size"] {
            flat.Push(NumGet(
                this.Ptr + (A_Index - 1) * this.Meta["item_size"], typeName))
        }
        pos := 0
        return CnpBridge._Reshape(flat, this.Meta["shape"], &pos)
    }

    Get(flatIndex) {
        if flatIndex < 0 or flatIndex >= this.Meta["size"]
            throw Error("flat index out of range")
        typeName := CnpBridge._TypeFor(this.Meta)
        return NumGet(
            this.Ptr + flatIndex * this.Meta["item_size"], typeName)
    }

    Set(flatIndex, value) {
        if !this.Meta["writeable"]
            throw Error("array is not writeable")
        if flatIndex < 0 or flatIndex >= this.Meta["size"]
            throw Error("flat index out of range")
        typeName := CnpBridge._TypeFor(this.Meta)
        NumPut(typeName, value,
            this.Ptr + flatIndex * this.Meta["item_size"])
    }

    __Delete() {
        ; Drop the strong reference.  cnumpy memory is freed by the wrapper
        ; only when no NdArray/view references remain.
        this.Owner := 0
        this.Meta := 0
        this.Ptr := 0
    }
}
