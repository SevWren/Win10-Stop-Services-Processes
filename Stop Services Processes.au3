#RequireAdmin
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=ff7.ico
#AutoIt3Wrapper_Outfile_x64=..\..\..\Users\mmuel\Desktop\Stop Services - Processes.Exe
#AutoIt3Wrapper_Compression=0
#AutoIt3Wrapper_Res_Description=Script monitors processes and services related to windows update and terminates if running.
#AutoIt3Wrapper_Res_Icon_Add=C:\github\my-github-info\Win10-Stop-Services-Processes\ff7.ico
#AutoIt3Wrapper_AU3Check_Parameters=-q -d -w 1 -w 2 -w 3 -w 4
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_ShowProgress=Y

#Region ;Includes/Options/Permissions/Hotkeys

;This is the ServiceControlAu3 library included in the repo
#include "C:\github\my-github-info\Win10-Stop-Services-Processes\Includes\ServiceControl.au3"
;Standard AU3 library Locations with AutoIT  Program Files (x86)\AutoIt3\Include
#include <MsgBoxConstants.au3>
#include <AutoItConstants.au3>
#include <Misc.au3>
#include <Date.au3>
#include <WinAPI.au3>       ; _WinAPI_OpenProcess, _WinAPI_CloseHandle
#include <WinAPIProc.au3>   ; _WinAPI_GetPriorityClass, WinAPI priority class constants
#include <Array.au3>        ; _ArrayAdd, _ArrayDelete
Opt("TrayIconDebug", 1) ;0=no info, 1=debug line info
Opt("WinTitleMatchMode", 2)
HotKeySet("{ScrollLock}{PAUSE}", "_exit")
HotKeySet("+{F1}", "ToggleScript") ;hotkey used to toggle on/off of script.
HotKeySet("+^9", "SetProcessPriority")  ; ctrl+shift+9 — set priority for all instances of a named process
HotKeySet("^!+9", "LockProcessPriority") ; ctrl+alt+shift+9 — lock a specific PID's priority and auto-restore on drift
#EndRegion ;Includes/Options/Permissions/Hotkeys

#Region ;Variables/Logging
Global $sStringInstaller = "In the _CloserInstaller function and just terminated"
Global $taskcloseran = 0
Global $sProcesses[18] = ["taskhostw.exe", "TrustedInstaller.exe", "TiWorker.exe", "CompatTelRunner.exe", "VSSVC.exe", "msiexec.exe", "msedge.exe", "helppane.exe", "net.exe", "vmcompute.exe", "msedgewebview2.exe", "update.exe", "AggregatorHost.exe", "dllhost.exe", "TCPSVCS.EXE", "xgamehelper.exe", "xgamehelper.exe", "backgroundTaskHost.exe"] ;  list of processes to always close
Global $bScriptRunning = False ;Variable to track the script's running state
Global $iLastStopServices = TimerInit() ;Variable to track the last time _stopservicescustom() was called.
Global $iLastStopProcesses = TimerInit() ;Variable to track the last time _closeinstaller() was called.
Global $iconfile = "%HOMEDRIVE%\Users\mmuel\Documents\AutoIT\ff7.ico" ;update with whatever icon file .ico you prefer to use in systray
Global $iLogMaxAgeDays = 7
Global $sLogFile = @HomeDrive & "\login\closure_log.txt" ; FIX: Using @HomeDrive macro instead of environment variable for better reliability.
Global $iLogLevel = 2 ;0=Error,1=Info,2=Verbose
Global $bLogToConsole = True ; logtofile
Global Const $PROCESS_IDLE = 0   ; ProcessSetPriority: Idle — not defined in this AutoIt version's AutoItConstants.au3
Global $aPriorityWatchPIDs[0]    ; PIDs currently under priority watchdog
Global $aPriorityWatchTargets[0] ; Corresponding target AutoIt priority constants (0-5)
Global $aPriorityWatchNames[0]   ; Corresponding human-readable priority names
TraySetIcon($iconfile)

