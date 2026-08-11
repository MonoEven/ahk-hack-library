#SingleInstance Force
#NoTrayIcon

#Include ahk_hack_single.ahk

out := ""
outFile := A_ScriptDir "\ahk_hack_demo.out"
try {
    AhkMagic.Init()
    out .= AhkMagic.Summary() "`n"
    out .= "Abs rva=0x" Format("{:X}", AhkMagic.BifRva("Abs")) "`n"

    old := AhkMagic.PatchBif("Abs", "Sin")
    name := "Abs"
    out .= "patched Abs(1)=" %name%(1) "`n"
    AhkMagic.RestoreBif("Abs", old)
    out .= "restored Abs(1)=" %name%(1) "`n"

    out .= "eval 1+2*3=" AhkMagic.Eval("1 + 2 * 3") "`n"
    out .= "OK`n"
} catch as e {
    out .= "FAIL: " e.What " | " e.Message " | line " e.Line "`n"
}
FileAppend out, outFile
ExitApp 0
