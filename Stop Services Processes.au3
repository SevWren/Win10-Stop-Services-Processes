#RequireAdmin
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=ff7.ico
#AutoIt3Wrapper_Outfile_x64=.\release\Stop Services - Processes.exe
#AutoIt3Wrapper_Compression=0
#AutoIt3Wrapper_Compile_Both=y
#AutoIt3Wrapper_UseX64=y
#AutoIt3Wrapper_Res_Description=Script monitors processes and services related to windows update and terminates if running.
#AutoIt3Wrapper_Res_Icon_Add=ff7.ico
#AutoIt3Wrapper_AU3Check_Parameters=-q -d -w 1 -w 2 -w 3 -w 4
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_ShowProgress=Y

#Region ;Includes/Options/Permissions
; ServiceControl.au3: custom advapi32.dll wrapper — retained for _ServiceExists,
;   _ServiceRunning, _StartService, _CreateService, _DeleteService.
;   _StopService in ServiceControl.au3 is NO LONGER called; use _SM_StopServicesBatch.
#include "Includes\ServiceControl.au3"
; ServiceManager.au3: authoritative service-stop adapter (T03/T04 rework)
#include "Includes\ServiceManager.au3"
#include <MsgBoxConstants.au3>
#include <AutoItConstants.au3>
#include <Misc.au3>
#include <Date.au3>
#include <WinAPI.au3>       ; _WinAPI_GetLastError, _WinAPI_OpenProcess, _WinAPI_CloseHandle
#include <WinAPIProc.au3>   ; _WinAPI_GetPriorityClass, WinAPI priority class constants
#include <Array.au3>        ; _ArrayAdd, _ArrayDelete
Opt("TrayIconDebug", 1)
Opt("WinTitleMatchMode", 2)
#EndRegion ;Includes/Options/Permissions

#Region ;hotkeys
HotKeySet("{ScrollLock}{PAUSE}", "_exit")
HotKeySet("+{F1}", "ToggleScript")       ; Shift+F1 — toggle monitoring loop on/off
HotKeySet("+^9", "SetProcessPriority")   ; Ctrl+Shift+9 — set priority for all instances of a named process
HotKeySet("^!+9", "LockProcessPriority") ; Ctrl+Alt+Shift+9 — lock a specific PID's priority and auto-restore on drift
#EndRegion

#Region ;Timing constants
; Single definition point for all interval values.
; Ref: docs/ARCHITECTURE.md — Timing Constants
Global Const $PROC_POLL_INTERVAL_SEC   = 2       ; process-kill cycle (seconds)
Global Const $SVC_POLL_INTERVAL_SEC    = 10      ; service-stop cycle (seconds)
Global Const $MAIN_LOOP_SLEEP_MS       = 500     ; active monitoring While loop sleep (ms)
Global Const $PRIORITY_WATCHDOG_MS     = 10000   ; AdlibRegister interval for _PriorityWatchdog (ms)
Global Const $SVC_BATCH_TIMEOUT_MS     = 20000   ; shared deadline for one batch-stop (ms)
Global Const $SVC_BATCH_POLL_MS        = 500     ; poll sleep within batch-stop wait loop (ms)
#EndRegion

#Region ;Variables/Logging
Global $sStringInstaller   = "In the _CloserInstaller function and just terminated"
Global $taskcloseran       = 0

; Process inventory — processes closed every $PROC_POLL_INTERVAL_SEC seconds.
; Note: "xgamehelper.exe" appears at index 15 and 16 (preserved as-is from baseline —
;   second close is a harmless no-op; see BASELINE-INVENTORY.md).
Global $sProcesses[18] = [ _
    "taskhostw.exe", "TrustedInstaller.exe", "TiWorker.exe", "CompatTelRunner.exe", _
    "VSSVC.exe", "msiexec.exe", "msedge.exe", "helppane.exe", "net.exe", "vmcompute.exe", _
    "msedgewebview2.exe", "update.exe", "AggregatorHost.exe", "dllhost.exe", "TCPSVCS.EXE", _
    "xgamehelper.exe", "xgamehelper.exe", "backgroundTaskHost.exe"]

