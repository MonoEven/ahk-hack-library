; ahk-hack standalone core.
;
; One-file AutoHotkey v2 scanner for AutoHotkey executables.  Copy this file
; anywhere and #Include it, or run ahk_hack_demo.ahk for a self-test.
; The x64 blob below is generated from lib/mcode/scanner.c by
; tools/build_mcode.py; it locates g_BIF, sMdFunc and g_BIV_A inside the
; running interpreter and copies entry metadata into a caller buffer.
MC_REMOTE_CALL_STUB_X64 := "564883ec304889ce0f1041284c8b49204c8b4118488b4908488b56100f11442420ff1689463831c04883c4305ec3"
MC_REMOTE_EVAL_STUB_X64 := "564883ec704889ce0f1041304c8b49284c8b4120488b4910488b56180f11442420ff1689c1894678b80100000085c9754f488b4638488b4e400f10000f104810488b40200f1056604c8b4e584c8b4650488b564848894424680f114c24580f114424480f57c00f114424380f11542420c744243001000000ff560889467c31c04883c4705ec3"
MC_PE_EXPORT_SCANNER_X64 := "4157415641545657534885c90f94c04885d2410f94c04108c0b8010000000f85fb0000006681394d5a0f85f0000000448b413c41813c08504500000f85de0000006641817c08180b020f85d0000000418b8408880000004885c00f84ab0000004183bc088c000000000f849c0000004c8d0408448b4c08108b7c0818448b540820448b5c08248b74081c4c890248c7421000000000b80800000085ff747881ff0010000041b800100000440f42c74801ce4901ca4901cb4a8d3cc500000000488d3c7f31db66662e0f1f840000000000458b32450fb73b468b24be4901ce4c89741a184c89641a204501cf44897c1a28c7441a2c000000004983c2044983c3024883c3184839df75c7eb0e0f57c00f1102b8100000004531c04c89040231c05b5f5e415c415e415fc3"
MC_BIF_SCANNER_X64 := "41574156565755534881ec780200004885c90f94c04885d2410f94c04108c0be010000000f85da0600006681394d5a0f85cf0600008b413c813c08504500000f85bf06000066817c08180b020f85b2060000440fb74c0806664183f91041b810000000450f42c1664585c90f84e4020000440fb74c0814410fb7f84801c84c01c8448d04fd000000004f8d04804c8d4c24704531d241bb0100000031ed31dbeb50660f7f442450440fb6742452440fb67c24534180f6614180f7744508f7440fb67424544180f6610fb6db4508fe410f44db66666666662e0f1f8400000000004983c2284983c1204d39d00f84d7000000468b7410204585f6460f44741028468b7c10244901cf4d89394d01f74d8979084e8b74101866490f6ec6660f7f442460440fb67c24604d8971134180ff2e75af66410f7ec641c1ee084180fe640f845dffffff450fb6f64183fe72743d4183fe74758c660f7f442430440fb6742432440fb67c24334180f6654180f7784508f7440fb67424344180f674400fb6ed4508fe410f44ebe955ffffff660f7f442440807c2442640f8544ffffff807c2443610f8539ffffff807c2444740f852effffff66440fc5f00241c1ee084180fe610fb6dbe906ffffff4084ed0f95c184db0f95c020c889f9c1e1054531c0eb24906642c784048000000000004531c946888c04820000004983c0204c39c10f8454010000460fb69404830000004180fa2e753e4280bc04840000007275434280bc04850000007375384280bc048600000072752d4280bc048700000063410f94c184c0746ceb21662e0f1f84000000000084c0758c4531c9eb570f1f80000000004531c984c074494180fa2e0f856fffffff4280bc048400000074754d4280bc04850000006575424280bc04860000007875374280bc048700000074410f94c1eb2b6666666666662e0f1f8400000000004180f10146888c048000000046888c0481000000e925ffffff4531c946888c04800000004280bc04840000007275304280bc04850000006475254280bc048600000061751a4280bc048700000074750f4280bc048800000061410f94c1eb034531c946888c04810000004280bc04840000006475284280bc048500000061751d4280bc04860000007475124280bc048700000061410f94c1e9a1feffff4531c9e999feffff31ff488d420848894424284989d74889542420488d4c247041b92000000089fa4531c0e8a303000085c00f847f0300004d8d7720498d47184c897424284889442420488d4c2470be0100000041b92800000089fa41b801000000e86c03000085c00f8448030000498d5f38498d473048895c24284889442420488d4c247041b91800000089fa41b802000000e83a03000085c00f84160300004c89f849c747102000000049c747282800000049c747401800000049c7474800000000418b570885d27e6dffca4881faff010000b9ff010000480f42ca488b10c1e1054883c1204531c00f1f8400000000004e8b0c024e894c00504e8b4c02084e894c0058460fb64c021046894c0060460fb64c021146894c0064460fb64c021246894c006842c744006c000000004983c0204c39c175ba418b0e85c90f8ea5010000ffc94881f9ff010000baff010000480f42d1488b4818488d1492488d14d5280000004531c0662e0f1f8400000000004e8b0c014e898c00504000004e8b4c01084e898c0058400000460fb64c011046888c0060400000460fb64c011146888c0061400000460fb64c011246888c0062400000460fb64c011346888c0063400000460fb64c011446888c0064400000460fb64c011546888c0065400000460fb64c011646888c0066400000460fb64c011746888c0067400000460fb64c011846888c0068400000460fb64c011946888c0069400000460fb64c011a46888c006a400000460fb64c011b46888c006b400000460fb64c011c46888c006c400000460fb64c011d46888c006d400000460fb64c011e46888c006e400000460fb64c011f46888c006f400000460fb64c012046888c0070400000460fb64c012146888c0071400000460fb64c012246888c0072400000460fb64c012346888c0073400000460fb64c012446888c0074400000460fb64c012546888c0075400000460fb64c012646888c0076400000460fb64c012746888c00774000004983c0284c39c20f858afeffff448b034585c00f8e8c00000041ffc84181f8ff000000baff000000410f42d0488b4830ffc231f64585c074704189d14181e1fe0100004531d24531c04e8b1c114e899c10509000004e8b5c11084e899c10589000004e8b5c11104e899c10609000004e8b5c11184e899c10689000004e8b5c11204e899c10709000004e8b5c11284e899c10789000004983c0024983c2304d39c175a6eb0731f6eb324531c0f6c201742a48055090000049c1e0034b8d14404c8b04114c8904104c8b4411084c89441008488b4c111048894c101089f04881c4780200005b5d5f5e415e415fc3662e0f1f8400000000004157415641554154565755534883ec3085d20f8e76040000488bac24a00000004c8b94249800000089d64889f748c1e70531db48c74424200000000048c744242800000000eb15660f1f84000000000048ffc34839f30f84170400004889da48c1e205488d0411807c11110075068078120074dc4c8b384c8b7008498d47104c39f077cc4d8b27eb404c8b9424980000004c8b0c244c8b5c2408488b4424284939c3490f47c34889442428488b442420490f47c548894424200f1f80000000004983c5184d39f577874d89fd4c89e04983c7084d8b650831d2eb0e0f1f4400004883c2204839d774d7807c1111007507807c11120074e9483944110876e24839041177dc31d2662e0f1f840000000000440fb71c10664585db74254183c381664183fba1729a4c8d5a024883fa7e4c89da75ddeb8b66662e0f1f84000000000031d2eb196666662e0f1f8400000000004883c2204839d70f8463ffffff807c11100074ec4c3964110876e54c39241177df0fb7104183f8010f840f0200004585c00f857d0200006683fa410f852fffffff66837802620f8524ffffffba0600000066837804730f8514ffffff66833c02000f8509ffffff4b8d04294883c01041bb010000004c39f00f87ccfeffff4b8d14294c89e84c890c244c895c240848894424184889d04c8b124c8b5a084531c9eb1b66666666662e0f1f8400000000004983c1204c39cf0f847cfeffff42807c091100750842807c09120074e34e3954090876dc4e39140977d631d20f1f4000450fb70c12664585c974214183c181664183f9a10f823ffeffff4c8d4a024883fa7e4c89ca75d9e92dfeffff31d2eb0d4883c2204839d70f841cfeffff807c11100074ec4c395c110876e54c391c1177df4183f802488944241075406641833a590f85bf0000006641837a02590f85b30000006641837a04590f85a70000006641837a06590f859b0000006641837a08000f858f000000e98e010000488b542418488b1248895424184531db488b542418460fb70c1a430fb7141a664585c974476685d274428d42bf8d6a203c1a400fb6c50f43c2418d51bf418d692080fa1a400fb6d5410f43d138c275274983c3024981fb80000000488bac24a0000000488b44241075a6eb1e664139d17618e946fdffff488bac24a0000000488b4424100f8333fdffff4c8b5c240849ffc34c8b0c244a8d1408488b4424104c01c84883c0104c39f0488b4424104c8b9424980000000f8651feffffe90dfdffff6683fa420f8529fdffff668378026c0f851efdffff668378046f0f8513fdffff66837806630f8508fdffff668378086b0f85fdfcffff6683780a490f85f2fcffff6683780c6e0f85e7fcffff6683780e700f85dcfcffff66837810750f85d1fcffffba1400000066837812740f85c1fcffffe9a8fdffff6683fa410f85b2fcffff66837802680f85a7fcffff668378046b0f859cfcffff66837806500f8591fcffff66837808610f8586fcffff6683780a740f857bfcffffba0e0000006683780c680f856bfcffffe952fdffff4c8b5c240849ffc34c8b9424980000004c8b0c24e927fcffff4c8b4424204d85c00f94c0488b5424284883fa0a0f92c108c1740431c0eb0c4d890248895500b8010000004883c4305b5d5f5e415c415d415e415fc3"


; Decode a raw hex machine-code blob and return an executable Buffer.
MCode(hex) {
    size := StrLen(hex) // 2
    buf := Buffer(size)
    loop size {
        byte := Integer("0x" SubStr(hex, 2 * A_Index - 1, 2))
        NumPut("UChar", byte, buf, A_Index - 1)
    }
    oldProtect := 0
    if !DllCall("VirtualProtect", "Ptr", buf.Ptr, "UPtr", size, "UInt", 0x40, "UInt*", oldProtect)
        throw Error("VirtualProtect failed", -1)
    return buf
}


class AhkMagic {
    static scanner := 0
    static exportScanner := 0
    static inprocEval := 0
    static memScriptLoader := 0
    static internalLocator := 0
    static internalLocated := false
    static evalScriptLocated := false
    static evalLayoutLocated := false
    static evalMFuncsOff := 0
    static evalMFuncsCountOff := 0
    static evalMLastLineOff := 0
    static evalMJumpLineOff := 0
    static evalCurrOff := 0
    static evalParserLocated := false
    static evalParser := Map()
    static evalPreparse := 0
    static evalPreprocess := 0
    static evalOpenInclude := 0
    static evalLoadTs := 0
    static evalSrcCount := 0
    static evalGptr := 0
    static exprToPostfix := 0
    static expandSingleArg := 0
    static currLineSlot := 0
    static crtFree := 0
    static gScript := 0
    static finalizeExpr := 0
    static findOrAddVar := 0
    static symInvalid := 73
    static moduleBase := 0
    static bifTablePtr := 0
    static bifCount := 0
    static bifStride := 0
    static mdfuncTablePtr := 0
    static mdfuncCount := 0
    static mdfuncStride := 0
    static bivTablePtr := 0
    static bivCount := 0
    static bivStride := 0
    static bif := Map()
    static mdfunc := Map()
    static biv := Map()

    static Init() {
        if AhkMagic.scanner
            return
        if A_PtrSize != 8
            throw Error("this mcode blob is x64 only", -1)
        AhkMagic.scanner := MCode(MC_BIF_SCANNER_X64)
        AhkMagic.moduleBase := DllCall("GetModuleHandle", "Str", A_AhkPath, "Ptr")
        if !AhkMagic.moduleBase
            throw Error("GetModuleHandle failed", -1)

        out := Buffer(64 * 1024)
        rc := DllCall(AhkMagic.scanner.Ptr, "Ptr", AhkMagic.moduleBase, "Ptr", out.Ptr, "Int")
        if rc != 0
            throw Error("AhkScanTables failed with rc=" rc, -1)

        AhkMagic.bifTablePtr := NumGet(out, 0, "Ptr")
        AhkMagic.bifCount := NumGet(out, 8, "Int64")
        AhkMagic.bifStride := NumGet(out, 16, "Int64")
        AhkMagic.mdfuncTablePtr := NumGet(out, 24, "Ptr")
        AhkMagic.mdfuncCount := NumGet(out, 32, "Int64")
        AhkMagic.mdfuncStride := NumGet(out, 40, "Int64")
        AhkMagic.bivTablePtr := NumGet(out, 48, "Ptr")
        AhkMagic.bivCount := NumGet(out, 56, "Int64")
        AhkMagic.bivStride := NumGet(out, 64, "Int64")

        bifBase := 80
        bifStride := 32
        loop AhkMagic.bifCount {
            p := out.Ptr + bifBase + (A_Index - 1) * bifStride
            namePtr := NumGet(p, 0, "Ptr")
            fnPtr := NumGet(p, 8, "Ptr")
            min := NumGet(p, 16, "UInt")
            max := NumGet(p, 20, "UInt")
            fid := NumGet(p, 24, "UInt")
            name := StrGet(namePtr, "UTF-16")
            AhkMagic.bif[name] := Map(
                "index", A_Index - 1,
                "rva", fnPtr - AhkMagic.moduleBase,
                "min", min,
                "max", max,
                "fid", fid
            )
        }

        mdfBase := 80 + 512 * 32
        mdfStride := 40
        loop AhkMagic.mdfuncCount {
            p := out.Ptr + mdfBase + (A_Index - 1) * mdfStride
            namePtr := NumGet(p, 0, "Ptr")
            fnPtr := NumGet(p, 8, "Ptr")
            retType := NumGet(p, 16, "UChar")
            name := StrGet(namePtr, "UTF-16")
            AhkMagic.mdfunc[name] := Map(
                "index", A_Index - 1,
                "rva", fnPtr - AhkMagic.moduleBase,
                "ret", retType
            )
        }

        bivBase := 80 + 512 * 32 + 512 * 40
        bivStride := 24
        loop AhkMagic.bivCount {
            p := out.Ptr + bivBase + (A_Index - 1) * bivStride
            namePtr := NumGet(p, 0, "Ptr")
            getter := NumGet(p, 8, "Ptr")
            setter := NumGet(p, 16, "Ptr")
            name := StrGet(namePtr, "UTF-16")
            AhkMagic.biv[name] := Map(
                "index", A_Index - 1,
                "getter_rva", getter ? getter - AhkMagic.moduleBase : 0,
                "setter_rva", setter ? setter - AhkMagic.moduleBase : 0
            )
        }
    }

    static BifRva(name) {
        AhkMagic.Init()
        if !AhkMagic.bif.Has(name)
            throw Error("builtin not found: " name)
        return AhkMagic.bif[name]["rva"]
    }

