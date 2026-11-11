# Glossary — Win10-Stop-Services-Processes

> Domain vocabulary for this project. Contains terms only — no implementation details.
> Updated inline as terms are resolved during sessions.

## Service Control Manager (SCM)

The Windows component (`services.msc`, accessed via `advapi32.dll`) that manages Windows
services: starting, stopping, querying, and configuring them. The `OpenSCManagerW` API
returns a handle to it.

## Service Handle

An opaque value returned by `OpenServiceW` that grants the rights requested (e.g.,
`SERVICE_STOP`, `SERVICE_QUERY_STATUS`). Every acquired service handle must be released
with exactly one `CloseServiceHandle` call.

## Service State

One of seven values returned by `QueryServiceStatus` / `QueryServiceStatusEx`:
`STOPPED` (1), `START_PENDING` (2), `STOP_PENDING` (3), `RUNNING` (4),
`CONTINUE_PENDING` (5), `PAUSE_PENDING` (6), `PAUSED` (7).

## Batch Stop

A single call to `_SM_StopServicesBatch()` that opens SCM once, issues stop controls
to all eligible services without serial waiting, then polls all pending services against
one shared deadline, and returns one result row per input service.

## Result Row

A six-element array `[$sName, $iInitialState, $iFinalState, $sOutcome, $iWin32Error, ""]`
returned for each service in a batch. `$sOutcome` is one of:
`STOPPED`, `ALREADY_STOPPED`, `UNAVAILABLE`, `FAILED`, `TIMED_OUT`.

## Priority Class

A Windows API constant returned by `GetPriorityClass` (kernel32.dll): `IDLE_PRIORITY_CLASS`
(0x40), `BELOW_NORMAL_PRIORITY_CLASS` (0x4000), `NORMAL_PRIORITY_CLASS` (0x20),
`ABOVE_NORMAL_PRIORITY_CLASS` (0x8000), `HIGH_PRIORITY_CLASS` (0x80),
`REALTIME_PRIORITY_CLASS` (0x100). These differ from AutoIt's `ProcessSetPriority`
constants (0–5) — always convert via `_WinAPIPriorityClassToAutoItConst()`.

## Priority Watchdog

The `AdlibRegister`-driven mechanism (`_PriorityWatchdog`) that fires every 10 seconds,
checks the current priority of each watched PID via `GetPriorityClass`, and restores it
if drift is detected. Uses three parallel global arrays: `$aPriorityWatchPIDs`,
`$aPriorityWatchTargets`, `$aPriorityWatchNames`.

## Process Inventory

The array(s) of process executable names (`$sProcesses[]`, `$sProcesses2[]`) that
`_CloseInstaller()` terminates every ~2 seconds when the monitoring loop is active.

## Service Inventory

The list of Windows service names that `_SM_StopServicesBatch()` attempts to stop
each cycle. Canonical list: `FDResPub`, `fdPHost`, `TrustedInstaller`, `wuauserv`,
`UsoSvc`, `DoSvc`, `WaaSMedicSvc`, `SSDPSRV`, `sppsvc`.

## Timing Constants

Named configuration values:
- `$PROC_POLL_INTERVAL_SEC = 2` — process-kill cycle interval
- `$SVC_POLL_INTERVAL_SEC = 10` — service-stop cycle interval
- `$MAIN_LOOP_SLEEP_MS = 500` — sleep inside the active monitoring While loop
- `$PRIORITY_WATCHDOG_INTERVAL_MS = 10000` — AdlibRegister interval for priority watchdog
- `$SVC_BATCH_TIMEOUT_MS = 20000` — shared deadline for one batch-stop operation
- `$SVC_POLL_MS = 500` — per-poll sleep inside batch-stop wait loop
