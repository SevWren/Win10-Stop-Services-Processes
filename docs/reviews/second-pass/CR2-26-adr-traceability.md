# CR2-26 — ADR Traceability Review (Second Pass)

**Reviewer:** Independent second pass
**Date:** 2026-11-12
**Scope:** All 10 ADRs in `docs/adr/`, cross-checked against
`Includes/ServiceManager.au3`, `Stop Services Processes.au3`,
and `Includes/ServiceControl.au3`
**Purpose:** Independent verification of the T3-08 ADR validation claim of 10/10 PASS.
Also evaluates whether `docs/adr/README.md` correctly indexes all 10 ADRs.

---

## Summary

| ADR | Decision | Verdict |
|-----|----------|---------|
| 0001 | ServiceManager module extraction | PASS |
| 0002 | START_PENDING treated as stop-ineligible | PASS |
| 0003 | Two-level error reporting convention | PASS |
| 0004 | ServiceManager/ServiceControl incompatible error conventions | PASS |
| 0005 | Graceful-only service stop; no force-kill fallback | PASS |
| 0006 | Batch-scoped SCM handle | PASS |
| 0007 | AutoIt integers as canonical priority representation | PASS |
| 0008 | Direct DllCall to advapi32.dll | PASS |
| 0009 | QueryServiceStatus (7-DWORD) not QueryServiceStatusEx | PASS |
| 0010 | 50 ms passive loop / 500 ms active monitoring loop | PASS |

**Overall: 10/10 PASS. The T3-08 claim is confirmed independently.**

One additional finding is recorded at the end of this document: `docs/adr/README.md`
omits ADR-0010 from its index table.

---

## Per-ADR Analysis

---

### ADR-0001 — ServiceManager Module Extraction

**Decision recorded:** Extract service-stop behaviour into a new module
`ServiceManager.au3` built around a single public function
`_SM_StopServicesBatch`. The function opens the SCM once, issues stop controls
to all eligible services without serial waits, polls against a shared deadline,
and returns a structured `[n][6]` 2D result array. `ServiceControl.au3` is
retained for non-stop helpers (`_ServiceExists`, `_ServiceRunning`,
`_StartService`, `_CreateService`, `_DeleteService`); its `_StopService` is no
longer called on the monitoring hot path.

**Code implementation:**

- `Includes/ServiceManager.au3` — header comment, lines 1–36, states it is the
  "authoritative service-stop implementation" and that `_StopService` is no
  longer called.
- `_SM_StopServicesBatch` signature, lines 138–380, is the sole public function
  as required.
- `Stop Services Processes.au3` lines 18–20: both files are `#include`d. The
  comment at line 15–17 explicitly states `_StopService` in `ServiceControl.au3`
  is "NO LONGER called; use `_SM_StopServicesBatch`."
- `_RunServiceBatchStop()`, lines 237–263, calls `_SM_StopServicesBatch` and
  iterates the returned 2D array routing each row to `_LogMessage` — matching the
  ADR's consequence "iterates the result array."
- `ServiceManager.au3` calls `_LogMessage` directly (e.g. line 177) and
  `_WinAPI_GetLastError` directly (e.g. line 176), confirming the ADR's dependency
  note ("not fully self-contained").

**Verdict: PASS**

---

### ADR-0002 — START_PENDING Services Are Stop-Ineligible

**Decision recorded:** `_SM_IsStopEligible()` returns `False` for `START_PENDING`.
`_SM_StopServicesBatch` records outcome `FAILED` with Win32 error 1061 for such
services without sending a stop control. Services are retried on the next cycle
(`$SVC_POLL_INTERVAL_SEC = 10 s`).

**Code implementation:**

- `_SM_IsStopEligible`, `Includes/ServiceManager.au3` lines 476–483: the `Switch`
  case covers only `$SM_STATE_RUNNING`, `$SM_STATE_PAUSED`, `$SM_STATE_PAUSE_PENDING`,
  `$SM_STATE_CONTINUE_PENDING` — `START_PENDING` (state 2) falls to `Case Else /
  Return False`.
- Phase 1 routing in `_SM_StopServicesBatch`, lines 264–273: `If Not
  _SM_IsStopEligible($iInitState)` sets `$aResults[$i][3] = $SM_OUTCOME_FAILED`,
  `$aResults[$i][4] = $SM_ERR_CANNOT_ACCEPT` (1061), appends the note "Service in
  START_PENDING state; stop control not accepted," closes the handle, and
  `ContinueLoop` — no `ControlService` call is made.
