# BUG-11: WaaSMedicSvc protected service — silent FAILED outcome, no user notification

**Status:** Open
**Severity:** Low (expected by ADR-0005; tool goal is best-effort suppression)
**Type:** Documentation gap + minor UX gap
**Files affected:**
- `Includes/ServiceManager.au3`
- `Stop Services Processes.au3`
- `docs/research/windows-scm-api.md` (already documents the issue — no change needed)

---

## Summary

`WaaSMedicSvc` (Windows Update Medic Service) is protected on Windows 10 1803+ by a kernel-level protection mechanism. `ControlService` with `SERVICE_CONTROL_STOP` reliably returns `ERROR_ACCESS_DENIED` (Win32 = 5) on modern builds. The script routes this to a `FAILED` outcome, logs it at `LOG_LEVEL_ERROR`, and silently continues. The monitoring loop retries every 10 seconds. The service is never stopped, and the user receives no notification that this target is permanently unserviceable.

This is not a crash or data-loss bug. It is a documentation gap (the README does not mention the protected-service limitation) and a minor UX gap (no distinction between a transient FAILED and a permanently unserviceable service).

---

## Investigation

### 1. Research doc — `docs/research/windows-scm-api.md`

The per-service reference table at the bottom of the file already records the protection mechanism precisely:

> `WaaSMedicSvc` — Protected by a service protection mechanism on Windows 10 1803+;
> `ControlService` with `SERVICE_CONTROL_STOP` may return `ERROR_ACCESS_DENIED` (5) or
> `ERROR_SERVICE_CANNOT_ACCEPT_CTRL` (1061). Expect FAILED outcome on modern builds.

The research doc is accurate and complete. No changes needed there.

### 2. `Includes/ServiceManager.au3` — what happens on ControlService failure

When `ControlService` returns FALSE for a stop-eligible service (RUNNING/PAUSED/etc.), the failure path in `_SM_StopServicesBatch` is (lines 286–298):

```autoit
If $iCtrlDllErr Or Not $aCtrl[0] Then
    Local $sCtrlOutcome = _SM_Win32ErrToOutcome($iCtrlWinErr)
    $aResults[$i][3] = $sCtrlOutcome
    $aResults[$i][4] = $iCtrlWinErr
    ...
    DllCall("advapi32.dll", "bool", "CloseServiceHandle", "handle", $hService)
    ContinueLoop
EndIf
```

`_SM_Win32ErrToOutcome` maps Win32 errors as follows:

| Win32 error | Outcome |
|---|---|
| 1062 (`ERROR_SERVICE_NOT_ACTIVE`) | `ALREADY_STOPPED` |
| 1060 (`ERROR_SERVICE_DOES_NOT_EXIST`) | `UNAVAILABLE` |
| everything else | `FAILED` |

For `WaaSMedicSvc`, `ControlService` returns `ERROR_ACCESS_DENIED` (5) or `ERROR_SERVICE_CANNOT_ACCEPT_CTRL` (1061). Neither is handled specially — both map to `FAILED`. The service handle is closed and the loop continues. The service is never added to the pending-poll list.

**Win32 error expected:** `ERROR_ACCESS_DENIED` (5) is the primary code on Windows 10 1803+ protected services. `ERROR_SERVICE_CANNOT_ACCEPT_CTRL` (1061) could also appear if the protection intercepts at the control-dispatch layer.

**Outcome routing:** `FAILED` — correct per the current classification table. There is no `PROTECTED` or `UNAVAILABLE` outcome for a service that exists but cannot be controlled.

### 3. `Stop Services Processes.au3` — what `_RunServiceBatchStop` does with FAILED

`_RunServiceBatchStop` (lines 232–258) iterates the result array and routes each outcome to `_LogMessage`:

```autoit
Case $sOutcome = $SM_OUTCOME_FAILED
    _LogMessage("Service stop failed: " & $sSvcName & " (Win32: " & $iWin32 & ")", $LOG_TYPE_SERVICE, $LOG_LEVEL_ERROR)
```

Behavior on FAILED:
- Logs one `LOG_LEVEL_ERROR` line to `%HOMEDRIVE%\login\closure_log.txt` (and SciTE console if active).
- No retry within the same cycle (the batch already ran `ControlService` once; there is no retry logic inside `_SM_StopServicesBatch`).
- No MsgBox, no `_TrayNotify`, no toast notification.
- The monitoring loop will re-attempt on the next `$SVC_POLL_INTERVAL_SEC` (10 s) tick, producing the same FAILED log entry every 10 seconds for as long as the script is active.

There is no de-duplication of repeated FAILED entries. On a typical session the log will accumulate one error line per 10-second cycle for every protected service in the target list.

### 4. User experience

| Scenario | What the user sees |
|---|---|
| `WaaSMedicSvc` is running and protected | Nothing visible. Log file fills with `"Service stop failed: WaaSMedicSvc (Win32: 5)"` every 10 s. No tray tooltip. No popup. |
| User checks the log | Error entries present, but no explanation that this is expected / permanent. |
| User runs the script on Windows 10 pre-1803 | `ControlService` likely succeeds; `WaaSMedicSvc` stops normally (`STOPPED` outcome). |

The only user-visible signal is the `LOG_LEVEL_ERROR` log entry, which is easy to miss and carries no context explaining that the failure is a Windows protection mechanism, not a permissions or configuration problem with the script.

### 5. ADR-0005 alignment

