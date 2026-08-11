#SingleInstance Force
#Include ahk_hack_single.ahk

test := "add(a, b)`n{`n    return a + b`n}`nadd(1, 2)`n"

MsgBox AhkMagic.EvalScript(test)              ; 3, in-process
MsgBox AhkMagic.EvalNative("1 + 2 * 3")       ; 7, in-process
MsgBox AhkMagic.Eval("StrLen(`"hello`")")     ; 5
MsgBox AhkMagic.EvalSubprocess("Format(`"{:.2f}`", Sin(1))") ; explicit subprocess
