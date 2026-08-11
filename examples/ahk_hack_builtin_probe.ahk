#SingleInstance Force
#NoTrayIcon

#Include ..\ahk_hack_single.ahk

out := ""
outFile := A_ScriptDir "\builtin_probe.out"
try {
    AhkMagic.Init()
    for rawName in (A_Args.Length ? A_Args : ["Abs", "Sin", "StrLen"]) {
        name := StrReplace(rawName, "_", " ")
        if !AhkMagic.bif.Has(name) {
            out .= name " not found`n"
            continue
        }
        e := AhkMagic.bif[name]
        out .= name "`n"
        out .= "  rva=0x" Format("{:X}", e["rva"]) "`n"
        out .= "  addr=0x" Format("{:X}", AhkMagic.moduleBase + e["rva"]) "`n"
        out .= "  min=" e["min"] " max=" e["max"] " fid=" e["fid"] "`n"
    }
    out .= "OK`n"
} catch as e {
    out .= "FAIL: " e.What " | " e.Message " | line " e.Line "`n"
}
FileAppend out, outFile
ExitApp 0
