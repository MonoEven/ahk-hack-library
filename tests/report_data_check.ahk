#SingleInstance Force
#NoTrayIcon
#Include ..\reports\ahk-runtime-AutoHotkey64-report.ahk
out := "count=" AhkHackReport["builtins"]["count"] "`n"
out .= "name=" AhkHackReport["builtins"]["functions"]["Abs"]["rva"] "`n"
out .= "stride=" AhkHackReport["builtins"]["stride"] "`n"
outFile := A_ScriptDir "\report_data_check.out"
FileAppend out, outFile
ExitApp 0
