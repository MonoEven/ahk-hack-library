#SingleInstance Force
#NoTrayIcon
#Include ..\ahk_hack_single.ahk

outFile := A_ScriptDir "\evalscript_class_" A_AhkVersion ".out"
if FileExist(outFile)
    FileDelete outFile

text := "
(
class Point {
    x := 0
    y := 0
    __New(x, y) {
        this.x := x
        this.y := y
    }
}
Point(1, 2).x + Point(1, 2).y
)"

try {
    r := AhkMagic.EvalScript(text)
    FileAppend "r=" r "`n", outFile
    ExitApp 0
} catch as e {
    FileAppend "FAIL " e.What " | " e.Message " | line " e.Line
        . " extra=" e.Extra "`n", outFile
    ExitApp 1
}
