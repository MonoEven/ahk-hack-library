#SingleInstance Force
#NoTrayIcon

#Include ..\lib\ahk_hack.ahk

out := ""
outFile := A_ScriptDir "\export_scan_test.out"
try {
    dll := "D:\Tech\Projects\Autohotkey\Lib\visual_studio\tasks\2026-07-19-cnumpy-foundation\build\x64\Release\cnumpy_ahk.dll"
    hmod := DllCall("LoadLibraryW", "Str", dll, "Ptr")
    if !hmod
        throw Error("LoadLibrary failed: " dll)
    exports := AhkMagic.ScanExports(hmod)
    out .= "count=" exports.Count "`n"
    for name in ["cnp_ahk_from_doubles", "cnp_ahk_create", "cnp_frombuffer", "cnp_add"] {
        if exports.Has(name)
            out .= name " rva=0x" Format("{:X}", exports[name]["rva"])
                . " ord=" exports[name]["ordinal"] "`n"
        else
            out .= name " MISSING`n"
    }
    sample := []
    for name, info in exports {
        sample.Push(name)
        if sample.Length >= 5
            break
    }
    out .= "samples=" Join(",", sample) "`n"
    out .= "OK`n"
} catch as e {
    out .= "FAIL: " e.What " | " e.Message " | line " e.Line "`n"
}
FileAppend out, outFile
ExitApp 0

Join(sep, values) {
    result := ""
    for i, value in values
        result .= (i > 1 ? sep : "") value
    return result
}
