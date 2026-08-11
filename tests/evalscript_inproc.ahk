#SingleInstance Force
#NoTrayIcon
#Include ..\ahk_hack_single.ahk

outFile := A_ScriptDir "\evalscript_inproc_" A_AhkVersion ".out"
if FileExist(outFile)
    FileDelete outFile

before := Map()
Loop Files A_Temp "\ahk_mcode_inproc_*.ahk"
    before[A_LoopFilePath] := true

text := "
(
add(a, b) {
    return a + b
}
add(1, 2)
)"
try {
    r1 := AhkMagic.Eval(text)
    Loop Files A_Temp "\ahk_mcode_inproc_*.ahk"
        if !before.Has(A_LoopFilePath) {
            FileAppend "FAIL temp file created: " A_LoopFilePath "`n", outFile
            ExitApp 1
        }
    FileAppend "r1=" r1 "`n", outFile
    ExitApp 0
} catch as e {
    FileAppend "FAIL " e.What " | " e.Message " | line " e.Line
        . " extra=" e.Extra "`n", outFile
    ExitApp 1
}