ADR-0005 (`docs/adr/0005-graceful-only-service-stop.md`) explicitly acknowledges this case in its Consequences section:

> A service that persistently ignores `SERVICE_CONTROL_STOP` (e.g., a protected or malfunctioning
> service) will never be stopped by this tool. The outcome will remain `TIMED_OUT` on every cycle
> until the service is stopped by other means.

Note: ADR-0005 describes the persistent-failure outcome as `TIMED_OUT`, but the actual outcome for a protected service is `FAILED` (ControlService returns an error immediately; the service never enters the pending-poll list to time out). The ADR's framing is slightly imprecise for this specific case — the semantics are the same (permanent failure, retry each cycle) but the outcome string differs.

---

## Root cause

There is no code defect. The behavior is correct given the architecture:

1. `ControlService` fails with `ERROR_ACCESS_DENIED` (5).
2. `_SM_Win32ErrToOutcome(5)` returns `FAILED` (correct — 5 is not a "does not exist" or "already stopped" condition).
3. `_RunServiceBatchStop` logs the FAILED outcome at ERROR level and moves on.
4. ADR-0005 deliberately rejects any force-kill fallback.

The gap is that nothing in the user-facing layer (README, log message text, tray notification) explains that `WaaSMedicSvc` will always fail on Windows 10 1803+ and that this is expected behavior, not a misconfiguration.

---

## Findings

### Is this a code issue or a documentation issue?

Primarily a **documentation issue**, with a secondary **log-noise issue**.

**Documentation gap (confirmed):** The README (`CLAUDE.md`) lists `WaaSMedicSvc` in the service target array without any note about the protection mechanism. A user who sees repeated `"Service stop failed: WaaSMedicSvc (Win32: 5)"` log entries has no in-product explanation.

**Log noise issue (minor):** The FAILED entry is emitted at `LOG_LEVEL_ERROR` on every 10-second cycle. For a service that will never succeed, this produces unbounded log growth and trains the user to ignore ERROR-level entries. A one-time or rate-limited note, or a note field explaining the Win32=5 on WaaSMedicSvc specifically, would reduce noise without changing behavior.

**Code change is not warranted for correctness:** The routing to FAILED is correct. Adding a `PROTECTED` outcome or a special-case branch for Win32=5 on specific service names would add complexity that conflicts with ADR-0005's deliberate simplicity. The service manager already surfaces the Win32 error code (5) in the log entry, which is sufficient for a technically literate user to diagnose.

---

## Recommendations

### Recommended: Documentation update (README / known-limitations section)

Add a note to the README (or a `docs/KNOWN-LIMITATIONS.md` file) stating:

- `WaaSMedicSvc` is protected on Windows 10 1803+ and cannot be stopped by any user-mode SCM call, including this script.
- The script will log `"Service stop failed: WaaSMedicSvc (Win32: 5)"` on every cycle. This is expected and not a bug.
- Users who want to suppress this log noise may remove `WaaSMedicSvc` from `$aSvcTargetNames` in `Stop Services Processes.au3`.

### Optional: Improve the log message note field for Win32=5

`_SM_StopServicesBatch` already populates `$aResults[$i][5]` (the note field) for START_PENDING and TIMED_OUT outcomes. The same mechanism could populate a note for `ERROR_ACCESS_DENIED` (5):

> "Access denied — service may be protected (WaaSMedicSvc on Windows 10 1803+)"

This would surface in `_RunServiceBatchStop` only if the FAILED case is updated to include the note in the log message. This is a low-priority quality-of-life change, not a correctness fix. It must not introduce a service-name-specific branch in `ServiceManager.au3` (that belongs in the caller or documentation layer).

### Not recommended: Code changes to routing or outcome classification

- Do not add a `PROTECTED` outcome string — it would be indistinguishable from FAILED at the call site and complicates the outcome contract without enabling any different handling.
- Do not add a `WaaSMedicSvc`-specific branch in `_SM_Win32ErrToOutcome` — Win32=5 is a general access-denied error; special-casing a service name inside a generic error-mapping function violates separation of concerns.
- Do not remove `WaaSMedicSvc` from the default target list without user instruction — it may be stoppable on older or specially configured builds.

### ADR-0005 note (minor)

The Consequences section of ADR-0005 says a persistently unresponsive service "will remain `TIMED_OUT`". For protected services, the actual outcome is `FAILED` (immediate ControlService rejection, not a timeout). Consider updating the ADR wording to: "outcome will remain `FAILED` or `TIMED_OUT` on every cycle" to cover both cases accurately.

---

## Summary table

| Question | Finding |
|---|---|
| What Win32 error does ControlService return for WaaSMedicSvc? | `ERROR_ACCESS_DENIED` (5), possibly also `ERROR_SERVICE_CANNOT_ACCEPT_CTRL` (1061) |
| Does ServiceManager.au3 route this to FAILED or UNAVAILABLE? | `FAILED` — correct per `_SM_Win32ErrToOutcome` |
| Does _RunServiceBatchStop log it? | Yes — `LOG_LEVEL_ERROR` every 10-second cycle |
| Does it retry? | No within-cycle retry; the monitoring loop retries every 10 s indefinitely |
| Is there any user notification beyond the log? | No — no tray tooltip, no MsgBox |
| Is this a code defect? | No — behavior is correct per ADR-0005 |
| What needs to change? | Documentation (README known-limitations) and optionally the log note field |
