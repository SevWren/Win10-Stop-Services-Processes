; =============================================================================
; ServiceManager.au3 — Native SCM batch-stop adapter
; Branch : arch/service-manager-migration
; Ticket : T03 — Build ServiceManager.au3 + Deterministic Test Harness
; Date   : 2026-11-11
;
; RESPONSIBILITY
;   Authoritative service-stop implementation for Stop Services Processes.au3.
;   Replaces the broken _StopService() path in ServiceControl.au3 for stop ops.
;   ServiceControl.au3 is RETAINED for _ServiceExists, _ServiceRunning,
;   _StartService, _CreateService, _DeleteService.
;
; PUBLIC INTERFACE
;   _SM_StopServicesBatch(ByRef $aServiceNames [, $iBatchTimeoutMs [, $iPollIntervalMs]])
;     → 2D array [n][6]: one row per input service
;     → @error 1 if SCM cannot be opened (batch-level failure)
;
; INTERNAL HELPERS (not called from main script)
;   _SM_ServiceStateToString($iState)
;   _SM_Win32ErrToOutcome($iWin32Err)
;   _SM_IsStopEligible($iState)
;   _SM_StateNeedsPolling($iState)
;   _SM_StateToAlreadyStopped($iState)
;   _SM_BuildResultRow($sName, $iInitState, $iFinalState, $sOutcome, $iWin32Err, $sNote)
;
; RESEARCH SOURCES
;   Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-openscmanagerw
;   Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-openservicew
;   Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-queryservicestatus
;   Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-controlservice
;   Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-closeservicehandle
;   Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/ns-winsvc-service_status
;   Ref: https://www.autoitscript.com/autoit3/docs/functions/DllCall.htm
;   Ref: https://www.autoitscript.com/autoit3/docs/functions/DllStructCreate.htm
; =============================================================================

#include-once

; ---------------------------------------------------------------------------
; Service state constants
; Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/ns-winsvc-service_status
; ---------------------------------------------------------------------------
Global Const $SM_STATE_STOPPED          = 1
Global Const $SM_STATE_START_PENDING    = 2
Global Const $SM_STATE_STOP_PENDING     = 3
Global Const $SM_STATE_RUNNING          = 4
Global Const $SM_STATE_CONTINUE_PENDING = 5
Global Const $SM_STATE_PAUSE_PENDING    = 6
Global Const $SM_STATE_PAUSED           = 7

; ---------------------------------------------------------------------------
; Outcome string constants
; ---------------------------------------------------------------------------
Global Const $SM_OUTCOME_STOPPED        = "STOPPED"
Global Const $SM_OUTCOME_ALREADY_STOPPED_STOPPED = "ALREADY_STOPPED"
Global Const $SM_OUTCOME_UNAVAILABLE    = "UNAVAILABLE"
Global Const $SM_OUTCOME_FAILED         = "FAILED"
Global Const $SM_OUTCOME_TIMED_OUT      = "TIMED_OUT"

; ---------------------------------------------------------------------------
; Win32 error codes relevant to SCM operations
; Ref: https://learn.microsoft.com/en-us/windows/win32/services/service-security-and-access-rights
; ---------------------------------------------------------------------------
Global Const $SM_ERR_ACCESS_DENIED      = 5
Global Const $SM_ERR_SVC_NOT_EXIST      = 1060    ; ERROR_SERVICE_DOES_NOT_EXIST
Global Const $SM_ERR_CANNOT_ACCEPT      = 1061    ; ERROR_SERVICE_CANNOT_ACCEPT_CTRL
Global Const $SM_ERR_NOT_ACTIVE         = 1062    ; ERROR_SERVICE_NOT_ACTIVE → ALREADY_STOPPED

