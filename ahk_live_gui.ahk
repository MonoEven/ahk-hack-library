#Requires AutoHotkey v2
#SingleInstance Force
#NoTrayIcon
#Include lib\ahk_live\init.ahk

if A_Args.Length >= 2 and A_Args[1] = "--selftest" {
    SelfTest(Integer(A_Args[2]))
    ExitApp 0
}

global autoPid := 0
global autoDemo := 0
if A_Args.Length >= 2 and (A_Args[1] = "--attach" or A_Args[1] = "--demo") {
    autoPid := Integer(A_Args[2])
    if A_Args[1] = "--demo"
        autoDemo := 1
}
global autoShot := 0
if A_Args.Length >= 3 and A_Args[1] = "--shot" {
    autoPid := Integer(A_Args[2])
    autoDemo := 1
    autoShot := Integer(A_Args[3])
}

global session := AhkLiveSession()
global gTab := 0
global gLv := 0
global gShowAll := 0
global gHookInfo := 0
global gLog := 0
global gEvalExpr := 0
global gEvalResult := 0
global gScriptEdit := 0
global gScriptResult := 0
global gSnapshotSpecs := 0
global gSnapshotResult := 0
global gGlobalsSpecs := 0
global gInventoryResult := 0
global gPatchOld := 0
global gPatchNew := 0
global gPatchResult := 0
global gPatchSession := 0
global gTraceName := 0
global gTraceArgs := 0
global gTraceResult := 0
global gTracer := 0
global gWatchExpr := 0
global gWatchMs := 0
global gWatchResult := 0
global gWatcher := 0
global gReloadPath := 0
global gReloadMs := 0
global gReloadResult := 0
global gReloader := 0
global gForensicsResult := 0


SafeStr(v) {
    try {
        if v is String or v is Integer or v is Float
            return v
        if v is Map
            return "Map(count=" v.Count ")"
        if v is Array
            return "Array(len=" v.Length ")"
        if v is Object
            return Type(v)
        return String(v)
    } catch
        return "<unprintable>"
}


SplitSpecs(text) {
    out := []
    depth := 0
    quote := ""
    start := 1
    loop StrLen(text) {
        c := SubStr(text, A_Index, 1)
        if quote != "" {
            if c = quote
                quote := ""
        } else if c = "'" or c = Chr(34)
            quote := c
        else if c = "(" or c = "[" or c = "{"
            depth += 1
        else if c = ")" or c = "]" or c = "}"
            depth -= 1
        else if c = "," and depth = 0 and quote = "" {
            out.Push(SubStr(text, start, A_Index - start))
            start := A_Index + 1
        }
    }
    out.Push(SubStr(text, start))
    return out
}


AhkLive_OnError(e, exitCode := 0) {
    msg := FormatTime(, "HH:mm:ss") " ERR " SafeStr(e.What)
        . " | " SafeStr(e.Message)
        . " | " SafeStr(e.File) ":" SafeStr(e.Line)
        . " | extra=" SafeStr(e.Extra)
        . " | exit=" SafeStr(exitCode)
    FileAppend(msg "`n", A_Temp "\ahk_live_gui_error.log")
    try {
        global gLog
        if gLog
            gLog.Value .= msg "`n"
    } catch as inner
        FileAppend("ERR log write failed: " SafeStr(inner.Message) "`n"
            , A_Temp "\ahk_live_gui_error.log")
    return true
}

try
    OnError(AhkLive_OnError)
catch as e
    FileAppend("OnError unavailable: " SafeStr(e.Message) "`n"
        , A_Temp "\ahk_live_gui_error.log")
BuildGui()


