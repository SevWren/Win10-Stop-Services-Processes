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

**Status**: IMPLEMENTED — `_SM_StopServicesBatch` returns `[n][6]` array; Gate 5 evidence: REQ-001 (T05 review SPEC-003).

**Detail**: Each call to `_SM_StopServicesBatch` must return one result row per input service.
Outcome codes: `STOPPED`, `ALREADY_STOPPED`, `UNAVAILABLE`, `FAILED`, `TIMED_OUT`.
Result row column layout: `[i][0]` name, `[i][1]` initial state, `[i][2]` final state, `[i][3]` outcome, `[i][4]` Win32 error, `[i][5]` note (columns 0–5 per ARCHITECTURE.md public contract).

---

## REQ-002 — All 7 Service States Interpreted

**Source**: MSDN SERVICE_STATUS struct; enterprise prompt Task 3

**Implementation**: `_SM_ServiceStateToString()` in `Includes/ServiceManager.au3` — maps state integer 1–7 to canonical string; backed by seven `$SM_STATE_*` Global Const declarations

**Verification**: Tests — `_Test_ServiceStateToString` covers all 7 states + 3 out-of-range values

**Evidence**: docs/research/windows-scm-api.md confirms state values 1–7; Gate 5 evidence: REQ-002 (`_SM_ServiceStateToString`; T05 review SPEC-004)

**Status**: IMPLEMENTED — all 7 state integers mapped in `_SM_ServiceStateToString` Switch block; `_SM_GetServiceState` is a separate DllCall helper and is not the interpretation function

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

**Evidence**: Code structure review; Gate 5 evidence: REQ-003 (T05 review SPEC-005)

**Status**: IMPLEMENTED — Phase 1 loop issues stop controls for all eligible services before Phase 2 poll loop begins; verified by code inspection of `_SM_StopServicesBatch` two-loop structure

**Detail**: Phase 1 opens service handles + queries state + issues stop controls for all
eligible services. Phase 2 polls all pending services against one shared `TimerInit()` deadline.

---

## REQ-004 — Minimum Access Rights Only

**Source**: Enterprise prompt Task 3; docs/research/windows-scm-api.md

**Implementation**: DllCall parameters in `_SM_StopServicesBatch`

**Verification**: Code inspection — no use of `SC_MANAGER_ALL_ACCESS` or `SERVICE_ALL_ACCESS`

**Evidence**: MSDN confirms `SC_MANAGER_CONNECT | SERVICE_QUERY_STATUS | SERVICE_STOP` is sufficient; Gate 5 evidence: REQ-004 (T05 review SPEC-006)

**Status**: IMPLEMENTED — `$SM_SC_MANAGER_CONNECT = 0x0001`, `$SM_SERVICE_QUERY_STATUS = 0x0004`, `$SM_SERVICE_STOP = 0x0020` declared as named constants; no `SC_MANAGER_ALL_ACCESS` or `SERVICE_ALL_ACCESS` present

**Detail**:
- `OpenSCManagerW` → `SC_MANAGER_CONNECT` (0x0001)
- `OpenServiceW` for stop → `SERVICE_QUERY_STATUS | SERVICE_STOP` (0x0024)

---

## REQ-005 — Every Handle Has Exactly One Cleanup Path

**Source**: CLAUDE.md; enterprise prompt Task 3; ServiceControl.au3 bug analysis (T01)

**Implementation**: ServiceManager.au3 — handle tracking arrays, cleanup on every return path

**Verification**: Code review — trace every DllCall returning a handle to its CloseServiceHandle

**Evidence**: Code structure inspection; Gate 5 evidence: REQ-005 (T05 review SPEC-007)

**Status**: IMPLEMENTED — every DllCall returning a handle (`OpenSCManagerW`, `OpenServiceW`) is closed on every return path, including early-exit paths via `ContinueLoop`; timeout path closes remaining pending handles before SCM handle

---

## REQ-006 — @error Captured Immediately After DllCall

**Source**: CLAUDE.md "AutoIt Version Compatibility Notes"; docs/research/autoit-dllcall.md