    static BifAddr(name) {
        AhkMagic.Init()
        return AhkMagic.moduleBase + AhkMagic.BifRva(name)
    }

    static PatchBif(name, newName) {
        AhkMagic.Init()
        if !AhkMagic.bif.Has(name)
            throw Error("builtin not found: " name)
        if !AhkMagic.bif.Has(newName)
            throw Error("builtin not found: " newName)
        entryAddr := AhkMagic.bifTablePtr
            + AhkMagic.bif[name]["index"] * AhkMagic.bifStride
            + A_PtrSize
        oldPtr := NumGet(entryAddr, 0, "Ptr")
        expected := AhkMagic.moduleBase + AhkMagic.bif[name]["rva"]
        if oldPtr != expected
            throw Error("table pointer mismatch for " name
                ": got 0x" Format("{:X}", oldPtr)
                ", expected 0x" Format("{:X}", expected))
        NumPut("Ptr", AhkMagic.moduleBase + AhkMagic.bif[newName]["rva"], entryAddr)
        return oldPtr
    }

    static RestoreBif(name, oldPtr) {
        AhkMagic.Init()
        if !AhkMagic.bif.Has(name)
            throw Error("builtin not found: " name)
        entryAddr := AhkMagic.bifTablePtr
            + AhkMagic.bif[name]["index"] * AhkMagic.bifStride
            + A_PtrSize
        NumPut("Ptr", oldPtr, entryAddr)
    }

    ; Deep patch: change the mBIF field of an already-resolved built-in Func
    ; object, so even direct calls compiled at load time (e.g. Abs(1)) are
    ; redirected.  Works together with PatchBif on the table itself.
    static PatchBifObject(fnObj, newName) {
        AhkMagic.Init()
        if !(fnObj is Func)
            throw TypeError("expected a Func object")
        if !AhkMagic.bif.Has(newName)
            throw Error("builtin not found: " newName)
        fnName := fnObj.Name
        if !AhkMagic.bif.Has(fnName)
            throw Error("function object is not a built-in: " fnName)
        oldAddr := AhkMagic.moduleBase + AhkMagic.bif[fnName]["rva"]
        newAddr := AhkMagic.moduleBase + AhkMagic.bif[newName]["rva"]
        rawPtr := ObjPtr(fnObj)
        off := AhkMagic._FindBifPtrOffset(rawPtr, oldAddr)
        if off < 0
            throw Error("could not locate mBIF in function object for " fnName)
        NumPut("Ptr", newAddr, rawPtr, off)
        ; Keep future table lookups consistent with the deep patch.
        AhkMagic.PatchBif(fnName, newName)
        return Map(
            "fnName", fnName,
            "newName", newName,
            "oldPtr", oldAddr,
            "offset", off
        )
    }

    static RestoreBifObject(fnObj, state) {
        AhkMagic.Init()
        if !(fnObj is Func)
            throw TypeError("expected a Func object")
        fnName := fnObj.Name
        if state["fnName"] != fnName
            throw Error("state does not match function object " fnName)
        if !AhkMagic.bif.Has(state["newName"])
            throw Error("builtin not found: " state["newName"])
        rawPtr := ObjPtr(fnObj)
        current := AhkMagic.moduleBase + AhkMagic.bif[state["newName"]]["rva"]
        off := AhkMagic._FindBifPtrOffset(rawPtr, current)
        if off < 0
            throw Error("could not locate mBIF in function object for " fnName)
        NumPut("Ptr", state["oldPtr"], rawPtr, off)
        AhkMagic.RestoreBif(fnName, state["oldPtr"])
    }

    static _FindBifPtrOffset(rawPtr, targetAddr) {
        loop 64 {
            off := (A_Index - 1) * 8
            if NumGet(rawPtr, off, "Ptr") = targetAddr
                return off
        }
        return -1
    }

    ; General PE export-table scanner (works for any loaded DLL/EXE module).
    static ScanExports(moduleBase) {
        if !AhkMagic.exportScanner
            AhkMagic.exportScanner := MCode(MC_PE_EXPORT_SCANNER_X64)
        out := Buffer(100 * 1024)
        rc := DllCall(
            AhkMagic.exportScanner.Ptr,
            "Ptr", moduleBase,
            "Ptr", out.Ptr,
            "Int"
        )
        if rc != 0
            throw Error("AhkScanExports failed with rc=" rc)
        count := NumGet(out, 8, "Int64")
        result := Map()
        loop count {
            p := out.Ptr + 24 + (A_Index - 1) * 24
            namePtr := NumGet(p, 0, "Ptr")
            fnRva := NumGet(p, 8, "Int64")
            ordinal := NumGet(p, 16, "UInt")
            result[StrGet(namePtr, "UTF-8")] := Map(
                "rva", fnRva,
                "ordinal", ordinal
            )
        }
        return result
    }

    ; ------------------------------------------------------------------
    ; True in-process Eval.  Locates the interpreter's own expression
    ; compiler/evaluator, builds a temporary Line/ArgStruct, and calls
    ; them directly in this process.
    ; ------------------------------------------------------------------

    static _ModuleSections() {
        base := AhkMagic.moduleBase
        peOff := NumGet(base, 0x3C, "UInt")
        numSections := NumGet(base + peOff + 6, "UShort")
        optSize := NumGet(base + peOff + 20, "UShort")
        secTable := base + peOff + 24 + optSize
        result := Map()
        loop numSections {
            hdr := secTable + (A_Index - 1) * 40
            name := StrGet(hdr, 8, "UTF-8")
            vsize := NumGet(hdr + 8, "UInt")
            va := NumGet(hdr + 12, "UInt")
            result[name] := Map(
                "rva", va,
                "size", vsize,
                "ptr", base + va
            )
        }
        return result
    }

    static _TextSection(secs) {
        if secs.Has(".text")
            return secs[".text"]
        for name, sec in secs
            if name != ".rsrc"
                return sec
        throw Error("text section not found")
    }

