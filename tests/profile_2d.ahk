#SingleInstance Force
#NoTrayIcon

#Include ..\lib\ahk_layout.ahk

out := ""
outFile := A_ScriptDir "\profile_2d.out"
nativeDll := A_ScriptDir "\..\build\native_fill\native_fill.dll"
_layout := 0
_data := 0

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

NativeFill(arr, dataPtr, count, layout) {
    obj := ObjPtr(arr)
    item := NumGet(obj, layout["mItem"], "Ptr")
    return DllCall(
        nativeDll "\cnp_fill_leaf",
        "Ptr", obj, "Ptr", item, "Ptr", dataPtr,
        "Int64", count, "Int", 8, "Int", 0,
        "UInt", layout["mLength"], "UInt", layout["mCapacity"],
        "UInt", layout["variantSize"], "UInt", layout["valueOffset"],
        "UInt", layout["symbolOffset"], "UInt", layout["symInt"],
        "UInt", layout["symFloat"], "Int")
}

AllocOnly() {
    global
    loop 1000 {
        a := Array()
        a.Capacity := 1000
    }
}

FillOnly() {
    global _layout, _data
    loop 1000 {
        a := Array()
        a.Capacity := 1000
        rc := NativeFill(a, _data.Ptr, 1000, _layout)
        if rc != 0
            throw Error("fill rc=" rc)
    }
}

PushOnly() {
    parent := Array()
    loop 1000 {
        a := Array()
        a.Capacity := 1000
        parent.Push(a)
    }
}

FillPush() {
    global _layout, _data
    parent := Array()
    loop 1000 {
        a := Array()
        a.Capacity := 1000
        rc := NativeFill(a, _data.Ptr, 1000, _layout)
        if rc != 0
            throw Error("fill rc=" rc)
        parent.Push(a)
    }
}

try {
    layout := AhkLayout.Discover()
    _layout := layout
    _data := Buffer(1000 * 8, 0)

    msAlloc := Measure(AllocOnly)
    msFill := Measure(FillOnly)
    msPush := Measure(PushOnly)
    msFillPush := Measure(FillPush)

    out .= "alloc1000x1000 ms=" Format("{:.3f}", msAlloc) "`n"
    out .= "fill1000x1000 ms=" Format("{:.3f}", msFill) "`n"
    out .= "push1000 ms=" Format("{:.3f}", msPush) "`n"
    out .= "fill+push1000x1000 ms=" Format("{:.3f}", msFillPush) "`n"
    out .= "OK`n"
} catch as e {
    out .= "FAIL: " e.What " | " e.Message
        . " | file " e.File " | line " e.Line " | " e.Extra "`n"
    FileAppend out, outFile
    ExitApp 1
}
FileAppend out, outFile
ExitApp 0