**Implementation**: Every DllCall in ServiceManager.au3 followed immediately by `Local $iDllErr = @error`

**Verification**: Code review — no line between DllCall and @error capture

**Evidence**: autoit-dllcall.md confirms @error is overwritten by the next operation; Gate 5 evidence: REQ-006 (T05 review SPEC-008)

**Status**: IMPLEMENTED — every DllCall in `ServiceManager.au3` is immediately followed by `Local $i*DllErr = @error` on the next line; verified by code inspection

---

## REQ-007 — "handle" Type String for All SC_HANDLE Parameters

**Source**: docs/research/autoit-dllcall.md; CLAUDE.md; ServiceControl.au3 bug (T01 baseline)

**Implementation**: All DllCall parameters accepting SC_HANDLE use `"handle"` not `"long"`

**Verification**: Code review — grep for `"long"` in ServiceManager.au3; must be absent for handle params

**Evidence**: autoit-dllcall.md confirms `"long"` truncates handles on 64-bit Windows; Gate 5 evidence: REQ-007 (T05 review SPEC-009)

**Status**: IMPLEMENTED — all SC_HANDLE parameters in `ServiceManager.au3` use `"handle"` type string; `"long"` is absent for handle params; verified by code inspection

---

## REQ-008 — ControlService Receives Valid SERVICE_STATUS Struct

**Source**: MSDN ControlService; docs/research/windows-scm-api.md; ServiceControl.au3 bug (T01)

**Implementation**: ServiceManager.au3 uses `DllStructCreate("dword;dword;dword;dword;dword;dword;dword")`
for the lpServiceStatus parameter, passing `DllStructGetPtr($tStatus)` as `"ptr"`

**Verification**: Code review — no `"str", ""` passed as struct; DllStructCreate used

**Evidence**: MSDN confirms SERVICE_STATUS = 7 DWORD fields; ControlService takes LPSERVICE_STATUS; Gate 5 evidence: REQ-008 (T05 review SPEC-010)

**Status**: IMPLEMENTED — `DllStructCreate("dword;dword;dword;dword;dword;dword;dword")` used for both `QueryServiceStatus` and `ControlService` struct parameters; `DllStructGetPtr($tStatus)` passed as `"ptr"`

---

## REQ-009 — Deterministic Test Harness Has No Live Service Stops

**Source**: Enterprise prompt Task 3: "no live stop controls"

**Implementation**: Tests/ServiceManager.Tests.au3

**Verification**: Code review — no calls to `_SM_StopServicesBatch` with real service names in tests

**Evidence**: Code inspection; Gate 5 evidence: REQ-009 (T05 review SPEC-001)

**Status**: IMPLEMENTED — no live SCM calls in deterministic test harness; `_Test_EmptyInput` is the only test that calls `_SM_StopServicesBatch` and does so with an empty array that returns before opening SCM

---

## REQ-010 — Service Inventory Matches Enterprise Prompt

**Source**: Enterprise prompt Task 2; BASELINE-INVENTORY.md (T01 found 6 services vs 9 in plan)

**Implementation**: `$aServiceNames` local array in `_stopservicescustom()` replacement

**Decision**: Use enterprise prompt inventory (9 services) as it is more comprehensive.
Added services vs baseline: `FDResPub`, `fdPHost`, `SSDPSRV`.

**Verification**: Code inspection — count 9 service names in the array

**Evidence**: Enterprise prompt Task 2 canonical list; BASELINE-INVENTORY.md delta section; Gate 5 evidence: REQ-010 (T05 review SPEC-011)

**Status**: IMPLEMENTED — 9 service names present in `$aServiceNames` local array in `_RunServiceBatchStop()` in `Stop Services Processes.au3`

**Detail** (canonical list per enterprise prompt):
`FDResPub`, `fdPHost`, `TrustedInstaller`, `wuauserv`, `UsoSvc`, `DoSvc`, `WaaSMedicSvc`,
`SSDPSRV`, `sppsvc`

---

## REQ-011 — Undeclared $iLastStopProcesses Fixed

**Source**: BASELINE-INVENTORY.md (T01) — variable used but never declared

**Implementation**: Add `Global $iLastStopProcesses = 0` to globals section in main script