; --- FIX: RESTRUCTURED LOG INITIALIZATION ---
ConsoleWrite("DEBUG: Starting log initialization." & @CRLF)
ConsoleWrite("DEBUG: Log file path is: " & $sLogFile & @CRLF)

If Not FileExists($sLogFile) Then
	ConsoleWrite("DEBUG: Log file does not exist. Attempting to create." & @CRLF)
	Dim $sLogDir = StringRegExpReplace($sLogFile, "\\[^\\]+$", "") ;<-- FIXED
	DirCreate($sLogDir)
	If @error Then
		ConsoleWrite("FATAL ERROR: Could not create directory: " & $sLogDir & " (Error: " & @error & "). Script cannot continue logging." & @CRLF)
	Else
		ConsoleWrite("DEBUG: Directory exists or was created. Writing initial log entry directly." & @CRLF)
		Dim $sDateTime = _NowTime(12) & " " & @MDAY & "/" & @MON & "/" & @YEAR ;<-- FIXED
		Dim $sLogEntry = $sDateTime & " [System] Log file initialized" ;<-- FIXED
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

While 1  ;Keeps script running indefinitely.  Hotkeys determine which path the script heads
	Sleep(50)
WEnd

Func ToggleScript() ;handles the toggling on and off of script.  Eventually use this to handle halting the main loop instead.
	If $bScriptRunning Then
		_LogMessage("F1 pressed - Pausing script", "System", 1)
		; ConsoleWrite("F1 pressed - Pausing script" & @CRLF) ; FIX: Removed redundant ConsoleWrite
		MsgBox($MB_SYSTEMMODAL, "AutoIT Script", "Script paused!", 1)
		$bScriptRunning = False ;this exits this function
	Else
		_LogMessage("F1 pressed - Starting script", "System", 1)
		; ConsoleWrite("F1 pressed - Starting script" & @CRLF) ; FIX: Removed redundant ConsoleWrite
		MsgBox($MB_SYSTEMMODAL, "AutoIT Script", "Script started!", 1)
		$bScriptRunning = True
	EndIf

	While $bScriptRunning ;Loop indefinetly escaped by F1 hotkey
		If CheckElapsedTime($iLastStopProcesses, 2) Then ; Check if 3 seconds have passed since the last call of _stopservices
			_CloseInstaller() ;_CloseInstaller() terminates all the process names stored in $sProcesses[] array
			$iLastStopProcesses = TimerInit() ;Update $iLastStopServices with the current time for future timerdiff checks
		EndIf

		If CheckElapsedTime($iLastStopServices, 2) Then ; Check if 10 seconds have passed since the last call of _stopservices
			_stopservicescustom() ; call function that handles checking service status and stop them if running
			$iLastStopServices = TimerInit() ;Update $iLastStopServices with the current time for future timerdiff checks
		EndIf
		Sleep(500)
		_miscpopups()
	WEnd
EndFunc   ;==>ToggleScript

Func _CheckAndRotateLogFile($sPath, $iDaysMax)
	If FileExists($sPath) Then
		Local $aFileTime = FileGetTime($sPath, 0, 1)
		If IsArray($aFileTime) Then
			Local $iFileDate = _DateToDayValue($aFileTime[0], $aFileTime[1], $aFileTime[2])
			Local $iToday = _DateToDayValue(@YEAR, @MON, @MDAY)
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

Func _CloseInstaller() ; Handles closing of all the processes stored in the $sProcesses array
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

