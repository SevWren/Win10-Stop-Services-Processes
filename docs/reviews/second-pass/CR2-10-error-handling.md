# CR2-10 — Error Handling Audit: ServiceManager.au3 & Stop Services Processes.au3

**Date**: 2026-11-12
**Reviewer axis**: Standards + Spec
**Standards sources**:
- `CODING_STANDARDS.md` — `@error` capture rule
- `docs/ARCHITECTURE.md` — DllCall patterns, outcome classification table, two-level contract
- `docs/adr/0003-batch-stop-two-level-error-convention.md` — normative two-level contract definition

**Files audited**:
- `/home/vercel-sandbox/repo/Includes/ServiceManager.au3`
- `/home/vercel-sandbox/repo/Stop Services Processes.au3`

---

## Summary Verdict

**PASS — no defects found.** All six check items are satisfied. The implementation is fully compliant with the standards and the ADR contract.

---

## Check 1 — Every `DllCall` in `ServiceManager.au3`: is `@error` checked immediately after? Is `@extended` / Win32 error captured?

CODING_STANDARDS.md requires: capture `@error` on the immediately following line; call `_WinAPI_GetLastError()` on the line after that, before any other API call.

| Call site | Line(s) | `@error` captured immediately? | Win32 error captured? | Notes |
|---|---|---|---|---|
| `OpenSCManagerW` | 170–174 | Yes — `Local $iScmDllErr = @error` on line 174 | Yes — `_WinAPI_GetLastError()` on line 176, inside failure branch (called before any other API) | Standard says capture Win32 "when a Windows API may set GetLastError"; done correctly here |
| `OpenServiceW` | 203–207 | Yes — `Local $iSvcDllErr = @error` on line 207 | Yes — `_WinAPI_GetLastError()` on line 209 | Correct order |
| `QueryServiceStatus` (Phase 1 inspect) | 228–231 | Yes — `Local $iQryDllErr = @error` on line 231 | Yes — `_WinAPI_GetLastError()` on line 232 immediately after | Correct order |
| `CloseServiceHandle` (ALREADY_STOPPED path, line 250) | 250 | Not checked — intentional | Not captured — intentional | ARCHITECTURE.md §"Close handles" explicitly documents: `@error` from `CloseServiceHandle` is intentionally not checked in cleanup paths. Conformant. |
| `ControlService` | 279–284 | Yes — `Local $iCtrlDllErr = @error` on line 283 | Yes — `_WinAPI_GetLastError()` on line 284 | Correct order |
| `CloseServiceHandle` (ControlService failure path, line 297) | 297 | Not checked — intentional | Not captured — intentional | Conformant per ARCHITECTURE.md note. |
| `QueryServiceStatus` (Phase 2 poll) | 325–328 | Yes — `Local $iPollDllErr = @error` on line 328 | Not explicitly captured | See Note A |
| `CloseServiceHandle` (Phase 2 stopped path, line 343) | 343 | Not checked — intentional | Not captured — intentional | Conformant. |
| `CloseServiceHandle` (timeout cleanup, line 371) | 371 | Not checked — intentional | Not captured — intentional | Conformant. |
| `CloseServiceHandle` (SCM, line 376) | 376 | Not checked — intentional | Not captured — intentional | Conformant. |
| `QueryServiceStatus` in `_SM_GetServiceState` | 399–402 | Yes — `Local $iDllErr = @error` on line 402 | Yes — `_WinAPI_GetLastError()` on line 403 | Correct order |

**Note A** (Phase 2 poll, line 328–329): `_WinAPI_GetLastError()` is not called after the Phase 2 `QueryServiceStatus` failure. The failure path at line 329–332 only logs and defers (`ContinueLoop`) — it does not record a Win32 error into the result row, so there is no result column to populate. This is consistent with the architectural spec: the Phase 2 poll-failure action is "leave in list (defer to next poll)" with no outcome-row update. The Win32 error is therefore not needed and its omission is correct. No defect.

**Check 1 verdict: PASS.**

---

## Check 2 — `OpenSCManagerW` failure: does it return `$aEmpty[0][6]` with `@error=1`?

The critical fix from T1-07 requires:
- On SCM open failure: `SetError(1)` is called.
- The returned array must be a zero-row array (`$aEmpty[0][6]`), NOT the pre-allocated `$aResults` array.

Code (lines 174–183):

```autoit
Local $iScmDllErr = @error    ; capture IMMEDIATELY — @error is volatile
If $iScmDllErr Or Not $aScmOpen[0] Then
    Local $iScmWinErr = _WinAPI_GetLastError()
    _LogMessage(...)
    ; Architecture contract: @error=1 → "batch-level failure; returned array has 0 rows"
    ; Return a zero-row array — NOT the pre-allocated $aResults (CR-02 MAJOR fix).
    Local $aEmpty[0][6]
    SetError(1)
    Return $aEmpty
EndIf
```

