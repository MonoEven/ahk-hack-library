#Requires AutoHotkey v2
#SingleInstance Force
#NoTrayIcon
#Include lib\ahk_live\init.ahk

global session := AhkLiveSession()
global gLv := 0
global gShowAll := 0
global gHookInfo := 0
global gLog := 0
global gEvalExpr := 0
global gEvalResult := 0
global gSnapshotExpr := 0
global gSnapshotResult := 0
global gInventoryResult := 0
global gPatchOld := 0
global gPatchNew := 0
global gPatchResult := 0
global gTraceName := 0
global gTraceResult := 0
global gObserveExpr := 0
global gObserveCond := 0
global gObserveResult := 0
global gForensicsResult := 0
global gWatcher := 0
global gPatchSession := 0

BuildGui()


BuildGui() {
    global gLv, gShowAll, gHookInfo, gLog
    global gEvalExpr, gEvalResult
    global gSnapshotExpr, gSnapshotResult
    global gInventoryResult
    global gPatchOld, gPatchNew, gPatchResult
    global gTraceName, gTraceResult
    global gObserveExpr, gObserveCond, gObserveResult
    global gForensicsResult
    global gWatcher, gPatchSession

    g := Gui(, "AhkLive Control Console")
    g.OnEvent("Close", (*) => ExitApp())
    g.SetFont("s10", "Consolas")

    g.Add("Text", "x12 y10", "AutoHotkey processes")
    gLv := g.Add("ListView", "x12 y28 w360 h220", ["PID", "Name", "Title"])
    gLv.OnEvent("DoubleClick", (*) => AttachSelected())
    gShowAll := g.Add("Checkbox", "x12 y252", "Show all processes")
    refresh := g.Add("Button", "x170 y250 w90", "Refresh")
    refresh.OnEvent("Click", (*) => RefreshList())
    attach := g.Add("Button", "x268 y250 w104", "Attach")
    attach.OnEvent("Click", (*) => AttachSelected())

    g.Add("Text", "x390 y10", "Hook")
    gHookInfo := g.Add("Edit", "x390 y28 w420 h90 ReadOnly", "not attached")

    tab := g.Add("Tab3", "x390 y128 w420 h250", ["Eval", "Snapshot", "Inventory", "Patch", "Observe", "Forensics"])

    tab.UseTab(1)
    g.Add("Text", "x402 y162", "Expression")
    gEvalExpr := g.Add("Edit", "x402 y180 w300 h32", "1 + 2 * 3")
    evalBtn := g.Add("Button", "x710 y180 w88 h32", "Eval")
    evalBtn.OnEvent("Click", (*) => DoEval())
    gEvalResult := g.Add("Edit", "x402 y220 w396 h120 ReadOnly", "")

    tab.UseTab(2)
    g.Add("Text", "x402 y162", "Name=Expression, comma-separated")
    gSnapshotExpr := g.Add("Edit", "x402 y180 w300 h32", "add=Add(2, 3), mul=Mul(4)")
    snapBtn := g.Add("Button", "x710 y180 w88 h32", "Snapshot")
    snapBtn.OnEvent("Click", (*) => DoSnapshot())
    gSnapshotResult := g.Add("Edit", "x402 y220 w396 h120 ReadOnly", "")

    tab.UseTab(3)
    invBtn := g.Add("Button", "x402 y180 w150 h30", "List functions")
    invBtn.OnEvent("Click", (*) => DoInventory())
    clsBtn := g.Add("Button", "x560 y180 w150 h30", "List classes")
    clsBtn.OnEvent("Click", (*) => DoClasses())
    gInventoryResult := g.Add("Edit", "x402 y218 w396 h122 ReadOnly", "")

    tab.UseTab(4)
    g.Add("Text", "x402 y162", "Old -> New")
    gPatchOld := g.Add("Edit", "x402 y180 w130", "Mul")
    g.Add("Text", "x538 y184", "->")
    gPatchNew := g.Add("Edit", "x556 y180 w130", "NewMul")
    patchBtn := g.Add("Button", "x694 y178 w102 h30", "Replace")
    patchBtn.OnEvent("Click", (*) => DoPatch())
    rollbackBtn := g.Add("Button", "x694 y250 w102 h30", "Rollback")
    rollbackBtn.OnEvent("Click", (*) => DoRollback())
    traceBtn := g.Add("Button", "x694 y214 w102 h30", "Trace")
    traceBtn.OnEvent("Click", (*) => DoTrace())
    g.Add("Text", "x402 y216", "Function to trace")
    gTraceName := g.Add("Edit", "x402 y236 w130", "Add")
    gPatchResult := g.Add("Edit", "x402 y274 w396 h66 ReadOnly", "")

    tab.UseTab(5)
    g.Add("Text", "x402 y162", "Watch expression")
    gObserveExpr := g.Add("Edit", "x402 y180 w300", "Mul(4)")
    g.Add("Text", "x402 y216", "Condition (optional)")
    gObserveCond := g.Add("Edit", "x402 y234 w300", "Mul(4) > 5")
    obsBtn := g.Add("Button", "x710 y180 w88 h30", "Start")
    obsBtn.OnEvent("Click", (*) => StartObserve())
    stopBtn := g.Add("Button", "x710 y216 w88 h30", "Stop")
    stopBtn.OnEvent("Click", (*) => StopObserve())
    gObserveResult := g.Add("Edit", "x402 y272 w396 h68 ReadOnly", "")

    tab.UseTab(6)
    reportBtn := g.Add("Button", "x402 y180 w150 h30", "Runtime report")
    reportBtn.OnEvent("Click", (*) => DoReport())
    exportBtn := g.Add("Button", "x560 y180 w150 h30", "Export CSV")
    exportBtn.OnEvent("Click", (*) => DoExport())
    gForensicsResult := g.Add("Edit", "x402 y218 w396 h122 ReadOnly", "")

    tab.UseTab()

    gLog := g.Add("Edit", "x12 y390 w798 h130 ReadOnly", "")
    g.Show("w822 h540")
    RefreshList()
}


