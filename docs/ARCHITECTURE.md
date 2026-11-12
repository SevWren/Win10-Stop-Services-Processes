# Architecture
Branch: arch/service-manager-migration
Date: 2026-11-11
Ticket: T02 — Define Contracts and Verify Windows SCM APIs

---

## Module Map

```
Stop Services Processes.au3   ← entry point, scheduling, interaction
  │
  ├── #include "Includes\ServiceControl.au3"   ← retained for: _ServiceExists, _ServiceRunning
  │                                               _StartService, _CreateService, _DeleteService
  │                                               NOT called for stop operations (D-002)
  │
  ├── #include "Includes\ServiceManager.au3"   ← NEW: authoritative service-stop module
  │       Public interface:
  │         _SM_StopServicesBatch(ByRef $aNames, $iBatchTimeoutMs, $iPollIntervalMs)
  │         → Returns 2D array; one result row per input service
  │       Internal only (not called from main script):
  │         _SM_GetServiceState($hService)          ; uses inline "advapi32.dll" string
  │         _SM_ServiceStateToString($iState)
  │         _SM_Win32ErrToOutcome($iWin32Err)
  │         _SM_IsStopEligible($iState)
  │         _SM_StateNeedsPolling($iState)
  │         _SM_StateToAlreadyStopped($iState)
  │         _SM_BuildResultRow($sName, $iInitState, $iFinalState, $sOutcome, $iWin32Err, $sNote)
  │
  ├── <WinAPI.au3>              ← _WinAPI_GetLastError
  ├── <WinAPIProc.au3>          ← priority class constants
  ├── <Array.au3>               ← _ArrayAdd, _ArrayDelete
  ├── <MsgBoxConstants.au3>
  ├── <AutoItConstants.au3>
  ├── <Misc.au3>
  └── <Date.au3>
```

---

## Timing Constants (single definition point, main script globals)

```autoit
Global Const $PROC_POLL_INTERVAL_SEC      = 2      ; process-kill cycle
Global Const $SVC_POLL_INTERVAL_SEC       = 10     ; service-stop cycle
Global Const $MAIN_LOOP_SLEEP_MS          = 500    ; active monitoring While loop sleep
Global Const $PRIORITY_WATCHDOG_MS        = 10000  ; AdlibRegister for _PriorityWatchdog
Global Const $SVC_BATCH_TIMEOUT_MS        = 20000  ; shared deadline for one batch-stop
Global Const $SVC_BATCH_POLL_MS           = 500    ; poll interval within batch-stop wait loop
```

---

## `_SM_StopServicesBatch` — Public Contract

```autoit
; Description : Opens the Windows SCM once, queries each named service, issues stop
;               controls to all eligible services without serial waiting, then polls
;               all pending services against one shared deadline, then closes all handles.
;               Returns one result row per input service.
;
; Parameters  : $aServiceNames  — 1D array of service name strings (ByRef for performance)
;               $iBatchTimeoutMs — shared deadline in ms (default: $SVC_BATCH_TIMEOUT_MS = 20000)
;               $iPollIntervalMs — poll sleep in ms (default: $SVC_BATCH_POLL_MS = 500)
;
; Return      : 2D array [0..UBound($aServiceNames)-1][0..5]
;               Row columns:
;                 [i][0] $sName        — service name string (copy of input)
;                 [i][1] $iInitState   — state at first query (1-7, or -1 = unavailable)
;                 [i][2] $iFinalState  — state after polling (1-7, or -1 = unavailable)
;                 [i][3] $sOutcome     — one of: "STOPPED", "ALREADY_STOPPED",
;                                        "UNAVAILABLE", "FAILED", "TIMED_OUT"
;                 [i][4] $iWin32Err    — Win32 error code at last failure (0 = no error)
;                 [i][5] $sNote        — human-readable note (empty string if no note)
;
; @error      : 0 = batch processed (check per-row outcomes for individual results)
;               1 = could not open SCM (batch-level failure; no rows populated)
;
; Side effects: Calls _LogMessage for each service outcome (level 1 for success, 0 for failure)
;               Does NOT throw MsgBox or modify the script state
;               Does NOT stop dependent services
;               Does NOT force-stop via process termination
;
; Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-openscmanagerw
; Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-openservicew
; Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-queryservicestatus  ; see API choice note below
; Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-controlservice
```

