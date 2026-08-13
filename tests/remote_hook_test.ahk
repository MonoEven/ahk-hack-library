#SingleInstance Force
#NoTrayIcon
#Include ..\ahk_hack_single.ahk

pid := Integer(A_Args[1])
outFile := A_ScriptDir "\remote_hook_test.out"
if FileExist(outFile) {
    try {
        FileDelete(outFile)
    } catch {
    }
}

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
    rhkAdd(a, b) {
        return a + b
    }
    rhkAdd(1, 2)
    )"
    Log("evalScript=" AhkMagic.RemoteEvalScript(hook, script))
    mulScript := "
    (
    rhkMul(a, b) {
        return a * b
    }
    rhkMul(2, 3)
    )"
    Log("evalScriptSecond=" AhkMagic.RemoteEvalScript(hook, mulScript))
    classScript := "
    (
    class RemoteHookPoint {
        x := 0
        y := 0
        __New(x, y) {
            this.x := x
            this.y := y
        }
    }
    RemoteHookPoint(1, 2).y
    )"
    Log("evalScriptClass=" AhkMagic.RemoteEvalScript(hook, classScript))
    Log("classNative=" AhkMagic.RemoteEval(hook, "RemoteHookPoint(1, 2).x"))
    Log("PASS")
    ExitApp 0
} catch as e {
    if hook.Has("script_layout") and hook["script_layout"].Has("struct") {
        s := hook["script_layout"]["struct"]
        Log("struct action=" s["line_action"]
            . " argc=" s["line_argc"]
            . " arg=" Format("0x{:X}", s["line_arg"])
            . " attr=" Format("0x{:X}", s["line_attribute"])
            . " next=" Format("0x{:X}", s["line_next"])
            . " aexpr=" s["arg_expression"]
            . " apost=" Format("0x{:X}", s["arg_postfix"])
            . " stride=" s["token_stride"]
            . " sym=" Format("0x{:X}", s["token_symbol"])
            . " use=" Format("0x{:X}", s["token_usage"])
            . " val=" Format("0x{:X}", s["token_value"])
            . " dmark=" Format("0x{:X}", s["deref_marker"])
            . " dvar=" Format("0x{:X}", s["deref_var"])
            . " dtype=" Format("0x{:X}", s["deref_type"])
            . " dlen=" Format("0x{:X}", s["deref_len"]))
    }
    Log("FAIL " e.What " | " e.Message " | line " e.Line " extra=" e.Extra)
    ExitApp 1
}
