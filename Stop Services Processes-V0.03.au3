#RequireAdmin
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=G:\Users\mmuel\OneDrive\Documents\AutoIT\ff7.ico
#AutoIt3Wrapper_Outfile=..\..\..\..\..\..\login\Stop Services - Processes.Exe
#AutoIt3Wrapper_Compression=0
#AutoIt3Wrapper_Res_Description=Script monitors processes and services related to windows update and terminates if running.
#AutoIt3Wrapper_Res_Icon_Add=G:\Users\mmuel\OneDrive\Documents\AutoIT\ff7.ico
#AutoIt3Wrapper_AU3Check_Parameters=-q -d -w 1 -w 2 -w 3 -w 4
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
; These directives configure compilation settings such as the output file, icon, and description.
; Adjust these settings based on the deployment environment or specific requirements.
#AutoIt3Wrapper_ShowProgress=Y

#Region ;Includes/Options/Permissions/Hotkeys
; Include libraries for service control, message boxes, constants, miscellaneous functions, and date handling.
#include <ServiceControl.au3>
#include <MsgBoxConstants.au3>
#include <AutoItConstants.au3>
#include <Misc.au3>
#include <Date.au3>

; Set script options:
; - TrayIconDebug: Enable debug info in the tray icon (1 = enabled).
; - WinTitleMatchMode: Set to 2 for partial window title matching.
Opt("TrayIconDebug", 1) ; 0=no info, 1=debug line info
Opt("WinTitleMatchMode", 2)

; Define hotkeys:
; - ScrollLock + Pause: Exit the script.
; - F1: Toggle the script's running state.
HotKeySet("{ScrollLock}{PAUSE}", "_exit")
HotKeySet("{F1}", "ToggleScript")
#EndRegion ;Includes/Options/Permissions/Hotkeys

#Region ;Globals
; Declare global variables with descriptions:
; - $sStringInstaller: String used in logging process closure messages.
; - $taskcloseran: Counter or flag (consider renaming for clarity, e.g., $iTaskCloseCount).
; - $sProcesses: Array of process names to monitor and close.
; - $bScriptRunning: Boolean flag to control the script's active state.
; - $iLastStopServices: Timer for the last service stop action.
; - $iLastStopProcesses: Timer for the last process closure action.
; - $iconfile: Path to the tray icon file.
; - $sLogFile: Path to the log file for recording actions.
; - $iLogLevel: Log verbosity (0=Errors only, 1=Basic, 2=Detailed).
; - $iLevel: Default log level for messages (consider renaming to avoid confusion with $iLogLevel).
; - $bLogToConsole: Boolean to enable console output alongside file logging.
Global $sStringInstaller = "In the _CloserInstaller function and just terminated"
Global $taskcloseran = 0
Global $sProcesses[11] = ["taskhostw.exe", "TrustedInstaller.exe", "TiWorker.exe", "CompatTelRunner.exe", "VSSVC.exe", "msiexec.exe", "msedge.exe", "helppane.exe", "net.exe", "vmcompute.exe", "msedgewebview2.exe"]
Global $bScriptRunning = False
Global $iLastStopServices = TimerInit()
Global $iLastStopProcesses = TimerInit()
Global $iconfile = "G:\Users\mmuel\OneDrive\Documents\AutoIT\ff7.ico"
Global $sLogFile = "G:\login\closure_log.txt"
Global $iLogLevel = 2 ; 0=Errors only, 1=Basic logging, 2=Detailed logging
Global $iLevel = 1    ; Default log level for messages
Global $bLogToConsole = True
TraySetIcon($iconfile) ; Set the tray icon using the specified file
If Not FileExists($sLogFile) Then ; Initialize logging: Create the log directory if it doesn’t exist
	DirCreate(StringRegExpReplace($sLogFile, "\\[^\\]+$", ""))
	_LogMessage("Log file initialized", "System", 1)
EndIf
#EndRegion ;Globals

; Log the start of the script to track initialization
_LogMessage("Script started", "System", 1)

; Main loop: Runs indefinitely, waiting for hotkey triggers
While 1
	Sleep(50) ; Small delay to reduce CPU usage
WEnd


Func ToggleScript() ;Toggle the script’s active state with F1 key
	If $bScriptRunning Then
		_LogMessage("F1 pressed - Pausing script", "System", 1)
		MsgBox($MB_SYSTEMMODAL, "AutoIT Script", "Script paused!", 1)
		$bScriptRunning = False
	Else
		_LogMessage("F1 pressed - Starting script", "System", 1)
		MsgBox($MB_SYSTEMMODAL, "AutoIT Script", "Script started!", 1)
		$bScriptRunning = True
	EndIf

	While $bScriptRunning ; Inner loop: Executes while the script is active
		If CheckElapsedTime($iLastStopProcesses, 2) Then ; Check processes every 2 seconds
			_CloseInstaller()
			$iLastStopProcesses = TimerInit()
		EndIf
		If CheckElapsedTime($iLastStopServices, 2) Then 		; Check services every 2 seconds
			_stopservicescustom()
			$iLastStopServices = TimerInit()
		EndIf
		Sleep(500) ; Brief pause between checks
		_AdvancedRenamer() ; Handle specific window closure
	WEnd
