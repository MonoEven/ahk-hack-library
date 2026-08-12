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

### Scriptable eval from the command line

The same attach path is exposed as `--eval` and `--script`, so any external
driver (PowerShell, CI, a coding agent, or another AutoHotkey process) can
interrogate a running target without opening the GUI:

```powershell
AutoHotkey64.exe ahk_hack_gui.ahk --eval <pid> "1 + 2 * 3"
AutoHotkey64.exe ahk_hack_gui.ahk --script <pid> add.ahk
```

`--eval` writes the evaluated value to
`%TEMP%\ahk_hack_gui_eval.out`; `--script` loads the file through the
target's own parser and writes the last expression result to
`%TEMP%\ahk_hack_gui_script.out`. Failures write a `FAIL ...` line and
return a nonzero exit code.

## Beyond debugging

Attach-and-eval tooling has a longer history in other runtimes: CPython 3.14
adds PEP 768 as a safe external debugger interface so `pdb` can attach to a
running process; Frida hooks functions and calls into them from outside the
target; Arthas attaches to JVMs to inspect state and redefine class bodies;
DTrace exposes dynamic tracing on live systems. The remote console maps the
same ideas onto AutoHotkey, and most of them work on interpreted, compiled,
and UPX-packed builds because the hook reads the runtime tables from memory
instead of relying on debug symbols or a built-in attach API.

Concrete directions worth building on top of `AttachRemote`:

- **Live hotfix and hot reload.** A long-running resident script can receive
  a replacement function or class through `RemoteEvalScript`, then have its
  callers switched with `RemoteReplaceFuncBody`, without losing in-memory
  state or restarting hotkeys/timers. This mirrors Arthas-style redefine and
  editor hot reload, but for scripts that have no official reload path.
- **Fault injection and chaos testing.** Redirect a builtin to another one,
  or inject a failing function, to force error branches in CI or staging.
  Because `RemoteDeepRedirect` also changes already-resolved call sites, it
  covers paths that a source-level mock cannot reach without a rebuild.
- **Support triage on production-like machines.** Attach to a target that
  cannot be stopped, read counters and timer state with `RemoteEval`, and
  dump the interpreter tables for forensic or capacity questions. The CLI
  modes make this scriptable from PowerShell or a support playbook.
- **Agent and IDE orchestration.** `--eval` and `--script` give a coding
  agent, a CI job, or an editor extension a narrow command surface for
  querying a live AutoHotkey process and applying small patches.
- **Interpreter research and compatibility tooling.** Dump the same table
  structures across versions and compiled formats, diff RVAs, and keep a
  regression suite that detects when a new build moves a parser layout.
- **Authorized security analysis.** With an owned process or a disposable
  VM, the same primitives can exercise hook detection, verify whether a
  script is packed, or inspect what a suspicious compiled exe does after
  unpacking in memory. This is a dual-use area: process injection is also
  catalogued as MITRE T1055, so only run it on targets you control and keep
  experiments isolated.

## Safety

The GUI is a research tool. Attach only to processes you own. Redirects and
script injection modify target memory and can crash the target if misused;
AV/EDR may flag executable-memory allocation and remote threads. For safe
experiments, keep a disposable target process and restart it between runs.
