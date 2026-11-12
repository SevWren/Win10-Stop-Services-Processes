# Windows Service Control Manager APIs — Research Notes
Source: https://learn.microsoft.com/en-us/windows/win32/services/
Fetched: 2026-11-11
Primary sources: MSDN pages fetched directly for all 7 APIs listed below.

---

## OpenSCManagerW

**DLL**: `advapi32.dll`
**Header**: `winsvc.h` (include `Windows.h`)

### Signature

```cpp
SC_HANDLE OpenSCManagerW(
  [in, optional] LPCWSTR lpMachineName,   // NULL = local computer
  [in, optional] LPCWSTR lpDatabaseName,  // NULL or SERVICES_ACTIVE_DATABASE
  [in]           DWORD   dwDesiredAccess  // e.g. SC_MANAGER_CONNECT
);
```

### Parameters

| Parameter | Type | Notes |
|-----------|------|-------|
| `lpMachineName` | `LPCWSTR` | NULL connects to local SCM. Remote machine UNC name otherwise. |
| `lpDatabaseName` | `LPCWSTR` | Should be `SERVICES_ACTIVE_DATABASE` or NULL (defaults to same). |
| `dwDesiredAccess` | `DWORD` | Requested access rights for the SCM database. |

### Return Value

- **Success**: `SC_HANDLE` (non-NULL opaque handle to the SCM database).
- **Failure**: `NULL`. Call `GetLastError()` for details.

### Error Codes on Failure

| Code | Name | Description |
|------|------|-------------|
| 5 | `ERROR_ACCESS_DENIED` | Requested access was denied. |
| 1065 | `ERROR_DATABASE_DOES_NOT_EXIST` | Specified database does not exist. |

### Access Rights Required

- `SC_MANAGER_CONNECT` (0x0001) is implicitly requested when calling this function.
- For querying/opening services: open with `SC_MANAGER_CONNECT`.
- For `CreateService`: requires Administrator privileges (`SC_MANAGER_CREATE_SERVICE`).
- Local authenticated users are granted `SC_MANAGER_CONNECT` by default.

### Notes

- The returned handle is only valid for the calling process.
- Must be closed with `CloseServiceHandle()`.

---

## OpenServiceW

**DLL**: `advapi32.dll`
**Header**: `winsvc.h`

### Signature

```cpp
SC_HANDLE OpenServiceW(
  [in] SC_HANDLE hSCManager,      // Handle from OpenSCManager
  [in] LPCWSTR   lpServiceName,   // Internal service name (not display name)
  [in] DWORD     dwDesiredAccess  // e.g. SERVICE_QUERY_STATUS | SERVICE_STOP
);
```

### Parameters

