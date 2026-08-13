#Include ..\lib\ahk_live\init.ahk

pid := Integer(A_Args[1])
outFile := A_Temp "\ahk_live_cross_smoke.out"
try FileDelete(outFile)

try {
    hook := AhkLiveInspect.Attach(pid)
    snap := AhkLiveInspect.Snapshot(hook, Map("add", "Add(2, 3)", "mul", "Mul(4)"))
    if snap["add"] != 5 or snap["mul"] != 8
        throw Error("snapshot assertion failed")
    FileAppend("snap=" snap["add"] "," snap["mul"] "`n", outFile)

    funcs := AhkLiveInspect.ListFunctions(hook)
    if funcs.Count < 1
        throw Error("function inventory assertion failed")
    FileAppend("funcs=" funcs.Count
        . " add=" AhkLive._JoinList(funcs["Add"]["params"]) "`n", outFile)

    classes := AhkLiveInspect.ListClasses(hook)
    FileAppend("classes=" classes.Count "`n", outFile)

    record := AhkLivePatch.Replace(hook, "Mul", "NewMul")
    replaced := AhkLiveInspect.Eval(hook, "Mul(4)")
    if replaced != 99
        throw Error("replace assertion failed")
    FileAppend("replaced=" replaced "`n", outFile)
    AhkLivePatch.Restore(hook, record)
    restored := AhkLiveInspect.Eval(hook, "Mul(4)")
    if restored != 8
        throw Error("restore assertion failed")
    FileAppend("restored=" restored "`n", outFile)

    watchLog := []
    watcher := AhkLiveTrace.Watch(hook, "Mul(4)", (v) => watchLog.Push(v), 300)
    Sleep 900
    watcher.Stop()
    FileAppend("watch=" watchLog.Length "`n", outFile)
    if watchLog.Length < 1
        throw Error("watch assertion failed")
    FileAppend("PASS`n", outFile)
    ExitApp 0
} catch as e {
    FileAppend("FAIL " e.What " | " e.Message " | line " e.Line "`n", outFile)
    ExitApp 1
}
