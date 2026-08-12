#NoTrayIcon
Persistent

pidFile := A_Temp "\ahk_remote_attach_target.pid"
outFile := A_Temp "\ahk_remote_function.out"
errFile := A_Temp "\ahk_remote_function.err"
try FileDelete(outFile)
try FileDelete(errFile)
FileAppend(DllCall("GetCurrentProcessId") "`n", pidFile)

name := "Abs"

B_direct(x) {
    return Abs(x)
}

B_dynamic(x) {
    global name
    return %name%(x)
}

F7:: {
    global outFile
    FileAppend("direct=" B_direct(1) "`n", outFile)
}

F8:: {
    global outFile
    FileAppend("dynamic=" B_dynamic(1) "`n", outFile)
}
