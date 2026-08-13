#SingleInstance Force
#NoTrayIcon
#Include ..\ahk_hack_single.ahk

pid := Integer(A_Args[1])
out := ""
outFile := A_ScriptDir "\remote_empty_target_test.out"
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
    Log("attached")

    ; The target script defines no user functions, so mFuncs is empty and
    ; layout discovery can only succeed through the probe-injection retry.
    r := AhkMagic.RemoteEvalScript(hook, "
    (
    rhkAddEmpty(a, b) {
        return a + b
    }
    rhkAddEmpty(2, 3)
    )")
    if r != 5
        throw Error("RemoteEvalScript on empty target returned " r)
    Log("empty_target_evalscript=ok")

    ; Second load must also work (layout is now cached).
    r2 := AhkMagic.RemoteEvalScript(hook, "
    (
    rhkMulEmpty(x) {
        return x * 2
    }
    rhkMulEmpty(4)
    )")
    if r2 != 8
        throw Error("second RemoteEvalScript on empty target returned " r2)
    if AhkMagic.RemoteEval(hook, "1 + 2 * 3") != 7
        throw Error("target unhealthy after empty-target evals")
    Log("target_healthy=ok")
    Log("OK")
} catch as e {
    Log("FAIL: " e.What " | " e.Message " | line " e.Line " | " e.Extra)
    FileAppend out, outFile
    ExitApp 1
}
FileAppend out, outFile
ExitApp 0
