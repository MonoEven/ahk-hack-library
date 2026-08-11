# ahk-hack library

![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)
![AutoHotkey](https://img.shields.io/badge/AutoHotkey-v2-green.svg)
![Platform](https://img.shields.io/badge/platform-Windows%20x64-lightgrey.svg)

The core of this library is **scanning**: machine code that reads the
internal structure of AutoHotkey executables and of arbitrary PE modules at
runtime.  cnumpy conversion is a practice integration built on top of it,
not the core.

Repository: https://github.com/MonoEven/ahk-hack-library

## Layout

```text
lib/
  init.ahk                  core entry: #Include ahk_hack.ahk only
  ahk_hack.ahk              alias for the standalone core ahk_hack_single.ahk
  mcode/
    scanner.c               AHK interpreter table scanner (g_BIF/sMdFunc/g_BIV_A)
    export_scanner.c        generic PE export-table scanner
    array_builder.c         native AHK Array fill (numeric leaves)
    array_children_builder.c native AHK Array fill (nested children)
  cnumpy/
    init.ahk                optional integration entry
    numpy.ahk               cnumpy wrapper (original copy)
    cnumpy_bridge.ahk       CnpBridge + CnpView
```

## Core usage (scanning)

```ahk
#Include lib\init.ahk

AhkMagic.Init()
AhkMagic.Summary()                  ; bif/mdfunc/biv table addresses
AhkMagic.BifRva("Abs")              ; RVA of a built-in C function
AhkMagic.ScanExports(dllBase)       ; named exports of any loaded module
```

`AhkMagic` also exposes native Array construction (`BuildArrayFlat`,
`BuildArrayChildren`) and `Eval`, which are the "magic" layer that scanning
enables.

## Optional cnumpy integration

The bridge does not hardcode `CnpArray` offsets. It uses `cnp_ahk_data_ptr`,
`cnp_dtype_kind`, and the runtime-discovered `AhkLayout` with cnumpy's native
fillers.

```ahk
Numpy.DllPath := "D:\...\cnumpy_ahk.dll"
#Include lib\cnumpy\init.ahk

ahk := CnpBridge.ToAhkNative(arr)   ; N-D deep copy, filled by machine code
view := CnpBridge.View(arr)         ; zero-copy read/write view
```

cnumpy repository: https://github.com/MonoEven/cnumpy

Ownership rules are documented in `docs/lifecycle-and-ownership.md`.

## Rebuilding the machine code

```powershell
python tools\build_mcode.py --embed-only --out lib\ahk_hack.ahk
```

Requires LLVM clang.  The build refuses to embed `.text` if any relocation
escapes the blob.

## Tests and benchmarks

- `tests/ahk_mcode_test.ahk` - core scanner + built-in patch demo.
- `tests/export_scan_test.ahk` - generic PE export scan.
- `fork/cnumpy-ahk-bridge/tests/cnumpy_bridge.test.ahk` - cnumpy integration.
- `fork/cnumpy-ahk-bridge/benchmarks/` - 1M and 100M element benchmarks.