Func _stopservicescustom() ; Check if a service is running and stop it, then log the closure
	Local $iSuccess = 0, $iFailure = 0, $bActionTaken = False

	Local $aServiceNames = ["TrustedInstaller", "wuauserv", "UsoSvc", "DoSvc", "WaaSMedicSvc", "sppsvc"]

	For $i = 0 To UBound($aServiceNames) - 1
		If _ServiceRunning("", $aServiceNames[$i]) Then
			$bActionTaken = True
			Local $iResult = _stopservice("", $aServiceNames[$i])
			If $iResult = 1 Then
				$iSuccess += 1
				_LogMessage("Successfully stopped service: " & $aServiceNames[$i], "Service", 1)
			Else
				$iFailure += 1
				_LogMessage("Failed to stop service: " & $aServiceNames[$i] & " (Error: " & @error & ")", "Service", 0)
			EndIf
		EndIf
	Next

	; service manages Windows components, so it requires special handling
	; to ensure it terminates the service correctly.
	If _ServiceRunning("", "sppsvc") Then
		$bActionTaken = True
		Local $iResult2 = ProcessClose("sppsvc.exe")
		If $iResult2 = 1 Then
			$iSuccess += 1
			_LogMessage("Successfully stopped sppsvc process", "Service", 1)
		Else
			$iFailure += 1
			_LogMessage("Failed to stop sppsvc process (Error: " & @error & ")", "Service", 0)
		EndIf
	EndIf

	If $bActionTaken Then
		_LogMessage("Service stop summary - Success: " & $iSuccess & ", Failed: " & $iFailure, "Service", 1)
	EndIf
EndFunc   ;==>_stopservicescustom

Func _LogMessage($sMessage, $sType, $iLevel) ;describe what this achieves
	If $iLevel > $iLogLevel Then Return ; Skip if message level is higher than current log level
	Local $sDateTime = _NowTime(12) & " " & @MDAY & "/" & @MON & "/" & @YEAR
	Local $sLogEntry = @CRLF & $sDateTime & " [" & $sType & "] " & $sMessage

	; FIX: Added robust error checking for FileOpen
	Local $hFile = FileOpen($sLogFile, 1) ; Mode 1 = Append (write-only)
	If $hFile = -1 Then
		; DEBUG: This will now tell us exactly why it failed.
		ConsoleWrite("ERROR in _LogMessage: Could not open log file '" & $sLogFile & "' for writing. @error code = " & @error & @CRLF)
		Return
	EndIf

	FileWrite($hFile, $sLogEntry)
	FileClose($hFile)

	If $bLogToConsole Then     ; Console output if enabled
		ConsoleWrite($sLogEntry & @CRLF)
	EndIf
EndFunc   ;==>_LogMessage

Func _miscpopups() ; monitors if window exists and closes if true
	If WinExists("[CLASS:TPleaseRegisterForm]") Then
		ConsoleWrite("Closing AdVancedRenamer Popup" & @CRLF)
		WinClose("[CLASS:TPleaseRegisterForm]")
	ElseIf WinExists("This is an unregistered copy", "") Then
		WinClose("This is an unregistered copy", "")
		ConsoleWrite("Closing Sublime Popup" & @CRLF)
	EndIf
EndFunc   ;==>_miscpopups

Func CheckElapsedTime($iStartTime, $iInterval)  ;calc of time difference in ms to seconds
	Return TimerDiff($iStartTime) >= ($iInterval * 1000)
EndFunc   ;==>CheckElapsedTime

