# Hardcoded Audit

This file records what is dynamically discovered and what intentionally stays
constant. The policy is: version-sensitive offsets must be discovered at
runtime; stable ABI and stable C++ record layout are validated before use.

## Dynamic at runtime

| Item | Where |
| --- | --- |
| PE section map and table addresses | `_ModuleSections`, machine-code scanner |
| Interpreter table records | `g_BIF`, `sMdFunc`, `g_BIV_A` scans |
| `ExpressionToPostfix`, `ExpandExpression`, `FindOrAddVar`, CRT free | `_LocateInternalFunctions` |
| `gScript`, `g`, current-line slot, `SYM_INVALID` | internal locator machine code |
| `mFuncs`, `mFuncsCount`, function name field, `mJumpToLine` | `_RemoteDiscoverLayout` |
| Parser state anchors and parser field region | `_RemoteParserAnchors`, `_RemoteDiscoverParser` |
| `Line`, `ArgStruct`, `ExprTokenType`, `DerefType` offsets | `_RemoteDiscoverStructs`, reused by in-process probe |
| Remote `OpenIncludedFile` and `LoadIncludedFile(TextStream*)` | string cross-reference scan |

## Intentional constants

| Item | Reason |
| --- | --- |
| PE header offsets (`e_lfanew`, optional-header fields) | Windows PE/COFF ABI |
| Table record strides `0x20` / `0x28` / `0x18` | Stable x64 `FuncEntry` layout in verified builds |
| Record field positions (name, fn pointer, parameter bytes) | Stable C++ struct layout; validated by table scans |
| Token stride and symbol/usage/value field positions | Discovered by the token validator; the candidates are structural |
| `SYM_VAR=4`, `DT_VAR=0`, `DT_FUNCREF=7`, `ACT_BLOCK_BEGIN=3` | Interpreter enum values, not offsets |

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

The full nine-test matrix passes on all 19 runtime builds found on this
machine. See `reports/runtime_matrix_all.txt`.

If a future build changes a version-sensitive layout, the locator or validator
throws an explicit error instead of proceeding with a guessed offset.
