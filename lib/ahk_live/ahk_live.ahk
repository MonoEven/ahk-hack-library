; AhkLive
;
; Live-inspection helpers layered on the AhkMagic remote primitives.
; This file deliberately does not modify AhkMagic; the exact function lookup
; and trace/replace helpers live here.

class AhkLive {
    static VERSION := "1.0.0"
    static renameSeq := 0
    static FUNC_SCAN_SIZE := 0x800
    static MIN_PTR := 0x10000
    static MAX_PTR := 0x7fffffffffff
    static watchSeq := 0
    static watches := Map()
    static watchTimerActive := false
    static reloadSeq := 0
    static reloads := Map()
    static reloadTimerActive := false

    static Attach(pid) {
        return AhkMagic.AttachRemote(pid)
    }

    static AttachByName(name) {
        return AhkMagic.AttachRemoteByName(name)
    }

    static Eval(hook, expr) {
        return AhkMagic.RemoteEval(hook, expr)
    }

    static LoadScript(hook, text) {
        return AhkMagic.RemoteEvalScript(hook, text)
    }

    static Snapshot(hook, specs) {
        if !(hook is Map)
            throw TypeError("hook must be an AttachRemote result", -1)
        result := Map()
        if specs is Map {
            for name, expr in specs
                result[name] := AhkMagic.RemoteEval(hook, expr)
        } else if specs is Array {
            for expr in specs
                result[expr] := AhkMagic.RemoteEval(hook, expr)
        } else {
            throw TypeError("specs must be a Map or Array", -1)
        }
        return result
    }

    static Watch(hook, expr, onChange, ms := 500) {
        if !(hook is Map)
            throw TypeError("hook must be an AttachRemote result", -1)
        if !(expr is String)
            throw TypeError("expr must be a string", -1)
        AhkLive.watchSeq += 1
        state := Map(
            "hook", hook,
            "expr", expr,
            "onChange", onChange,
            "ms", ms,
            "running", true,
            "last", "",
            "next", A_TickCount + ms
        )
        AhkLive.watches[AhkLive.watchSeq] := state
        AhkLive._EnsureWatchTimer()
        return AhkLiveWatcher("watch", AhkLive.watchSeq, state)
    }

    static HotReload(hook, scriptPath, interval := 1000) {
        if !(hook is Map)
            throw TypeError("hook must be an AttachRemote result", -1)
        if !(scriptPath is String)
            throw TypeError("scriptPath must be a string", -1)
        AhkLive.reloadSeq += 1
        state := Map(
            "hook", hook,
            "path", scriptPath,
            "interval", interval,
            "running", true,
            "sig", "",
            "next", A_TickCount + interval
        )
        AhkLive.reloads[AhkLive.reloadSeq] := state
        AhkLive._EnsureReloadTimer()
        return AhkLiveWatcher("reload", AhkLive.reloadSeq, state)
    }

