#SingleInstance Force
#NoTrayIcon
#Include ..\ahk_hack_single.ahk

pid := Integer(A_Args[1])
out := ""
outFile := A_ScriptDir "\remote_deep_redirect_test.out"
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
    before := AhkMagic.RemoteEval(hook, "B_direct(1)")
    Log("before_direct=" before)
    if before != 1
        throw Error("B_direct(1) should be 1 before redirect, got " before)

    result := AhkMagic.RemoteDeepRedirect(hook, "Abs", "Sin")
    Log("patched_count=" result["count"])
    if !result["count"]
        throw Error("RemoteDeepRedirect found no Func object to patch")

    afterDirect := AhkMagic.RemoteEval(hook, "B_direct(1)")
    afterDynamic := AhkMagic.RemoteEval(hook, "B_dynamic(1)")
    Log("after_direct=" afterDirect " after_dynamic=" afterDynamic)
    ; Sin(1) = 0.8414709848078965; a tolerance check proves the redirect.
    if Abs(afterDirect - 0.8414709848078965) > 1e-6
        throw Error("deep redirect failed: B_direct(1)=" afterDirect)
    if Abs(afterDynamic - 0.8414709848078965) > 1e-6
        throw Error("table redirect failed: B_dynamic(1)=" afterDynamic)
    Log("OK")
} catch as e {
    Log("FAIL: " e.What " | " e.Message " | line " e.Line " | " e.Extra)
    FileAppend out, outFile
    ExitApp 1
}
FileAppend out, outFile
ExitApp 0
