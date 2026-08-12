#Include ..\lib\ahk_live\init.ahk

pid := Integer(A_Args[1])
outFile := A_Temp "\ahk_live_cross_smoke.out"
try FileDelete(outFile)

try {
    hook := AhkLiveInspect.Attach(pid)
    snap := AhkLiveInspect.Snapshot(hook, Map("add", "Add(2, 3)", "mul", "Mul(4)"))
    FileAppend("snap=" snap["add"] "," snap["mul"] "`n", outFile)

    funcs := AhkLiveInspect.ListFunctions(hook)
    FileAppend("funcs=" funcs.Count
        . " add=" AhkLive._JoinList(funcs["Add"]["params"]) "`n", outFile)

    classes := AhkLiveInspect.ListClasses(hook)
    FileAppend("classes=" classes.Count "`n", outFile)

    record := AhkLivePatch.Replace(hook, "Mul", "NewMul")
    FileAppend("replaced=" AhkLiveInspect.Eval(hook, "Mul(4)") "`n", outFile)
    AhkLivePatch.Restore(hook, record)
    FileAppend("restored=" AhkLiveInspect.Eval(hook, "Mul(4)") "`n", outFile)

    watchLog := []
    watcher := AhkLiveTrace.Watch(hook, "Mul(4)", (v) => watchLog.Push(v), 300)
    Sleep 900
    watcher["Stop"]()
    FileAppend("watch=" watchLog.Length "`n", outFile)
    FileAppend("PASS`n", outFile)
} catch as e {
    FileAppend("FAIL " e.What " | " e.Message " | line " e.Line "`n", outFile)
}