; ---------------------------------------------------------------------------
; SCM and SERVICE access rights
; Ref: https://learn.microsoft.com/en-us/windows/win32/services/service-security-and-access-rights
; Minimum rights per operation — do not expand these without documented justification.
; ---------------------------------------------------------------------------
Global Const $SM_SC_MANAGER_CONNECT     = 0x0001
Global Const $SM_SERVICE_QUERY_STATUS   = 0x0004
Global Const $SM_SERVICE_STOP           = 0x0020
; Combined: query + stop (minimum needed for _SM_StopServicesBatch)
Global Const $SM_SERVICE_QUERY_AND_STOP = BitOR($SM_SERVICE_QUERY_STATUS, $SM_SERVICE_STOP)

; Control code for stop
; Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-controlservice
Global Const $SM_SERVICE_CONTROL_STOP   = 0x00000001

; ---------------------------------------------------------------------------
; Stop-eligible states
; Documentation-only: lists the stop-eligible states in human-readable form.
; Runtime eligibility is checked in _SM_IsStopEligible() via integer Switch.
; Ref: DM-01 Stop-Eligible State; DM-09 Change 4; GLOSSARY.md "Stop-Eligible State"
; ---------------------------------------------------------------------------
Global Const $SM_STOP_ELIGIBLE_STATES = "RUNNING,PAUSED,PAUSE_PENDING,CONTINUE_PENDING"

; ---------------------------------------------------------------------------
; Log level constants
; Match the _LogMessage $iLevel semantics documented in CLAUDE.md and DM-07.
; 0 = Error (failure events)
; 1 = Info  (completed-action / suppression events)
; 2 = Verbose (expected-negative observations, e.g. already stopped)
; ---------------------------------------------------------------------------
Global Const $LOG_LEVEL_ERROR   = 0
Global Const $LOG_LEVEL_INFO    = 1
Global Const $LOG_LEVEL_VERBOSE = 2

; ---------------------------------------------------------------------------
; Log type constants
; String tags for the $sType parameter of _LogMessage. DM-07 §2.2.
; ---------------------------------------------------------------------------
Global Const $LOG_TYPE_SYSTEM   = "System"
Global Const $LOG_TYPE_SERVICE  = "Service"

