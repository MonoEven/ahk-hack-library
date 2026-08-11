#SingleInstance Force
#NoTrayIcon

#Include ..\ahk_hack_single.ahk

dll := A_Args.Length ? A_Args[1] : "kernel32.dll"
filter := A_Args.Length > 1 ? A_Args[2] : ""
outFile := A_ScriptDir "\export_inventory.csv"

out := ""
try {
    hmod := DllCall("LoadLibraryW", "Str", dll, "Ptr")
    if !hmod
        throw Error("LoadLibrary failed: " dll)
    exports := AhkMagic.ScanExports(hmod)
    out .= "name,rva,ordinal`n"
    for name, info in exports {
        if filter != "" and !InStr(name, filter)
            continue
        out .= name "," info["rva"] "," info["ordinal"] "`n"
    }
} catch as e {
    out .= "FAIL: " e.What " | " e.Message " | line " e.Line "`n"
}
FileAppend out, outFile
ExitApp 0
