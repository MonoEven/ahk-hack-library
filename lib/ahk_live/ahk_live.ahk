; AhkLive
;
; Live-inspection helpers layered on the AhkMagic remote primitives.
; This file deliberately does not modify AhkMagic; the exact function lookup
; and trace/replace helpers live here.

class AhkLive {
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

    static TraceFunction(hook, name, outFile) {
        if !(hook is Map) or !hook.Has("pid")
            throw TypeError("hook must be an AttachRemote result", -1)
        if !(name is String) or Trim(name) = ""
            throw ValueError("name must be a non-empty string", -1)
        if !(outFile is String)
            throw TypeError("outFile must be a string", -1)

        nonce := Format("{:x}", A_TickCount) Format("{:x}", Random(1, 0x7fffffff))
        oldName := "_ahk_live_old_" . nonce
        deadName := "_ahk_live_dead_" . nonce
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
        script := "`n" name "(" params ") {`n"
            . "    FileAppend(`"TRACE enter " name "`" Chr(10), `"" escPath "`")`n"
            . "    return " oldName "(" callArgs ")`n"
            . "}`n"
            . "StrLen(`"`")"
        AhkMagic.RemoteEvalScript(hook, script)

        return Map(
            "hook", hook,
            "name", name,
            "oldName", oldName,
            "deadName", deadName,
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

    static _RenameFunc(hook, oldName, newName) {
        layout := AhkLive._EnsureLayout(hook)
        nameOff := AhkLive._EnsureNameOffset(hook, layout)
        h := AhkMagic._RemoteOpen(hook["pid"], true)
        try {
            funcs := AhkLive._FindExactFuncs(h, layout, nameOff, oldName)
            if !funcs.Length
                throw Error("function object not found: " oldName, -1)
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
                DllCall("WriteProcessMemory", "Ptr", h, "Ptr", nf + nameOff
                    , "Ptr", ptrBuf.Ptr, "UPtr", 8, "UPtr*", &written)
                DllCall("WriteProcessMemory", "Ptr", h, "Ptr", nf + 264
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
            data := AhkMagic._RemoteRead(h, funcs[1], 0x800)
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
            if names.Length < max
                throw Error("could not discover parameter names for " name, -1)
            return names
        } finally {
            DllCall("CloseHandle", "Ptr", h)
        }
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
