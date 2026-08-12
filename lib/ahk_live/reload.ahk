class AhkLiveReload {
    static Watch(hook, scriptPath, interval := 1000) {
        return AhkLive.HotReload(hook, scriptPath, interval)
    }
}
