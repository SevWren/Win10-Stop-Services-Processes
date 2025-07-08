#RequireAdmin
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Compression=0
#AutoIt3Wrapper_Res_Description=Script monitors processes and services related to windows update and terminates if running.
#AutoIt3Wrapper_Add_Constants=n
#AutoIt3Wrapper_AU3Check_Parameters=-q -d -w 1 -w 2 -w 3 -w 4
#AutoIt3Wrapper_ShowProgress=Y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#Region ;Includes/Options/Permissions/Hotkeys

;This is the ServiceControlAu3 library included in the repo
#include "C:\Users\mmuel\Documents\GitHub\Win10-Stop-Services-Processes\Includes\ServiceControl.au3"

;Standard AU3 library Locations with AutoIT  Program Files (x86)\AutoIt3\Include
#include <MsgBoxConstants.au3>
#include <AutoItConstants.au3>
#include <Misc.au3>
#include <Date.au3>
Opt("TrayIconDebug", 1) ;0=no info, 1=debug line info
Opt("WinTitleMatchMode", 2)
HotKeySet("{ScrollLock}{PAUSE}", "_exit")
HotKeySet("+{F1}", "ToggleScript") ;hotkey used to toggle on/off of script.
HotKeySet("+^9", "SetProcessPriority") ;ctrl/shift/9 hotkey for setting all instances of a process's priority
#EndRegion ;Includes/Options/Permissions/Hotkeys

#Region ;Variables/Logging
Global $sStringInstaller = "In the _CloserInstaller function and just terminated"
Global $taskcloseran = 0
Global $sProcesses[11] = ["taskhostw.exe", "TrustedInstaller.exe", "TiWorker.exe", "CompatTelRunner.exe", "VSSVC.exe", "msiexec.exe", "msedge.exe", "helppane.exe", "net.exe", "vmcompute.exe", "msedgewebview2.exe"] ;list of processes to always close
Global $bScriptRunning = False ; Variable to track the script's running state
Global $iLastStopServices = TimerInit() ;Variable to track the last time _stopservicescustom() was called.
Global $iLastStopProcesses = TimerInit() ;Variable to track the last time _closeinstaller() was called.
Global $iconfile = "%HOMEDRIVE%\Users\mmuel\Documents\AutoIT\ff7.ico" ;update with whatever icon file .ico you prefer to use in systray
Global $iLogMaxAgeDays = 7
Global $sLogFile = @HomeDrive & "\login\closure_log.txt" ; FIX: Using @HomeDrive macro instead of environment variable for better reliability.
Global $iLogLevel = 2 ; 0=Errors only, 1=Basic logging, 2=Detailed logging
Global $bLogToConsole = True ; Enable console logging alongside file logging
TraySetIcon($iconfile)

; --- FIX: RESTRUCTURED LOG INITIALIZATION ---
ConsoleWrite("DEBUG: Starting log initialization." & @CRLF)
ConsoleWrite("DEBUG: Log file path is: " & $sLogFile & @CRLF)

If Not FileExists($sLogFile) Then
	ConsoleWrite("DEBUG: Log file does not exist. Attempting to create." & @CRLF)
	Local $sLogDir = StringRegExpReplace($sLogFile, "\\[^\\]+$", "")
	DirCreate($sLogDir)
	If @error Then
		ConsoleWrite("FATAL ERROR: Could not create directory: " & $sLogDir & " (Error: " & @error & "). Script cannot continue logging." & @CRLF)
	Else
		ConsoleWrite("DEBUG: Directory exists or was created. Writing initial log entry directly." & @CRLF)
		; FIX: Use a direct FileWrite for initialization to avoid the "chicken and egg" paradox.
		Local $sDateTime = _NowTime(12) & " " & @MDAY & "/" & @MON & "/" & @YEAR
		Local $sLogEntry = $sDateTime & " [System] Log file initialized"
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
; --- END FIX ---
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

Func _exit()
	; FIX: Corrected bug where @CRLF was part of the type string and removed redundant ConsoleWrite
	_LogMessage("Script termination requested", "System", 1)
	_LogMessage("Script Was Terminated by _exit()", "System", 1)
	Exit
EndFunc   ;==>_exit

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