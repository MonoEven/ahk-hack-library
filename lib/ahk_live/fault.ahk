class AhkLiveFault {
    session := 0

    __New(session) {
        this.session := session
    }

    InjectReplace(oldName, newName) {
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
}
