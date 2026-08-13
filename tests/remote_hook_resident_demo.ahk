#SingleInstance Force
#NoTrayIcon
#Include ..\ahk_hack_single.ahk

hook := 0
targetOut := A_Temp "\ahk_remote_resident.out"
logFile := A_Temp "\ahk_hook_resident_demo.log"
if FileExist(logFile) {
    try {
        FileDelete(logFile)
    } catch {
    }
}

LastLine(prefix) {
    global targetOut
    text := FileRead(targetOut)
    if RegExMatch(text, "m)^" prefix "=(.*)$", &m)
        return m[1]
    return ""
}

F1:: {
    global hook
    global logFile
    name := A_Args.Length ? A_Args[1] : "AutoHotkey64.exe"
    hook := AhkMagic.AttachRemoteByName(name)
    FileAppend("attached " hook["pid"] "`n", logFile)
}

F2:: {
    global hook
    global logFile
    if !hook {
        FileAppend("press F1 first`n", logFile)
        return
    }
    AhkMagic.RemoteRedirect(hook, "Abs", "Sin")
    Send "{F7}"
    Sleep 400
    FileAppend("after redirect f7=" LastLine("f7") "`n", logFile)
}

F3:: {
    global hook
    global logFile
    if !hook {
        FileAppend("press F1 first`n", logFile)
        return
    }
    AhkMagic.RemoteEval(hook, "x := 1 + 2 * 3")
    Send "{F8}"
    Sleep 400
    FileAppend("after eval f8=" LastLine("f8") "`n", logFile)
}
