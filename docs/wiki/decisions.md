---
updated: 2026-11-12
---

# Architecture Decisions Log

Decisions recorded here are those that are hard to reverse, surprising without context,
and the result of a real trade-off. Each entry cites the ticket that produced it.

## D-001 — Local Markdown Issue Tracker (2026-11-11)

**Decision**: Use local markdown files under `.scratch/service-manager-migration/issues/`
as the issue tracker for this effort.

**Why**: No GitHub authentication is available in the Maton sandbox environment.
The `gh` CLI is not installed. Local markdown is the supported fallback per
`setup-matt-pocock-skills`.

**How to apply**: All ticket references in this effort use the format `T01`–`T06`
pointing to `.scratch/service-manager-migration/issues/0N-*.md`.

## D-002 — ServiceManager.au3 Supersedes ServiceControl.au3 for Stopping (2026-11-11)

**Decision**: `Includes/ServiceManager.au3` becomes the single authoritative path
for service-stop operations. `Includes/ServiceControl.au3` is retained for
`_ServiceExists`, `_ServiceRunning`, `_StartService`, `_CreateService`, and `_DeleteService`
(functions not duplicated in ServiceManager). The `_StopService` function in
ServiceControl.au3 is no longer called from the main script.

**Why**: ServiceControl.au3's `_StopService` sends a stop control but does not wait for
the service to reach STOPPED state, making it impossible to verify outcome. The enterprise
prompt requires per-service outcome classification (STOPPED, ALREADY_STOPPED, UNAVAILABLE,
FAILED, TIMED_OUT).

**How to apply**: `_stopservicescustom()` in the main script is replaced with a call to
`_SM_StopServicesBatch()`. ServiceControl.au3 stays included for its non-stop helpers.

## D-003 — ServiceManager Module Extraction (2026-11-12)

**Decision**: Service-stop behaviour is extracted into a new deep module `Includes/ServiceManager.au3`
built around a single public function `_SM_StopServicesBatch`. The function opens the Windows SCM
once per batch, issues stop controls to all eligible services without serial waiting, then polls all
pending services against a shared deadline, and returns a structured 2D result array with per-service
outcome codes (`STOPPED`, `ALREADY_STOPPED`, `UNAVAILABLE`, `FAILED`, `TIMED_OUT`).

**Why**: `ServiceControl.au3`'s `_StopService` sends a single stop control per service with no state
inspection or wait, making outcome classification impossible. The enterprise requirement demands
per-service outcome classification and Win32 error reporting. AutoIt's built-in `ServiceStop()` does
not expose the full `SERVICE_STATUS` struct or Win32 error codes needed for state-based routing.

**ADR**: [docs/adr/0001-servicemanager-module-extraction.md](../adr/0001-servicemanager-module-extraction.md)

## D-004 — START_PENDING Handled as Stop-Ineligible (2026-11-12)

**Decision**: `_SM_IsStopEligible()` returns `False` for a service in the `START_PENDING` state.
`_SM_StopServicesBatch` records outcome `FAILED` (Win32 error 1061) for any such service rather than
attempting to send `SERVICE_CONTROL_STOP`. The service is retried on the next 10-second cycle once
it reaches a stable state.

**Why**: Whether a stop control is accepted during `START_PENDING` is non-deterministic — it depends
on how far the service has progressed through its startup sequence at the exact moment of the call.
This creates a timing-dependent code path that is impossible to test deterministically. The
conservative rule keeps Phase 1 of the batch-stop algorithm free of ambiguous cases and makes the
test harness fully deterministic.

**ADR**: [docs/adr/0002-start-pending-stop-ineligible.md](../adr/0002-start-pending-stop-ineligible.md)

## D-005 — Graceful-Only Service Stop (2026-11-12)

**Decision**: Services are stopped exclusively via `SERVICE_CONTROL_STOP` sent to the SCM via
`ControlService`. If a service does not reach `STOPPED` within the shared batch deadline
(`$SVC_BATCH_TIMEOUT_MS = 20 s`), it is marked `TIMED_OUT` and left running until the next
monitoring cycle. No `TerminateProcess` call is ever made on a service's host process.

**Why**: Target services frequently run as `NT AUTHORITY\SYSTEM` and may be Windows-protected.
Force-killing a service host process can leave the SCM database in an inconsistent state and strand
dependent services. The 10-second retry cadence provides a sufficient recovery path without the
stability risk of force-kill.

**ADR**: [docs/adr/0005-graceful-only-service-stop.md](../adr/0005-graceful-only-service-stop.md)

