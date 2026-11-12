# BUG-07 — ServiceControl.au3 Impact Analysis

**File under analysis**: `Includes/ServiceControl.au3`
**Review date**: 2026-11-12
**Prior art**: CR2-07 (`docs/reviews/second-pass/CR2-07-servicecontrol-review.md`),
`docs/domain-modeling/servicecontrol-analysis.md`,
`docs/BASELINE-INVENTORY.md` §ServiceControl.au3 Technical Findings
**Related ADRs**: ADR-0001, ADR-0004, ADR-0008, ADR-0011
**Scope**: Impact analysis only. No code changes are made in this document.
Architecture changes to `ServiceControl.au3` warrant a dedicated ADR before implementation.

---

## 1. The Two Bugs Under Analysis

### Bug A — `ControlService` third argument: `"str", ""` instead of `LPSERVICE_STATUS`

Present in two functions:

**`_StopService` (lines 188–191):**
```autoit
$arRet = DllCall($hAdvapi32, "int", "ControlService", _
        "long", $hService, _
        "long", $SERVICE_CONTROL_STOP, _
        "str", "")
```

**`_ServiceRunning` (lines 277–280):**
```autoit
$arRet = DllCall($hAdvapi32, "int", "ControlService", _
        "long", $hService, _
        "long", $SERVICE_CONTROL_INTERROGATE, _
        "str", "")
```

The Win32 `ControlService` signature is:

```c
BOOL ControlService(
  SC_HANDLE        hService,
  DWORD            dwControl,
  LPSERVICE_STATUS lpServiceStatus   // out-param: pointer to SERVICE_STATUS (7 DWORDs)
);
```

`LPSERVICE_STATUS` is a required output pointer to a 7-DWORD `SERVICE_STATUS` struct. AutoIt's `DllCall` with `"str", ""` allocates a string buffer, not a struct. The kernel writes the struct contents to whatever address AutoIt passes for the string — a string buffer large enough to hold an empty string is 1 byte (the null terminator), far smaller than the 28-byte struct the kernel expects to fill. The returned state data is inaccessible to AutoIt script code regardless of whether the kernel write itself crashes; `$arRet[0]` is the BOOL return value of `ControlService`, not the service state.

The correct call, as demonstrated in `ServiceManager.au3` (line 279–282), is:
```autoit
Local $tCtrlStatus = DllStructCreate("dword;dword;dword;dword;dword;dword;dword")
Local $aCtrl = DllCall("advapi32.dll", "bool", "ControlService", _
        "handle", $hService, _
        "dword",  $SM_SERVICE_CONTROL_STOP, _
        "ptr",    DllStructGetPtr($tCtrlStatus))
```

### Bug B — `"long"` handle types throughout the file

Every `DllCall` in `ServiceControl.au3` that accepts or returns a Win32 `SC_HANDLE` or `HANDLE` uses `"long"` as the type annotation instead of `"handle"`. Examples: return type of `OpenSCManager` (line 110), input handle parameter of `OpenService` (line 118), input handle of `CloseServiceHandle` (line 136). This is present across all six functions in the file.

On 64-bit Windows, handles are 64-bit values. AutoIt's `"long"` type is 32 bits (a signed 32-bit integer). A 64-bit handle value passed through a `"long"` slot is truncated to its low 32 bits, corrupting the handle. The correct type is `"handle"`, which AutoIt defines as a pointer-sized integer (32-bit on 32-bit processes, 64-bit on 64-bit processes).

---

## 2. What Data Is Lost Due to `"str", ""` Instead of a Proper Struct

The `SERVICE_STATUS` struct (7 DWORDs) that `ControlService` fills contains:

| Field | Offset | Meaning |
|---|---|---|
| `dwServiceType` | 1 | Type of service (WIN32_OWN_PROCESS, DRIVER, etc.) |
| `dwCurrentState` | 2 | Current lifecycle state (STOPPED=1, RUNNING=4, etc.) |
| `dwControlsAccepted` | 3 | Which controls the service accepts at this moment |
| `dwWin32ExitCode` | 4 | Win32 error that the service reported on failure |
| `dwServiceSpecificExitCode` | 5 | Service-defined error code |
| `dwCheckPoint` | 6 | Progress counter during long operations |
| `dwWaitHint` | 7 | Estimated time to next state change (ms) |

With `"str", ""`, none of these fields is accessible. The post-call state of the service — whether it is `STOP_PENDING`, `STOPPED`, or still `RUNNING` after the control was issued — is completely unknown to the caller.