BuildGui() {
    global autoPid, autoDemo, autoShot, gTab, gLv, gShowAll, gHookInfo, gLog
    global gEvalExpr, gEvalResult, gScriptEdit, gScriptResult
    global gSnapshotSpecs, gSnapshotResult, gGlobalsSpecs
    global gInventoryResult
    global gPatchOld, gPatchNew, gPatchResult
    global gTraceName, gTraceArgs, gTraceResult
    global gWatchExpr, gWatchMs, gWatchResult
    global gReloadPath, gReloadMs, gReloadResult
    global gForensicsResult

    g := Gui(, "AhkLive")
    g.OnEvent("Close", (*) => ExitApp())
    g.SetFont("s10", "Segoe UI")

    g.Add("Text", "x12 y10 w360", "AutoHotkey processes")
    gLv := g.Add("ListView", "x12 y28 w360 h250", ["PID", "Name", "Title"])
    gLv.OnEvent("DoubleClick", (*) => AttachSelected())
    gShowAll := g.Add("Checkbox", "x12 y284", "Show all processes")
    refresh := g.Add("Button", "x170 y282 w86", "Refresh")
    refresh.OnEvent("Click", (*) => RefreshList())
    attach := g.Add("Button", "x262 y282 w54", "Attach")
    attach.OnEvent("Click", (*) => AttachSelected())
    detach := g.Add("Button", "x322 y282 w54", "Detach")
    detach.OnEvent("Click", (*) => DetachSession())

    g.Add("Text", "x390 y10 w570", "Hook")
    gHookInfo := g.Add("Edit", "x390 y28 w570 h90 ReadOnly", "not attached")

    tab := g.Add("Tab3", "x390 y128 w570 h370"
        , ["Eval", "Script", "Snapshot", "Inventory", "Patch"
            , "Trace", "Watch", "Reload", "Forensics"])
    gTab := tab

    tab.UseTab(1)
    gEvalExpr := g.Add("Edit", "x402 y168 w390 h56", "1 + 2 * 3")
    evalBtn := g.Add("Button", "x800 y168 w148 h30", "Eval")
    evalBtn.OnEvent("Click", (*) => DoEval())
    gEvalResult := g.Add("Edit", "x402 y232 w546 h180 ReadOnly", "")

    tab.UseTab(2)
    gScriptEdit := g.Add("Edit", "x402 y168 w546 h150 "
        , "`nguiScriptAdd(a, b) {`n    return a + b`n}`nguiScriptAdd(1, 2)`n")
    scriptBtn := g.Add("Button", "x800 y326 w148 h30", "EvalScript")
    scriptBtn.OnEvent("Click", (*) => DoScript())
    gScriptResult := g.Add("Edit", "x402 y366 w546 h130 ReadOnly", "")

    tab.UseTab(3)
    g.Add("Text", "x402 y168", "Snapshot: name=expr, comma-separated")
    gSnapshotSpecs := g.Add("Edit", "x402 y186 w546 h32"
        , "add=Add(2, 3), mul=Mul(4)")
    snapBtn := g.Add("Button", "x800 y186 w148 h30", "Snapshot")
    snapBtn.OnEvent("Click", (*) => DoSnapshot())
    g.Add("Text", "x402 y230", "Globals: comma-separated names")
    gGlobalsSpecs := g.Add("Edit", "x402 y248 w546 h32", "pidFile")
    globBtn := g.Add("Button", "x800 y248 w148 h30", "Globals")
    globBtn.OnEvent("Click", (*) => DoGlobals())
    gSnapshotResult := g.Add("Edit", "x402 y292 w546 h200 ReadOnly", "")

    tab.UseTab(4)
    invBtn := g.Add("Button", "x402 y168 w160 h30", "List functions")
    invBtn.OnEvent("Click", (*) => DoInventory())
    clsBtn := g.Add("Button", "x570 y168 w160 h30", "List classes")
    clsBtn.OnEvent("Click", (*) => DoClasses())
    gInventoryResult := g.Add("Edit", "x402 y208 w546 h280 ReadOnly", "")

    tab.UseTab(5)
    g.Add("Text", "x402 y168", "Replace")
    gPatchOld := g.Add("Edit", "x402 y186 w120", "Mul")
    g.Add("Text", "x530 y190", "->")
    gPatchNew := g.Add("Edit", "x548 y186 w120", "NewMul")
    patchBtn := g.Add("Button", "x680 y184 w120 h30", "Replace")
    patchBtn.OnEvent("Click", (*) => DoPatch())
    rollbackBtn := g.Add("Button", "x806 y184 w120 h30", "Rollback")
    rollbackBtn.OnEvent("Click", (*) => DoRollback())
    gPatchResult := g.Add("Edit", "x402 y228 w524 h260 ReadOnly", "")

    tab.UseTab(6)
    g.Add("Text", "x402 y168", "Function")
    gTraceName := g.Add("Edit", "x402 y186 w140", "Add")
    g.Add("Text", "x552 y172", "Call args")
    gTraceArgs := g.Add("Edit", "x552 y190 w140", "2, 3")
    traceBtn := g.Add("Button", "x704 y184 w110 h30", "Trace")
    traceBtn.OnEvent("Click", (*) => DoTrace())
    callBtn := g.Add("Button", "x820 y184 w110 h30", "Call")
    callBtn.OnEvent("Click", (*) => DoTraceCall())
    untraceBtn := g.Add("Button", "x704 y224 w110 h30", "Untrace")
    untraceBtn.OnEvent("Click", (*) => DoUntrace())
    gTraceResult := g.Add("Edit", "x402 y268 w528 h220 ReadOnly", "")

    tab.UseTab(7)
    g.Add("Text", "x402 y168", "Watch expression")
    gWatchExpr := g.Add("Edit", "x402 y186 w420", "Mul(4)")
    g.Add("Text", "x832 y172", "ms")
    gWatchMs := g.Add("Edit", "x832 y190 w100", "500")
    startWatch := g.Add("Button", "x402 y224 w140 h30", "Start watch")
    startWatch.OnEvent("Click", (*) => StartWatch())
    stopWatch := g.Add("Button", "x550 y224 w140 h30", "Stop watch")
    stopWatch.OnEvent("Click", (*) => StopWatch())
    gWatchResult := g.Add("Edit", "x402 y264 w530 h220 ReadOnly", "")

    tab.UseTab(8)
    g.Add("Text", "x402 y168", "Script file")
    gReloadPath := g.Add("Edit", "x402 y186 w420", "")
    g.Add("Text", "x832 y172", "ms")
    gReloadMs := g.Add("Edit", "x832 y190 w100", "1000")
    startReload := g.Add("Button", "x402 y224 w140 h30", "Start reload")
    startReload.OnEvent("Click", (*) => StartReload())
    stopReload := g.Add("Button", "x550 y224 w140 h30", "Stop reload")
    stopReload.OnEvent("Click", (*) => StopReload())
    gReloadResult := g.Add("Edit", "x402 y264 w530 h220 ReadOnly", "")

    tab.UseTab(9)
    reportBtn := g.Add("Button", "x402 y168 w160 h30", "Runtime report")
    reportBtn.OnEvent("Click", (*) => DoReport())
    exportBtn := g.Add("Button", "x570 y168 w160 h30", "Export CSV")
    exportBtn.OnEvent("Click", (*) => DoExport())
    gForensicsResult := g.Add("Edit", "x402 y208 w546 h280 ReadOnly", "")

    tab.UseTab()

    gLog := g.Add("Edit", "x12 y510 w948 h110 ReadOnly", "")
    g.Show("w972 h640")
    if autoPid
        AttachTo(autoPid)
    if autoDemo
        RunDemo()
    if autoShot {
        gTab.Value := autoShot
        try
            FileAppend("ready`n tab=" gTab.Value "`n"
                , A_Temp "\ahk_live_gui_shot_ready")
        catch
            FileAppend("ready`n", A_Temp "\ahk_live_gui_shot_ready")
    }
    SetTimer(Gui_RefreshTimer, 2000)
    RefreshList()
}


