#SingleInstance Force
#NoTrayIcon
#Include ..\ahk_hack_single.ahk

outFile := A_ScriptDir "\version_probe_" A_AhkVersion ".out"
if FileExist(outFile)
    FileDelete outFile

try {
    AhkMagic.Init()
    AhkMagic._LocateInternalFunctions()
    AhkMagic._LocateEvalScriptFunctions()
    FileAppend "version=" A_AhkVersion "`n"
        . "slot=0x" Format("{:X}", AhkMagic.currLineSlot) "`n"
        . "gscript=0x" Format("{:X}", AhkMagic.gScript) "`n"
        . "postfix=0x" Format("{:X}", AhkMagic.exprToPostfix) "`n"
        . "expand=0x" Format("{:X}", AhkMagic.expandSingleArg) "`n"
        . "finalize=0x" Format("{:X}", AhkMagic.finalizeExpr) "`n"
        . "findvar=0x" Format("{:X}", AhkMagic.findOrAddVar) "`n"
        . "free=0x" Format("{:X}", AhkMagic.crtFree) "`n"
        . "symInvalid=" AhkMagic.symInvalid "`n"
        . "preparse=0x" Format("{:X}", AhkMagic.evalPreparse) "`n"
        . "preprocess=0x" Format("{:X}", AhkMagic.evalPreprocess) "`n"
        . "openInclude=0x" Format("{:X}", AhkMagic.evalOpenInclude) "`n"
        . "loadTs=0x" Format("{:X}", AhkMagic.evalLoadTs) "`n"
        . "gptr=0x" Format("{:X}", AhkMagic.evalGptr) "`n"
        . "srcCount=0x" Format("{:X}", AhkMagic.evalSrcCount) "`n"
        , outFile
    ExitApp 0
} catch as e {
    FileAppend "FAIL version=" A_AhkVersion " " e.Message "`n"
        , outFile
    ExitApp 1
}