    static TraceFunction(hook, name, outFile, journal := 0) {
        if !(hook is Map) or !hook.Has("pid")
            throw TypeError("hook must be an AttachRemote result", -1)
        if !(name is String) or Trim(name) = ""
            throw ValueError("name must be a non-empty string", -1)
        if !(outFile is String)
            throw TypeError("outFile must be a string", -1)

        nonce := Format("{:x}", A_TickCount)
            . Format("{:x}", Random(1, 0x7fffffff))
        oldName := "_ahk_live_clone_" . nonce
        deadName := oldName
        retName := "_ahk_live_ret_" . nonce
        wrapperName := "_ahk_live_wrap_" . nonce
        logVar := "_ahk_live_log_" . nonce
        sig := AhkLive._FuncSignature(hook, name)
        loop sig["max"] {
            if sig["optional"][A_Index] or sig["byref"][A_Index]
                throw Error("TraceFunction does not support optional or ByRef parameters yet: " name, -1)
        }
        if sig["max"] < 2
            throw Error("TraceFunction currently requires at least two required parameters: " name, -1)
        paramNames := AhkLive._ParamNames(hook, name)
        params := AhkLive._JoinList(paramNames)

        layout := AhkLive._EnsureLayout(hook)
        nameOff := AhkLive._EnsureNameOffset(hook, layout)
        varLayout := AhkLive._EnsureVarLayout(hook, layout)
        h := AhkMagic._RemoteOpen(hook["pid"], true)
        try {
            funcs := AhkLive._FindExactFuncs(h, layout, nameOff, name)
            if !funcs.Length
                throw Error("function object not found: " name, -1)
            nf := funcs[1]
            mparamOff := AhkLive._FindMParamOff(h, nf, paramNames)
            if !mparamOff
                throw Error("mParam offset not found for " name, -1)
            mparamPtr := AhkMagic._RPtr(h, nf + mparamOff)
            p0 := AhkMagic._RPtr(h, mparamPtr)
            p1 := AhkMagic._RPtr(h, mparamPtr + 24)
            origJump := AhkMagic._RPtr(h, nf + layout["mjump_line_off"])
            clonePtr := AhkLive._CloneUserFunc(h, layout, nf, oldName)
            AhkLive._CreateGlobalObjectVar(h, layout, clonePtr, oldName
                , varLayout)
        } finally {
            DllCall("CloseHandle", "Ptr", h)
        }

        ; #Warn is positional: it silences the load-time "appears to never
        ; be assigned" warning for names the trace wrapper references that
        ; are created through interpreter internals (the clone global) and
        ; are invisible to the parser's assignment analysis.
        script := "#Warn All, Off`n`n" retName "(v, label) {`n"
            . "    global " logVar "`n"
            . "    " logVar " .= `"TRACE exit `" label `"=`" v Chr(10)`n"
            . "    return v`n"
            . "}`n"
            . wrapperName "(" params ") {`n"
            . "    return " retName "(" oldName "(" params "), `"" name "`")`n"
            . "}`n"
            . "StrLen(`"`")"
        AhkMagic.RemoteEvalScript(hook, script)

        h := AhkMagic._RemoteOpen(hook["pid"], true)
        try {
            wrappers := AhkLive._FindExactFuncs(h, layout, nameOff
                , wrapperName)
            if !wrappers.Length
                throw Error("trace wrapper not found", -1)
            wnf := wrappers[1]
            wmparamOff := AhkLive._FindMParamOff(h, wnf, paramNames)
            if !wmparamOff
                throw Error("wrapper mParam offset not found", -1)
            wmparamPtr := AhkMagic._RPtr(h, wnf + wmparamOff)
            p0Buf := Buffer(8)
            p1Buf := Buffer(8)
            NumPut("Ptr", p0, p0Buf, 0)
            NumPut("Ptr", p1, p1Buf, 0)
            AhkMagic._RemoteWrite(h, wmparamPtr, p0Buf)
            AhkMagic._RemoteWrite(h, wmparamPtr + 24, p1Buf)
            mvars := AhkLive._FindMVars(h, wnf, paramNames)
            if mvars {
                listData := AhkMagic._RemoteRead(h, mvars["item"], 0x40)
                loop 2 {
                    wv := NumGet(listData, (A_Index - 1) * 8, "Ptr")
                    target := A_Index = 1 ? p0 : p1
                    aliasBuf := Buffer(8)
                    NumPut("Ptr", target, aliasBuf, 0)
                    ; The alias pointer goes into the Var's mAliasFor slot
                    ; (validated constant offset), the symbol bit-clear
                    ; marks it as a constant alias, and the trailing flag
                    ; byte (symbol + 2) must be zeroed so the resolver
                    ; follows the alias instead of reading the value.
                    AhkMagic._RemoteWrite(h, wv + 0x10, aliasBuf)
                    symOff := varLayout["symbol"]
                    attr := NumGet(AhkMagic._RemoteRead(h, wv + symOff, 1)
                        , 0, "UChar")
                    AhkMagic._WByte(h, wv + symOff, attr & 0xFD)
                    AhkMagic._WByte(h, wv + symOff + 2, 0)
                }
            }
            AhkLive._ReplaceFuncBodyExact(hook, name, wrapperName)
        } finally {
            DllCall("CloseHandle", "Ptr", h)
        }

        return Map(
            "hook", hook,
            "name", name,
            "oldName", oldName,
            "deadName", deadName,
            "clone_ptr", clonePtr,
            "orig_jump", origJump,
            "log_var", logVar,
            "retName", retName,
            "outFile", outFile,
            "signature", sig,
            "params", params,
            "script", script
        )
    }

    static Untrace(hook, tracer) {
        if !(tracer is Map) or !tracer.Has("name") or !tracer.Has("orig_jump")
            throw TypeError("tracer must be a TraceFunction result", -1)
        layout := AhkLive._EnsureLayout(hook)
        nameOff := AhkLive._EnsureNameOffset(hook, layout)
        h := AhkMagic._RemoteOpen(hook["pid"], true)
        try {
            funcs := AhkLive._FindExactFuncs(h, layout, nameOff
                , tracer["name"])
            if !funcs.Length
                throw Error("function object not found: " tracer["name"], -1)
            jumpBuf := Buffer(8)
            NumPut("Ptr", tracer["orig_jump"], jumpBuf, 0)
            AhkMagic._RemoteWrite(h, funcs[1] + layout["mjump_line_off"]
                , jumpBuf)
        } finally {
            DllCall("CloseHandle", "Ptr", h)
        }
        return Map("name", tracer["name"], "restoredFrom", tracer["oldName"])
    }

    static ReplaceFunction(hook, oldName, newName, journal := 0) {
        if !(hook is Map) or !hook.Has("pid")
            throw TypeError("hook must be an AttachRemote result", -1)
        nonce := Format("{:x}", A_TickCount) Format("{:x}", Random(1, 0x7fffffff))
        copyName := "_ahk_live_copy_" . nonce
        script := "#Warn All, Off`n`n" copyName "(a*) {`n    return -1`n}`nStrLen(`"`")"
        AhkMagic.RemoteEvalScript(hook, script)
        AhkLive._ReplaceFuncBodyExact(hook, copyName, oldName, journal)
        AhkLive._ReplaceFuncBodyExact(hook, oldName, newName, journal)
        return Map("hook", hook, "name", oldName, "newName", newName
            , "copyName", copyName, "script", script)
    }

    static RestoreFunction(hook, record) {
        if !(record is Map) or !record.Has("name") or !record.Has("copyName")
            throw TypeError("record must be a ReplaceFunction result", -1)
        AhkLive._ReplaceFuncBodyExact(hook, record["name"], record["copyName"])
        return Map("name", record["name"], "restoredFrom", record["copyName"])
    }

    static Globals(hook, names) {
        if !(hook is Map)
            throw TypeError("hook must be an AttachRemote result", -1)
        if !(names is Array)
            throw TypeError("names must be an Array", -1)
        result := Map()
        for name in names
            result[name] := AhkMagic.RemoteEval(hook, name)
        return result
    }

    static ListFunctions(hook) {
        layout := AhkLive._EnsureLayout(hook)
        nameOff := AhkLive._EnsureNameOffset(hook, layout)
        h := AhkMagic._RemoteOpen(hook["pid"], true)
        try {
            gscript := layout["gscript"]
            arr := AhkMagic._RPtr(h, gscript + layout["mfuncs_off"])
            count := AhkMagic._RInt(h, gscript + layout["mfuncs_count_off"])
            result := Map()
            loop count {
                nf := AhkMagic._RPtr(h, arr + (A_Index - 1) * 8)
                name := AhkMagic._RemoteReadString(h
                    , AhkMagic._RPtr(h, nf + nameOff), 256)
                if name = "" or InStr(name, "_ahk_live_") = 1
                    or InStr(name, "ahkLiveNameProbe_") = 1
                    continue
                max := 0
                min := 0
                variadic := 0
                if RegExMatch(name, "^[A-Za-z_][A-Za-z0-9_]*$") {
                    try {
                        sig := AhkLive._FuncSignature(hook, name)
                        max := sig["max"]
                        min := sig["min"]
                        variadic := sig["variadic"]
                    }
                }
                params := max > 0
                    ? AhkLive._ParamNamesFromObject(h, nf, name, max) : []
                result[name] := Map("min", min, "max", max
                    , "variadic", variadic, "params", params)
            }
            return result
        } finally {
            DllCall("CloseHandle", "Ptr", h)
        }
    }

    static ListClasses(hook) {
        funcs := AhkLive.ListFunctions(hook)
        classes := Map()
        marker := ".Prototype."
        for name, info in funcs {
            pos := InStr(name, marker)
            if !pos
                continue
            cls := SubStr(name, 1, pos - 1)
            method := SubStr(name, pos + StrLen(marker))
            if !classes.Has(cls)
                classes[cls] := Map()
            classes[cls][method] := info
        }
        return classes
    }

    static _RenameFunc(hook, oldName, newName, journal := 0) {
        layout := AhkLive._EnsureLayout(hook)
        nameOff := AhkLive._EnsureNameOffset(hook, layout)
        h := AhkMagic._RemoteOpen(hook["pid"], true)
        try {
            funcs := AhkLive._FindExactFuncs(h, layout, nameOff, oldName)
            if !funcs.Length
                throw Error("function object not found: " oldName, -1)
            if StrLen(newName) > StrLen(oldName)
                throw Error("rename target is longer than the source name", -1)
            nameBuf := Buffer((StrLen(newName) + 1) * 2)
            StrPut(newName, nameBuf, "UTF-16")
            block := DllCall("VirtualAllocEx", "Ptr", h, "Ptr", 0
                , "UPtr", nameBuf.Size, "UInt", 0x3000, "UInt", 0x04, "Ptr")
            if !block
                throw Error("VirtualAllocEx failed", -1)
            written := 0
            DllCall("WriteProcessMemory", "Ptr", h, "Ptr", block
                , "Ptr", nameBuf.Ptr, "UPtr", nameBuf.Size, "UPtr*", &written)
            ptrBuf := Buffer(8)
            NumPut("Ptr", block, ptrBuf, 0)
            for nf in funcs {
                data := AhkMagic._RemoteRead(h, nf, AhkLive.FUNC_SCAN_SIZE)
                inlineOff := 0
                loop data.Size - StrLen(oldName) * 2 {
                    off := A_Index - 1
                    ok := true
                    loop StrLen(oldName) {
                        if NumGet(data, off + (A_Index - 1) * 2, "UShort")
                            != Ord(SubStr(oldName, A_Index, 1)) {
                            ok := false
                            break
                        }
                    }
                    if ok {
                        inlineOff := off
                        break
                    }
                }
                if inlineOff
                {
                    if journal
                        journal.Record(nf + inlineOff, nameBuf.Size)
                    DllCall("WriteProcessMemory", "Ptr", h
                        , "Ptr", nf + inlineOff, "Ptr", nameBuf.Ptr
                        , "UPtr", nameBuf.Size, "UPtr*", &written)
                }
                if journal
                    journal.Record(nf + nameOff, A_PtrSize)
                DllCall("WriteProcessMemory", "Ptr", h, "Ptr", nf + nameOff
                    , "Ptr", ptrBuf.Ptr, "UPtr", 8, "UPtr*", &written)
            }
            return Map("old", funcs, "name_block", block)
        } finally {
            DllCall("CloseHandle", "Ptr", h)
        }
    }

    static _FindMParamOff(h, nf, paramNames) {
        data := AhkMagic._RemoteRead(h, nf, 0x400)
        loop data.Size // 8 {
            off := (A_Index - 1) * 8
            q := NumGet(data, off, "Ptr")
            if q <= AhkLive.MIN_PTR or q >= AhkLive.MAX_PTR
                continue
            try
                arr := AhkMagic._RemoteRead(h, q, 0x60)
            catch
                continue
            v0 := NumGet(arr, 0, "Ptr")
            v1 := NumGet(arr, 24, "Ptr")
            if v0 <= AhkLive.MIN_PTR or v1 <= AhkLive.MIN_PTR
                continue
            n0 := ""
            n1 := ""
            try
                n0 := AhkMagic._RemoteReadString(h
                    , NumGet(AhkMagic._RemoteRead(h, v0 + 40, 8)
                        , 0, "Ptr"), 32)
            catch
                n0 := ""
            try
                n1 := AhkMagic._RemoteReadString(h
                    , NumGet(AhkMagic._RemoteRead(h, v1 + 40, 8)
                        , 0, "Ptr"), 32)
            catch
                n1 := ""
            if n0 = paramNames[1] and n1 = paramNames[2]
                return off
        }
        return 0
    }