| Parameter | Type | Notes |
|-----------|------|-------|
| `hSCManager` | `SC_HANDLE` | From `OpenSCManager`. Must have `SC_MANAGER_CONNECT`. |
| `lpServiceName` | `LPCWSTR` | Internal name (case-insensitive). Max 256 chars. No `/` or `\`. |
| `dwDesiredAccess` | `DWORD` | Access rights needed for subsequent operations on this service. |

### Return Value

- **Success**: `SC_HANDLE` (non-NULL handle to the service object).
- **Failure**: `NULL`. Call `GetLastError()` for details.

### Error Codes on Failure

| Code | Name | Description |
|------|------|-------------|
| 5 | `ERROR_ACCESS_DENIED` | Handle does not have access to the service. |
| 6 | `ERROR_INVALID_HANDLE` | The specified handle is invalid. |
| 123 | `ERROR_INVALID_NAME` | The specified service name is invalid. |
| 1060 | `ERROR_SERVICE_DOES_NOT_EXIST` | The specified service does not exist. |

### Access Rights Required

- Caller needs `SC_MANAGER_CONNECT` on the SCM handle.
- No additional privileges are required beyond `SC_MANAGER_CONNECT` to call `OpenService` itself.
- The `dwDesiredAccess` on the service handle must match subsequent operations (see Access Rights section).

---

## QueryServiceStatusEx

**DLL**: `advapi32.dll`
**Header**: `winsvc.h`

### Signature

```cpp
BOOL QueryServiceStatusEx(
  [in]            SC_HANDLE  hService,         // Service handle
  [in]            SC_STATUS_TYPE InfoLevel,    // Must be SC_STATUS_PROCESS_INFO (0)
  [out, optional] LPBYTE     lpBuffer,         // Pointer to buffer receiving SERVICE_STATUS_PROCESS
  [in]            DWORD      cbBufSize,        // Size of lpBuffer in bytes
  [out]           LPDWORD    pcbBytesNeeded    // Receives required size if buffer too small
);
```

### Parameters

| Parameter | Type | Notes |
|-----------|------|-------|
| `hService` | `SC_HANDLE` | From `OpenService`. Must have `SERVICE_QUERY_STATUS` access right. |
| `InfoLevel` | `SC_STATUS_TYPE` | Must be `SC_STATUS_PROCESS_INFO` (value 0). The only defined info level. |
| `lpBuffer` | `LPBYTE` | Out-pointer to a buffer large enough to hold `SERVICE_STATUS_PROCESS` (9 DWORDs = 36 bytes). |
| `cbBufSize` | `DWORD` | Size of `lpBuffer` in bytes. Pass `sizeof(SERVICE_STATUS_PROCESS)` = 36. |
| `pcbBytesNeeded` | `LPDWORD` | Receives the required buffer size if `cbBufSize` is too small. Always provide a valid pointer. |

### InfoLevel Constant

| Constant | Value | Meaning |
|----------|-------|---------|
| `SC_STATUS_PROCESS_INFO` | 0 | Returns `SERVICE_STATUS_PROCESS` (9 DWORDs). The only valid value. |

### Return Value

- **Success**: nonzero (TRUE). `lpBuffer` holds a filled `SERVICE_STATUS_PROCESS`.
- **Failure**: zero (FALSE). Call `GetLastError()` for details.

### Error Codes on Failure

| Code | Name | Description |
|------|------|-------------|
| 5 | `ERROR_ACCESS_DENIED` | Handle does not have `SERVICE_QUERY_STATUS` access right. |
| 6 | `ERROR_INVALID_HANDLE` | The handle is invalid. |
| 87 | `ERROR_INVALID_PARAMETER` | `InfoLevel` is not `SC_STATUS_PROCESS_INFO`, or `pcbBytesNeeded` is NULL. |
| 122 | `ERROR_INSUFFICIENT_BUFFER` | `cbBufSize` is smaller than required; `pcbBytesNeeded` holds the needed size. |

### QueryServiceStatus vs QueryServiceStatusEx — When to Use Which

| Criterion | `QueryServiceStatus` | `QueryServiceStatusEx` |
|-----------|---------------------|----------------------|
| Struct filled | `SERVICE_STATUS` (7 DWORDs) | `SERVICE_STATUS_PROCESS` (9 DWORDs) |
| Returns PID | No | Yes (`dwProcessId`) |
| Returns service flags | No | Yes (`dwServiceFlags`) |
| Required buffer | 28 bytes | 36 bytes |
| DllCall complexity | Simpler — no InfoLevel or size params | Requires `InfoLevel`, `cbBufSize`, `pcbBytesNeeded` params |
| Available since | Windows NT 3.5 | Windows 2000 |

**Trade-off**: Use `QueryServiceStatusEx` when you need the hosting process ID (e.g., to kill a service's process directly, or to identify whether a service shares a host process with others). Use `QueryServiceStatus` when you only need the service state integer — it is simpler to call and the DllCall pattern is shorter. The implementation in `Includes/ServiceManager.au3` uses `QueryServiceStatus` because it requires only `dwCurrentState` (field 2) and does not need the PID; this is a deliberate documented choice, not an oversight. The spec named `QueryServiceStatusEx` as a research target because the original design anticipated needing the PID, but the final implementation confirmed it is not required for the batch-stop operation.

---

## QueryServiceStatus

**DLL**: `advapi32.dll`
**Header**: `winsvc.h`

### Signature

```cpp
BOOL QueryServiceStatus(
  [in]  SC_HANDLE        hService,         // Service handle
  [out] LPSERVICE_STATUS lpServiceStatus   // Pointer to SERVICE_STATUS struct
);
```

**Note**: This function uses `SERVICE_STATUS` (7 fields), NOT `SERVICE_STATUS_PROCESS`.
For the extended 9-field version with process ID, use `QueryServiceStatusEx`.

### Parameters

| Parameter | Type | Notes |
|-----------|------|-------|
| `hService` | `SC_HANDLE` | From `OpenService`. Must have `SERVICE_QUERY_STATUS` access right. |
| `lpServiceStatus` | `LPSERVICE_STATUS` | Out-pointer to a `SERVICE_STATUS` struct to receive status. |

### Return Value

- **Success**: nonzero (TRUE).
- **Failure**: zero (FALSE). Call `GetLastError()` for details.

### Error Codes on Failure

| Code | Name | Description |
|------|------|-------------|
| 5 | `ERROR_ACCESS_DENIED` | Handle does not have `SERVICE_QUERY_STATUS` access right. |
| 6 | `ERROR_INVALID_HANDLE` | The handle is invalid. |

### Notes

- Returns the most recently reported status; the service may not have updated SCM yet.
- Superseded by `QueryServiceStatusEx` (which fills `SERVICE_STATUS_PROCESS` with 9 fields including PID).

---

## ControlService

**DLL**: `advapi32.dll`
**Header**: `winsvc.h`

### Signature

```cpp
BOOL ControlService(
  [in]  SC_HANDLE        hService,         // Service handle
  [in]  DWORD            dwControl,        // Control code (e.g. SERVICE_CONTROL_STOP = 0x00000001)
  [out] LPSERVICE_STATUS lpServiceStatus   // Pointer to SERVICE_STATUS struct
);
```

**Critical note**: The 3rd parameter is `LPSERVICE_STATUS` (pointer to `SERVICE_STATUS`, 7 fields),
**NOT** `LPSERVICE_STATUS_PROCESS`. `SERVICE_STATUS_PROCESS` is used only by `ControlServiceEx`.

### Parameters

| Parameter | Type | Notes |
|-----------|------|-------|
| `hService` | `SC_HANDLE` | From `OpenService`. Access rights depend on `dwControl`. |
| `dwControl` | `DWORD` | Control code. For stop: `SERVICE_CONTROL_STOP` = 0x00000001. |
| `lpServiceStatus` | `LPSERVICE_STATUS` | Receives the latest status after the control is dispatched. |

### Control Codes

| Code | Value | Required Access Right |
|------|-------|-----------------------|
| `SERVICE_CONTROL_STOP` | 0x00000001 | `SERVICE_STOP` (0x0020) |
| `SERVICE_CONTROL_PAUSE` | 0x00000002 | `SERVICE_PAUSE_CONTINUE` |
| `SERVICE_CONTROL_CONTINUE` | 0x00000003 | `SERVICE_PAUSE_CONTINUE` |
| `SERVICE_CONTROL_INTERROGATE` | 0x00000004 | `SERVICE_INTERROGATE` |

### Return Value

- **Success**: nonzero (TRUE).
- **Failure**: zero (FALSE). Call `GetLastError()`.

The `lpServiceStatus` struct is filled only when `GetLastError()` returns one of:
`NO_ERROR`, `ERROR_INVALID_SERVICE_CONTROL`, `ERROR_SERVICE_CANNOT_ACCEPT_CTRL`, or `ERROR_SERVICE_NOT_ACTIVE`.

### Error Codes on Failure

| Code | Name | Description |
|------|------|-------------|
| 5 | `ERROR_ACCESS_DENIED` | Handle does not have required access right. |
| 1051 | `ERROR_DEPENDENT_SERVICES_RUNNING` | Cannot stop — other running services depend on it. |
| 1052 | `ERROR_INVALID_SERVICE_CONTROL` | Control code is not valid or unacceptable to the service. |
| 1061 | `ERROR_SERVICE_CANNOT_ACCEPT_CTRL` | Service is in STOPPED, START_PENDING, or STOP_PENDING state. |
| 1062 | `ERROR_SERVICE_NOT_ACTIVE` | Service has not been started. |
| 1053 | `ERROR_SERVICE_REQUEST_TIMEOUT` | Service did not respond within 30 seconds. |
| 1115 | `ERROR_SHUTDOWN_IN_PROGRESS` | System is shutting down. |
| 6 | `ERROR_INVALID_HANDLE` | Handle was not obtained via CreateService/OpenService or is stale. |
| 87 | `ERROR_INVALID_PARAMETER` | Control code is undefined. |

### Service State Machine for ControlService

| Service state | STOP control | Other controls |
|---------------|-------------|----------------|
| STOPPED | ERROR_SERVICE_NOT_ACTIVE | ERROR_SERVICE_NOT_ACTIVE |
| STOP_PENDING | ERROR_SERVICE_CANNOT_ACCEPT_CTRL | ERROR_SERVICE_CANNOT_ACCEPT_CTRL |
| START_PENDING | Dispatched if accepted | ERROR_SERVICE_CANNOT_ACCEPT_CTRL |
| RUNNING | Dispatched if accepted | Dispatched if accepted |

---

## CloseServiceHandle

**DLL**: `advapi32.dll`
**Header**: `winsvc.h`

### Signature

```cpp
BOOL CloseServiceHandle(
  [in] SC_HANDLE hSCObject   // Handle to SCM or service object
);
```

### Parameters

| Parameter | Type | Notes |
|-----------|------|-------|
| `hSCObject` | `SC_HANDLE` | Handle from `OpenSCManager`, `OpenService`, or `CreateService`. |

### Return Value

- **Success**: nonzero (TRUE).
- **Failure**: zero (FALSE). Call `GetLastError()`.

### Error Codes on Failure

| Code | Name | Description |
|------|------|-------------|
| 6 | `ERROR_INVALID_HANDLE` | The specified handle is invalid. |

### Notes

- Does NOT destroy the SCM object (the SCM database persists).
- Does NOT stop or delete a service — only releases the handle.
- Always call for both the SCM handle and the service handle when done.

---

## SERVICE_STATUS struct

**Header**: `winsvc.h`
**Used by**: `QueryServiceStatus`, `ControlService`, `SetServiceStatus`, `EnumServicesStatus`

### Definition

```cpp
typedef struct _SERVICE_STATUS {
  DWORD dwServiceType;               // Field 1
  DWORD dwCurrentState;              // Field 2
  DWORD dwControlsAccepted;          // Field 3
  DWORD dwWin32ExitCode;             // Field 4
  DWORD dwServiceSpecificExitCode;   // Field 5
  DWORD dwCheckPoint;                // Field 6
  DWORD dwWaitHint;                  // Field 7
} SERVICE_STATUS, *LPSERVICE_STATUS;
```

**Total fields: 7. ALL fields are DWORD (32-bit unsigned integer). Confirmed from MSDN.**

### Fields in Order

| # | Field Name | Type | Description |
|---|-----------|------|-------------|
| 1 | `dwServiceType` | `DWORD` | Type of service (WIN32_OWN_PROCESS=0x10, WIN32_SHARE_PROCESS=0x20, KERNEL_DRIVER=0x01, etc.) |
| 2 | `dwCurrentState` | `DWORD` | Current state: STOPPED=1, START_PENDING=2, STOP_PENDING=3, RUNNING=4, CONTINUE_PENDING=5, PAUSE_PENDING=6, PAUSED=7 |
| 3 | `dwControlsAccepted` | `DWORD` | Bitmask of control codes the service accepts (SERVICE_ACCEPT_STOP=0x01, etc.) |
| 4 | `dwWin32ExitCode` | `DWORD` | Win32 error code on start/stop failure; NO_ERROR when running normally |
| 5 | `dwServiceSpecificExitCode` | `DWORD` | Service-specific error; valid only when dwWin32ExitCode = ERROR_SERVICE_SPECIFIC_ERROR |
| 6 | `dwCheckPoint` | `DWORD` | Progress counter incremented during lengthy operations |
| 7 | `dwWaitHint` | `DWORD` | Estimated time (ms) for pending operation to complete |

### dwCurrentState Values

| Value | Constant | Meaning |
|-------|----------|---------|
| 1 | `SERVICE_STOPPED` | Not running |
| 2 | `SERVICE_START_PENDING` | Starting |
| 3 | `SERVICE_STOP_PENDING` | Stopping |
| 4 | `SERVICE_RUNNING` | Running |
| 5 | `SERVICE_CONTINUE_PENDING` | Resume pending |
| 6 | `SERVICE_PAUSE_PENDING` | Pause pending |
| 7 | `SERVICE_PAUSED` | Paused |

---

## SERVICE_STATUS_PROCESS struct

**Header**: `winsvc.h`
**Used by**: `QueryServiceStatusEx`, `ControlServiceEx`, `EnumServicesStatusEx`, `NotifyServiceStatusChange`
**NOT used by**: `QueryServiceStatus` or `ControlService`

### Definition

```cpp
typedef struct _SERVICE_STATUS_PROCESS {
  DWORD dwServiceType;               // Field 1
  DWORD dwCurrentState;              // Field 2
  DWORD dwControlsAccepted;          // Field 3
  DWORD dwWin32ExitCode;             // Field 4
  DWORD dwServiceSpecificExitCode;   // Field 5
  DWORD dwCheckPoint;                // Field 6
  DWORD dwWaitHint;                  // Field 7
  DWORD dwProcessId;                 // Field 8  <-- additional vs SERVICE_STATUS
  DWORD dwServiceFlags;              // Field 9  <-- additional vs SERVICE_STATUS
} SERVICE_STATUS_PROCESS, *LPSERVICE_STATUS_PROCESS;
```

**Total fields: 9. ALL fields are DWORD. Confirmed from MSDN.**

Fields 1–7 are identical to `SERVICE_STATUS`. The two additional fields:

| # | Field Name | Type | Description |
|---|-----------|------|-------------|
| 8 | `dwProcessId` | `DWORD` | PID of the process hosting the service (0 if not running). |
| 9 | `dwServiceFlags` | `DWORD` | 0 = normal process; `SERVICE_RUNS_IN_SYSTEM_PROCESS` (0x01) = system process. |

### QueryServiceStatus vs QueryServiceStatusEx

| Function | Struct | Fields | Includes PID? |
|----------|--------|--------|---------------|
| `QueryServiceStatus` | `SERVICE_STATUS` | 7 | No |
| `QueryServiceStatusEx` | `SERVICE_STATUS_PROCESS` | 9 | Yes |

---

## Access Rights

### SC_MANAGER Access Rights (for OpenSCManager)

| Constant | Value | Description |
|----------|-------|-------------|
| `SC_MANAGER_CONNECT` | 0x0001 | Required to connect to the SCM. Implicitly requested by OpenSCManager. |
| `SC_MANAGER_CREATE_SERVICE` | 0x0002 | Required to create a service (Administrators only). |
| `SC_MANAGER_ENUMERATE_SERVICE` | 0x0004 | Required to enumerate services. |
| `SC_MANAGER_LOCK` | 0x0008 | Required to lock the SCM database. |
| `SC_MANAGER_QUERY_LOCK_STATUS` | 0x0010 | Required to query lock status. |
| `SC_MANAGER_MODIFY_BOOT_CONFIG` | 0x0020 | Required to call NotifyBootConfigStatus. |
| `SC_MANAGER_ALL_ACCESS` | 0xF003F | All access rights. |

**Confirmed: `SC_MANAGER_CONNECT` = 0x0001**

### SERVICE Access Rights (for OpenService)

| Constant | Value | Required for |
|----------|-------|--------------|
| `SERVICE_QUERY_CONFIG` | 0x0001 | QueryServiceConfig |
| `SERVICE_CHANGE_CONFIG` | 0x0002 | ChangeServiceConfig |
| `SERVICE_QUERY_STATUS` | 0x0004 | QueryServiceStatus, QueryServiceStatusEx |
| `SERVICE_ENUMERATE_DEPENDENTS` | 0x0008 | EnumDependentServices |
| `SERVICE_START` | 0x0010 | StartService |
| `SERVICE_STOP` | 0x0020 | ControlService with SERVICE_CONTROL_STOP |
| `SERVICE_PAUSE_CONTINUE` | 0x0040 | ControlService with PAUSE/CONTINUE |
| `SERVICE_INTERROGATE` | 0x0080 | ControlService with INTERROGATE |
| `SERVICE_USER_DEFINED_CONTROL` | 0x0100 | ControlService with user-defined codes |
| `SERVICE_ALL_ACCESS` | 0xF01FF | All access rights. |

**Confirmed: `SERVICE_QUERY_STATUS` = 0x0004, `SERVICE_STOP` = 0x0020**

### Minimum Rights Per Operation

| Operation | OpenSCManager dwDesiredAccess | OpenService dwDesiredAccess |
|-----------|-------------------------------|----------------------------|
| Query service status | `SC_MANAGER_CONNECT` (0x0001) | `SERVICE_QUERY_STATUS` (0x0004) |
| Stop a service | `SC_MANAGER_CONNECT` (0x0001) | `SERVICE_STOP` (0x0020) |
| Query + Stop | `SC_MANAGER_CONNECT` (0x0001) | `SERVICE_QUERY_STATUS \| SERVICE_STOP` (0x0024) |
| Start a service | `SC_MANAGER_CONNECT` (0x0001) | `SERVICE_START` (0x0010) |

### Default Rights by Account

Local authenticated users (non-admin) are granted by default on a service object:
`SERVICE_QUERY_CONFIG`, `SERVICE_QUERY_STATUS`, `SERVICE_ENUMERATE_DEPENDENTS`,
`SERVICE_INTERROGATE`, `SERVICE_USER_DEFINED_CONTROL` — but NOT `SERVICE_STOP` or `SERVICE_START`.

Administrators are granted `SERVICE_ALL_ACCESS` by default.

---

## Win32 Error Codes

| Decimal | Hex | Constant | Description |
|---------|-----|----------|-------------|
| 5 | 0x0005 | `ERROR_ACCESS_DENIED` | Insufficient rights to perform the operation. |
| 6 | 0x0006 | `ERROR_INVALID_HANDLE` | Handle is invalid or stale. |
| 87 | 0x0057 | `ERROR_INVALID_PARAMETER` | A parameter is invalid (e.g., undefined control code). |
| 1051 | 0x041B | `ERROR_DEPENDENT_SERVICES_RUNNING` | Service cannot stop — dependent services still running. |
| 1052 | 0x041C | `ERROR_INVALID_SERVICE_CONTROL` | Control code not valid or not acceptable to the service. |
| 1053 | 0x041D | `ERROR_SERVICE_REQUEST_TIMEOUT` | Service did not respond to start/stop/control within 30s. |
| 1060 | 0x0424 | `ERROR_SERVICE_DOES_NOT_EXIST` | Named service not found in the SCM database. |
| 1061 | 0x0425 | `ERROR_SERVICE_CANNOT_ACCEPT_CTRL` | Service is in a state where controls cannot be sent (STOPPED, START_PENDING, STOP_PENDING). |
| 1062 | 0x0426 | `ERROR_SERVICE_NOT_ACTIVE` | Service has not been started. |
| 1065 | 0x0429 | `ERROR_DATABASE_DOES_NOT_EXIST` | SCM database does not exist. |
| 1068 | 0x042C | `ERROR_SERVICE_DEPENDENCY_FAIL` | A dependency service failed to start. |
| 1072 | 0x0430 | `ERROR_SERVICE_MARKED_FOR_DELETE` | Service is marked for deletion (DeleteService was called). |

---

## Summary: QueryServiceStatus vs ControlService Struct Usage

| Function | 3rd param struct | Field count | Includes PID |
|----------|-----------------|-------------|--------------|
| `QueryServiceStatus` | `SERVICE_STATUS` | 7 | No |
| `ControlService` | `SERVICE_STATUS` | 7 | No |
| `QueryServiceStatusEx` | `SERVICE_STATUS_PROCESS` | 9 | Yes |
| `ControlServiceEx` | `SERVICE_STATUS_PROCESS` | 9 | Yes |

Both `QueryServiceStatus` and `ControlService` use the 7-field `SERVICE_STATUS` struct.

---

## Service Inventory Reconciliation

**Spec requirement**: Reconcile service inventory against baseline (FDResPub, fdPHost, TrustedInstaller, wuauserv, UsoSvc, DoSvc, WaaSMedicSvc, SSDPSRV, sppsvc).

### Baseline vs Enterprise-Prompt Inventory

The cloned repo baseline (`_stopservicescustom()` in `Stop Services Processes.au3` before migration) contained **6 services**:

```
TrustedInstaller, wuauserv, UsoSvc, DoSvc, WaaSMedicSvc, sppsvc
```

The enterprise prompt specified **9 services**. Three services were absent from the baseline and have been added:

| Service | In baseline | In enterprise prompt | Delta |
|---------|------------|---------------------|-------|
| `TrustedInstaller` | Yes | Yes | — |
| `wuauserv` | Yes | Yes | — |
| `UsoSvc` | Yes | Yes | — |
| `DoSvc` | Yes | Yes | — |
| `WaaSMedicSvc` | Yes | Yes | — |
| `sppsvc` | Yes | Yes | — |
| `FDResPub` | No | Yes | Added |
| `fdPHost` | No | Yes | Added |
| `SSDPSRV` | No | Yes | Added |

The current implementation in `_RunServiceBatchStop()` uses all 9 services per the enterprise prompt. This delta is recorded in `docs/BASELINE-INVENTORY.md`.

### Per-Service Reference

| Service Name | Display Name | Typical State | Special Considerations |
|-------------|--------------|---------------|----------------------|
| `FDResPub` | Function Discovery Resource Publication | Running or Stopped (variable) | Publishes the computer and its resources to the network; often running on domain-joined machines. No special stop constraints. |
| `fdPHost` | Function Discovery Provider Host | Running or Stopped (variable) | Hosts Function Discovery providers; `FDResPub` depends on it. Stop `FDResPub` first if stopping both, though the batch approach handles dependency failures via `ERROR_DEPENDENT_SERVICES_RUNNING`. |
| `TrustedInstaller` | Windows Modules Installer | Stopped (triggered on demand) | Installs, modifies, and removes Windows updates and optional components. Also appears as the process `TrustedInstaller.exe` in the process inventory. Stopping the service does not kill the process if it has already detached; the process kill and service stop are handled independently. |
| `wuauserv` | Windows Update | Running or Stop-Pending | Core Windows Update service. Frequently in START_PENDING or RUNNING when updates are active. May restart quickly via task scheduler; repeated stops are expected. |
| `UsoSvc` | Update Orchestrator Service | Running or Stopped | Orchestrates the sequence of Windows Update download and install operations. Depends on `wuauserv`. |
| `DoSvc` | Delivery Optimization | Running or Stopped | Handles peer-to-peer and CDN delivery of Windows Update content. Can be in START_PENDING during active downloads. |
| `WaaSMedicSvc` | Windows Update Medic Service | Running | Protected by a service protection mechanism on Windows 10 1803+; `ControlService` with `SERVICE_CONTROL_STOP` may return `ERROR_ACCESS_DENIED` (5) or `ERROR_SERVICE_CANNOT_ACCEPT_CTRL` (1061). Expect FAILED outcome on modern builds. |
| `SSDPSRV` | SSDP Discovery | Running or Stopped | Discovers networked devices and services using SSDP. `fdPHost` and `FDResPub` may depend on it. No elevated stop constraints. |
| `sppsvc` | Software Protection | Running or Stopped | Manages software licensing; may resist stop with `ERROR_ACCESS_DENIED` on some configurations. The old implementation had a `ProcessClose("sppsvc.exe")` fallback; the new batch path does not — if the service stop fails, outcome is FAILED and no process kill is attempted. |
