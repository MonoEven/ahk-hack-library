#NoTrayIcon
Persistent

pidFile := A_Temp "\ahk_live_probe_target.pid"
FileAppend(DllCall("GetCurrentProcessId") "`n", pidFile)

Add(a, b) {
    return a + b
}

Mul(x) {
    return x * 2
}

Squared(x) {
    return x * x
}

NewMul(x) {
    return 99
}

F9:: {
    global outFile
    if !IsSet(outFile)
        outFile := A_Temp "\ahk_live_probe_target.out"
    FileAppend("add=" Add(2, 3) "`n", outFile)
    FileAppend("mul=" Mul(4) "`n", outFile)
}