    static _FindMVars(h, nf, paramNames) {
        data := AhkMagic._RemoteRead(h, nf, 0x400)
        loop 0x200 // 8 {
            off := (A_Index - 1) * 8
            itemPtr := NumGet(data, off, "Ptr")
            count := NumGet(data, off + 8, "Int")
            if itemPtr <= AhkLive.MIN_PTR or itemPtr >= AhkLive.MAX_PTR
                or count < 2 or count > 100
                continue
            try
                listData := AhkMagic._RemoteRead(h, itemPtr, count * 8)
            catch
                continue
            v0 := NumGet(listData, 0, "Ptr")
            v1 := NumGet(listData, 8, "Ptr")
            n0 := ""
            n1 := ""
            try
                n0 := AhkMagic._RemoteReadString(h
                    , NumGet(AhkMagic._RemoteRead(h, v0 + 40, 8)
                        , 0, "Ptr"), 32)
            catch
                n0 := ""
            try
                n1 := AhkMagic._RemoteReadString(h
                    , NumGet(AhkMagic._RemoteRead(h, v1 + 40, 8)
                        , 0, "Ptr"), 32)
            catch
                n1 := ""
            if n0 = paramNames[1] and n1 = paramNames[2]
                return Map("off", off, "item", itemPtr)
        }
        return 0
    }

    static _CloneUserFunc(h, layout, nf, newName) {
        size := 0x400
        clonePtr := DllCall("VirtualAllocEx", "Ptr", h, "Ptr", 0
            , "UPtr", size, "UInt", 0x3000, "UInt", 0x40, "Ptr")
        if !clonePtr
            throw Error("VirtualAllocEx(clone) failed", -1)
        AhkMagic._RemoteWrite(h, clonePtr
            , AhkMagic._RemoteRead(h, nf, size))
        nameBuf := Buffer((StrLen(newName) + 1) * 2)
        StrPut(newName, nameBuf, "UTF-16")
        nameBlock := DllCall("VirtualAllocEx", "Ptr", h, "Ptr", 0
            , "UPtr", nameBuf.Size, "UInt", 0x3000, "UInt", 0x04, "Ptr")
        if !nameBlock
            throw Error("VirtualAllocEx(name) failed", -1)
        AhkMagic._RemoteWrite(h, nameBlock, nameBuf)
        ptrBuf := Buffer(8)
        NumPut("Ptr", nameBlock, ptrBuf, 0)
        AhkMagic._RemoteWrite(h, clonePtr + layout["name_off"], ptrBuf)
        return clonePtr
    }

    ; Discover the Var record layout in the target by diffing one variable
    ; between an integer state and an object state, both assigned by the
    ; interpreter itself so no offset or symbol constant is assumed.  The
    ; changed bytes outside the value field must form one consecutive run
    ; (symbol followed by flags); anything else fails loudly.
    static _EnsureVarLayout(hook, layout) {
        if hook.Has("var_layout")
            return hook["var_layout"]
        h := AhkMagic._RemoteOpen(hook["pid"], true)
        try {
            name := "_ahk_live_vp" Format("{:x}", A_TickCount)
            nameBuf := Buffer((StrLen(name) + 1) * 2)
            StrPut(name, nameBuf, "UTF-16")
            nameBlock := DllCall("VirtualAllocEx", "Ptr", h, "Ptr", 0
                , "UPtr", nameBuf.Size, "UInt", 0x3000, "UInt", 0x04, "Ptr")
            if !nameBlock
                throw Error("VirtualAllocEx(name) failed", -1)
            AhkMagic._RemoteWrite(h, nameBlock, nameBuf)
            varPtr := AhkMagic._RemoteCall(h, layout["find_var"]
                , [layout["gscript"], nameBlock, StrLen(name), 0x101])
            if !varPtr
                throw Error("FindOrAddVar failed for var probe", -1)
            snapFresh := AhkMagic._RemoteRead(h, varPtr, 0x80)
            AhkMagic.RemoteEval(hook, name " := 12345")
            snapInt := AhkMagic._RemoteRead(h, varPtr, 0x80)
            AhkMagic.RemoteEval(hook, name " := StrSplit(`"a`", `",`")")
            snapObj := AhkMagic._RemoteRead(h, varPtr, 0x80)

            valueOff := -1
            loop 0x80 - 7 {
                off := A_Index - 1
                if NumGet(snapInt, off, "Int64") = 12345 {
                    valueOff := off
                    break
                }
            }
            if valueOff < 0
                throw Error("var value offset not discovered", -1)

            ; The object-state byte set: everything the interpreter changes
            ; between the fresh variable and the object assignment (value
            ; field excluded).  Writing this exact set makes a fresh var
            ; behave as an object reference.
            changed := Map()
            loop 0x80 {
                off := A_Index - 1
                if off >= valueOff and off < valueOff + 8
                    continue
                bf := NumGet(snapFresh, off, "UChar")
                bo := NumGet(snapObj, off, "UChar")
                if bf != bo
                    changed[off] := bo
            }
            if !changed.Count
                throw Error("var symbol/flags bytes not discovered", -1)
            symOff := -1
            loop 0x80 {
                off := A_Index - 1
                if off >= valueOff and off < valueOff + 8
                    continue
                if NumGet(snapInt, off, "UChar") != NumGet(snapObj, off, "UChar") {
                    symOff := off
                    break
                }
            }
            if symOff < 0
                throw Error("var symbol byte not discovered", -1)
            varLayout := Map(
                "name", name,
                "value", valueOff,
                "symbol", symOff,
                "sym_object", changed[symOff],
                "changed", changed)
            hook["var_layout"] := varLayout
            return varLayout
        } finally {
            DllCall("CloseHandle", "Ptr", h)
        }
    }

    static _CreateGlobalObjectVar(h, layout, objPtr, name, varLayout) {
        nameBuf := Buffer((StrLen(name) + 1) * 2)
        StrPut(name, nameBuf, "UTF-16")
        nameBlock := DllCall("VirtualAllocEx", "Ptr", h, "Ptr", 0
            , "UPtr", nameBuf.Size, "UInt", 0x3000, "UInt", 0x04, "Ptr")
        if !nameBlock
            throw Error("VirtualAllocEx(name) failed", -1)
        AhkMagic._RemoteWrite(h, nameBlock, nameBuf)
        varPtr := AhkMagic._RemoteCall(h, layout["find_var"]
            , [layout["gscript"], nameBlock, StrLen(name), 0x101])
        if !varPtr
            throw Error("FindOrAddVar failed for " name, -1)
        objBuf := Buffer(8)
        NumPut("Ptr", objPtr, objBuf, 0)
        AhkMagic._RemoteWrite(h, varPtr + varLayout["value"], objBuf)
        ; Apply the discovered object-state bytes (symbol + flags) so the
        ; variable behaves as an object reference.
        for off, byteVal in varLayout["changed"]
            AhkMagic._WByte(h, varPtr + off, byteVal)
        return varPtr
    }

    static _WatchTick(hook, expr, state, onChange) {
        if !state["running"]
            return
        try {
            value := AhkMagic.RemoteEval(hook, expr)
            if state["last"] != value {
                state["last"] := value
                if onChange
                    onChange(value)
            }
        } catch as e {
            try {
                f := FileOpen(A_Temp "\ahk_live_watch_err.txt", "a", "UTF-8")
                f.Write(e.What " | " e.Message " | line " e.Line "`n")
                f.Close()
            }
            if onChange
                onChange(e)
        }
    }

    static _EnsureWatchTimer() {
        if AhkLive.watchTimerActive
            return
        SetTimer(AhkLive_WatchTimer, 50)
        AhkLive.watchTimerActive := true
    }

    static _EnsureReloadTimer() {
        if AhkLive.reloadTimerActive
            return
        SetTimer(AhkLive_HotReloadTimer, 50)
        AhkLive.reloadTimerActive := true
    }

    static _StopWatcher(kind, id, state) {
        state["running"] := false
        if kind = "watch" {
            AhkLive.watches.Delete(id)
            if !AhkLive.watches.Count and AhkLive.watchTimerActive {
                SetTimer(AhkLive_WatchTimer, 0)
                AhkLive.watchTimerActive := false
            }
            return
        }
        if kind = "reload" {
            AhkLive.reloads.Delete(id)
            if !AhkLive.reloads.Count and AhkLive.reloadTimerActive {
                SetTimer(AhkLive_HotReloadTimer, 0)
                AhkLive.reloadTimerActive := false
            }
            return
        }
        throw ValueError("unknown watcher kind", -1)
    }

    static _HotReloadTick(hook, scriptPath, state) {
        if !state["running"]
            return
        if !FileExist(scriptPath)
            return
        sig := FileGetTime(scriptPath) "-" FileGetSize(scriptPath)
        if sig = state["sig"]
            return
        state["sig"] := sig
        AhkMagic.RemoteEvalScript(hook, FileRead(scriptPath, "UTF-8"))
    }


    static _FuncSignature(hook, name) {
        min := Integer(AhkMagic.RemoteEval(hook, name ".MinParams"))
        max := Integer(AhkMagic.RemoteEval(hook, name ".MaxParams"))
        variadic := AhkMagic.RemoteEval(hook, name ".IsVariadic") = 1
        byref := []
        optional := []
        loop max {
            byref.Push(AhkMagic.RemoteEval(hook
                , name ".IsByRef(" A_Index ")") = 1)
            optional.Push(AhkMagic.RemoteEval(hook
                , name ".IsOptional(" A_Index ")") = 1)
        }
        return Map("min", min, "max", max, "variadic", variadic
            , "byref", byref, "optional", optional)
    }

    static _ParamList(sig, forCall) {
        out := ""
        loop sig["max"] {
            if out != ""
                out .= ", "
            if forCall and sig["byref"][A_Index]
                out .= "&"
            out .= "a" A_Index
        }
        if sig["variadic"] {
            if out != ""
                out .= ", "
            out .= "args*"
        }
        return out
    }

    static _ParamNames(hook, name) {
        layout := AhkLive._EnsureLayout(hook)
        nameOff := AhkLive._EnsureNameOffset(hook, layout)
        max := Integer(AhkMagic.RemoteEval(hook, name ".MaxParams"))
        h := AhkMagic._RemoteOpen(hook["pid"], true)
        try {
            funcs := AhkLive._FindExactFuncs(h, layout, nameOff, name)
            if !funcs.Length
                throw Error("function object not found: " name, -1)
            return AhkLive._ParamNamesFromObject(h, funcs[1], name, max)
        } finally {
            DllCall("CloseHandle", "Ptr", h)
        }
    }

    static _ParamNamesFromObject(h, nf, name, max) {
        data := AhkMagic._RemoteRead(h, nf, AhkLive.FUNC_SCAN_SIZE)
        names := []
        loop data.Size // 8 {
            off := (A_Index - 1) * 8
            p := NumGet(data, off, "Ptr")
            if p < AhkLive.MIN_PTR or p > AhkLive.MAX_PTR
                continue
            try s := AhkMagic._RemoteReadString(h, p, 64)
            catch
                continue
            if s = name or !RegExMatch(s, "^[A-Za-z_][A-Za-z0-9_]*$")
                continue
            if AhkLive._Contains(names, s)
                continue
            names.Push(s)
            if names.Length = max
                break
        }
        return names
    }

    static _Contains(arr, value) {
        for item in arr
            if item = value
                return true
        return false
    }

    static _JoinList(list, sep := ", ") {
        out := ""
        for item in list
            out .= (out = "" ? "" : sep) . item
        return out
    }

    static _ShortName(maxLen) {
        if maxLen < 1
            maxLen := 1
        AhkLive.renameSeq += 1
        n := AhkLive.renameSeq
        prefix := "_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        digits := "_0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        out := ""
        loop maxLen {
            if A_Index = 1 {
                out .= SubStr(prefix, Mod(n, StrLen(prefix)) + 1, 1)
                n := Integer(n // StrLen(prefix))
            } else {
                out .= SubStr(digits, Mod(n, StrLen(digits)) + 1, 1)
                n := Integer(n // StrLen(digits))
            }
        }
        return out
    }

    static _EnsureLayout(hook) {
        if hook.Has("script_layout") {
            layout := hook["script_layout"]
            if !layout.Has("find_var") {
                if !hook.Has("script_loc")
                    throw Error("script_loc missing", -1)
                loc := hook["script_loc"]
                layout["find_var"] := NumGet(loc["loc_out"], 16, "Ptr")
            }
            return layout
        }
        h := AhkMagic._RemoteOpen(hook["pid"], true)
        try {
            modBase := AhkMagic._RemoteModuleBase(h, hook["pid"])
            secs := AhkMagic._RemoteSections(h, modBase["base"])
            loc := AhkMagic._RemoteLocateEvalScript(secs, modBase["base"])
            layout := AhkMagic._RemoteDiscoverLayout(h, secs, modBase["base"], loc)
            layout["find_var"] := NumGet(loc["loc_out"], 16, "Ptr")
            hook["script_layout"] := layout
            hook["script_loc"] := loc
            return layout
        } finally {
            DllCall("CloseHandle", "Ptr", h)
        }
    }

    static _EnsureNameOffset(hook, layout) {
        if hook.Has("name_off")
            return hook["name_off"]
        if layout.Has("name_off") and layout["name_off"] {
            hook["name_off"] := layout["name_off"]
            return layout["name_off"]
        }
        throw Error("function name offset not found", -1)
    }

    static _FindExactFuncs(h, layout, nameOff, name) {
        gscript := layout["gscript"]
        arr := AhkMagic._RPtr(h, gscript + layout["mfuncs_off"])
        count := AhkMagic._RInt(h, gscript + layout["mfuncs_count_off"])
        result := []
        loop count {
            nf := AhkMagic._RPtr(h, arr + (A_Index - 1) * 8)
            p := AhkMagic._RPtr(h, nf + nameOff)
            if !p
                continue
            try s := AhkMagic._RemoteReadString(h, p, StrLen(name) + 1)
            catch
                continue
            if s = name
                result.Push(nf)
        }
        return result
    }

    static _ReplaceFuncBodyExact(hook, oldName, newName, journal := 0) {
        layout := AhkLive._EnsureLayout(hook)
        nameOff := AhkLive._EnsureNameOffset(hook, layout)
        h := AhkMagic._RemoteOpen(hook["pid"], true)
        try {
            oldList := AhkLive._FindExactFuncs(h, layout, nameOff, oldName)
            newList := AhkLive._FindExactFuncs(h, layout, nameOff, newName)
            if !oldList.Length or !newList.Length
                throw Error("function object not found: " oldName " / " newName, -1)
            jumpOff := layout["mjump_line_off"]
            newJump := AhkMagic._RPtr(h, newList[1] + jumpOff)
            if !newJump
                throw Error("new function body not found", -1)
            for oldPtr in oldList {
                if journal
                    journal.Record(oldPtr + jumpOff, A_PtrSize)
                AhkMagic._WPtr(h, oldPtr + jumpOff, newJump)
            }
            return Map("old", oldList, "new", newList[1], "count", oldList.Length)
        } finally {
            DllCall("CloseHandle", "Ptr", h)
        }
    }
}


class AhkLiveWatcher {
    kind := ""
    id := 0
    state := 0

    __New(kind, id, state) {
        this.kind := kind
        this.id := id
        this.state := state
    }

    Stop() {
        if !this.state["running"]
            return
        AhkLive._StopWatcher(this.kind, this.id, this.state)
    }
}

AhkLive_WatchTimer() {
    now := A_TickCount
    for id, state in AhkLive.watches {
        if !state["running"] or now < state["next"]
            continue
        AhkLive._WatchTick(state["hook"], state["expr"]
            , state, state["onChange"])
        state["next"] := now + state["ms"]
    }
}

AhkLive_HotReloadTimer() {
    now := A_TickCount
    for id, state in AhkLive.reloads {
        if !state["running"] or now < state["next"]
            continue
        AhkLive._HotReloadTick(state["hook"], state["path"], state)
        state["next"] := now + state["interval"]
    }
}


class AhkLiveJournal {
    __New(hook) {
        if !(hook is Map) or !hook.Has("pid")
            throw TypeError("hook must be an AttachRemote result", -1)
        this.hook := hook
        this.records := Map()
    }

    Record(addr, size) {
        if !(addr is Integer) or !(size is Integer) or size < 1
            throw ValueError("addr and size are required", -1)
        if this.records.Has(addr)
            return
        h := AhkMagic._RemoteOpen(this.hook["pid"], false)
        try {
            this.records[addr] := AhkMagic._RemoteRead(h, addr, size)
        } finally {
            DllCall("CloseHandle", "Ptr", h)
        }
    }

    RecordPtr(addr) {
        this.Record(addr, A_PtrSize)
    }

    Rollback() {
        if !this.records.Count
            return 0
        h := AhkMagic._RemoteOpen(this.hook["pid"], true)
        try {
            written := 0
            for addr, buf in this.records {
                DllCall("WriteProcessMemory", "Ptr", h, "Ptr", addr
                    , "Ptr", buf.Ptr, "UPtr", buf.Size, "UPtr*", &written)
            }
            count := this.records.Count
            this.records := Map()
            return count
        } finally {
            DllCall("CloseHandle", "Ptr", h)
        }
    }
}
