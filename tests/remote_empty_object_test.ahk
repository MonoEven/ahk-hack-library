#SingleInstance Force
#NoTrayIcon
#Include ..\ahk_hack_single.ahk

pid := Integer(A_Args[1])
out := ""
outFile := A_ScriptDir "\remote_empty_object_test.out"
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
    hook := AhkMagic.AttachRemote(pid)

    ; --- object return values (remote: raw pointer in the target) ---
    ptr := AhkMagic.RemoteEval(hook, "Add")
    if !(ptr is Integer) or ptr < 0x10000
        throw Error("RemoteEval did not return an object pointer: " ptr)
    Log("remote_obj_ptr=0x" Format("{:X}", ptr))

    ; --- syntax errors must throw cleanly and leave the target healthy ---
    caught := false
    try {
        AhkMagic.RemoteEvalScript(hook, "broken(a, b) {`n    return a +`n}")
    } catch as e {
        caught := true
        Log("remote_syntax_error_threw=" SubStr(e.Message, 1, 60))
        if InStr(e.Message, "rc=")
            throw Error("remote syntax error leaked opaque loader rc: " e.Message)
        if !InStr(e.Message, "validation failed")
            throw Error("remote syntax error did not come from /validate: " e.Message)
    }
    if !caught
        throw Error("invalid remote script did not throw")
    if AhkMagic.RemoteEval(hook, "1 + 2 * 3") != 7
        throw Error("target unhealthy after invalid remote script")
    Log("target_alive_after_syntax_error=ok")
    Log("OK")
} catch as e {
    Log("FAIL: " e.What " | " e.Message " | line " e.Line " | " e.Extra)
    FileAppend out, outFile
    ExitApp 1
}
FileAppend out, outFile
ExitApp 0
