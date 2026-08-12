class AhkLiveTrace {
    static Trace(hook, name, outFile) {
        return AhkLive.TraceFunction(hook, name, outFile)
    }

    static Untrace(hook, tracer) {
        return AhkLive.Untrace(hook, tracer)
    }

    static Watch(hook, expr, onChange, ms := 500) {
        return AhkLive.Watch(hook, expr, onChange, ms)
    }
}