## D-006 — Batch-Scoped SCM Handle (2026-11-12)

**Decision**: `_SM_StopServicesBatch` opens the Windows SCM handle (`$hSCM`) once at the start of
the function and holds it for the entire batch (Phase 1 dispatch and Phase 2 polling). It is closed
once after all per-service handles are released. This is intentionally different from
`ServiceControl.au3`, which opens and closes its own SCM handle per function call.

**Why**: One `OpenSCManagerW` call per batch instead of one per service avoids redundant round-trips
and provides a single failure point for SCM unavailability: if the SCM cannot be opened, the function
returns `@error=1` with a zero-row array and no per-service work is attempted, giving the caller a
clean batch-level abort signal.

**ADR**: [docs/adr/0006-batch-scoped-scm-handle.md](../adr/0006-batch-scoped-scm-handle.md)

## D-007 — AutoIt Priority Constants as Canonical Internal Form (2026-11-12)

**Decision**: Process priorities are stored and compared internally as AutoIt integers (0–5)
throughout all priority-bearing variables and the watchdog arrays. The Windows API
`GetPriorityClass` hex constants (e.g., `0x20` for Normal) are converted to AutoIt integers exactly
once at the read boundary inside `_GetProcessPriorityByPID` via `_WinAPIPriorityClassToAutoItConst`.
No other code path may store or compare raw Windows priority class hex values.

**Why**: `ProcessSetPriority` requires AutoIt integers; storing Windows hex constants internally
would force a hex-to-integer conversion on every write site, including the most performance-sensitive
watchdog restore path. Centralising the conversion at the read boundary keeps all comparison and
assignment sites clean. Code that compares a raw `GetPriorityClass` return value against an AutoIt
integer compiles silently and produces wrong results (`0x20 <> 2`).

**ADR**: [docs/adr/0007-autoit-priority-constants-canonical.md](../adr/0007-autoit-priority-constants-canonical.md)

## D-008 — Direct DllCall to advapi32.dll for SCM Operations (2026-11-12)

**Decision**: `ServiceManager.au3` calls `OpenSCManagerW`, `OpenServiceW`, `QueryServiceStatus`,
`ControlService`, and `CloseServiceHandle` via `DllCall("advapi32.dll", ...)` directly. AutoIt's
built-in service functions and `_WinAPI_*` wrappers are not used anywhere in the module.

**Why**: AutoIt's built-in service functions return only binary success/failure and do not expose the
`SERVICE_STATUS` struct fields (`dwCurrentState`, `dwWaitHint`) that the batch-stop algorithm
requires for state-based routing. The project's AutoIt 3.3.16.1 installation has confirmed bugs
where `_WinAPI_*` wrappers propagate unreliable `@error` values after WinAPI calls (documented in
`CLAUDE.md` for `_WinAPI_GetPriorityClass`; the same concern applies across all `_WinAPI_*`
wrappers over advapi32.dll). Direct `DllCall` with immediate `@error` capture is the only reliable
pattern available.

**ADR**: [docs/adr/0008-direct-dllcall-advapi32.md](../adr/0008-direct-dllcall-advapi32.md)

## D-009 — test_process_close.au3 Marked for Deletion (2026-11-12)

**Decision**: `test_process_close.au3` is marked for deletion and must not be retained or
referenced going forward.

**Why**: Analysis under ticket T4-08 found that the file duplicates production behavior rather
than testing it in isolation. It does not meet the project's test standards: it has no assertions,
no pass/fail signalling, and no isolation from live system state. Keeping it creates a false
impression of test coverage while adding maintenance surface with no corresponding benefit.

**How to apply**: Delete the file. Do not replace it with a stub. If a genuine test for process
close behavior is needed in the future, write it from scratch against the test standards defined
at that time.

## D-010 — Convention-Only Boundary Between ServiceControl.au3 and ServiceManager.au3 (2026-11-12)

**Decision**: The boundary between `Includes/ServiceControl.au3` and `Includes/ServiceManager.au3`
is enforced by convention only, not by any technical mechanism (no AutoIt `#pragma` scope, no
namespace guard, no access modifier).

**Why**: AutoIt does not support private functions or module encapsulation. The separation is
maintained entirely by the `_SM_` prefix convention for `ServiceManager.au3` exports and by the
agreed division of responsibility (ServiceManager owns the batch-stop path; ServiceControl owns
existence, running-state, start, create, and delete helpers). Callers must respect this by never
calling `_SM_*` internals directly and never adding stop logic to ServiceControl.au3.

