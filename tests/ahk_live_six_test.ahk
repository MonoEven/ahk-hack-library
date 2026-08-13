#Include ..\lib\ahk_live\init.ahk

pid := Integer(A_Args[1])
outFile := A_Temp "\ahk_live_six_test.out"
csvFile := A_Temp "\ahk_live_six_test.csv"
try FileDelete(outFile)
try FileDelete(csvFile)

try {
    session := AhkLiveSession()
    if !session.Attach(pid).ok
        throw Error("attach failed")

    obs := AhkLiveObservability(session.hook)
    seen := []
    watcher := obs.WatchWhen("Mul(4)", "Mul(4) > 5", (event) => seen.Push(event.value), 300)
    Sleep 900
    watcher.Stop()
    if seen.Length != 1
        throw Error("observability assertion failed")
    FileAppend("obs_events=" seen.Length "`n", outFile)

    fault := AhkLiveFault(session)
    injected := fault.InjectReplace("Mul", "NewMul")
    if !injected.ok
        throw Error(injected.error)
    faultValue := session.Eval("Mul(4)")
    if !faultValue.ok or faultValue.value != 99
        throw Error("fault assertion failed")
    FileAppend("fault_value=" faultValue.value "`n", outFile)
    if !injected.value["patch"].Rollback().ok
        throw Error("rollback failed")

    procs := AhkLiveDesktop.List()
    FileAppend("desktop_count=" procs.Length "`n", outFile)

    report := AhkLiveForensics.Report(session.hook)
    FileAppend("forensics_version=" report["version"]
        . " funcs=" report["functions"].Count
        . " classes=" report["classes"].Count "`n", outFile)

    agent := AhkLiveAgent(pid)
    agentResult := agent.Eval("Mul(4)")
    if !agentResult.ok or agentResult.value != 8
        throw Error("agent assertion failed")
    FileAppend("agent_eval=" agentResult.value "`n", outFile)
    agent.Close()

    AhkLiveCompat.ExportCsv(session.hook, csvFile)
    if !FileExist(csvFile)
        throw Error("compat export assertion failed")
    FileAppend("compat_csv=" FileExist(csvFile) "`n", outFile)

    session.Close()
    FileAppend("PASS`n", outFile)
    ExitApp 0
} catch as e {
    FileAppend("FAIL " e.What " | " e.Message " | line " e.Line "`n", outFile)
    ExitApp 1
}
