# cnumpy-ahk-bridge fork

Fork workspace for experimenting with converting cnumpy arrays into native
AutoHotkey values.  The original `2026-07-19-cnumpy-foundation` project is
left untouched; this directory only contains a copy of the wrapper and the
new bridge code.

The consolidated library now lives at `../../lib`; tests and benchmarks in
this fork import `lib/cnumpy/*` directly.  The `ahk/` and `bridge/` copies
below are kept as the historical fork state.

## Layout

- `ahk/numpy.ahk` - byte-for-byte copy of the original wrapper.
- `include/cnumpy/cnumpy.h` - reference copy of the C header.
- `bridge/cnumpy_bridge.ahk` - the new conversion layer.
- `tests/cnumpy_bridge.test.ahk` - end-to-end test.

## Bridge API

```ahk
Numpy.DllPath := "D:\...\cnumpy_ahk.dll"
Numpy.Init()

meta := CnpBridge.Metadata(arr)          ; raw CnpArray metadata peek
ahk  := CnpBridge.ToAhk(arr)             ; deep copy to nested AHK Array
fast := CnpBridge.ToAhkFast(arr)         ; deep copy via raw bytes
view := CnpBridge.View(arr)              ; zero-copy read/write view
buf  := CnpBridge.ToBuffer(arr)          ; raw bytes into AHK Buffer
arr2 := CnpBridge.FromAhk(ahk, dtype)    ; nested AHK Array -> NdArray
arr3 := CnpBridge.FromAhkFast(ahk, dtype); exact-dtype fast reverse
arr4 := CnpBridge.FromBuffer(buf, dtype) ; Buffer -> NdArray (copies)
```

`CnpBridge` reads `CnpArray` fields (`ndim`, `shape`, `strides`, `size`,
`data`, `dtype`, `flags`) read-only.  All conversion paths copy data into
AHK-owned memory; cnumpy keeps ownership of the source array.

Ownership rules are documented in `docs/lifecycle-and-ownership.md`.

## Run the test

```powershell
& D:\Tech\Projects\Autohotkey\Lib\.codex\autohotkey-2.0.26\runtime\AutoHotkey64.exe `
  tests\cnumpy_bridge.test.ahk
```

The test verifies 1-D/2-D/3-D conversion, AHK -> cnumpy roundtrip, raw
Buffer roundtrip, zero-copy view read/write, fast path roundtrip, the
ownership contract (a returned view keeps the array alive), and that cnumpy
operations still work afterwards.

## Benchmark

`benchmarks/cnumpy_bridge_benchmark.ahk` compares the old wrapper-based deep
copy with the new paths on a 1,000,000-element float64 array (best of 5):

| Path | Time |
| --- | --- |
| `ToAhk` (old) | ~437 ms |
| `ToAhkFast` (raw bytes) | ~563 ms |
| `ToAhkNative` (mcode fills Array internals) | ~742 ms at 100M |
| `View` (zero-copy) | < 1 ms |
| `ToBuffer` (memcpy) | < 1 ms |
| `FromAhk` (old) | ~968 ms |
| `FromAhkFast` (raw write) | ~1016 ms |
| `ToAhkNative` 2-D 1000x1000 | ~15 ms |
| `ToAhk` 2-D 1000x1000 (old) | ~466 ms |

`ToAhkNative` creates a real `Array()` and lets machine code fill its
internal `mItem` Variant array, so there is no AHK element loop at all.
Measured with QPC on 100,000,000 float64 elements: `ToAhkNative` ~742 ms
(allocation + fill), `ToBuffer` ~277 ms (800 MB memcpy), `View` ~0.017 ms.
Multi-dimensional arrays are built as nested `Array()` trees: parents are
filled with `SYM_OBJECT` child variants by `AhkBuildArrayChildren`, and each
child is AddRef'd before ownership is transferred.  1000x1000 2-D conversion
is ~15 ms vs ~466 ms on the old wrapper path.
The earlier "under 1 ms" figure at 1M elements was below the 1 ms timer
resolution.  The zero-copy `CnpView`/`ToBuffer` paths remain the fastest for
"keep a handle to the same bytes" use cases.

## Next steps

- Auto-generate `cnumpy_ahk.dll` bindings from the generalized mcode export
  scanner (1027 exports already enumerated).
- Native deep-copy builder (machine code constructing AHK arrays directly).
- Route conversion through interpreter internals for large arrays.