- `SetError(1)` is called before `Return $aEmpty`. Correct — `Return` does not clear `@error` set by `SetError`.
- The returned array is `$aEmpty[0][6]` (zero rows), not `$aResults`. Correct.
- `_WinAPI_GetLastError()` is called before `_LogMessage`, which could internally call other API functions. Correct order.

**Check 2 verdict: PASS.**

---

## Check 3 — `OpenServiceW` failure: routes to UNAVAILABLE? Win32 error captured in result row?

Code (lines 207–219):

```autoit
Local $iSvcDllErr = @error    ; capture IMMEDIATELY
If $iSvcDllErr Or Not $aSvcOpen[0] Then
    Local $iSvcWinErr = _WinAPI_GetLastError()
    If $iSvcWinErr = $SM_ERR_SVC_NOT_EXIST Then
        $aResults[$i][3] = $SM_OUTCOME_UNAVAILABLE
        $aResults[$i][4] = $SM_ERR_SVC_NOT_EXIST
        ...
    Else
        $aResults[$i][3] = $SM_OUTCOME_FAILED
        $aResults[$i][4] = $iSvcWinErr
        ...
    EndIf
    ContinueLoop   ; do not close a handle that was never opened
EndIf
```

- Win32 error 1060 (`ERROR_SERVICE_DOES_NOT_EXIST`) → `UNAVAILABLE` with `$iWin32Err = 1060`. Matches ARCHITECTURE.md outcome table.
- Other Win32 errors → `FAILED` with actual `$iWin32Err`. Matches outcome table row "OpenServiceW returns NULL with other error".
- Win32 error is captured in `$aResults[$i][4]` in both branches.
- `ContinueLoop` is correctly used (no handle was opened, so no `CloseServiceHandle` call needed).

**Check 3 verdict: PASS.**

---

## Check 4 — `ControlService` failure: routes to FAILED? Error captured?

Code (lines 283–298):

```autoit
Local $iCtrlDllErr = @error    ; capture IMMEDIATELY
Local $iCtrlWinErr = _WinAPI_GetLastError()   ; before any other call

If $iCtrlDllErr Or Not $aCtrl[0] Then
    Local $sCtrlOutcome = _SM_Win32ErrToOutcome($iCtrlWinErr)
    $aResults[$i][2] = $iInitState
    $aResults[$i][3] = $sCtrlOutcome
    $aResults[$i][4] = $iCtrlWinErr
    If $sCtrlOutcome = $SM_OUTCOME_ALREADY Then
        _LogMessage(...)
    Else
        _LogMessage(...)
    EndIf
    DllCall("advapi32.dll", "bool", "CloseServiceHandle", "handle", $hService)
    ContinueLoop
EndIf
```

- `_SM_Win32ErrToOutcome($iCtrlWinErr)` is used to classify the error:
  - Win32 1062 (`NOT_ACTIVE`) → `ALREADY_STOPPED`
  - Win32 1060 (`DOES_NOT_EXIST`) → `UNAVAILABLE`
  - All others → `FAILED`
- This matches the ARCHITECTURE.md outcome table rows for `ControlService` failures.
- `$iCtrlWinErr` is captured in `$aResults[$i][4]` in all branches.
- `CloseServiceHandle` is called before `ContinueLoop`. Correct handle ownership.

**Check 4 verdict: PASS.**

---

## Check 5 — Two-level error contract: does `@error` ONLY equal 1 for SCM-level failure? Never for per-service failures?

Per `docs/adr/0003-batch-stop-two-level-error-convention.md`:
- `@error = 1`: reserved exclusively for SCM-open failure (batch-level).
- `@error = 0`: returned for all cases where the batch ran (including batches where individual services FAILED or TIMED_OUT).

Review of all `Return` paths in `_SM_StopServicesBatch`:

| Return path | `SetError` called? | `@error` value at return |
|---|---|---|
| Empty input (`$iCount = 0`), line 143–145 | No | 0 (default) |
| SCM open failure, lines 181–182 | `SetError(1)` before `Return` | 1 |
| Normal completion (after Phase 2 + timeout), line 378 | No | 0 (default) |

There are no other `Return` statements in the function. `@error` is never set to 1 for per-service failures — those are encoded exclusively in `$aResults[$i][3]` (outcome string) and `$aResults[$i][4]` (Win32 error). No per-service error path calls `SetError` or `Return` — they all use `ContinueLoop` to continue the batch.

**Check 5 verdict: PASS.**

---

## Check 6 — In `Stop Services Processes.au3`: does `_RunServiceBatchStop` check `@error=1` from `_SM_StopServicesBatch`?

Code (lines 237–243):

