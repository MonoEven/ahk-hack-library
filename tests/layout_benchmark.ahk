#SingleInstance Force
#NoTrayIcon

#Include ..\lib\cnumpy\cnumpy_adaptive.ahk
#Include ..\lib\cnumpy\cnumpy_bridge.ahk

; CnpBridge.ToAhkNative (the mcode path) is intentionally NOT called here.
; The comparison covers the old wrapper loop, the raw-bytes loop, the
; adaptive AHK fill, the adaptive native-DLL fill, and the zero-copy paths.

out := ""
outFile := A_ScriptDir "\layout_benchmark.out"
nativeDll := A_ScriptDir "\..\build\native_fill\native_fill.dll"

Progress(line) {
    global outFile
    FileAppend line "`n", outFile
}

class Timer {
    static freq := 0
    static Now() {
        if !Timer.freq {
            local f := 0
            DllCall("QueryPerformanceFrequency", "Int64*", &f)
            Timer.freq := f
        }
        local t := 0
        DllCall("QueryPerformanceCounter", "Int64*", &t)
        return t
    }
    static Ms(a, b) => (b - a) * 1000.0 / Timer.freq
}

Measure(callback, repeats := 3) {
    best := 0.0
    loop repeats {
        t0 := Timer.Now()
        callback()
        t1 := Timer.Now()
        ms := Timer.Ms(t0, t1)
        if A_Index = 1 or ms < best
            best := ms
    }
    return best
}

try {
    Progress("init")
    Numpy.DllPath := "D:\Tech\Projects\Autohotkey\Lib\visual_studio\tasks\2026-07-19-cnumpy-foundation\build\x64\Release\cnumpy_ahk.dll"
    Numpy.Init()
    count := 1000000
    arr := Numpy.Arange(0, count, 1, Numpy.DT_FLOAT64)
    Progress("array created")

    ; Warmup all paths once.
    CnpBridge.ToAhk(arr)
    CnpBridge.ToAhkFast(arr)
    CnpAdaptiveBridge.ToAhk(arr)
    CnpAdaptiveBridge.ToAhkNativeDll(arr, nativeDll)
    Progress("warmup done")
    out .= "version=" A_AhkVersion "`n"
    out .= "dll=" nativeDll " exists=" FileExist(nativeDll) "`n"

    Progress("measuring oldTo")
    oldTo := Measure((*) => CnpBridge.ToAhk(arr))
    Progress("measuring fastTo")
    fastTo := Measure((*) => CnpBridge.ToAhkFast(arr))
    Progress("measuring adaptiveTo")
    adaptiveTo := Measure((*) => CnpAdaptiveBridge.ToAhk(arr))
    Progress("measuring nativeDllTo")
    nativeDllTo := Measure((*) => CnpAdaptiveBridge.ToAhkNativeDll(arr, nativeDll))
    Progress("measuring bufCopy")
    bufCopy := Measure((*) => CnpBridge.ToBuffer(arr))
    Progress("measuring viewCreate")
    viewCreate := Measure((*) => CnpBridge.View(arr))
    Progress("measures done")

    ; Correctness for the 1-D paths.
    a := CnpAdaptiveBridge.ToAhk(arr)
    n := CnpAdaptiveBridge.ToAhkNativeDll(arr, nativeDll)
    if a.Length != count or n.Length != count
        throw Error("1-D length mismatch")
    if a[1] != 0 or a[count] != count - 1
        throw Error("1-D adaptive spot check failed")
    if n[1] != 0 or n[count] != count - 1
        throw Error("1-D native spot check failed")
    a := 0
    n := 0
    Progress("1d checks done")

    a2d := arr.Reshape([1000, 1000])
    Progress("2d reshape done")
    old2d := Measure((*) => CnpBridge.ToAhk(a2d))
    Progress("2d old done")
    fast2d := Measure((*) => CnpBridge.ToAhkFast(a2d))
    Progress("2d fast done")
    adaptive2d := Measure((*) => CnpAdaptiveBridge.ToAhk(a2d))
    Progress("2d adaptive done")
    native2d := Measure((*) => CnpAdaptiveBridge.ToAhkNativeDll(a2d, nativeDll))
    Progress("2d native done")

    a2 := CnpAdaptiveBridge.ToAhk(a2d)
    n2 := CnpAdaptiveBridge.ToAhkNativeDll(a2d, nativeDll)
    if a2.Length != 1000 or a2[1000].Length != 1000
        throw Error("2-D adaptive shape mismatch")
    if a2[1000][1000] != a2d.GetItem(1000 * 1000 - 1)
        throw Error("2-D adaptive value mismatch")
    if n2[1000][1000] != a2d.GetItem(1000 * 1000 - 1)
        throw Error("2-D native value mismatch")
    if n2[1][2] != 1
        throw Error("2-D native early-row mismatch")
    a2 := 0
    n2 := 0
    Progress("2d checks done")

    out .= Format("count={}`n", count)
    out .= Format("ToAhk old ms={:.3f}`n", oldTo)
    out .= Format("ToAhkFast ms={:.3f}`n", fastTo)
    out .= Format("ToAhkAdaptive(AHK loop) ms={:.3f}`n", adaptiveTo)
    out .= Format("ToAhkAdaptive(native DLL) ms={:.3f}`n", nativeDllTo)
    out .= Format("ToBuffer ms={:.3f}`n", bufCopy)
    out .= Format("View create ms={:.4f}`n", viewCreate)
    out .= Format("adaptive-vs-old speedup={:.2f}x`n", oldTo / adaptiveTo)
    out .= Format("native-vs-old speedup={:.2f}x`n", oldTo / nativeDllTo)
    out .= Format("2D old ms={:.3f}`n", old2d)
    out .= Format("2D fast ms={:.3f}`n", fast2d)
    out .= Format("2D adaptive(AHK loop) ms={:.3f}`n", adaptive2d)
    out .= Format("2D adaptive(native DLL) ms={:.3f}`n", native2d)
    out .= Format("2D native speedup={:.2f}x`n", old2d / native2d)
    out .= "OK`n"
} catch as e {
    out .= "FAIL: " e.What " | " e.Message
        . " | file " e.File " | line " e.Line " | " e.Extra "`n"
    FileAppend out, outFile
    ExitApp 1
}
FileAppend out, outFile
ExitApp 0