Global $bScriptRunning = False   ; tracks whether the monitoring loop is active
Global $iLastStopServices  = TimerInit()  ; timer for service-stop cycle
Global $iLastStopProcesses = 0            ; timer for process-kill cycle (0 → fires on first check)

Global $iconfile = @ScriptDir & "\ff7.ico"

Global $iLogMaxAgeDays = 7
Global $sLogFile       = @HomeDrive & "\login\closure_log.txt"
Global $iLogLevel      = 2      ; 0=Error, 1=Info, 2=Verbose
Global $bLogToConsole  = True   ; mirrors output to SciTE console

Global Const $PROCESS_IDLE = 0  ; not defined in this AutoIt version's AutoItConstants.au3

; Priority watchdog parallel arrays
Global $aPriorityWatchPIDs[0]      ; PIDs under watchdog
Global $aPriorityWatchTargets[0]   ; corresponding target AutoIt priority constants (0–5)
Global $aPriorityWatchNames[0]     ; corresponding human-readable priority names

TraySetIcon($iconfile)
ConsoleWrite("DEBUG: Starting log initialization." & @CRLF)
ConsoleWrite("DEBUG: Log file path is: " & $sLogFile & @CRLF)

If Not FileExists($sLogFile) Then
    ConsoleWrite("DEBUG: Log file does not exist. Attempting to create." & @CRLF)
    Dim $sLogDir = StringRegExpReplace($sLogFile, "\\[^\\]+$", "")
    DirCreate($sLogDir)
    If @error Then
        ConsoleWrite("FATAL ERROR: Could not create directory: " & $sLogDir & " (Error: " & @error & "). Script cannot continue logging." & @CRLF)
    Else
        ConsoleWrite("DEBUG: Directory exists or was created. Writing initial log entry directly." & @CRLF)
        Dim $sDateTime = _NowTime(12) & " " & @MDAY & "/" & @MON & "/" & @YEAR
        Dim $sLogEntry = $sDateTime & " [System] Log file initialized"
        FileWrite($sLogFile, $sLogEntry & @CRLF)
        If @error Then
            ConsoleWrite("FATAL ERROR: Could not write initial entry to log file: " & $sLogFile & " (Error: " & @error & "). Check permissions or antivirus." & @CRLF)
        Else
            ConsoleWrite("DEBUG: Initial log entry written successfully." & @CRLF)
        EndIf
    EndIf
Else
    ConsoleWrite("DEBUG: Log file exists. Checking for rotation." & @CRLF)
    _CheckAndRotateLogFile($sLogFile, $iLogMaxAgeDays)
EndIf
#EndRegion ;Variables/Logging

While 1   ; Main loop — passive. Hotkeys drive all behavior.
    Sleep(50)
WEnd

; ---------------------------------------------------------------------------
; Func ToggleScript
; Hotkey: Shift+F1 — toggles the active monitoring loop on/off.
; ---------------------------------------------------------------------------
Func ToggleScript()
    If $bScriptRunning Then
        _LogMessage("F1 pressed - Pausing script", "System", 1)
        MsgBox($MB_SYSTEMMODAL, "AutoIT Script", "Script paused!", 1)
        $bScriptRunning = False
    Else
        _LogMessage("F1 pressed - Starting script", "System", 1)
        MsgBox($MB_SYSTEMMODAL, "AutoIT Script", "Script started!", 1)
        $bScriptRunning = True
    EndIf

    While $bScriptRunning   ; active monitoring loop — exits when Shift+F1 sets $bScriptRunning = False
        If CheckElapsedTime($iLastStopProcesses, $PROC_POLL_INTERVAL_SEC) Then
            _CloseInstaller()
            $iLastStopProcesses = TimerInit()
        EndIf
        If CheckElapsedTime($iLastStopServices, $SVC_POLL_INTERVAL_SEC) Then
            _RunServiceBatchStop()
            $iLastStopServices = TimerInit()
        EndIf
        Sleep($MAIN_LOOP_SLEEP_MS)
        _miscpopups()
    WEnd
