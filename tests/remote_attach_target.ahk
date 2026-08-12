#NoTrayIcon
Persistent

pidFile := A_Temp "\ahk_remote_attach_target.pid"
FileAppend Format("{1}`n{2}`n", DllCall("GetCurrentProcessId"), A_AhkPath), pidFile
Sleep 120000