; ---------------------------------------------------------------------------
; Func _SM_StopServicesBatch
;
; Opens the Windows SCM once, queries each named service, issues stop controls
; to all eligible services without serial waiting, then polls all pending
; services against one shared deadline, then closes all handles.
;
; Parameters:
;   $aServiceNames  — 1D ByRef array of service name strings
;   $iBatchTimeoutMs — total time (ms) to wait for all services to stop (default 20000)
;   $iPollIntervalMs — sleep between polls (ms) (default 500)
;
; Returns:
;   2D array [n][6] — one row per input service:
;     [i][0] $sName        — service name
;     [i][1] $iInitState   — state at first query (integer 1–7, or -1 = unavailable)
;     [i][2] $iFinalState  — state after polling (integer 1–7, or -1)
;     [i][3] $sOutcome     — "STOPPED", "ALREADY_STOPPED", "UNAVAILABLE", "FAILED", "TIMED_OUT"
;     [i][4] $iWin32Err    — Win32 error at last failure (0 = no error)
;     [i][5] $sNote        — human-readable note (empty string if none)
;
; @error:
;   0 — batch processed (check per-row outcomes for individual service results)
;   1 — could not open SCM (batch-level failure; returned array has 0 rows)
;
; Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-openscmanagerw
; ---------------------------------------------------------------------------
Func _SM_StopServicesBatch(ByRef $aServiceNames, $iBatchTimeoutMs = 20000, $iPollIntervalMs = 500)
    Local $iCount = UBound($aServiceNames)

    ; --- Handle empty input gracefully (not an SCM-level failure) ---
    If $iCount = 0 Then
        Local $aEmptyResult[0][6]
        Return $aEmptyResult
    EndIf

    ; --- Allocate result array ---
    Local $aResults[$iCount][6]
    Local $i
    For $i = 0 To $iCount - 1
        $aResults[$i][0] = $aServiceNames[$i]
        $aResults[$i][1] = -1
        $aResults[$i][2] = -1
        $aResults[$i][3] = ""
        $aResults[$i][4] = 0
        $aResults[$i][5] = ""
    Next

    ; --- Open SCM (batch-level handle) ---
    ; SCM Handle vs Service Handle distinction (DM-09 Change 5; GLOSSARY.md "SCM Handle"):
    ;   $hSCM  — SCM Handle, opened ONCE for the entire batch with SC_MANAGER_CONNECT.
    ;            Lifetime: this function call. Closed after all per-service handles are closed.
    ;   $hService — Service Handle, opened per-service with SERVICE_QUERY_STATUS|SERVICE_STOP.
    ;               Lifetime: one service within the batch (Phase 1 routing through Phase 2 poll).
    ; A failure here is a batch-level failure: no per-service work can proceed.
    ; Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-openscmanagerw
    ; lpMachineName = NULL (ptr 0) → local computer
    ; lpDatabaseName = "ServicesActive" → active services database
    ; dwDesiredAccess = SC_MANAGER_CONNECT → minimum right needed to open services
    Local $aScmOpen = DllCall("advapi32.dll", "handle", "OpenSCManagerW", _
            "ptr",   0, _
            "wstr",  "ServicesActive", _
            "dword", $SM_SC_MANAGER_CONNECT)
    Local $iScmDllErr = @error    ; capture IMMEDIATELY — @error is volatile
    If $iScmDllErr Or Not $aScmOpen[0] Then
        Local $iScmWinErr = _WinAPI_GetLastError()
        _LogMessage("_SM_StopServicesBatch: OpenSCManagerW failed (DllErr=" & $iScmDllErr & ", Win32=" & $iScmWinErr & ")", $LOG_TYPE_SERVICE, $LOG_LEVEL_ERROR)
        ; Architecture contract: @error=1 → "batch-level failure; returned array has 0 rows"
        ; Return a zero-row array — NOT the pre-allocated $aResults (CR-02 MAJOR fix).
        Local $aEmpty[0][6]
        SetError(1)
        Return $aEmpty
    EndIf
    Local $hSCM = $aScmOpen[0]

    ; --- Pending-services tracking arrays ---
    ; Parallel arrays: [pending service index in $aResults, service handle]
    Local $aPendingIdx[0]     ; index into $aResults
    Local $aPendingHnd[0]     ; corresponding service handle
    ; $iPendLen declared at function scope — not inside the Phase 1 loop — so
    ; AU3Check -w 3 does not emit a redeclaration-in-loop warning (BUG-02 fix).
    ; Assigned before every read site inside the loop body below.
    Local $iPendLen

    ; =========================================================================
    ; PHASE 1 — Inspect each service and issue stop controls without serial waiting
    ; =========================================================================
    For $i = 0 To $iCount - 1
        Local $sName = $aServiceNames[$i]

        ; Open service with query + stop rights
        ; Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-openservicew
        Local $aSvcOpen = DllCall("advapi32.dll", "handle", "OpenServiceW", _
                "handle", $hSCM, _
                "wstr",   $sName, _
                "dword",  $SM_SERVICE_QUERY_AND_STOP)
        Local $iSvcDllErr = @error    ; capture IMMEDIATELY
        If $iSvcDllErr Or Not $aSvcOpen[0] Then
            Local $iSvcWinErr = _WinAPI_GetLastError()
            If $iSvcWinErr = $SM_ERR_SVC_NOT_EXIST Then
                $aResults[$i][3] = $SM_OUTCOME_UNAVAILABLE
                $aResults[$i][4] = $SM_ERR_SVC_NOT_EXIST
                _LogMessage("_SM_StopServicesBatch: service not found: " & $sName, $LOG_TYPE_SERVICE, $LOG_LEVEL_VERBOSE)
            Else
                $aResults[$i][3] = $SM_OUTCOME_FAILED
                $aResults[$i][4] = $iSvcWinErr
                _LogMessage("_SM_StopServicesBatch: OpenServiceW failed for " & $sName & " (Win32=" & $iSvcWinErr & ")", $LOG_TYPE_SERVICE, $LOG_LEVEL_ERROR)
            EndIf
            ContinueLoop   ; do not close a handle that was never opened
        EndIf
        Local $hService = $aSvcOpen[0]

        ; Query current service state
        ; Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-queryservicestatus
        ; SERVICE_STATUS: 7 DWORD fields; dwCurrentState is field 2
        ; Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/ns-winsvc-service_status
        Local $tQueryStatus = DllStructCreate("dword;dword;dword;dword;dword;dword;dword")
        Local $aQuery = DllCall("advapi32.dll", "bool", "QueryServiceStatus", _
                "handle", $hService, _
                "ptr",    DllStructGetPtr($tQueryStatus))
        Local $iQryDllErr = @error    ; capture IMMEDIATELY
        Local $iQryWinErr = _WinAPI_GetLastError()   ; before any other call
        If $iQryDllErr Or Not $aQuery[0] Then
            $aResults[$i][3] = $SM_OUTCOME_FAILED
            $aResults[$i][4] = $iQryWinErr
            _LogMessage("_SM_StopServicesBatch: QueryServiceStatus failed for " & $sName & " (Win32=" & $iQryWinErr & ")", $LOG_TYPE_SERVICE, $LOG_LEVEL_ERROR)
            DllCall("advapi32.dll", "bool", "CloseServiceHandle", "handle", $hService)
            ContinueLoop
        EndIf
        Local $iInitState = DllStructGetData($tQueryStatus, 2)   ; field 2 = dwCurrentState
        $aResults[$i][1] = $iInitState

        ; Route based on initial state
        If _SM_StateToAlreadyStopped($iInitState) Then
            ; Service is STOPPED — no control needed
            $aResults[$i][2] = $iInitState
            $aResults[$i][3] = $SM_OUTCOME_ALREADY_STOPPED
            $aResults[$i][4] = 0
            _LogMessage("_SM_StopServicesBatch: already stopped: " & $sName, $LOG_TYPE_SERVICE, $LOG_LEVEL_VERBOSE)
            DllCall("advapi32.dll", "bool", "CloseServiceHandle", "handle", $hService)
            ContinueLoop
        EndIf

        If _SM_StateNeedsPolling($iInitState) Then
            ; Service is in STOP_PENDING — just add to pending list and poll
            $iPendLen = UBound($aPendingIdx)
            ReDim $aPendingIdx[$iPendLen + 1]
            ReDim $aPendingHnd[$iPendLen + 1]
            $aPendingIdx[$iPendLen] = $i
            $aPendingHnd[$iPendLen] = $hService
            ContinueLoop
        EndIf

        If Not _SM_IsStopEligible($iInitState) Then
            ; START_PENDING: cannot receive stop control now — mark FAILED
            $aResults[$i][2] = $iInitState
            $aResults[$i][3] = $SM_OUTCOME_FAILED
            $aResults[$i][4] = $SM_ERR_CANNOT_ACCEPT
            $aResults[$i][5] = "Service in START_PENDING state; stop control not accepted"
            _LogMessage("_SM_StopServicesBatch: service in un-stoppable state: " & $sName & " (state=" & $iInitState & ")", $LOG_TYPE_SERVICE, $LOG_LEVEL_ERROR)
            DllCall("advapi32.dll", "bool", "CloseServiceHandle", "handle", $hService)
            ContinueLoop
        EndIf

        ; Service is RUNNING / PAUSED / PAUSE_PENDING / CONTINUE_PENDING — issue stop control
        ; Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-controlservice
        ; ControlService 3rd param: LPSERVICE_STATUS (SERVICE_STATUS, 7 DWORDs) — NOT SERVICE_STATUS_PROCESS
        Local $tCtrlStatus = DllStructCreate("dword;dword;dword;dword;dword;dword;dword")
        Local $aCtrl = DllCall("advapi32.dll", "bool", "ControlService", _
                "handle", $hService, _
                "dword",  $SM_SERVICE_CONTROL_STOP, _
                "ptr",    DllStructGetPtr($tCtrlStatus))
        Local $iCtrlDllErr = @error    ; capture IMMEDIATELY
        Local $iCtrlWinErr = _WinAPI_GetLastError()   ; before any other call

        If $iCtrlDllErr Or Not $aCtrl[0] Then
            ; Stop control failed — classify outcome by Win32 error
            Local $sCtrlOutcome = _SM_Win32ErrToOutcome($iCtrlWinErr)
            $aResults[$i][2] = $iInitState
            $aResults[$i][3] = $sCtrlOutcome
            $aResults[$i][4] = $iCtrlWinErr
            If $sCtrlOutcome = $SM_OUTCOME_ALREADY_STOPPED Then
                _LogMessage("_SM_StopServicesBatch: service not active (Win32=1062): " & $sName, $LOG_TYPE_SERVICE, $LOG_LEVEL_VERBOSE)
            Else
                _LogMessage("_SM_StopServicesBatch: ControlService failed for " & $sName & " (Win32=" & $iCtrlWinErr & ")", $LOG_TYPE_SERVICE, $LOG_LEVEL_ERROR)
            EndIf
            DllCall("advapi32.dll", "bool", "CloseServiceHandle", "handle", $hService)
            ContinueLoop
        EndIf

        ; Stop control accepted — add to pending list for polling
        ; (same ReDim append pattern as the STOP_PENDING branch above — $iPendLen reused)
        $iPendLen = UBound($aPendingIdx)
        ReDim $aPendingIdx[$iPendLen + 1]
        ReDim $aPendingHnd[$iPendLen + 1]
        $aPendingIdx[$iPendLen] = $i
        $aPendingHnd[$iPendLen] = $hService

    Next   ;==>Phase 1 loop

    ; =========================================================================
    ; PHASE 2 — Poll all pending services against one shared deadline
    ; =========================================================================
    Local $iTimer = TimerInit()

    While UBound($aPendingIdx) > 0 And TimerDiff($iTimer) < $iBatchTimeoutMs
        Sleep($iPollIntervalMs)
        ; Iterate backwards so array shrinks safely during removal
        Local $j
        For $j = UBound($aPendingIdx) - 1 To 0 Step -1
            Local $iResultIdx = $aPendingIdx[$j]
            Local $hPendSvc   = $aPendingHnd[$j]

            Local $tPollStatus = DllStructCreate("dword;dword;dword;dword;dword;dword;dword")
            Local $aPoll = DllCall("advapi32.dll", "bool", "QueryServiceStatus", _
                    "handle", $hPendSvc, _
                    "ptr",    DllStructGetPtr($tPollStatus))
            Local $iPollDllErr = @error    ; capture IMMEDIATELY
            If $iPollDllErr Or Not $aPoll[0] Then
                ; Cannot read status this tick — defer (leave in pending list)
                _LogMessage("_SM_StopServicesBatch: poll query failed for " & $aResults[$iResultIdx][0] & " — deferring", $LOG_TYPE_SERVICE, $LOG_LEVEL_ERROR)
                ContinueLoop
            EndIf

            Local $iPollState = DllStructGetData($tPollStatus, 2)   ; field 2 = dwCurrentState
            $aResults[$iResultIdx][2] = $iPollState   ; update final state each poll

            If $iPollState = $SM_STATE_STOPPED Then
                ; Service reached STOPPED state
                $aResults[$iResultIdx][3] = $SM_OUTCOME_STOPPED
                $aResults[$iResultIdx][4] = 0
                _LogMessage("_SM_StopServicesBatch: service stopped: " & $aResults[$iResultIdx][0], $LOG_TYPE_SERVICE, $LOG_LEVEL_INFO)
                DllCall("advapi32.dll", "bool", "CloseServiceHandle", "handle", $hPendSvc)
                ; Remove from pending arrays (shrink from the end)
                Local $iPendCount = UBound($aPendingIdx)
                If $j < $iPendCount - 1 Then
                    ; Shift remaining elements left
                    Local $k
                    For $k = $j To $iPendCount - 2
                        $aPendingIdx[$k] = $aPendingIdx[$k + 1]
                        $aPendingHnd[$k] = $aPendingHnd[$k + 1]
                    Next
                EndIf
                ReDim $aPendingIdx[$iPendCount - 1]
                ReDim $aPendingHnd[$iPendCount - 1]
            EndIf
            ; If still in-progress, leave in pending list for next poll cycle

        Next   ;==>poll inner loop

    WEnd   ;==>Phase 2 poll loop

    ; --- Timeout: mark any remaining pending services as TIMED_OUT ---
    Local $iTimeoutIdx
    For $iTimeoutIdx = 0 To UBound($aPendingIdx) - 1
        Local $iTOIdx = $aPendingIdx[$iTimeoutIdx]
        $aResults[$iTOIdx][3] = $SM_OUTCOME_TIMED_OUT
        $aResults[$iTOIdx][4] = 0
        $aResults[$iTOIdx][5] = "Deadline exceeded (" & $iBatchTimeoutMs & "ms)"
        _LogMessage("_SM_StopServicesBatch: stop timed out: " & $aResults[$iTOIdx][0], $LOG_TYPE_SERVICE, $LOG_LEVEL_ERROR)
        DllCall("advapi32.dll", "bool", "CloseServiceHandle", "handle", $aPendingHnd[$iTimeoutIdx])
    Next

    ; --- Close SCM handle ---
    ; Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-closeservicehandle
    DllCall("advapi32.dll", "bool", "CloseServiceHandle", "handle", $hSCM)

    Return $aResults