EndFunc   ;==>ToggleScript

; ---------------------------------------------------------------------------
; Func _CheckAndRotateLogFile
; Deletes the log file if it is older than $iDaysMax days.
; ---------------------------------------------------------------------------
Func _CheckAndRotateLogFile($sPath, $iDaysMax)
    If FileExists($sPath) Then
        Local $aFileTime = FileGetTime($sPath, 0, 1)
        If IsArray($aFileTime) Then
            Local $iFileDate = _DateToDayValue($aFileTime[0], $aFileTime[1], $aFileTime[2])
            Local $iToday    = _DateToDayValue(@YEAR, @MON, @MDAY)
            If $iToday - $iFileDate > $iDaysMax Then
                ConsoleWrite("DEBUG: Log file is older than " & $iDaysMax & " days. Deleting." & @CRLF)
                FileDelete($sPath)
                If @error Then
                    ConsoleWrite("ERROR: Failed to delete old log file. (Error: " & @error & ")" & @CRLF)
                EndIf
            EndIf
        EndIf
    EndIf
EndFunc   ;==>_CheckAndRotateLogFile

; ---------------------------------------------------------------------------
; Func _CloseInstaller
; Terminates every process named in $sProcesses[]. Called every $PROC_POLL_INTERVAL_SEC.
; ---------------------------------------------------------------------------
Func _CloseInstaller()
    Local $iSuccess = 0, $iFailure = 0, $bActionTaken = False

    For $i = 0 To UBound($sProcesses) - 1
        If ProcessExists($sProcesses[$i]) Then
            $bActionTaken = True
            Local $iResult = ProcessClose($sProcesses[$i])
            If $iResult = 1 Then
                $iSuccess += 1
                _LogMessage("Successfully closed process: " & $sProcesses[$i], "Process", 1)
            Else
                $iFailure += 1
                _LogMessage("Failed to close process: " & $sProcesses[$i] & " (Error: " & @error & ")", "Process", 0)
            EndIf
        EndIf
    Next

    If $bActionTaken Then
        _LogMessage("Process closure summary - Success: " & $iSuccess & ", Failed: " & $iFailure, "Process", 1)
    EndIf
EndFunc   ;==>_CloseInstaller

; ---------------------------------------------------------------------------
; Func _RunServiceBatchStop
; Wrapper that calls _SM_StopServicesBatch() and routes each result row to
; _LogMessage. Called every $SVC_POLL_INTERVAL_SEC.
;
; Service inventory per enterprise prompt (9 services):
;   FDResPub, fdPHost, TrustedInstaller, wuauserv, UsoSvc, DoSvc,
;   WaaSMedicSvc, SSDPSRV, sppsvc
; ---------------------------------------------------------------------------
Func _RunServiceBatchStop()
    Local $aNames[9] = [ _
        "FDResPub", "fdPHost", "TrustedInstaller", "wuauserv", _
        "UsoSvc", "DoSvc", "WaaSMedicSvc", "SSDPSRV", "sppsvc"]

    Local $aResults = _SM_StopServicesBatch($aNames, $SVC_BATCH_TIMEOUT_MS, $SVC_BATCH_POLL_MS)
    If @error Then
        _LogMessage("Service batch stop: could not open SCM — batch skipped", "Service", 0)
        Return
    EndIf

    For $i = 0 To UBound($aResults) - 1
        Local $sSvcName = $aResults[$i][0]
        Local $sOutcome = $aResults[$i][3]
        Local $iWin32   = $aResults[$i][4]
        Select
            Case $sOutcome = $SM_OUTCOME_STOPPED
                _LogMessage("Service stopped: " & $sSvcName, "Service", 1)
            Case $sOutcome = $SM_OUTCOME_ALREADY
                _LogMessage("Service already stopped: " & $sSvcName, "Service", 2)
            Case $sOutcome = $SM_OUTCOME_TIMEDOUT
                _LogMessage("Service stop timed out: " & $sSvcName, "Service", 0)
            Case $sOutcome = $SM_OUTCOME_UNAVAILABLE
                _LogMessage("Service not found: " & $sSvcName, "Service", 2)
            Case $sOutcome = $SM_OUTCOME_FAILED
                _LogMessage("Service stop failed: " & $sSvcName & " (Win32: " & $iWin32 & ")", "Service", 0)
            Case Else
                _LogMessage("Service outcome unknown: " & $sSvcName & " (" & $sOutcome & ")", "Service", 0)
        EndSelect
    Next
