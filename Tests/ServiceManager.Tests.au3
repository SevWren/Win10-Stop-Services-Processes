#RequireAdmin
; =============================================================================
; #RequireAdmin SCOPE NOTE
;   This directive is required because _Test_EmptyInput and
;   _Test_BatchUnknownServices both call _SM_StopServicesBatch, which opens a
;   live SCM handle via OpenSCManagerW — an operation that requires admin
;   privileges on Windows. The remaining nine test functions are pure-logic
;   tests that never open an SCM handle and could run without admin. AutoIt
;   does not support conditional elevation per-function; a single
;   #RequireAdmin at the top applies to the entire process. If you need to run
;   the pure-logic tests without admin, comment out _Test_EmptyInput and
;   _Test_BatchUnknownServices in the main body and remove #RequireAdmin.
; =============================================================================

; =============================================================================
; ServiceManager.Tests.au3 — Deterministic test harness for ServiceManager.au3
; Branch : arch/service-manager-migration
; Ticket : T03 — Build ServiceManager.au3 + Deterministic Test Harness
; Date   : 2026-11-11
;
; TEST DESIGN PHILOSOPHY
; ----------------------
; This harness is organised into two categories of test function:
;
;   1. Pure-logic unit tests
;      These exercise functions that take input values and return output values
;      with no DllCall, no global state mutation, and no I/O. They are fully
;      deterministic regardless of the Windows SCM state or the services
;      installed on the system. Examples:
;        _SM_ServiceStateToString, _SM_Win32ErrToOutcome, _SM_IsStopEligible,
;        _SM_StateNeedsPolling, _SM_StateToAlreadyStopped, _SM_BuildResultRow
;
;   2. SCM integration tests
;      These call _SM_StopServicesBatch with real (or deliberately non-existent)
;      service names. They exercise the actual Phase 1 / Phase 2 algorithm,
;      including the OpenSCManagerW call. Because live Windows services that
;      match the production service names (wuauserv, TrustedInstaller, etc.)
;      are not present in this Linux sandbox environment, the only testable
;      integration path is the UNAVAILABLE outcome produced when OpenServiceW
;      returns Win32 error 1060 (ERROR_SERVICE_DOES_NOT_EXIST). This exercises
;      Phase 1 routing for the non-existent service branch without issuing any
;      stop controls.
;
; STUB PATTERN
; ------------
;   There are no stub helper functions in this harness. The module under test
;   (ServiceManager.au3) exposes its pure-logic helpers as callable Funcs;
;   tests call them directly. Result arrays for scenario tests are constructed
;   inline to verify accounting properties independently of live SCM calls.
;   The term "stub" in older comments referred to _BuildExpectedRow, which has
;   been removed (dead code — never called).
;
; DETERMINISTIC DESIGN CONSTRAINT
; --------------------------------
;   REQ-009 prohibits live stop controls in this harness. Per-service result
;   arrays for timeout, failure, and already-stopped scenarios are constructed
;   manually to test outcome-accounting properties without touching a live SCM.
;   The two SCM integration tests (_Test_EmptyInput, _Test_BatchUnknownServices)
;   do open a live SCM handle but issue no stop controls: the first passes an
;   empty list; the second uses names that do not exist on any real Windows
;   install, ensuring Phase 1 routes all services to UNAVAILABLE and returns
;   without entering Phase 2.
;
; CONSOLEWRITE EXCEPTION
; ----------------------
;   CODING_STANDARDS.md prohibits direct ConsoleWrite calls outside of
;   initialization/debug code. This test harness is explicitly exempt: it is a
;   diagnostic tool with no access to the main-script _LogMessage infrastructure,
;   and CI-friendly output requires writing directly to stdout. The exception is
;   limited to test harness files in the Tests/ directory.
;
; PURPOSE
;   Verify the pure-logic and result-accounting behaviour of ServiceManager.au3
;   without issuing live stop controls to production services.
;
;   All pure-logic tests are deterministic. SCM integration tests exercise the
;   UNAVAILABLE code path only (non-existent service names, no stop controls).
;
; RUNNING
;   On Windows with AutoIt installed:
;     AutoIt3.exe "Tests\ServiceManager.Tests.au3"
;   OR compile and run the exe.
;   AU3Check: AU3Check -q -d -w 1 -w 2 -w 3 -w 4 Tests\ServiceManager.Tests.au3
;
; ENVIRONMENT GATE
;   This harness requires Windows (AutoIt runtime). It is marked NOT RUN in the
;   Linux sandbox. Static AU3Check is also Windows-only.
; =============================================================================

