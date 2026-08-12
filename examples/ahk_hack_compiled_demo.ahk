#SingleInstance Force
#Include ..\ahk_hack_single.ahk

AhkMagic.Init()

funcScript := "
(
add(a, b) {
    return a + b
}
add(1, 2)
)"
classScript := "
(
class Point {
    x := 0
    y := 0
    __New(x, y) {
        this.x := x
        this.y := y
    }
}
Point(1, 2).y
)"
AhkMagic.EvalScript(classScript)

text := "1 + 2 * 3 = " AhkMagic.EvalNative("1 + 2 * 3") "`n"
    . "add(1, 2) = " AhkMagic.EvalScript(funcScript) "`n"
    . "Point(1, 2).y = " AhkMagic.EvalNative("Point(1, 2).y")
MsgBox text, "AhkMagic compiled demo"
ExitApp 0
