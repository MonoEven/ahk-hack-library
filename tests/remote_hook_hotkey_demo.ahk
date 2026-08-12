#SingleInstance Force
#NoTrayIcon
#Include ..\ahk_hack_single.ahk

hook := 0
logFile := A_Temp "\ahk_hook_hotkey_demo.log"
try FileDelete(logFile)
FileAppend("start`n", logFile)

F1:: {
    global hook
    name := A_Args.Length ? A_Args[1] : "AutoHotkey64.exe"
    hook := AhkMagic.AttachRemoteByName(name)
    FileAppend("attached pid=" hook["pid"]
        . " bif=" hook["builtins"]["count"] "`n", logFile)
    ToolTip "attached " hook["pid"]
}

F2:: {
    global hook
    if !hook {
        FileAppend("press F1 first`n", logFile)
        return
    }
    AhkMagic.RemoteRedirect(hook, "Abs", "Sin")
    FileAppend("redirected Abs -> Sin`n", logFile)
    ToolTip "Abs -> Sin"
}

F3:: {
    global hook
    if !hook {
        FileAppend("press F1 first`n", logFile)
        return
    }
    r := AhkMagic.RemoteEval(hook, "1 + 2 * 3")
    FileAppend("eval=" r "`n", logFile)
    ToolTip "eval=" r
}