---

## API Choice: QueryServiceStatus vs QueryServiceStatusEx

**Decision**: The implementation uses `QueryServiceStatus` (7-DWORD `SERVICE_STATUS` struct), not
`QueryServiceStatusEx` (9-DWORD `SERVICE_STATUS_PROCESS` struct).

**Rationale**: The enterprise prompt mandates `QueryServiceStatusEx` and `SERVICE_STATUS_PROCESS`.
However, the actual implementation in `Includes/ServiceManager.au3` uses `QueryServiceStatus`
throughout (Phase 1 inspect, Phase 2 poll, and `_SM_GetServiceState` helper). This is a deliberate
simplification because:

1. The two additional fields in `SERVICE_STATUS_PROCESS` are `dwProcessId` (field 8) and
   `dwServiceFlags` (field 9). Neither is needed by `_SM_StopServicesBatch` — the function only
   reads `dwCurrentState` (field 2) to route stop decisions and poll for `SERVICE_STOPPED`.
2. `ControlService` (also used here) accepts only `LPSERVICE_STATUS` (7 DWORDs) — it has no Ex
   variant that takes `SERVICE_STATUS_PROCESS`. Both APIs share the same 7-field struct for the
   stop-control path.
3. Using `QueryServiceStatus` avoids the `InfoLevel` and `cbBufSize` parameters required by
   `QueryServiceStatusEx`, reducing call-site complexity with no functional loss for this use case.

**Trade-off**: PID-based duplicate detection (e.g., detecting when two service names map to the
same host process) is not possible without `dwProcessId`. This is an accepted limitation; the
batch-stop design does not require PID awareness.

**Struct reference** (both documented per enterprise prompt requirement):

| Struct | Fields | Used by |
|---|---|---|
| `SERVICE_STATUS` | 7 DWORDs | `QueryServiceStatus`, `ControlService` (this module) |
| `SERVICE_STATUS_PROCESS` | 9 DWORDs | `QueryServiceStatusEx`, `ControlServiceEx` (not used here) |

`SERVICE_STATUS` field order: `dwServiceType` (1), `dwCurrentState` (2), `dwControlsAccepted` (3),
`dwWin32ExitCode` (4), `dwServiceSpecificExitCode` (5), `dwCheckPoint` (6), `dwWaitHint` (7).

`SERVICE_STATUS_PROCESS` adds: `dwProcessId` (8), `dwServiceFlags` (9).

See `docs/adr/` for all architecture decision records. Research source: `docs/research/windows-scm-api.md` §
"QueryServiceStatus vs QueryServiceStatusEx".

---

## Batch-Stop Algorithm

