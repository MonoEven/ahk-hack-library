#NoTrayIcon
Persistent

pidFile := A_Temp "\ahk_remote_attach_target.pid"
outFile := A_Temp "\ahk_remote_evalscript.out"
errFile := A_Temp "\ahk_remote_evalscript.err"
try FileDelete(outFile)
try FileDelete(errFile)
FileAppend(DllCall("GetCurrentProcessId") "`n", pidFile)

A(x) {
    return 1
}

B_add(x) {
    return A(x)
}

F9:: {
    global outFile
    try {
        FileAppend("f9=" B_add(1) "`n", outFile)
    } catch as e {
        FileAppend("f9err=" e.Message "`n", outFile)
    }
}
