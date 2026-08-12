#NoTrayIcon
Persistent

pidFile := A_Temp "\ahk_remote_attach_target.pid"
outFile := A_Temp "\ahk_remote_resident.out"
errFile := A_Temp "\ahk_remote_resident.err"
try FileDelete(outFile)
try FileDelete(errFile)
FileAppend(DllCall("GetCurrentProcessId") "`n", pidFile)

x := 0
name := "Abs"

F7:: {
    global name
    global outFile
    try {
        FileAppend("f7=" %name%(1) "`n", outFile)
    } catch as e {
        FileAppend("f7err=" e.Message "`n", outFile)
    }
}

F8:: {
    global x
    global outFile
    FileAppend("f8=" x "`n", outFile)
}
