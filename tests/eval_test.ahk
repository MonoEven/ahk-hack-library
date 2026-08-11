#SingleInstance Force
#NoTrayIcon

#Include ..\lib\ahk_hack.ahk

out := ""
outFile := A_ScriptDir "\eval_test.out"
try {
    AhkMagic.Init()
    out .= "1+2*3=" AhkMagic.Eval("1 + 2 * 3") "`n"
    out .= "Sin(1)=" AhkMagic.Eval("Sin(1)") "`n"
    out .= "A_AhkVersion=" AhkMagic.Eval("A_AhkVersion") "`n"
    out .= "StrLen=" AhkMagic.Eval("StrLen(`"hello`")") "`n"
    out .= "OK`n"
} catch as e {
    out .= "FAIL: " e.What " | " e.Message " | line " e.Line "`n"
}
FileAppend out, outFile
ExitApp 0
