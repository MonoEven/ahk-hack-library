#Include ..\lib\ahk_live\init.ahk

pid := Integer(A_Args[1])
outFile := A_Temp "\ahk_live_test.out"
traceLog := A_Temp "\ahk_live_trace.log"
try FileDelete(outFile)
try FileDelete(traceLog)

try {
    hook := AhkLiveInspect.Attach(pid)
    snap := AhkLiveInspect.Snapshot(hook, Map(
        "add", "Add(2, 3)",
        "mul", "Mul(4)"
    ))
    FileAppend("snap_add=" snap["add"] " snap_mul=" snap["mul"] "`n", outFile)

    tracer := AhkLiveTrace.Trace(hook, "Add", traceLog)
    FileAppend(tracer["script"] "`n--END--`n", outFile)
    FileAppend("old_call=" AhkLiveInspect.Eval(hook, tracer["oldName"] "(2, 3)") "`n", outFile)
    r := AhkLiveInspect.Eval(hook, "Add(2, 3)")
    FileAppend("traced_add=" r "`n", outFile)
    AhkLiveTrace.Untrace(hook, tracer)
    r := AhkLiveInspect.Eval(hook, "Add(2, 3)")
    FileAppend("restored_add=" r "`n", outFile)

    record := AhkLivePatch.Replace(hook, "Mul", "NewMul")
    FileAppend(record["script"] "`n--REPLACE-END--`n", outFile)
    r := AhkLiveInspect.Eval(hook, "Mul(4)")
    FileAppend("replaced_mul=" r "`n", outFile)
    AhkLivePatch.Restore(hook, record)
    r := AhkLiveInspect.Eval(hook, "Mul(4)")
    FileAppend("restored_mul=" r "`n", outFile)

    watchLog := []
    watcher := AhkLiveTrace.Watch(hook, "Mul(4)", (v) => watchLog.Push(v), 300)
    Sleep 1200
    watcher["Stop"]()
    FileAppend("watch_count=" watchLog.Length " first=" (watchLog.Length ? watchLog[1] : "") "`n", outFile)

    globals := AhkLiveInspect.Globals(hook, ["pidFile"])
    FileAppend("pidFile=" globals["pidFile"] "`n", outFile)
    funcs := AhkLiveInspect.ListFunctions(hook)
    FileAppend("func_count=" funcs.Count
        . " add_params=" AhkLive._JoinList(funcs["Add"]["params"]) "`n", outFile)
    FileAppend("name_off=" hook["name_off"] "`n", outFile)
    classes := AhkLiveInspect.ListClasses(hook)
    FileAppend("class_count=" classes.Count
        . " point_methods=" AhkLive._JoinList(_Keys(classes["Point"])) "`n", outFile)

    FileAppend("PASS`n", outFile)
} catch as e {
    FileAppend("FAIL " e.What " | " e.Message " | line " e.Line "`n", outFile)
}

_Keys(map) {
    out := []
    for key in map
        out.Push(key)
    return out
}
