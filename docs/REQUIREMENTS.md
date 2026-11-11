# Requirements Register
Branch: arch/service-manager-migration
Date: 2026-11-11
Ticket: T02 — Define Contracts and Verify Windows SCM APIs

---

## REQ-001 — Batch Service Stop Returns Per-Service Outcomes

**Source**: Enterprise prompt Task 3; BASELINE-INVENTORY.md finding that _StopService returns
immediately without verification.

**Implementation**: `_SM_StopServicesBatch()` in `Includes/ServiceManager.au3`

**Verification**: Tests/ServiceManager.Tests.au3 — test cases for each outcome code

**Evidence**: Static analysis of ServiceManager.au3 source; runtime evidence NOT RUN (Windows required)

**Status**: Implementation pending (T03)

**Detail**: Each call to `_SM_StopServicesBatch` must return one result row per input service.
Outcome codes: `STOPPED`, `ALREADY_STOPPED`, `UNAVAILABLE`, `FAILED`, `TIMED_OUT`.

---

## REQ-002 — All 7 Service States Interpreted

**Source**: MSDN SERVICE_STATUS struct; enterprise prompt Task 3

**Implementation**: `_SM_GetServiceState()` helper in ServiceManager.au3

**Verification**: Tests — state query returns correct integer for each of 7 states

**Evidence**: docs/research/windows-scm-api.md confirms state values 1–7

**Status**: Implementation pending (T03)

**Detail**:
- `SERVICE_STOPPED` = 1
- `SERVICE_START_PENDING` = 2
- `SERVICE_STOP_PENDING` = 3
- `SERVICE_RUNNING` = 4
- `SERVICE_CONTINUE_PENDING` = 5
- `SERVICE_PAUSE_PENDING` = 6
- `SERVICE_PAUSED` = 7

---

## REQ-003 — Batch Issues Stop Controls Without Serial Waiting

**Source**: Enterprise prompt Task 3: "issue stop controls without serial waiting, then poll all
pending services against one shared deadline"

**Implementation**: ServiceManager.au3 `_SM_StopServicesBatch()` two-phase design

**Verification**: Static inspection — stop loop and poll loop are separate phases

**Evidence**: Code structure review

**Status**: Implementation pending (T03)

**Detail**: Phase 1 opens service handles + queries state + issues stop controls for all
eligible services. Phase 2 polls all pending services against one shared `TimerInit()` deadline.

---

## REQ-004 — Minimum Access Rights Only

**Source**: Enterprise prompt Task 3; docs/research/windows-scm-api.md

**Implementation**: DllCall parameters in `_SM_StopServicesBatch`

**Verification**: Code inspection — no use of `SC_MANAGER_ALL_ACCESS` or `SERVICE_ALL_ACCESS`

**Evidence**: MSDN confirms `SC_MANAGER_CONNECT | SERVICE_QUERY_STATUS | SERVICE_STOP` is sufficient

**Status**: Implementation pending (T03)

**Detail**:
- `OpenSCManagerW` → `SC_MANAGER_CONNECT` (0x0001)
- `OpenServiceW` for stop → `SERVICE_QUERY_STATUS | SERVICE_STOP` (0x0024)

---

## REQ-005 — Every Handle Has Exactly One Cleanup Path

**Source**: CLAUDE.md; enterprise prompt Task 3; ServiceControl.au3 bug analysis (T01)

**Implementation**: ServiceManager.au3 — handle tracking arrays, cleanup on every return path

**Verification**: Code review — trace every DllCall returning a handle to its CloseServiceHandle

**Evidence**: Code structure inspection

**Status**: Implementation pending (T03)

---

## REQ-006 — @error Captured Immediately After DllCall

**Source**: CLAUDE.md "AutoIt Version Compatibility Notes"; docs/research/autoit-dllcall.md

**Implementation**: Every DllCall in ServiceManager.au3 followed immediately by `Local $iDllErr = @error`

**Verification**: Code review — no line between DllCall and @error capture

**Evidence**: autoit-dllcall.md confirms @error is overwritten by the next operation

**Status**: Implementation pending (T03)

---

## REQ-007 — "handle" Type String for All SC_HANDLE Parameters

**Source**: docs/research/autoit-dllcall.md; CLAUDE.md; ServiceControl.au3 bug (T01 baseline)

**Implementation**: All DllCall parameters accepting SC_HANDLE use `"handle"` not `"long"`

**Verification**: Code review — grep for `"long"` in ServiceManager.au3; must be absent for handle params