Func SetProcessPriority()
	Local $sProcessName = InputBox("Process Priority", "Enter process name:")
	If @error Then ; User pressed Cancel
		_LogMessage("Process priority setting cancelled by user (Process Name Input)", "ProcessPriority", 1)
		Return ; Exit function if user cancels
	EndIf
	If $sProcessName = "" Then ; User entered empty string
		_LogMessage("Process priority setting cancelled: Process name cannot be empty.", "ProcessPriority", 1)
		MsgBox($MB_SYSTEMMODAL, "Process Priority", "Process name cannot be empty.", 1)
		Return
	EndIf

	Local $sPriorityLevel = InputBox("Process Priority", "Select priority level:" & @CRLF & "1 - Below Normal" & @CRLF & "2 - Normal" & @CRLF & "3 - Above Normal")
	If @error Then ; User pressed Cancel
		_LogMessage("Process priority setting cancelled by user (Priority Level Input)", "ProcessPriority", 1)
		Return ; Exit if user cancels
	EndIf

	; Declare a variable to store the priority constant
	Local $iPriorityConst
	; Determine the priority level based on user input
	Switch $sPriorityLevel
		Case "1"
			$iPriorityConst = $PROCESS_BELOWNORMAL ; Set priority to Below Normal
		Case "2"
			$iPriorityConst = $PROCESS_NORMAL ; Set priority to Normal
		Case "3"
			$iPriorityConst = $PROCESS_ABOVENORMAL ; Set priority to Above Normal
		Case Else
			; Log an error message for invalid input
			_LogMessage("Invalid priority level entered: " & $sPriorityLevel, "ProcessPriority", 0)
			MsgBox($MB_SYSTEMMODAL, "Process Priority", "Invalid priority level. Please enter 1, 2, or 3.", 1)
			Return ; Exit if invalid input
	EndSwitch

	Local $aProcessList = ProcessList($sProcessName)
	If @error Or $aProcessList[0][0] = 0 Then ; Check for error or no processes found
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

	For $i = 1 To $aProcessList[0][0] ; Loop through each process in the list (skip header row)
		Local $iPID = $aProcessList[$i][1] ; Get the PID
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
	If $iFailureCount > 0 Then
		$sMsg &= @CRLF & "Failed to set priority for " & $iFailureCount & " instance(s). Check log for errors."
	EndIf
	MsgBox($MB_SYSTEMMODAL, "Process Priority", $sMsg, 1)

EndFunc   ;==>SetProcessPriority

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

	; Reject duplicate — each PID may only appear once in the watchlist
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

	; --- Step 4: Add to watchlist and register adlib if this is the first entry ---
	Local $bWasEmpty = (UBound($aPriorityWatchPIDs) = 0)
	_ArrayAdd($aPriorityWatchPIDs, $iPID)
	_ArrayAdd($aPriorityWatchTargets, $iPriorityConst)
	_ArrayAdd($aPriorityWatchNames, $sPriorityName)

	If $bWasEmpty Then AdlibRegister("_PriorityWatchdog", 10000)

	_TrayNotify("Watching PID " & $iPID & " -> " & $sPriorityName)
	_LogMessage("LockProcessPriority: Watchdog started — PID " & $iPID & " → " & $sPriorityName & " (" & UBound($aPriorityWatchPIDs) & " PID(s) now monitored)", "PriorityWatchdog", 1)

EndFunc   ;==>LockProcessPriority

Func _PriorityWatchdog()
	; Iterate backwards so _ArrayDelete does not shift unprocessed indices
	For $i = UBound($aPriorityWatchPIDs) - 1 To 0 Step -1
		Local $iPID          = $aPriorityWatchPIDs[$i]
		Local $iPriorityConst = $aPriorityWatchTargets[$i]
		Local $sPriorityName  = $aPriorityWatchNames[$i]

		; Check process existence first
		If Not ProcessExists($iPID) Then
			_ArrayDelete($aPriorityWatchPIDs, $i)
			_ArrayDelete($aPriorityWatchTargets, $i)
			_ArrayDelete($aPriorityWatchNames, $i)
			_TrayNotify("PID " & $iPID & " exited - watchdog stopped.")
			_LogMessage("_PriorityWatchdog: PID " & $iPID & " no longer exists. Removed from watchlist (" & UBound($aPriorityWatchPIDs) & " PID(s) remaining)", "PriorityWatchdog", 1)
			ContinueLoop
		EndIf

		; Read current priority via WinAPI
		Local $iCurrentConst = _GetProcessPriorityByPID($iPID)
		If $iCurrentConst = -1 Then
			; Could not read priority this tick — log and defer until next tick
			_LogMessage("_PriorityWatchdog: Could not read priority for PID " & $iPID & ". Deferring check to next tick.", "PriorityWatchdog", 0)
			ContinueLoop
		EndIf

		; Check for drift
		If $iCurrentConst <> $iPriorityConst Then
			Local $sCurrentName = _PriorityConstantToName($iCurrentConst)
			_LogMessage("_PriorityWatchdog: Priority drift on PID " & $iPID & " — detected " & $sCurrentName & ", expected " & $sPriorityName & ". Restoring.", "PriorityWatchdog", 1)

			; TOCTOU re-check before restore attempt
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

	; Unregister when watchlist is empty
	If UBound($aPriorityWatchPIDs) = 0 Then
		AdlibUnRegister("_PriorityWatchdog")
		_LogMessage("_PriorityWatchdog: Watchlist empty. AdlibRegister unregistered.", "PriorityWatchdog", 1)
	EndIf