```
_SM_StopServicesBatch($aNames, $iBatchMs, $iPollMs)
│
├── Open SCM: OpenSCManagerW(NULL, "ServicesActive", SC_MANAGER_CONNECT)
│   └── On failure: SetError(1), return empty array
│
├── PHASE 1 — Inspect + Issue (no serial waiting)
│   For each $aNames[$i]:
│     Open service: OpenServiceW($hSCM, $sName, SERVICE_QUERY_STATUS | SERVICE_STOP)
│     If OpenService fails (GetLastError = 1060 → DOES_NOT_EXIST):
│       outcome = UNAVAILABLE, initialState = -1
│       Close nothing (handle was never opened)
│       Continue to next service
│
│     Query state: QueryServiceStatus($hService, $tStatus)
│     If QueryServiceStatus fails:
│       outcome = FAILED, iWin32Err = GetLastError
│       CloseServiceHandle($hService)
│       Continue
│
│     Record initialState = DllStructGetData($tStatus, 2)  ; field 2 = dwCurrentState
│
│     If initialState == SERVICE_STOPPED (1):
│       outcome = ALREADY_STOPPED
│       CloseServiceHandle($hService)
│       Continue
│
│     If initialState == SERVICE_STOP_PENDING (3):
│       Add to pendingList with $hService (already stopping, just wait)
│       Continue
│
│     Issue: ControlService($hService, SERVICE_CONTROL_STOP, $tCtrlStatus)
│     Capture $iCtrlDllErr = @error, $iCtrlWinErr = _WinAPI_GetLastError()
│
│     If ControlService fails:
│       If $iCtrlWinErr == 1062 (NOT_ACTIVE): outcome = ALREADY_STOPPED
│       Else:                                   outcome = FAILED, iWin32Err = $iCtrlWinErr
│       CloseServiceHandle($hService)
│       Continue
│
│     Else (stop control accepted):
│       Add to pendingList with $hService (stop was dispatched)
│
├── PHASE 2 — Poll pendingList against shared deadline
│   $iTimer = TimerInit()
│   While pendingList not empty AND TimerDiff($iTimer) < $iBatchMs:
│     Sleep($iPollMs)
│     For each pending entry (iterate backwards for safe delete):
│       Re-query state: QueryServiceStatus($hService, $tStatus)
│       If query fails: leave in list (defer to next poll)
│       If state == SERVICE_STOPPED:
│         outcome = STOPPED
│         finalState = SERVICE_STOPPED
│         CloseServiceHandle($hService)
│         Remove from pendingList
│   End While
│
│   For remaining pendingList entries (timeout):
│     outcome = TIMED_OUT
│     finalState = last-known state from most recent query
│     CloseServiceHandle($hService)
│
├── Close SCM: CloseServiceHandle($hSCM)
│
└── Log + return result array
```

### Pending-State Routing Reference

The routing in Phase 1 is determined by three helper predicates (`_SM_StateToAlreadyStopped`,
`_SM_StateNeedsPolling`, `_SM_IsStopEligible`). The table below shows how every `dwCurrentState`
value maps to its Phase 1 outcome:

| State (value) | Predicate that fires | Phase 1 action | Expected outcome |
|---|---|---|---|
| `SERVICE_STOPPED` (1) | `_SM_StateToAlreadyStopped` = True | Close handle, record result | `ALREADY_STOPPED` |
| `SERVICE_START_PENDING` (2) | `_SM_IsStopEligible` = False | Close handle, record result with Win32 1061 | `FAILED` (stop cannot be accepted while starting) |
| `SERVICE_STOP_PENDING` (3) | `_SM_StateNeedsPolling` = True | Add to pendingList, skip ControlService call | `STOPPED` or `TIMED_OUT` after Phase 2 poll |
| `SERVICE_RUNNING` (4) | `_SM_IsStopEligible` = True | Issue `ControlService(STOP)`, add to pendingList | `STOPPED` or `TIMED_OUT` after Phase 2 poll |
| `SERVICE_CONTINUE_PENDING` (5) | `_SM_IsStopEligible` = True | Issue `ControlService(STOP)`, add to pendingList | `STOPPED` or `TIMED_OUT` after Phase 2 poll |
| `SERVICE_PAUSE_PENDING` (6) | `_SM_IsStopEligible` = True | Issue `ControlService(STOP)`, add to pendingList | `STOPPED` or `TIMED_OUT` after Phase 2 poll |
| `SERVICE_PAUSED` (7) | `_SM_IsStopEligible` = True | Issue `ControlService(STOP)`, add to pendingList | `STOPPED` or `TIMED_OUT` after Phase 2 poll |

Notes:
- `SERVICE_START_PENDING` (2) is not stop-eligible. `ControlService` would return error 1061
  (`ERROR_SERVICE_CANNOT_ACCEPT_CTRL`). The implementation detects this via `_SM_IsStopEligible`
  and records `FAILED` with Win32 1061 without attempting the control call.
