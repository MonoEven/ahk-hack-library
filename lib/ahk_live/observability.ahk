class AhkLiveEvent {
    __New(kind, target, value, tick) {
        this.kind := kind
        this.target := target
        this.value := value
        this.tick := tick
    }
}


class AhkLiveObservability {
    static watchSeq := 0
    static watches := Map()
    static timerActive := false

    hook := 0
    events := []

    __New(hook) {
        this.hook := hook
    }

    WatchWhen(expr, condition, onChange, ms := 500) {
        AhkLiveObservability.watchSeq += 1
        id := AhkLiveObservability.watchSeq
        state := Map(
            "owner", this,
            "expr", expr,
            "condition", condition,
            "onChange", onChange,
            "ms", ms,
            "running", true,
            "last", "",
            "next", A_TickCount + ms
        )
        AhkLiveObservability.watches[id] := state
        AhkLiveObservability._EnsureTimer()
        return AhkLiveObservabilityWatcher(id, state)
    }

    static _EnsureTimer() {
        if AhkLiveObservability.timerActive
            return
        SetTimer(AhkLive_ObservabilityTimer, 50)
        AhkLiveObservability.timerActive := true
    }

    static _Stop(id, state) {
        state["running"] := false
        AhkLiveObservability.watches.Delete(id)
        if !AhkLiveObservability.watches.Count and AhkLiveObservability.timerActive {
            SetTimer(AhkLive_ObservabilityTimer, 0)
            AhkLiveObservability.timerActive := false
        }
    }

    static _Tick(state) {
        if !state["running"]
            return
        try {
            value := AhkMagic.RemoteEval(state["owner"].hook, state["expr"])
            if state["last"] != value {
                state["last"] := value
                ok := true
                if state["condition"] != "" {
                    ok := AhkMagic.RemoteEval(state["owner"].hook
                        , state["condition"]) = 1
                }
                if ok {
                    event := AhkLiveEvent("watch", state["expr"], value
                        , A_TickCount)
                    state["owner"].events.Push(event)
                    if state["onChange"]
                        state["onChange"](event)
                }
            }
        } catch as e {
            try {
                f := FileOpen(A_Temp "\ahk_live_observability_err.txt"
                    , "a", "UTF-8")
                f.Write(e.What " | " e.Message " | line " e.Line "`n")
                f.Close()
            }
            if state["onChange"]
                state["onChange"](e)
        }
    }
}


class AhkLiveObservabilityWatcher {
    id := 0
    state := 0

    __New(id, state) {
        this.id := id
        this.state := state
    }

    Stop() {
        if !this.state["running"]
            return
        AhkLiveObservability._Stop(this.id, this.state)
    }
}


AhkLive_ObservabilityTimer() {
    now := A_TickCount
    for id, state in AhkLiveObservability.watches {
        if !state["running"] or now < state["next"]
            continue
        AhkLiveObservability._Tick(state)
        state["next"] := now + state["ms"]
    }
}
