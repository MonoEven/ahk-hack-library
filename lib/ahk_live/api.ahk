; Product-level AhkLive API.  Low-level AhkLive remains available for research
; use, but new integrations should prefer AhkLiveSession and AhkLiveResult.

class AhkLiveResult {
    ok := false
    value := ""
    error := ""
    meta := Map()

    __New(ok, value := "", error := "", meta := Map()) {
        this.ok := ok
        this.value := value
        this.error := error
        this.meta := meta
    }

    static Ok(value := "", meta := Map()) {
        return AhkLiveResult(true, value, "", meta)
    }

    static Err(error := "", meta := Map()) {
        return AhkLiveResult(false, "", error, meta)
    }
}


class AhkLiveSession {
    hook := 0
    closed := false

    Attach(pid) {
        if this.closed
            return AhkLiveResult.Err("session is closed")
        try {
            this.hook := AhkLive.Attach(pid)
            return AhkLiveResult.Ok(this.hook["pid"])
        } catch as e {
            return AhkLiveResult.Err(this._ErrText(e))
        }
    }

    AttachByName(name) {
        if this.closed
            return AhkLiveResult.Err("session is closed")
        try {
            this.hook := AhkLive.AttachByName(name)
            return AhkLiveResult.Ok(this.hook["pid"])
        } catch as e {
            return AhkLiveResult.Err(this._ErrText(e))
        }
    }

    Eval(expr) {
        return this._Wrap((hook) => AhkLive.Eval(hook, expr))
    }

    Snapshot(specs) {
        return this._Wrap((hook) => AhkLive.Snapshot(hook, specs))
    }

    Globals(names) {
        return this._Wrap((hook) => AhkLive.Globals(hook, names))
    }

    ListFunctions() {
        return this._Wrap((hook) => AhkLive.ListFunctions(hook))
    }

    ListClasses() {
        return this._Wrap((hook) => AhkLive.ListClasses(hook))
    }

    Trace(name, outFile) {
        return this._Wrap((hook) => AhkLive.TraceFunction(hook, name, outFile))
    }

    Untrace(tracer) {
        return this._Wrap((hook) => AhkLive.Untrace(hook, tracer))
    }

    Replace(oldName, newName) {
        return this._Wrap((hook) => AhkLive.ReplaceFunction(hook, oldName, newName))
    }

    Restore(record) {
        return this._Wrap((hook) => AhkLive.RestoreFunction(hook, record))
    }

    Watch(expr, onChange, ms := 500) {
        if !this.hook
            return AhkLiveResult.Err("not attached")
        try {
            return AhkLiveResult.Ok(AhkLive.Watch(this.hook, expr, onChange, ms))
        } catch as e {
            return AhkLiveResult.Err(this._ErrText(e))
        }
    }

    HotReload(scriptPath, interval := 1000) {
        if !this.hook
            return AhkLiveResult.Err("not attached")
        try {
            return AhkLiveResult.Ok(AhkLive.HotReload(this.hook, scriptPath, interval))
        } catch as e {
            return AhkLiveResult.Err(this._ErrText(e))
        }
    }

    BeginPatch() {
        if !this.hook
            return AhkLiveResult.Err("not attached")
        return AhkLiveResult.Ok(AhkLivePatchSession(this))
    }

    Close() {
        this.closed := true
        this.hook := 0
        return AhkLiveResult.Ok(true)
    }

    _Wrap(fn) {
        if !this.hook
            return AhkLiveResult.Err("not attached")
        try {
            return AhkLiveResult.Ok(fn(this.hook))
        } catch as e {
            return AhkLiveResult.Err(this._ErrText(e))
        }
    }

    _ErrText(e) {
        return e.What " | " e.Message " | line " e.Line
    }
}


class AhkLivePatchSession {
    session := 0
    journal := 0
    active := true

    __New(session) {
        this.session := session
        this.journal := AhkLiveJournal(session.hook)
    }

    Replace(oldName, newName) {
        if !this.active
            return AhkLiveResult.Err("patch session is not active")
        try {
            value := AhkLive.ReplaceFunction(this.session.hook, oldName, newName, this.journal)
            return AhkLiveResult.Ok(value)
        } catch as e {
            return AhkLiveResult.Err(this.session._ErrText(e))
        }
    }

    Trace(name, outFile) {
        if !this.active
            return AhkLiveResult.Err("patch session is not active")
        try {
            value := AhkLive.TraceFunction(this.session.hook, name, outFile, this.journal)
            return AhkLiveResult.Ok(value)
        } catch as e {
            return AhkLiveResult.Err(this.session._ErrText(e))
        }
    }

    Rollback() {
        if !this.active
            return AhkLiveResult.Err("patch session is not active")
        try {
            count := this.journal.Rollback()
            this.active := false
            return AhkLiveResult.Ok(count)
        } catch as e {
            return AhkLiveResult.Err(this.session._ErrText(e))
        }
    }

    Commit() {
        if !this.active
            return AhkLiveResult.Err("patch session is not active")
        this.active := false
        return AhkLiveResult.Ok(this.journal.records.Count)
    }
}