EndFunc   ;==>_RunServiceBatchStop

; ---------------------------------------------------------------------------
; Func _LogMessage
; Routes all runtime log messages to file and optionally to SciTE console.
; ---------------------------------------------------------------------------
Func _LogMessage($sMessage, $sType, $iLevel)
    If $iLevel > $iLogLevel Then Return   ; skip if below current verbosity threshold
    Local $sDateTime = _NowTime(12) & " " & @MDAY & "/" & @MON & "/" & @YEAR
    Local $sLogEntry = @CRLF & $sDateTime & " [" & $sType & "] " & $sMessage

    Local $hFile = FileOpen($sLogFile, 1)   ; Mode 1 = Append
    If $hFile = -1 Then
        ConsoleWrite("ERROR in _LogMessage: Could not open log file '" & $sLogFile & "' for writing. @error code = " & @error & @CRLF)
        Return
    EndIf
    FileWrite($hFile, $sLogEntry)
    FileClose($hFile)

    If $bLogToConsole Then
        ConsoleWrite($sLogEntry & @CRLF)
    EndIf
EndFunc   ;==>_LogMessage

; ---------------------------------------------------------------------------
; Func CheckElapsedTime
; Returns True if at least $iInterval seconds have elapsed since $iStartTime.
; ---------------------------------------------------------------------------
Func CheckElapsedTime($iStartTime, $iInterval)
    Return TimerDiff($iStartTime) >= ($iInterval * 1000)
EndFunc   ;==>CheckElapsedTime

; ---------------------------------------------------------------------------
; Func SetProcessPriority
; Hotkey: Ctrl+Shift+9 — sets priority for all instances of a named process.
; ---------------------------------------------------------------------------
Func SetProcessPriority()
    Local $sProcessName = InputBox("Process Priority", "Enter process name:")
    If @error Then
        _LogMessage("Process priority setting cancelled by user (Process Name Input)", "ProcessPriority", 1)
        Return
    EndIf
    If $sProcessName = "" Then
        _LogMessage("Process priority setting cancelled: Process name cannot be empty.", "ProcessPriority", 1)
        MsgBox($MB_SYSTEMMODAL, "Process Priority", "Process name cannot be empty.", 1)
        Return
    EndIf

    Local $sPriorityLevel = InputBox("Process Priority", "Select priority level:" & @CRLF & "1 - Below Normal" & @CRLF & "2 - Normal" & @CRLF & "3 - Above Normal")
    If @error Then
        _LogMessage("Process priority setting cancelled by user (Priority Level Input)", "ProcessPriority", 1)
        Return
    EndIf

    Local $iPriorityConst
    Switch $sPriorityLevel
        Case "1"
            $iPriorityConst = $PROCESS_BELOWNORMAL
        Case "2"
            $iPriorityConst = $PROCESS_NORMAL
        Case "3"
            $iPriorityConst = $PROCESS_ABOVENORMAL
        Case Else
            _LogMessage("Invalid priority level entered: " & $sPriorityLevel, "ProcessPriority", 0)
            MsgBox($MB_SYSTEMMODAL, "Process Priority", "Invalid priority level. Please enter 1, 2, or 3.", 1)
            Return
    EndSwitch

    Local $aProcessList = ProcessList($sProcessName)
    If @error Or $aProcessList[0][0] = 0 Then
        _LogMessage("No processes found with the name '" & $sProcessName & "'.", "ProcessPriority", 1)
        MsgBox($MB_SYSTEMMODAL, "Process Priority", "No processes found with the name '" & $sProcessName & "'.", 1)
        Return
    EndIf

    Local $iSuccessCount = 0
    Local $iFailureCount = 0
    Local $sPriorityName
    Switch $iPriorityConst
        Case $PROCESS_BELOWNORMAL
            $sPriorityName = "Below Normal"
        Case $PROCESS_NORMAL
            $sPriorityName = "Normal"
        Case $PROCESS_ABOVENORMAL
            $sPriorityName = "Above Normal"
    EndSwitch

    For $i = 1 To $aProcessList[0][0]
        Local $iPID = $aProcessList[$i][1]
        If ProcessSetPriority($iPID, $iPriorityConst) Then
            $iSuccessCount += 1
        Else
            $iFailureCount += 1
            _LogMessage("Failed to set priority for process '" & $sProcessName & "' (PID: " & $iPID & ") (Error: " & @error & ")", "ProcessPriority", 0)
        EndIf
    Next

    If $iSuccessCount > 0 Then
        _LogMessage("Successfully set priority to " & $sPriorityName & " for " & $iSuccessCount & " instance(s) of process '" & $sProcessName & "'.", "ProcessPriority", 1)
    EndIf
    If $iFailureCount > 0 Then
        _LogMessage("Failed to set priority for " & $iFailureCount & " instance(s) of process '" & $sProcessName & "'. See log for details.", "ProcessPriority", 0)
    EndIf

    Local $sMsg = "Priority set to " & $sPriorityName & " for " & $iSuccessCount & " instance(s) of '" & $sProcessName & "'."
    If $iFailureCount > 0 Then $sMsg &= @CRLF & "Failed to set priority for " & $iFailureCount & " instance(s). Check log for errors."
    MsgBox($MB_SYSTEMMODAL, "Process Priority", $sMsg, 1)
