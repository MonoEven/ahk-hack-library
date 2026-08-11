#SingleInstance Force
#NoTrayIcon

#Include ..\..\..\lib\cnumpy\init.ahk

out := ""
outFile := A_ScriptDir "\cnumpy_bridge_benchmark_100m.out"

Progress(line) {
    global outFile
    FileAppend line "`n", outFile
}

class Bench {
    static freq := 0
    static Now() {
        if !Bench.freq {
            local f := 0
            DllCall("QueryPerformanceFrequency", "Int64*", &f)
            Bench.freq := f
        }
        local t := 0
        DllCall("QueryPerformanceCounter", "Int64*", &t)
        return t
    }
    static Ms(a, b) => (b - a) * 1000.0 / Bench.freq
}

Measure(callback, repeats := 3) {
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

CapacityOnly(count) {
    result := Array()
    result.Capacity := count
    return result
}

try {
    Numpy.DllPath := "D:\Tech\Projects\Autohotkey\Lib\visual_studio\tasks\2026-07-19-cnumpy-foundation\build\x64\Release\cnumpy_ahk.dll"
    Numpy.Init()
    count := 100000000
    arr := Numpy.Arange(0, count, 1, Numpy.DT_FLOAT64)
    Progress("created " Round(arr.Nbytes / (1024 * 1024)) " MiB array")

    CnpBridge.ToAhkNative(arr)
    CnpBridge.ToBuffer(arr)
    CnpBridge.View(arr)
    Progress("warmup done")

    capOnly := Measure((*) => CapacityOnly(count))
    Progress("capOnly done")
    nativeTo := Measure((*) => CnpBridge.ToAhkNative(arr))
    Progress("nativeTo done")
    bufCopy := Measure((*) => CnpBridge.ToBuffer(arr))
    Progress("bufCopy done")
    viewCreate := Measure((*) => CnpBridge.View(arr))
    Progress("viewCreate done")

    arr1m := Numpy.Arange(0, 1000000, 1, Numpy.DT_FLOAT64)
    a2d := arr1m.Reshape([1000, 1000])
    Progress("2d created " a2d.CContiguous)
    n2d := Measure((*) => CnpBridge.ToAhkNative(a2d))
    Progress("2d native done")
    o2d := Measure((*) => CnpBridge.ToAhk(a2d), 1)
    Progress("2d old done")

    out .= Format("count={}`n", count)
    out .= Format("Capacity only ms={:.3f}`n", capOnly)
    out .= Format("ToAhkNative ms={:.3f}`n", nativeTo)
    out .= Format("ToBuffer ms={:.3f}`n", bufCopy)
    out .= Format("View create ms={:.4f}`n", viewCreate)
    out .= Format("2D 1000x1000 ToAhkNative ms={:.3f}`n", n2d)
    out .= Format("2D 1000x1000 ToAhk old ms={:.3f}`n", o2d)
    out .= "OK`n"
    FileAppend out, outFile
} catch as e {
    out .= "FAIL: " e.What " | " e.Message " | line " e.Line "`n"
    FileAppend out, outFile
    ExitApp 1
}
ExitApp 0