EndFunc   ;==>_SM_StopServicesBatch

; ---------------------------------------------------------------------------
; Func _SM_ServiceStateToString
;
; Maps a service state integer (1–7) to a human-readable string.
; Returns "UNKNOWN" for unrecognised values.
;
; Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/ns-winsvc-service_status
; ---------------------------------------------------------------------------
Func _SM_ServiceStateToString($iState)
    Switch $iState
        Case $SM_STATE_STOPPED
            Return "STOPPED"
        Case $SM_STATE_START_PENDING
            Return "START_PENDING"
        Case $SM_STATE_STOP_PENDING
            Return "STOP_PENDING"
        Case $SM_STATE_RUNNING
            Return "RUNNING"
        Case $SM_STATE_CONTINUE_PENDING
            Return "CONTINUE_PENDING"
        Case $SM_STATE_PAUSE_PENDING
            Return "PAUSE_PENDING"
        Case $SM_STATE_PAUSED
            Return "PAUSED"
        Case Else
            Return "UNKNOWN"
    EndSwitch
EndFunc   ;==>_SM_ServiceStateToString

; ---------------------------------------------------------------------------
; Func _SM_Win32ErrToOutcome
;
; Maps a Win32 error code returned by ControlService or OpenService to an
; outcome string. Used to classify ControlService failures.
;
; Note: 1060 (DOES_NOT_EXIST) maps to UNAVAILABLE — used for OpenService failures.
; Note: 1062 (NOT_ACTIVE) maps to ALREADY_STOPPED — service was not running.
; All others map to FAILED.
;
; Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-controlservice
; ---------------------------------------------------------------------------
Func _SM_Win32ErrToOutcome($iWin32Err)
    Select
        Case $iWin32Err = $SM_ERR_NOT_ACTIVE      ; 1062 — service was not started
            Return $SM_OUTCOME_ALREADY_STOPPED
        Case $iWin32Err = $SM_ERR_SVC_NOT_EXIST   ; 1060 — does not exist
            Return $SM_OUTCOME_UNAVAILABLE
        Case Else
            Return $SM_OUTCOME_FAILED
    EndSelect
