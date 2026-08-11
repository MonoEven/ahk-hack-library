#SingleInstance Force
#NoTrayIcon
#Include ..\ahk_hack_single.ahk

outFile := A_ScriptDir "\evalscript_repeat_" A_AhkVersion ".out"
if FileExist(outFile)
    FileDelete outFile

fnText := "
(
add(a, b) {
    return a + b
}
add(1, 2)
)"

classText := "
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
    r1 := AhkMagic.EvalScript(fnText)
    FileAppend "r1=" r1 "`n", outFile
    r2 := AhkMagic.EvalScript(classText)
    FileAppend "r2=" r2 "`n", outFile
    r3 := AhkMagic.EvalScript("
(
mul(a, b) {
    return a * b
}
mul(2, 3)
)")
    FileAppend "r3=" r3 "`n", outFile
    if r1 != 3 or r2 != 3 or r3 != 6
        throw Error("unexpected results: " r1 " " r2 " " r3)
    FileAppend "OK`n", outFile
    ExitApp 0
} catch as e {
    FileAppend "FAIL " e.What " | " e.Message " | line " e.Line
        . " extra=" e.Extra "`n", outFile
    ExitApp 1
}
