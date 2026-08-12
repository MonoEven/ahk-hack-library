# AhkLive

AhkLive is a separate live-inspection layer built on the `AhkMagic` remote
primitives. It does not modify `ahk_hack_single.ahk`.

## Entry point

```ahk
#Include lib\ahk_live\init.ahk
```

The entry point loads the AhkMagic core and then `ahk_live.ahk`.

## API

| Method | Purpose |
| --- | --- |
| `Attach(pid)` | Attach to a running AutoHotkey process. |
| `AttachByName(name)` | Attach by executable name. |
| `Eval(hook, expr)` | Evaluate an expression in the target. |
| `LoadScript(hook, text)` | Load multi-line script text in the target. |
| `Snapshot(hook, specs)` | Evaluate a `Map` of names to expressions and return a `Map`. |
| `Watch(hook, expr, onChange, ms)` | Poll an expression and call `onChange` when its value changes. |
| `TraceFunction(hook, name, outFile)` | Redirect a user function through a logging wrapper. |
| `Untrace(hook, tracer)` | Restore the original function. |
| `ReplaceFunction(hook, oldName, newName)` | Replace one user function body with another. |
| `RestoreFunction(hook, record)` | Restore the original function body. |

## Example

```ahk
hook := AhkLive.Attach(pid)

snap := AhkLive.Snapshot(hook, Map(
    "add", "Add(2, 3)",
    "mul", "Mul(4)"
))

tracer := AhkLive.TraceFunction(hook, "Add", A_Temp "\trace.log")
result := AhkLive.Eval(hook, "Add(2, 3)")
AhkLive.Untrace(hook, tracer)

record := AhkLive.ReplaceFunction(hook, "Mul", "NewMul")
result := AhkLive.Eval(hook, "Mul(4)")
AhkLive.RestoreFunction(hook, record)
```

## Limits

- `TraceFunction` currently supports user-defined functions with at least two
  required parameters. Optional, ByRef, and single-parameter tracing are not
  supported yet.
- `ReplaceFunction` swaps function body addresses. The replacement body should
  not depend on parameters unless its parameter layout matches the original
  function exactly; this is best used for constant or mock bodies.
- The target and the attacher must be the same interpreter family. Windows x64
  only.
- Renamed and injected functions are left in the target process. Use a
  disposable target for repeated experiments.

## Safety

Only attach to processes you own. Function replacement and tracing modify
interpreter memory and can crash the target or trigger AV/EDR.