    static _FindUtf16(secs, text) {
        len := StrLen(text)
        needle := Buffer(2 * (len + 1), 0)
        StrPut(text, needle, "UTF-16")
        hits := []
        for name, sec in secs {
            if name = ".rsrc"
                continue
            if !sec["ptr"] or sec["size"] < 2 * len
                continue
            p := sec["ptr"]
            count := sec["size"] >= 2 * len
                ? Min((sec["size"] - 2 * len) // 2 + 1, 0x100000)
                : 0
            if count <= 0
                continue
            loop count {
                off := (A_Index - 1) * 2
                ok := true
                loop len {
                    if NumGet(p + off + 2 * (A_Index - 1), "UShort")
                        != NumGet(needle, 2 * (A_Index - 1), "UShort") {
                        ok := false
                        break
                    }
                }
                if ok and NumGet(p + off + 2 * len, "UShort") = 0
                    hits.Push(sec["rva"] + off)
            }
        }
        return hits
    }

    static _RipRefs(sec, targetRva) {
        p := sec["ptr"]
        size := sec["size"]
        refs := []
        if size < 8
            return refs
        loop size - 7 {
            i := A_Index - 1
            b := NumGet(p + i, "UChar")
            if b != 0x48 and b != 0x4C
                continue
            if NumGet(p + i + 1, "UChar") != 0x8D
                continue
            reg := NumGet(p + i + 2, "UChar")
            if reg != 0x05 and reg != 0x0D and reg != 0x15 and reg != 0x1D
                and reg != 0x25 and reg != 0x2D and reg != 0x35 and reg != 0x3D
                continue
            disp := NumGet(p + i + 3, "Int")
            next := sec["rva"] + i + 7
            if next + disp = targetRva
                refs.Push(sec["rva"] + i)
        }
        return refs
    }

    static _FnStart(sec, refRva) {
        p := sec["ptr"]
        off := refRva - sec["rva"]
        i := off
        while i > 0 {
            if NumGet(p + i - 1, "UChar") = 0xCC
                and i >= 2 and NumGet(p + i - 2, "UChar") = 0xCC
                break
            i -= 1
        }
        return sec["rva"] + i
    }

    static _FindCallers(sec, targetRva) {
        p := sec["ptr"]
        size := sec["size"]
        calls := []
        if size < 6
            return calls
        loop size - 5 {
            i := A_Index - 1
            if NumGet(p + i, "UChar") != 0xE8
                continue
            disp := NumGet(p + i + 1, "Int")
            if sec["rva"] + i + 5 + disp = targetRva
                calls.Push(sec["rva"] + i)
        }
        return calls
    }

    static _BestStart(sec, refs) {
        starts := Map()
        for ref in refs {
            start := AhkMagic._FnStart(sec, ref)
            starts[start] := starts.Has(start) ? starts[start] + 1 : 1
        }
        best := 0
        bestCount := 0
        for start, count in starts {
            if count > bestCount {
                best := start
                bestCount := count
            }
        }
        return best
    }

    static _CurrLineSlotAddr() {
        AhkMagic.Init()
        if !AhkMagic.biv.Has("LineNumber")
            throw Error("A_LineNumber getter not found")
        p := AhkMagic.moduleBase + AhkMagic.biv["LineNumber"]["getter_rva"]
        if NumGet(p, "UChar") != 0x48 or NumGet(p + 1, "UChar") != 0x8B
            or NumGet(p + 2, "UChar") != 0x05
            throw Error("unexpected A_LineNumber getter code")
        disp := NumGet(p + 3, "Int")
        return p + 7 + disp
    }

    static _LocateInternalFunctions() {
        if AhkMagic.internalLocated
            return
        secs := AhkMagic._ModuleSections()
        text := AhkMagic._TextSection(secs)

        postfixRefs := AhkMagic._RipRefs(text, AhkMagic._FindUtf16(secs, "Missing operand.")[1])
        postfix2 := AhkMagic._BestStart(text, postfixRefs)
        if !postfix2
            throw Error("ExpressionToPostfix not found")

        expandRefs := AhkMagic._RipRefs(text, AhkMagic._FindUtf16(secs, "Error evaluating expression.")[1])
        expand := AhkMagic._BestStart(text, expandRefs)
        if !expand
            throw Error("ExpandExpression not found")

        AhkMagic.exprToPostfix := AhkMagic.moduleBase + postfix2
        AhkMagic.expandSingleArg := AhkMagic.moduleBase + expand
        AhkMagic.currLineSlot := AhkMagic._CurrLineSlotAddr()
        if !AhkMagic.internalLocator
            AhkMagic.internalLocator := MCode(MC_INTERNAL_LOCATOR_X64)
        locOut := Buffer(64, 0)
        rc := DllCall(
            AhkMagic.internalLocator.Ptr,
            "Ptr", AhkMagic.moduleBase,
            "UInt64", text["rva"],
            "UInt64", text["size"],
            "UInt64", postfix2,
            "UInt64", expand,
            "Ptr", locOut.Ptr,
            "Int"
        )
        if rc != 0
            throw Error("internal locator failed with rc=" rc)
        AhkMagic.gScript := NumGet(locOut, 0, "Ptr")
        AhkMagic.finalizeExpr := NumGet(locOut, 8, "Ptr")
        AhkMagic.findOrAddVar := NumGet(locOut, 16, "Ptr")
        AhkMagic.crtFree := NumGet(locOut, 24, "Ptr")
        AhkMagic.symInvalid := NumGet(locOut, 32, "UInt")
        AhkMagic.internalLocated := true
    }

    static _LocateCrtFree() {
        secs := AhkMagic._ModuleSections()
        text := AhkMagic._TextSection(secs)
        postfixRva := AhkMagic.exprToPostfix - AhkMagic.moduleBase
        callers := AhkMagic._FindCallers(text, postfixRva)
        for callerRva in callers {
            off := callerRva - text["rva"] + 5
            p := text["ptr"] + off
            loop 96 {
                i := A_Index - 1
                if NumGet(p + i, "UChar") != 0xE8
                    continue
                disp := NumGet(p + i + 1, "Int")
                target := text["rva"] + off + i + 5 + disp
                if target != postfixRva
                    return AhkMagic.moduleBase + target
            }
        }
        throw Error("CRT free not found")
    }

    static _FindBytePattern(sec, hexPattern, startRva := 0) {
        p := sec["ptr"]
        size := sec["size"]
        start := sec["rva"] + startRva
        needle := Buffer(StrLen(hexPattern) // 2)
        loop needle.Size {
            byte := Integer("0x" SubStr(hexPattern, 2 * A_Index - 1, 2))
            NumPut("UChar", byte, needle, A_Index - 1)
        }
        max := size - needle.Size + 1
        loop max {
            i := A_Index - 1
            if NumGet(p + i, "UChar") != NumGet(needle, 0, "UChar")
                continue
            ok := true
            loop needle.Size {
                if NumGet(p + i + A_Index - 1, "UChar")
                    != NumGet(needle, A_Index - 1, "UChar") {
                    ok := false
                    break
                }
            }
            if ok
                return sec["rva"] + i
        }
        return 0
    }

    static _FindBytePatternInFunc(sec, startRva, hexPattern) {
        p := sec["ptr"]
        off := startRva - sec["rva"]
        limit := Min(sec["size"] - 4, off + 0x4000)
        needle := Buffer(StrLen(hexPattern) // 2)
        loop needle.Size {
            byte := Integer("0x" SubStr(hexPattern, 2 * A_Index - 1, 2))
            NumPut("UChar", byte, needle, A_Index - 1)
        }
        i := off
        while i < limit {
            if NumGet(p + i, "UChar") = 0xCC
                and NumGet(p + i + 1, "UChar") = 0xCC
                break
            if NumGet(p + i, "UChar") = NumGet(needle, 0, "UChar") {
                ok := true
                loop needle.Size {
                    if NumGet(p + i + A_Index - 1, "UChar")
                        != NumGet(needle, A_Index - 1, "UChar") {
                        ok := false
                        break
                    }
                }
                if ok
                    return true
            }
            i += 1
        }
        return false
    }

    static _LocatePreprocessFunc(sec) {
        p := sec["ptr"]
        size := sec["size"]
        count := size - 8
        loop count {
            i := A_Index - 1
            if NumGet(p + i, "UChar") != 0x41
                or NumGet(p + i + 1, "UChar") != 0x0F
                or NumGet(p + i + 2, "UChar") != 0xB6
                continue
            m := NumGet(p + i + 3, "UChar")
            if m != 0x76 and m != 0x7E
                continue
            if NumGet(p + i + 4, "UChar") != 0x23
                continue
            limit := Min(size - 4, i + 0x300)
            j := i + 5
            while j < limit {
                if NumGet(p + j, "UChar") = 0x80
                    and NumGet(p + j + 1, "UChar") = 0x78
                    and NumGet(p + j + 2, "UChar") = 0x23
                    and NumGet(p + j + 3, "UChar") = 0x02
                    return AhkMagic._FnStart(sec, sec["rva"] + i)
                j += 1
            }
        }
        return 0
    }

    static _LocateGptr(sec, preparseRva) {
        callers := AhkMagic._FindCallers(sec, preparseRva)
        for caller in callers {
            start := AhkMagic._FnStart(sec, caller)
            p := sec["ptr"]
            off := start - sec["rva"]
            limit := Min(sec["size"] - 16, off + 0x4000)
            i := off
            while i < limit {
                if NumGet(p + i, "UChar") = 0xCC
                    and NumGet(p + i + 1, "UChar") = 0xCC
                    break
                if NumGet(p + i, "UChar") = 0x48
                    and NumGet(p + i + 1, "UChar") = 0x8B
                    and NumGet(p + i + 2, "UChar") = 0x05 {
                    j := i + 7
                    while j < Min(i + 24, limit) {
                        if NumGet(p + j, "UChar") = 0x48
                            and NumGet(p + j + 1, "UChar") = 0x89
                            and NumGet(p + j + 2, "UChar") = 0x58
                            and NumGet(p + j + 3, "UChar") = 0x28
                            or NumGet(p + j, "UChar") = 0x48
                            and NumGet(p + j + 1, "UChar") = 0x89
                            and NumGet(p + j + 2, "UChar") = 0x50
                            and NumGet(p + j + 3, "UChar") = 0x28 {
                            disp := NumGet(p + i + 3, "Int")
                            return sec["rva"] + i + 7 + disp
                        }
                        j += 1
                    }
                }
                i += 1
            }
        }
        return 0
    }

    static _HasBytesNear(sec, rva, hexPattern, range := 40) {
        found := AhkMagic._FindBytePattern(sec, hexPattern, rva - sec["rva"])
        return found and found - rva < range
    }

    static _LocateLoadTs(sec, openRva) {
        callers := AhkMagic._FindCallers(sec, openRva)
        for caller in callers {
            p := sec["ptr"]
            base := sec["rva"]
            off := caller - base + 5
            limit := Min(sec["size"] - 5, off + 0x300)
            i := off
            while i < limit {
                isCmp := NumGet(p + i, "UChar") = 0x83
                    and NumGet(p + i + 1, "UChar") = 0xF8
                    and NumGet(p + i + 2, "UChar") = 0x03
                isCmp2 := NumGet(p + i, "UChar") = 0x3D
                    and NumGet(p + i + 1, "UChar") = 0x03
                if isCmp or isCmp2 {
                    j := i + 3
                    callLimit := Min(sec["size"] - 5, j + 0x200)
                    while j < callLimit {
                        if NumGet(p + j, "UChar") = 0xE8 {
                            disp := NumGet(p + j + 1, "Int")
                            target := base + j + 5 + disp
                            if AhkMagic._HasBytesNear(sec, target
                                , "555356574154415541564157", 40)
                                return target
                        }
                        j += 1
                    }
                    break
                }
                i += 1
            }
        }
        return 0
    }

    static _LocateSrcCount(sec, openRva) {
        callers := AhkMagic._FindCallers(sec, openRva)
        for caller in callers {
            p := sec["ptr"]
            base := sec["rva"]
            off := caller - base
            i := off - 5
            min := Max(0, off - 0x100)
            while i >= min {
                b := NumGet(p + i, "UChar")
                if b = 0x8B
                    and (NumGet(p + i + 1, "UChar") = 0x2D
                    or NumGet(p + i + 1, "UChar") = 0x1D
                    or NumGet(p + i + 1, "UChar") = 0x35
                    or NumGet(p + i + 1, "UChar") = 0x3D) {
                    disp := NumGet(p + i + 2, "Int")
                    target := base + i + 6 + disp
                    if target > 0x10000 {
                        val := NumGet(AhkMagic.moduleBase + target, "Int")
                        if val >= 0 and val < 100000
                            return target
                    }
                }
                if b = 0x44
                    and NumGet(p + i + 1, "UChar") = 0x8B
                    and (NumGet(p + i + 2, "UChar") = 0x2D
                    or NumGet(p + i + 2, "UChar") = 0x3D) {
                    disp := NumGet(p + i + 3, "Int")
                    target := base + i + 7 + disp
                    if target > 0x10000 {
                        val := NumGet(AhkMagic.moduleBase + target, "Int")
                        if val >= 0 and val < 100000
                            return target
                    }
                }
                i -= 1
            }
        }
        return 0
    }

    static _LocateEvalScriptFunctions() {
        if AhkMagic.evalScriptLocated
            return
        AhkMagic._LocateInternalFunctions()
        secs := AhkMagic._ModuleSections()
        text := AhkMagic._TextSection(secs)
        postfixRva := AhkMagic.exprToPostfix - AhkMagic.moduleBase
        callers := AhkMagic._FindCallers(text, postfixRva)
        preparse := 0
        for caller in callers {
            start := AhkMagic._FnStart(text, caller)
            if AhkMagic._FindBytePatternInFunc(text, start, "803B03")
                and AhkMagic._FindBytePatternInFunc(text, start, "803B04") {
                preparse := start
                break
            }
        }
        if !preparse
            throw Error("PreparseExpressions not found")

        preprocess := AhkMagic._LocatePreprocessFunc(text)
        if !preprocess
            throw Error("PreprocessLocalVars not found")

        openNeedle := "48895C240848895424105556574154415541564157488DAC243000FEFFB8D0000200"
        openNeedle21 := "40535556574154415541564157B8D8000100"
        open := AhkMagic._FindBytePattern(text, openNeedle)
        if !open
            open := AhkMagic._FindBytePattern(text, openNeedle21)
        if !open
            throw Error("OpenIncludedFile not found")

        loadTs := AhkMagic._LocateLoadTs(text, open)
        if !loadTs
            throw Error("LoadIncludedFile(TextStream) not found")
        srcCount := 0
        if !RegExMatch(A_AhkVersion, "^2\.1")
            srcCount := AhkMagic._LocateSrcCount(text, open)

        gptr := AhkMagic._LocateGptr(text, preparse)
        if !gptr
            throw Error("g pointer not found")

        AhkMagic.evalPreparse := AhkMagic.moduleBase + preparse
        AhkMagic.evalPreprocess := AhkMagic.moduleBase + preprocess
        AhkMagic.evalOpenInclude := AhkMagic.moduleBase + open
        AhkMagic.evalLoadTs := AhkMagic.moduleBase + loadTs
        AhkMagic.evalSrcCount := srcCount ? AhkMagic.moduleBase + srcCount : 0
        AhkMagic.evalGptr := AhkMagic.moduleBase + gptr
        AhkMagic.evalScriptLocated := true
    }

    static _EvalStructOffsets() {
        return Map(
            "line_action", 0,
            "line_argc", 1,
            "line_arg", 8,
            "line_attribute", 16,
            "line_next", 32,
            "arg_postfix", 24,
            "token_symbol", 16,
            "token_usage", 8,
            "token_value", 0,
            "deref_marker", 0,
            "deref_len", 20
        )
    }

    static _DiscoverCurrOff() {
        if AhkMagic.evalCurrOff
            return AhkMagic.evalCurrOff
        secs := AhkMagic._ModuleSections()
        text := AhkMagic._TextSection(secs)
        preparseRva := AhkMagic.evalPreparse - AhkMagic.moduleBase
        callers := AhkMagic._FindCallers(text, preparseRva)
        for caller in callers {
            p := text["ptr"]
            base := text["rva"]
            off := AhkMagic._FnStart(text, caller) - base
            limit := Min(text["size"] - 16, off + 0x4000)
            i := off
            while i < limit {
                if NumGet(p + i, "UChar") = 0xCC
                    and NumGet(p + i + 1, "UChar") = 0xCC
                    break
                if NumGet(p + i, "UChar") = 0x48
                    and NumGet(p + i + 1, "UChar") = 0x8B
                    and NumGet(p + i + 2, "UChar") = 0x05 {
                    j := i + 7
                    while j < Min(i + 24, limit) {
                        if NumGet(p + j, "UChar") = 0x48
                            and (NumGet(p + j + 1, "UChar") = 0x89)
                            and (NumGet(p + j + 2, "UChar") = 0x58
                                or NumGet(p + j + 2, "UChar") = 0x50) {
                            AhkMagic.evalCurrOff := NumGet(p + j + 3, "UChar")
                            return AhkMagic.evalCurrOff
                        }
                        j += 1
                    }
                }
                i += 1
            }
        }
        throw Error("g->curr offset not found")
    }

    static _DiscoverEvalLayout() {
        if AhkMagic.evalLayoutLocated
            return
        AhkMagic._LocateEvalScriptFunctions()
        AhkMagic._DiscoverCurrOff()
        gScript := AhkMagic.gScript
        g := NumGet(AhkMagic.evalGptr, "Ptr")
        savedProbeCur := NumGet(g, AhkMagic.evalCurrOff, "Ptr")
        gSnap := Buffer(0x100)
        DllCall("RtlMoveMemory", "Ptr", gSnap.Ptr, "Ptr", g, "UPtr", 0x100)
        NumPut("Ptr", 0, g, AhkMagic.evalCurrOff)
        snap := Buffer(0x200)
        DllCall("RtlMoveMemory", "Ptr", snap.Ptr, "Ptr", gScript, "UPtr", 0x200)
        oldSrcCount := AhkMagic.evalSrcCount ? NumGet(AhkMagic.evalSrcCount, "Int") : 0

        probe := "
(
ahkHackLayoutProbe() {
    return 1
}
)"
        AhkMagic._LoadScriptMemory(probe)

        countOff := 0
        loop 0x200 // 4 {
            off := (A_Index - 1) * 4
            before := NumGet(snap, off, "Int")
            after := NumGet(gScript, off, "Int")
            if after = before + 1 and before >= 0 and after > 0 {
                countOff := off
                break
            }
        }
        if !countOff
            throw Error("mFuncsCount offset not found")
        oldCount := NumGet(snap, countOff, "Int")

        funcsOff := 0
        loop 0x200 // 8 {
            off := (A_Index - 1) * 8
            p := NumGet(gScript, off, "Ptr")
            if p > 0x10000 and p < 0x7fffffffffff
                and !DllCall("IsBadReadPtr", "Ptr", p, "UPtr", 0x100) {
                newFunc := NumGet(p, oldCount * 8, "Ptr")
                if newFunc > 0x10000 and newFunc < 0x7fffffffffff {
                    funcsOff := off
                    break
                }
            }
        }
        if !funcsOff
            throw Error("mFuncs offset not found")

        lastOff := -1
        loop 0x200 // 8 {
            off := (A_Index - 1) * 8
            if off = funcsOff
                continue
            before := NumGet(snap, off, "Ptr")
            after := NumGet(gScript, off, "Ptr")
            if before != after and after > 0x10000 {
                lastOff := off
                break
            }
        }
        if lastOff < 0 {
            detail := "count=" countOff " funcs=" funcsOff
            loop 0x200 // 8 {
                off := (A_Index - 1) * 8
                b := NumGet(snap, off, "Ptr")
                a := NumGet(gScript, off, "Ptr")
                if b != a
                    detail .= " @" Format("{:X}", off) " " b "->" a
                        . " bad=" DllCall("IsBadReadPtr", "Ptr", a, "UPtr", 0x40)
            }
            throw Error("mLastLine offset not found: " detail)
        }