Gui_RefreshTimer() {
    if WinActive("AhkLive")
        RefreshList()
}


Log(msg) {
    global gLog
    line := FormatTime(, "HH:mm:ss") " " SafeStr(msg) "`n"
    try {
        if gLog
            gLog.Value .= line
    } catch as e {
        FileAppend("GUI log append failed: " SafeStr(e.Message) "`n"
            , A_Temp "\ahk_live_gui_error.log")
    }
    FileAppend(line, A_Temp "\ahk_live_gui.log")
}


LogResult(label, result) {
    if result.ok
        Log(label " ok=" SafeStr(result.value))
    else
        Log(label " FAIL " SafeStr(result.error))
}


EnumProcesses() {
    list := []
    hSnap := DllCall("CreateToolhelp32Snapshot", "UInt", 0x2, "UInt", 0, "Ptr")
    if hSnap = 0 or hSnap = -1
        return list
    try {
        pe := Buffer(568)
        NumPut("UInt", 568, pe, 0)
        if DllCall("Process32FirstW", "Ptr", hSnap, "Ptr", pe, "Int") {
            loop {
                pid := NumGet(pe, 8, "UInt")
                name := StrGet(pe.Ptr + 40, "UTF-16")
                list.Push(Map("pid", pid, "name", name))
            } until !DllCall("Process32NextW", "Ptr", hSnap, "Ptr", pe, "Int")
        }
    } finally {
        DllCall("CloseHandle", "Ptr", hSnap)
    }
    return list
}


