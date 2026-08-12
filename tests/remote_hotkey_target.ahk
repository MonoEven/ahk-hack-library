#NoTrayIcon
Persistent

pidFile := A_Temp "\ahk_remote_attach_target.pid"
outFile := A_Temp "\ahk_remote_hotkey.out"
errFile := A_Temp "\ahk_remote_hotkey.err"
try FileDelete(outFile)
try FileDelete(errFile)
FileAppend(DllCall("GetCurrentProcessId") "`n", pidFile)

name := "Abs"

F7:: {
    try {
        result := %name%(1)
        FileAppend(result "`n", outFile)
    } catch as e {
        FileAppend(e.What " | " e.Message "`n", errFile)
    }
}