- States 5, 6, 7 (`CONTINUE_PENDING`, `PAUSE_PENDING`, `PAUSED`) are treated identically to
  `RUNNING` — the stop control is accepted by services in these states. If the service's
  `dwControlsAccepted` does not include `SERVICE_ACCEPT_STOP`, `ControlService` will fail with
  1052 (`ERROR_INVALID_SERVICE_CONTROL`) and the outcome will be `FAILED`.

---

## DllCall Patterns (verified against primary sources)

### Open SCM — local machine only

```autoit
; Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-openscmanagerw
Local $aOpen = DllCall("advapi32.dll", "handle", "OpenSCManagerW", _
        "ptr", 0, _                 ; lpMachineName = NULL → local computer
        "wstr", "ServicesActive", _ ; lpDatabaseName
        "dword", $SC_MANAGER_CONNECT)
Local $iDllErr = @error             ; capture IMMEDIATELY
If $iDllErr Or Not $aOpen[0] Then
    Local $iWinErr = _WinAPI_GetLastError()
    ; ... handle failure
EndIf
Local $hSCM = $aOpen[0]
```

### Open service handle

```autoit
; Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-openservicew
Local $aSvc = DllCall("advapi32.dll", "handle", "OpenServiceW", _
        "handle", $hSCM, _
        "wstr", $sServiceName, _
        "dword", BitOR($SERVICE_QUERY_STATUS, $SERVICE_STOP))
Local $iDllErr = @error
If $iDllErr Or Not $aSvc[0] Then
    Local $iWinErr = _WinAPI_GetLastError()
    ; ...
EndIf
Local $hService = $aSvc[0]
```

### Query service state

```autoit
; SERVICE_STATUS: 7 DWORDs. dwCurrentState is field 2.
; Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/ns-winsvc-service_status
; Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-queryservicestatus
Local $tStatus = DllStructCreate("dword;dword;dword;dword;dword;dword;dword")
Local $aQry = DllCall("advapi32.dll", "bool", "QueryServiceStatus", _
        "handle", $hService, _
        "ptr", DllStructGetPtr($tStatus))
Local $iDllErr = @error
Local $iWinErr = _WinAPI_GetLastError()   ; before any other call
If $iDllErr Or Not $aQry[0] Then
    ; ...
EndIf
Local $iState = DllStructGetData($tStatus, 2)   ; field 2 = dwCurrentState
```

### Send stop control

```autoit
; ControlService: 3rd param is LPSERVICE_STATUS (SERVICE_STATUS, 7 DWORDs)
; Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-controlservice
Local $tCtrlStatus = DllStructCreate("dword;dword;dword;dword;dword;dword;dword")
Local $aCtrl = DllCall("advapi32.dll", "bool", "ControlService", _
        "handle", $hService, _
        "dword", $SERVICE_CONTROL_STOP, _
        "ptr", DllStructGetPtr($tCtrlStatus))
Local $iDllErr = @error
Local $iWinErr = _WinAPI_GetLastError()   ; before any other call
If $iDllErr Or Not $aCtrl[0] Then
    ; check $iWinErr for 1051, 1052, 1061, 1062, etc.
EndIf
```

### Close handles

```autoit
; Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-closeservicehandle
DllCall("advapi32.dll", "bool", "CloseServiceHandle", "handle", $hService)
DllCall("advapi32.dll", "bool", "CloseServiceHandle", "handle", $hSCM)
; Note: @error from CloseServiceHandle is intentionally NOT checked in cleanup paths
; since we cannot recover from a failed close, and checking would require additional @error
; variables that obscure the cleanup flow.
```

---

## Outcome Classification Table