        arrPtr := NumGet(gScript, funcsOff, "Ptr")
        newFunc := NumGet(arrPtr, oldCount * 8, "Ptr")
        oldLast := NumGet(snap, lastOff, "Ptr")
        newLast := NumGet(gScript, lastOff, "Ptr")
        lineSet := Map()
        line := oldLast ? NumGet(oldLast, 32, "Ptr") : 0
        loop 10000 {
            if !line
                break
            lineSet[line] := true
            if line = newLast
                break
            line := NumGet(line, 32, "Ptr")
        }
        jumpOff := 0
        loop 0x100 // 8 {
            off := (A_Index - 1) * 8
            p := NumGet(newFunc, off, "Ptr")
            if p > 0x10000 and lineSet.Has(p) {
                jumpOff := off
                break
            }
        }
        if !jumpOff
            throw Error("mJumpLine offset not found")

        DllCall("RtlMoveMemory", "Ptr", gScript, "Ptr", snap.Ptr, "UPtr", 0x200)
        if AhkMagic.evalSrcCount
            NumPut("Int", oldSrcCount, AhkMagic.evalSrcCount)
        DllCall("RtlMoveMemory", "Ptr", g, "Ptr", gSnap.Ptr, "UPtr", 0x100)
        NumPut("Ptr", savedProbeCur, g, AhkMagic.evalCurrOff)

        AhkMagic.evalMFuncsOff := funcsOff
        AhkMagic.evalMFuncsCountOff := countOff
        AhkMagic.evalMLastLineOff := lastOff
        AhkMagic.evalMJumpLineOff := jumpOff
        AhkMagic._DiscoverParserOffsets()
        AhkMagic.evalLayoutLocated := true
    }

    static _DiscoverParserOffsets() {
        if AhkMagic.evalParserLocated
            return
        secs := AhkMagic._ModuleSections()
        text := AhkMagic._TextSection(secs)
        p := text["ptr"]
        base := text["rva"]
        off := AhkMagic.evalLoadTs - AhkMagic.moduleBase - base
        limit := Min(text["size"] - 8, off + 0x100)
        qCmp := -1
        dCmp := -1
        i := off
        while i < limit {
            b0 := NumGet(p + i, "UChar")
            if b0 = 0x48 and NumGet(p + i + 1, "UChar") = 0x83 {
                modrm := NumGet(p + i + 2, "UChar")
                if modrm = 0x79 and NumGet(p + i + 4, "UChar") = 0 {
                    if qCmp < 0 {
                        qCmp := NumGet(p + i + 3, "UChar")
                    }
                } else if modrm = 0xB9 and NumGet(p + i + 7, "UChar") = 0 {
                    if qCmp < 0 {
                        qCmp := NumGet(p + i + 3, "Int")
                    }
                }
            }
            if b0 = 0x83 and NumGet(p + i + 1, "UChar") = 0xB9
                and (i = off or NumGet(p + i - 1, "UChar") != 0x48)
                and NumGet(p + i + 6, "UChar") = 0 {
                if dCmp < 0
                    dCmp := NumGet(p + i + 2, "Int")
            }
            if qCmp >= 0 and dCmp >= 0
                break
            i += 1
        }
        if qCmp < 0 or dCmp < 0
            throw Error("parser state anchors not found")

        parser := Map()
        if dCmp > 0x100 {
            ; 2.1 layout: ScriptModule/parser state sits below mClassObjectCount.
            parser["mclass_count"] := dCmp
            parser["mline_parent"] := dCmp - 0x30
            parser["mpending_related"] := dCmp - 0x28
            parser["mlast_param_init"] := dCmp - 0x20
            parser["mpending_hotkey"] := dCmp - 0x18
            parser["mexpr_func"] := dCmp - 0x10
            parser["mexpr_func_index"] := dCmp - 8
            parser["mnext_func_body"] := dCmp - 4
            parser["mignore_block"] := dCmp - 3
            parser["mbackcompat"] := dCmp - 2
            parser["mcurrent_module"] := dCmp - 0x50
            parser["mlast_module"] := dCmp - 0x48
        } else {
            ; 2.0 layout: parser fields grow upward from mOpenBlock.
            parser["mopen"] := qCmp
            parser["mpending_parent"] := qCmp + 8
            parser["mpending_related"] := qCmp + 16
            parser["mlast_param_init"] := qCmp + 24
            parser["mnext_func_body"] := qCmp + 32
            parser["mclass_count"] := dCmp
        }
        AhkMagic.evalParser := parser
        AhkMagic.evalParserLocated := true
    }

    ; Evaluate an expression inside this interpreter process.
    ; Returns a number or string.  Throws on unsupported/invalid input.
    static EvalNative(expr) {
        AhkMagic.Init()
        if !(expr is String)
            throw TypeError("expr must be a string", -1)
        if StrLen(expr) > 4096
            throw ValueError("expr too long", -1)
        if !AhkMagic.inprocEval
            AhkMagic.inprocEval := MCode(MC_INPROC_EVAL_X64)
        AhkMagic._LocateInternalFunctions()

        scratch := Buffer(8 * 1024 * 1024, 0)
        out := Buffer(512, 0)
        exprBuf := Buffer((StrLen(expr) + 1) * 2, 0)
        StrPut(expr, exprBuf, "UTF-16")
        rc := DllCall(
            AhkMagic.inprocEval.Ptr,
            "Ptr", AhkMagic.exprToPostfix,
            "Ptr", AhkMagic.expandSingleArg,
            "Ptr", AhkMagic.currLineSlot,
            "Ptr", scratch.Ptr,
            "Ptr", exprBuf.Ptr,
            "Ptr", out.Ptr,
            "Int", 1,
            "Ptr", 0,
            "Ptr", 0,
            "Ptr", AhkMagic.gScript,
            "Ptr", AhkMagic.finalizeExpr,
            "Ptr", AhkMagic.findOrAddVar,
            "Ptr", AhkMagic.crtFree,
            "Ptr", AhkMagic.symInvalid,
            "Int"
        )
        if rc != 0
            throw Error("EvalNative harness failed with rc=" rc)
        status := NumGet(out, 0, "UInt")
        if status != 0
            throw Error("EvalNative failed with status=" status)
        type := NumGet(out, 4, "UInt")
        if type = 1
            return NumGet(out, 8, "Int64")
        if type = 2
            return NumGet(out, 8, "Double")
        if type = 0
            return StrGet(NumGet(out, 16, "Ptr"), "UTF-16")
        throw Error("EvalNative returned unknown symbol " type)
    }

    static Summary() {
        AhkMagic.Init()
        return Format(
            "module=0x{:X}`nbif={} @0x{:X} (stride 0x{:X})`n"
            . "mdfunc={} @0x{:X} (stride 0x{:X})`n"
            . "biv={} @0x{:X} (stride 0x{:X})",
            AhkMagic.moduleBase,
            AhkMagic.bifCount, AhkMagic.bifTablePtr, AhkMagic.bifStride,
            AhkMagic.mdfuncCount, AhkMagic.mdfuncTablePtr, AhkMagic.mdfuncStride,
            AhkMagic.bivCount, AhkMagic.bivTablePtr, AhkMagic.bivStride
        )
    }

    static Eval(expr) {
        AhkMagic.Init()
        if !(expr is String)
            throw TypeError("expr must be a string", -1)
        if expr = ""
            throw ValueError("expr must not be empty", -1)
        if RegExMatch(expr, "[\r\n]")
            return AhkMagic.EvalScript(expr)
        try {
            return AhkMagic.EvalNative(expr)
        } catch as e {
            ; Expressions the in-process pipeline cannot evaluate yet fall
            ; back to the explicit subprocess implementation.
        }
        return AhkMagic.EvalSubprocess(expr)
    }

    static EvalScript(text) {
        AhkMagic.Init()
        if !(text is String)
            throw TypeError("text must be a string", -1)
        if Trim(text) = ""
            throw ValueError("text must not be empty", -1)

        AhkMagic._DiscoverEvalLayout()
        off := AhkMagic._EvalStructOffsets()
        currOff := AhkMagic.evalCurrOff
        mfuncsOff := AhkMagic.evalMFuncsOff
        mfuncsCountOff := AhkMagic.evalMFuncsCountOff
        mlastLineOff := AhkMagic.evalMLastLineOff
        mjumpLineOff := AhkMagic.evalMJumpLineOff

        last := ""
        for line in StrSplit(text, "`n", "`r") {
            t := Trim(line)
            if t = ""
                continue
            if RegExMatch(t, "^(if|else|for|while|loop|try|catch|finally|return|break|continue|class|static|global|local|throw)\b")
                continue
            if SubStr(t, -1) = "{"
                continue
            last := t
        }
        if last = ""
            throw ValueError("no expression result found in script text", -1)

        gScript := AhkMagic.gScript
        oldLast := NumGet(gScript, mlastLineOff, "Ptr")
        oldFuncCount := NumGet(gScript, mfuncsCountOff, "Int")
        g := NumGet(AhkMagic.evalGptr, "Ptr")
        savedCur := NumGet(g, currOff, "Ptr")
        parser := AhkMagic.evalParser
        savedState := []
        for key in ["mopen", "mpending_parent", "mline_parent", "mpending_related"
            , "mlast_param_init", "mpending_hotkey", "mexpr_func", "mcurrent_module"] {
            if parser.Has(key)
                savedState.Push([key, "Ptr", NumGet(gScript, parser[key], "Ptr")])
        }
        for key in ["mexpr_func_index", "mclass_count"] {
            if parser.Has(key)
                savedState.Push([key, "Int", NumGet(gScript, parser[key], "Int")])
        }
        for key in ["mnext_func_body", "mignore_block", "mbackcompat"] {
            if parser.Has(key)
                savedState.Push([key, "UChar", NumGet(gScript, parser[key], "UChar")])
        }
        try {
            if parser.Has("mopen")
                NumPut("Ptr", 0, gScript, parser["mopen"])
            if parser.Has("mpending_parent")
                NumPut("Ptr", 0, gScript, parser["mpending_parent"])
            if parser.Has("mline_parent")
                NumPut("Ptr", 0, gScript, parser["mline_parent"])
            if parser.Has("mpending_related")
                NumPut("Ptr", 0, gScript, parser["mpending_related"])
            if parser.Has("mlast_param_init")
                NumPut("Ptr", 0, gScript, parser["mlast_param_init"])
            if parser.Has("mpending_hotkey")
                NumPut("Ptr", 0, gScript, parser["mpending_hotkey"])
            if parser.Has("mexpr_func")
                NumPut("Ptr", 0, gScript, parser["mexpr_func"])
            if parser.Has("mexpr_func_index")
                NumPut("Int", 0x7fffffff, gScript, parser["mexpr_func_index"])
            if parser.Has("mnext_func_body")
                NumPut("UChar", 0, gScript, parser["mnext_func_body"])
            if parser.Has("mignore_block")
                NumPut("UChar", 0, gScript, parser["mignore_block"])
            if parser.Has("mbackcompat")
                NumPut("UChar", 1, gScript, parser["mbackcompat"])
            if parser.Has("mclass_count")
                NumPut("Int", 0, gScript, parser["mclass_count"])
            NumPut("Ptr", 0, g, currOff)

            if !AhkMagic.memScriptLoader
                AhkMagic.memScriptLoader := MCode(MC_MEM_SCRIPT_X64)
            textBuf := Buffer((StrLen(text) + 1) * 2, 0)
            StrPut(text, textBuf, "UTF-16")
            scratch := Buffer(0x400, 0)
            rc := DllCall(AhkMagic.memScriptLoader.Ptr
                , "Ptr", AhkMagic.evalLoadTs
                , "Ptr", gScript
                , "Ptr", AhkMagic.evalSrcCount
                , "Ptr", textBuf.Ptr
                , "UInt", StrLen(text) * 2
                , "Ptr", scratch.Ptr
                , "Int")
            if rc != 0
                throw Error("LoadIncludedFile(memory) failed with rc=" rc)

            funcsItem := NumGet(gScript, mfuncsOff, "Ptr")
            funcCount := NumGet(gScript, mfuncsCountOff, "Int")
            if funcCount > oldFuncCount {
                firstNew := oldLast ? NumGet(oldLast, off["line_next"], "Ptr") : 0
                if firstNew {
                    rcTail := DllCall(AhkMagic.evalPreparse
                        , "Ptr", gScript
                        , "Ptr", firstNew
                        , "Int")
                    if rcTail != 1
                        throw Error("PreparseExpressions(tail) failed with rc=" rcTail)
                }
                loop funcCount - oldFuncCount {
                    idx := oldFuncCount + A_Index - 1
                    newFunc := NumGet(funcsItem + idx * 8, "Ptr")
                    jump := NumGet(newFunc, mjumpLineOff, "Ptr")
                    if !jump
                        continue

                    rc2 := DllCall(AhkMagic.evalPreparse
                        , "Ptr", gScript
                        , "Ptr", jump
                        , "Int")
                    if rc2 != 1
                        throw Error("PreparseExpressions failed with rc=" rc2)

                    NumPut("Ptr", newFunc, g, currOff)
                    line := jump
                    while line {
                        if NumGet(line, off["line_action"], "UChar") = 3
                            and NumGet(line, off["line_attribute"], "Ptr")
                            NumPut("Ptr", NumGet(line, off["line_attribute"], "Ptr")
                                , g, currOff)
                        argc := NumGet(line, off["line_argc"], "UChar")
                        if argc {
                            arg := NumGet(line, off["line_arg"], "Ptr")
                            if arg and NumGet(arg, 1, "UChar") {
                                postfix := NumGet(arg, off["arg_postfix"], "Ptr")
                                if postfix {
                                    while NumGet(postfix, off["token_symbol"], "UInt") != AhkMagic.symInvalid {
                                        if NumGet(postfix, off["token_symbol"], "UInt") = 4
                                            and NumGet(postfix, off["token_usage"], "UInt") < 3 {
                                            deref := NumGet(postfix, off["token_value"], "Ptr")
                                            if deref {
                                                derefType := NumGet(deref, 16, "UChar")
                                                marker := NumGet(deref, off["deref_marker"], "Ptr")
                                                len := NumGet(deref, off["deref_len"], "UInt")
                                                if derefType = 7 {
                                                    NumPut("Ptr", NumGet(deref, 8, "Ptr")
                                                        , postfix, off["token_value"])
                                                } else if derefType = 0 and marker and len > 0 and len <= 64 {
                                                    var := DllCall(AhkMagic.findOrAddVar
                                                        , "Ptr", gScript
                                                        , "Ptr", marker
                                                        , "UPtr", len
                                                        , "UInt", 0x103
                                                        , "Ptr")
                                                    if var
                                                        NumPut("Ptr", var, postfix, off["token_value"])
                                                }
                                            }
                                        }
                                        postfix += 24
                                    }
                                }
                            }
                        }
                        line := NumGet(line, off["line_next"], "Ptr")
                    }
                    NumPut("Ptr", savedCur, g, currOff)
                    rc4 := DllCall(AhkMagic.evalPreprocess
                        , "Ptr", gScript
                        , "Ptr", newFunc
                        , "Int")
                    if rc4 != 1
                        throw Error("PreprocessLocalVars failed with rc=" rc4)
                }
            }
            ; Detach the newly added lines from the running line list so the
            ; active execution cannot continue into them.  The new function
            ; remains reachable through mFuncs.
            ; NumPut("Ptr", 0, oldLast, off["line_next"])
            ; NumPut("Ptr", oldLast, gScript, mlastLineOff)
            NumPut("Ptr", 0, g, currOff)
            r := AhkMagic.EvalNative(last)
            NumPut("Ptr", savedCur, g, currOff)
            return r
        } finally {
            for item in savedState
                NumPut(item[2], item[3], gScript, parser[item[1]])
            NumPut("Ptr", savedCur, g, currOff)
        }
    }

    static _LoadScriptMemory(text) {
        if !AhkMagic.memScriptLoader
            AhkMagic.memScriptLoader := MCode(MC_MEM_SCRIPT_X64)
        gScript := AhkMagic.gScript
        textBuf := Buffer((StrLen(text) + 1) * 2, 0)
        StrPut(text, textBuf, "UTF-16")
        scratch := Buffer(0x400, 0)
        rc := DllCall(AhkMagic.memScriptLoader.Ptr
            , "Ptr", AhkMagic.evalLoadTs
            , "Ptr", gScript
            , "Ptr", AhkMagic.evalSrcCount
            , "Ptr", textBuf.Ptr
            , "UInt", StrLen(text) * 2
            , "Ptr", scratch.Ptr
            , "Int")
        if rc != 0
            throw Error("LoadIncludedFile(memory) failed with rc=" rc)
    }

    ; ------------------------------------------------------------------
    ; Remote attach: read the three interpreter tables from another
    ; AutoHotkey process without injecting anything.
    ; ------------------------------------------------------------------

    static _RemoteOpen(pid, write := false) {
        access := 0x410
        if write
            access := 0x410 | 0x28
        h := DllCall("OpenProcess", "UInt", access, "Int", 0, "UInt", pid, "Ptr")
        if !h
            throw Error("OpenProcess failed", -1)
        return h
    }

    static _RemoteModuleBase(h, pid) {
        hSnap := DllCall("CreateToolhelp32Snapshot", "UInt", 0x18, "UInt", pid, "Ptr")
        if hSnap = -1 or !hSnap
            throw Error("CreateToolhelp32Snapshot failed", -1)
        buf := Buffer(1080)
        NumPut("UInt", 1080, buf, 0)
        best := Map("base", 0, "path", "")
        try {
            if !DllCall("Module32FirstW", "Ptr", hSnap, "Ptr", buf.Ptr)
                throw Error("Module32FirstW failed", -1)
            loop {
                modBase := NumGet(buf, 24, "Ptr")
                modName := StrGet(buf.Ptr + 48, 256, "UTF-16")
                modPath := StrGet(buf.Ptr + 560, 260, "UTF-16")
                if !best["base"] or InStr(modName, "AutoHotkey", false) {
                    best := Map("base", modBase, "path", modPath)
                    if InStr(modName, "AutoHotkey", false)
                        break
                }
                if !DllCall("Module32NextW", "Ptr", hSnap, "Ptr", buf.Ptr)
                    break
            }
        } finally {
            DllCall("CloseHandle", "Ptr", hSnap)
        }
        if !best["base"]
            throw Error("module base not found", -1)
        return best
    }

    static _RemotePidByName(name) {
        hSnap := DllCall("CreateToolhelp32Snapshot", "UInt", 0x2, "UInt", 0, "Ptr")
        if hSnap = -1 or !hSnap
            throw Error("CreateToolhelp32Snapshot failed", -1)
        buf := Buffer(568)
        NumPut("UInt", 568, buf, 0)
        pid := 0
        try {
            if !DllCall("Process32FirstW", "Ptr", hSnap, "Ptr", buf.Ptr)
                throw Error("Process32FirstW failed", -1)
            loop {
                exe := StrGet(buf.Ptr + 44, 260, "UTF-16")
                if StrCompare(exe, name, false) = 0 {
                    pid := NumGet(buf, 8, "UInt")
                    break
                }
                if !DllCall("Process32NextW", "Ptr", hSnap, "Ptr", buf.Ptr)
                    break
            }
        } finally {
            DllCall("CloseHandle", "Ptr", hSnap)
        }
        if !pid
            throw Error("process not found: " name, -1)
        return pid
    }

    static _RemoteRead(h, addr, size) {
        buf := Buffer(size)
        read := 0
        if !DllCall("ReadProcessMemory", "Ptr", h, "Ptr", addr, "Ptr", buf.Ptr
            , "UPtr", size, "UPtr*", &read)
            throw Error("ReadProcessMemory failed at 0x" Format("{:X}", addr), -1)
        return buf
    }

    static _RemoteSections(h, base) {
        dos := AhkMagic._RemoteRead(h, base, 0x40)
        e_lfanew := NumGet(dos, 0x3C, "UInt")
        pe := AhkMagic._RemoteRead(h, base + e_lfanew, 0x18)
        if NumGet(pe, 0, "UInt") != 0x4550
            throw Error("PE signature not found", -1)
        num := NumGet(pe, 6, "UShort")
        optSize := NumGet(pe, 20, "UShort")
        secTable := base + e_lfanew + 24 + optSize
        hdrs := AhkMagic._RemoteRead(h, secTable, num * 40)
        secs := Map()
        hasText := false
        hasData := false
        loop num {
            off := (A_Index - 1) * 40
            name := StrGet(hdrs.Ptr + off, 8, "UTF-8")
            vsize := NumGet(hdrs, off + 8, "UInt")
            va := NumGet(hdrs, off + 12, "UInt")
            rawSize := NumGet(hdrs, off + 16, "UInt")
            size := vsize ? vsize : rawSize
            if name = ".text"
                hasText := true
            if name = ".rdata" or name = ".data"
                hasData := true
            secs[name] := Map("name", name, "rva", va, "size", size
                , "start", base + va, "end", base + va + size
                , "data", Buffer(0), "ptr", 0)
        }
        strict := hasText and hasData
        for _, sec in secs {
            if strict and sec["name"] != ".text"
                and sec["name"] != ".rdata" and sec["name"] != ".data"
                continue
            if sec["name"] = ".rsrc"
                continue
            if sec["size"] > 0 and sec["size"] < 0x800000 {
                try
                    sec["data"] := AhkMagic._RemoteRead(h, sec["start"], sec["size"])
                catch
                    sec["data"] := Buffer(0)
                sec["ptr"] := sec["data"].Ptr
            }
        }
        return secs
    }

    static _RemoteReadUtf16(secs, addr, maxLen := 64) {
        for _, sec in secs {
            if addr >= sec["start"] and addr < sec["end"]
                and sec["data"].Size > 0 {
                off := addr - sec["start"]
                if off < sec["data"].Size
                    return StrGet(sec["data"].Ptr + off, maxLen, "UTF-16")
            }
        }
        return ""
    }

    static _RemoteStrValid(secs, addr) {
        text := AhkMagic._RemoteReadUtf16(secs, addr, 64)
        if text = "" or StrLen(text) > 64
            return false
        return RegExMatch(text, "^[\x20-\x7E]+$") ? true : false
    }

    static _RemotePtrInText(secs, ptr) {
        hasText := false
        for _, sec in secs
            if sec["name"] = ".text"
                hasText := true
        for _, sec in secs {
            if ptr < sec["start"] or ptr >= sec["end"]
                continue
            if sec["name"] = ".text"
                return true
            if !hasText and sec["name"] != ".rsrc"
                return true
        }
        return false
    }

    static _RemoteTable(h, secs, base, kind) {
        if kind = "bif" {
            stride := 0x20
            anchor := "Abs"
        } else if kind = "mdfunc" {
            stride := 0x28
            anchor := "BlockInput"
        } else {
            stride := 0x18
            anchor := "AhkPath"
        }
        bestStart := 0
        bestCount := 0
        for _, sec in secs {
            if sec["data"].Size < 32
                continue
            p := sec["data"].Ptr
            maxOff := sec["data"].Size - 16
            off := 0
            while off <= maxOff {
                namePtr := NumGet(p + off, "Ptr")
                fnPtr := NumGet(p + off + 8, "Ptr")
                if AhkMagic._RemoteStrValid(secs, namePtr)
                    and AhkMagic._RemotePtrInText(secs, fnPtr) {
                    name := AhkMagic._RemoteReadUtf16(secs, namePtr, 64)
                    if name = anchor {
                        count := 1
                        prevName := name
                        q := off + stride
                        while q + 16 <= sec["data"].Size {
                            qNamePtr := NumGet(p + q, "Ptr")
                            qFnPtr := NumGet(p + q + 8, "Ptr")
                            if !AhkMagic._RemoteStrValid(secs, qNamePtr)
                                or !AhkMagic._RemotePtrInText(secs, qFnPtr)
                                break
                            qName := AhkMagic._RemoteReadUtf16(secs, qNamePtr, 64)
                            if StrCompare(qName, prevName, false) < 0
                                break
                            count += 1
                            prevName := qName
                            q += stride
                        }
                        if count > bestCount {
                            bestCount := count
                            bestStart := sec["rva"] + off
                        }
                    }
                }
                off += 8
            }
        }
        empty := Map("found", false, "stride", stride, "count", 0
            , "entries", Map(), "names", [])
        if bestCount < 10
            return empty
        sec := 0
        for _, s in secs
            if bestStart >= s["rva"] and bestStart < s["rva"] + s["size"] {
                sec := s
                break
            }
        if !sec or sec["data"].Size = 0
            return empty
        entries := Map()
        names := []
        off := bestStart - sec["rva"]
        loop bestCount {
            p := sec["data"].Ptr + off
            namePtr := NumGet(p, "Ptr")
            name := AhkMagic._RemoteReadUtf16(secs, namePtr, 64)
            if kind = "bif" {
                entries[name] := Map(
                    "rva", NumGet(p + 8, "Ptr") - base,
                    "min", NumGet(p + 16, "UChar"),
                    "max", NumGet(p + 17, "UChar"),
                    "fid", NumGet(p + 18, "UChar"))
            } else if kind = "mdfunc" {
                entries[name] := Map(
                    "rva", NumGet(p + 8, "Ptr") - base,
                    "ret", NumGet(p + 16, "UChar"))
            } else {
                getter := NumGet(p + 8, "Ptr")
                setter := NumGet(p + 16, "Ptr")
                entries[name] := Map(
                    "getter_rva", getter - base,
                    "setter_rva", setter ? setter - base : 0)
            }
            names.Push(name)
            off += stride
        }
        return Map("found", true, "table_rva", bestStart, "stride", stride
            , "count", bestCount, "entries", entries, "names", names)
    }

    static _RemoteLocateInternal(secs, base) {
        text := AhkMagic._TextSection(secs)
        if !text["ptr"]
            throw Error("remote text section not loaded", -1)
        postfixRefs := AhkMagic._RipRefs(text
            , AhkMagic._FindUtf16(secs, "Missing operand.")[1])
        postfix2 := AhkMagic._BestStart(text, postfixRefs)
        expandRefs := AhkMagic._RipRefs(text
            , AhkMagic._FindUtf16(secs, "Error evaluating expression.")[1])
        expand := AhkMagic._BestStart(text, expandRefs)
        if !postfix2 or !expand
            throw Error("remote expression functions not found", -1)
        return Map("postfix_rva", postfix2, "expand_rva", expand)
    }

    static _RemoteCurrLineSlot(secs, base, getterRva) {
        text := AhkMagic._TextSection(secs)
        p := text["ptr"]
        off := getterRva - text["rva"]
        if NumGet(p + off, "UChar") != 0x48
            or NumGet(p + off + 1, "UChar") != 0x8B
            or NumGet(p + off + 2, "UChar") != 0x05
            throw Error("unexpected remote A_LineNumber getter code", -1)
        disp := NumGet(p + off + 3, "Int")
        return base + getterRva + 7 + disp
    }

    static _HexBuffer(hex) {
        size := StrLen(hex) // 2
        buf := Buffer(size)
        loop size {
            byte := Integer("0x" SubStr(hex, 2 * A_Index - 1, 2))
            NumPut("UChar", byte, buf, A_Index - 1)
        }
        return buf
    }

    static _RemoteWrite(h, addr, buf) {
        written := 0
        if !DllCall("WriteProcessMemory", "Ptr", h, "Ptr", addr
            , "Ptr", buf.Ptr, "UPtr", buf.Size, "UPtr*", &written)
            throw Error("WriteProcessMemory failed", -1)
    }

    static _RemoteReadString(h, addr, maxLen := 4096) {
        out := Buffer(0)
        chunk := 256
        loop {
            if out.Size >= maxLen
                break
            try
                part := AhkMagic._RemoteRead(h, addr + out.Size, chunk)
            catch
                break
            if part.Size = 0
                break
            combined := Buffer(out.Size + part.Size)
            if out.Size
                DllCall("RtlMoveMemory", "Ptr", combined.Ptr, "Ptr", out.Ptr
                    , "UPtr", out.Size)
            DllCall("RtlMoveMemory", "Ptr", combined.Ptr + out.Size
                , "Ptr", part.Ptr, "UPtr", part.Size)
            out := combined
            found := 0
            loop out.Size - 1 {
                if NumGet(out, A_Index - 1, "UShort") = 0 {
                    found := A_Index - 1
                    break
                }
            }
            if found
                return StrGet(out.Ptr, found // 2, "UTF-16")
        }
        return StrGet(out.Ptr, "UTF-16")
    }

    static AttachRemote(pid) {
        if !(pid is Integer)
            throw TypeError("pid must be an integer", -1)
        h := AhkMagic._RemoteOpen(pid, false)
        try {
            mod := AhkMagic._RemoteModuleBase(h, pid)
            secs := AhkMagic._RemoteSections(h, mod["base"])
            bif := AhkMagic._RemoteTable(h, secs, mod["base"], "bif")
            mdfunc := AhkMagic._RemoteTable(h, secs, mod["base"], "mdfunc")
            biv := AhkMagic._RemoteTable(h, secs, mod["base"], "biv")
            internal := Map()
            try {
                loc := AhkMagic._RemoteLocateInternal(secs, mod["base"])
                textSec := AhkMagic._TextSection(secs)
                loc["text_rva"] := textSec["rva"]
                loc["text_size"] := textSec["size"]
                if biv["found"] and biv["entries"].Has("LineNumber") {
                    loc["curr_line_slot"] := AhkMagic._RemoteCurrLineSlot(
                        secs, mod["base"]
                        , biv["entries"]["LineNumber"]["getter_rva"])
                    internal := loc
                }
            } catch as e {
                internal := Map("error", e.What " | " e.Message)
            }
            return Map(
                "pid", pid,
                "module", mod["path"],
                "image_base", mod["base"],
                "builtins", bif,
                "native_functions", mdfunc,
                "builtin_vars", biv,
                "internal", internal
            )
        } finally {
            DllCall("CloseHandle", "Ptr", h)
        }
    }

    static AttachRemoteByName(name) {
        if !(name is String)
            throw TypeError("name must be a string", -1)
        pid := AhkMagic._RemotePidByName(name)
        return AhkMagic.AttachRemote(pid)
    }

    static RemoteRedirect(hook, name, newName) {
        if !(hook is Map) or !hook.Has("pid")
            throw TypeError("hook must be an AttachRemote result", -1)
        bif := hook["builtins"]
        if !bif["found"] or !bif["entries"].Has(name)
            or !bif["entries"].Has(newName)
            throw Error("builtin redirect names not found", -1)
        idx := 0
        for n in bif["names"] {
            if n = name
                break
            idx += 1
        }
        if idx >= bif["names"].Length
            throw Error("builtin index not found", -1)
        h := AhkMagic._RemoteOpen(hook["pid"], true)
        try {
            fnSlot := hook["image_base"] + bif["table_rva"]
                + idx * bif["stride"] + 8
            newPtr := hook["image_base"] + bif["entries"][newName]["rva"]
            data := Buffer(8)
            NumPut("Ptr", newPtr, data, 0)
            written := 0
            if !DllCall("WriteProcessMemory", "Ptr", h, "Ptr", fnSlot
                , "Ptr", data.Ptr, "UPtr", 8, "UPtr*", &written)
                throw Error("WriteProcessMemory failed", -1)
        } finally {
            DllCall("CloseHandle", "Ptr", h)
        }
        return Map("src", name, "dst", newName, "fn_slot", fnSlot)
    }

    static RemoteDeepRedirect(hook, name, newName) {
        if !(hook is Map) or !hook.Has("pid")
            throw TypeError("hook must be an AttachRemote result", -1)
        bif := hook["builtins"]
        if !bif["found"] or !bif["entries"].Has(name)
            or !bif["entries"].Has(newName)
            throw Error("builtin redirect names not found", -1)
        idx := 0
        for n in bif["names"] {
            if n = name
                break
            idx += 1
        }
        if idx >= bif["names"].Length
            throw Error("builtin index not found", -1)

        h := AhkMagic._RemoteOpen(hook["pid"], true)
        try {
            slot := hook["image_base"] + bif["table_rva"] + idx * bif["stride"]
            slotBuf := AhkMagic._RemoteRead(h, slot, 16)
            namePtr := NumGet(slotBuf, 0, "Ptr")
            oldFn := NumGet(slotBuf, 8, "Ptr")
            newFn := hook["image_base"] + bif["entries"][newName]["rva"]

            patches := []
            addr := 0
            mbi := Buffer(48)
            loop {
                if !DllCall("VirtualQueryEx", "Ptr", h, "Ptr", addr
                    , "Ptr", mbi.Ptr, "UPtr", 48)
                    break
                state := NumGet(mbi, 32, "UInt")
                protect := NumGet(mbi, 36, "UInt")
                memType := NumGet(mbi, 40, "UInt")
                regionSize := NumGet(mbi, 24, "Int64")
                baseAddr := NumGet(mbi, 0, "Ptr")
                if state = 0x1000 and memType = 0x20000
                    and (protect & 0x4 or protect & 0x40)
                    and regionSize > 0 and regionSize < 0x8000000 {
                    chunkSize := 0x10000
                    off := 0
                    while off < regionSize {
                        want := Min(chunkSize, regionSize - off)
                        try
                            data := AhkMagic._RemoteRead(h, baseAddr + off, want)
                        catch {
                            off += want
                            continue
                        }
                        maxOff := data.Size - 8
                        pos := 0
                        while pos <= maxOff {
                            if NumGet(data, pos, "Ptr") = oldFn {
                                ok := false
                                start := Max(0, pos - 0x200)
                                end := Min(data.Size - 8, pos + 0x200)
                                j := start
                                while j <= end {
                                    if NumGet(data, j, "Ptr") = namePtr {
                                        ok := true
                                        break
                                    }
                                    j += 8
                                }
                                if ok
                                    patches.Push(baseAddr + off + pos)
                            }
                            pos += 8
                        }
                        off += want
                    }
                }
                if regionSize <= 0
                    break
                nextAddr := baseAddr + regionSize
                if nextAddr <= addr
                    break
                addr := nextAddr
            }
            if !patches.Length
                throw Error("no Func object found for " name, -1)
            data := Buffer(8)
            NumPut("Ptr", newFn, data, 0)
            for p in patches
                AhkMagic._RemoteWrite(h, p, data)
            return Map("src", name, "dst", newName, "count", patches.Length)
        } finally {
            DllCall("CloseHandle", "Ptr", h)
        }
    }

    static RemoteEval(hook, expr) {
        if !(hook is Map) or !hook.Has("pid") or !hook.Has("internal")
            or !hook["internal"].Has("postfix_rva")
            throw Error("hook has no remote eval context", -1)
        if !(expr is String)
            throw TypeError("expr must be a string", -1)

        internal := hook["internal"]
        stub := AhkMagic._HexBuffer(MC_REMOTE_EVAL_STUB_X64)
        locator := AhkMagic._HexBuffer(MC_INTERNAL_LOCATOR_X64)
        evalBlob := AhkMagic._HexBuffer(MC_INPROC_EVAL_X64)
        codeSize := stub.Size + locator.Size + evalBlob.Size
        paramOff := (codeSize + 15) // 16 * 16
        locOff := paramOff + 136
        outOff := locOff + 64
        exprLen := (StrLen(expr) + 1) * 2
        exprOff := outOff + 512
        scratchOff := exprOff + exprLen
        total := scratchOff + 8 * 1024 * 1024

        h := AhkMagic._RemoteOpen(hook["pid"], true)
        try {
            block := DllCall("VirtualAllocEx", "Ptr", h, "Ptr", 0
                , "UPtr", total, "UInt", 0x3000, "UInt", 0x40, "Ptr")
            if !block
                throw Error("VirtualAllocEx failed", -1)
            try {
                AhkMagic._RemoteWrite(h, block, stub)
                AhkMagic._RemoteWrite(h, block + stub.Size, locator)
                AhkMagic._RemoteWrite(h, block + stub.Size + locator.Size, evalBlob)

                param := Buffer(136)
                NumPut("Ptr", block + stub.Size, param, 0)
                NumPut("Ptr", block + stub.Size + locator.Size, param, 8)
                NumPut("Ptr", hook["image_base"], param, 16)
                NumPut("UInt64", internal["text_rva"], param, 24)
                NumPut("UInt64", internal["text_size"], param, 32)
                NumPut("UInt64", internal["postfix_rva"], param, 40)
                NumPut("UInt64", internal["expand_rva"], param, 48)
                NumPut("Ptr", block + locOff, param, 56)
                NumPut("Ptr", hook["image_base"] + internal["postfix_rva"], param, 64)
                NumPut("Ptr", hook["image_base"] + internal["expand_rva"], param, 72)
                NumPut("Ptr", internal["curr_line_slot"], param, 80)
                NumPut("Ptr", block + scratchOff, param, 88)
                NumPut("Ptr", block + exprOff, param, 96)
                NumPut("Ptr", block + outOff, param, 104)
                NumPut("UInt64", 0, param, 112)
                NumPut("Int", 0, param, 120)
                NumPut("Int", 0, param, 124)
                AhkMagic._RemoteWrite(h, block + paramOff, param)

                exprBuf := Buffer(exprLen)
                StrPut(expr, exprBuf, "UTF-16")
                AhkMagic._RemoteWrite(h, block + exprOff, exprBuf)

                tid := 0
                thread := DllCall("CreateRemoteThread", "Ptr", h, "Ptr", 0
                    , "UPtr", 0, "Ptr", block, "Ptr", block + paramOff
                    , "UInt", 0, "UInt*", &tid, "Ptr")
                if !thread
                    throw Error("CreateRemoteThread failed", -1)
                try {
                    DllCall("WaitForSingleObject", "Ptr", thread, "UInt", 10000)
                    paramBack := AhkMagic._RemoteRead(h, block + paramOff, 136)
                    locRc := NumGet(paramBack, 120, "Int")
                    evalRc := NumGet(paramBack, 124, "Int")
                    if locRc != 0
                        throw Error("remote internal locator rc=" locRc, -1)
                    if evalRc != 0
                        throw Error("remote eval rc=" evalRc, -1)
                    out := AhkMagic._RemoteRead(h, block + outOff, 512)
                    status := NumGet(out, 0, "UInt")
                    type := NumGet(out, 4, "UInt")
                    if status != 0
                        throw Error("remote eval status=" status, -1)
                    if type = 1
                        return NumGet(out, 8, "Int64")
                    if type = 2
                        return NumGet(out, 8, "Double")
                    if type = 0 {
                        ptr := NumGet(out, 16, "Ptr")
                        return ptr ? AhkMagic._RemoteReadString(h, ptr) : ""
                    }
                    throw Error("remote eval returned unknown type " type, -1)
                } finally {
                    DllCall("CloseHandle", "Ptr", thread)
                }
            } finally {
                DllCall("VirtualFreeEx", "Ptr", h, "Ptr", block, "UPtr", 0
                    , "UInt", 0x8000)
            }
        } finally {
            DllCall("CloseHandle", "Ptr", h)
        }
    }

    static _RemoteCall(h, fnAddr, args) {
        stub := AhkMagic._HexBuffer(MC_REMOTE_CALL_STUB_X64)
        param := Buffer(72)
        NumPut("Ptr", fnAddr, param, 0)
        loop 6 {
            val := args.Has(A_Index) ? args[A_Index] : 0
            NumPut("Ptr", val, param, 8 + 8 * (A_Index - 1))
        }
        NumPut("Int", 0, param, 56)
        block := DllCall("VirtualAllocEx", "Ptr", h, "Ptr", 0
            , "UPtr", stub.Size + 72, "UInt", 0x3000, "UInt", 0x40, "Ptr")
        if !block
            throw Error("VirtualAllocEx failed", -1)
        try {
            AhkMagic._RemoteWrite(h, block, stub)
            AhkMagic._RemoteWrite(h, block + stub.Size, param)
            tid := 0
            thread := DllCall("CreateRemoteThread", "Ptr", h, "Ptr", 0
                , "UPtr", 0, "Ptr", block, "Ptr", block + stub.Size
                , "UInt", 0, "UInt*", &tid, "Ptr")
            if !thread
                throw Error("CreateRemoteThread failed", -1)
            try {
                DllCall("WaitForSingleObject", "Ptr", thread, "UInt", 10000)
                back := AhkMagic._RemoteRead(h, block + stub.Size, 72)
                return NumGet(back, 56, "Int")
            } finally {
                DllCall("CloseHandle", "Ptr", thread)
            }
        } finally {
            DllCall("VirtualFreeEx", "Ptr", h, "Ptr", block, "UPtr", 0
                , "UInt", 0x8000)
        }
    }

    static _RemoteInternalLocator(h, secs, base, postfixRva, expandRva) {
        text := AhkMagic._TextSection(secs)
        locator := AhkMagic._HexBuffer(MC_INTERNAL_LOCATOR_X64)
        block := DllCall("VirtualAllocEx", "Ptr", h, "Ptr", 0
            , "UPtr", locator.Size + 64, "UInt", 0x3000, "UInt", 0x40, "Ptr")
        if !block
            throw Error("VirtualAllocEx failed", -1)
        try {
            AhkMagic._RemoteWrite(h, block, locator)
            locOut := block + locator.Size
            rc := AhkMagic._RemoteCall(h, block
                , [base, text["rva"], text["size"], postfixRva, expandRva, locOut])
            if rc != 0
                throw Error("remote internal locator rc=" rc, -1)
            return AhkMagic._RemoteRead(h, locOut, 64)
        } finally {
            DllCall("VirtualFreeEx", "Ptr", h, "Ptr", block, "UPtr", 0
                , "UInt", 0x8000)
        }
    }

    static _RemoteLoadScript(h, base, loc, text) {
        memScript := AhkMagic._HexBuffer(MC_MEM_SCRIPT_X64)
        textLen := (StrLen(text) + 1) * 2
        scratchSize := 0x400
        block := DllCall("VirtualAllocEx", "Ptr", h, "Ptr", 0
            , "UPtr", memScript.Size + textLen + scratchSize
            , "UInt", 0x3000, "UInt", 0x40, "Ptr")
        if !block
            throw Error("VirtualAllocEx failed", -1)
        try {
            AhkMagic._RemoteWrite(h, block, memScript)
            textAddr := block + memScript.Size
            scratchAddr := textAddr + textLen
            textBuf := Buffer(textLen)
            StrPut(text, textBuf, "UTF-16")
            AhkMagic._RemoteWrite(h, textAddr, textBuf)
            gscript := NumGet(loc["loc_out"], 0, "Ptr")
            loadTs := base + loc["load_ts_rva"]
            srcCount := loc.Has("src_count_rva") and loc["src_count_rva"]
                ? base + loc["src_count_rva"] : 0
            return AhkMagic._RemoteCall(h, block
                , [loadTs, gscript, srcCount, textAddr, StrLen(text) * 2
                    , scratchAddr])
        } finally {
            DllCall("VirtualFreeEx", "Ptr", h, "Ptr", block, "UPtr", 0
                , "UInt", 0x8000)
        }
    }

    static _RemoteCurrOff(secs, preparseRva) {
        text := AhkMagic._TextSection(secs)
        callers := AhkMagic._FindCallers(text, preparseRva)
        for caller in callers {
            p := text["ptr"]
            base := text["rva"]
            off := AhkMagic._FnStart(text, caller) - base
            limit := Min(text["size"] - 16, off + 0x4000)
            i := off
            while i < limit {
                if NumGet(p + i, "UChar") = 0xCC
                    and NumGet(p + i + 1, "UChar") = 0xCC
                    break
                if NumGet(p + i, "UChar") = 0x48
                    and NumGet(p + i + 1, "UChar") = 0x8B
                    and NumGet(p + i + 2, "UChar") = 0x05 {
                    j := i + 7
                    while j < Min(i + 24, limit) {
                        if NumGet(p + j, "UChar") = 0x48
                            and NumGet(p + j + 1, "UChar") = 0x89
                            and (NumGet(p + j + 2, "UChar") = 0x58
                            or NumGet(p + j + 2, "UChar") = 0x50)
                            return NumGet(p + j + 3, "UChar")
                        j += 1
                    }
                }
                i += 1
            }
        }
        return 0
    }

    static _RemoteParserOffsets(text, loadTsRva) {
        p := text["ptr"]
        base := text["rva"]
        off := loadTsRva - base
        limit := Min(text["size"] - 8, off + 0x100)
        qCmp := -1
        dCmp := -1
        i := off
        while i < limit {
            b0 := NumGet(p + i, "UChar")
            if b0 = 0x48 and NumGet(p + i + 1, "UChar") = 0x83 {
                modrm := NumGet(p + i + 2, "UChar")
                if modrm = 0x79 and NumGet(p + i + 4, "UChar") = 0
                    and qCmp < 0
                    qCmp := NumGet(p + i + 3, "UChar")
                else if modrm = 0xB9 and NumGet(p + i + 7, "UChar") = 0
                    and qCmp < 0
                    qCmp := NumGet(p + i + 3, "Int")
            }
            if b0 = 0x83 and NumGet(p + i + 1, "UChar") = 0xB9
                and (i = off or NumGet(p + i - 1, "UChar") != 0x48)
                and NumGet(p + i + 6, "UChar") = 0
                and dCmp < 0
                dCmp := NumGet(p + i + 2, "Int")
            if qCmp >= 0 and dCmp >= 0
                break
            i += 1
        }
        if qCmp < 0 or dCmp < 0
            throw Error("parser state anchors not found", -1)
        if dCmp > 0x100
            return Map(
                "mclass_count", dCmp,
                "mline_parent", dCmp - 0x30,
                "mpending_related", dCmp - 0x28,
                "mlast_param_init", dCmp - 0x20,
                "mpending_hotkey", dCmp - 0x18,
                "mexpr_func", dCmp - 0x10,
                "mexpr_func_index", dCmp - 8,
                "mnext_func_body", dCmp - 4,
                "mignore_block", dCmp - 3,
                "mbackcompat", dCmp - 2,
                "mcurrent_module", dCmp - 0x50,
                "mlast_module", dCmp - 0x48)
        return Map(
            "mopen", qCmp,
            "mpending_parent", qCmp + 8,
            "mpending_related", qCmp + 16,
            "mlast_param_init", qCmp + 24,
            "mnext_func_body", qCmp + 32,
            "mclass_count", dCmp)
    }

    static _RemoteLocateEvalScript(secs, base) {
        text := AhkMagic._TextSection(secs)
        postfixRefs := AhkMagic._RipRefs(text
            , AhkMagic._FindUtf16(secs, "Missing operand.")[1])
        postfixRva := AhkMagic._BestStart(text, postfixRefs)
        expandRefs := AhkMagic._RipRefs(text
            , AhkMagic._FindUtf16(secs, "Error evaluating expression.")[1])
        expandRva := AhkMagic._BestStart(text, expandRefs)
        if !postfixRva or !expandRva
            throw Error("remote expression functions not found", -1)
        preparse := 0
        for caller in AhkMagic._FindCallers(text, postfixRva) {
            start := AhkMagic._FnStart(text, caller)
            if AhkMagic._FindBytePatternInFunc(text, start, "803B03")
                and AhkMagic._FindBytePatternInFunc(text, start, "803B04") {
                preparse := start
                break
            }
        }
        if !preparse
            throw Error("PreparseExpressions not found", -1)
        preprocess := AhkMagic._LocatePreprocessFunc(text)
        if !preprocess
            throw Error("PreprocessLocalVars not found", -1)
        open := AhkMagic._FindBytePattern(text
            , "48895C240848895424105556574154415541564157488DAC243000FEFFB8D0000200")
        if !open
            open := AhkMagic._FindBytePattern(text
                , "40535556574154415541564157B8D8000100")
        if !open
            throw Error("OpenIncludedFile not found", -1)
        loadTs := AhkMagic._LocateLoadTs(text, open)
        if !loadTs
            throw Error("LoadIncludedFile(TextStream) not found", -1)
        gptr := AhkMagic._LocateGptr(text, preparse)
        if !gptr
            throw Error("g pointer not found", -1)
        currOff := AhkMagic._RemoteCurrOff(secs, preparse)
        if !currOff
            throw Error("g->curr offset not found", -1)
        parser := AhkMagic._RemoteParserOffsets(text, loadTs)
        return Map(
            "postfix_rva", postfixRva,
            "expand_rva", expandRva,
            "preparse_rva", preparse,
            "preprocess_rva", preprocess,
            "open_rva", open,
            "load_ts_rva", loadTs,
            "src_count_rva", 0,
            "gptr_rva", gptr,
            "curr_off", currOff,
            "parser", parser)
    }

    static _RemoteDiscoverLayout(h, secs, base, loc) {
        locOut := AhkMagic._RemoteInternalLocator(h, secs, base
            , loc["postfix_rva"], loc["expand_rva"])
        loc["loc_out"] := locOut
        gscript := NumGet(locOut, 0, "Ptr")
        gAddr := base + loc["gptr_rva"]
        g := NumGet(AhkMagic._RemoteRead(h, gAddr, 8), 0, "Ptr")
        currOff := loc["curr_off"]
        snap := AhkMagic._RemoteRead(h, gscript, 0x200)
        gsnap := AhkMagic._RemoteRead(h, g, 0x100)
        savedCur := NumGet(AhkMagic._RemoteRead(h, g + currOff, 8), 0, "Ptr")
        zeroBuf := Buffer(0x100, 0)
        AhkMagic._RemoteWrite(h, g, zeroBuf)
        curBuf := Buffer(8)
        NumPut("Ptr", 0, curBuf, 0)
        AhkMagic._RemoteWrite(h, g + currOff, curBuf)
        parser := loc["parser"]
        for key in ["mopen", "mpending_parent", "mline_parent"
            , "mpending_related", "mlast_param_init", "mpending_hotkey"
            , "mexpr_func"]
            if parser.Has(key)
                AhkMagic._WPtr(h, gscript + parser[key], 0)
        if parser.Has("mexpr_func_index")
            AhkMagic._WInt(h, gscript + parser["mexpr_func_index"], 0x7fffffff)
        if parser.Has("mnext_func_body")
            AhkMagic._WByte(h, gscript + parser["mnext_func_body"], 0)
        if parser.Has("mignore_block")
            AhkMagic._WByte(h, gscript + parser["mignore_block"], 0)
        if parser.Has("mbackcompat")
            AhkMagic._WByte(h, gscript + parser["mbackcompat"], 1)
        if parser.Has("mclass_count")
            AhkMagic._WInt(h, gscript + parser["mclass_count"], 0)
        probe := "
        (
        ahkHackLayoutProbe() {
            return 1
        }
        )"
        rc := AhkMagic._RemoteLoadScript(h, base, loc, probe)
        if rc != 0
            throw Error("layout probe load rc=" rc, -1)
        after := AhkMagic._RemoteRead(h, gscript, 0x200)
        countOff := 0
        loop 0x200 // 4 {
            off := (A_Index - 1) * 4
            before := NumGet(snap, off, "Int")
            afterVal := NumGet(after, off, "Int")
            if afterVal = before + 1 and before >= 0 and afterVal < 100000 {
                countOff := off
                break
            }
        }
        if !countOff
            throw Error("mFuncsCount offset not found", -1)
        oldCount := NumGet(snap, countOff, "Int")
        lastOff := -1
        loop 0x200 // 8 {
            off := (A_Index - 1) * 8
            before := NumGet(snap, off, "Ptr")
            afterVal := NumGet(after, off, "Ptr")
            if before != afterVal and afterVal > 0x10000 {
                lastOff := off
                break
            }
        }
        if lastOff < 0
            throw Error("mLastLine offset not found", -1)
        oldLast := NumGet(snap, lastOff, "Ptr")
        newLast := NumGet(after, lastOff, "Ptr")
        lineSet := Map()
        line := oldLast ? NumGet(AhkMagic._RemoteRead(h, oldLast + 32, 8)
            , 0, "Ptr") : 0
        loop 10000 {
            if !line
                break
            lineSet[line] := true
            if line = newLast
                break
            line := NumGet(AhkMagic._RemoteRead(h, line + 32, 8), 0, "Ptr")
        }
        funcsOff := 0
        jumpOff := 0
        loop 0x200 // 8 {
            off := (A_Index - 1) * 8
            p := NumGet(after, off, "Ptr")
            if p <= 0x10000 or p >= 0x7fffffffffff
                continue
            try {
                newFunc := NumGet(AhkMagic._RemoteRead(h, p + oldCount * 8, 8)
                    , 0, "Ptr")
            } catch
                continue
            if newFunc <= 0x10000 or newFunc >= 0x7fffffffffff
                continue
            loop 0x100 // 8 {
                joff := (A_Index - 1) * 8
                try {
                    q := NumGet(AhkMagic._RemoteRead(h, newFunc + joff, 8)
                        , 0, "Ptr")
                } catch
                    continue
                if q > 0x10000 and lineSet.Has(q) {
                    funcsOff := off
                    jumpOff := joff
                    break
                }
            }
            if funcsOff
                break
        }
        if !funcsOff or !jumpOff
            throw Error("mFuncs/mJumpLine offset not found", -1)
        AhkMagic._RemoteWrite(h, gscript, snap)
        AhkMagic._RemoteWrite(h, g, gsnap)
        savedBuf := Buffer(8)
        NumPut("Ptr", savedCur, savedBuf, 0)
        AhkMagic._RemoteWrite(h, g + currOff, savedBuf)
        return Map(
            "gscript", gscript,
            "g", g,
            "curr_off", currOff,
            "mfuncs_off", funcsOff,
            "mfuncs_count_off", countOff,
            "mlast_line_off", lastOff,
            "mjump_line_off", jumpOff,
            "parser", loc["parser"])
    }

    static _RPtr(h, addr) {
        return NumGet(AhkMagic._RemoteRead(h, addr, 8), 0, "Ptr")
    }

    static _RInt(h, addr) {
        return NumGet(AhkMagic._RemoteRead(h, addr, 4), 0, "Int")
    }

    static _WPtr(h, addr, val) {
        buf := Buffer(8)
        NumPut("Ptr", val, buf, 0)
        AhkMagic._RemoteWrite(h, addr, buf)
    }

    static _WInt(h, addr, val) {
        buf := Buffer(4)
        NumPut("Int", val, buf, 0)
        AhkMagic._RemoteWrite(h, addr, buf)
    }

    static _WByte(h, addr, val) {
        buf := Buffer(1)
        NumPut("UChar", val, buf, 0)
        AhkMagic._RemoteWrite(h, addr, buf)
    }

    static RemoteEvalScript(hook, text) {
        if !(hook is Map) or !hook.Has("pid")
            throw TypeError("hook must be an AttachRemote result", -1)
        if !(text is String) or Trim(text) = ""
            throw TypeError("text must be a non-empty string", -1)

        h := AhkMagic._RemoteOpen(hook["pid"], true)
        try {
            mod := AhkMagic._RemoteModuleBase(h, hook["pid"])
            secs := AhkMagic._RemoteSections(h, mod["base"])
            if hook.Has("script_loc") and hook.Has("script_layout") {
                loc := hook["script_loc"]
                layout := hook["script_layout"]
            } else {
                loc := AhkMagic._RemoteLocateEvalScript(secs, mod["base"])
                layout := AhkMagic._RemoteDiscoverLayout(h, secs, mod["base"], loc)
                hook["script_loc"] := loc
                hook["script_layout"] := layout
            }
            locOut := loc["loc_out"]
            gscript := layout["gscript"]
            g := layout["g"]
            currOff := layout["curr_off"]
            parser := layout["parser"]
            oldLast := AhkMagic._RPtr(h, gscript + layout["mlast_line_off"])
            oldFuncCount := AhkMagic._RInt(h, gscript + layout["mfuncs_count_off"])
            savedCur := AhkMagic._RPtr(h, g + currOff)
            savedCurFunc := AhkMagic._RPtr(h, g + 0x28)

            savedState := []
            for key in ["mopen", "mpending_parent", "mline_parent"
                , "mpending_related", "mlast_param_init", "mpending_hotkey"
                , "mexpr_func", "mcurrent_module"]
                if parser.Has(key)
                    savedState.Push([key, "Ptr"
                        , AhkMagic._RPtr(h, gscript + parser[key])])
            for key in ["mexpr_func_index", "mclass_count"]
                if parser.Has(key)
                    savedState.Push([key, "Int"
                        , AhkMagic._RInt(h, gscript + parser[key])])
            for key in ["mnext_func_body", "mignore_block", "mbackcompat"]
                if parser.Has(key)
                    savedState.Push([key, "UChar"
                        , NumGet(AhkMagic._RemoteRead(h, gscript + parser[key], 1)
                            , 0, "UChar")])

            try {
                for key in ["mopen", "mpending_parent", "mline_parent"
                    , "mpending_related", "mlast_param_init"
                    , "mpending_hotkey", "mexpr_func"]
                    if parser.Has(key)
                        AhkMagic._WPtr(h, gscript + parser[key], 0)
                if parser.Has("mexpr_func_index")
                    AhkMagic._WInt(h, gscript + parser["mexpr_func_index"]
                        , 0x7fffffff)
                if parser.Has("mnext_func_body")
                    AhkMagic._WByte(h, gscript + parser["mnext_func_body"], 0)
                if parser.Has("mignore_block")
                    AhkMagic._WByte(h, gscript + parser["mignore_block"], 0)
                if parser.Has("mbackcompat")
                    AhkMagic._WByte(h, gscript + parser["mbackcompat"], 1)
                if parser.Has("mclass_count")
                    AhkMagic._WInt(h, gscript + parser["mclass_count"], 0)
                AhkMagic._WPtr(h, g + currOff, 0)

                rc := AhkMagic._RemoteLoadScript(h, mod["base"], loc, text)
                if rc != 0
                    throw Error("LoadIncludedFile(memory) rc=" rc, -1)

                funcsItem := AhkMagic._RPtr(h, gscript + layout["mfuncs_off"])
                funcCount := AhkMagic._RInt(h, gscript + layout["mfuncs_count_off"])
                if funcCount > oldFuncCount {
                    firstNew := oldLast
                        ? AhkMagic._RPtr(h, oldLast + 32) : 0
                    if firstNew {
                        rc := AhkMagic._RemoteCall(h
                            , mod["base"] + loc["preparse_rva"]
                            , [gscript, firstNew])
                        if rc != 1
                            throw Error("PreparseExpressions(tail) rc=" rc, -1)
                    }
                    loop funcCount - oldFuncCount {
                        idx := oldFuncCount + A_Index - 1
                        newFunc := AhkMagic._RPtr(h, funcsItem + idx * 8)
                        jump := AhkMagic._RPtr(h
                            , newFunc + layout["mjump_line_off"])
                        if !jump
                            continue
                        AhkMagic._WPtr(h, g + 0x28, newFunc)
                        rc := AhkMagic._RemoteCall(h
                            , mod["base"] + loc["preparse_rva"]
                            , [gscript, jump])
                        if rc != 1
                            throw Error("PreparseExpressions rc=" rc, -1)
                        AhkMagic._WPtr(h, g + currOff, newFunc)
                        line := jump
                        while line {
                            lineData := AhkMagic._RemoteRead(h, line, 40)
                            action := NumGet(lineData, 0, "UChar")
                            attr := NumGet(lineData, 16, "Ptr")
                            argc := NumGet(lineData, 1, "UChar")
                            arg := NumGet(lineData, 8, "Ptr")
                            if action = 3 and attr
                                AhkMagic._WPtr(h, g + currOff, attr)
                            if argc and arg
                                and NumGet(AhkMagic._RemoteRead(h, arg + 1, 1)
                                    , 0, "UChar") {
                                postfix := AhkMagic._RPtr(h, arg + 24)
                                if postfix {
                                    loop {
                                        token := AhkMagic._RemoteRead(h
                                            , postfix, 24)
                                        symbol := NumGet(token, 16, "UInt")
                                        if symbol = NumGet(locOut, 32, "UInt")
                                            break
                                        if symbol = 4
                                            and NumGet(token, 8, "UInt") < 3 {
                                            deref := NumGet(token, 0, "Ptr")
                                            if deref {
                                                derefData := AhkMagic._RemoteRead(h
                                                    , deref, 24)
                                                derefType := NumGet(derefData
                                                    , 16, "UChar")
                                                marker := NumGet(derefData
                                                    , 0, "Ptr")
                                                derefLen := NumGet(derefData
                                                    , 20, "UInt")
                                                if derefType = 7 {
                                                    AhkMagic._WPtr(h, postfix
                                                        , AhkMagic._RPtr(h
                                                            , deref + 8))
                                                } else if derefType = 0
                                                    and marker
                                                    and derefLen > 0
                                                    and derefLen <= 64 {
                                                    var := AhkMagic._RemoteCall(h
                                                        , NumGet(locOut, 16, "Ptr")
                                                        , [gscript, marker
                                                            , derefLen, 0x103])
                                                    if var
                                                        AhkMagic._WPtr(h, postfix
                                                            , var)
                                                }
                                            }
                                        }
                                        postfix += 24
                                    }
                                }
                            }
                            line := AhkMagic._RPtr(h, line + 32)
                        }
                        AhkMagic._WPtr(h, g + currOff, savedCur)
                        rc := AhkMagic._RemoteCall(h
                            , mod["base"] + loc["preprocess_rva"]
                            , [gscript, newFunc])
                        if rc != 1
                            throw Error("PreprocessLocalVars rc=" rc, -1)
                        AhkMagic._WPtr(h, g + 0x28, savedCurFunc)
                    }
                }
                AhkMagic._WPtr(h, g + currOff, 0)

                last := ""
                for raw in StrSplit(text, "`n", "`r") {
                    t := Trim(raw)
                    if t = ""
                        continue
                    if RegExMatch(t
                        , "^(if|else|for|while|loop|try|catch|finally|return|break|continue|class|static|global|local|throw)\b")
                        continue
                    if SubStr(t, -1) = "{"
                        continue
                    last := t
                }
                if last = ""
                    throw ValueError("no expression result found in script text")
                return AhkMagic.RemoteEval(hook, last)
            } finally {
                for item in savedState {
                    if item[2] = "Ptr"
                        AhkMagic._WPtr(h, gscript + parser[item[1]], item[3])
                    else if item[2] = "Int"
                        AhkMagic._WInt(h, gscript + parser[item[1]], item[3])
                    else
                        AhkMagic._WByte(h, gscript + parser[item[1]], item[3])
                }
                AhkMagic._WPtr(h, g + 0x28, savedCurFunc)
                AhkMagic._WPtr(h, g + currOff, savedCur)
            }
        } finally {
            DllCall("CloseHandle", "Ptr", h)
        }
    }

    static RemoteReplaceFuncBody(hook, oldName, newName) {
        if !(hook is Map) or !hook.Has("pid")
            throw TypeError("hook must be an AttachRemote result", -1)
        h := AhkMagic._RemoteOpen(hook["pid"], true)
        try {
            mod := AhkMagic._RemoteModuleBase(h, hook["pid"])
            secs := AhkMagic._RemoteSections(h, mod["base"])
            if hook.Has("script_layout") {
                layout := hook["script_layout"]
            } else {
                loc := AhkMagic._RemoteLocateEvalScript(secs, mod["base"])
                layout := AhkMagic._RemoteDiscoverLayout(h, secs, mod["base"], loc)
                hook["script_layout"] := layout
            }
            oldList := AhkMagic._RemoteFindUserFuncs(h, layout, oldName)
            newPtr := AhkMagic._RemoteFindUserFunc(h, layout, newName)
            if !oldList.Length or !newPtr
                throw Error("function object not found: " oldName " / " newName, -1)
            jumpOff := layout["mjump_line_off"]
            newJump := AhkMagic._RPtr(h, newPtr + jumpOff)
            if !newJump
                throw Error("new function body not found", -1)
            patched := []
            for oldPtr in oldList {
                AhkMagic._WPtr(h, oldPtr + jumpOff, newJump)
                patched.Push(oldPtr)
            }
            return Map("old", oldList, "new", newPtr, "jump_off", jumpOff
                , "count", patched.Length)
        } finally {
            DllCall("CloseHandle", "Ptr", h)
        }
    }

    static _RemoteFindUserFunc(h, layout, name) {
        list := AhkMagic._RemoteFindUserFuncs(h, layout, name)
        return list.Length ? list[1] : 0
    }

    static _RemoteFindUserFuncs(h, layout, name) {
        gscript := layout["gscript"]
        arr := AhkMagic._RPtr(h, gscript + layout["mfuncs_off"])
        count := AhkMagic._RInt(h, gscript + layout["mfuncs_count_off"])
        result := []
        shortName := name
        dot := InStr(name, ".")
        fullName := ""
        if dot {
            shortName := SubStr(name, dot + 1)
            fullName := SubStr(name, 1, dot - 1)
                . ".Prototype." shortName
        }
        loop count {
            nf := AhkMagic._RPtr(h, arr + (A_Index - 1) * 8)
            candidates := [name, shortName]
            if fullName != ""
                candidates.Push(fullName)
            for want in candidates {
                data := AhkMagic._RemoteRead(h, nf, 0x500)
                found := false
                loop data.Size // 2 - StrLen(want) {
                    off := (A_Index - 1) * 2
                    ok := true
                    loop StrLen(want) {
                        if NumGet(data, off + (A_Index - 1) * 2, "UShort")
                            != Ord(SubStr(want, A_Index, 1)) {
                            ok := false
                            break
                        }
                    }
                    if ok and NumGet(data, off + StrLen(want) * 2, "UShort") = 0 {
                        found := true
                        break
                    }
                }
                if found
                    result.Push(nf)
            }
        }
        return result
    }

    static EvalSubprocess(expr) {
        AhkMagic.Init()
        if !(expr is String)
            throw TypeError("expr must be a string", -1)
        if expr = ""
            throw ValueError("expr must not be empty", -1)

        tag := Format("{:x}", A_TickCount) "-" Format("{:x}", Random(1, 0x7fffffff))
        scriptFile := A_Temp "\ahk_mcode_eval_" tag ".ahk"
        resultFile := A_Temp "\ahk_mcode_eval_" tag ".txt"

        quote := expr
        script := "try {`n"
            . "    result := (" quote ")`n"
            . "    FileAppend result, `"" resultFile "`", `"UTF-8`"`n"
            . "} catch as e {`n"
            . "    FileAppend `"ERROR: `" e.Message, `"" resultFile "`", `"UTF-8`"`n"
            . "    ExitApp 1`n"
            . "}`n"
        FileAppend script, scriptFile, "UTF-8"
        try {
            ; Compiled exes built from the regular v2 runtime can re-enter
            ; interpreter mode with /script; the SC build does not support it.
            cmd := A_IsCompiled
                ? Format('"{1}" /script /ErrorStdOut "{2}"', A_AhkPath, scriptFile)
                : Format('"{1}" /ErrorStdOut "{2}"', A_AhkPath, scriptFile)
            RunWait cmd, , "Hide"
            if !FileExist(resultFile)
                throw Error("eval child produced no result", -1)
            result := FileRead(resultFile, "UTF-8")
            if RegExMatch(result, "^ERROR: (.*)$", &m)
                throw Error("eval failed: " m[1], -1)
            return result
        } finally {
            if FileExist(scriptFile)
                FileDelete(scriptFile)
            if FileExist(resultFile)
                FileDelete(resultFile)
        }
    }
}