**ADR**: [docs/adr/0011-convention-only-module-boundary.md](../adr/0011-convention-only-module-boundary.md)

## D-011 — `$sProcesses[18]` Promoted to Configuration Region (2026-11-12)

**Decision**: `$sProcesses[18]` (the process kill target list) is moved from the
`Variables/Logging` region into the `Configuration — Target lists` region of
`Stop Services Processes.au3`, immediately after `$aSvcTargetNames[9]`.

**Why**: Both arrays are user-editable configuration inputs of identical nature. Placing
them in the same region makes them discoverable together and removes the misleading
implication that the process list is runtime state. No callers change — only the region
boundary moves.

**BUG report**: [MED-01](../reviews/bugs/BUG-INDEX.md#med-01----sprocesses18-declared-in-variableslogging-region-instead-of-configuration--target-lists)

## D-012 — `$bLogBusy` Re-entrancy Guard in `_LogMessage` (2026-11-12)

**Decision**: A boolean re-entrancy guard (`$bLogBusy`) is added to `_LogMessage`. On
entry the guard is checked; if already set, the new message is written directly to the
file after the outer call's `FileClose` rather than opening a competing handle. The guard
is set before `FileOpen` and cleared after `FileClose`.

**Why**: AutoIt `AdlibRegister` callbacks fire between bytecode instructions, including
inside `_LogMessage`. A `_PriorityWatchdog` interrupt between `FileOpen` and `FileWrite`
in an outer `_LogMessage` call opens a second append handle to the same log file. When the
outer call resumes with its stale file pointer, it overwrites the watchdog entry rather
than appending after it. The guard eliminates the competing-handle window.

**BUG report**: [HIGH-06 / BUG-09](../reviews/bugs/BUG-09-log-rotation.md)

## D-013 — `HotKeySet` Disable/Reenable Pattern in `ToggleScript` (2026-11-12)

**Decision**: `ToggleScript` disables the `Shift+F1` hotkey (`HotKeySet("{F1}")` with no
callback) as its first statement and re-enables it (`HotKeySet("{F1}", "ToggleScript")`)
as its last statement before returning, bracketing the `MsgBox` yield and the
`$bScriptRunning` state transition.

**Why**: AutoIt delivers queued hotkeys at `MsgBox` yield points. With `$bScriptRunning =
True` set after the yield, a second `Shift+F1` press during the 1-second `MsgBox` enters
a second `ToggleScript` invocation while `$bScriptRunning` is still `False`. Both
invocations enter the `While $bScriptRunning` loop simultaneously. Disabling the hotkey
for the duration of the function closes the delivery window without requiring a mutex.

**BUG report**: [HIGH-05 / BUG-10](../reviews/bugs/BUG-10-hotkey-reentrancy.md)

## D-014 — Parallel Array Atomic Rollback in `LockProcessPriority` (2026-11-12)

**Decision**: The three `_ArrayAdd` calls in `LockProcessPriority` (appending to
`$aPriorityWatchPIDs`, `$aPriorityWatchTargets`, and `$aPriorityWatchNames`) each check
`@error` immediately after the call. On any failure, all preceding successful adds are
rolled back by decrementing `$aPriorityWatch*[0]` (the UBound counter used by AutoIt
arrays), restoring size parity before returning.

**Why**: The three arrays are index-parallel: `_PriorityWatchdog` reads all three by the
same loop index. If one `_ArrayAdd` fails and the arrays diverge in size, subsequent
watchdog iterations silently read `""` for out-of-range indices and pass priority `0`
(Idle) to `ProcessSetPriority` — a wrong-priority silent restore. The rollback keeps the
invariant that all three arrays are always the same length.

**BUG report**: [HIGH-07 / BUG-08](../reviews/bugs/BUG-08-watchdog-arrays.md)

## Session Note — Second-Pass Resolutions (2026-11-12)

**Blockers resolved**:

- **B-006** (README updated): The project README was updated to reflect the current architecture,
  including the ServiceManager module and the `_SM_` prefix tier. Blocker is closed.
- **B-007** (GLOSSARY variable names removed): Variable-name entries that contaminated the
  GLOSSARY as pseudo-definitions have been removed. Blocker is closed.

**GLOSSARY rewrite**: The GLOSSARY was completely rewritten in this session. The prior version
contained 8 contaminated entries (variable names, implementation details, and circular
definitions masquerading as domain terms). The replacement contains 46 clean domain terms defined
in plain language, free of AutoIt syntax and implementation references.
