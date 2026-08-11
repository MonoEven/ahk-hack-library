#SingleInstance Force
#NoTrayIcon
#Include ..\ahk_hack_single.ahk

outFile := A_ScriptDir "\version_probe.out"
if FileExist(outFile)
    FileDelete outFile

try {
    AhkMagic.Init()
    AhkMagic._LocateInternalFunctions()
    FileAppend "version=" A_AhkVersion "`n"
        . "slot=0x" Format("{:X}", AhkMagic.currLineSlot) "`n"
        . "gscript=0x" Format("{:X}", AhkMagic.gScript) "`n"
        . "finalize=0x" Format("{:X}", AhkMagic.finalizeExpr) "`n"
        . "findvar=0x" Format("{:X}", AhkMagic.findOrAddVar) "`n"
        . "free=0x" Format("{:X}", AhkMagic.crtFree) "`n"
        . "symInvalid=" AhkMagic.symInvalid "`n"
        , outFile
    ExitApp 0
} catch as e {
    FileAppend "FAIL version=" A_AhkVersion " " e.Message "`n"
        , outFile
    ExitApp 1
}
