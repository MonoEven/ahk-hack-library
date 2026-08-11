#SingleInstance Force
#NoTrayIcon
#Include ahk_hack_single.ahk

MsgBox AhkMagic.Eval("1 + 2 * 3")          ; 7
MsgBox AhkMagic.Eval("StrLen(`"hello`")")   ; 5
MsgBox AhkMagic.EvalSubprocess("Format(`"{:.2f}`", Sin(1))") ; explicit subprocess
MsgBox AhkMagic.EvalNative("1 + 2 * 3")     ; 7, in-process
MsgBox AhkMagic.EvalNative("2 * 3.5")       ; 7.0, in-process
MsgBox AhkMagic.EvalNative("Abs(-5)")       ; 5, in-process

script := "
(
add(a, b) {
    return a + b
}
add(1, 2)
)"
MsgBox AhkMagic.EvalScript(script)          ; 3, in-process

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
Point(1, 2).x
)"
MsgBox AhkMagic.EvalScript(classScript)     ; 1, class loaded and used in-process
MsgBox AhkMagic.EvalNative("Point(1, 2).y") ; 2, class loaded and used in-process