RefreshList() {
    global gLv, gShowAll
    gLv.Delete()
    for proc in EnumProcesses() {
        if !gShowAll.Value and !RegExMatch(proc["name"], "i)autohotkey")
            continue
        title := ""
        try
            title := WinGetTitle("ahk_pid " proc["pid"])
        gLv.Add(, proc["pid"], proc["name"], title)
    }
    gLv.ModifyCol(1, "AutoHdr")
    gLv.ModifyCol(2, "AutoHdr")
    gLv.ModifyCol(3, "AutoHdr")
}


AttachSelected() {
    global gLv
    row := gLv.GetNext()
    if !row {
        Log("select a process")
        return
    }
    pid := gLv.GetText(row, 1)
    AttachTo(Integer(pid))
}


AttachTo(pid) {
    global gHookInfo, session
    result := session.Attach(Integer(pid))
    if !result.ok {
        Log("attach failed: " result.error)
        gHookInfo.Value := "attach failed"
        return
    }
    hook := session.hook
    info := "pid=" hook["pid"]
        . "`nmodule=" hook["module"]
        . "`nbase=0x" Format("{:X}", hook["image_base"])
        . "`nbif=" hook["builtins"]["count"]
        . " native=" hook["native_functions"]["count"]
        . " biv=" hook["builtin_vars"]["count"]
    try
        info .= "`nversion=" AhkMagic.RemoteEval(hook, "A_AhkVersion")
    gHookInfo.Value := info
    Log("attached " pid)
}


DetachSession() {
    global session, gHookInfo, gTracer, gWatcher, gReloader, gPatchSession
    if gWatcher {
        gWatcher.Stop()
        gWatcher := 0
    }
    if gReloader {
        gReloader.Stop()
        gReloader := 0
    }
    if gPatchSession {
        gPatchSession.Rollback()
        gPatchSession := 0
    }
    if gTracer {
        session.Untrace(gTracer)
        gTracer := 0
    }
    session.Close()
    gHookInfo.Value := "not attached"
    Log("detached")
}


RequireHook() {
    global session
    if !session.hook
        throw Error("attach to a process first", -1)
    return session.hook
}