EndFunc   ;==>SetProcessPriority

; ---------------------------------------------------------------------------
; Func LockProcessPriority
; Hotkey: Ctrl+Alt+Shift+9 — locks a PID to a priority; watchdog auto-restores on drift.
; ---------------------------------------------------------------------------
Func LockProcessPriority()
    ; --- Step 1: Collect and validate PID ---
    Local $sRawPID = InputBox("Priority Watchdog", "Enter the Process ID (PID) to monitor:" & @CRLF & @CRLF & "Must be a positive integer of a currently running process.")
    If @error Then
        _LogMessage("LockProcessPriority: Cancelled by user at PID prompt.", "PriorityWatchdog", 1)
        Return
    EndIf

    If Not StringIsDigit($sRawPID) Or Number($sRawPID) <= 0 Then
        _TrayNotify("Invalid PID. Must be a positive whole number.")
        _LogMessage("LockProcessPriority: Invalid PID entered: '" & $sRawPID & "'", "PriorityWatchdog", 0)
        Return
    EndIf

    Local $iPID = Int($sRawPID)
    If Not ProcessExists($iPID) Then
        _TrayNotify("PID " & $iPID & " does not exist.")
        _LogMessage("LockProcessPriority: PID " & $iPID & " does not exist.", "PriorityWatchdog", 0)
        Return
    EndIf

    ; Reject duplicate — each PID may appear only once in the watchlist
    For $i = 0 To UBound($aPriorityWatchPIDs) - 1
        If $aPriorityWatchPIDs[$i] = $iPID Then
            _TrayNotify("PID " & $iPID & " is already being monitored.")
            _LogMessage("LockProcessPriority: PID " & $iPID & " is already in the watchlist.", "PriorityWatchdog", 1)
            Return
        EndIf
    Next

    ; --- Step 2: Collect and validate priority ---
    Local $sPriorityPrompt = "Select target priority for PID " & $iPID & ":" & @CRLF & @CRLF & _
            "0 = Idle" & @CRLF & _
            "1 = Below Normal" & @CRLF & _
            "2 = Normal" & @CRLF & _
            "3 = Above Normal" & @CRLF & _
            "4 = High" & @CRLF & _
            "5 = Real-time  (use with extreme caution)"

    Local $sRawPriority = InputBox("Priority Watchdog", $sPriorityPrompt, "2")
    If @error Then
        _LogMessage("LockProcessPriority: Cancelled by user at priority prompt for PID " & $iPID & ".", "PriorityWatchdog", 1)
        Return
    EndIf

    If Not StringIsDigit($sRawPriority) Then
        _TrayNotify("Invalid input. Enter a number from 0 to 5.")
        _LogMessage("LockProcessPriority: Non-numeric priority input '" & $sRawPriority & "' for PID " & $iPID & ".", "PriorityWatchdog", 0)
        Return
    EndIf

    Local $iPriorityConst = Int($sRawPriority)
    If $iPriorityConst < 0 Or $iPriorityConst > 5 Then
        _TrayNotify("Priority must be 0 through 5.")
        _LogMessage("LockProcessPriority: Priority out of range: " & $iPriorityConst & " for PID " & $iPID & ".", "PriorityWatchdog", 0)
        Return
    EndIf

    Local $sPriorityName = _PriorityConstantToName($iPriorityConst)

    ; --- Step 3: TOCTOU re-check then apply priority immediately ---
    If Not ProcessExists($iPID) Then
        _TrayNotify("PID " & $iPID & " exited before priority could be set.")
        _LogMessage("LockProcessPriority: PID " & $iPID & " exited between input and initial set.", "PriorityWatchdog", 1)
        Return
    EndIf

    If Not ProcessSetPriority($iPID, $iPriorityConst) Then
        _TrayNotify("Failed to set priority for PID " & $iPID & ". See log.")
        _LogMessage("LockProcessPriority: ProcessSetPriority failed for PID " & $iPID & " (Error: " & @error & ")", "PriorityWatchdog", 0)
        Return
    EndIf

    ; --- Step 4: Add to watchlist; register AdlibRegister only on first entry ---
    Local $bWasEmpty = (UBound($aPriorityWatchPIDs) = 0)
    _ArrayAdd($aPriorityWatchPIDs, $iPID)
    _ArrayAdd($aPriorityWatchTargets, $iPriorityConst)
    _ArrayAdd($aPriorityWatchNames, $sPriorityName)

    If $bWasEmpty Then AdlibRegister("_PriorityWatchdog", $PRIORITY_WATCHDOG_MS)

    _TrayNotify("Watching PID " & $iPID & " -> " & $sPriorityName)
    _LogMessage("LockProcessPriority: Watchdog started — PID " & $iPID & " → " & $sPriorityName & " (" & UBound($aPriorityWatchPIDs) & " PID(s) now monitored)", "PriorityWatchdog", 1)
