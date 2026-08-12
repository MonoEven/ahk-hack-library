#Include ..\lib\ahk_live\init.ahk

pid := Integer(A_Args[1])
outFile := A_Temp "\ahk_live_benchmark.out"
try FileDelete(outFile)

try {
    session := AhkLiveSession()
    if !session.Attach(pid).ok
        throw Error("attach failed")

    t := A_TickCount
    session.Eval("Add(2, 3)")
    evalMs := A_TickCount - t

    t := A_TickCount
    session.Snapshot(Map("add", "Add(2, 3)", "mul", "Mul(4)"))
    snapMs := A_TickCount - t

    t := A_TickCount
    session.ListFunctions()
    listMs := A_TickCount - t

    FileAppend("eval_ms=" evalMs " snap_ms=" snapMs " list_ms=" listMs "`n", outFile)
    FileAppend("PASS`n", outFile)
    session.Close()
} catch as e {
    FileAppend("FAIL " e.What " | " e.Message " | line " e.Line "`n", outFile)
}
