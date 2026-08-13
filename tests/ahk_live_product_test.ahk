#Include ..\lib\ahk_live\init.ahk

pid := Integer(A_Args[1])
outFile := A_Temp "\ahk_live_product_test.out"
if FileExist(outFile) {
    try {
        FileDelete(outFile)
    } catch {
    }
}

try {
    session := AhkLiveSession()
    attach := session.Attach(pid)
    if !attach.ok
        throw Error(attach.error)

    snap := session.Snapshot(Map("mul", "Mul(4)"))
    if !snap.ok
        throw Error(snap.error)
    if snap.value["mul"] != 8
        throw Error("snapshot assertion failed")
    FileAppend("snap=" snap.value["mul"] "`n", outFile)

    patch := session.BeginPatch()
    if !patch.ok
        throw Error(patch.error)
    ps := patch.value
    replaced := ps.Replace("Mul", "NewMul")
    if !replaced.ok
        throw Error(replaced.error)
    patched := session.Eval("Mul(4)")
    if !patched.ok or patched.value != 99
        throw Error("replace assertion failed")
    FileAppend("patched=" patched.value "`n", outFile)

    rollback := ps.Rollback()
    if !rollback.ok
        throw Error(rollback.error)
    rolledBack := session.Eval("Mul(4)")
    if !rolledBack.ok or rolledBack.value != 8
        throw Error("rollback assertion failed")
    FileAppend("rolled_back=" rolledBack.value
        . " records=" rollback.value "`n", outFile)

    session.Close()
    FileAppend("PASS`n", outFile)
    ExitApp 0
} catch as e {
    FileAppend("FAIL " e.What " | " e.Message " | line " e.Line "`n", outFile)
    ExitApp 1
}
