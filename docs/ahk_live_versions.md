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
| v2.0.2 | pass | pass | fail | fail | pass |
| v2.0.3 | pass | pass | fail | fail | pass |
| v2.0.4 | pass | pass | fail | fail | pass |
| v2.0.26 | pass | pass | pass | pass | pass |
| 2.1-alpha.30 | pass | pass | pass | pass | pass |

For 2.0.2 through 2.0.4, `OpenIncludedFile` is not discovered by the current
script-loader locator, so in-memory script loading and function inventory do
not work. Core attach, expression eval, and watch still work.