Log(msg) {
    global gLog
    gLog.Value .= msg "`n"
}


RefreshList() {
    global gLv, gShowAll
    gLv.Delete()
    for proc in EnumProcesses() {
        if !gShowAll.Value and !RegExMatch(proc.name, "i)autohotkey")
            continue
        title := ""
        try
            title := WinGetTitle("ahk_pid " proc.pid)
        gLv.Add(, proc.pid, proc.name, title)
    }
    gLv.ModifyCol(1, "AutoHdr")
    gLv.ModifyCol(2, "AutoHdr")
    gLv.ModifyCol(3, "AutoHdr")
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


AttachSelected() {
    global gLv, gHookInfo, session
    row := gLv.GetNext()
    if !row {
        Log("select a process")
        return
    }
    pid := gLv.GetText(row, 1)
    result := session.Attach(Integer(pid))
    if !result.ok {
        Log("attach failed: " result.error)
        return
    }
    hook := session.hook
    gHookInfo.Value := "pid=" hook["pid"]
        . "`nmodule=" hook["module"]
        . "`nbase=0x" Format("{:X}", hook["image_base"])
        . "`nbif=" hook["builtins"]["count"]
        . " native=" hook["native_functions"]["count"]
        . " biv=" hook["builtin_vars"]["count"]
    Log("attached " pid)
}


DoEval() {
    global session, gEvalExpr, gEvalResult
    result := session.Eval(gEvalExpr.Value)
    if !result.ok {
        gEvalResult.Value := result.error
        return
    }
    gEvalResult.Value := result.value
}


DoSnapshot() {
    global session, gSnapshotExpr, gSnapshotResult
    specs := Map()
    for part in StrSplit(gSnapshotExpr.Value, ",") {
        item := Trim(part)
        if item = ""
            continue
        pair := StrSplit(item, "=", , 2)
        if pair.Length = 2
            specs[Trim(pair[1])] := Trim(pair[2])
    }
    result := session.Snapshot(specs)
    if !result.ok {
        gSnapshotResult.Value := result.error
        return
    }
    out := ""
    for name, value in result.value
        out .= name "=" value "`n"
    gSnapshotResult.Value := out
}


DoInventory() {
    global session, gInventoryResult
    result := session.ListFunctions()
    if !result.ok {
        gInventoryResult.Value := result.error
        return
    }
    out := ""
    for name, info in result.value
        out .= name "(" AhkLive._JoinList(info["params"]) ")`n"
    gInventoryResult.Value := out
}


DoClasses() {
    global session, gInventoryResult
    result := session.ListClasses()
    if !result.ok {
        gInventoryResult.Value := result.error
        return
    }
    out := ""
    for cls, methods in result.value {
        for method in methods
            out .= cls "." method "`n"
    }
    gInventoryResult.Value := out
}


DoPatch() {
    global session, gPatchOld, gPatchNew, gPatchResult, gPatchSession
    if !session.hook {
        gPatchResult.Value := "not attached"
        return
    }
    result := session.BeginPatch()
    if !result.ok {
        gPatchResult.Value := result.error
        return
    }
    ps := result.value
    patch := ps.Replace(gPatchOld.Value, gPatchNew.Value)
    if !patch.ok {
        ps.Rollback()
        gPatchResult.Value := patch.error
        return
    }
    gPatchSession := ps
    gPatchResult.Value := "patched. Rollback via patch session."
}


DoRollback() {
    global gPatchSession, gPatchResult
    if !gPatchSession {
        gPatchResult.Value := "no active patch"
        return
    }
    result := gPatchSession.Rollback()
    if !result.ok {
        gPatchResult.Value := result.error
        return
    }
    gPatchSession := 0
    gPatchResult.Value := "rolled back"
}


DoTrace() {
    global session, gTraceName, gTraceResult
    if !session.hook {
        gTraceResult.Value := "not attached"
        return
    }
    result := session.Trace(gTraceName.Value, A_Temp "\ahk_live_trace.log")
    if !result.ok {
        gTraceResult.Value := result.error
        return
    }
    gTraceResult.Value := "trace active"
}


StartObserve() {
    global session, gObserveExpr, gObserveCond, gObserveResult, gWatcher
    if !session.hook {
        gObserveResult.Value := "not attached"
        return
    }
    obs := AhkLiveObservability(session.hook)
    watcher := obs.WatchWhen(gObserveExpr.Value, gObserveCond.Value
        , ObserveCallback, 500)
    gWatcher := watcher
    gObserveResult.Value .= "watching`n"
}


StopObserve() {
    global gWatcher, gObserveResult
    if gWatcher {
        gWatcher["Stop"]()
        gWatcher := 0
    }
    gObserveResult.Value .= "stopped`n"
}


ObserveCallback(event) {
    global gObserveResult
    gObserveResult.Value .= event.value "`n"
}


DoReport() {
    global session, gForensicsResult
    if !session.hook {
        gForensicsResult.Value := "not attached"
        return
    }
    report := AhkLiveForensics.Report(session.hook)
    gForensicsResult.Value := "pid=" report["pid"]
        . " version=" report["version"]
        . "`nmodule=" report["module"]
        . "`nfunctions=" report["functions"].Count
        . " classes=" report["classes"].Count
        . "`nbif=" report["builtins"]
        . " native=" report["native_functions"]
        . " biv=" report["builtin_vars"]
}


DoExport() {
    global session, gForensicsResult
    if !session.hook {
        gForensicsResult.Value := "not attached"
        return
    }
    path := A_Temp "\ahk_live_inventory.csv"
    AhkLiveCompat.ExportCsv(session.hook, path)
    gForensicsResult.Value := path
}
