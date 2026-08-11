#SingleInstance Force
#Include ahk_hack_single.ahk

test := "
(
add(a, b) {
    return a + b
}
add(1, 2)
)"

classTest := "
(
class Point {
    x := 0
    y := 0
    __New(x, y) {
        this.x := x
        this.y := y
    }
}
Point(1, 2).x
)"

MsgBox AhkMagic.EvalScript(test)              ; 3, in-process
MsgBox AhkMagic.EvalScript(classTest)         ; 1, class instance in-process
MsgBox AhkMagic.EvalNative("1 + 2 * 3")       ; 7, in-process
MsgBox AhkMagic.Eval("StrLen(`"hello`")")     ; 5
MsgBox AhkMagic.EvalSubprocess("Format(`"{:.2f}`", Sin(1))") ; explicit subprocess
