#RequireAdmin
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=ff7.ico
#AutoIt3Wrapper_Outfile_x64=..\..\..\Users\mmuel\Desktop\Stop Services - Processes.Exe
#AutoIt3Wrapper_Compression=0
#AutoIt3Wrapper_Compile_Both=y
#AutoIt3Wrapper_UseX64=y
#AutoIt3Wrapper_Res_Description=Script monitors processes and services related to windows update and terminates if running.
#AutoIt3Wrapper_Res_Icon_Add=C:\github\my-github-info\Win10-Stop-Services-Processes\ff7.ico
#AutoIt3Wrapper_AU3Check_Parameters=-q -d -w 1 -w 2 -w 3 -w 4
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_ShowProgress=Y

#Region ;Includes/Options/Permissions
; This project must use the script's working directory instead of a fixed local path.
;~ #include-once
#include "Includes\ServiceControl.au3"
#include <MsgBoxConstants.au3>
#include <AutoItConstants.au3>
#include <Misc.au3>
#include <Date.au3>
#include <WinAPI.au3>
#include <WinAPIProc.au3>
#include <Array.au3>
Opt("TrayIconDebug", 1)
Opt("WinTitleMatchMode", 2)
#EndRegion ;Includes/Options/Permissions/Hotkeys

#Region ;hotkeys
HotKeySet("{ScrollLock}{PAUSE}", "_exit")
HotKeySet("+{F1}", "ToggleScript")
HotKeySet("+^9", "SetProcessPriority")
HotKeySet("^!+9", "LockProcessPriority")
#EndRegion

#Region ;Variables/Logging
Global $iLastStopProcesses = TimerInit()
Global $iLastStopServices = TimerInit()
Global $sStringInstaller = "In the _CloserInstaller function and just terminated"
Global $taskcloseran = 0
Global $sProcesses[18] = ["taskhostw.exe", "TrustedInstaller.exe", "TiWorker.exe", "CompatTelRunner.exe", "VSSVC.exe", "msiexec.exe", "msedge.exe", "helppane.exe", "net.exe", "vmcompute.exe", "msedgewebview2.exe", "update.exe", "AggregatorHost.exe", "dllhost.exe", "TCPSVCS.EXE", "xgamehelper.exe", "backgroundTaskHost.exe", "TrustedInstaller.exe"]
Global $bScriptRunning = False
Global $iconfile = @ScriptDir & "\ff7.ico"

Global $iLogMaxAgeDays = 7
Global $sLogFile = @HomeDrive & "\login\closure_log.txt"
Global $iLogLevel = 2
Global $bLogToConsole = True
Global Const $PROCESS_IDLE = 0
Global $aPriorityWatchPIDs[0]
Global $aPriorityWatchTargets[0]
Global $aPriorityWatchNames[0]
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

While 1
	Sleep(50)
WEnd

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

	While $bScriptRunning
		If CheckElapsedTime($iLastStopProcesses, 2) Then
			_CloseInstaller()
			$iLastStopProcesses = TimerInit()
		EndIf

		If CheckElapsedTime($iLastStopServices, 2) Then
			_stopservicescustom()
			$iLastStopServices = TimerInit()
		EndIf
		Sleep(500)
		_miscpopups()
	WEnd
EndFunc

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
EndFunc

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
EndFunc

Func _stopservicescustom()
	Local $iSuccess = 0, $iFailure = 0, $bActionTaken = False
	Local $aServiceNames = ["TrustedInstaller", "wuauserv", "UsoSvc", "DoSvc", "WaaSMedicSvc", "sppsvc", "LanmanServer", "stisvc"]

	For $i = 0 To UBound($aServiceNames) - 1
		Local $sService = $aServiceNames[$i]
		If _ServiceRunning("", $sService) Then
			$bActionTaken = True
			Local $iResult = _StopService("", $sService)
			If $iResult = 1 Then
				$iSuccess += 1
				_LogMessage("Successfully stopped service: " & $sService, "Service", 1)
			Else
				$iFailure += 1
				_LogMessage("Failed to stop service: " & $sService & " (Error: " & @error & ")", "Service", 0)
			EndIf
		Else
			_LogMessage("Service not running or status check failed: " & $sService, "Service", 1)
		EndIf
	Next

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
EndFunc

Func _LogMessage($sMessage, $sType, $iLevel)
	If $iLevel > $iLogLevel Then Return
	Local $sDateTime = _NowTime(12) & " " & @MDAY & "/" & @MON & "/" & @YEAR
	Local $sLogEntry = @CRLF & $sDateTime & " [" & $sType & "] " & $sMessage
	Local $hFile = FileOpen($sLogFile, 1)
	If $hFile = -1 Then
		ConsoleWrite("ERROR in _LogMessage: Could not open log file '" & $sLogFile & "' for writing. @error code = " & @error & @CRLF)
		Return
	EndIf

	FileWrite($hFile, $sLogEntry)
	FileClose($hFile)

	If $bLogToConsole Then
		ConsoleWrite($sLogEntry & @CRLF)
	EndIf
EndFunc

Func CheckElapsedTime($iStartTime, $iInterval)
	Return TimerDiff($iStartTime) >= ($iInterval * 1000)
