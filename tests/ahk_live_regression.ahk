#Include ..\lib\ahk_live\init.ahk

pid := Integer(A_Args[1])
outFile := A_Temp "\ahk_live_regression.out"
traceLog := A_Temp "\ahk_live_regression_trace.log"
if FileExist(outFile) {
    try {
        FileDelete(outFile)
    } catch {
    }
}
if FileExist(traceLog) {
    try {
        FileDelete(traceLog)
    } catch {
    }
}

try {
    session := AhkLiveSession()
    attach := session.Attach(pid)
    if !attach.ok
        throw Error(attach.error)

    r := session.EvalScript("`nrhkReg(a, b) {`n    return a * b`n}`nrhkReg(3, 4)`n")
    if !r.ok or r.value != 12
        throw Error("eval script after attach failed")

    r := session.Eval("Add(2, 3)")
    if !r.ok or r.value != 5
        throw Error("eval after eval script failed")

    r := session.Snapshot(Map(
        "add", "Add(2, 3)",
        "mul", "Mul(4)"
    ))
    if !r.ok or r.value["add"] != 5 or r.value["mul"] != 8
        throw Error("snapshot after eval script failed")

    tracer := session.Trace("Add", traceLog)
    if !tracer.ok
        throw Error(tracer.error)
    r := session.Eval("Add(2, 3)")
    if !r.ok or r.value != 5
        throw Error("traced call failed")
    traceValue := session.Eval(tracer.value["log_var"])
    if !traceValue.ok or !InStr(traceValue.value, "TRACE exit Add=5")
        throw Error("trace log missing")
    untrace := session.Untrace(tracer.value)
    if !untrace.ok
        throw Error(untrace.error)

    conflict := session.EvalScript(
        "`nAdd(a, b) {`n    return a + b`n}`nAdd(1, 2)`n")
    if conflict.ok or !InStr(conflict.error, "already exists")
        throw Error("duplicate function was not rejected")
    r := session.Eval("Add(2, 3)")
    if !r.ok or r.value != 5
        throw Error("target became unusable after conflict rejection")

    session.Close()
    FileAppend("PASS`n", outFile)
    ExitApp 0
} catch as e {
    FileAppend("FAIL " e.What " | " e.Message " | line " e.Line "`n"
        , outFile)
    ExitApp 1
}
