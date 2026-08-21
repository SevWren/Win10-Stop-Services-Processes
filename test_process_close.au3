#RequireAdmin
#include <MsgBoxConstants.au3>
While 1 = 1
	If ProcessExists("TCPSVCS.EXE") Then ; Check if the Notepad process is running.
;~         MsgBox($MB_SYSTEMMODAL, "", "Notepad is running")
		ConsoleWrite('TCPSVCS.EXE running' & @CRLF) ; ! = red text color
		ProcessClose("TCPSVCS.EXE")
	Else
;~         MsgBox($MB_SYSTEMMODAL, "", "Notepad is not running")
		ConsoleWrite('TCPSVCS.EXE not-running' & @CRLF)
	EndIf
	Sleep(2000)
WEnd

