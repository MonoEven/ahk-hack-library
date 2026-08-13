# AhkLive Developer Guide

## Architecture

`AhkLive` is split into four public layers over a low-level remote core:

- `core` (`ahk_live.ahk`): remote handles, layout discovery, exact function
  lookup, rename, and body replacement.
- `inspect`: snapshots, global reads, function and class inventories.
- `patch`: function replacement and rollback.
- `trace`: function tracing and expression watchpoints.
- `reload`: script-file hot reload.
- `agent`: product command surface for coding agents.
- `observability`: conditional watchpoints and event log.
- `fault`: transactional fault injection.
- `desktop`: process discovery for RPA-style workflows.
- `forensics`: runtime inventory reports for packed or suspicious builds.
- `compat`: CSV export for migration and IDE tooling.

`api.ahk` adds the product surface: `AhkLiveSession`, `AhkLiveResult`, and
`AhkLivePatchSession`.

## Lifecycle and ownership

`AhkLiveSession` owns the remote hook returned by `Attach` or
`AttachByName`. The hook is not exposed directly by the product API. Call
`Close()` to release the logical session. Closing does not unload injected
functions or patch the target; use `AhkLivePatchSession.Rollback()` before
closing when a patch must be undone.

`AhkLivePatchSession` is created by `BeginPatch()` and owns an
`AhkLiveJournal`. Every low-level write performed through a patch session is
recorded before it happens. `Rollback()` restores the recorded bytes and
deactivates the session. `Commit()` deactivates the session without rolling
back.

## Diagnostics

All product API methods return `AhkLiveResult`. A result has:

- `ok`: true or false.
- `value`: the successful return value.
- `error`: a normalized `What | Message | line` string on failure.
- `meta`: reserved metadata map.

Callers should check `ok` before reading `value`. Low-level `AhkLive` methods
still throw exceptions and are intended for research use.

## Compatibility

The full test matrix is verified on AutoHotkey 2.1-alpha.30 and 2.0.26.
Trace and replacement depend on runtime layout discovery, so new interpreter
builds must be added to `tools/ahk_live_matrix.ps1` and validated before they
are considered supported.

## Security

Only attach to processes you own. Patch and trace operations modify remote
memory, allocate executable or writable memory, and may be flagged by AV/EDR.
Run experiments in disposable processes and roll back patches explicitly.
