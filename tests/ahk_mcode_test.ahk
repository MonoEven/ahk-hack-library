#SingleInstance Force
#NoTrayIcon

#Include ..\lib\ahk_hack.ahk

out := ""
outFile := A_ScriptDir "\ahk_mcode_test.out"
try {
    AhkMagic.Init()
    out .= AhkMagic.Summary() "`n"
    out .= "Abs rva=0x" Format("{:X}", AhkMagic.BifRva("Abs")) "`n"
    out .= "Sin rva=0x" Format("{:X}", AhkMagic.BifRva("Sin")) "`n"

    name := "Abs"
    old := AhkMagic.PatchBif("Abs", "Sin")
    entryAddr := AhkMagic.bifTablePtr
        + AhkMagic.bif["Abs"]["index"] * AhkMagic.bifStride
        + A_PtrSize
    afterPtr := NumGet(entryAddr, "Ptr")
    sinAddr := AhkMagic.BifAddr("Sin")
    out .= "after patch ptr=0x" Format("{:X}", afterPtr)
        . " sin=0x" Format("{:X}", sinAddr) "`n"
    if afterPtr != sinAddr
        throw Error("memory patch did not stick")

    patched := %name%(1)
    expected := Sin(1)
    out .= "patched Abs(1)=" patched "`nexpected sin(1)=" expected "`n"

    AhkMagic.RestoreBif("Abs", old)
    restored := %name%(1)
    out .= "restored Abs(1)=" restored "`n"
    afterRestorePtr := NumGet(entryAddr, "Ptr")
    absAddr := AhkMagic.BifAddr("Abs")
    out .= "after restore ptr=0x" Format("{:X}", afterRestorePtr)
        . " abs=0x" Format("{:X}", absAddr) "`n"
    if afterRestorePtr != absAddr
        throw Error("restore did not stick")

    ; Deep patch: redirect an already-compiled direct call in source.
    deepState := AhkMagic.PatchBifObject(Abs, "Sin")
    deepPatched := Abs(1)
    if Abs(deepPatched - Sin(1)) > 0.000000001
        throw Error("deep patch did not redirect direct call")
    AhkMagic.RestoreBifObject(Abs, deepState)
    if Abs(1) != 1
        throw Error("deep restore failed")
    out .= "deep patch ok`n"
    out .= "OK`n"
} catch as e {
    out .= "FAIL: " e.What " | " e.Message " | line " e.Line " | " e.Extra "`n"
    FileAppend out, outFile
    ExitApp 1
}
FileAppend out, outFile
ExitApp 0
