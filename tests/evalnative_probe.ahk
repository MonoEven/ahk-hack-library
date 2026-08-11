#SingleInstance Force
#NoTrayIcon
#Include ..\ahk_hack_single.ahk

outFile := A_ScriptDir "\evalnative_probe.out"
if FileExist(outFile)
    FileDelete outFile

ok := true
Check(got, expected, label) {
    global ok, outFile
    if got != expected or Type(got) != Type(expected) {
        ok := false
        FileAppend "FAIL " label ": got=" got " (" Type(got)
            . ") expected=" expected " (" Type(expected) ")`n", outFile
    }
}

try {
    AhkMagic.Init()
    Check(AhkMagic.EvalNative("1 + 2 * 3"), 7, "arithmetic")
    Check(AhkMagic.EvalNative("2 * 3.5"), 7.0, "float")
    Check(AhkMagic.EvalNative("`"hello`""), "hello", "string")
    Check(AhkMagic.EvalNative("3 > 2"), 1, "compare")
} catch as e {
    ok := false
    FileAppend "FAIL " e.What " | " e.Message " | line " e.Line "`n"
        , A_ScriptDir "\evalnative_probe.out"
}

FileAppend (ok ? "OK`n" : "FAILED`n"), outFile
ExitApp ok ? 0 : 1