EndFunc

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
	If $iFailureCount > 0 Then
		$sMsg &= @CRLF & "Failed to set priority for " & $iFailureCount & " instance(s). Check log for errors."
	EndIf
	MsgBox($MB_SYSTEMMODAL, "Process Priority", $sMsg, 1)
EndFunc

Func LockProcessPriority()
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

	For $i = 0 To UBound($aPriorityWatchPIDs) - 1
		If $aPriorityWatchPIDs[$i] = $iPID Then
			_TrayNotify("PID " & $iPID & " is already being monitored.")
			_LogMessage("LockProcessPriority: PID " & $iPID & " is already in the watchlist.", "PriorityWatchdog", 1)
			Return
		EndIf
	Next

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

	Local $bWasEmpty = (UBound($aPriorityWatchPIDs) = 0)
	_ArrayAdd($aPriorityWatchPIDs, $iPID)
	_ArrayAdd($aPriorityWatchTargets, $iPriorityConst)
	_ArrayAdd($aPriorityWatchNames, $sPriorityName)

	If $bWasEmpty Then AdlibRegister("_PriorityWatchdog", 10000)

	_TrayNotify("Watching PID " & $iPID & " -> " & $sPriorityName)
	_LogMessage("LockProcessPriority: Watchdog started — PID " & $iPID & " → " & $sPriorityName & " (" & UBound($aPriorityWatchPIDs) & " PID(s) now monitored)", "PriorityWatchdog", 1)
EndFunc

Func _PriorityWatchdog()
	For $i = UBound($aPriorityWatchPIDs) - 1 To 0 Step -1
		Local $iPID = $aPriorityWatchPIDs[$i]
		Local $iPriorityConst = $aPriorityWatchTargets[$i]
		Local $sPriorityName = $aPriorityWatchNames[$i]

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
		_LogMessage("_PriorityWatchdog: Watchlist empty. AdlibRegister unregistered.", "PriorityWatchdog", 1)
	EndIf
EndFunc

Func _GetProcessPriorityByPID($iPID)
	Local Const $PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
	Local $aOpen = DllCall("kernel32.dll", "handle", "OpenProcess", "dword", $PROCESS_QUERY_LIMITED_INFORMATION, "bool", False, "dword", $iPID)
	If @error Or Not $aOpen[0] Then
		Local $iOpenWinErr = _WinAPI_GetLastError()
		_LogMessage("_GetProcessPriorityByPID: OpenProcess failed for PID " & $iPID & " (DllError: " & @error & ", WinError: " & $iOpenWinErr & ")", "PriorityWatchdog", 0)
		Return -1
	EndIf

	Local $aResult = DllCall("kernel32.dll", "dword", "GetPriorityClass", "handle", $aOpen[0])
	Local $iDllError = @error
	Local $iWinError = _WinAPI_GetLastError()
	DllCall("kernel32.dll", "bool", "CloseHandle", "handle", $aOpen[0])

	If $iDllError Or Not $aResult[0] Then
		_LogMessage("_GetProcessPriorityByPID: GetPriorityClass failed for PID " & $iPID & " (DllError: " & $iDllError & ", WinError: " & $iWinError & ")", "PriorityWatchdog", 0)
		Return -1
	EndIf

	Return _WinAPIPriorityClassToAutoItConst($aResult[0])
EndFunc

Func _WinAPIPriorityClassToAutoItConst($iWinAPIClass)
	Switch $iWinAPIClass
		Case $IDLE_PRIORITY_CLASS
			Return $PROCESS_IDLE
		Case $BELOW_NORMAL_PRIORITY_CLASS
			Return $PROCESS_BELOWNORMAL
		Case $NORMAL_PRIORITY_CLASS
			Return $PROCESS_NORMAL
		Case $ABOVE_NORMAL_PRIORITY_CLASS
			Return $PROCESS_ABOVENORMAL
		Case $HIGH_PRIORITY_CLASS
			Return $PROCESS_HIGH
		Case $REALTIME_PRIORITY_CLASS
			Return $PROCESS_REALTIME
		Case Else
			Return -1
	EndSwitch
EndFunc

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
EndFunc

#Region ;traytips
Func _TrayNotify($sMessage)
	ToolTip("[Priority Watchdog]" & @CRLF & $sMessage, @DesktopWidth - 260, @DesktopHeight - 80)
	AdlibRegister("_ClearTrayNotify", 2000)
EndFunc

Func _ClearTrayNotify()
	ToolTip("")
	AdlibUnRegister("_ClearTrayNotify")
EndFunc
#EndRegion

Func _miscpopups()
	If WinExists("[CLASS:TPleaseRegisterForm]") Then
		ConsoleWrite("Closing AdVancedRenamer Popup" & @CRLF)
		WinClose("[CLASS:TPleaseRegisterForm]")
	ElseIf WinExists("This is an unregistered copy", "") Then
		WinClose("This is an unregistered copy", "")
		ConsoleWrite("Closing Sublime Popup" & @CRLF)
	EndIf
EndFunc

Func _exit()
	_LogMessage("Script termination requested", "System", 1)
	_LogMessage("Script Was Terminated by _exit()", "System", 1)
	Exit
EndFunc
