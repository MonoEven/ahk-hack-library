#SingleInstance Force
#NoTrayIcon
#Include ..\ahk_hack_single.ahk

out := ""
outFile := A_ScriptDir "\eval_object_syntax_test.out"
if FileExist(outFile) {
    try {
        FileDelete(outFile)
    } catch {
    }
}
Log(s) {
    global out
    out .= s "`n"
}

try {
    AhkMagic.Init()

    ; --- object return values (in-process) ---
    f := AhkMagic.EvalNative("Abs")
    if !(f is Func) or f.Name != "Abs"
        throw Error("EvalNative did not return the Abs Func object")
    Log("evalnative_func_obj=ok")

    cls := AhkMagic.EvalScript("
    (
    class EvalPoint {
        x := 0
        __New(x) {
            this.x := x
        }
    }
    EvalPoint
    )")
    if !(cls is Class)
        throw Error("EvalScript did not return the class object: " Type(cls))
    ; Instantiate through the returned class variable so the test never
    ; references a dynamically-defined class name at load time.
    p := cls(5)
    if p.x != 5
        throw Error("class returned by eval is not usable")
    Log("evalscript_class_obj=ok")

    ; --- syntax errors must throw cleanly and leave the host alive ---
    caught := false
    try {
        AhkMagic.EvalScript("broken(a, b) {`n    return a +`n}`nbroken(1, 2)")
    } catch as e {
        caught := true
        Log("syntax_error_threw=" SubStr(e.Message, 1, 60))
        ; The error must carry the interpreter's real validation message,
        ; never the opaque loader rc leak.
        if InStr(e.Message, "rc=")
            throw Error("syntax error leaked opaque loader rc: " e.Message)
        if !InStr(e.Message, "validation failed")
            throw Error("syntax error did not come from /validate: " e.Message)
    }
    if !caught
        throw Error("invalid script did not throw")
    r := AhkMagic.EvalNative("1 + 1")
    if r != 2
        throw Error("host interpreter corrupted after invalid script: " r)
    Log("host_alive_after_syntax_error=ok")

    ; --- a valid eval still works after all of the above ---
    if AhkMagic.EvalScript("
    (
    okFn(a, b) {
        return a + b
    }
    okFn(2, 3)
    )") != 5
        throw Error("valid EvalScript after error path failed")
    Log("OK")
} catch as e {
    Log("FAIL: " e.What " | " e.Message " | line " e.Line " | " e.Extra)
    FileAppend out, outFile
    ExitApp 1
}
FileAppend out, outFile
ExitApp 0
