class AhkLiveForensics {
    static Report(hook) {
        version := AhkMagic.RemoteEval(hook, "A_AhkVersion")
        return Map(
            "pid", hook["pid"],
            "module", hook["module"],
            "image_base", hook["image_base"],
            "version", version,
            "builtins", hook["builtins"]["count"],
            "native_functions", hook["native_functions"]["count"],
            "builtin_vars", hook["builtin_vars"]["count"],
            "functions", AhkLive.ListFunctions(hook),
            "classes", AhkLive.ListClasses(hook)
        )
    }
}
