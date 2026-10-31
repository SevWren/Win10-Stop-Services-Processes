;===============================================================================
; WARNING: DO NOT DELETE WINDOWS SERVICES.
; This helper is intentionally disabled because permanently deleting services is
; dangerous and not needed for this project. The script performs safe stop
; requests only. If you need to stop a service, use ControlService with
; SERVICE_CONTROL_STOP. Do not call DeleteService.
;===============================================================================
Func _DeleteService($sComputerName, $sServiceName)
	SetError(0x00000005) ; ERROR_ACCESS_DENIED
	Return 0
EndFunc   ;==>_DeleteService
