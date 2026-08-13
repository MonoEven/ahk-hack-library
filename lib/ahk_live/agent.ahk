class AhkLiveAgent {
    session := 0

    __New(pid) {
        this.session := AhkLiveSession()
        result := this.session.Attach(pid)
        if !result.ok
            throw Error(result.error)
    }

    Eval(expr) {
        return this.session.Eval(expr)
    }

    Snapshot(specs) {
        return this.session.Snapshot(specs)
    }

    Inventory() {
        return AhkLiveResult.Ok(Map(
            "functions", this.session.ListFunctions().value,
            "classes", this.session.ListClasses().value
        ))
    }

    Replace(oldName, newName) {
        patch := this.session.BeginPatch()
        if !patch.ok
            return patch
        ps := patch.value
        result := ps.Replace(oldName, newName)
        if !result.ok {
            ps.Rollback()
            return result
        }
        return AhkLiveResult.Ok(Map("patch", ps, "record", result.value))
    }

    Close() {
        return this.session.Close()
    }
}