EndFunc   ;==>_SM_Win32ErrToOutcome

; ---------------------------------------------------------------------------
; Func _SM_IsStopEligible
;
; Returns True if a service in the given state is eligible to receive a
; SERVICE_CONTROL_STOP command. Services in STOPPED, STOP_PENDING, or
; START_PENDING states are not eligible (ControlService would return 1061 or 1062).
;
; States eligible for stop: RUNNING (4), PAUSED (7), PAUSE_PENDING (6),
;                            CONTINUE_PENDING (5)
;
; Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-controlservice
; ---------------------------------------------------------------------------
Func _SM_IsStopEligible($iState)
    Switch $iState
        Case $SM_STATE_RUNNING, $SM_STATE_PAUSED, $SM_STATE_PAUSE_PENDING, $SM_STATE_CONTINUE_PENDING
            Return True
        Case Else
            Return False
    EndSwitch
EndFunc   ;==>_SM_IsStopEligible

; ---------------------------------------------------------------------------
; Func _SM_StateNeedsPolling
;
; Returns True if the service is in STOP_PENDING state at first query —
; meaning the stop is already in progress and no new ControlService call is
; needed; the service just needs to be polled.
;
; Ref: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/ns-winsvc-service_status
; ---------------------------------------------------------------------------
Func _SM_StateNeedsPolling($iState)
    Return ($iState = $SM_STATE_STOP_PENDING)
