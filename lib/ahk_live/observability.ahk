class AhkLiveEvent {
    __New(kind, target, value, tick) {
        this.kind := kind
        this.target := target
        this.value := value
        this.tick := tick
    }
}


class AhkLiveObservability {
    hook := 0
    events := []

    __New(hook) {
        this.hook := hook
    }

    WatchWhen(expr, condition, onChange, ms := 500) {
        state := Map("running", true, "last", "")
        tick := (*) => this._Tick(expr, condition, state, onChange)
        state["timer"] := SetTimer(tick, ms)
        state["Stop"] := (*) => (state["running"] := false, SetTimer(tick, 0))
        return state
    }

    _Tick(expr, condition, state, onChange) {
        if !state["running"]
            return
        try {
            value := AhkMagic.RemoteEval(this.hook, expr)
            if state["last"] != value {
                state["last"] := value
                ok := true
                if condition != "" {
                    ok := AhkMagic.RemoteEval(this.hook, condition) = 1
                }
                if ok {
                    event := AhkLiveEvent("watch", expr, value, A_TickCount)
                    this.events.Push(event)
                    if onChange
                        onChange(event)
                }
            }
        }
    }
}