- `Stop Services Processes.au3` line 43: `$SVC_POLL_INTERVAL_SEC = 10` confirmed.

**Verdict: PASS**

---

### ADR-0003 — Two-Level Error Reporting

**Decision recorded:** `@error 1` signals a batch-level SCM-open failure only.
All per-service failures are encoded in `$aResults[$i][3]` as outcome strings.
`@error` is `0` on the normal return path even when individual rows contain
`FAILED` or `TIMED_OUT`. Callers must not treat `@error = 0` as "all stopped."

**Code implementation:**

- `Includes/ServiceManager.au3` lines 180–183: SCM-open failure path calls
  `SetError(1)` and returns a zero-row array `$aEmpty[0][6]`. This is the only
  `SetError` call in the function.
- Lines 338–342 (Phase 2 stopped branch), lines 367–372 (timeout branch): both
  write outcome strings to `$aResults[$i][3]`; neither calls `SetError`.
- The final `Return $aResults` (line 378) carries no `SetError` call, so
  `@error = 0` on the normal path.
- `Stop Services Processes.au3` lines 239–262 (`_RunServiceBatchStop`): checks
  `@error` first (line 239), then iterates the array and inspects `$sOutcome`
  (line 246) — the correct two-step usage pattern.

**Verdict: PASS**

---

### ADR-0004 — ServiceManager/ServiceControl Incompatible Error Conventions

**Decision recorded:** `ServiceControl.au3` functions use scalar `1`/`0` returns
with Win32 error in `@error`. `_SM_StopServicesBatch` returns a 2D array and uses
`@error` only for the batch-level SCM failure. The divergence is intentional. The
modules must not be used interchangeably for stop operations.

**Code implementation:**

- `Includes/ServiceControl.au3` lines 141–145 (`_StartService` return logic),
  lines 201–205 (`_StopService` return logic): confirm the `1`/`0`/`SetError`
  scalar pattern.
- `Includes/ServiceManager.au3`: `_SM_StopServicesBatch` returns a 2D array
  (lines 143, 148, 378) and uses `SetError(1)` only for the SCM-open failure
  (line 181). No other `SetError` calls exist in the module.
- Both modules are `#include`d in `Stop Services Processes.au3` lines 18 and 20
  without conflict, confirming co-existence.
- The main script never calls `_StopService` from `ServiceControl.au3` for the
  monitoring path — it calls `_SM_StopServicesBatch` exclusively (line 238).

**Verdict: PASS**

---

### ADR-0005 — Graceful-Only Service Stop; No Force-Kill Fallback

**Decision recorded:** Services are stopped exclusively via `SERVICE_CONTROL_STOP`
through `ControlService`. No `TerminateProcess` call is made. Services that do not
reach `STOPPED` within `$SVC_BATCH_TIMEOUT_MS = 20 s` are marked `TIMED_OUT` and
retried on the next cycle.

**Code implementation:**

- `Includes/ServiceManager.au3` lines 279–283: `ControlService` is called with
  `$SM_SERVICE_CONTROL_STOP` (0x00000001). No `TerminateProcess`, `ProcessClose`,
  or any kernel32 process-termination call exists anywhere in the file.
- Phase 2 timeout handling, lines 364–372: services still in `$aPendingIdx` after
  the `While` loop receive `$SM_OUTCOME_TIMEDOUT` and their handles are closed.
  No force-kill is attempted.
- `Stop Services Processes.au3` line 46: `$SVC_BATCH_TIMEOUT_MS = 20000` (20 s)
  confirmed.
- The `_KillProcessList` function (`Stop Services Processes.au3` lines 207–227)
  uses `ProcessClose` only for processes listed in `$sProcesses[]` — entirely
  separate from the service-stop path, and `ProcessClose` is not called from
  within `ServiceManager.au3`.

**Verdict: PASS**

---

### ADR-0006 — Batch-Scoped SCM Handle

**Decision recorded:** `_SM_StopServicesBatch` opens one `$hSCM` handle at the
top of the function for the entire batch. If it fails, the function returns
`@error = 1` with a zero-row array and no per-service work is done. The handle is
closed once, after all per-service handles and the Phase 2 poll are complete.
`ServiceControl.au3` uses the opposite per-call pattern — both are intentional.