EndFunc   ;==>_SM_StateNeedsPolling

; ---------------------------------------------------------------------------
; Func _SM_StateToAlreadyStopped
;
; Returns True if the service is already in the STOPPED state — meaning no
; control needs to be sent and the outcome is ALREADY_STOPPED.
; ---------------------------------------------------------------------------
Func _SM_StateToAlreadyStopped($iState)
    Return ($iState = $SM_STATE_STOPPED)
EndFunc   ;==>_SM_StateToAlreadyStopped

; ---------------------------------------------------------------------------
; Func _SM_BuildResultRow
;
; Constructs a single result row array [0..5] for a service outcome.
; Convenience helper used internally and by the test harness.
;
; Parameters:
;   $sName       — service name
;   $iInitState  — initial state integer (1–7, or -1)
;   $iFinalState — final state integer (1–7, or -1)
;   $sOutcome    — outcome string constant
;   $iWin32Err   — Win32 error (0 = none)
;   $sNote       — optional human-readable note
;
; Returns: 1D array [6]
; ---------------------------------------------------------------------------
Func _SM_BuildResultRow($sName, $iInitState, $iFinalState, $sOutcome, $iWin32Err, $sNote = "")
    Local $aRow[6]
    $aRow[0] = $sName
    $aRow[1] = $iInitState
    $aRow[2] = $iFinalState
    $aRow[3] = $sOutcome
    $aRow[4] = $iWin32Err
    ; Column 5: $sNote — human-readable diagnostic note. Non-empty only for outcomes that
    ; require explanation. Currently populated in two cases (DM-04 §3.6):
    ;   START_PENDING: "Service in START_PENDING state; stop control not accepted"
    ;   TIMED_OUT:     "Deadline exceeded (<N>ms)"
    ; Empty string ("") for all other outcomes. Callers must not treat an empty note as
    ; an error indicator — check $sOutcome ([i][3]) for outcome classification.
    $aRow[5] = $sNote
    Return $aRow
EndFunc   ;==>_SM_BuildResultRow