EndFunc   ;==>LockProcessPriority

; ---------------------------------------------------------------------------
; Func _PriorityWatchdog
; AdlibRegister callback — fires every $PRIORITY_WATCHDOG_MS.
; Checks priority of each watched PID; restores if drifted; removes dead PIDs.
; ---------------------------------------------------------------------------
Func _PriorityWatchdog()
    ; Iterate backwards so _ArrayDelete does not shift unprocessed indices
    For $i = UBound($aPriorityWatchPIDs) - 1 To 0 Step -1
        Local $iPID          = $aPriorityWatchPIDs[$i]
        Local $iPriorityConst = $aPriorityWatchTargets[$i]
        Local $sPriorityName  = $aPriorityWatchNames[$i]

        If Not ProcessExists($iPID) Then
            _ArrayDelete($aPriorityWatchPIDs, $i)
            _ArrayDelete($aPriorityWatchTargets, $i)
            _ArrayDelete($aPriorityWatchNames, $i)
            _TrayNotify("PID " & $iPID & " exited - watchdog stopped.")
            _LogMessage("_PriorityWatchdog: PID " & $iPID & " no longer exists. Removed from watchlist (" & UBound($aPriorityWatchPIDs) & " PID(s) remaining)", "PriorityWatchdog", 1)
            ContinueLoop
        EndIf

        Local $iCurrentConst = _GetProcessPriorityByPID($iPID)
        If $iCurrentConst = -1 Then
            _LogMessage("_PriorityWatchdog: Could not read priority for PID " & $iPID & ". Deferring check to next tick.", "PriorityWatchdog", 0)
            ContinueLoop
        EndIf

        If $iCurrentConst <> $iPriorityConst Then
            Local $sCurrentName = _PriorityConstantToName($iCurrentConst)
            _LogMessage("_PriorityWatchdog: Priority drift on PID " & $iPID & " — detected " & $sCurrentName & ", expected " & $sPriorityName & ". Restoring.", "PriorityWatchdog", 1)

            ; TOCTOU re-check before restore
            If Not ProcessExists($iPID) Then
                _ArrayDelete($aPriorityWatchPIDs, $i)
                _ArrayDelete($aPriorityWatchTargets, $i)
                _ArrayDelete($aPriorityWatchNames, $i)
                _TrayNotify("PID " & $iPID & " exited - watchdog stopped.")
                _LogMessage("_PriorityWatchdog: PID " & $iPID & " exited between drift detection and restore attempt.", "PriorityWatchdog", 1)
                ContinueLoop
            EndIf

            If ProcessSetPriority($iPID, $iPriorityConst) Then
                _TrayNotify("PID " & $iPID & " restored to " & $sPriorityName)
                _LogMessage("_PriorityWatchdog: Successfully restored PID " & $iPID & " → " & $sPriorityName, "PriorityWatchdog", 1)
            Else
                _LogMessage("_PriorityWatchdog: ProcessSetPriority failed on restore for PID " & $iPID & " (Error: " & @error & ")", "PriorityWatchdog", 0)
            EndIf
        EndIf
    Next

    If UBound($aPriorityWatchPIDs) = 0 Then
        AdlibUnRegister("_PriorityWatchdog")
        _LogMessage("_PriorityWatchdog: Watchlist empty. AdlibUnRegister called.", "PriorityWatchdog", 1)
    EndIf
