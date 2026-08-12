#Include ..\lib\ahk_live\init.ahk

pid := Integer(A_Args[1])
outFile := A_Temp "\ahk_live_product_test.out"
try FileDelete(outFile)

try {
    session := AhkLiveSession()
    attach := session.Attach(pid)
    if !attach.ok
        throw Error(attach.error)

    snap := session.Snapshot(Map("mul", "Mul(4)"))
    if !snap.ok
        throw Error(snap.error)
    FileAppend("snap=" snap.value["mul"] "`n", outFile)

    patch := session.BeginPatch()
    if !patch.ok
        throw Error(patch.error)
    ps := patch.value
    replaced := ps.Replace("Mul", "NewMul")
    if !replaced.ok
        throw Error(replaced.error)
    FileAppend("patched=" session.Eval("Mul(4)").value "`n", outFile)

    rollback := ps.Rollback()
    if !rollback.ok
        throw Error(rollback.error)
    FileAppend("rolled_back=" session.Eval("Mul(4)").value
        . " records=" rollback.value "`n", outFile)

    session.Close()
    FileAppend("PASS`n", outFile)
} catch as e {
    FileAppend("FAIL " e.What " | " e.Message " | line " e.Line "`n", outFile)
}