**Code implementation:**

- `Includes/ServiceManager.au3` lines 170–184: single `OpenSCManagerW` call at
  the top of `_SM_StopServicesBatch`. On failure (lines 175–183) `SetError(1)` and
  `Return $aEmpty` immediately — no per-service loop is entered.
- `$hSCM` is passed as the first argument to every `OpenServiceW` call in Phase 1
  (line 204) — there is no second `OpenSCManagerW` anywhere in the function.
- Lines 374–376: `CloseServiceHandle($hSCM)` is called once after the timeout
  cleanup loop, as the final act before `Return $aResults`.
- `Includes/ServiceControl.au3`: each of the five functions (`_StartService`,
  `_StopService`, `_ServiceExists`, `_ServiceRunning`, `_DeleteService`) opens and
  closes its own SCM handle independently (confirmed at lines 109/137, 169/197,
  224/240, 264/283, 403/429 respectively) — matching the ADR's description of the
  per-call pattern.

**Verdict: PASS**

---

### ADR-0007 — AutoIt Integers as Canonical Priority Representation

**Decision recorded:** Process priorities are stored and compared internally as
AutoIt integers (0–5). Windows API hex priority class values (`GetPriorityClass`
output) are converted to AutoIt integers once, at the read boundary, via
`_WinAPIPriorityClassToAutoItConst`. All priority-bearing variables and watchdog
array slots hold AutoIt integers.

**Code implementation:**

- `Stop Services Processes.au3` lines 72–77: `$AUTOIT_PRIORITY_IDLE = 0` through
  `$AUTOIT_PRIORITY_REALTIME = 5` defined as named constants.
- Lines 452–454: `$aPriorityWatchTargets` stores `$iPriorityConst` (AutoIt integer,
  validated to be 0–5 at line 429).
- `_GetProcessPriorityByPID` lines 530–551: calls `GetPriorityClass` via `DllCall`
  (line 540), then at line 550 returns
  `_WinAPIPriorityClassToAutoItConst($aResult[0])` — the conversion happens before
  the value leaves the function.
- `_WinAPIPriorityClassToAutoItConst` lines 558–575: maps Windows API hex values
  (`$IDLE_PRIORITY_CLASS = 0x40`, etc.) to AutoIt integers (0–5).
- `_PriorityWatchdog` line 489: comparison `$iCurrentConst <> $iPriorityConst`
  compares two AutoIt integers; `ProcessSetPriority($iPID, $iPriorityConst)` at
  line 503 also receives an AutoIt integer directly — no conversion at write sites.

**Verdict: PASS**

---

### ADR-0008 — Direct DllCall to advapi32.dll

**Decision recorded:** All SCM API calls in `ServiceManager.au3`
(`OpenSCManagerW`, `OpenServiceW`, `QueryServiceStatus`, `ControlService`,
`CloseServiceHandle`) use `DllCall("advapi32.dll", ...)` directly. No AutoIt
built-in service functions or `_WinAPI_*` wrappers are used for advapi32 calls.
Every call site must follow the capture-immediately pattern: `Local $iDllErr =
@error` on the line after `DllCall`, then `Local $iWinErr =
_WinAPI_GetLastError()` before any other call.

**Code implementation:**

- `Includes/ServiceManager.au3`:
  - `OpenSCManagerW` via `DllCall("advapi32.dll", ...)`: line 170–173.
    `@error` captured at line 174; `_WinAPI_GetLastError()` at line 176.
  - `OpenServiceW`: lines 203–206. `@error` captured at line 207;
    `_WinAPI_GetLastError()` at line 209.
  - `QueryServiceStatus` (Phase 1): lines 228–230. `@error` captured at line 231;
    `_WinAPI_GetLastError()` at line 232.
  - `ControlService`: lines 279–282. `@error` captured at line 283;
    `_WinAPI_GetLastError()` at line 284.
  - `QueryServiceStatus` (Phase 2 poll): lines 325–327. `@error` captured at
    line 328.
  - `CloseServiceHandle` calls: lines 237, 250, 271, 297, 343, 371, 376 — all
    `DllCall("advapi32.dll", ...)`.
  - `_SM_GetServiceState`: lines 399–401. `@error` captured at line 402;
    `_WinAPI_GetLastError()` at line 403.
