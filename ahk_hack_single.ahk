; ahk-hack standalone core.
;
; One-file AutoHotkey v2 scanner for AutoHotkey executables.  Copy this file
; anywhere and #Include it, or run ahk_hack_demo.ahk for a self-test.
; The x64 blob below is generated from lib/mcode/scanner.c by
; tools/build_mcode.py; it locates g_BIF, sMdFunc and g_BIV_A inside the
; running interpreter and copies entry metadata into a caller buffer.
MC_PE_EXPORT_SCANNER_X64 := "4157415641545657534885c90f94c04885d2410f94c04108c0b8010000000f85fb0000006681394d5a0f85f0000000448b413c41813c08504500000f85de0000006641817c08180b020f85d0000000418b8408880000004885c00f84ab0000004183bc088c000000000f849c0000004c8d0408448b4c08108b7c0818448b540820448b5c08248b74081c4c890248c7421000000000b80800000085ff747881ff0010000041b800100000440f42c74801ce4901ca4901cb4a8d3cc500000000488d3c7f31db66662e0f1f840000000000458b32450fb73b468b24be4901ce4c89741a184c89641a204501cf44897c1a28c7441a2c000000004983c2044983c3024883c3184839df75c7eb0e0f57c00f1102b8100000004531c04c89040231c05b5f5e415c415e415fc3"
MC_BIF_SCANNER_X64 := "415741565657534881ecb00100004885c90f94c04885d2410f94c04108c0be010000000f850b0500006681394d5a0f85000500008b413c813c08504500000f85f004000066817c08180b020f85e3040000440fb74c0806664183f91041b810000000450f42c1664585c90f841d010000440fb74c0814410fb7f84801c84c01c84c8d442442448d0cfd000000004f8d0c894531d26666662e0f1f840000000000468b5c10204585db460f445c1028428b5c10244801cb498958ee4c01db498958f642807c10182e7537460fb65c10194180fb74753b42807c101a65756242807c101b78755a42807c101c74410f94c3eb516666666666662e0f1f8400000000006641c740fe0000eb440f1f800000000041c640fe004180fb72754b42807c101a64752342807c101b61751b42807c101c74751342807c101d61410f94c3eb0a4531db458858fe4531db458858ff4531db4588184983c2284983c0184d39d10f853cffffffeb2941c640ff004180fb6475dc42807c101a6175d442807c101b7475cc42807c101c61410f94c3ebc331ff488d420848894424284989d74889542420488d4c243041b92000000089fa4531c0e89b03000085c00f84770300004d8d7720498d47184c897424284889442420488d4c2430be0100000041b92800000089fa41b801000000e86403000085c00f8440030000498d5f38498d473048895c24284889442420488d4c243041b91800000089fa41b802000000e83203000085c00f840e0300004c89f849c747102000000049c747282800000049c747401800000049c7474800000000418b570885d27e65ffca4881faff010000b9ff010000480f42ca488b10c1e1054883c1204531c04e8b0c024e894c00504e8b4c02084e894c0058460fb64c021046894c0060460fb64c021146894c0064460fb64c021246894c006842c744006c000000004983c0204c39c175ba418b0e85c90f8ea5010000ffc94881f9ff010000baff010000480f42d1488b4818488d1492488d14d5280000004531c0662e0f1f8400000000004e8b0c014e898c00504000004e8b4c01084e898c0058400000460fb64c011046888c0060400000460fb64c011146888c0061400000460fb64c011246888c0062400000460fb64c011346888c0063400000460fb64c011446888c0064400000460fb64c011546888c0065400000460fb64c011646888c0066400000460fb64c011746888c0067400000460fb64c011846888c0068400000460fb64c011946888c0069400000460fb64c011a46888c006a400000460fb64c011b46888c006b400000460fb64c011c46888c006c400000460fb64c011d46888c006d400000460fb64c011e46888c006e400000460fb64c011f46888c006f400000460fb64c012046888c0070400000460fb64c012146888c0071400000460fb64c012246888c0072400000460fb64c012346888c0073400000460fb64c012446888c0074400000460fb64c012546888c0075400000460fb64c012646888c0076400000460fb64c012746888c00774000004983c0284c39c20f858afeffff448b034585c00f8e8c00000041ffc84181f8ff000000baff000000410f42d0488b4830ffc231f64585c074704189d14181e1fe0100004531d24531c04e8b1c114e899c10509000004e8b5c11084e899c10589000004e8b5c11104e899c10609000004e8b5c11184e899c10689000004e8b5c11204e899c10709000004e8b5c11284e899c10789000004983c0024983c2304d39c175a6eb0731f6eb324531c0f6c201742a48055090000049c1e0034b8d14404c8b04114c8904104c8b4411084c89441008488b4c111048894c101089f04881c4b00100005b5f5e415e415fc366662e0f1f8400000000004157415641554154565755534883ec3085d20f8e76040000488bac24a00000004c8b94249800000089d6488d04f500000000488d3c4031db48c74424200000000048c744242800000000eb100f1f400048ffc34839f30f8417040000488d145b488d04d1807cd1110075068078120074df4c8b384c8b7008498d47104c39f077cf4d8b27eb434c8b9424980000004c8b0c244c8b5c2408488b4424284939c3490f47c34889442428488b442420490f47c54889442420662e0f1f8400000000004983c5184d39f577874d89fd4c89e04983c7084d8b650831d2eb0e0f1f4400004883c2184839d774d7807c1111007507807c11120074e9483944110876e24839041177dc31d2662e0f1f840000000000440fb71c10664585db74254183c381664183fba1729a4c8d5a024883fa7e4c89da75ddeb8b66662e0f1f84000000000031d2eb196666662e0f1f8400000000004883c2184839d70f8463ffffff807c11100074ec4c3964110876e54c39241177df0fb7104183f8010f840f0200004585c00f857d0200006683fa410f852fffffff66837802620f8524ffffffba0600000066837804730f8514ffffff66833c02000f8509ffffff4b8d04294883c01041bb010000004c39f00f87c9feffff4b8d14294c89e84c890c244c895c240848894424184889d04c8b124c8b5a084531c9eb1b66666666662e0f1f8400000000004983c1184c39cf0f8479feffff42807c091100750842807c09120074e34e3954090876dc4e39140977d631d20f1f4000450fb70c12664585c974214183c181664183f9a10f823cfeffff4c8d4a024883fa7e4c89ca75d9e92afeffff31d2eb0d4883c2184839d70f8419feffff807c11100074ec4c395c110876e54c391c1177df4183f802488944241075406641833a590f85bf0000006641837a02590f85b30000006641837a04590f85a70000006641837a06590f859b0000006641837a08000f858f000000e98e010000488b542418488b1248895424184531db488b542418460fb70c1a430fb7141a664585c974476685d274428d42bf8d6a203c1a400fb6c50f43c2418d51bf418d692080fa1a400fb6d5410f43d138c275274983c3024981fb80000000488bac24a0000000488b44241075a6eb1e664139d17618e943fdffff488bac24a0000000488b4424100f8330fdffff4c8b5c240849ffc34c8b0c244a8d1408488b4424104c01c84883c0104c39f0488b4424104c8b9424980000000f8651feffffe90afdffff6683fa420f8529fdffff668378026c0f851efdffff668378046f0f8513fdffff66837806630f8508fdffff668378086b0f85fdfcffff6683780a490f85f2fcffff6683780c6e0f85e7fcffff6683780e700f85dcfcffff66837810750f85d1fcffffba1400000066837812740f85c1fcffffe9a8fdffff6683fa410f85b2fcffff66837802680f85a7fcffff668378046b0f859cfcffff66837806500f8591fcffff66837808610f8586fcffff6683780a740f857bfcffffba0e0000006683780c680f856bfcffffe952fdffff4c8b5c240849ffc34c8b9424980000004c8b0c24e924fcffff4c8b4424204d85c00f94c0488b5424284883fa0a0f92c108c1740431c0eb0c4d890248895500b8010000004883c4305b5d5f5e415c415d415e415fc3"


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
    static internalLocator := 0
    static internalLocated := false
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

    static _FindUtf16(secs, text) {
        len := StrLen(text)
        needle := Buffer(2 * (len + 1), 0)
        StrPut(text, needle, "UTF-16")
        hits := []
        for name, sec in secs {
            if name != ".rdata"
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
        text := secs[".text"]

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
        text := secs[".text"]
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
            RunWait Format('"{1}" /ErrorStdOut "{2}"', A_AhkPath, scriptFile), , "Hide"
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

MC_INTERNAL_LOCATOR_X64 := "4157415641554154565755534881ec280300004885c90f94c04885d2410f94c24108c24d85c0410f94c34508d34883bc249803000000410f94c2b8010000004508da0f85f70200004c8bb424900300004c89cf4829d70f92c04929d6410f92c24108c2b8020000000f85d10200004c8d9f00000200b8030000004d39c30f87bc0200004c8d7f074d39df0f87aa020000488d340a488da90000010031db4989fc48897c241048896c2408eb29488b6c24086666666666662e0f1f840000000000498d4424014983c4084d39dc4989c40f878700000042803c264875e44e8d142641807a018d75d941807a020d75d249637a034d8d2c3a4983c5074939ed72c14189da31ed85db741d0f1f8400000000004c39acec20010000740b48ffc54939ea75ee4489d539dd400f95c783fb400f93c04008f875134e89acd42001000042c744942000000000ffc339dd0f835bffffff89e8ff448420e950ffffff85db0f84d60100004189dc4489e083e00383fb040f838902000031db4531ed31ff4885c074364e8d14ec4981c2200100004e8d24ac4983c4204531edeb0e660f1f44000049ffc54c39e87410438b2cac39fd76f04b8b1cea89efebe84885db0f84790100004901f14929c94801d24929d1498d14314883c20c488b7c24104989f9eb2090498d49014983c10848ffc2b8050000004d89cf4d39d94989c90f874001000042803c0e4875da4a8d040e8078018d75d08078020d75ca486348034801c84883c0074839d875ba498d47054c39d80f97c1498d41174939c7410f93c24108ca75a04989d442803c3ee875224a8d0c3e4c6369014a8d2c294883c5054889e94829f14881c1000100004c39c17621498d4f014839c10f8367ffffff4983c70649ffc44d39df4989cf76bbe953ffffff4d01e54531d2eb0f66662e0f1f8400000000004983c20243807c150066752443807c150183751c43807c15023a751443807c15030074356666662e0f1f8400000000004981fafc000000749343807c15016675bf43807c15028375b743807c15033a75af43807c15040075a74d39de4d0f42de488d47104c39d80f866601000031d2b8060000004983f805722548896c241849c7c1f6ffffff4929f141be0b00000041bf060000004531e4eb33b8040000004881c4280300005b5d5f5e415c415d415e415fc3498d4c24014983c40649ffc649ffc749ffc94d39c44989cc77d242803c26e875df4e8d142649634a014901ca4929f24983c2054c3b54241075c64d8d542405498d7c240a4c39c7400f97c7498d6c24654939ea410f93c24108fa75a441ba050000004929ca4c895424084a8d0c3e4531d242807c11ffe875154e632c11488b7c24084c01d74c01ef0f85460100004b8d3c174839ef0f8365ffffff4b8d3c1649ffc24c39c776cae954ffffff4183e4fc31db4531ed31ffeb110f1f40004983c5044d39ec0f8460fdffff468b54ac204139fa760b4a8b9cec200100004489d7468b54ac244139fa760b4a8b9cec280100004489d7468b54ac284139fa760b4a8b9cec300100004489d7468b54ac2c4139fa76aa4a8b9cec380100004489d7eb9d4889faeb14488d42014883c2114c39da4889c20f8781feffff803c164875e6807c16018975df807c16025475d8807c16032475d1807c16041075ca807c16055575c3807c16065675bc807c16075775b5807c16084175ae807c16095475a7807c160a4175a0807c160b557599807c160c417592807c160d56758b807c160e4175844883fa020f827affffff807c160f570f856fffffff807c16ffcc0f8564ffffff807c16fecc0f8559ffffff4801f2e9e8fdffff498d83000800004c39c04c0f42c04983c304b8070000004d39c30f87f8fdffff4d29cd4d01d54c8b942498030000488b7c2418eb0c49ffc34d39c30f87d7fdffff42807c1efc8375ec42807c1efe1075e4420fb64c1eff448d49ce4180f93373d449891a4989520849897a104d896a1841894a2031c0e99dfdffff"
MC_INPROC_EVAL_X64 := "4157415641554154565755534881ec980000004c89cf4c89c34989cb4c8ba42408010000488b8c240001000048c78424800000000000400048c7442468000000004d85db0f94c04885d2410f94c04108c04885db0f94c04d85c9410f94c14108c14508c14885c90f94c04408c84d85e4410f94c04883bc242801000000410f94c14508c14108c14883bc243801000000410f94c04883bc244001000000410f94c2b8010000004508c24508ca41f6c2010f85eb050000488b8424200100004c8bac24180100004c8d87000100004885c04889c6490f44f04c8db7800100004c8d8f000300004c894c24704c898c24900000004d85ed4c0f44ef756e0f57c00f11070f1147100f1147200f1147300f1147400f1147500f1147600f1147700f1187800000000f1187900000000f1187a00000000f1187b00000000f1187c00000000f1187d00000000f1187e00000000f1187f0000000c6070341c645010141c7450401000000498975080f57c0410f1106410f114610410f114620410f114630410f114640410f114650410f114660410f1146706683390074164531c90f1f40006642837c4902004d8d490175f3eb034531c94885c04c895c24600f85d4010000488d87000810000f57c0410f1100410f114010410f114020410f114030410f114040410f114050410f114060410f11407041c60000c646010144894e0448894e0849b800010000000100004c8946204531c04989c9eb14660f1f8400000000004983c1044584db4c0f45c9450fb7114183fa22744b4183fa2774454585d20f8432010000418d4a9f6683f91a0f828e000000664183fa5f0f8483000000418d4aa56683f9e57779410fb7ca81f980000000736d4983c102ebb20f1f8000000000498d4902410fb769026685ed410f94c3664439d5410f94c74508df75830f1f006683fd60750f66418379040074074983c1044c89c94989c94883c102410fb769026685ed410f94c30f8452ffffff664439d575cce947ffffff0f1f80000000004531db4c89c9eb140f1f840000000000440fb751024883c10241ffc3418d6a9f6683fd1a72ea418d6abf6683fd1a400f92c5664183fa5f410f94c74108ef75d0410fb7ea81fd80000000400f92c54183c2c6664183faf6410f92c24484d574b04181f8fe0000000f87c5feffff4589c24f8d14524e890cd04ac744d008000000006642c744d010000046895cd01441ffc0e99cfeffff4585c04c8b5c2460741441c1e003438d0c4048c704080000000048894610488954247849c70424010000000f57c0410f114424084c8b3b4c892b4c8d4424684c89e94889f241ffd389c5488b4c24684885c97407ff94244001000083fd0175264883bc2410010000000f84e70100004c897c2450488bac24480100004c8b7e18418b4710eb2c4c893b41c7042402000000e993020000488b4008498907666666662e0f1f840000000000418b47284983c71839e8745083f80475ef41837f080277e8498b074885c074e08078100774c6448b4014488b10488b8c242801000041b903010000ff9424380100004885c075a9488b44245048890341c7042405000000e923020000488b8424300100004885c00f94c1483b4424600f94c208ca75114c89e94889f2ffd083f8010f8548010000488b4424704889842488000000c78790010000ffffffff48c78788010000ffffffff4889879801000048c787a001000000000000488d8700033f004889442438488d8424800000004889442430488d8424900000004889442428488d842488000000488944242048c744244000003f004c8d44245c4c89e931d24d89f1ff542478488b4c245048890b4885c00f84a900000041c70424000000008b8f9001000041894c2404488b8f8001000049894c240849894c2410498d4c24204889ca4c29f24883fa0f0f8792000000ba05000000660f1f840000000000450fb64416fb44884411fb450fb64416fc44884411fc450fb64416fd44884411fd450fb64416fe44884411fe450fb64416ff44884411ff450fb60416448804114883c2064883fa3575b6eb514c893b48b8000000006300000049890424e9bd00000041c7042403000000e9b0000000488b44245048890341c7042406000000e99b000000410f10060f1101410f1046100f114110410f1046200f114120418b4c240483f9050f878a000000ba270000000fa3ca0f837c000000488b461849894424504885c0744c31c00f1f8000000000488b4e180fb60c0141884c0458488b4e180fb64c010141884c0459488b4e180fb64c010241884c045a488b4e180fb64c010341884c045b4883c004483d2001000075bd8b44245c41898424c800000031c04881c4980000005b5d5f5e415c415d415e415fc341c7442404000000004989442410e971ffffff"

