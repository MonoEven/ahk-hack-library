#SingleInstance Force
#NoTrayIcon
#Include ..\ahk_hack_single.ahk

hook := 0
targetOut := A_Temp "\ahk_remote_evalscript.out"
logFile := A_Temp "\ahk_hook_evalscript_demo.log"
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
    try {
        script := "
        (
        NewA(x) {
            return 42
        }
        NewA(1)
        )"
        AhkMagic.RemoteEvalScript(hook, script)
        AhkMagic.RemoteReplaceFuncBody(hook, "A", "NewA")
        Send "{F9}"
        Sleep 400
        FileAppend("after address replace A f9=" LastLine("f9") "`n", logFile)
    } catch as e {
        FileAppend("F2 FAIL " e.What " | " e.Message " | line " e.Line "`n", logFile)
    }
}

F3:: {
    global hook
    global logFile
    if !hook {
        FileAppend("press F1 first`n", logFile)
        return
    }
    try {
        classScript := "
        (
        class PointNew {
            x := 0
            y := 0
            __New(x, y) {
                this.x := x
                this.y := y
            }
        }
        PointNew(1, 2).y
        )"
        AhkMagic.RemoteEvalScript(hook, classScript)
        r := AhkMagic.RemoteEval(hook, "PointNew(1, 2).y")
        FileAppend("after class eval=" r "`n", logFile)
    } catch as e {
        FileAppend("F3 FAIL " e.What " | " e.Message " | line " e.Line "`n", logFile)
    }
}