DoEval() {
    global session, gEvalExpr, gEvalResult
    try {
        result := session.Eval(gEvalExpr.Value)
        if !result.ok {
            gEvalResult.Value := "FAIL " SafeStr(result.error)
            Log("eval FAIL " SafeStr(result.error))
            return
        }
        gEvalResult.Value := SafeStr(result.value)
        Log("eval => " SafeStr(result.value))
    } catch as e {
        gEvalResult.Value := "FAIL " SafeStr(e.Message)
        Log("eval FAIL " SafeStr(e.Message))
    }
}


DoScript() {
    global session, gScriptEdit, gScriptResult
    try {
        result := session.EvalScript(gScriptEdit.Value)
        if !result.ok {
            gScriptResult.Value := "FAIL " SafeStr(result.error)
            Log("script FAIL " SafeStr(result.error))
            return
        }
        gScriptResult.Value := SafeStr(result.value)
        Log("script => " SafeStr(result.value))
    } catch as e {
        gScriptResult.Value := "FAIL " SafeStr(e.Message)
        Log("script FAIL " SafeStr(e.Message))
    }
}


DoSnapshot() {
    global session, gSnapshotSpecs, gSnapshotResult
    specs := Map()
    for part in SplitSpecs(gSnapshotSpecs.Value) {
        item := Trim(part)
        if item = ""
            continue
        pair := StrSplit(item, "=", , 2)
        if pair.Length = 2
            specs[Trim(pair[1])] := Trim(pair[2])
    }
    result := session.Snapshot(specs)
    if !result.ok {
        gSnapshotResult.Value := SafeStr(result.error)
        Log("snapshot FAIL " SafeStr(result.error))
        return
    }
    out := ""
    for name, value in result.value
        out .= name "=" SafeStr(value) "`n"
    gSnapshotResult.Value := out
    Log("snapshot ok")
}


DoGlobals() {
    global session, gGlobalsSpecs, gSnapshotResult
    names := []
    for part in SplitSpecs(gGlobalsSpecs.Value) {
        item := Trim(part)
        if item != ""
            names.Push(item)
    }
    result := session.Globals(names)
    if !result.ok {
        gSnapshotResult.Value := SafeStr(result.error)
        Log("globals FAIL " SafeStr(result.error))
        return
    }
    out := ""
    for name, value in result.value
        out .= name "=" SafeStr(value) "`n"
    gSnapshotResult.Value := out
    Log("globals ok")
}


DoInventory() {
    global session, gInventoryResult
    result := session.ListFunctions()
    if !result.ok {
        gInventoryResult.Value := SafeStr(result.error)
        Log("inventory FAIL " SafeStr(result.error))
        return
    }
    out := ""
    for name, info in result.value
        out .= name "(" AhkLive._JoinList(info["params"]) ")`n"
    gInventoryResult.Value := out
    Log("inventory ok count=" result.value.Count)
}


DoClasses() {
    global session, gInventoryResult
    result := session.ListClasses()
    if !result.ok {
        gInventoryResult.Value := SafeStr(result.error)
        Log("classes FAIL " SafeStr(result.error))
        return
    }
    out := ""
    for cls, methods in result.value {
        for method in methods
            out .= cls "." method "`n"
    }
    gInventoryResult.Value := out
    Log("classes ok count=" result.value.Count)
}


DoPatch() {
    global session, gPatchOld, gPatchNew, gPatchResult, gPatchSession
    if !session.hook {
        gPatchResult.Value := "not attached"
        return
    }
    if gPatchSession {
        gPatchResult.Value := "rollback the active patch first"
        return
    }
    result := session.BeginPatch()
    if !result.ok {
        gPatchResult.Value := SafeStr(result.error)
        Log("patch begin FAIL " SafeStr(result.error))
        return
    }
    ps := result.value
    patch := ps.Replace(gPatchOld.Value, gPatchNew.Value)
    if !patch.ok {
        ps.Rollback()
        gPatchResult.Value := SafeStr(patch.error)
        Log("patch FAIL " SafeStr(patch.error))
        return
    }
    gPatchSession := ps
    gPatchResult.Value := "patched " gPatchOld.Value " -> " gPatchNew.Value
    Log("patched " gPatchOld.Value " -> " gPatchNew.Value)
}


