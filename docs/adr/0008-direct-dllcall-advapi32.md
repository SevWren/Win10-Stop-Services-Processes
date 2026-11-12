# Direct DllCall to advapi32.dll instead of AutoIt WinAPI wrappers for SCM operations

`ServiceManager.au3` calls `OpenSCManagerW`, `OpenServiceW`, `QueryServiceStatus`,
`ControlService`, and `CloseServiceHandle` via `DllCall("advapi32.dll", ...)` directly
rather than using AutoIt's built-in service functions or `_WinAPI_*` wrappers, because
the built-ins do not expose the full `SERVICE_STATUS` struct that the batch-stop algorithm
requires for state-based routing.

## Considered options

**Direct DllCall to advapi32.dll (chosen):** `QueryServiceStatus` fills a seven-field
`SERVICE_STATUS` struct; `dwCurrentState` (field 2), `dwWaitHint`, and the other fields
are read directly from the struct via `DllStructGetData`. This gives `_SM_StopServicesBatch`
the per-service state integer it needs to route each service into the correct phase-1
branch (`ALREADY_STOPPED`, pending-poll, stop-eligible, or ineligible) and to decide when
Phase 2 polling is complete.

**AutoIt built-in `ServiceStop()` / `_Service_*` functions (rejected):** AutoIt's built-in
service functions return a binary success/failure value. They do not expose `dwCurrentState`
or any other `SERVICE_STATUS` field. The batch-stop algorithm cannot classify services by
state using these functions, and they have known gaps with protected services (e.g.
`WaaSMedicSvc`) that require direct Win32 access. Rejected for the same reasons recorded in
ADR-0001.

**AutoIt `_WinAPI_*` wrappers (rejected):** The project's AutoIt installation (3.3.16.1)
has confirmed bugs where `_WinAPI_*` wrappers propagate unreliable `@error` values after
WinAPI calls. `CLAUDE.md` documents this for `_WinAPI_GetPriorityClass` on the kernel32.dll
path; the same reliability concern applies to any `_WinAPI_*` wrapper over advapi32.dll.
Direct `DllCall` captures `@error` immediately on the line after the call, before it can
be overwritten, and captures `_WinAPI_GetLastError()` before any subsequent call can clear
it.

## Consequences

- Every advapi32.dll call site must follow the capture-immediately pattern:
  `Local $iDllErr = @error` on the line directly after `DllCall`, then
  `Local $iWinErr = _WinAPI_GetLastError()` before any other call. Deviating from this
  order produces silent misclassification of Win32 errors.
- The DllCall type signatures (`"handle"`, `"bool"`, `"dword"`, `"wstr"`, `"ptr"`) and
  the `SERVICE_STATUS` struct layout (`"dword;dword;dword;dword;dword;dword;dword"`) must
  be validated against the official Win32 documentation. Any drift silently passes wrong
  values to the SCM.
- Portability to non-Windows platforms is impossible. This is intentional: the project
  targets Windows 10/11 exclusively and requires administrator privileges.
- `ServiceControl.au3` follows the same direct-DllCall pattern for its own advapi32.dll
  calls (predating `ServiceManager.au3`). Both files must continue to use direct DllCall;
  do not introduce `_WinAPI_*` wrappers into either file.