- No `ServiceStop()`, `_ServiceStop()`, or any `_WinAPI_*` wrapper for advapi32
  calls appears in `ServiceManager.au3`.

**Verdict: PASS**

---

### ADR-0009 — QueryServiceStatus API Selection (7-DWORD SERVICE_STATUS)

**Decision recorded:** `QueryServiceStatus` with the 7-DWORD `SERVICE_STATUS`
struct is used throughout instead of `QueryServiceStatusEx` /
`SERVICE_STATUS_PROCESS` (9 DWORDs), because the batch-stop algorithm only reads
`dwCurrentState` (field 2) and `ControlService` already requires the same 7-DWORD
struct. `dwProcessId` and `dwServiceFlags` are not needed.

**Code implementation:**

- `Includes/ServiceManager.au3`:
  - Phase 1 query struct: `DllStructCreate("dword;dword;dword;dword;dword;dword;dword")`
    at line 227 — exactly 7 DWORDs.
  - Phase 2 poll struct: same layout at line 324.
  - `_SM_GetServiceState` struct: same layout at line 398.
  - `dwCurrentState` read as struct field 2 via `DllStructGetData($t, 2)` at lines
    240, 335, and 409.
- `QueryServiceStatusEx` does not appear anywhere in `ServiceManager.au3` (or in
  either of the other two source files).
- `ControlService` struct at line 278: same 7-DWORD layout — confirming the ADR's
  note that both APIs share the struct, so no extra definition is needed.

**Verdict: PASS**

---

### ADR-0010 — Main Loop Sleep Timing (50 ms Passive / 500 ms Active)

**Decision recorded:** The passive main loop (`While 1 / Sleep(50) / WEnd`)
keeps its 50 ms sleep for hotkey and tray responsiveness. The active monitoring
loop inside `ToggleScript()` uses `Sleep($MAIN_LOOP_SLEEP_MS)` where
`$MAIN_LOOP_SLEEP_MS = 500`, which is sufficient because all real work is gated
on `_CheckElapsedTime()` timers (`$PROC_POLL_INTERVAL_SEC = 2 s`,
`$SVC_POLL_INTERVAL_SEC = 10 s`).

**Code implementation:**

- `Stop Services Processes.au3` line 44: `$MAIN_LOOP_SLEEP_MS = 500` defined as a
  named constant.
- Lines 147–149: passive main loop — `While 1 / Sleep(50) / WEnd`. The literal
  `50` is used here, consistent with the ADR's statement that the passive loop
  retains the CLAUDE.md baseline of 50 ms.
- Lines 166–177 (active monitoring loop inside `ToggleScript`): `Sleep($MAIN_LOOP_SLEEP_MS)`
  at line 175 — the 500 ms constant.
- Lines 42–43: `$PROC_POLL_INTERVAL_SEC = 2` and `$SVC_POLL_INTERVAL_SEC = 10`
  confirmed; `_CheckElapsedTime` gates both work calls (lines 167 and 171) so the
  500 ms sleep between checks is sufficient.

**Verdict: PASS**

---

## README.md Index Accuracy Check

The `docs/adr/README.md` index table (lines 13–22) lists entries for ADRs 0001
through 0009 — **nine rows**.

**Finding: ADR-0010 is missing from the README index.**

The file `docs/adr/0010-main-loop-sleep-timing.md` exists on disk and is a valid
accepted ADR. The README was last substantively updated before ADR-0010 was written
(the Validation Notes section at the bottom is dated 2026-11-12 but only references
ADR-0001 through ADR-0009). The README's index therefore under-counts by one and
does not accurately represent the full ADR set.

The Validation Notes section in the README likewise stops at ADR-0009 — there is no
ADR-0010 entry there either.

**README verdict: PARTIALLY INCORRECT — omits ADR-0010 from both the index table
and the Validation Notes section.**

---

## Conclusion

The T3-08 ADR validation claim of 10/10 PASS is **confirmed** by this independent
review. All 10 ADR decisions are faithfully implemented in the codebase, with
specific line-number evidence cited above for each.

The only discrepancy found is in the `docs/adr/README.md` index: ADR-0010
(`0010-main-loop-sleep-timing.md`) is not listed in the index table or the
Validation Notes section. The ADR file itself is correctly written and the code
implements it correctly; only the README index is incomplete.
