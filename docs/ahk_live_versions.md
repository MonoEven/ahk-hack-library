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

`v2.1-alpha.13` and `v2.1-alpha.16` currently fail the combined
replace/restore/watch path. Their `PreparseExpressions` and remote eval state
recover differently after a patch, so those two alpha builds are not listed as
supported until that path is fixed.