EndFunc   ;==>_PriorityWatchdog

; ---------------------------------------------------------------------------
; Func _GetProcessPriorityByPID
; Returns the current AutoIt priority constant (0–5) for the given PID.
; Returns -1 on any failure.
;
; Uses DllCall directly — bypasses _WinAPI_GetPriorityClass wrapper which
; propagates unreliable @error values in AutoIt 3.3.16.x.
; Uses PROCESS_QUERY_LIMITED_INFORMATION (0x1000) — broader access than 0x0400.
;
; Ref: https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-openprocess
; Ref: https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getpriorityclass
; ---------------------------------------------------------------------------
Func _GetProcessPriorityByPID($iPID)
    Local Const $PROCESS_QUERY_LIMITED_INFORMATION = 0x1000

    Local $aOpen = DllCall("kernel32.dll", "handle", "OpenProcess", "dword", $PROCESS_QUERY_LIMITED_INFORMATION, "bool", False, "dword", $iPID)
    If @error Or Not $aOpen[0] Then
        Local $iOpenWinErr = _WinAPI_GetLastError()
        _LogMessage("_GetProcessPriorityByPID: OpenProcess failed for PID " & $iPID & " (DllError: " & @error & ", WinError: " & $iOpenWinErr & ")", "PriorityWatchdog", 0)
        Return -1
    EndIf

    Local $aResult   = DllCall("kernel32.dll", "dword", "GetPriorityClass", "handle", $aOpen[0])
    Local $iDllError = @error               ; capture IMMEDIATELY
    Local $iWinError = _WinAPI_GetLastError()   ; before CloseHandle
    DllCall("kernel32.dll", "bool", "CloseHandle", "handle", $aOpen[0])

    If $iDllError Or Not $aResult[0] Then
        _LogMessage("_GetProcessPriorityByPID: GetPriorityClass failed for PID " & $iPID & " (DllError: " & $iDllError & ", WinError: " & $iWinError & ")", "PriorityWatchdog", 0)
        Return -1
    EndIf

    Return _WinAPIPriorityClassToAutoItConst($aResult[0])
EndFunc   ;==>_GetProcessPriorityByPID

