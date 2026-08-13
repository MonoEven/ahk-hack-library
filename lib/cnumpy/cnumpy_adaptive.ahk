; cnumpy_adaptive.ahk - cnumpy -> native AHK Array conversion driven by
; runtime-discovered AHK layout (lib/ahk_layout.ahk).
;
; No mcode and no hardcoded AutoHotkey Array offsets.  Leaf arrays are
; filled through AhkLayout.FillLeaf; parent arrays are assembled with the
; public Push API, so the child AddRef path never needs internal layout.

#Include ..\ahk_layout.ahk
#Include numpy.ahk

class CnpAdaptiveBridge {
    ; CnpArray ABI offsets from include/cnumpy/cnumpy.h.  These describe
    ; cnumpy's own exported struct, not the AutoHotkey executable.
    static _OFF_NDIM := 0
    static _OFF_SHAPE := 8
    static _OFF_STRIDES := 16
    static _OFF_SIZE := 24
    static _OFF_DATA := 32
    static _OFF_DTYPE := 40
    static _OFF_FLAGS := 48
    static _OFF_OFFSET := 64
    static _fillFn := Map()

    static Metadata(ndarray) {
        Numpy.Init()
        if !(ndarray is Numpy.NdArray)
            throw TypeError("expected Numpy.NdArray, got " Type(ndarray))
        handle := ndarray.Handle
        if !handle
            throw Error("NdArray handle is null")
        ndim := NumGet(handle, CnpAdaptiveBridge._OFF_NDIM, "Int")
        shapePtr := NumGet(handle, CnpAdaptiveBridge._OFF_SHAPE, "Ptr")
        stridesPtr := NumGet(handle, CnpAdaptiveBridge._OFF_STRIDES, "Ptr")
        size := NumGet(handle, CnpAdaptiveBridge._OFF_SIZE, "Int64")
        dataPtr := NumGet(handle, CnpAdaptiveBridge._OFF_DATA, "Ptr")
        dtypePtr := NumGet(handle, CnpAdaptiveBridge._OFF_DTYPE, "Ptr")
        flags := NumGet(handle, CnpAdaptiveBridge._OFF_FLAGS, "UInt")
        offset := NumGet(handle, CnpAdaptiveBridge._OFF_OFFSET, "Int64")
        shape := []
        strides := []
        loop ndim {
            shape.Push(NumGet(shapePtr, (A_Index - 1) * 8, "Int64"))
            strides.Push(NumGet(stridesPtr, (A_Index - 1) * 8, "Int64"))
        }
        itemSize := dtypePtr ? NumGet(dtypePtr, 4, "Int") : 0
        kind := dtypePtr ? Chr(NumGet(dtypePtr, 12, "UChar")) : ""
        return Map(
            "ndim", ndim,
            "shape", shape,
            "size", size,
            "data", dataPtr,
            "offset", offset,
            "item_size", itemSize,
            "kind", kind,
            "c_contiguous", (flags & 0x0001) != 0
        )
    }

    static ToAhk(ndarray) {
        filler := ObjBindMethod(AhkLayout, "FillLeaf")
        return CnpAdaptiveBridge._ToAhk(ndarray, filler)
    }

    ; Same conversion with the leaf fill executed by a normal C export
    ; instead of an AHK loop.  No machine code is involved.
    static ToAhkNativeDll(ndarray, dllPath) {
        filler := ObjBindMethod(CnpAdaptiveBridge, "_NativeFillLeaf", dllPath)
        return CnpAdaptiveBridge._ToAhk(ndarray, filler)
    }

    static _ToAhk(ndarray, filler) {
        meta := CnpAdaptiveBridge.Metadata(ndarray)
        typeCode := CnpAdaptiveBridge._TypeCode(meta)
        if typeCode < 0
            throw Error("ToAhk supports numeric dtypes only")
        if !meta["c_contiguous"]
            throw Error("ToAhk requires a C-contiguous array")
        if meta["ndim"] = 0
            return ndarray.GetItem(0)
        layout := AhkLayout.Discover()
        return CnpAdaptiveBridge._Build(meta, meta["shape"], 0, 0,
            typeCode, layout, filler)
    }

    static _Build(meta, shape, dim, leafOffset, typeCode, layout, filler) {
        count := shape[dim + 1]
        if dim = meta["ndim"] - 1 {
            leaf := Array()
            leaf.Capacity := count
            dataPtr := meta["data"] + meta["offset"]
                + leafOffset * meta["item_size"]
            filler(leaf, dataPtr, count, meta["item_size"], typeCode, layout)
            return leaf
        }
        result := Array()
        result.Capacity := count
        childStride := 1
        loop meta["ndim"] - dim - 1
            childStride *= shape[dim + 1 + A_Index]
        loop count {
            child := CnpAdaptiveBridge._Build(meta, shape, dim + 1,
                leafOffset + (A_Index - 1) * childStride,
                typeCode, layout, filler)
            result.Push(child)
        }
        return result
    }

    static _NativeFillLeaf(dllPath, arr, dataPtr, count, itemSize, typeCode,
            layout) {
        ; Resolve the export once.  AHK's by-name DllCall is far too slow
        ; for per-leaf calls; the cached pointer keeps hot loops native-fast.
        if !CnpAdaptiveBridge._fillFn.Has(dllPath) {
            module := DllCall("LoadLibrary", "Str", dllPath, "Ptr")
            if !module
                throw Error("LoadLibrary failed: " dllPath)
            fn := DllCall("GetProcAddress", "Ptr", module,
                "AStr", "cnp_fill_leaf", "Ptr")
            if !fn
                throw Error("GetProcAddress failed: cnp_fill_leaf")
            CnpAdaptiveBridge._fillFn[dllPath] := fn
        }
        fn := CnpAdaptiveBridge._fillFn[dllPath]
        obj := ObjPtr(arr)
        item := NumGet(obj, layout["mItem"], "Ptr")
        rc := DllCall(
            fn,
            "Ptr", obj,
            "Ptr", item,
            "Ptr", dataPtr,
            "Int64", count,
            "Int", itemSize,
            "Int", typeCode,
            "UInt", layout["mLength"],
            "UInt", layout["mCapacity"],
            "UInt", arr.Capacity,
            "UInt", layout["variantSize"],
            "UInt", layout["valueOffset"],
            "UInt", layout["symbolOffset"],
            "UInt", layout["symInt"],
            "UInt", layout["symFloat"],
            "Int")
        if rc != 0
            throw Error("cnp_fill_leaf failed with rc=" rc)
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
}