For `_StopService`, the specific loss is `dwCurrentState` (field 2) and `dwWaitHint` (field 7). `dwCurrentState` would tell the caller whether the service has already reached `STOPPED` or is still transitioning. `dwWaitHint` is the kernel-provided estimate for how long to wait before polling again — without it, any wait logic must use a fixed arbitrary interval or poll blindly.

For `_ServiceRunning`, the loss is `dwCurrentState` (field 2), which is the only reliable indication of running state from an `INTERROGATE` call.

---

## 3. Impact on `_StopService`

`_StopService` sends `SERVICE_CONTROL_STOP` and then checks only `$arRet[0]`, the BOOL return value of `ControlService`:

```autoit
$arRet = DllCall($hAdvapi32, "int", "ControlService", _
        "long", $hService, _
        "long", $SERVICE_CONTROL_STOP, _
        "str", "")
If $arRet[0] = 0 Then
    $arRet = DllCall($hKernel32, "long", "GetLastError")
    $lError = $arRet[0]
EndIf
```

`$arRet[0]` is `1` (TRUE) if the stop control was accepted by the SCM, `0` (FALSE) if it was rejected. The function returns `1` to indicate the stop control was dispatched — it makes no claim that the service stopped.

The function comment at line 155 documents this explicitly: "This function does not check to see if the service has stopped successfully."

**Assessment**: `_StopService` does not use the returned state data at all, and its documented contract does not require it to. The `"str", ""` bug causes the struct to be inaccessible, but since the code only reads `$arRet[0]` (the BOOL), the missing struct has no effect on `_StopService`'s correctness within its own stated contract. The function's limitation is architectural (no stop confirmation, no state polling, no structured outcome), not a consequence of the struct bug.

The more significant issue in `_StopService` is the combination of the `"long"` handle type (Bug B) with the fact that it is now a deprecated code path. `_StopService` is not called on the monitoring hot path; `_SM_StopServicesBatch` has replaced it for all stop operations (confirmed in `Stop Services Processes.au3` lines 15–17 and ADR-0011). The stop control is never issued via `_StopService` in production use of this codebase.

**Verdict for `_StopService`**: The `"str", ""` struct bug causes no incorrect behavior in `_StopService` as implemented because the function does not consume the struct. The `"long"` handle truncation bug (Bug B) is the more serious risk in this function. However, since `_StopService` is not called in production, neither bug affects runtime behavior in the current codebase.

---

## 4. Impact on `_ServiceRunning`

`_ServiceRunning` calls `ControlService(SERVICE_CONTROL_INTERROGATE, ...)` and uses the return value directly as the running indicator:

```autoit
$arRet = DllCall($hAdvapi32, "int", "ControlService", _
        "long", $hService, _
        "long", $SERVICE_CONTROL_INTERROGATE, _
        "str", "")
$bRunning = $arRet[0]
```

`$arRet[0]` is the BOOL return value of `ControlService` — `1` if the interrogate control was accepted, `0` if it was rejected or failed.

The function's comment (lines 250–254) documents this design explicitly:

> "This function relies on the fact that only a running service responds to a SERVICE_CONTROL_INTERROGATE control code."

This design is intentional and consistent with MSDN documentation: a service that is not running cannot have a handle opened with `SERVICE_INTERROGATE` access and cannot respond to control codes. The technique is therefore a valid binary running/not-running test within its documented scope.

**CR2-07 finding S-3** noted this as CR2-07 found it "uses the integer success code as running indicator" and characterised it as "compounding the problem." This characterisation requires clarification:

- Using `$arRet[0]` (the BOOL success code) as the running indicator is **the correct technique for this design**. The function uses interrogate-response as a proxy for running state; the BOOL is exactly the right signal for that test.
- What is lost due to `"str", ""` is `dwCurrentState` from the returned struct, which would give a precise state value (RUNNING=4, PAUSED=7, STOP_PENDING=3, etc.) rather than just a binary yes/no. If a future caller needed to distinguish PAUSED from RUNNING, the struct would be required.
- As currently implemented and used, `_ServiceRunning` returns a binary 0/1 that correctly answers the question "did the service respond to INTERROGATE?" The `"str", ""` bug prevents access to the struct but does not corrupt the BOOL signal that the function actually returns.

**However, there is a known limitation that the `"str", ""` bug makes undetectable**: `ControlService` will fail with `ERROR_INVALID_SERVICE_CONTROL` (1052) or `ERROR_SERVICE_CANNOT_ACCEPT_CTRL` (1061) for some protected services that reject `INTERROGATE` controls even when running. Protected Windows services (Windows Defender, WaaS Medic, SFC) are documented to reject interrogate controls. For such services, `_ServiceRunning` returns `0` (not running) even when the service is actually running. This is a limitation of the interrogate-based technique itself, not of the `"str", ""` bug — the MSDN documentation for `ControlService` explicitly notes this limitation, and the function comment acknowledges it ("Check the ControlService page on MSDN for limitations with using this method").

