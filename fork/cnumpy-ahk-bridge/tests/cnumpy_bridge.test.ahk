#SingleInstance Force
#NoTrayIcon

#Include ..\..\..\lib\cnumpy\numpy.ahk
#Include ..\..\..\lib\cnumpy\cnumpy_bridge.ahk

out := ""
outFile := A_ScriptDir "\cnumpy_bridge_test.out"

AssertClose(actual, expected, label) {
    if Abs(actual - expected) > 1e-9
        throw Error(label ": expected " expected ", got " actual)
}

AssertDeep(actual, expected, label) {
    if !CnpBridge._DeepEq(actual, expected)
        throw Error(label ": nested arrays differ")
}

try {
    Numpy.DllPath := "D:\Tech\Projects\Autohotkey\Lib\visual_studio\tasks\2026-07-19-cnumpy-foundation\build\x64\Release\cnumpy_ahk.dll"
    Numpy.Init()
    out .= "version=" Numpy.Version() "`n"

    a1 := Numpy.Array([1.5, -2.0, 3.25])
    m1 := CnpBridge.Metadata(a1)
    out .= "1d ndim=" m1["ndim"] " size=" m1["size"]
        . " itemsize=" m1["item_size"] "`n"
    if m1["shape"][1] != 3
        throw Error("1d shape")
    ahk1 := CnpBridge.ToAhk(a1)
    AssertDeep(ahk1, [1.5, -2.0, 3.25], "1d to ahk")
    out .= "1d ok`n"

    a2 := Numpy.Array([1, 2, 3, 4], [2, 2])
    ahk2 := CnpBridge.ToAhk(a2)
    AssertDeep(ahk2, [[1, 2], [3, 4]], "2d to ahk")
    shape2 := CnpBridge._ShapeOf(ahk2)
    if shape2.Length != 2 or shape2[1] != 2 or shape2[2] != 2
        throw Error("2d shape")
    out .= "2d ok`n"

    a3 := Numpy.Array([1, 2, 3, 4, 5, 6, 7, 8], [2, 2, 2])
    ahk3 := CnpBridge.ToAhk(a3)
    AssertDeep(ahk3, [[[1, 2], [3, 4]], [[5, 6], [7, 8]]], "3d to ahk")
    out .= "3d ok`n"

    back := CnpBridge.FromAhk(ahk2, a2.Dtype)
    if back.Size != 4
        throw Error("roundtrip size")
    AssertClose(back.GetItem(0), 1, "roundtrip 0")
    AssertClose(back.GetItem(3), 4, "roundtrip 3")
    out .= "roundtrip ok`n"

    buf := CnpBridge.ToBuffer(a1)
    if buf.Size != a1.Nbytes
        throw Error("buffer size " buf.Size " != " a1.Nbytes)
    b1 := CnpBridge.FromBuffer(buf, a1.Dtype)
    AssertClose(b1.GetItem(0), 1.5, "buffer item 0")
    AssertClose(b1.GetItem(2), 3.25, "buffer item 2")
    out .= "buffer ok`n"

    view := CnpBridge.View(a1)
    if view.Size != a1.Nbytes
        throw Error("view size")
    AssertClose(view.Get(0), 1.5, "view get 0")
    view.Set(0, 9.25)
    AssertClose(a1.GetItem(0), 9.25, "view write did not propagate")
    view.Set(0, 1.5)
    AssertClose(a1.GetItem(0), 1.5, "view restore")
    out .= "view ok`n"

    fast1 := CnpBridge.ToAhkFast(a1)
    AssertDeep(fast1, ahk1, "fast 1d")
    a2fast := CnpBridge.FromAhkFast([[1, 2], [3, 4]], a2.Dtype)
    if a2fast.Size != 4
        throw Error("fast roundtrip size")
    AssertClose(a2fast.GetItem(0), 1, "fast item 0")
    AssertClose(a2fast.GetItem(3), 4, "fast item 3")
    out .= "fast path ok`n"

    native1 := CnpBridge.ToAhkNative(a1)
    AssertDeep(native1, ahk1, "native 1d")
    if native1.Length != 3
        throw Error("native length")
    native2 := CnpBridge.ToAhkNative(a2)
    AssertDeep(native2, ahk2, "native 2d")
    native3 := CnpBridge.ToAhkNative(a3)
    AssertDeep(native3, ahk3, "native 3d")
    out .= "native ok`n"

    kept := MakeView(a2)
    if kept.Size != a2.Nbytes
        throw Error("kept view size")
    AssertClose(kept.Get(3), 4, "kept view get")
    out .= "ownership ok`n"

    sum := Numpy.Add(a1, a1)
    AssertClose(sum.GetItem(0), 3.0, "cnumpy add 0")
    AssertClose(sum.GetItem(2), 6.5, "cnumpy add 2")
    out .= "cnumpy untouched ok`n"

    out .= "OK`n"
} catch as e {
    out .= "FAIL: " e.What " | " e.Message " | line " e.Line "`n"
}
FileAppend out, outFile
ExitApp 0

MakeView(ndarray) {
    ; The local ndarray goes out of scope, but the returned view holds a
    ; strong reference to it, so the underlying cnumpy array stays alive.
    return CnpBridge.View(ndarray)
}
