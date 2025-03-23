#RequireAdmin
_LogMessage("Script started", "System", 1)
; Local $iResult = ProcessClose("sppsvc.exe")
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=G:\Users\mmuel\OneDrive\Documents\AutoIT\ff7.ico
#AutoIt3Wrapper_Outfile=..\..\..\Desktop\Stop Services - Processes.Exe
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
Global $iLogLevel = 2 ; 0=Errors only, 1=Basic logging, 2=Detailed logging
Global $bLogToConsole = True ; Enable console logging alongside file logging
TraySetIcon($iconfile)
Exit
; Initialize logging
If Not FileExists($sLogFile) Then
    DirCreate(StringRegExpReplace($sLogFile, "\\[^\\]+$", ""))
    _LogMessage("Log file initialized", "System", 1)
EndIf
#EndRegion ;Globals

While 1  ;Keeps script running indefinitely.  Hotkeys determine which path the script heads
    Sleep(50)
WEnd

Func ToggleScript() ;handles the toggling on and off of script.  Eventually use this to handle halting the main loop instead.
    If $bScriptRunning Then
        _LogMessage("F1 pressed - Pausing script", "System", 1)
        MsgBox($MB_SYSTEMMODAL, "AutoIT Script", "Script paused!", 1)
        $bScriptRunning = False ;this exits this function
    Else
        _LogMessage("F1 pressed - Starting script", "System", 1)
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

    ; Special handling for sppsvc
    If _ServiceRunning("", "sppsvc") Then
        $bActionTaken = True
        Local $iResult = ProcessClose("sppsvc.exe")
        #ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $iResult =  = ' & $iResult =  & @CRLF & '>Error code: ' & @error & @CRLF) ;### Debug Console
        ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $iResult = ' & $iResult & @CRLF & '>Error code: ' & @error & @CRLF) ;### Debug Console

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

Func _LogMessage($sMessage, $sType, $iLevel)
    If $iLevel > $iLogLevel Then Return ; Skip if message level is higher than current log level

    Local $sDateTime = _NowTime(12) & " " & @MDAY & "/" & @MON & "/" & @YEAR
    Local $sLogEntry = @CRLF & $sDateTime & " [" & $sType & "] " & $sMessage

    ; Attempt to write to log file
    Local $hFile = FileOpen($sLogFile, 1)
    If $hFile = -1 Then
        ConsoleWrite("Error: Could not open log file for writing" & @CRLF)
        Return
    EndIf

    FileWrite($hFile, $sLogEntry)
    FileClose($hFile)

    ; Console output if enabled
    If $bLogToConsole Then
        ConsoleWrite($sLogEntry & @CRLF)
    EndIf
EndFunc

Func _exit()
    _LogMessage("Script termination requested", "System", 1)
    _LogMessage("Script Was Terminated by _exit()", "System", 1)
    Exit
EndFunc

Func _AdvancedRenamer()
    If WinExists("[CLASS:TPleaseRegisterForm]") Then
        ConsoleWrite("In _AdvancedRenamer function" & @CRLF)
        ConsoleWrite("Passed check, closing window" & @CRLF)
        WinClose("[CLASS:TPleaseRegisterForm]")
    EndIf
EndFunc   ;==>_AdvancedRenamer

Func CheckElapsedTime($iStartTime, $iInterval)  ;handles the calculation of time difference in ms to seconds
    Return TimerDiff($iStartTime) >= ($iInterval * 1000)
EndFunc   ;==>CheckElapsedTime