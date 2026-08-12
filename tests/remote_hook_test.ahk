#SingleInstance Force
#NoTrayIcon
#Include ..\ahk_hack_single.ahk

pid := Integer(A_Args[1])
outFile := A_ScriptDir "\remote_hook_test.out"
try FileDelete(outFile)

Log(msg) {
    global outFile
    FileAppend(msg "`n", outFile)
}

try {
    hook := AhkMagic.AttachRemote(pid)
    Log("bif=" hook["builtins"]["count"]
        . " native=" hook["native_functions"]["count"]
        . " biv=" hook["builtin_vars"]["count"])
    Log("Abs rva=0x" Format("{:X}", hook["builtins"]["entries"]["Abs"]["rva"]))
    r := AhkMagic.RemoteRedirect(hook, "Abs", "Sin")
    Log("redirected at 0x" Format("{:X}", r["fn_slot"]))
    hook2 := AhkMagic.AttachRemote(pid)
    Log("after Abs rva=0x" Format("{:X}", hook2["builtins"]["entries"]["Abs"]["rva"]))
    Log("PASS")
    ExitApp 0
} catch as e {
    Log("FAIL " e.What " | " e.Message " | line " e.Line " extra=" e.Extra)
    ExitApp 1
}