MC_INTERNAL_LOCATOR_X64 := "4157415641554154565755534881ec38030000488bb424a8030000c744242c000000004885c90f94c04885d2410f94c24108c24d85c0410f94c34508d34885f6410f94c2b8010000004508da0f854a0200004c8b9c24a00300004929d10f92c04929d3410f92c24108c2b8020000000f85270200004d8d9100000200b8030000004d39c20f8712020000498d41074c39d00f87000200004801ca4881c10000010031ff4c89c8eb180f1f840000000000488d58014883c0084c39d04889d8777c803c024875ea488d1c02807b018d75e0807b020d75da4c6373034c01f34883c3074839cb72ca4189ff4531f685ff74154a399cf430010000740b49ffc64d39f775ee4589fe4139fe400f95c583ff40410f93c44108ec75134a899cfc3001000042c744bc3000000000ffc74139fe73804489f3ff449c30e974ffffff85ff0f845301000089fb89d883e00383ff040f832202000031ff4531f631c94885c074384a8d1cf44881c3300100004e8d34b44983c6304531ffeb100f1f84000000000049ffc74c39f87410438b2cbe39cd76f04a8b3cfb89e9ebe84885ff0f84f6000000b8050000004981f8000100000f82e900000031c94889d3eb20660f1f4400004c8d71014881c10101000048ffc34c39c14c89f10f87c2000000803c0a4475e0807c0a018975d9807c0a024c75d2807c0a032475cb807c0a042075c441be04000000eb106666662e0f1f8400000000004983c60242807c33fc66752442807c33fd83751c42807c33fe3a751442807c33ff0074386666662e0f1f8400000000004981fe000100000f8473ffffff42807c33fd6675bb42807c33fe8375b342807c33ff3a75ab42803c330075a44c8d72ff4885c97418410fb6040e3dc3000000740e3dcc000000740748ffc975e831c94801d14531ffeb2eb8040000004881c4380300005b5d5f5e415c415d415e415fc3498d5f014983c706b8080000004d39c74989df77d742803c3ae875e44a8d043a486358014801d84883c0054839c875d04d85ff740f4c89fb41803c1ecc740748ffcb75f431db488d83000100004c39c077ae4801d3b804000000eb044883c002807c03fc667515807c03fd83750e807c03fe3a7507807c03ff007427483d000100000f8478ffffff807c03fd6675cd807c03fe8375c6807c03ff3a75bf803c030075b94d39d34d0f42d3498d41104c39d00f866d0100004531f6488d4a064531ffe99100000083e3fc31ff4531f631c9eb1b66666666662e0f1f8400000000004983c6044c39f30f84befdffff428b6cb43039cd760a4a8bbcf43001000089e9428b6cb43439cd760a4a8bbcf43801000089e9428b6cb43839cd760a4a8bbcf44001000089e9428b6cb43c39cd76b14a8bbcf44801000089e9eba54d8d5f014983c70648ffc1b8060000004d39c74d89df0f8795feffff42803c3ae875dd4a8d043a4c6360014c01e04829d04883c0054c39c875c64d8d5f05498d470a4c39c0400f97c5498d47654939c3410f93c34108eb75a741bb050000004d29e34531e442807c21ffe8750d4e632c214b8d2c234c01ed75264f8d2c274983c5064939c50f8375ffffff4f8d2c274983c50b49ffc44d39c576cae960ffffff4c8d4c242c4889d54889d14c89c24d89d0e80f01000085c00f84f90000004c01ed4c01fd498d042c4883c00a48893e4c89760848895e10488946188b44242c89462031c0e9c8fdffff4d89ceeb14498d46014983c6114d39d64989c60f877afeffff42803c324875e542807c32018975dd42807c32025475d542807c32032475cd42807c32041075c542807c32055575bd42807c32065675b542807c32075775ad42807c32084175a542807c320954759d42807c320a41759542807c320b55758d42807c320c41758542807c320d560f8579ffffff42807c320e410f856dffffff4983fe020f8263ffffff42807c320f570f8557ffffff42807c32ffcc0f854bffffff42807c32fecc0f853fffffff4901d6e9c8fdffffb807000000e9f0fcffff0f1f4000498d80000800004839d0480f42d04983c00431c0eb0d662e0f1f84000000000049ffc04939d0772842807c01fc8375f042807c01fe1075e8460fb65401ff458d5ace4180fb3277d8458911b801000000c3"
MC_MEM_SCRIPT_X64 := "5657534883ec204c89c64989ca488b4c24684d85d20f94c04885d2410f94c04108c04d85c9410f94c34508c34885c9410f94c0b8010000004508d80f85c80100008b4424600f57c00f11010f1141100f1141200f1141300f1141400f1141500f1141600f1141700f1181800000000f1181900000000f1181a00000000f1181b00000000f1181c00000000f1181d00000000f1181e00000000f1181f00000004c8d81000100000f1181000100000f1181100100000f1181200100000f1181400100000f1181500100000f1181600100000f1181700100000f1181800100000f1181900100000f1181a00100000f1181b00100000f1181c00100000f1181d00100000f1181e00100000f1181f00100004c8d1d0a0100004c89194c8d1d300100004c8959084c8d1d350100004c8959104c8d1d5a0100004c8959184c8d1d9f0200004c8959204c8d1da40200004c8959284c8d1da90200004c8959304c8d1dae0200004c8959384889890001000048c781080100000c00000049bb00000000b00400004c899910010000c781180100000200000066c7812c01000000000f1181300100004c898940010000898148010000c6814c010000004c898950010000898158010000c6815c010000004c8989600100004885f674048b3eeb0231ff4885f60f94c34889d14c89c24189f841ffd289c131c083f9010f95c108cb740688c801c0eb06ffc7893e31c04883c4205b5f5ec36666666666662e0f1f84000000000048c7414000000000c7414800000000c6414c0048c7415000000000c7415800000000c6415c0048c7416000000000c390b001c3666666662e0f1f84000000000048c7414000000000c7414800000000c6414c0048c7415000000000c7415800000000c6415c0048c7416000000000c390565753488b41404c8b51504c8b4960448b59484c29d04c01d84589c34c39d8410f43c085c074214189c083f808410f92c34889d64c29d64883fe200f92c34408db740d4531dbeb7e4531c0e9e300000083f82073054531dbeb424589c34183e3e031f6666666662e0f1f840000000000410f100432410f104c32100f1104320f114c32104883c6204939f375e34539c30f849d00000041f6c018742a4c89de4589c34183e3f8662e0f1f840000000000498b3c3248893c324883c6084939f375ef4539c3746d4c89c74c89de4883e703741e4c89de66662e0f1f840000000000410fb61c32881c3248ffc648ffcf75f04d29c34983fbfc773a0f1f8000000000450fb61c3244881c32450fb65c320144885c3201450fb65c320244885c3202450fb65c320344885c32034883c6044939f075cd4d01c24c8951504d01c14c8949605b5f5ec366662e0f1f84000000000031c0c3666666662e0f1f84000000000031c0c3666666662e0f1f840000000000488b4150482b4140c30f1f80000000008b4148c3"
MC_INPROC_EVAL_X64 := "4157415641554154565755534881ec980000004c89cf4c89c34989cf4c8ba42408010000488b8c240001000048c78424800000000000400048c7442468000000004d85ff0f94c04885d2410f94c04108c04885db0f94c04d85c9410f94c14108c14508c14885c90f94c04408c84d85e4410f94c04883bc242801000000410f94c14508c14108c14883bc243801000000410f94c04883bc244001000000410f94c2b8010000004508c24508ca41f6c2010f851b060000488b8424200100004c8bac24180100004c8d87000100004885c04889c6490f44f04c8db7800100004c8d8f000300004c894c24704c898c24900000004d85ed4c0f44ef756e0f57c00f11070f1147100f1147200f1147300f1147400f1147500f1147600f1147700f1187800000000f1187900000000f1187a00000000f1187b00000000f1187c00000000f1187d00000000f1187e00000000f1187f0000000c6070341c645010141c7450401000000498975080f57c0410f1106410f114610410f114620410f114630410f114640410f114650410f114660410f1146706683390074164531c90f1f40006642837c4902004d8d490175f3eb034531c94885c04c897c24600f85fe010000488d870008100048894424500f57c0410f1100410f114010410f114020410f114030410f114040410f114050410f114060410f11407041c60000c646010144894e0448894e0849b800010000000100004c8946204531c04989cb4d89d9eb0c904983c1044084ed4d0f45cb450fb7114183fa22744b4183fa2774454585d20f8457010000418d429f6683f81a0f828e000000664183fa5f0f8483000000418d42a56683f8e57779410fb7c23d80000000736e4983c102ebb30f1f8400000000004d8d5902450fb77902664585ff400f94c5664539d70f94c04008e875830f1f00664183ff60750f66418379040074074983c1044d89cb4d89d94983c302450fb77902664585ff400f94c50f8450ffffff664539d775cae945ffffff0f1f44000031ed4d89cbeb14660f1f840000000000450fb753024983c302ffc5418d429f6683f81a72eb418d42bf6683f81a0f92c0664183fa5f410f94c74108c775d2410fb7c23d800000000f92c04183c2c6664183faf6410f92c24484d074b44939c9741f4181f8ff0000000f92c066418379fe2e410f95c24184c20f84bcfeffffeb0d4181f8fe0000000f87adfeffff4489c0488d04404c8b5424504d890cc249c744c208000000006641c744c210000041896cc21441ffc0e97ffeffff4585c04c8b7c2460741941c1e003438d0440488b4c245048c704010000000048894e10488954247849c70424010000000f57c0410f11442408488b0348894424504c892b4c8d4424684c89e94889f241ffd789c5488b4c24684885c97407ff94244001000083fd0175214883bc2410010000000f84e8010000488bac24480100004c8b7e18418b4710eb32488b44245048890341c7042402000000e994020000488b400849890766666666662e0f1f840000000000418b47284983c71839e8745083f80475ef41837f080277e8498b074885c074e08078100774c5448b4014488b10488b8c242801000041b903010000ff9424380100004885c075a8488b44245048890341c7042405000000e923020000488b8424300100004885c00f94c1483b4424600f94c208ca75114c89e94889f2ffd083f8010f854d010000488b4424704889842488000000c78790010000ffffffff48c78788010000ffffffff4889879801000048c787a001000000000000488d8700033f004889442438488d8424800000004889442430488d8424900000004889442428488d842488000000488944242048c744244000003f004c8d44245c4c89e931d24d89f1ff542478488b4c245048890b4885c00f84ae00000041c70424000000008b8f9001000041894c2404488b8f8001000049894c240849894c2410498d4c24204889ca4c29f24883fa0f0f8797000000ba05000000660f1f840000000000450fb64416fb44884411fb450fb64416fc44884411fc450fb64416fd44884411fd450fb64416fe44884411fe450fb64416ff44884411ff450fb60416448804114883c2064883fa3575b6eb56488b44245048890348b8000000006300000049890424e9b800000041c7042403000000e9ab000000488b44245048890341c7042406000000e996000000410f10060f1101410f1046100f114110410f1046200f114120418b4c240483f9050f8785000000ba270000000fa3ca737b488b461849894424504885c0744b31c0660f1f440000488b4e180fb60c0141884c0458488b4e180fb64c010141884c0459488b4e180fb64c010241884c045a488b4e180fb64c010341884c045b4883c004483d2001000075bd8b44245c41898424c800000031c04881c4980000005b5d5f5e415c415d415e415fc341c7442404000000004989442410e972ffffff"
