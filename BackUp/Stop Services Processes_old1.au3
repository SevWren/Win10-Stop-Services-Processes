#RequireAdmin
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=G:\Users\mmuel\OneDrive\Documents\AutoIT\ff7.ico
#AutoIt3Wrapper_Outfile=..\..\Desktop\Stop Services - Processes_Server.Exe
#AutoIt3Wrapper_Compression=0
#AutoIt3Wrapper_Res_Description=Script monitors processes and services related to windows update and terminates if running.
#AutoIt3Wrapper_Res_Icon_Add=G:\Users\mmuel\OneDrive\Documents\AutoIT\ff7.ico
#AutoIt3Wrapper_Add_Constants=n
#AutoIt3Wrapper_AU3Check_Parameters=-q -d -w 1 -w 2 -w 3 -w 4
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_ShowProgress=Y
#Region ;Includes/Options/Permissions/Hotkeys
#include <ServiceControl.au3>
#include <MsgBoxConstants.au3>
#include <AutoItConstants.au3>
#include <Misc.au3>
#include <Date.au3>
Opt("TrayIconDebug", 1) ;0=no info, 1=debug line info
Opt("WinTitleMatchMode", 2)
HotKeySet("{ScrollLock}{PAUSE}", "_exit")
HotKeySet("{F1}", "ToggleScript") ;hotkey used to toggle on/off of script
TraySetIcon("G:\Users\mmuel\OneDrive\Documents\AutoIT\ff7.ico")
TraySetIcon($iconfile)
#EndRegion ;Includes/Options/Permissions/Hotkeys

#Region ;Globals
Global $sStringInstaller = "In the _CloserInstaller function and just terminated"
Global $taskcloseran = 0
Global $sProcesses[11] = ["taskhostw.exe", "TrustedInstaller.exe", "TiWorker.exe", "CompatTelRunner.exe", "VSSVC.exe", "msiexec.exe", "msedge.exe", "helppane.exe", "net.exe", "vmcompute.exe", "msedgewebview2.exe"] ;list of processes to always close
Global $bScriptRunning = False ; Variable to track the script's running state
Global $iLastStopServices = TimerInit() ;Variable to track the last time _stopservicescustom() was called.
Global $iLastStopProcesses = TimerInit() ;Variable to track the last time _closeinstaller() was called.
Global $iconfile = "G:\Users\mmuel\OneDrive\Documents\AutoIT\ff7.ico"
Global $sLogFile = "G:\login\closure_log.txt"
TraySetIcon($iconfile)
#EndRegion ;Globals

While 1  ;Keeps script running indefinitely.  Hotkeys determine which path the script heads
	Sleep(50)
WEnd

Func ToggleScript() ;handles the toggling on and off of script.  Eventually use this to handle halting the main loop instead.
	If $bScriptRunning Then
		MsgBox($MB_SYSTEMMODAL, "AutoIT Script", "Script paused!", 1)
		$bScriptRunning = False ;this exits this function
	Else
		MsgBox($MB_SYSTEMMODAL, "AutoIT Script", "Script started!", 1)
		$bScriptRunning = True
	EndIf

	While $bScriptRunning  ;Loop indefinetly escaped by F1 hotkey
		If CheckElapsedTime($iLastStopProcesses, 2) Then ; Check if 3 seconds have passed since the last call of _stopservices
			_CloseInstaller() ;_CloseInstaller() terminates all the process names stored in $sProcesses[] array
			$iLastStopProcesses = TimerInit() ;Update $iLastStopServices with the current time for future timerdiff checks
		EndIf

		If CheckElapsedTime($iLastStopServices, 2) Then ; Check if 10 seconds have passed since the last call of _stopservices
			_stopservicescustom() ; call function that handles checking service status and stop them if running
			$iLastStopServices = TimerInit() ;Update $iLastStopServices with the current time for future timerdiff checks
		EndIf
		Sleep(500)
		_AdvancedRenamer()
	WEnd
EndFunc   ;==>ToggleScript

Func _CloseInstaller() ; Handles closing of all the processes stored in the $sProcesses array
	For $i = 0 To UBound($sProcesses) - 1 ; Loop that is determined on the total number of rows in $sProcesses array
		If ProcessExists($sProcesses[$i]) Then ; If value in array is valid then
			ProcessClose($sProcesses[$i]) ; Close the process stored in the current row $i of the $sProcesses array
			; Log the process closure
			LogClosure($sProcesses[$i], "Process")
		EndIf
	Next ; Continue loop
EndFunc   ;==>_CloseInstaller

Func _stopservicescustom() ; Check if a service is running and stop it, then log the closure
	; Run cmd prompt and pass net stop commands and set cmd prompt to hidden
	Local $bServiceStopped = False

	; Define an array of service names
	Local $aServiceNames = ["TrustedInstaller", "wuauserv", "UsoSvc", "DoSvc", "WaaSMedicSvc", "sppsvc"]

	; Loop through each service name in the array
	For $i = 0 To UBound($aServiceNames) - 1
		; Check if the service is running
		If _ServiceRunning("", $aServiceNames[$i]) Then
			; Stop the service
			_stopservice("", $aServiceNames[$i])
			; Set the flag to indicate that a service was stopped
			$bServiceStopped = True
			; Log the service closure
			LogClosure($aServiceNames[$i], "Service")
		EndIf
	Next

	; Special handling for sppsvc service as it requires ProcessClose
	If _ServiceRunning("", "sppsvc") Then
		ProcessClose("sppsvc.exe")
		$bServiceStopped = True
		; Log the service closure
		LogClosure("sppsvc", "Service")
	EndIf
EndFunc   ;==>_stopservicescustom

Func LogClosure($sName, $sType) ; Function to log the date and time of closure
	Local $sDateTime = _NowTime(12) & " " & @MDAY & "/" & @MON & "/" & @YEAR      ; Get the current date and time
	Local $sLogEntry = @CRLF & $sDateTime & " - " & $sType & " '" & $sName & "' was closed." & @CRLF ; Create the log entry
	FileWrite($sLogFile, $sLogEntry)
EndFunc   ;==>LogClosure

Func CheckElapsedTime($iStartTime, $iInterval)  ;handles the calculation of time difference in ms to seconds
	Return TimerDiff($iStartTime) >= ($iInterval * 1000)
EndFunc   ;==>CheckElapsedTime

Func _LogTest($sLogEntry) ;writes $sLogEntry data to file
	FileWrite($sLogFile, $sLogEntry)
EndFunc   ;==>_LogTest

Func _exit()
	Local $sDateTime = _NowTime(12) & " " & @MDAY & "/" & @MON & "/" & @YEAR ;Get the current date and time
	Local $sLogEntry = @CRLF & $sDateTime & " - " & "Script Was Terminated by _exit()" & @CRLF ; Create the log entry
	FileWrite($sLogFile, $sLogEntry) ; Write the log entry to the log file
	Exit
EndFunc   ;==>_exit

Func _AdvancedRenamer()
	If WinExists("[CLASS:TPleaseRegisterForm]") Then
		ConsoleWrite("In _AdvancedRenamer function" & @CRLF)
		ConsoleWrite("Passed check, closing window" & @CRLF)
		WinClose("[CLASS:TPleaseRegisterForm]")
	EndIf
EndFunc   ;==>_AdvancedRenamer