EndFunc   ;==>ToggleScript


Func _CloseInstaller() ;Close specified processes listed in $sProcesses
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


Func _stopservicescustom() ;Stop specified services and handle sppsvc process separately
	Local $iSuccess = 0, $iFailure = 0, $bActionTaken = False, $iResult
	Local $aServiceNames = ["TrustedInstaller", "wuauserv", "UsoSvc", "DoSvc", "WaaSMedicSvc", "sppsvc"]
	For $i = 0 To UBound($aServiceNames) - 1 ; Attempt to stop each service if it’s running
		If _ServiceRunning("", $aServiceNames[$i]) Then
			$bActionTaken = True
			$iResult = _stopservice("", $aServiceNames[$i])
			If $iResult = 1 Then
				$iSuccess += 1
				_LogMessage("Successfully stopped service: " & $aServiceNames[$i], "Service", 1)
			Else
				$iFailure += 1
				_LogMessage("Failed to stop service: " & $aServiceNames[$i] & " (Error: " & @error & ")", "Service", 0)
			EndIf
		EndIf
	Next
	If _ServiceRunning("", "sppsvc") Then ;Special handling for sppsvc: Close its process if the service is active
		$bActionTaken = True
		$iResult = ProcessClose("sppsvc.exe")
		If $iResult = 1 Then
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


Func _LogMessage($sMessage, $sType, $iLevel);Log messages to a file and optionally to the console
	If $iLevel > $iLogLevel Then Return
	Local $sDateTime = _NowTime(12) & " " & @MDAY & "/" & @MON & "/" & @YEAR
	Local $sLogEntry = @CRLF & $sDateTime & " [" & $sType & "] " & $sMessage
	Local $hFile = FileOpen($sLogFile, 1)
	If $hFile = -1 Then
		ConsoleWrite("Error: Could not open log file for writing" & @CRLF)
		Return
	EndIf
	FileWrite($hFile, $sLogEntry)
	FileClose($hFile)
	If $bLogToConsole Then
		ConsoleWrite($sLogEntry & @CRLF)
	EndIf
EndFunc   ;==>_LogMessage

Func _exit() ;Handle script termination with logging
	_LogMessage("Script termination requested", "System", 1)
	_LogMessage("Script Was Terminated by _exit()", "System", 1)
	Exit
EndFunc   ;==>_exit

Func _AdvancedRenamer() ;Close window if it exists
	If WinExists("[CLASS:TPleaseRegisterForm]") Then
		WinClose("[CLASS:TPleaseRegisterForm]")
		_LogMessage("Closed Advanced Renamer registration window", "Window", 1)
	EndIf
EndFunc   ;==>_AdvancedRenamer

Func CheckElapsedTime($iStartTime, $iInterval);Check if a specified time interval(in seconds)has elapsed
	Return TimerDiff($iStartTime) >= ($iInterval * 1000)
EndFunc   ;==>CheckElapsedTime

#comments-start
; Script Logic Overview:
; - Purpose: This script monitors and manages specific Windows services and processes, primarily to control or prevent Windows update-related activities.
; - Hotkeys:
;   - F1: Toggles the script between active and paused states.
;   - ScrollLock + Pause: Exits the script.
; - Behavior: When active, it checks every 2 seconds to:
;   - Close processes listed in $sProcesses (e.g., TrustedInstaller.exe, msiexec.exe).
;   - Stop services listed in _stopservicescustom() (e.g., wuauserv, sppsvc).
;   - Close a specific window ("Advanced Renamer" registration prompt).
; - Logging: Actions and errors are logged to a file ($sLogFile) and optionally to the console, with configurable log levels (0=Errors, 1=Basic, 2=Detailed).
; - Loop: Runs indefinitely in the background, waiting for hotkey inputs.

; Notes on Changes and Scheduled Task Behavior:
; - File Paths: Absolute paths are used (e.g., $sLogFile = "G:\login\closure_log.txt", $iconfile = "G:\Users\mmuel\OneDrive\Documents\AutoIT\ff7.ico"). Ensure these paths are accessible from the scheduled task’s execution context.
; - Working Directory: When run via a scheduled task at login, the working directory might default to the desktop or system directory (e.g., C:\Windows\System32) instead of G:\login. Use absolute paths for all file operations to prevent issues.
; - Permissions: The script requires admin privileges (#RequireAdmin) to stop services and close processes. Ensure the scheduled task is configured to "Run with highest privileges."
; - User Context: If the task runs under a different user (e.g., SYSTEM vs. a user account), verify that G:\login and other paths are accessible to that user.
; - Fix Suggestion: To ensure consistent behavior, set the scheduled task’s "Start in" directory to "G:\login" or embed a FileChangeDir("G:\login") at the script’s start.
#comments-end
