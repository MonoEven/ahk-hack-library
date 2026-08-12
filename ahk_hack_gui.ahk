#Requires AutoHotkey v2
#SingleInstance Force
#NoTrayIcon
#Include ahk_hack_single.ahk

; Command-line self-test without opening the window:
;   AutoHotkey64.exe ahk_hack_gui.ahk --selftest <pid>
if A_Args.Length >= 2 and A_Args[1] = "--selftest" {
    SelfTest(Integer(A_Args[2]))
    ExitApp 0
}

global guiHook := 0
global monitorExprText := ""
global monitorLast := ""
global monitorTickMs := 500
global gLv := 0
global gShowAll := 0
global gHookInfo := 0
global gLog := 0
global gEvalExpr := 0
global gEvalResult := 0
global gScriptEdit := 0
global gScriptResult := 0
global gRedirSrc := 0
global gRedirDst := 0
global gRedirResult := 0
global gMonitorExpr := 0
global gMonitorMs := 0
global gMonitorResult := 0

BuildGui()


BuildGui() {
    global gLv, gShowAll, gHookInfo, gLog
    global gEvalExpr, gEvalResult, gScriptEdit, gScriptResult
    global gRedirSrc, gRedirDst, gRedirResult
    global gMonitorExpr, gMonitorMs, gMonitorResult

    g := Gui(, "ahk-hack Remote Console")
    g.OnEvent("Close", (*) => ExitApp())
    g.SetFont("s10", "Consolas")

    g.Add("Text", "x12 y10", "AutoHotkey processes")
    gLv := g.Add("ListView", "x12 y28 w360 h240", ["PID", "Name", "Title"])
    gLv.OnEvent("DoubleClick", (*) => AttachSelected())
    gShowAll := g.Add("Checkbox", "x12 y276", "Show all processes")
    refresh := g.Add("Button", "x170 y274 w90", "Refresh")
    refresh.OnEvent("Click", (*) => RefreshList())
    attach := g.Add("Button", "x268 y274 w104", "Attach")
    attach.OnEvent("Click", (*) => AttachSelected())

    g.Add("Text", "x390 y10", "Hook")
    gHookInfo := g.Add("Edit", "x390 y28 w410 h90 ReadOnly", "not attached")

    g.Add("Text", "x390 y128", "Actions")
    tab := g.Add("Tab3", "x390 y148 w410 h232", ["Eval", "Script", "Redirect", "Monitor", "Inspect"])

    tab.UseTab(1)
    gEvalExpr := g.Add("Edit", "x402 y180 w246 h48", "1 + 2 * 3")
    evalRun := g.Add("Button", "x656 y180 w132 h48", "RemoteEval")
    evalRun.OnEvent("Click", (*) => DoEval())
    gEvalResult := g.Add("Edit", "x402 y236 w386 h128 ReadOnly", "")

    tab.UseTab(2)
    gScriptEdit := g.Add("Edit", "x402 y180 w386 h100", "
        (
        add(a, b) {
            return a + b
        }
        add(1, 2)
        )")
    scriptRun := g.Add("Button", "x656 y288 w132 h36", "RemoteEvalScript")
    scriptRun.OnEvent("Click", (*) => DoScript())
    gScriptResult := g.Add("Edit", "x402 y332 w386 h52 ReadOnly", "")

    tab.UseTab(3)
    g.Add("Text", "x402 y180", "Redirect builtin")
    gRedirSrc := g.Add("Edit", "x402 y198 w110", "Abs")
    g.Add("Text", "x520 y202", "->")
    gRedirDst := g.Add("Edit", "x536 y198 w110", "Sin")
    tableBtn := g.Add("Button", "x656 y196 w132 h26", "Table")
    tableBtn.OnEvent("Click", (*) => DoRedirect(false))
    deepBtn := g.Add("Button", "x656 y228 w132 h26", "Deep")
    deepBtn.OnEvent("Click", (*) => DoRedirect(true))
    gRedirResult := g.Add("Edit", "x402 y266 w386 h90 ReadOnly", "")

    tab.UseTab(4)
    g.Add("Text", "x402 y180", "Watch expression")
    gMonitorExpr := g.Add("Edit", "x402 y198 w386 h40", "x")
    g.Add("Text", "x402 y246", "Interval (ms)")
    gMonitorMs := g.Add("Edit", "x402 y264 w90", "500")
    startBtn := g.Add("Button", "x500 y262 w90 h26", "Start")
    startBtn.OnEvent("Click", (*) => StartMonitor())
    stopBtn := g.Add("Button", "x598 y262 w90 h26", "Stop")
    stopBtn.OnEvent("Click", (*) => StopMonitor())
    gMonitorResult := g.Add("Edit", "x402 y296 w386 h58 ReadOnly", "")

    tab.UseTab(5)
    verBtn := g.Add("Button", "x402 y180 w150 h28", "Read version")
    verBtn.OnEvent("Click", (*) => InspectVersion())
    dumpBtn := g.Add("Button", "x560 y180 w150 h28", "Dump tables")
    dumpBtn.OnEvent("Click", (*) => DumpTables())
    g.Add("Text", "x402 y220 w386 h120", "Dump writes BIF / native / BIV tables"
        . "`n to A_Temp\ahk_hook_dump.txt. Read-only"
        . "`n operations are safe for the target.")

    tab.UseTab()

    gLog := g.Add("Edit", "x12 y390 w788 h130 ReadOnly", "")
    g.Show("w810 h540")
    RefreshList()
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
                list.Push({pid: pid, name: name})
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


AttachSelected() {
    global gLv
    row := gLv.GetNext(0, "Focused")
    if !row {
        Log("select a process first")
        return
    }
    AttachTo(gLv.GetText(row, 1))
}


AttachTo(pid) {
    global guiHook, gHookInfo
    try {
        guiHook := AhkMagic.AttachRemote(Integer(pid))
        info := "module=" guiHook["module"] "`n"
            . "base=0x" Format("{:X}", guiHook["image_base"]) "`n"
            . "bif=" guiHook["builtins"]["count"]
            . " native=" guiHook["native_functions"]["count"]
            . " biv=" guiHook["builtin_vars"]["count"]
        try
            info .= "`nversion=" AhkMagic.RemoteEval(guiHook, "A_AhkVersion")
        gHookInfo.Value := info
        Log("attached pid=" pid " module=" guiHook["module"])
    } catch as e {
        guiHook := 0
        gHookInfo.Value := "attach failed"
        Log("attach FAIL " e.What " | " e.Message)
    }
}


RequireHook() {
    global guiHook
    if !guiHook
        throw Error("attach to a process first", -1)
    return guiHook
}


DoEval() {
    global gEvalExpr, gEvalResult
    try {
        hook := RequireHook()
        r := AhkMagic.RemoteEval(hook, gEvalExpr.Value)
        gEvalResult.Value := r
        Log("eval " gEvalExpr.Value " => " r)
    } catch as e {
        gEvalResult.Value := "FAIL " e.Message
        Log("eval FAIL " e.Message)
    }
}


DoScript() {
    global gScriptEdit, gScriptResult
    try {
        hook := RequireHook()
        r := AhkMagic.RemoteEvalScript(hook, gScriptEdit.Value)
        gScriptResult.Value := r
        Log("script result => " r)
    } catch as e {
        gScriptResult.Value := "FAIL " e.Message
        Log("script FAIL " e.Message)
    }
}


DoRedirect(deep) {
    global gRedirSrc, gRedirDst, gRedirResult
    try {
        hook := RequireHook()
        src := Trim(gRedirSrc.Value)
        dst := Trim(gRedirDst.Value)
        if !src or !dst
            throw Error("source and destination names are required", -1)
        if deep {
            r := AhkMagic.RemoteDeepRedirect(hook, src, dst)
            gRedirResult.Value := "deep redirected " src " -> " dst
                . " at " r["count"] " object(s)"
            Log("deep redirect " src " -> " dst " (" r["count"] ")")
        } else {
            r := AhkMagic.RemoteRedirect(hook, src, dst)
            gRedirResult.Value := "redirected " src " -> " dst
                . " at 0x" Format("{:X}", r["fn_slot"])
            Log("redirect " src " -> " dst)
        }
    } catch as e {
        gRedirResult.Value := "FAIL " e.Message
        Log("redirect FAIL " e.Message)
    }
}


StartMonitor() {
    global gMonitorExpr, gMonitorMs, gMonitorResult
    global monitorExprText, monitorLast, monitorTickMs
    try {
        RequireHook()
        monitorExprText := gMonitorExpr.Value
        monitorLast := ""
        monitorTickMs := Max(50, Integer(gMonitorMs.Value))
        gMonitorResult.Value := ""
        SetTimer(MonitorTick, monitorTickMs)
        Log("monitor started: " monitorExprText)
    } catch as e {
        Log("monitor start FAIL " e.Message)
    }
}


StopMonitor() {
    SetTimer(MonitorTick, 0)
    Log("monitor stopped")
}


MonitorTick() {
    global guiHook, monitorExprText, monitorLast, monitorTickMs
    global gMonitorResult
    if !guiHook {
        StopMonitor()
        return
    }
    try {
        v := AhkMagic.RemoteEval(guiHook, monitorExprText)
        if v != monitorLast {
            monitorLast := v
            gMonitorResult.Value := v
            Log("watch " monitorExprText " = " v)
        }
    } catch as e {
        Log("monitor FAIL " e.Message)
    }
}


InspectVersion() {
    try {
        hook := RequireHook()
        v := AhkMagic.RemoteEval(hook, "A_AhkVersion")
        Log("version=" v)
    } catch as e {
        Log("version FAIL " e.Message)
    }
}


DumpTables() {
    try {
        hook := RequireHook()
        outFile := A_Temp "\ahk_hook_dump.txt"
        try FileDelete(outFile)
        FileAppend("module=" hook["module"] "`n"
            . "base=0x" Format("{:X}", hook["image_base"]) "`n", outFile)
        for kind, key in Map("builtins", "bif", "native_functions", "mdfunc"
            , "builtin_vars", "biv") {
            table := hook[kind]
            FileAppend("`n[" key "] count=" table["count"]
                . " table_rva=0x" Format("{:X}", table["table_rva"])
                . " stride=0x" Format("{:X}", table["stride"]) "`n", outFile)
            for name, e in table["entries"] {
                if key = "bif"
                    line := Format("  {1} rva=0x{2:X} min={3} max={4} fid={5}`n"
                        , name, e["rva"], e["min"], e["max"], e["fid"])
                else if key = "mdfunc"
                    line := Format("  {1} rva=0x{2:X} ret={3}`n"
                        , name, e["rva"], e["ret"])
                else
                    line := Format("  {1} getter=0x{2:X} setter=0x{3:X}`n"
                        , name, e["getter_rva"], e["setter_rva"])
                FileAppend(line, outFile)
            }
        }
        Log("tables dumped to " outFile)
    } catch as e {
        Log("dump FAIL " e.Message)
    }
}


Log(msg) {
    global gLog
    stamp := SubStr(A_Now, 9, 2) ":" SubStr(A_Now, 11, 2) ":" SubStr(A_Now, 13, 2)
    gLog.Value .= "[" stamp "] " msg "`n"
}


SelfTest(pid) {
    outFile := A_Temp "\ahk_hack_gui_selftest.out"
    try FileDelete(outFile)
    Write(msg) {
        FileAppend(msg "`n", outFile)
    }
    Write("pid=" pid)
    try {
        hook := AhkMagic.AttachRemote(pid)
        Write("module=" hook["module"])
        Write("base=0x" Format("{:X}", hook["image_base"]))
        Write("bif=" hook["builtins"]["count"]
            . " native=" hook["native_functions"]["count"]
            . " biv=" hook["builtin_vars"]["count"])
        Write("eval=" AhkMagic.RemoteEval(hook, "1 + 2 * 3"))
        Write("evalstr=" AhkMagic.RemoteEval(hook, "Format('x{:.1f}', 1.5)"))
        Write("version=" AhkMagic.RemoteEval(hook, "A_AhkVersion"))
        script := "
        (
        add(a, b) {
            return a + b
        }
        add(1, 2)
        )"
        Write("script=" AhkMagic.RemoteEvalScript(hook, script))
        Write("PASS")
        ExitApp 0
    } catch as e {
        Write("FAIL " e.What " | " e.Message " | line " e.Line)
        ExitApp 1
    }
}
