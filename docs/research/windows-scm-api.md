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
