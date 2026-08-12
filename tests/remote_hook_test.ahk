#SingleInstance Force
#NoTrayIcon
#Include ..\ahk_hack_single.ahk

pid := Integer(A_Args[1])
outFile := A_ScriptDir "\remote_hook_test.out"
try FileDelete(outFile)

Log(msg) {
    global outFile
    FileAppend(msg "`n", outFile)
}

try {
    hook := AhkMagic.AttachRemote(pid)
    Log("internal=" (hook.Has("internal") and hook["internal"].Has("error")
        ? hook["internal"]["error"] : "ok"))
    Log("bif=" hook["builtins"]["count"]
        . " native=" hook["native_functions"]["count"]
        . " biv=" hook["builtin_vars"]["count"])
    Log("Abs rva=0x" Format("{:X}", hook["builtins"]["entries"]["Abs"]["rva"]))
    r := AhkMagic.RemoteRedirect(hook, "Abs", "Sin")
    Log("redirected at 0x" Format("{:X}", r["fn_slot"]))
    hook2 := AhkMagic.AttachRemote(pid)
    Log("after Abs rva=0x" Format("{:X}", hook2["builtins"]["entries"]["Abs"]["rva"]))
    Log("eval=" AhkMagic.RemoteEval(hook, "1 + 2 * 3"))
    Log("evalfloat=" AhkMagic.RemoteEval(hook, "2 * 3.5"))
    script := "
    (
    add(a, b) {
        return a + b
    }
    add(1, 2)
    )"
    Log("evalScript=" AhkMagic.RemoteEvalScript(hook, script))
    mulScript := "
    (
    mul(a, b) {
        return a * b
    }
    mul(2, 3)
    )"
    Log("evalScriptSecond=" AhkMagic.RemoteEvalScript(hook, mulScript))
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
    Log("evalScriptClass=" AhkMagic.RemoteEvalScript(hook, classScript))
    Log("classNative=" AhkMagic.RemoteEval(hook, "Point(1, 2).x"))
    Log("PASS")
    ExitApp 0
} catch as e {
    Log("FAIL " e.What " | " e.Message " | line " e.Line " extra=" e.Extra)
    ExitApp 1
}