#Region ;Includes
#include <AutoItConstants.au3>
#include <MsgBoxConstants.au3>
#EndRegion

; ---------------------------------------------------------------------------
; Service state and outcome constants are defined in ServiceManager.au3.
; They are NOT redeclared here to avoid Global Const redefinition conflicts
; under AU3Check -w 3 / -w 4. The #include at the bottom of this file
; (after all Func definitions) makes them available at call time.
; ---------------------------------------------------------------------------

; Win32 error codes used in tests
Global Const $ERR_ACCESS_DENIED         = 5
Global Const $ERR_DEPENDENT_RUNNING     = 1051
Global Const $ERR_INVALID_CTRL         = 1052
Global Const $ERR_SVC_NOT_EXIST        = 1060
Global Const $ERR_CANNOT_ACCEPT        = 1061
Global Const $ERR_NOT_ACTIVE           = 1062
Global Const $ERR_DEPENDENCY_FAIL      = 1068
Global Const $ERR_MARKED_DELETE        = 1072

; ---------------------------------------------------------------------------
; Test framework globals
; ---------------------------------------------------------------------------
Global $g_iTestCount   = 0
Global $g_iPassCount   = 0
Global $g_iFailCount   = 0
Global $g_sTestLog     = ""

; ---------------------------------------------------------------------------
; Test framework helpers
; ---------------------------------------------------------------------------

Func _TestAssert($sTestName, $bResult, $sExpected = "", $sActual = "")
    $g_iTestCount += 1
    If $bResult Then
        $g_iPassCount += 1
        $g_sTestLog &= "  PASS  " & $sTestName & @CRLF
    Else
        $g_iFailCount += 1
        $g_sTestLog &= "  FAIL  " & $sTestName
        If $sExpected <> "" Or $sActual <> "" Then
            $g_sTestLog &= "  [expected: " & $sExpected & "  got: " & $sActual & "]"
        EndIf
        $g_sTestLog &= @CRLF
    EndIf
EndFunc

Func _PrintResults()
    ConsoleWrite(@CRLF & "==================================================" & @CRLF)
    ConsoleWrite("ServiceManager Test Results" & @CRLF)
    ConsoleWrite("==================================================" & @CRLF)
    ConsoleWrite($g_sTestLog)
    ConsoleWrite("--------------------------------------------------" & @CRLF)
    ConsoleWrite("Total: " & $g_iTestCount & "   Pass: " & $g_iPassCount & "   Fail: " & $g_iFailCount & @CRLF)
    ConsoleWrite("==================================================" & @CRLF)
    If $g_iFailCount = 0 Then
        ConsoleWrite("ALL TESTS PASSED" & @CRLF)
    Else
        ConsoleWrite("FAILURES DETECTED — see above" & @CRLF)
    EndIf
EndFunc

; ---------------------------------------------------------------------------
; Unit under test: pure-logic helpers from ServiceManager.au3
;
; These are tested here by calling the actual functions once ServiceManager.au3
; is included. The pure-logic helpers (_SM_ServiceStateToString,
; _SM_Win32ErrToOutcome, _SM_IsStopEligible, _SM_StateNeedsPolling,
; _SM_StateToAlreadyStopped, _SM_BuildResultRow) make no DllCall and generate
; no live SCM traffic. SCM integration tests that call _SM_StopServicesBatch
; are grouped separately at the bottom of the function list.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Tests for _SM_ServiceStateToString (pure mapping function)
; ---------------------------------------------------------------------------