**Verification**: AU3Check -w 1 would no longer flag undeclared variable

**Status**: IMPLEMENTED — `Global $iLastStopProcesses = 0` declared in globals section of `Stop Services Processes.au3`; Gate 5 evidence: REQ-011 (T05 review STD-05)

---

## REQ-012 — Duplicate #include and HotKeySet Lines Removed

**Source**: BASELINE-INVENTORY.md (T01)

**Implementation**: Remove 3 duplicate #include pairs and 2 duplicate HotKeySet pairs

**Verification**: Code inspection

**Status**: IMPLEMENTED — 3 duplicate `#include` pairs (`WinAPI.au3`, `WinAPIProc.au3`, `Array.au3`) and 2 duplicate `HotKeySet` pairs removed from `Stop Services Processes.au3`; Gate 5 evidence: REQ-012 (T05 review STD-03/STD-04)

---

## REQ-013 — Service Poll Interval Changed to 10 Seconds

**Source**: Enterprise prompt Target Behavior: "service polling at 10 seconds";
BASELINE-INVENTORY.md (T01) found both process and service intervals at 2 seconds

**Implementation**: `$SVC_POLL_INTERVAL_SEC = 10` named constant; `CheckElapsedTime($iLastStopServices, $SVC_POLL_INTERVAL_SEC)` in ToggleScript

**Verification**: Code inspection

**Status**: IMPLEMENTED — `Global Const $SVC_POLL_INTERVAL_SEC = 10` declared in `Stop Services Processes.au3` globals; Gate 5 evidence: REQ-013 (T05 review SPEC-04)

---

## REQ-014 — Include Paths Portable (Working Directory Relative)

**Source**: CLAUDE.md path portability rules; enterprise prompt; BASELINE-INVENTORY.md

**Implementation**: `#include "Includes\ServiceControl.au3"` and `#include "Includes\ServiceManager.au3"`
(relative paths); `#AutoIt3Wrapper_Outfile_x64` changed to `.\release\Stop Services - Processes.exe`

**Verification**: Code inspection — no hardcoded user-profile or checkout-root paths

**Status**: IMPLEMENTED — all `#include` and `#AutoIt3Wrapper_*` paths changed to relative form; `#AutoIt3Wrapper_Res_Icon_Add` changed to `ff7.ico`; Gate 5 evidence: REQ-014 (T05 review SPEC-05)

---

## REQ-015 — Intra-Batch Poll Interval is 500 ms

**Source**: Enterprise prompt Target Behavior: "The default poll interval is 500 ms"; spec §Service manager

**Implementation**: `Global Const $SVC_BATCH_POLL_MS = 500` in `Stop Services Processes.au3` (line 47); passed as `$iPollIntervalMs` argument to `_SM_StopServicesBatch`; function default parameter `$iPollIntervalMs = 500` in `Includes/ServiceManager.au3`

**Verification**: Code inspection — `$SVC_BATCH_POLL_MS = 500` present in globals; `Sleep($iPollIntervalMs)` in Phase 2 poll loop of `_SM_StopServicesBatch`

**Evidence**: `Stop Services Processes.au3` line 47; `Includes/ServiceManager.au3` function signature line 112; docs/ARCHITECTURE.md line 45

**Status**: IMPLEMENTED — `$SVC_BATCH_POLL_MS = 500` declared as named constant and passed through to `Sleep()` in Phase 2 poll loop; static inspection only (NOT RUN — Windows runtime required)

---

## REQ-016 — Batch Stop Deadline is 20 Seconds

**Source**: Enterprise prompt Target Behavior: "The default batch deadline is 20 seconds"; spec §Service manager

**Implementation**: `Global Const $SVC_BATCH_TIMEOUT_MS = 20000` in `Stop Services Processes.au3` (line 46); passed as `$iBatchTimeoutMs` argument to `_SM_StopServicesBatch`; function default parameter `$iBatchTimeoutMs = 20000` in `Includes/ServiceManager.au3`; Phase 2 `While` condition: `TimerDiff($iTimer) < $iBatchTimeoutMs`

