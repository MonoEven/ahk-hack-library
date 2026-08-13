#Requires AutoHotkey v2
#SingleInstance Force
#NoTrayIcon
#Include lib\ahk_live\init.ahk

outFile := A_Temp "\ahk_live_cli.out"
if FileExist(outFile) {
    try {
        FileDelete(outFile)
    } catch {
    }
}

if A_Args.Length >= 1 and A_Args[1] = "--version" {
    FileAppend(AhkLive.VERSION, outFile, "UTF-8")
    ExitApp 0
}

if A_Args.Length < 3 {
    FileAppend("usage: ahk_live_cli.ahk --eval <pid> <expr>", outFile)
    ExitApp 2
}

mode := A_Args[1]
pid := Integer(A_Args[2])

try {
    session := AhkLiveSession()
    if !session.Attach(pid).ok
        throw Error("attach failed")
    switch mode {
    case "--eval":
        result := session.Eval(A_Args[3])
        if !result.ok
            throw Error(result.error)
        FileAppend(result.value, outFile, "UTF-8")
    case "--functions":
        result := session.ListFunctions()
        if !result.ok
            throw Error(result.error)
        for name in result.value
            FileAppend(name "`n", outFile, "UTF-8")
    case "--classes":
        result := session.ListClasses()
        if !result.ok
            throw Error(result.error)
        for name in result.value
            FileAppend(name "`n", outFile, "UTF-8")
    default:
        throw Error("unknown mode: " mode)
    }
    session.Close()
    ExitApp 0
} catch as e {
    FileAppend("FAIL " e.What " | " e.Message, outFile, "UTF-8")
    ExitApp 1
}