The correct API for state inspection without this limitation is `QueryServiceStatus`, which `ServiceManager.au3` uses throughout.

**Verdict for `_ServiceRunning`**: The `"str", ""` bug prevents access to `dwCurrentState` from the returned struct, but `_ServiceRunning` does not use `dwCurrentState` from the struct — it uses the BOOL return value. Within the function's documented contract (interrogate-based binary running check), the `"str", ""` bug causes no incorrect behavior. The function's limitation with protected services is an architectural issue with the interrogate technique, not a consequence of the struct bug.

**Is `_ServiceRunning`'s approach actually correct behavior?** Yes, as a binary running/not-running indicator using interrogate-response as the signal — it is the documented MSDN technique for this purpose. It is an intentionally coarse test: some running services will return false negatives (protected services that reject interrogate). Whether this coarseness is acceptable depends on which services a caller is testing. For the services in `$aSvcTargetNames` (wuauserv, TrustedInstaller, WaaSMedicSvc, etc.), WaaSMedicSvc is specifically known to reject interrogate controls, so `_ServiceRunning("", "WaaSMedicSvc")` would likely return `0` even when the service is active.

---

## 5. `_ServiceRunning` Call Sites in the Main Codebase

A search of `Stop Services Processes.au3` and `ServiceManager.au3` for all calls to `_ServiceRunning`:

**`Stop Services Processes.au3`**: `_ServiceRunning` is not called anywhere in the monitoring loop, the `ToggleScript` function, `_RunServiceBatchStop`, `_KillProcessList`, `_PriorityWatchdog`, or any other function. The only reference is in the `#include` comment (line 16): "`ServiceControl.au3`: custom advapi32.dll wrapper — retained for `_ServiceRunning`, `_StartService`, `_CreateService`, `_DeleteService`."

**`ServiceManager.au3`**: `_ServiceRunning` is not called. `ServiceManager.au3` uses `QueryServiceStatus` directly for all state inspection.

**Conclusion**: `_ServiceRunning` is not called anywhere in the current codebase. It is retained as part of `ServiceControl.au3`'s public API for potential future use, but it is not on any active code path.

---

## 6. Impact Severity Assessment

### Bug A — `"str", ""` struct argument to `ControlService`

| Function | Struct data used? | Incorrect behavior caused? | Active code path? |
|---|---|---|---|
| `_StopService` | No — only `$arRet[0]` (BOOL) is read | None within stated contract | No — superseded by `_SM_StopServicesBatch` |
| `_ServiceRunning` | No — only `$arRet[0]` (BOOL) is read | None within stated contract | No — not called anywhere in codebase |

**Current runtime impact**: None. Neither function is called in production use of this codebase.

**Latent impact if either function were called by a future caller**: `_StopService` would still correctly dispatch a stop control and report whether it was accepted. A caller wanting to know the service's state after the stop control would have no struct to read. `_ServiceRunning` would still correctly return a binary running/not-running indicator using interrogate-response. A caller wanting `dwCurrentState` or `dwWaitHint` would have no struct to read.

**If the `"str", ""` were replaced with a proper struct without fixing Bug B**: the struct data would be accessible, but on 64-bit Windows the handle corruption from Bug B would likely prevent `ControlService` from succeeding at all, making the struct improvement moot.

### Bug B — `"long"` handle types

| Scenario | Impact |
|---|---|
| 32-bit process on 32-bit Windows | No impact — handles are 32-bit; `"long"` and `"handle"` are equivalent |
| 32-bit process on 64-bit Windows | No impact — a 32-bit process receives handles that fit in 32 bits |
| 64-bit process on 64-bit Windows | Handle corruption — `"long"` truncates to 32 bits; `OpenSCManager`/`OpenService` return values are silently corrupted; all subsequent calls using those handles fail |

**Target platform**: The script's `#AutoIt3Wrapper_Compile_Both=y` and `#AutoIt3Wrapper_UseX64=y` directives (confirmed in both the main script lines 6–7 and `docs/BASELINE-INVENTORY.md` lines 115–116) indicate the script is **compiled as a 64-bit executable** for its primary release target. The target OS is Windows 10/11 (confirmed in `CLAUDE.md` §Project Overview and `docs/ARCHITECTURE.md`), which is exclusively 64-bit.

This means Bug B is **active on the target platform** for a 64-bit build. When the compiled x64 `.exe` runs on Windows 10/11 (64-bit), `"long"` truncates 64-bit handles. All `OpenSCManager` and `OpenService` calls in `ServiceControl.au3` would return corrupted handle values. Every subsequent operation using those handles — `CloseServiceHandle`, `ControlService`, `StartService`, `DeleteService`, `CreateService` — would operate on invalid handles and fail.

