; AhkLive
;
; Live-inspection helpers layered on the AhkMagic remote primitives.
; This file deliberately does not modify AhkMagic; the exact function lookup
; and trace/replace helpers live here.

class AhkLive {
    static renameSeq := 0

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
        state := Map("running", true, "last", "")
        tick := (*) => AhkLive._WatchTick(hook, expr, state, onChange)
        state["timer"] := SetTimer(tick, ms)
        state["Stop"] := (*) => AhkLive._WatchStop(state, tick)
        return state
    }

    static HotReload(hook, scriptPath, interval := 1000) {
        if !(hook is Map)
            throw TypeError("hook must be an AttachRemote result", -1)
        if !(scriptPath is String)
            throw TypeError("scriptPath must be a string", -1)
        state := Map("running", true, "sig", "")
        tick := (*) => AhkLive._HotReloadTick(hook, scriptPath, state)
        state["timer"] := SetTimer(tick, interval)
        state["Stop"] := (*) => AhkLive._HotReloadStop(state, tick)
        return state
    }

    static TraceFunction(hook, name, outFile) {
        if !(hook is Map) or !hook.Has("pid")
            throw TypeError("hook must be an AttachRemote result", -1)
        if !(name is String) or Trim(name) = ""
            throw ValueError("name must be a non-empty string", -1)
        if !(outFile is String)
            throw TypeError("outFile must be a string", -1)

        nameLen := StrLen(name)
        oldName := AhkLive._ShortName(nameLen)
        deadName := AhkLive._ShortName(nameLen)
        retName := "_ahk_live_ret_" Format("{:x}", A_TickCount)
            . Format("{:x}", Random(1, 0x7fffffff))
        escPath := StrReplace(outFile, "\", "\\")
        sig := AhkLive._FuncSignature(hook, name)
        loop sig["max"] {
            if sig["optional"][A_Index] or sig["byref"][A_Index]
                throw Error("TraceFunction does not support optional or ByRef parameters yet: " name, -1)
        }
        if sig["max"] < 2
            throw Error("TraceFunction currently requires at least two required parameters: " name, -1)
        paramNames := AhkLive._ParamNames(hook, name)
        params := AhkLive._JoinList(paramNames)
        callArgs := params

        AhkLive._RenameFunc(hook, name, oldName)
        script := "`n" retName "(v, label) {`n"
            . "    FileAppend(`"TRACE exit `" label `"=`" v Chr(10), `"" escPath "`")`n"
            . "    return v`n"
            . "}`n"
            . name "(" params ") {`n"
            . "    return " retName "(" oldName "(" callArgs "), `"" name "`")`n"
            . "}`n"
            . "StrLen(`"`")"
        AhkMagic.RemoteEvalScript(hook, script)

        return Map(
            "hook", hook,
            "name", name,
            "oldName", oldName,
            "deadName", deadName,
            "retName", retName,
            "outFile", outFile,
            "signature", sig,
            "params", params,
            "script", script
        )
    }

    static Untrace(hook, tracer) {
        if !(tracer is Map) or !tracer.Has("name") or !tracer.Has("oldName")
            or !tracer.Has("deadName")
            throw TypeError("tracer must be a TraceFunction result", -1)
        AhkLive._RenameFunc(hook, tracer["name"], tracer["deadName"])
        AhkLive._RenameFunc(hook, tracer["oldName"], tracer["name"])
        return Map("name", tracer["name"], "restoredFrom", tracer["oldName"])
    }

    static ReplaceFunction(hook, oldName, newName) {
        if !(hook is Map) or !hook.Has("pid")
            throw TypeError("hook must be an AttachRemote result", -1)
        nonce := Format("{:x}", A_TickCount) Format("{:x}", Random(1, 0x7fffffff))
        copyName := "_ahk_live_copy_" . nonce
        script := "`n" copyName "(a*) {`n    return -1`n}`nStrLen(`"`")"
        AhkMagic.RemoteEvalScript(hook, script)
        AhkLive._ReplaceFuncBodyExact(hook, copyName, oldName)
        AhkLive._ReplaceFuncBodyExact(hook, oldName, newName)
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

    static _RenameFunc(hook, oldName, newName) {
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
                data := AhkMagic._RemoteRead(h, nf, 0x800)
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
                    DllCall("WriteProcessMemory", "Ptr", h
                        , "Ptr", nf + inlineOff, "Ptr", nameBuf.Ptr
                        , "UPtr", nameBuf.Size, "UPtr*", &written)
                DllCall("WriteProcessMemory", "Ptr", h, "Ptr", nf + nameOff
                    , "Ptr", ptrBuf.Ptr, "UPtr", 8, "UPtr*", &written)
            }
            return Map("old", funcs, "name_block", block)
        } finally {
            DllCall("CloseHandle", "Ptr", h)
        }
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
            if onChange
                onChange(e)
        }
    }

    static _WatchStop(state, tick) {
        state["running"] := false
        SetTimer(tick, 0)
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

    static _HotReloadStop(state, tick) {
        state["running"] := false
        SetTimer(tick, 0)
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
        data := AhkMagic._RemoteRead(h, nf, 0x800)
        names := []
        loop data.Size // 8 {
            off := (A_Index - 1) * 8
            p := NumGet(data, off, "Ptr")
            if p < 0x10000 or p > 0x7fffffffffff
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
        if hook.Has("script_layout")
            return hook["script_layout"]
        h := AhkMagic._RemoteOpen(hook["pid"], true)
        try {
            mod := AhkMagic._RemoteModuleBase(h, hook["pid"])
            secs := AhkMagic._RemoteSections(h, mod["base"])
            loc := AhkMagic._RemoteLocateEvalScript(secs, mod["base"])
            layout := AhkMagic._RemoteDiscoverLayout(h, secs, mod["base"], loc)
            hook["script_layout"] := layout
            return layout
        } finally {
            DllCall("CloseHandle", "Ptr", h)
        }
    }

    static _EnsureNameOffset(hook, layout) {
        if hook.Has("name_off")
            return hook["name_off"]
        name := "ahkLiveNameProbe_" Format("{:x}", A_TickCount)
            . Format("{:x}", Random(1, 0x7fffffff))
        script := "`n" name "() {`n    return 1`n}`nStrLen(`"`")"
        AhkMagic.RemoteEvalScript(hook, script)
        h := AhkMagic._RemoteOpen(hook["pid"], true)
        try {
            gscript := layout["gscript"]
            arr := AhkMagic._RPtr(h, gscript + layout["mfuncs_off"])
            count := AhkMagic._RInt(h, gscript + layout["mfuncs_count_off"])
            nf := AhkMagic._RPtr(h, arr + (count - 1) * 8)
            data := AhkMagic._RemoteRead(h, nf, 0x1000)
            loop data.Size // 8 {
                off := (A_Index - 1) * 8
                p := NumGet(data, off, "Ptr")
                if p < 0x10000 or p > 0x7fffffffffff
                    continue
                try s := AhkMagic._RemoteReadString(h, p, StrLen(name) + 1)
                catch
                    continue
                if s = name {
                    hook["name_off"] := off
                    return off
                }
            }
            throw Error("function name offset not found", -1)
        } finally {
            DllCall("CloseHandle", "Ptr", h)
        }
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

    static _ReplaceFuncBodyExact(hook, oldName, newName) {
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
            for oldPtr in oldList
                AhkMagic._WPtr(h, oldPtr + jumpOff, newJump)
            return Map("old", oldList, "new", newList[1], "count", oldList.Length)
        } finally {
            DllCall("CloseHandle", "Ptr", h)
        }
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