**Verification**: Code inspection — `$SVC_BATCH_TIMEOUT_MS = 20000` present in globals; `While … TimerDiff($iTimer) < $iBatchTimeoutMs` in `_SM_StopServicesBatch` Phase 2

**Evidence**: `Stop Services Processes.au3` line 46; `Includes/ServiceManager.au3` function signature line 112 and poll loop line 276; docs/ARCHITECTURE.md line 44

**Status**: IMPLEMENTED — `$SVC_BATCH_TIMEOUT_MS = 20000` declared as named constant and enforced by `TimerDiff` guard in Phase 2 poll loop; services exceeding deadline receive `TIMED_OUT` outcome; static inspection only (NOT RUN — Windows runtime required)

---

## REQ-017 — Windows SCM Query API Selection: QueryServiceStatus (not QueryServiceStatusEx)

**Source**: Enterprise prompt Task 2: "Use `OpenSCManagerW`, `OpenServiceW`, `QueryServiceStatusEx`, `ControlService`, and `CloseServiceHandle`, or record a primary-source decision for a different API"; CR-04 finding SP-01; CR-05 finding SPEC-S02

**Implementation**: `QueryServiceStatus` (7-DWORD `SERVICE_STATUS` struct) used throughout `Includes/ServiceManager.au3` — in `_SM_GetServiceState`, Phase 1 query loop, and Phase 2 poll loop; `QueryServiceStatusEx` and `SERVICE_STATUS_PROCESS` (9 DWORDs) are not used

**Decision**: The enterprise prompt allowed an alternative API if a primary-source decision was recorded. The implementation selected `QueryServiceStatus` because:
1. `dwCurrentState` occupies field 2 in both `SERVICE_STATUS` (7 DWORDs) and `SERVICE_STATUS_PROCESS` (9 DWORDs) — the state integer is identical in both structs.
2. `SERVICE_QUERY_STATUS` (0x0004) access right is sufficient for both APIs — no additional rights are needed.
3. `QueryServiceStatusEx` requires passing an info level (`SC_STATUS_PROCESS_INFO = 0`) plus a buffer size parameter, adding call complexity; the PID field it provides (`dwProcessId` in `SERVICE_STATUS_PROCESS`) is not used anywhere in this implementation.
4. `ControlService` takes `LPSERVICE_STATUS` (7 DWORDs), not `LPSERVICE_STATUS_PROCESS`, so the simpler struct must be allocated for the stop control regardless; using it for queries avoids maintaining two struct types.

See `docs/adr/0009-queryservicestatus-api-selection.md` for the formal ADR recording this API selection decision.

**Verification**: Code inspection — grep `QueryServiceStatus` in `Includes/ServiceManager.au3` shows no `QueryServiceStatusEx` calls; `DllStructCreate("dword;dword;dword;dword;dword;dword;dword")` (7 fields) used for all query structs

**Evidence**: `Includes/ServiceManager.au3` lines 189, 285, 359; docs/research/windows-scm-api.md §QueryServiceStatus vs QueryServiceStatusEx comparison table; MSDN `SERVICE_STATUS` struct (7 DWORDs); CR-04 finding SP-01; CR-05 finding SPEC-S02

**Status**: IMPLEMENTED (with recorded decision) — `QueryServiceStatus` used in place of `QueryServiceStatusEx`; decision rationale recorded above per enterprise prompt alternative-API clause; static inspection only (NOT RUN — Windows runtime required)

---

## Conflicts Resolved

| Conflict | Resolution | Record |
|---|---|---|
| Service interval: baseline=2s, enterprise prompt=10s | Use 10s per enterprise prompt; introduce named constants | REQ-013 |
| Service inventory: baseline=6, enterprise prompt=9 | Use 9 from enterprise prompt; list in BASELINE-INVENTORY.md delta | REQ-010 |
| `xgamehelper.exe` duplicate | Retain both entries (behavior: second close is harmless no-op); document as known | T04 |
| ServiceControl.au3 `_StopService` vs new `_SM_StopServicesBatch` | ServiceManager.au3 is authoritative for stop operations; ServiceControl.au3 retained for non-stop helpers | D-002 in wiki |
