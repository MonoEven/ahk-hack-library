#SingleInstance Force
#NoTrayIcon

#Include ..\..\..\lib\cnumpy\init.ahk

out := ""
outFile := A_ScriptDir "\cnumpy_bridge_benchmark.out"

Progress(line) {
    global outFile
    FileAppend line "`n", outFile
}

class Bench {
    static Now() => DllCall("GetTickCount64", "UInt64")
    static Ms(a, b) => b - a
}

Measure(callback, repeats := 5) {
    best := 0.0
    loop repeats {
        t0 := Bench.Now()
        callback()
        t1 := Bench.Now()
        ms := Bench.Ms(t0, t1)
        if A_Index = 1 or ms < best
            best := ms
    }
    return best
}

try {
    Numpy.DllPath := "D:\Tech\Projects\Autohotkey\Lib\visual_studio\tasks\2026-07-19-cnumpy-foundation\build\x64\Release\cnumpy_ahk.dll"
    Numpy.Init()
    Progress("loaded dll")
    count := 1000000
    arr := Numpy.Arange(0, count, 1, Numpy.DT_FLOAT64)
    dtype := arr.Dtype
    Progress("array created size=" arr.Size)

    CnpBridge.ToAhk(arr)
    CnpBridge.ToAhkFast(arr)
    CnpBridge.ToAhkNative(arr)
    Progress("warmup done")

    oldTo := Measure((*) => CnpBridge.ToAhk(arr))
    Progress("oldTo done")
    fastTo := Measure((*) => CnpBridge.ToAhkFast(arr))
    Progress("fastTo done")
    nativeTo := Measure((*) => CnpBridge.ToAhkNative(arr))
    Progress("nativeTo done")
    viewCreate := Measure((*) => CnpBridge.View(arr))
    Progress("view done")
    bufCopy := Measure((*) => CnpBridge.ToBuffer(arr))
    Progress("buf done")
    ahk := CnpBridge.ToAhkFast(arr)
    oldFrom := Measure((*) => CnpBridge.FromAhk(ahk, dtype))
    Progress("oldFrom done")
    fastFrom := Measure((*) => CnpBridge.FromAhkFast(ahk, dtype))
    Progress("fastFrom done")

    out .= Format("size={}`n", count)
    out .= Format("ToAhk old ms={:.3f}`n", oldTo)
    out .= Format("ToAhkFast ms={:.3f}`n", fastTo)
    out .= Format("ToAhkNative ms={:.3f}`n", nativeTo)
    out .= Format("View create ms={:.4f}`n", viewCreate)
    out .= Format("ToBuffer ms={:.3f}`n", bufCopy)
    out .= Format("FromAhk old ms={:.3f}`n", oldFrom)
    out .= Format("FromAhkFast ms={:.3f}`n", fastFrom)
    out .= Format("to speedup={:.2f}x`n", oldTo / fastTo)
    nativeSpeedup := nativeTo > 0 ? oldTo / nativeTo : 99999
    out .= Format("to native speedup={:.2f}x`n", nativeSpeedup)
    out .= Format("from speedup={:.2f}x`n", oldFrom / fastFrom)
    out .= "OK`n"
    FileAppend out, outFile
} catch as e {
    out .= "FAIL: " e.What " | " e.Message " | line " e.Line "`n"
    FileAppend out, outFile
    ExitApp 1
}
ExitApp 0
