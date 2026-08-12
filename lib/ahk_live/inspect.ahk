class AhkLiveInspect {
    static Attach(pid) {
        return AhkLive.Attach(pid)
    }

    static Eval(hook, expr) {
        return AhkLive.Eval(hook, expr)
    }

    static Snapshot(hook, specs) {
        return AhkLive.Snapshot(hook, specs)
    }

    static Globals(hook, names) {
        return AhkLive.Globals(hook, names)
    }

    static ListFunctions(hook) {
        return AhkLive.ListFunctions(hook)
    }

    static ListClasses(hook) {
        return AhkLive.ListClasses(hook)
    }
}