; ---------------------------------------------------------------------------
; Func _WinAPIPriorityClassToAutoItConst
; Maps Windows API PRIORITY_CLASS values to AutoIt ProcessSetPriority constants.
; These are entirely different numbering schemes — this conversion is mandatory.
; ---------------------------------------------------------------------------
Func _WinAPIPriorityClassToAutoItConst($iWinAPIClass)
    Switch $iWinAPIClass
        Case $IDLE_PRIORITY_CLASS          ; 0x00000040
            Return $PROCESS_IDLE           ; 0
        Case $BELOW_NORMAL_PRIORITY_CLASS  ; 0x00004000
            Return $PROCESS_BELOWNORMAL    ; 1
        Case $NORMAL_PRIORITY_CLASS        ; 0x00000020
            Return $PROCESS_NORMAL         ; 2
        Case $ABOVE_NORMAL_PRIORITY_CLASS  ; 0x00008000
            Return $PROCESS_ABOVENORMAL    ; 3
        Case $HIGH_PRIORITY_CLASS          ; 0x00000080
            Return $PROCESS_HIGH           ; 4
        Case $REALTIME_PRIORITY_CLASS      ; 0x00000100
            Return $PROCESS_REALTIME       ; 5
        Case Else
            Return -1   ; unrecognised priority class
    EndSwitch
EndFunc   ;==>_WinAPIPriorityClassToAutoItConst

; ---------------------------------------------------------------------------
; Func _PriorityConstantToName
; Maps AutoIt ProcessSetPriority constants (0–5) to human-readable strings.
; ---------------------------------------------------------------------------
Func _PriorityConstantToName($iPriorityConst)
    Switch $iPriorityConst
        Case $PROCESS_IDLE
            Return "Idle"
        Case $PROCESS_BELOWNORMAL
            Return "Below Normal"
        Case $PROCESS_NORMAL
            Return "Normal"
        Case $PROCESS_ABOVENORMAL
            Return "Above Normal"
        Case $PROCESS_HIGH
            Return "High"
        Case $PROCESS_REALTIME
            Return "Real-time"
        Case Else
            Return "Unknown (" & $iPriorityConst & ")"
    EndSwitch
EndFunc   ;==>_PriorityConstantToName

#Region ;traytips
; ---------------------------------------------------------------------------
; Func _TrayNotify
; Displays a small tray tooltip (ToolTip, NOT TrayTip).
; TrayTip produces large Windows 10/11 toast notifications with Action Center
; entries — ToolTip does not.
; ---------------------------------------------------------------------------
Func _TrayNotify($sMessage)
    ToolTip("[Priority Watchdog]" & @CRLF & $sMessage, @DesktopWidth - 260, @DesktopHeight - 80)
    AdlibRegister("_ClearTrayNotify", 2000)
EndFunc   ;==>_TrayNotify

Func _ClearTrayNotify()
    ToolTip("")
    AdlibUnRegister("_ClearTrayNotify")
EndFunc   ;==>_ClearTrayNotify
#EndRegion ;traytips

; ---------------------------------------------------------------------------
; Func _miscpopups
; Closes known application registration dialogs.
; Specific to author's system — disable by commenting out the call in ToggleScript.
; ---------------------------------------------------------------------------
Func _miscpopups()
    If WinExists("[CLASS:TPleaseRegisterForm]") Then
        _LogMessage("Closing AdvancedRenamer popup (TPleaseRegisterForm)", "System", 1)
        WinClose("[CLASS:TPleaseRegisterForm]")
    ElseIf WinExists("This is an unregistered copy", "") Then
        WinClose("This is an unregistered copy", "")
        _LogMessage("Closing Sublime Text unregistered-copy popup", "System", 1)
    EndIf
EndFunc   ;==>_miscpopups

; ---------------------------------------------------------------------------
; Func _exit
; Hotkey: ScrollLock+Pause — terminates the script immediately.
; ---------------------------------------------------------------------------
Func _exit()
    _LogMessage("Script termination requested", "System", 1)
    _LogMessage("Script Was Terminated by _exit()", "System", 1)
    Exit
EndFunc   ;==>_exit
