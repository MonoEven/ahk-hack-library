# ahk-hack library

GitHub: [https://github.com/MonoEven/ahk-hack-library](https://github.com/MonoEven/ahk-hack-library)

The core of this project is **runtime structure scanning** of AutoHotkey
executables and arbitrary PE modules, implemented as embedded x64 machine
code inside an AHK v2 library.  cnumpy array conversion is a practice
integration built on top of the scanner, not the core.

At runtime, `lib/ahk_hack.ahk` scans the currently running
`AutoHotkey.exe` and locates the interpreter's main tables:

| Table | Content | x64 stride |
| --- | --- | --- |
| `g_BIF` | built-in script functions (`Abs`, `Sin`, ...) | `0x20` |
| `sMdFunc` | typed native functions (`MsgBox`, `WinActivate`, ...) | `0x28` |
| `g_BIV_A` | built-in variables (`A_AhkPath`, `A_YYYY`, ...) | `0x18` |

The machine code is generated from C sources under `lib/mcode/` with clang
and embedded as raw hex.  No Python or external analyzer is needed when the
AHK file runs.

## Library layout

```text
lib/
  init.ahk                  core entry (scanning only)
  ahk_hack.ahk              MCode() + AhkMagic
  mcode/                    C sources of the machine-code blobs
  cnumpy/                   optional practice integration (numpy + bridge)
tools/
  build_mcode.py            compiles lib/mcode and embeds into lib/ahk_hack.ahk
  ahk_inspect.py            Python/PE cross-check analyzer
tests/                      core scanner + export scan + eval tests
fork/cnumpy-ahk-bridge/     cnumpy integration tests and benchmarks
```

## Usage

Core scanning:

```ahk
#Include lib\init.ahk

AhkMagic.Init()
MsgBox AhkMagic.Summary()
absRva := AhkMagic.BifRva("Abs")
exports := AhkMagic.ScanExports(dllBase)
```

Runtime magic enabled by scanning:

```ahk
old := AhkMagic.PatchBif("Abs", "Sin")
name := "Abs"
MsgBox %name%(1)              ; now returns sin(1)
AhkMagic.RestoreBif("Abs", old)
MsgBox AhkMagic.Eval("1 + 2 * 3")
```

Optional cnumpy integration:

```ahk
Numpy.DllPath := "D:\...\cnumpy_ahk.dll"
#Include lib\cnumpy\init.ahk
ahk := CnpBridge.ToAhkNative(arr)
```

See `lib/README.md` for details.

## Rebuilding the machine code

Requirements: LLVM clang (`F:\Tech\LLVM\bin\clang.exe` in this environment).

```powershell
python tools\build_mcode.py --embed-only --out lib\ahk_hack.ahk
```

The build refuses to embed `.text` if any relocation escapes the blob.

## Verified versions

The same mcode blob and tests pass against:

- AutoHotkey 2.1-alpha.30 (64-bit)
- AutoHotkey 2.0.26 (64-bit)
- AutoHotkey 2.0.0 (64-bit)
- AutoHotkey 2.0-beta.10 (64-bit)

## Scanning beyond AHK

`AhkMagic.ScanExports(moduleBase)` parses the PE export directory of any
loaded DLL/EXE in machine code and returns every named export with its
function RVA and ordinal.  The cnumpy integration uses it to enumerate all
1027 exports of `cnumpy_ahk.dll` without hardcoding a binding table.

## Native AHK array construction

`AhkMagic.BuildArrayFlat()` and `AhkMagic.BuildArrayChildren()` fill the
internal `mItem`/`mLength`/`mCapacity` fields of real `Array()` objects
directly (layout from the AHK v2 source), including nested N-D trees via
`SYM_OBJECT` child variants.  `CnpBridge.ToAhkNative()` uses this to convert
100,000,000 float64 elements in ~705 ms (QPC), and a 1000x1000 2-D array in
~15 ms instead of ~466 ms through an AHK loop.

## Adaptive Array layout (no mcode)

`lib/ahk_layout.ahk` discovers the running interpreter's `Array()` layout at
runtime by mutation-diffing live objects and cross-validating with a second
probe set.  It contains no hardcoded Array offsets and executes no machine
code.  Verified offsets:

| AHK version | mItem | mLength | mCapacity |
| --- | --- | --- | --- |
| 2.1-alpha.30 | `0x28` | `0x30` | `0x34` |
| 2.1-alpha.1 / 2.0.26 / 2.0.0 / 2.0-beta.10 / 2.0-beta.9 | `0x20` | `0x28` | `0x2C` |

The hardcoded `32/40/44` used by the mcode builder is wrong on 2.1-alpha.30,
so adaptivity is required, not optional, when supporting multiple AHK
releases.

`lib/cnumpy/cnumpy_adaptive.ahk` converts cnumpy arrays through the
discovered layout: leaf arrays are filled by `AhkLayout.FillLeaf` (pure AHK
or a normal C export) and parent arrays are assembled with the public
`Push` API, which removes the internal child `AddRef` path entirely.
`lib/native_fill/native_fill.c` is a proof-of-concept DLL with the same fill
logic as `lib/mcode/array_builder.c`, compiled by clang as a normal module:

| Path (1,000,000 float64) | 1-D | 1000x1000 |
| --- | --- | --- |
| old `ToAhk` | ~458 ms | ~461 ms |
| adaptive AHK loop | ~1793 ms | ~1794 ms |
| adaptive native DLL | ~5.3 ms (87x) | ~15.1 ms (30.5x) |
| `ToBuffer` | ~1.6 ms | - |
| `View` | ~0.011 ms | - |

The native-DLL numbers match the mcode path's reported 2-D result (~15 ms)
without embedded machine code.  One AHK-specific gotcha: by-name `DllCall`
against this module costs ~0.72 ms per call, so hot loops must cache the
`GetProcAddress` pointer.

## Known limits

- The embedded scanner is x64 only; `AhkMagic.Init()` raises an explicit
  error on 32-bit AutoHotkey.
- `AhkMagic.Eval()` evaluates expressions by launching a hidden child process
  of the same `A_AhkPath` interpreter.  True in-process eval through the
  internal expression parser is the next research milestone.
- `PatchBif()` changes the `g_BIF` entry.  Function objects already created
  and cached by the interpreter keep their old target; a first dynamic call
  after patching reflects the new pointer, and restoring the table restores
  the on-disk-equivalent state.