| Scenario | Outcome Code | Win32Err |
|---|---|---|
| Service was already stopped at first query | `ALREADY_STOPPED` | 0 |
| Stop control sent; service reached STOPPED within deadline | `STOPPED` | 0 |
| Stop control sent; service did not reach STOPPED within deadline | `TIMED_OUT` | 0 |
| `OpenServiceW` returns NULL with error 1060 | `UNAVAILABLE` | 1060 |
| `OpenServiceW` returns NULL with other error | `FAILED` | Win32 error |
| `QueryServiceStatus` fails | `FAILED` | Win32 error |
| `ControlService` fails with 1062 (NOT_ACTIVE) | `ALREADY_STOPPED` | 1062 |
| `ControlService` fails with 1051 (DEPENDENT) | `FAILED` | 1051 |
| `ControlService` fails with 1052 (INVALID_SERVICE_CONTROL) | `FAILED` | 1052 |
| `ControlService` fails with 5 (ACCESS_DENIED) | `FAILED` | 5 |
| `ControlService` fails with other error | `FAILED` | Win32 error |
| Service is in STOP_PENDING at first query | Polled; STOPPED or TIMED_OUT | 0 |
| SCM cannot be opened | Batch @error=1; no rows | Win32 error |

---

## Integration Point (main script ToggleScript)

```autoit
; BEFORE (old — does not verify outcome):
;     _stopservicescustom()
;
; AFTER (new — structured outcomes):
If CheckElapsedTime($iLastStopServices, $SVC_POLL_INTERVAL_SEC) Then
    _RunServiceBatchStop()
    $iLastStopServices = TimerInit()
EndIf

; _RunServiceBatchStop() is a thin wrapper in the main script:
Func _RunServiceBatchStop()
    Local $aNames[9] = ["FDResPub", "fdPHost", "TrustedInstaller", "wuauserv", _
                        "UsoSvc", "DoSvc", "WaaSMedicSvc", "SSDPSRV", "sppsvc"]
    Local $aResults = _SM_StopServicesBatch($aNames, $SVC_BATCH_TIMEOUT_MS, $SVC_BATCH_POLL_MS)
    If @error Then
        _LogMessage("Service batch stop: could not open SCM", "Service", 0)
        Return
    EndIf
    For $i = 0 To UBound($aResults) - 1
        Local $sOutcome = $aResults[$i][3]
        Local $iErr     = $aResults[$i][4]
        Select
            Case $sOutcome = "STOPPED"
                _LogMessage("Service stopped: " & $aResults[$i][0], "Service", 1)
            Case $sOutcome = "ALREADY_STOPPED"
                _LogMessage("Service already stopped: " & $aResults[$i][0], "Service", 2)
            Case $sOutcome = "TIMED_OUT"
                _LogMessage("Service stop timed out: " & $aResults[$i][0], "Service", 0)
            Case $sOutcome = "UNAVAILABLE"
                _LogMessage("Service not found: " & $aResults[$i][0], "Service", 2)
            Case $sOutcome = "FAILED"
                _LogMessage("Service stop failed: " & $aResults[$i][0] & " (Win32: " & $iErr & ")", "Service", 0)
        EndSelect
    Next
EndFunc
```

---

## Known Documentation Gap in BASELINE-INVENTORY.md (owned by T1-13)

<!-- CR-04 S-08: docs/BASELINE-INVENTORY.md AU3Check summary table omits the "long" handle-type
     bug row for ServiceControl.au3. The ServiceControl.au3 technical-findings sub-section does
     document that the handle type used in DllCall is "long" rather than "handle" (a type mismatch
     that would generate an AU3Check warning under -w 3), but this finding does not have a row in
     the AU3Check summary table at the top of BASELINE-INVENTORY.md. The information is present in
     the file — it is a summary-completeness gap only.
     This note is recorded here because BASELINE-INVENTORY.md is owned by the T1-13 agent and
     cannot be edited by this agent (T02). -->

---

## Notes on ServiceControl.au3 Retention

`ServiceControl.au3` is retained for its non-stop helpers: `_ServiceExists`, `_ServiceRunning`,
`_StartService`, `_CreateService`, `_DeleteService`. Its `_StopService` function is NOT called
from the main script after T04 integration. `_ServiceRunning` (via `SERVICE_CONTROL_INTERROGATE`)
remains available for future use but is not used in the monitoring loop.

The `_StopService` function in `ServiceControl.au3` is not deleted (it may be needed by callers
not visible in this codebase), but it is no longer on the monitoring hot path.