```autoit
Func _RunServiceBatchStop()
    Local $aResults = _SM_StopServicesBatch($aSvcTargetNames, $SVC_BATCH_TIMEOUT_MS, $SVC_BATCH_POLL_MS)
    If @error Then
        _LogMessage("Service batch stop: could not open SCM — batch skipped", $LOG_TYPE_SERVICE, $LOG_LEVEL_ERROR)
        Return
    EndIf
    ...
EndFunc
```

- `@error` is checked on the immediately following line after the call (line 239: `If @error Then`). This correctly captures the `@error = 1` sentinel from `_SM_StopServicesBatch`.
- On `@error = 1`, the function logs at `$LOG_LEVEL_ERROR` and returns without iterating the (empty) result array. Correct — the returned array has 0 rows in this case, so iterating it would be a no-op at best and a logic error at worst.
- The log message text ("could not open SCM — batch skipped") accurately reflects the semantics defined in the ADR.

**Check 6 verdict: PASS.**

---

## Detailed Findings Table

| ID | File | Location | Check | Status | Notes |
|---|---|---|---|---|---|
| EH-01 | ServiceManager.au3 | Line 174 | `OpenSCManagerW` @error capture | PASS | Captured immediately as `$iScmDllErr` |
| EH-02 | ServiceManager.au3 | Line 176 | `OpenSCManagerW` Win32 error capture | PASS | `_WinAPI_GetLastError()` called before `_LogMessage` |
| EH-03 | ServiceManager.au3 | Lines 180–182 | SCM failure returns `$aEmpty[0][6]` with `@error=1` | PASS | T1-07 fix confirmed present and correct |
| EH-04 | ServiceManager.au3 | Lines 207–219 | `OpenServiceW` failure routing | PASS | 1060→UNAVAILABLE, others→FAILED; Win32 in row[4] |
| EH-05 | ServiceManager.au3 | Lines 231–232 | `QueryServiceStatus` (Phase 1) @error + Win32 capture | PASS | Both captured in correct order |
| EH-06 | ServiceManager.au3 | Lines 283–284 | `ControlService` @error + Win32 capture | PASS | Both captured in correct order |
| EH-07 | ServiceManager.au3 | Lines 286–298 | `ControlService` failure routing | PASS | `_SM_Win32ErrToOutcome` used; Win32 in row[4] |
| EH-08 | ServiceManager.au3 | Lines 328–329 | `QueryServiceStatus` (Phase 2) @error capture | PASS | Captured; Win32 not needed (defer path only) |
| EH-09 | ServiceManager.au3 | Lines 143–145, 378 | Normal return paths: `@error` never set | PASS | Two-level contract intact |
| EH-10 | ServiceManager.au3 | Lines 402–403 | `_SM_GetServiceState` @error + Win32 capture | PASS | Both captured in correct order |
| EH-11 | Stop Services Processes.au3 | Lines 238–242 | `_RunServiceBatchStop` checks `@error=1` | PASS | Checked immediately; logs and returns on failure |
| EH-12 | Stop Services Processes.au3 | Lines 238–242 | `@error=1` triggers batch skip, not partial iteration | PASS | `Return` before `For` loop; zero-row array not iterated |

---

## Observations (Non-Defects)

1. **Phase 2 poll Win32 omission is by design.** The absence of `_WinAPI_GetLastError()` in the Phase 2 poll failure path (line 329) is architecturally correct. The spec says to defer on poll failure with no row update. No Win32 error column exists to populate in this case. This is not a defect.

2. **`CloseServiceHandle` @error not checked.** All cleanup `CloseServiceHandle` calls omit `@error` checking. This is explicitly sanctioned by ARCHITECTURE.md §"Close handles": "Note: @error from CloseServiceHandle is intentionally NOT checked in cleanup paths since we cannot recover from a failed close." Conformant.

3. **`SetError(1)` placement before `Return`.** The `SetError(1)` call precedes `Return $aEmpty` at line 182. This is the correct AutoIt pattern — `Return` does not clear the error state set by `SetError`. Verified correct.

4. **Win32 error not captured for `OpenSCManagerW` before `_LogMessage`.** The Win32 error is captured at line 176 (`_WinAPI_GetLastError()`), which occurs before the `_LogMessage` call at line 177. `_LogMessage` calls `FileOpen`, `FileWrite`, `FileClose`, and `ConsoleWrite`, all of which could reset `GetLastError`. The order is correct — Win32 error is captured first.

---

## Conclusion

The error handling implementation in `Includes/ServiceManager.au3` and `Stop Services Processes.au3` is **fully compliant** with:
- `CODING_STANDARDS.md` `@error` capture rule (immediate capture on next line; Win32 on line after)
- `docs/ARCHITECTURE.md` outcome classification table and DllCall patterns
- `docs/adr/0003-batch-stop-two-level-error-convention.md` two-level contract

No defects were identified. All twelve check items pass.