**Mitigating factor**: None of `ServiceControl.au3`'s functions are called in the production monitoring loop. `_SM_StopServicesBatch` (which uses `"handle"` throughout) handles all service-stop operations. The corrupted handles would only manifest if `_ServiceRunning`, `_ServiceExists`, `_StartService`, `_CreateService`, or `_DeleteService` were called from the main script.

**Current runtime impact of Bug B**: None in the existing codebase, because no `ServiceControl.au3` function is on the active code path. The 64-bit handle truncation would cause silent failures the moment any of these functions were invoked in a 64-bit build.

---

## 7. Summary Table

| Bug | Affected functions | Data lost | Incorrect behavior today? | Incorrect behavior if called on 64-bit? |
|---|---|---|---|---|
| A: `"str",""` struct arg | `_StopService`, `_ServiceRunning` | `SERVICE_STATUS` struct (all 7 fields) | No — BOOL return value is sufficient for both functions' contracts | No — BOOL is still returned; struct fields unreachable |
| B: `"long"` handle types | All six functions | N/A — handle corruption causes call failures, not data loss | No — no function is called in production | Yes — `OpenSCManager`/`OpenService` return corrupted handles; all dependent calls fail silently |

**Overall severity**: Low in the current codebase, because all `ServiceControl.au3` functions are off the active code path. The bugs become High severity the moment any of the five non-stop helper functions (`_ServiceRunning`, `_ServiceExists`, `_StartService`, `_CreateService`, `_DeleteService`) is called in a 64-bit build, because Bug B would silently corrupt every SCM and service handle returned by those functions.

The `"str", ""` bug (Bug A) is secondary to the handle truncation bug (Bug B). On a 64-bit build, Bug B prevents the functions from operating at all. On a 32-bit build, Bug A would become the dominant issue: the functions execute but discard state data that callers might need.

---

## 8. Notes on Architecture Changes

The two bugs are related but have different fix scopes:

- **Bug A fix scope**: Localised — two `DllCall` sites in `_StopService` and `_ServiceRunning` need a `DllStructCreate("dword;dword;dword;dword;dword;dword;dword")` and the `"ptr", DllStructGetPtr(...)` idiom. No interface change.
- **Bug B fix scope**: Mechanical but broad — every handle-typed parameter across all six functions must change from `"long"` to `"handle"`, and every handle-typed return must also change. The return type annotation on `OpenSCManager` and `OpenService` calls must change from `"long"` to `"handle"`.

Both fixes should be treated as a single coordinated change. Fixing Bug A without Bug B leaves the struct-reading code unreachable on 64-bit due to corrupted handles. Fixing Bug B without Bug A means the struct is now addressable but the code still does not read it.

Additional work that the fix pass should include:
- Adding `#include-once` (noted in CR2-07 §S-1 and ADR-0011)
- Adding a deprecation comment to `_StopService` pointing to `_SM_StopServicesBatch` (noted in CR2-07 §SP-3)
- Switching to wide-character entry points (`OpenSCManagerW`, `OpenServiceW`) to match `ServiceManager.au3` (noted in `servicecontrol-analysis.md` §4)

These architectural changes warrant an ADR before implementation, per the project's documented standard.

---

## 9. References

- `Includes/ServiceControl.au3` — lines 158–207 (`_StopService`), 256–288 (`_ServiceRunning`)
- `Includes/ServiceManager.au3` — lines 278–298 (correct `ControlService` pattern with struct)
- `Stop Services Processes.au3` — lines 1–7 (x64 compile directives), 14–19 (include comments)
- `docs/reviews/second-pass/CR2-07-servicecontrol-review.md` — findings S-2, S-3, SP-3
- `docs/domain-modeling/servicecontrol-analysis.md` — §4 Known Issues
- `docs/BASELINE-INVENTORY.md` — §ServiceControl.au3 Technical Findings, §AU3Check Concerns
- `docs/adr/0001-servicemanager-module-extraction.md` — rationale for superseding `_StopService`
- `docs/adr/0004-servicemanager-incompatible-with-servicecontrol-error-convention.md`
- `docs/adr/0008-direct-dllcall-advapi32.md` — correct DllCall patterns
- `docs/adr/0011-servicecontrol-servicemanager-boundary-convention.md`
- MSDN: [`ControlService`](https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-controlservice)
- MSDN: [`SERVICE_STATUS`](https://learn.microsoft.com/en-us/windows/win32/api/winsvc/ns-winsvc-service_status)