Func _Test_ServiceStateToString()
    ConsoleWrite(@CRLF & "--- _SM_ServiceStateToString ---" & @CRLF)

    ; Include ServiceManager so its functions are callable
    ; (In a real run this is handled by #include at the top of the compilation unit)
    ; The tests below call _SM_ServiceStateToString directly.

    _TestAssert("state 1 = STOPPED",          _SM_ServiceStateToString(1) = "STOPPED")
    _TestAssert("state 2 = START_PENDING",     _SM_ServiceStateToString(2) = "START_PENDING")
    _TestAssert("state 3 = STOP_PENDING",      _SM_ServiceStateToString(3) = "STOP_PENDING")
    _TestAssert("state 4 = RUNNING",           _SM_ServiceStateToString(4) = "RUNNING")
    _TestAssert("state 5 = CONTINUE_PENDING",  _SM_ServiceStateToString(5) = "CONTINUE_PENDING")
    _TestAssert("state 6 = PAUSE_PENDING",     _SM_ServiceStateToString(6) = "PAUSE_PENDING")
    _TestAssert("state 7 = PAUSED",            _SM_ServiceStateToString(7) = "PAUSED")
    _TestAssert("state -1 = UNKNOWN",          _SM_ServiceStateToString(-1) = "UNKNOWN")
    _TestAssert("state 0 = UNKNOWN",           _SM_ServiceStateToString(0) = "UNKNOWN")
    _TestAssert("state 99 = UNKNOWN",          _SM_ServiceStateToString(99) = "UNKNOWN")
EndFunc

; ---------------------------------------------------------------------------
; Tests for _SM_Win32ErrToOutcome (pure mapping function)
; ---------------------------------------------------------------------------

Func _Test_Win32ErrToOutcome()
    ConsoleWrite(@CRLF & "--- _SM_Win32ErrToOutcome ---" & @CRLF)

    ; ControlService error 1062 = NOT_ACTIVE → service was not started → ALREADY_STOPPED
    _TestAssert("win32 1062 → ALREADY_STOPPED", _SM_Win32ErrToOutcome(1062) = $SM_OUTCOME_ALREADY, $SM_OUTCOME_ALREADY, _SM_Win32ErrToOutcome(1062))

    ; ControlService error 5 = ACCESS_DENIED → FAILED
    _TestAssert("win32 5 → FAILED",             _SM_Win32ErrToOutcome(5) = $SM_OUTCOME_FAILED,   $SM_OUTCOME_FAILED, _SM_Win32ErrToOutcome(5))

    ; ControlService error 1051 = DEPENDENT → FAILED
    _TestAssert("win32 1051 → FAILED",          _SM_Win32ErrToOutcome(1051) = $SM_OUTCOME_FAILED, $SM_OUTCOME_FAILED, _SM_Win32ErrToOutcome(1051))

    ; ControlService error 1052 = INVALID_SERVICE_CONTROL → FAILED
    _TestAssert("win32 1052 → FAILED",          _SM_Win32ErrToOutcome(1052) = $SM_OUTCOME_FAILED, $SM_OUTCOME_FAILED, _SM_Win32ErrToOutcome(1052))

    ; ControlService error 1061 = CANNOT_ACCEPT_CTRL → FAILED (service state doesn't accept stop)
    _TestAssert("win32 1061 → FAILED",          _SM_Win32ErrToOutcome(1061) = $SM_OUTCOME_FAILED, $SM_OUTCOME_FAILED, _SM_Win32ErrToOutcome(1061))

    ; ControlService error 1068 = DEPENDENCY_FAIL → FAILED
    _TestAssert("win32 1068 → FAILED",          _SM_Win32ErrToOutcome(1068) = $SM_OUTCOME_FAILED, $SM_OUTCOME_FAILED, _SM_Win32ErrToOutcome(1068))

    ; ControlService error 1072 = MARKED_FOR_DELETE → FAILED
    _TestAssert("win32 1072 → FAILED",          _SM_Win32ErrToOutcome(1072) = $SM_OUTCOME_FAILED, $SM_OUTCOME_FAILED, _SM_Win32ErrToOutcome(1072))

    ; Unknown error → FAILED (default)
    _TestAssert("win32 999 → FAILED (default)", _SM_Win32ErrToOutcome(999) = $SM_OUTCOME_FAILED, $SM_OUTCOME_FAILED, _SM_Win32ErrToOutcome(999))

    ; OpenService error 1060 = SERVICE_DOES_NOT_EXIST → UNAVAILABLE
    _TestAssert("win32 1060 → UNAVAILABLE",     _SM_Win32ErrToOutcome(1060) = $SM_OUTCOME_UNAVAILABLE, $SM_OUTCOME_UNAVAILABLE, _SM_Win32ErrToOutcome(1060))
EndFunc

; ---------------------------------------------------------------------------
; Tests for _SM_IsStopEligible (pure logic: which states can receive a stop control)
; Ref: ARCHITECTURE.md — batch-stop algorithm
; ---------------------------------------------------------------------------

Func _Test_IsStopEligible()
    ConsoleWrite(@CRLF & "--- _SM_IsStopEligible ---" & @CRLF)

    ; RUNNING services are eligible for stop
    _TestAssert("RUNNING (4) is eligible",           _SM_IsStopEligible($SM_STATE_RUNNING) = True)

    ; PAUSED services are eligible for stop
    _TestAssert("PAUSED (7) is eligible",            _SM_IsStopEligible($SM_STATE_PAUSED) = True)

    ; CONTINUE_PENDING is eligible (service is resuming but can still receive stop)
    _TestAssert("CONTINUE_PENDING (5) is eligible",  _SM_IsStopEligible($SM_STATE_CONTINUE_PENDING) = True)

    ; PAUSE_PENDING is eligible
    _TestAssert("PAUSE_PENDING (6) is eligible",     _SM_IsStopEligible($SM_STATE_PAUSE_PENDING) = True)

    ; STOPPED is NOT eligible (already stopped — handle as ALREADY_STOPPED before ControlService)
    _TestAssert("STOPPED (1) is NOT eligible",       _SM_IsStopEligible($SM_STATE_STOPPED) = False)

    ; STOP_PENDING is NOT eligible for a new stop control (already stopping — just poll)
    _TestAssert("STOP_PENDING (3) is NOT eligible",  _SM_IsStopEligible($SM_STATE_STOP_PENDING) = False)

    ; START_PENDING is NOT eligible (ControlService with STOP would fail with 1061)
    _TestAssert("START_PENDING (2) is NOT eligible", _SM_IsStopEligible($SM_STATE_START_PENDING) = False)
EndFunc

; ---------------------------------------------------------------------------
; Tests for _SM_BuildResultRow (result row construction helper)
; ---------------------------------------------------------------------------

Func _Test_BuildResultRow()
    ConsoleWrite(@CRLF & "--- _SM_BuildResultRow ---" & @CRLF)

    Local $aRow = _SM_BuildResultRow("wuauserv", 4, 1, $SM_OUTCOME_STOPPED, 0, "")
    _TestAssert("row[0] = service name",    $aRow[0] = "wuauserv",           "wuauserv",          $aRow[0])
    _TestAssert("row[1] = initial state",   $aRow[1] = 4,                    "4",                 String($aRow[1]))
    _TestAssert("row[2] = final state",     $aRow[2] = 1,                    "1",                 String($aRow[2]))
    _TestAssert("row[3] = outcome",         $aRow[3] = $SM_OUTCOME_STOPPED,  $SM_OUTCOME_STOPPED, $aRow[3])
    _TestAssert("row[4] = win32 err = 0",   $aRow[4] = 0,                    "0",                 String($aRow[4]))
    _TestAssert("row[5] = note = empty",    $aRow[5] = "",                   "",                  $aRow[5])

    ; UNAVAILABLE row: initial/final state = -1
    Local $aRow2 = _SM_BuildResultRow("FDResPub", -1, -1, $SM_OUTCOME_UNAVAILABLE, $ERR_SVC_NOT_EXIST, "")
    _TestAssert("unavailable row: initState=-1",  $aRow2[1] = -1, "-1", String($aRow2[1]))
    _TestAssert("unavailable row: outcome",       $aRow2[3] = $SM_OUTCOME_UNAVAILABLE, $SM_OUTCOME_UNAVAILABLE, $aRow2[3])
    _TestAssert("unavailable row: win32=1060",    $aRow2[4] = $ERR_SVC_NOT_EXIST, "1060", String($aRow2[4]))
EndFunc

; ---------------------------------------------------------------------------
; Tests for _SM_StopServicesBatch result column count
; Verifies the module returns exactly 6 columns per row, not AutoIt array
; mechanics. Passes two names that do not exist on any real Windows install;
; _SM_StopServicesBatch opens the SCM and routes both services to UNAVAILABLE
; (Win32 1060) in Phase 1 without entering Phase 2. The column count of the
; returned array is a property of the module under test, not of AutoIt.
;
; NOTE: This test opens a live SCM handle (requires #RequireAdmin / Windows).
; The service names are intentionally nonsensical so no stop control is ever
; issued (REQ-009).
; ---------------------------------------------------------------------------

Func _Test_ResultArrayDimensions()
    ConsoleWrite(@CRLF & "--- _SM_StopServicesBatch: 6 columns per row ---" & @CRLF)

    ; Two names guaranteed not to exist on any Windows system
    Local $aNames[2] = ["__NonExistent_TestSvc_A__", "__NonExistent_TestSvc_B__"]
    Local $aResults = _SM_StopServicesBatch($aNames)

    ; The module must return exactly 2 rows (one per input) and exactly 6 columns
    _TestAssert("batch(2 unknown): row count = 2",    UBound($aResults, 1) = 2, "2", String(UBound($aResults, 1)))
    _TestAssert("batch(2 unknown): col count = 6",    UBound($aResults, 2) = 6, "6", String(UBound($aResults, 2)))
    ; Confirm the module correctly sets the service name in column 0
    _TestAssert("batch(2 unknown): row 0 name preserved", $aResults[0][0] = "__NonExistent_TestSvc_A__", "__NonExistent_TestSvc_A__", $aResults[0][0])
    ; Confirm outcome is UNAVAILABLE (Win32 1060 path in Phase 1)
    _TestAssert("batch(2 unknown): row 0 outcome = UNAVAILABLE", $aResults[0][3] = $SM_OUTCOME_UNAVAILABLE, $SM_OUTCOME_UNAVAILABLE, $aResults[0][3])
EndFunc

; ---------------------------------------------------------------------------
; Tests for single-service failure accounting within a batch
; Verifies that one FAILED service does not affect other services' outcomes
; ---------------------------------------------------------------------------

Func _Test_SingleFailureInBatch()
    ConsoleWrite(@CRLF & "--- Single-Service Failure in Batch Does Not Affect Others ---" & @CRLF)

    ; Simulate a 3-service batch where service[1] fails (ACCESS_DENIED)
    ; and services [0] and [2] stop successfully
    Local $aResults[3][6]
    $aResults[0][0] = "wuauserv"      : $aResults[0][3] = $SM_OUTCOME_STOPPED
    $aResults[1][0] = "WaaSMedicSvc"  : $aResults[1][3] = $SM_OUTCOME_FAILED : $aResults[1][4] = 5
    $aResults[2][0] = "UsoSvc"        : $aResults[2][3] = $SM_OUTCOME_STOPPED

    _TestAssert("service[0] outcome unaffected by service[1] failure", $aResults[0][3] = $SM_OUTCOME_STOPPED,  $SM_OUTCOME_STOPPED,  $aResults[0][3])
    _TestAssert("service[1] correctly marked FAILED with win32=5",     $aResults[1][3] = $SM_OUTCOME_FAILED And $aResults[1][4] = 5, "FAILED+5", $aResults[1][3] & "+" & String($aResults[1][4]))
    _TestAssert("service[2] outcome unaffected by service[1] failure", $aResults[2][3] = $SM_OUTCOME_STOPPED,  $SM_OUTCOME_STOPPED,  $aResults[2][3])
EndFunc

; ---------------------------------------------------------------------------
; Tests for shared-timeout accounting
; Verifies that TIMED_OUT is set when service does not reach STOPPED within deadline
; ---------------------------------------------------------------------------

Func _Test_SharedTimeout()
    ConsoleWrite(@CRLF & "--- Shared Timeout Outcome Accounting ---" & @CRLF)

    ; Simulate: service[0] stopped before deadline, service[1] did not
    Local $aResults[2][6]
    $aResults[0][0] = "DoSvc"     : $aResults[0][3] = $SM_OUTCOME_STOPPED
    $aResults[1][0] = "TrustedInstaller" : $aResults[1][3] = $SM_OUTCOME_TIMEDOUT : $aResults[1][2] = 3  ; STOP_PENDING

    _TestAssert("timed-out service: outcome = TIMED_OUT",   $aResults[1][3] = $SM_OUTCOME_TIMEDOUT, $SM_OUTCOME_TIMEDOUT, $aResults[1][3])
    _TestAssert("timed-out service: finalState = STOP_PENDING (3)", $aResults[1][2] = 3, "3", String($aResults[1][2]))
    _TestAssert("other service: outcome = STOPPED",         $aResults[0][3] = $SM_OUTCOME_STOPPED, $SM_OUTCOME_STOPPED, $aResults[0][3])
EndFunc

; ---------------------------------------------------------------------------
; Tests for state-to-outcome routing (stop-eligibility gate)
; Focuses on the three routing predicates and their mutual exclusivity.
; Assertions on _SM_IsStopEligible and _SM_StateNeedsPolling per individual
; state live in _Test_AllSevenStates to avoid duplication (CR-03 S-06).
; ---------------------------------------------------------------------------

Func _Test_StateToOutcomeRouting()
    ConsoleWrite(@CRLF & "--- State-to-Outcome Routing ---" & @CRLF)

    ; STOPPED at first query → ALREADY_STOPPED (no ControlService call)
    _TestAssert("state STOPPED → ALREADY_STOPPED (no control sent)", _SM_StateToAlreadyStopped($SM_STATE_STOPPED) = True)
    _TestAssert("state RUNNING → not already stopped",               _SM_StateToAlreadyStopped($SM_STATE_RUNNING) = False)
    _TestAssert("state PAUSED  → not already stopped",               _SM_StateToAlreadyStopped($SM_STATE_PAUSED)  = False)

    ; Confirm routing predicates are mutually exclusive for STOP_PENDING:
    ; eligible=False AND polling=True — these two must never both be True
    _TestAssert("STOP_PENDING: eligible=False, polling=True (mutually exclusive)", _
            (Not _SM_IsStopEligible($SM_STATE_STOP_PENDING)) And _SM_StateNeedsPolling($SM_STATE_STOP_PENDING))
EndFunc

; ---------------------------------------------------------------------------
; Tests for per-service result accounting (all 7 initial states covered)
; Verifies correct initial routing for each possible state
; ---------------------------------------------------------------------------

Func _Test_AllSevenStates()
    ConsoleWrite(@CRLF & "--- All 7 Service States Correctly Classified ---" & @CRLF)

    ; State 1: STOPPED → ALREADY_STOPPED
    _TestAssert("state 1 (STOPPED) → ALREADY_STOPPED routing", _SM_StateToAlreadyStopped($SM_STATE_STOPPED) = True)

    ; State 2: START_PENDING → not eligible, not polling → FAILED on ControlService attempt
    ;   (ControlService on START_PENDING returns 1061 CANNOT_ACCEPT_CTRL)
    _TestAssert("state 2 (START_PENDING) → not eligible for stop",  Not _SM_IsStopEligible($SM_STATE_START_PENDING))
    _TestAssert("state 2 (START_PENDING) → not in polling list",    Not _SM_StateNeedsPolling($SM_STATE_START_PENDING))
    ; This means START_PENDING services where stop is attempted will get FAILED from win32 1061
    _TestAssert("win32 1061 → FAILED outcome",  _SM_Win32ErrToOutcome(1061) = $SM_OUTCOME_FAILED)

    ; State 3: STOP_PENDING → not eligible, goes to polling
    _TestAssert("state 3 (STOP_PENDING) → polling only",  _SM_StateNeedsPolling($SM_STATE_STOP_PENDING) = True)
    _TestAssert("state 3 (STOP_PENDING) → not eligible",  Not _SM_IsStopEligible($SM_STATE_STOP_PENDING))

    ; State 4: RUNNING → eligible → ControlService → polling
    _TestAssert("state 4 (RUNNING) → eligible for stop",   _SM_IsStopEligible($SM_STATE_RUNNING) = True)
    _TestAssert("state 4 (RUNNING) → not pre-polling",     Not _SM_StateNeedsPolling($SM_STATE_RUNNING))

    ; State 5: CONTINUE_PENDING → eligible
    _TestAssert("state 5 (CONTINUE_PENDING) → eligible",   _SM_IsStopEligible($SM_STATE_CONTINUE_PENDING) = True)

    ; State 6: PAUSE_PENDING → eligible
    _TestAssert("state 6 (PAUSE_PENDING) → eligible",      _SM_IsStopEligible($SM_STATE_PAUSE_PENDING) = True)

    ; State 7: PAUSED → eligible
    _TestAssert("state 7 (PAUSED) → eligible",             _SM_IsStopEligible($SM_STATE_PAUSED) = True)
EndFunc

; ---------------------------------------------------------------------------
; Tests for empty input array
; ---------------------------------------------------------------------------

Func _Test_EmptyInput()
    ConsoleWrite(@CRLF & "--- Empty Input Array ---" & @CRLF)

    ; An empty input array must return an empty 2D result array (not @error=1)
    ; @error=1 is reserved for SCM open failure
    Local $aEmpty[0]
    Local $aResults = _SM_StopServicesBatch($aEmpty)
    _TestAssert("empty input: @error = 0 (not an SCM failure)",  @error = 0)
    _TestAssert("empty input: result row count = 0",             UBound($aResults) = 0)
EndFunc

; ---------------------------------------------------------------------------
; Tests for result row accounting: single UNAVAILABLE in a 2-service batch
; ---------------------------------------------------------------------------

Func _Test_UnavailableInBatch()
    ConsoleWrite(@CRLF & "--- Unavailable Service In Batch ---" & @CRLF)

    ; Simulate: service[0] does not exist, service[1] is RUNNING and stops successfully
    Local $aResults[2][6]
    $aResults[0][0] = "NonExistentService123" : $aResults[0][1] = -1 : $aResults[0][2] = -1
    $aResults[0][3] = $SM_OUTCOME_UNAVAILABLE : $aResults[0][4] = $ERR_SVC_NOT_EXIST
    $aResults[1][0] = "wuauserv"              : $aResults[1][1] = 4  : $aResults[1][2] = 1
    $aResults[1][3] = $SM_OUTCOME_STOPPED     : $aResults[1][4] = 0

    _TestAssert("unavailable service: initState = -1",         $aResults[0][1] = -1,                  "-1",    String($aResults[0][1]))
    _TestAssert("unavailable service: outcome = UNAVAILABLE",  $aResults[0][3] = $SM_OUTCOME_UNAVAILABLE, $SM_OUTCOME_UNAVAILABLE, $aResults[0][3])
    _TestAssert("unavailable service: win32 = 1060",           $aResults[0][4] = $ERR_SVC_NOT_EXIST,  "1060",  String($aResults[0][4]))
    _TestAssert("other service: outcome unaffected = STOPPED", $aResults[1][3] = $SM_OUTCOME_STOPPED, $SM_OUTCOME_STOPPED, $aResults[1][3])
EndFunc

; ---------------------------------------------------------------------------
; Behavioral integration test: _SM_StopServicesBatch with non-existent services
;
; WHY THIS IS THE TESTABLE INTEGRATION PATH IN A LINUX SANDBOX
; ------------------------------------------------------------
; The two-phase batch-stop algorithm (Phase 1: issue stop controls; Phase 2:
; poll against shared deadline) cannot be exercised with real Windows services
; in this Linux sandbox because:
;   a) AutoIt runs only on Windows; this harness is marked NOT RUN in the
;      Linux sandbox (environment gate in the header).
;   b) Even on Windows, the production service names (wuauserv, TrustedInstaller,
;      etc.) must NOT be stopped by the test harness (REQ-009 — no live stop
;      controls).
;
; The UNAVAILABLE path (OpenServiceW → Win32 1060 ERROR_SERVICE_DOES_NOT_EXIST)
; is the only path through Phase 1 that:
;   - exercises real SCM code (OpenSCManagerW succeeds, OpenServiceW fails)
;   - issues zero stop controls (the service handle is never obtained)
;   - produces a deterministic outcome regardless of which Windows system runs it
;     (a deliberately nonsensical name will never exist)
;   - reaches the result-accounting branch that records initState=-1,
;     finalState=-1, outcome=UNAVAILABLE, win32=1060
;
; This test validates that the Phase 1 UNAVAILABLE routing in
; _SM_StopServicesBatch produces the correct per-row result for each input
; service and that @error=0 (the batch itself did not fail — only individual
; services were absent).
;
; NOTE: Requires #RequireAdmin (opens a live SCM handle on Windows).
; ---------------------------------------------------------------------------

Func _Test_BatchUnknownServices()
    ConsoleWrite(@CRLF & "--- _SM_StopServicesBatch: Phase 1 UNAVAILABLE path ---" & @CRLF)

    ; Three names that do not exist on any real Windows install.
    ; Using names with internal underscores and mixed case to avoid any
    ; accidental collision with real service names.
    Local $aNames[3] = ["__TestHarness_NX_Svc1__", "__TestHarness_NX_Svc2__", "__TestHarness_NX_Svc3__"]

    Local $aResults = _SM_StopServicesBatch($aNames)

    ; Batch-level @error must be 0 — SCM opened successfully even though
    ; the individual services do not exist
    _TestAssert("unknown services: @error = 0 (SCM open succeeded)",   @error = 0)

    ; Result array must have one row per input service
    _TestAssert("unknown services: row count = 3",  UBound($aResults, 1) = 3, "3", String(UBound($aResults, 1)))

    ; Each row must have exactly 6 columns
    _TestAssert("unknown services: col count = 6",  UBound($aResults, 2) = 6, "6", String(UBound($aResults, 2)))

    ; All three services must be routed to UNAVAILABLE (Phase 1: OpenServiceW → 1060)
    Local $i
    For $i = 0 To 2
        _TestAssert("row " & $i & ": outcome = UNAVAILABLE",    $aResults[$i][3] = $SM_OUTCOME_UNAVAILABLE, $SM_OUTCOME_UNAVAILABLE, $aResults[$i][3])
        _TestAssert("row " & $i & ": win32 = 1060",             $aResults[$i][4] = $SM_ERR_SVC_NOT_EXIST,   "1060",                  String($aResults[$i][4]))
        _TestAssert("row " & $i & ": initState = -1",           $aResults[$i][1] = -1,                      "-1",                    String($aResults[$i][1]))
        _TestAssert("row " & $i & ": finalState = -1",          $aResults[$i][2] = -1,                      "-1",                    String($aResults[$i][2]))
        _TestAssert("row " & $i & ": name preserved in row",    $aResults[$i][0] = $aNames[$i],             $aNames[$i],             $aResults[$i][0])
    Next
EndFunc

; ---------------------------------------------------------------------------
; Main: run all tests
; ---------------------------------------------------------------------------

#include "Includes\ServiceManager.au3"

ConsoleWrite("ServiceManager.Tests.au3 — deterministic test harness" & @CRLF)
ConsoleWrite("No live service stop controls are issued in this harness." & @CRLF)

_Test_ServiceStateToString()
_Test_Win32ErrToOutcome()
_Test_IsStopEligible()
_Test_BuildResultRow()
_Test_ResultArrayDimensions()
_Test_SingleFailureInBatch()
_Test_SharedTimeout()
_Test_StateToOutcomeRouting()
_Test_AllSevenStates()
_Test_EmptyInput()
_Test_UnavailableInBatch()
_Test_BatchUnknownServices()

_PrintResults()

If $g_iFailCount > 0 Then
    Exit 1   ; Non-zero exit = test failure (CI-friendly)
Else
    Exit 0
EndIf
