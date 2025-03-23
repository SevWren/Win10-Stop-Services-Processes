#RequireAdmin
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=G:\Users\mmuel\OneDrive\Documents\AutoIT\ff7.ico
#AutoIt3Wrapper_Outfile=..\..\..\Desktop\Stop Services - Processes.Exe
#AutoIt3Wrapper_Compression=0
#AutoIt3Wrapper_Res_Description=Script monitors processes and services related to windows update and terminates if running.
#AutoIt3Wrapper_Res_Icon_Add=G:\Users\mmuel\OneDrive\Documents\AutoIT\ff7.ico
#AutoIt3Wrapper_Add_Constants=n
#AutoIt3Wrapper_AU3Check_Parameters=-q -d -w 1 -w 2 -w 3 -w 4
#AutoIt3Wrapper_ShowProgress=n
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#Region ;includes & autoit opt
#include <ServiceControl.au3>
#include "G:\Users\mmuel\OneDrive\Documents\GitHub\Au3_StopServices\Includes\CloseMyWindows.au3"
#include <MsgBoxConstants.au3>
#include <AutoItConstants.au3>
#include <Misc.au3>
#include <Date.au3>
#include <WinAPI.au3>
#include "MyProcessPriority.au3" ; Include the external file
Opt("TrayIconDebug", 1) ;0=no info, 1=debug line info
Opt("WinTitleMatchMode", 2)
#EndRegion ;includes & autoit opt

#Region ;Hotkeys
HotKeySet("{ScrollLock}{PAUSE}", "_exit")
HotKeySet("{F1}", "ToggleScript") ;hotkey used to toggle on/off of script
HotKeySet("^9", "SetProcessPriority") ;ctrl and 9 toggles function
#EndRegion ;Hotkeys

#Region ;Globals
Global $sStringInstaller = "In the _CloserInstaller function and just terminated"
Global $taskcloseran = 0
Global $sProcesses = ["taskhostw.exe", "TrustedInstaller.exe", "TiWorker.exe", "CompatTelRunner.exe", "VSSVC.exe", "msiexec.exe", "msedge.exe", "helppane.exe", "net.exe", "vmcompute.exe", "msedgewebview2.exe", "BraveCrashHandler.exe", "BraveCrashHandler64.exe"]
Global $bScriptRunning = False ; track the scripts running state
Global $iLastStopServices = TimerInit() ;track last time _stopservicescustom() was called.
Global $iLastStopProcesses = TimerInit() ;track last time _closeinstaller() was called.
Global $iconfile = @MyDocumentsDir & "\AutoIT\ff7.ico"
Global $sLogFile = @AppDataDir & "\StopServicesProcess\closure_log.txt"
Global $hFile = FileOpen($sLogFile, $FO_append + $FO_CREATEPATH) ;directory & file creation of $sLogfile, open in append mode
Global $bEnableAdvancedRenamer = 1 ; Variable to enable (1) or disable (0) the _AdvancedRenamer function by default

TraySetIcon($iconfile)
#EndRegion ;Globals

ConsoleWrite("Script Started" & @CRLF)
_LogTest("StopServicesProcesses.exe Launched.")

While 1  ;main loop. Hotkeys determine scripts functions
	Sleep(50)
WEnd

Func ToggleScript() ;toggling script on off.
	If $bScriptRunning Then
		MsgBox($MB_SYSTEMMODAL, "AutoIT Script", "Script paused!", 1)
		ConsoleWrite("Script Paused via F1 key" & @CRLF)
		_LogTest("Script Paused via F1 key")
		$bScriptRunning = False ;intended to return to main while loop
	Else
		MsgBox($MB_SYSTEMMODAL, "AutoIT Script", "Script started!", 1)
		ConsoleWrite("Script Started via F1 key" & @CRLF)
		_LogTest("Script Started via F1 key")
		$bScriptRunning = True
	EndIf

	While $bScriptRunning  ;Loop indefinetly until F1 hotkey
		If CheckElapsedTime($iLastStopProcesses, 2) Then ; Check if 3 seconds passed since the call of _stopservices
			_CloseInstaller() ;terminates process names stored in $sProcesses[]
			$iLastStopProcesses = TimerInit() ; Update timestamp for next process check interval
		EndIf

		If CheckElapsedTime($iLastStopServices, 2) Then ; Check if 2 seconds passed since last call of _stopservices
			_stopservicescustom() ; call func handles service status checks and stops if running
			$iLastStopServices = TimerInit() ; Update timestamp for next service check interval
		EndIf

		If $bEnableAdvancedRenamer Then
			_CloseMyWindows()
		EndIf

		Sleep(500)
	WEnd
EndFunc   ;==>ToggleScript


Func _CloseInstaller() ; Handles closing of all the processes stored in the $sProcesses array
	For $i = 0 To UBound($sProcesses) - 1 ; Loop that is determined on the total number of rows in $sProcesses array
		If ProcessExists($sProcesses[$i]) Then ; If value in array is valid then
			ProcessClose($sProcesses[$i]) ; Close the process stored in the current row $i of the $sProcesses array
			LogClosure($sProcesses[$i], "Process") ; Log the process closure
		EndIf
	Next ; Continue loop
EndFunc   ;==>_CloseInstaller

Func _stopservicescustom() ; Check if a service is running and stop it, then log the closure
	; Run cmd prompt and pass net stop commands and set cmd prompt to hidden
	Local $bServiceStopped = False
	Local $aServiceNames = ["TrustedInstaller", "wuauserv", "UsoSvc", "DoSvc", "WaaSMedicSvc"] ;windows 10 service names

	For $i = 0 To UBound($aServiceNames) - 1
		If _ServiceRunning("", $aServiceNames[$i]) Then
			_stopservice("", $aServiceNames[$i])
			; Set the flag to indicate that a service was stopped
			$bServiceStopped = True
			LogClosure($aServiceNames[$i], "Service") ;log service closed for each instance in the loop
		EndIf
	Next

	; Special handling for sppsvc service as it requires ProcessClose
	If _ServiceRunning("", "sppsvc") Then
		ProcessClose("sppsvc.exe")
		$bServiceStopped = True
		LogClosure("sppsvc", "Service")
	EndIf
EndFunc   ;==>_stopservicescustom

Func LogClosure($sName, $sType) ; Function to log the date and time of closure
	Local $sDateTime = _NowTime(12) & " " & @MON & "/" & @MDAY & "/" & @YEAR ; Get the current date and time
	Local $sLogEntry = $sDateTime & " - " & $sType & " '" & $sName & "' was closed." & @CRLF ; Create the log entry
	FileWrite($sLogFile, $sLogEntry)
EndFunc   ;==>LogClosure

Func _LogTest($sLogEntry) ;writes $sLogEntry data to file
	Local $sDateTime = _NowTime(12) & " " & @MON & "/" & @MDAY & "/" & @YEAR ; Get the current date and time
	FileWrite($sLogFile, $sDateTime & " " & $sLogEntry & @CRLF)
EndFunc   ;==>_LogTest

Func CheckElapsedTime($iStartTime, $iInterval)  ;handles the calculation of time difference in ms to seconds
	Return TimerDiff($iStartTime) >= ($iInterval * 1000)
EndFunc   ;==>CheckElapsedTime

Func _exit() ;handle exiting script and logging before exit
	_LogTest("Script Was Terminated by _exit()")
	_LogTest("Exiting Script via Scroll Lock and Pause/Break hotkey.")
	FileClose($sLogFile)
	ConsoleWrite("Exiting Script via Scroll Lock and Pause/Break hotkey.")
	Exit
EndFunc   ;==>_exit