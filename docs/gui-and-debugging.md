# ahk-hack Remote Console

`ahk_hack_gui.ahk` is a small GUI on top of `AhkMagic` for working with a
running AutoHotkey process without changing its source. It lists running
AutoHotkey processes, attaches to one, and exposes the remote hook APIs as
buttons and text fields.

## Workflow

1. Launch the GUI with `AutoHotkey64.exe ahk_hack_gui.ahk`.
2. Click **Refresh** to enumerate AutoHotkey processes. Enable **Show all
   processes** to include compiled exes and other executables.
3. Select a process and click **Attach**. The hook panel shows the module,
   image base, and table counts; the version is read back with a remote eval.
4. Use the tabs:
   - **Eval**: evaluate an expression inside the target.
   - **Script**: load a multi-line script, including function and class
     definitions, through the target's own loader.
   - **Redirect**: point a builtin at another builtin, either in the BIF table
     or in already-resolved `Func` objects.
   - **Monitor**: watch an expression on a timer and log value changes.
   - **Inspect**: read `A_AhkVersion` or dump the three interpreter tables to
     `%TEMP%\ahk_hook_dump.txt`.

All operations go through the same `AttachRemote` / `RemoteEval` /
`RemoteEvalScript` / `RemoteRedirect` / `RemoteDeepRedirect` paths used by the
test suite, so a process that passes the tests can be driven from the GUI.

## What it is useful for

### Live variable and state inspection

A resident script usually exposes state through hotkeys or files. With the GUI
you can read any global or expression directly:

```ahk
RemoteEval(hook, "x")
RemoteEval(hook, "Format('x{:.1f}', 1.5)")
```

The monitor tab turns this into a cheap watchpoint: poll an expression and log
only when the value changes. That is useful for tracking counters, timers, or
UI state while the script keeps running.

### Function-level experiments without a rebuild

`RemoteRedirect` changes future dynamic lookups; `RemoteDeepRedirect` changes
already-resolved function objects, so a function that directly calls `Abs()`
starts returning `Sin()` as well. This lets you test alternative behavior in
the live interpreter and observe downstream effects before touching source.

`RemoteEvalScript` can inject replacement functions and classes:

```ahk
NewA(x) {
    return 42
}
```

`RemoteReplaceFuncBody` then swaps the old body pointer, so a caller like
`B_add(x) := A(x)` returns the new result without restarting the target.

### Debugging compiled and packed builds

Ahk2Exe-compiled exes embed the same runtime. The GUI can attach to them,
including UPX/MPRESS-packed builds, because the tables are read from the
unpacked image in memory. This makes it possible to inspect and probe a
packaged script at runtime even when you only have the exe.

### Cross-version interpreter research

The same GUI works against 2.0-beta.10, 2.0.0, 2.0.26, and 2.1-alpha.30.
Dumping the BIF / native / BIV tables side by side shows which RVAs changed
and which stayed stable, which is exactly what the runtime-discovery layer
must tolerate.

### Test and QA automation

The `--selftest` mode runs the same attach + eval + script path headlessly:

```powershell
AutoHotkey64.exe ahk_hack_gui.ahk --selftest <pid>
```

The result is written to `%TEMP%\ahk_hack_gui_selftest.out`, so the GUI's
underlying logic can be verified in CI or from a script without opening a
window.

## Safety

The GUI is a research tool. Attach only to processes you own. Redirects and
script injection modify target memory and can crash the target if misused;
AV/EDR may flag executable-memory allocation and remote threads. For safe
experiments, keep a disposable target process and restart it between runs.
