#SingleInstance Force
#NoTrayIcon

#Include ..\reports\ahk-runtime-AutoHotkey64-report.ahk

outFile := A_ScriptDir "\report_load_only.out"
FileAppend "loaded", outFile
ExitApp 0
