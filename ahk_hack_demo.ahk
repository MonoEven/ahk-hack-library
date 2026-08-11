#SingleInstance Force
#NoTrayIcon

#Include ahk_hack_single.ahk

out := ""
outFile := A_ScriptDir "\ahk_hack_demo.out"

Write(s) {
    global out
    out .= s "`n"
}

try {
    AhkMagic.Init()
    Write(AhkMagic.Summary())
    Write("")

    Write("builtin functions: " AhkMagic.bifCount " total")
    for name in ["Abs", "Sin", "StrLen", "MsgBox", "WinExist"] {
        if AhkMagic.bif.Has(name) {
            e := AhkMagic.bif[name]
            Write(Format("  {1} rva=0x{2:X} min={3} max={4} fid={5}",
                name, e["rva"], e["min"], e["max"], e["fid"]))
        }
    }
    addrs := Map()
    for name, e in AhkMagic.bif
        addrs[e["rva"]] := addrs.Has(e["rva"]) ? addrs[e["rva"]] + 1 : 1
    Write("distinct C functions behind the builtin table: " addrs.Count)
    Write("")

    Write("native functions: " AhkMagic.mdfuncCount " total")
    for name in ["BlockInput", "MsgBox", "WinActivate"] {
        if AhkMagic.mdfunc.Has(name)
            Write(Format("  {1} rva=0x{2:X} ret={3}",
                name, AhkMagic.mdfunc[name]["rva"], AhkMagic.mdfunc[name]["ret"]))
    }
    Write("")

    Write("builtin vars: " AhkMagic.bivCount " total")
    for name in ["AhkPath", "AhkVersion", "Clipboard"] {
        if AhkMagic.biv.Has(name)
            Write(Format("  {1} getter=0x{2:X} setter=0x{3:X}",
                name, AhkMagic.biv[name]["getter_rva"], AhkMagic.biv[name]["setter_rva"]))
    }
    Write("")

    k32 := DllCall("GetModuleHandle", "Str", "kernel32.dll", "Ptr")
    exports := AhkMagic.ScanExports(k32)
    Write("kernel32 exports: " exports.Count " total")
    for name in ["VirtualAlloc", "CreateFileW", "ReadProcessMemory"] {
        if exports.Has(name)
            Write(Format("  {1} rva=0x{2:X} ord={3}",
                name, exports[name]["rva"], exports[name]["ordinal"]))
    }
    Write("")

    Write("patch demo (Abs -> Sin):")
    name := "Abs"
    Write("  baseline Abs(1) via child eval = " AhkMagic.Eval("Abs(1)"))
    old := AhkMagic.PatchBif("Abs", "Sin")
    Write("  patched Abs(1)=" %name%(1))
    AhkMagic.RestoreBif("Abs", old)
    entryAddr := AhkMagic.bifTablePtr
        + AhkMagic.bif["Abs"]["index"] * AhkMagic.bifStride
        + A_PtrSize
    Write("  restored ptr=0x" Format("{:X}", NumGet(entryAddr, "Ptr")))
    Write("")

    Write("eval demo:")
    Write("  1 + 2 * 3 = " AhkMagic.Eval("1 + 2 * 3"))
    Write("  StrLen(`"hello`") = " AhkMagic.Eval("StrLen(`"hello`")"))
    Write("  Format(`"{:.2f}`", Sin(1)) = "
        . AhkMagic.Eval("Format(`"{:.2f}`", Sin(1))"))
    Write("OK")
} catch as e {
    Write("FAIL: " e.What " | " e.Message " | line " e.Line)
}
FileAppend out, outFile
ExitApp 0
