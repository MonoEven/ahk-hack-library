class AhkLivePatch {
    static Replace(hook, oldName, newName) {
        return AhkLive.ReplaceFunction(hook, oldName, newName)
    }

    static Restore(hook, record) {
        return AhkLive.RestoreFunction(hook, record)
    }
}
