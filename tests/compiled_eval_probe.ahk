#SingleInstance Force
#NoTrayIcon
#Include ..\ahk_hack_single.ahk

outFile := A_ScriptDir "\compiled_eval_probe.out"
try FileDelete(outFile)

Log(msg) {
    global outFile
    FileAppend msg "`n", outFile
}

try {
    Log("version=" A_AhkVersion " path=" A_AhkPath)

    AhkMagic.Init()
    Log("init=" AhkMagic.Summary())

    Log("native 1+2*3=" AhkMagic.EvalNative("1 + 2 * 3"))
    Log("eval 1+2*3=" AhkMagic.Eval("1 + 2 * 3"))

    script := "
    (
    add(a, b) {
        return a + b
    }
    add(1, 2)
    )"
    Log("script=" AhkMagic.EvalScript(script))

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
    Log("class=" AhkMagic.EvalScript(classScript))
    Log("classnative=" AhkMagic.EvalNative("Point(1, 2).y"))
    Log("subprocess=" AhkMagic.EvalSubprocess("1 + 1"))
    Log("PASS")
    ExitApp 0
} catch as e {
    Log("FAIL " e.What " | " e.Message " | line " e.Line " extra=" e.Extra)
    ExitApp 1
}