DoRollback() {
    global gPatchSession, gPatchResult
    if !gPatchSession {
        gPatchResult.Value := "no active patch"
        return
    }
    result := gPatchSession.Rollback()
    gPatchSession := 0
    gPatchResult.Value := result.ok ? "rolled back" : result.error
    Log("rollback " (result.ok ? "ok" : "FAIL " SafeStr(result.error)))
}


DoTrace() {
    global session, gTraceName, gTraceResult, gTracer
    if !session.hook {
        gTraceResult.Value := "not attached"
        return
    }
    if gTracer {
        gTraceResult.Value := "untrace the current tracer first"
        return
    }
    result := session.Trace(gTraceName.Value, A_Temp "\ahk_live_trace.log")
    if !result.ok {
        gTraceResult.Value := SafeStr(result.error)
        Log("trace FAIL " SafeStr(result.error))
        return
    }
    gTracer := result.value
    gTraceResult.Value := "trace active on " gTraceName.Value
    Log("trace active on " gTraceName.Value)
}


DoTraceCall() {
    global session, gTraceName, gTraceArgs, gTraceResult, gTracer
    if !gTracer {
        gTraceResult.Value := "start a trace first"
        return
    }
    expr := gTraceName.Value "(" gTraceArgs.Value ")"
    result := session.Eval(expr)
    if !result.ok {
        gTraceResult.Value := SafeStr(result.error)
        Log("tracecall FAIL " SafeStr(result.error))
        return
    }
    logResult := session.Eval(gTracer["log_var"])
    if !logResult.ok {
        gTraceResult.Value := expr " => " SafeStr(result.value)
            . "`nlog FAIL " SafeStr(logResult.error)
        Log("tracecall log FAIL " SafeStr(logResult.error))
        return
    }
    gTraceResult.Value := expr " => " SafeStr(result.value)
        . "`n" SafeStr(logResult.value)
    Log("tracecall " expr " => " SafeStr(result.value))
}


DoUntrace() {
    global session, gTracer, gTraceResult
    if !gTracer {
        gTraceResult.Value := "no active tracer"
        return
    }
    session.Untrace(gTracer)
    gTracer := 0
    gTraceResult.Value := "untraced"
    Log("untraced")
}


StartWatch() {
    global session, gWatchExpr, gWatchMs, gWatchResult, gWatcher
    try {
        if !session.hook {
            gWatchResult.Value := "not attached"
            Log("watch FAIL not attached")
            return
        }
        if gWatcher {
            gWatcher.Stop()
        }
        obs := AhkLiveObservability(session.hook)
        ms := Max(100, Integer(gWatchMs.Value))
        gWatcher := obs.WatchWhen(gWatchExpr.Value, ""
            , WatchCallback, ms)
        gWatchResult.Value := "watching " gWatchExpr.Value
        Log("watch active on " gWatchExpr.Value)
    } catch as e {
        gWatchResult.Value := "FAIL " SafeStr(e.Message)
        Log("watch FAIL " SafeStr(e.Message))
    }
}


StopWatch() {
    global gWatcher, gWatchResult
    if gWatcher {
        gWatcher.Stop()
        gWatcher := 0
    }
    gWatchResult.Value .= "`nstopped"
    Log("watch stopped")
}


WatchCallback(event) {
    global gWatchResult
    value := event is Error ? SafeStr(event.Message) : SafeStr(event.value)
    gWatchResult.Value .= "`n" value
    Log("watch event " value)
}