**Evidence**: autoit-dllcall.md confirms `"long"` truncates handles on 64-bit Windows

**Status**: Implementation pending (T03)

---

## REQ-008 — ControlService Receives Valid SERVICE_STATUS Struct

**Source**: MSDN ControlService; docs/research/windows-scm-api.md; ServiceControl.au3 bug (T01)

**Implementation**: ServiceManager.au3 uses `DllStructCreate("dword;dword;dword;dword;dword;dword;dword")`
for the lpServiceStatus parameter, passing `DllStructGetPtr($tStatus)` as `"ptr"`

**Verification**: Code review — no `"str", ""` passed as struct; DllStructCreate used

**Evidence**: MSDN confirms SERVICE_STATUS = 7 DWORD fields; ControlService takes LPSERVICE_STATUS

**Status**: Implementation pending (T03)

---

## REQ-009 — Deterministic Test Harness Has No Live Service Stops

**Source**: Enterprise prompt Task 3: "no live stop controls"

**Implementation**: Tests/ServiceManager.Tests.au3

**Verification**: Code review — no calls to `_SM_StopServicesBatch` with real service names in tests

**Evidence**: Code inspection

**Status**: Implementation pending (T03)

---

## REQ-010 — Service Inventory Matches Enterprise Prompt

**Source**: Enterprise prompt Task 2; BASELINE-INVENTORY.md (T01 found 6 services vs 9 in plan)

**Implementation**: `$aServiceNames` local array in `_stopservicescustom()` replacement

**Decision**: Use enterprise prompt inventory (9 services) as it is more comprehensive.
Added services vs baseline: `FDResPub`, `fdPHost`, `SSDPSRV`.

**Verification**: Code inspection — count 9 service names in the array

**Evidence**: Enterprise prompt Task 2 canonical list; BASELINE-INVENTORY.md delta section

**Status**: Implementation pending (T04)

**Detail** (canonical list per enterprise prompt):
`FDResPub`, `fdPHost`, `TrustedInstaller`, `wuauserv`, `UsoSvc`, `DoSvc`, `WaaSMedicSvc`,
`SSDPSRV`, `sppsvc`

---

## REQ-011 — Undeclared $iLastStopProcesses Fixed

**Source**: BASELINE-INVENTORY.md (T01) — variable used but never declared

**Implementation**: Add `Global $iLastStopProcesses = 0` to globals section in main script

**Verification**: AU3Check -w 1 would no longer flag undeclared variable

**Status**: Implementation pending (T04)

---

## REQ-012 — Duplicate #include and HotKeySet Lines Removed

**Source**: BASELINE-INVENTORY.md (T01)

**Implementation**: Remove 3 duplicate #include pairs and 2 duplicate HotKeySet pairs

**Verification**: Code inspection

**Status**: Implementation pending (T04)

---

## REQ-013 — Service Poll Interval Changed to 10 Seconds

**Source**: Enterprise prompt Target Behavior: "service polling at 10 seconds";
BASELINE-INVENTORY.md (T01) found both process and service intervals at 2 seconds

**Implementation**: `$SVC_POLL_INTERVAL_SEC = 10` named constant; `CheckElapsedTime($iLastStopServices, $SVC_POLL_INTERVAL_SEC)` in ToggleScript

**Verification**: Code inspection

**Status**: Implementation pending (T04)

---

## REQ-014 — Include Paths Portable (Working Directory Relative)

**Source**: CLAUDE.md path portability rules; enterprise prompt; BASELINE-INVENTORY.md

**Implementation**: `#include "Includes\ServiceControl.au3"` and `#include "Includes\ServiceManager.au3"`
(relative paths); `#AutoIt3Wrapper_Outfile_x64` changed to `.\release\Stop Services - Processes.exe`

**Verification**: Code inspection — no hardcoded user-profile or checkout-root paths

**Status**: Implementation pending (T04)

---

## Conflicts Resolved

| Conflict | Resolution | Record |
|---|---|---|
| Service interval: baseline=2s, enterprise prompt=10s | Use 10s per enterprise prompt; introduce named constants | REQ-013 |
| Service inventory: baseline=6, enterprise prompt=9 | Use 9 from enterprise prompt; list in BASELINE-INVENTORY.md delta | REQ-010 |
| `xgamehelper.exe` duplicate | Retain both entries (behavior: second close is harmless no-op); document as known | T04 |
| ServiceControl.au3 `_StopService` vs new `_SM_StopServicesBatch` | ServiceManager.au3 is authoritative for stop operations; ServiceControl.au3 retained for non-stop helpers | D-002 in wiki |
