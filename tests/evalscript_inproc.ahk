#SingleInstance Force
#NoTrayIcon
#Include ..\ahk_hack_single.ahk

outFile := A_ScriptDir "\evalscript_inproc.out"
if FileExist(outFile)
    FileDelete outFile

text := "add(a, b)`n{`n    return a + b`n}`nadd(1, 2)`n"
try {
    r1 := AhkMagic.Eval(text)
    FileAppend "r1=" r1 "`n", outFile
    ExitApp 0
} catch as e {
    FileAppend "FAIL " e.What " | " e.Message " | line " e.Line
        . " extra=" e.Extra "`n", outFile
    ExitApp 1
}
