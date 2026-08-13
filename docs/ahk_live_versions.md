# AhkLive Version Matrix

The table is generated with `tests/ahk_live_cross_smoke.ahk` against each
AutoHotkey v2 runtime that is present on this machine.

| Runtime | Core attach | Snapshot | Inventory | Replace | Watch |
| --- | --- | --- | --- | --- | --- |
| v2.0-beta.9 | pass | pass | pass | pass | pass |
| v2.0-beta.10 | pass | pass | pass | pass | pass |
| v2.0-beta.12 | pass | pass | pass | pass | pass |
| v2.0-beta.13 | pass | pass | pass | pass | pass |
| v2.0-beta.15 | pass | pass | pass | pass | pass |
| v2.0-rc.1 | pass | pass | pass | pass | pass |
| v2.0-rc.3 | pass | pass | pass | pass | pass |
| v2.0.0 | pass | pass | pass | pass | pass |
| v2.0.2 | pass | pass | pass | pass | pass |
| v2.0.3 | pass | pass | pass | pass | pass |
| v2.0.4 | pass | pass | pass | pass | pass |
| v2.0.26 | pass | pass | pass | pass | pass |
| 2.1-alpha.30 | pass | pass | pass | pass | pass |
| 2.1-alpha.13 | pass | pass | pass | pass | pass |
| 2.1-alpha.16 | pass | pass | pass | pass | pass |

`v2.1-alpha.13` and `v2.1-alpha.16` now pass the dynamic layout, in-process
eval, inventory, replace/restore, and watch paths. AhkLive keeps one named
timer function for all watchers instead of passing bound function objects to
`SetTimer`; this matches the supported AHK v2 timer contract across these
releases.

The scanner now reads the interpreter layout from an already-running process
without injecting a probe function. `mFuncs`, `mFuncsCount`, the function name
field, and `mJumpLine` are selected from candidate arrays by validating all
visible `Func` objects. `OpenIncludedFile` is found from its `#Include` and
cannot-open error strings, and the `TextStream` loader is the first call target
following the open-file mode comparison. These paths are version-independent
and use only PE section metadata plus the live process memory.

Parser state offsets are validated against live `gScript` memory. The
`LoadIncludedFile` machine code provides two displacement anchors, then the
live object confirms `mClassObjectCount` and the `mExprFuncIndex` sentinel
before the surrounding parser field offsets are accepted. This replaces the
older `dCmp > 0x100` version-family branch.

`RemoteEvalScript` no longer reads fixed `Line`, `ArgStruct`, `ExprTokenType`,
or `DerefType` offsets. The scanner validates ordinary `Func` bodies by their
back-reference, derives the token stride and symbol/usage/value fields from
live postfix arrays, and discovers `DerefType` from the `ArgStruct.deref`
array that already exists in a running script. The same code path then uses
those offsets for the injected `PreparseExpressions` pass. This was verified
with `tests/remote_hook_test.ahk` on `v2.0.26`, `v2.1-alpha.13`,
`v2.1-alpha.16`, and `v2.1-alpha.30`.

The in-process `EvalScript` path now uses the same runtime struct discovery.
`_DiscoverEvalLayout` loads a temporary probe function, finds `mJumpToLine`
from the line's back-reference, and runs the shared `Line`/`ArgStruct`/token/
deref validator before restoring the `Script` object. `tests/evalscript_inproc`,
`tests/evalscript_repeat`, and `tests/evalscript_class` pass on the same four
runtimes.

`tools/verify_all_runtimes.ps1` runs the full nine-test matrix across 19
runtime builds found on this machine. Every build passes all 9 tests,
including `tests/ahk_live_test.ahk`. `TraceFunction` uses a cloned `UserFunc`
with a `VAR_CONSTANT` alias and shared parameter variables, so the trace path
is now stable across the whole matrix. The latest report is at
`reports/runtime_matrix_all.txt`.
