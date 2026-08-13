# Hardcoded Audit

This file records what is dynamically discovered and what intentionally stays
constant. The policy is: version-sensitive offsets must be discovered at
runtime; stable ABI and stable C++ record layout are validated before use.
Every entry below is the current truth as of the last audit; the audit is
re-run whenever a machine-code blob or a discovery path changes.

## Dynamic at runtime

| Item | Where |
| --- | --- |
| PE section map and table addresses | `_ModuleSections`, machine-code scanner |
| Interpreter table records | `g_BIF`, `sMdFunc`, `g_BIV_A` scans |
| `ExpressionToPostfix`, `ExpandExpression`, `FindOrAddVar`, CRT free | `_LocateInternalFunctions` |
| `gScript`, `g`, current-line slot, `SYM_INVALID` | internal locator machine code |
| `mFuncs`, `mFuncsCount`, function name field, `mJumpToLine` | `_RemoteDiscoverLayout` (majority back-reference rule) |
| Parser state (in-process) | two candidate regions (sentinel-anchored and qCmp-anchored) are built and auto-validated against the live Script object; the strictly-validating candidate wins; save/restore walks only the discovered field set — no field names assumed per version, no blind pre-load reset (that variant AV'd on 2.0-beta builds and was removed) |
| Parser state (remote) | two candidate regions (sentinel-anchored and qCmp-anchored) are built and auto-validated against the live target state; the strictly-validating candidate wins — no version-family branch |
| `Line`/`ArgStruct`/token/`DerefType` offsets — EVERY field the eval blob uses | `_RemoteDiscoverStructs` + `_ArgShapeInProc`/`_RemoteArgShape` content validation; passed to the blob as a 21-slot layout array |
| `TextStream`/`TextMem` mData slot (0x40 in 2.0, 0x50 in 2.1) | dual-slot write in `lib/mcode/mem_script.c`: both candidate offsets are populated with the same buffer, so no version selection happens; every load is validated by its result — rc == 1 plus, for the discovery probe, a function-count increase — and an unsupported layout fails that check loudly at probe time (in-process and remote) |
| `Var` record in AhkLive tracing (value, symbol byte, object-state byte set) | `_EnsureVarLayout`: one variable is diffed between its fresh, integer, and object states (all assigned by the interpreter itself); the discovered set is written back verbatim |
| Array (`Array`) layout for `AhkLayout.FillLeaf` | `lib/ahk_layout.ahk` mutation-diffing, no offsets at all |
| cnumpy `CnpArray` layout | `lib/cnumpy/cnumpy_adaptive.ahk` — but these offsets describe cnumpy's own exported struct, not AutoHotkey |

## Validated relative layout (derived from a discovered anchor, checked before use)

| Layout | Where | Validation |
| --- | --- | --- |
| `ArgStruct` `len`/`text`/`deref` = `arg_postfix - 20/-16/-8`, `type` = `arg_expression - 1`, max stack/alloc = `arg_postfix + 8/+12` | `_ArgShapeInProc`, `_RemoteArgShape` | the live arg must be self-consistent: type byte is 0, length equals the UTF-16 text length, the deref pointer is readable — otherwise discovery throws |
| AhkLive param `Var.mAliasFor` at `+0x10` and the trailing flag byte at `symbol + 2` | trace parameter aliasing | validated by behavior: the traced call must produce the correct result on every supported runtime (trace tests) |
| RemoteDeepRedirect slot heuristics (vtable at `pos-0x10/-0x08`, packed min/max at `pos-0x10`) | deep-redirect candidate validation | a miss fails loudly ("no Func object found"); the patch address itself is found by scanning |
| Remote-eval fallback layout (`_DefaultEvalLayout`) when a hook has no discovered layout | `RemoteEval` | the eval blob validates the assumed token layout (symbol sanity, bounded sentinel search, deref range) before its first write and reports status 9 on mismatch |

## Intentional constants

| Item | Reason |
| --- | --- |
| PE header offsets (`e_lfanew`, optional-header fields, `SizeOfImage` at +80) | Windows PE/COFF ABI |
| Table record strides `0x20` / `0x28` / `0x18` | Stable x64 `FuncEntry` layout in verified builds |
| Record field positions (name, fn pointer, parameter bytes) | Stable C++ struct layout; validated by table scans |
| `SYM_VAR=4`, `DT_VAR=0`, `DT_FUNCREF=7`, `ACT_BLOCK_BEGIN=3`, `FINDVAR_FOR_READ=0x103` | Interpreter enum values, not offsets |
| Scanner output buffer contract (counts capped at 512/512/256 and 4096; entry bases 80/16464/36944/24) | Self-consistent ABI between the C blobs and the AHK parsers; caps are enforced with explicit errors |
| Remote parameter-block layouts (136 B for eval, 72 B for calls, stub register mapping) | Self-consistent ABI between the stubs and the AHK writers |
| Scratch geometry (8 MiB scratch, `FINAL_DEREF_ADDR=0x100800`, expand deref `0x3F0000`, 512 B result, 0x400 loader scratch, layout arrays at scratch+0x200 / object+0x100) | Internal contract between the caller and the blob; not interpreter layout |
| Heuristic windows (64-qword function-object scan, 0x500 name window, 0x100/0x200/0x800 snapshots, 10 s remote timeout, 100000-step walk caps) | Safety bounds, not layout |

## Tested claims

The following suites pass on `v2.0.26`, `v2.1-alpha.13`, `v2.1-alpha.16`, and
`v2.1-alpha.30`:

- `tests/remote_hook_test.ahk`
- `tests/ahk_live_cross_smoke.ahk`
- `tests/ahk_live_test.ahk`
- `tests/ahk_live_product_test.ahk`
- `tests/ahk_live_six_test.ahk`
- `tests/ahk_live_benchmark.ahk`
- `tests/evalscript_inproc.ahk`
- `tests/evalscript_repeat.ahk`
- `tests/evalscript_class.ahk`
- `tests/eval_object_syntax_test.ahk`
- `tests/remote_empty_object_test.ahk`
- `tests/remote_empty_target_test.ahk`
- `tests/remote_deep_redirect_test.ahk`

The full thirteen-test matrix passes on all 19 runtime builds found on this
machine. See `reports/runtime_matrix_all.txt`.

If a future build changes a version-sensitive layout, the locator or validator
throws an explicit error instead of proceeding with a guessed offset.
