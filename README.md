# ahk-hack

![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)
![AutoHotkey](https://img.shields.io/badge/AutoHotkey-v2-green.svg)
![Platform](https://img.shields.io/badge/platform-Windows%20x64-lightgrey.svg)

Runtime structure scanner for AutoHotkey executables, implemented as embedded
x64 machine code inside an AutoHotkey v2 library.

The core capability is **scanning**: at runtime, the library locates the
interpreter tables (`g_BIF`, `sMdFunc`, `g_BIV_A`) of the currently running
`AutoHotkey.exe`, and can enumerate the PE export table of any loaded
DLL/EXE. Everything else, including native AHK array construction and the
optional cnumpy bridge, is built on that scanning layer.

Repository: [https://github.com/MonoEven/ahk-hack-library](https://github.com/MonoEven/ahk-hack-library)

Practice integration: [https://github.com/MonoEven/cnumpy](https://github.com/MonoEven/cnumpy)

---

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [API Reference](#api-reference)
- [Lifecycle and Ownership](#lifecycle-and-ownership)
- [Security](#security)
- [Performance](#performance)
- [Supported Versions](#supported-versions)
- [Project Layout](#project-layout)
- [Building from Source](#building-from-source)
- [Testing](#testing)
- [License](#license)

## Features

- **Version-independent interpreter scanning.** The same machine-code blob
  discovers `g_BIF`, `sMdFunc`, and `g_BIV_A` across AutoHotkey 2.0-beta.10
  through 2.1-alpha.30 without per-version offsets.
- **Generic PE export scanning.** `AhkMagic.ScanExports()` parses the export
  directory of any loaded module and returns every named export with its
  function RVA and ordinal.
- **Runtime built-in redirection.** `PatchBif()` can temporarily re-point a
  built-in C function and `RestoreBif()` restores it.
- **Expression eval.** `AhkMagic.Eval()` tries the interpreter's in-process
  expression pipeline first and falls back to `EvalSubprocess()` for
  expressions it cannot evaluate yet. `EvalNative()` is the in-process core.
- **Optional cnumpy bridge.** `CnpBridge` converts `CnpArray` to native AHK
  values, supports zero-copy views, and is validated by 1D/2D/3D tests.
- **Self-contained at runtime.** No Python, no external scanner, no
  interpreter source changes. clang is needed only to rebuild the embedded
  machine code.
- **Single-file core.** `ahk_hack_single.ahk` contains the whole scanning
  core; `ahk_hack_demo.ahk` runs a self-test.

## Architecture

The machine code is written in C under `lib/mcode/`, compiled with clang into
freestanding, position-independent functions, and embedded into
`lib/ahk_hack.ahk` as raw hex. The build tool refuses to embed `.text` if any
relocation escapes the blob.

| Blob | Source | Purpose |
| --- | --- | --- |
| Interpreter scanner | `lib/mcode/scanner.c` | Locates `g_BIF`, `sMdFunc`, `g_BIV_A` |
| Export scanner | `lib/mcode/export_scanner.c` | Generic PE export-table scan |
| Internal locator | `lib/mcode/internal_locator.c` | Dynamically locates EvalNative internals (`g_script`, `FinalizeExpression`, `FindOrAddVar`, CRT free, `SYM_INVALID`) |
The AHK entry point is `lib/init.ahk`, which loads only the scanning core.
The cnumpy integration lives in `lib/cnumpy/` and is optional.

## Quick Start

### Core scanning

```ahk
#Include lib\init.ahk

AhkMagic.Init()
MsgBox AhkMagic.Summary()

absRva := AhkMagic.BifRva("Abs")
absAddr := AhkMagic.BifAddr("Abs")
```

### Export scanning

```ahk
hmod := DllCall("LoadLibraryW", "Str", "D:\path\cnumpy_ahk.dll", "Ptr")
exports := AhkMagic.ScanExports(hmod)
MsgBox exports.Count
```

### Runtime redirection

```ahk
old := AhkMagic.PatchBif("Abs", "Sin")
name := "Abs"
MsgBox %name%(1)               ; first dynamic call returns sin(1)
AhkMagic.RestoreBif("Abs", old)
```

### Expression eval

```ahk
MsgBox AhkMagic.EvalNative("1 + 2 * 3")     ; 7, in-process
MsgBox AhkMagic.EvalNative("Abs(-5)")       ; 5, in-process
MsgBox AhkMagic.EvalNative("SubStr(`"abc`", 2)") ; "bc", in-process
MsgBox AhkMagic.Eval("StrLen(`"hello`")")   ; 5, in-process first
MsgBox AhkMagic.EvalSubprocess("Format(`"{:.2f}`", Sin(1))") ; explicit subprocess
```

### Optional cnumpy integration

```ahk
Numpy.DllPath := "D:\...\build\x64\Release\cnumpy_ahk.dll"
#Include lib\cnumpy\init.ahk

ahk := CnpBridge.ToAhkNative(arr)   ; N-D deep copy, runtime-discovered layout
view := CnpBridge.View(arr)         ; zero-copy read/write view
```

## Examples

- `ahk_hack_demo.ahk` - runnable self-test: interpreter table inventory,
  distinct built-in C functions, kernel32 export scan, built-in redirection,
  and Eval.
- `examples/ahk_hack_export_inventory.ahk` - dumps a module's exports to CSV,
  with an optional name filter.
- `examples/ahk_hack_builtin_probe.ahk` - prints RVA, absolute address, and
  parameter counts for built-in functions by name.

```powershell
& D:\...\AutoHotkey64.exe ahk_hack_demo.ahk
& D:\...\AutoHotkey64.exe examples\ahk_hack_export_inventory.ahk kernel32.dll Virtual
& D:\...\AutoHotkey64.exe examples\ahk_hack_builtin_probe.ahk Abs StrLen
```

## API Reference

### AhkMagic

| Method | Description |
| --- | --- |
| `Init()` | Scans the running AutoHotkey executable and builds `bif`, `mdfunc`, `biv` maps |
| `Summary()` | Returns table addresses and entry counts |
| `BifRva(name)` / `BifAddr(name)` | RVA / absolute address of a built-in C function |
| `ScanExports(moduleBase)` | Returns `Map(name -> {rva, ordinal})` for a loaded module |
| `PatchBif(name, newName)` / `RestoreBif(name, oldPtr)` | Temporarily redirect and restore a built-in |
| `PatchBifObject(fnObj, newName)` / `RestoreBifObject(fnObj, state)` | Deep-redirect an already-resolved built-in so direct calls are affected |
| `Eval(expr)` | Tries the in-process pipeline, then `EvalSubprocess()` for unsupported expressions |
| `EvalSubprocess(expr)` | Evaluates an expression string in a hidden child process |
| `EvalNative(expr)` | Evaluates literals, operators, variables, and function calls through the interpreter's in-process expression pipeline |

### CnpBridge

| Method | Description |
| --- | --- |
| `Metadata(arr)` | Read-only `CnpArray` metadata peek |
| `ToAhk(arr)` | Deep copy to nested AHK `Array` (cnumpy conversion path) |
| `ToAhkFast(arr)` | Deep copy via raw element reads |
| `ToAhkNative(arr)` | Deep copy with machine-code Array construction |
| `View(arr)` | Zero-copy read/write view |
| `ToBuffer(arr)` | Raw bytes copied into an AHK `Buffer` |
| `FromAhk(data, dtype)` / `FromAhkFast(data, dtype)` | Nested AHK `Array` to `NdArray` |
| `FromBuffer(buffer, dtype)` | `Buffer` to `NdArray` (copy semantics) |
| `WriteRaw(arr, flat)` | Writes exact-dtype bytes into a C-contiguous array |

## Lifecycle and Ownership

All conversion APIs except `CnpView` use copy semantics. `CnpView` borrows
cnumpy memory and holds a strong reference to the owner `NdArray`, so the
underlying array cannot be freed while the view is alive. Writes through the
view require a writeable array. See
[`docs/lifecycle-and-ownership.md`](fork/cnumpy-ahk-bridge/docs/lifecycle-and-ownership.md)
for the full contract.

The cnumpy bridge does not hardcode `CnpArray` offsets. Data pointers come
from `cnp_ahk_data_ptr`, dtype kind from `cnp_dtype_kind`, and native Array
construction uses `AhkLayout.Discover()` with cnumpy's own
`cnp_ahk_fill_array_flat` / `cnp_ahk_fill_array_nd` fillers.

## Security

> This library allocates executable memory, executes machine code, and reads
> or writes interpreter internals directly. Treat it as a reverse-engineering
> research tool.

Operations fall into three categories:

- **Read-only:** `Init`, `Summary`, `BifRva`, `BifAddr`, `ScanExports`,
  `Metadata`, and `CnpView` reads. These do not modify process state.
- **Mutating:** `PatchBif`, `RestoreBif`, `WriteRaw`, and `CnpView.Set`.
  Wrong offsets, types, or ordering can crash the interpreter.
- **Executing:** `Eval` and `EvalNative`. This is arbitrary expression/code
  execution.

Key risks:

- Executable-memory allocation and internal function calls may be flagged by
  antivirus or EDR.
- Offsets are derived from the AutoHotkey 2.0.26 source. Other versions,
  compilers, or architectures may differ. Run the test suite against the
  target exe first.
- Never eval untrusted input. Never leave `PatchBif` enabled in production.
- `EvalNative` builds a temporary `Line`/`ArgStruct` inside the interpreter.
  Variable/function derefs are resolved through the interpreter's own var
  table; unsupported syntax fails loudly instead of degrading silently.
  Internal addresses and enum deltas such as `SYM_INVALID` are discovered
  at runtime by the embedded locator, not hardcoded per version.
- Never use `CnpView` after its owner reference is released.
- Do not substitute external `Buffer` memory for the internal `mItem` of an
  `Array()`; it causes a double free.
- 32-bit AutoHotkey is not supported; `Init()` raises an explicit error.

Recommended workflow: test in a VM or isolated environment, back up the exe,
record its SHA256, and only analyze software you are authorized to research.
This library is not intended to bypass licensing, DRM, or access controls.

## Performance

Measured with QPC on a 64-bit Windows host using AutoHotkey 2.0.26.

| Scenario | Result |
| --- | --- |
| `ToAhkNative`, 100,000,000 float64 elements | ~705 ms |
| `ToBuffer`, 800 MB memcpy | ~206 ms |
| `CnpView` create | ~0.011 ms |
| `ToAhkNative`, 1000x1000 2D | ~14.9 ms |
| `ToAhk` (old AHK loop), 1000x1000 2D | ~466 ms |

The early "1M elements under 1 ms" figure was a timer-resolution artifact;
the 100M measurement is the real figure.

## Supported Versions

- AutoHotkey 2.1-alpha.30 (64-bit)
- AutoHotkey 2.0.26 (64-bit)
- AutoHotkey 2.0.0 (64-bit)
- AutoHotkey 2.0-beta.10 (64-bit)

`EvalNative` is verified on AutoHotkey 2.1-alpha.30, 2.0.26, 2.0.0, and
2.0-beta.10 (all x64).

## Project Layout

```text
lib/
  init.ahk                  core entry, scanning only
  ahk_hack.ahk              MCode() + AhkMagic
  mcode/                    machine-code C sources
  cnumpy/                   optional cnumpy integration
tools/
  build_mcode.py            compiles and embeds the machine code
  ahk_inspect.py            Python/PE cross-check analyzer
  locate_internal_functions.py locates the internal expression parser/evaluator
tests/                      core, export, and eval tests
examples/                   export inventory and built-in probe demos
fork/cnumpy-ahk-bridge/     cnumpy integration tests and benchmarks
blog_ahk_hack.txt           blog post (ZH)
blog_ahk_hack_en.txt        blog post (EN)
ahk_hack_single.ahk         standalone single-file core
ahk_hack_demo.ahk           runnable self-test demo
```

## Building from Source

Requirements: LLVM clang (for example `F:\Tech\LLVM\bin\clang.exe`).

```powershell
python tools\build_mcode.py --embed-only --out lib\ahk_hack.ahk
```

The build compiles all C sources under `lib/mcode/`, verifies that no
relocation escapes the `.text` blob, and writes the machine code back into
`lib/ahk_hack.ahk`.

## Locating internal expression functions

`tools/locate_internal_functions.py` finds the addresses of
`Line::ExpressionToPostfix` and `Line::ExpandExpression` in a given
AutoHotkey exe, using error-string fingerprints and RIP-relative xrefs:

```powershell
python tools\locate_internal_functions.py D:\...\AutoHotkey64.exe
```

These RVAs are consumed by `AhkMagic.EvalNative()`, which builds a temporary
`Line`/`ArgStruct` and calls the interpreter's own compiler and evaluator
directly instead of launching a child process.

## Testing

```powershell
python -m unittest discover -s tests -p 'test_*.py' -v

# Core scan and built-in patch demo
& D:\...\AutoHotkey64.exe tests\ahk_mcode_test.ahk

# Generic PE export scan
& D:\...\AutoHotkey64.exe tests\export_scan_test.ahk

# In-process expression eval
& D:\...\AutoHotkey64.exe tests\evalnative_probe.ahk

# Per-version internal address probe
& D:\...\AutoHotkey64.exe tests\version_probe.ahk

# cnumpy integration, including 1D/2D/3D native construction
& D:\...\AutoHotkey64.exe fork\cnumpy-ahk-bridge\tests\cnumpy_bridge.test.ahk
```

## License

MIT. See [LICENSE](LICENSE).