StartReload() {
    global session, gReloadPath, gReloadMs, gReloadResult, gReloader
    try {
        if !session.hook {
            gReloadResult.Value := "not attached"
            Log("reload FAIL not attached")
            return
        }
        path := gReloadPath.Value
        if !FileExist(path) {
            gReloadResult.Value := "file not found"
            Log("reload FAIL file not found")
            return
        }
        if gReloader {
            gReloader.Stop()
        }
        ms := Max(200, Integer(gReloadMs.Value))
        gReloader := session.HotReload(path, ms)
        gReloadResult.Value := "watching " path
        Log("reload active on " path)
    } catch as e {
        gReloadResult.Value := "FAIL " SafeStr(e.Message)
        Log("reload FAIL " SafeStr(e.Message))
    }
}


StopReload() {
    global gReloader, gReloadResult
    if gReloader {
        gReloader.Stop()
        gReloader := 0
    }
    gReloadResult.Value .= "`nstopped"
    Log("reload stopped")
}


DoReport() {
    global session, gForensicsResult
    try {
        if !session.hook {
            gForensicsResult.Value := "not attached"
            Log("report FAIL not attached")
            return
        }
        report := AhkLiveForensics.Report(session.hook)
        gForensicsResult.Value := "pid=" SafeStr(report["pid"])
            . " version=" SafeStr(report["version"])
            . "`nmodule=" SafeStr(report["module"])
            . "`nfunctions=" SafeStr(report["functions"].Count)
            . " classes=" SafeStr(report["classes"].Count)
            . "`nbif=" SafeStr(report["builtins"])
            . " native=" SafeStr(report["native_functions"])
            . " biv=" SafeStr(report["builtin_vars"])
        Log("report ok")
    } catch as e {
        gForensicsResult.Value := "FAIL " SafeStr(e.Message)
        Log("report FAIL " SafeStr(e.Message))
    }
}


DoExport() {
    global session, gForensicsResult
    try {
        if !session.hook {
            gForensicsResult.Value := "not attached"
            Log("export FAIL not attached")
            return
        }
        path := A_Temp "\ahk_live_inventory.csv"
        AhkLiveCompat.ExportCsv(session.hook, path)
        gForensicsResult.Value := path
        Log("export ok " path)
    } catch as e {
        gForensicsResult.Value := "FAIL " SafeStr(e.Message)
        Log("export FAIL " SafeStr(e.Message))
    }
}


RunDemo() {
    global gEvalExpr, gScriptEdit, gSnapshotSpecs
    global gTraceName, gTraceArgs
    gEvalExpr.Value := "Add(2, 3)"
    gTraceName.Value := "Add"
    gTraceArgs.Value := "2, 3"
    try
        DoEval()
    catch as e
        Log("demo eval FAIL " e.Message)
    gScriptEdit.Value := "`nrhkDemo(a, b) {`n    return a * b`n}`nrhkDemo(3, 4)`n"
    try
        DoScript()
    catch as e
        Log("demo script FAIL " e.Message)
    gSnapshotSpecs.Value := "add=Add(2, 3), mul=Mul(4)"
    try
        DoSnapshot()
    catch as e
        Log("demo snapshot FAIL " e.Message)
    try
        DoInventory()
    catch as e
        Log("demo inventory FAIL " e.Message)
    try
        DoReport()
    catch as e
        Log("demo report FAIL " e.Message)
    try
        DoTrace()
    catch as e
        Log("demo trace FAIL " e.Message)
    try
        DoTraceCall()
    catch as e
        Log("demo tracecall FAIL " e.Message)
    Log("demo ready")
    FileAppend("ready`n", A_Temp "\ahk_live_gui_demo_ready")
}


SelfTest(pid) {
    s := AhkLiveSession()
    attach := s.Attach(pid)
    if !attach.ok {
        FileAppend("FAIL " attach.error "`n", A_Temp "\ahk_live_gui_selftest.out")
        return
    }
    r := s.Eval("1 + 2 * 3")
    if !r.ok or r.value != 7 {
        FileAppend("FAIL eval`n", A_Temp "\ahk_live_gui_selftest.out")
        return
    }
    FileAppend("PASS`n", A_Temp "\ahk_live_gui_selftest.out")
    s.Close()
}