EndFunc   ;==>_PriorityWatchdog

Func _GetProcessPriorityByPID($iPID)
	; Returns the current AutoIt priority constant (0-5) for the given PID.
	; Returns -1 on any failure.
	; Uses DllCall directly — bypasses _WinAPI_GetPriorityClass wrapper which propagates
	; unreliable @error values. PROCESS_QUERY_LIMITED_INFORMATION (0x1000) is sufficient
	; for GetPriorityClass and is granted by more process types than PROCESS_QUERY_INFORMATION.
	Local Const $PROCESS_QUERY_LIMITED_INFORMATION = 0x1000

	; Open process handle
	Local $aOpen = DllCall("kernel32.dll", "handle", "OpenProcess", "dword", $PROCESS_QUERY_LIMITED_INFORMATION, "bool", False, "dword", $iPID)
	If @error Or Not $aOpen[0] Then
		Local $iOpenWinErr = _WinAPI_GetLastError()
		_LogMessage("_GetProcessPriorityByPID: OpenProcess failed for PID " & $iPID & " (DllError: " & @error & ", WinError: " & $iOpenWinErr & ")", "PriorityWatchdog", 0)
		Return -1
	EndIf

	; Read priority class — capture @error and GetLastError before CloseHandle clears them
	Local $aResult    = DllCall("kernel32.dll", "dword", "GetPriorityClass", "handle", $aOpen[0])
	Local $iDllError  = @error
	Local $iWinError  = _WinAPI_GetLastError()
	DllCall("kernel32.dll", "bool", "CloseHandle", "handle", $aOpen[0])

	If $iDllError Or Not $aResult[0] Then
		_LogMessage("_GetProcessPriorityByPID: GetPriorityClass failed for PID " & $iPID & " (DllError: " & $iDllError & ", WinError: " & $iWinError & ")", "PriorityWatchdog", 0)
		Return -1
	EndIf

	Return _WinAPIPriorityClassToAutoItConst($aResult[0])

EndFunc   ;==>_GetProcessPriorityByPID

Func _WinAPIPriorityClassToAutoItConst($iWinAPIClass)
	; Maps Windows API PRIORITY_CLASS values to AutoIt ProcessSetPriority constants.
	; These are entirely different numbering schemes — this mapping is mandatory.
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
			Return -1 ; Unrecognised priority class
	EndSwitch
EndFunc   ;==>_WinAPIPriorityClassToAutoItConst

Func _PriorityConstantToName($iPriorityConst)
	; Maps AutoIt ProcessSetPriority constants to human-readable strings.
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

Func _TrayNotify($sMessage)
	; ToolTip produces a tiny native tooltip — no toast, no Action Center, no sound.
	; Positioned bottom-right near the system tray. Auto-clears after 3 seconds.
	ToolTip("[Priority Watchdog]" & @CRLF & $sMessage, @DesktopWidth - 260, @DesktopHeight - 80)
	AdlibRegister("_ClearTrayNotify", 3000)
EndFunc   ;==>_TrayNotify

Func _ClearTrayNotify()
	ToolTip("")
	AdlibUnRegister("_ClearTrayNotify")
EndFunc   ;==>_ClearTrayNotify

Func _exit()
	; FIX: Corrected bug where @CRLF was part of the type string and removed redundant ConsoleWrite
	_LogMessage("Script termination requested", "System", 1)
	_LogMessage("Script Was Terminated by _exit()", "System", 1)
	Exit
EndFunc   ;==>_exit
