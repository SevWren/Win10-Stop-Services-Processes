# CR2-25 — Full Spec Traceability Matrix
Branch: arch/service-manager-migration
Date: 2026-11-12
Reviewer: automated second-pass review
Ticket: T05 — Spec Traceability Audit

---

## Scope

This review covers all 17 REQs declared in `docs/REQUIREMENTS.md` and traces each to:
1. Its status field in the spec source (`REQUIREMENTS.md`).
2. Its implementation artifact (file + approximate line reference).
3. Its test coverage — named test function(s) in `Tests/ServiceManager.Tests.au3` or a documented static-inspection justification where no executable test exists.

Files reviewed:
- `docs/REQUIREMENTS.md`
- `Includes/ServiceManager.au3`
- `Tests/ServiceManager.Tests.au3`
- `Stop Services Processes.au3`

---

## Traceability Matrix

| REQ | Description | Status in REQUIREMENTS.md | Implementation artifact | Test function(s) | Coverage type |
|-----|-------------|--------------------------|------------------------|-----------------|---------------|
| REQ-001 | Batch service stop returns per-service outcome row ([n][6] array; outcome codes STOPPED, ALREADY_STOPPED, UNAVAILABLE, FAILED, TIMED_OUT; columns 0–5 per contract) | IMPLEMENTED | `Includes/ServiceManager.au3` — `_SM_StopServicesBatch()` lines 138–380; result array allocated at line 148, columns populated throughout Phase 1 and Phase 2 | `_Test_ResultArrayDimensions` (row count, col count, name preservation, UNAVAILABLE outcome); `_Test_BatchUnknownServices` (row count=3, col count=6, all columns per row); `_Test_SingleFailureInBatch` (per-row isolation); `_Test_SharedTimeout` (TIMED_OUT row); `_Test_UnavailableInBatch` (UNAVAILABLE row columns); `_Test_EmptyInput` (zero-row result) | unit + SCM integration |
| REQ-002 | All 7 Windows service state integers (1–7) mapped to canonical strings by `_SM_ServiceStateToString`; backed by seven `$SM_STATE_*` Global Const declarations | IMPLEMENTED | `Includes/ServiceManager.au3` — Global Const declarations lines 44–50; `_SM_ServiceStateToString()` Switch block lines 420–439 | `_Test_ServiceStateToString` — 10 assertions: all 7 valid states (1–7) + 3 out-of-range values (-1, 0, 99) return "UNKNOWN" | unit |
| REQ-003 | Phase 1 issues stop controls to all eligible services before Phase 2 poll loop begins — no serial waiting | IMPLEMENTED | `Includes/ServiceManager.au3` — Phase 1 For loop lines 194–309 (stop controls issued for all eligible services); Phase 2 While loop lines 316–361 (polls all pending against shared deadline) | Static inspection — the two-phase structure is structurally verifiable: Phase 1 `For` loop terminates before the `TimerInit()` call at line 314 that starts Phase 2; no `Sleep` or poll call exists inside Phase 1. No executable test covers the temporal ordering of stop controls vs. poll cycles (requires a Windows SCM with live services). | static inspection |
| REQ-004 | Minimum access rights only: `SC_MANAGER_CONNECT` (0x0001) for SCM open; `SERVICE_QUERY_STATUS \| SERVICE_STOP` (0x0024) for service open; no `SC_MANAGER_ALL_ACCESS` or `SERVICE_ALL_ACCESS` | IMPLEMENTED | `Includes/ServiceManager.au3` — named constants lines 75–79 (`$SM_SC_MANAGER_CONNECT`, `$SM_SERVICE_QUERY_STATUS`, `$SM_SERVICE_STOP`, `$SM_SERVICE_QUERY_AND_STOP`); `OpenSCManagerW` call line 170 uses `$SM_SC_MANAGER_CONNECT`; `OpenServiceW` call line 203 uses `$SM_SERVICE_QUERY_AND_STOP` | Static inspection — grep confirms no `SC_MANAGER_ALL_ACCESS` or `SERVICE_ALL_ACCESS` literal or constant appears in `ServiceManager.au3`. The specific hex values and constant names are verifiable without runtime execution. | static inspection |
| REQ-005 | Every handle (SCM and per-service) has exactly one cleanup path; all return paths close open handles | IMPLEMENTED | `Includes/ServiceManager.au3` — `$hService` closed at: line 237 (QueryServiceStatus failure), line 250 (ALREADY_STOPPED), line 271 (not stop-eligible), line 297 (ControlService failure); line 343 (Phase 2 STOPPED); lines 365–372 (timeout cleanup loop); `$hSCM` closed at line 376 after all service handles | Static inspection — handle lifecycle is traceable by code reading: each `OpenServiceW` result is followed by a `ContinueLoop` path that closes the handle, a pending-list append that defers to Phase 2 or timeout cleanup, or a Phase 2 success close. The SCM handle is the last closed. No executable test drives a specific early-exit path with handle leak detection. | static inspection |
| REQ-006 | `@error` captured immediately after every DllCall (next line, no intervening statements) | IMPLEMENTED | `Includes/ServiceManager.au3` — `$iScmDllErr = @error` line 174 (after `OpenSCManagerW`); `$iSvcDllErr = @error` line 207 (after `OpenServiceW`); `$iQryDllErr = @error` line 231 (after Phase 1 `QueryServiceStatus`); `$iCtrlDllErr = @error` line 283 (after `ControlService`); `$iPollDllErr = @error` line 328 (after Phase 2 `QueryServiceStatus`); `_SM_GetServiceState` `$iDllErr = @error` line 402 | Static inspection — each DllCall is followed on the immediately next line by `Local $i*DllErr = @error`; no intermediate statement appears between any DllCall and its `@error` capture. This is a structural text property verifiable by inspection without runtime execution. | static inspection |
| REQ-007 | All `SC_HANDLE` parameters in DllCall signatures use `"handle"` type string; `"long"` is absent for handle params | IMPLEMENTED | `Includes/ServiceManager.au3` — `OpenSCManagerW` return type `"handle"` line 170; `OpenServiceW` return type `"handle"` line 203, first param `"handle"` line 204; `QueryServiceStatus` first param `"handle"` lines 229, 325; `ControlService` first param `"handle"` line 280; all `CloseServiceHandle` params `"handle"` lines 237, 250, 271, 297, 343, 371, 376 | Static inspection — grep for `"long"` in `ServiceManager.au3` returns zero matches for handle parameters. `"handle"` type string is confirmed on every SC_HANDLE parameter. | static inspection |
| REQ-008 | `ControlService` receives a valid `SERVICE_STATUS` struct (7 DWORD fields via `DllStructCreate`; pointer passed as `"ptr"`) — not a string or empty value | IMPLEMENTED | `Includes/ServiceManager.au3` — `DllStructCreate("dword;dword;dword;dword;dword;dword;dword")` at line 278 (`$tCtrlStatus`); `DllStructGetPtr($tCtrlStatus)` passed as `"ptr"` at line 282; same 7-DWORD struct used for `QueryServiceStatus` calls at lines 227, 324, 398 | Static inspection — struct definition and pointer passing are textually verifiable. The same 7-DWORD pattern is confirmed at every `QueryServiceStatus` and `ControlService` call site. No executable test issues a live `ControlService` call (blocked by REQ-009). | static inspection |
| REQ-009 | Deterministic test harness issues no live stop controls; `_SM_StopServicesBatch` is called only with an empty array or intentionally non-existent service names | IMPLEMENTED | `Tests/ServiceManager.Tests.au3` — empty-array call at line 409 (`_Test_EmptyInput`); non-existent service names `__NonExistent_TestSvc_A/B__` at lines 292–293 (`_Test_ResultArrayDimensions`); `__TestHarness_NX_Svc1/2/3__` at line 471 (`_Test_BatchUnknownServices`); no call uses production service names | `_Test_EmptyInput` (empty array — returns before SCM open); `_Test_ResultArrayDimensions` (non-existent names — UNAVAILABLE, no stop issued); `_Test_BatchUnknownServices` (3 non-existent names — UNAVAILABLE, no stop issued). All remaining 9 test functions are pure-logic and make no DllCall at all. | unit + SCM integration |
| REQ-010 | Service inventory contains exactly 9 service names matching the enterprise prompt canonical list (`FDResPub`, `fdPHost`, `TrustedInstaller`, `wuauserv`, `UsoSvc`, `DoSvc`, `WaaSMedicSvc`, `SSDPSRV`, `sppsvc`) | IMPLEMENTED | `Stop Services Processes.au3` — `Global $aSvcTargetNames[9]` lines 84–86 (Configuration — Target lists region); 9 names present and match the REQ-010 canonical list exactly | Static inspection — count and names are textually verifiable from the array literal. No executable test validates the inventory list (a pure configuration value with no logic to test). | static inspection |
| REQ-011 | `$iLastStopProcesses` declared as `Global $iLastStopProcesses = 0` in globals section | IMPLEMENTED | `Stop Services Processes.au3` — `Global $iLastStopProcesses = 0` line 104 (Variables/Logging region) | Static inspection — AU3Check `-w 1` undeclared-variable scan would validate this; the declaration is textually present. No test harness covers the main-script globals. | static inspection |
| REQ-012 | 3 duplicate `#include` pairs (`WinAPI.au3`, `WinAPIProc.au3`, `Array.au3`) and 2 duplicate `HotKeySet` pairs removed | IMPLEMENTED | `Stop Services Processes.au3` — `#include <WinAPI.au3>` line 25 (single occurrence); `#include <WinAPIProc.au3>` line 26 (single occurrence); `#include <Array.au3>` line 27 (single occurrence); `HotKeySet` lines 33–36 (four distinct hotkeys, no duplicates) | Static inspection — each `#include` and `HotKeySet` appears exactly once. File has 36 lines in the preamble region; absence of duplicates is textually verifiable. | static inspection |
| REQ-013 | Service poll interval set to 10 seconds via `Global Const $SVC_POLL_INTERVAL_SEC = 10`; used in `_CheckElapsedTime` call in `ToggleScript` | IMPLEMENTED | `Stop Services Processes.au3` — `Global Const $SVC_POLL_INTERVAL_SEC = 10` line 43; `_CheckElapsedTime($iLastStopServices, $SVC_POLL_INTERVAL_SEC)` line 171 in `ToggleScript` | Static inspection — constant value and usage point are textually verifiable. No unit test covers timing constants; the constant is a configuration value. | static inspection |
| REQ-014 | All `#include` and `#AutoIt3Wrapper_*` paths use relative (working-directory-relative) form; no hardcoded user-profile or checkout-root paths | IMPLEMENTED | `Stop Services Processes.au3` — `#AutoIt3Wrapper_Outfile_x64=.\release\Stop Services - Processes.exe` line 4; `#AutoIt3Wrapper_Res_Icon_Add=ff7.ico` line 9; `#include "Includes\ServiceControl.au3"` line 18; `#include "Includes\ServiceManager.au3"` line 20; all standard AutoIt `#include <...>` use angle-bracket form (library paths) | Static inspection — each `#include` and wrapper directive is textually verifiable; no absolute path containing a username or drive root appears in the preamble region. | static inspection |
| REQ-015 | Intra-batch poll interval is 500 ms; `Global Const $SVC_BATCH_POLL_MS = 500` declared and passed to `_SM_StopServicesBatch`; `Sleep($iPollIntervalMs)` called in Phase 2 | IMPLEMENTED | `Stop Services Processes.au3` — `Global Const $SVC_BATCH_POLL_MS = 500` line 47; `_SM_StopServicesBatch($aSvcTargetNames, $SVC_BATCH_TIMEOUT_MS, $SVC_BATCH_POLL_MS)` line 238 in `_RunServiceBatchStop`; `Includes/ServiceManager.au3` — function default `$iPollIntervalMs = 500` line 138; `Sleep($iPollIntervalMs)` line 317 in Phase 2 poll loop | Static inspection — constant declaration, pass-through call, and `Sleep` usage are textually verifiable. Runtime verification (NOT RUN — Windows required). | static inspection |
| REQ-016 | Batch stop deadline is 20 seconds; `Global Const $SVC_BATCH_TIMEOUT_MS = 20000` declared and passed; Phase 2 `While` guarded by `TimerDiff($iTimer) < $iBatchTimeoutMs`; services exceeding deadline receive `TIMED_OUT` | IMPLEMENTED | `Stop Services Processes.au3` — `Global Const $SVC_BATCH_TIMEOUT_MS = 20000` line 46; `_RunServiceBatchStop` line 238 passes value; `Includes/ServiceManager.au3` — default `$iBatchTimeoutMs = 20000` line 138; `While … TimerDiff($iTimer) < $iBatchTimeoutMs` line 316; timeout loop assigns `$SM_OUTCOME_TIMEDOUT` at line 367 | `_Test_SharedTimeout` — constructs a simulated result array where one service has outcome `TIMED_OUT` and `finalState = STOP_PENDING (3)`; validates outcome and state values. The live 20-second timer is verified by static inspection only (NOT RUN — Windows required). | unit + static inspection |
| REQ-017 | `QueryServiceStatus` (7-DWORD `SERVICE_STATUS`) used throughout instead of `QueryServiceStatusEx`; decision rationale recorded in `REQUIREMENTS.md` per enterprise prompt alternative-API clause | IMPLEMENTED (with recorded decision) | `Includes/ServiceManager.au3` — `QueryServiceStatus` DllCall at lines 228–230 (Phase 1 query), 325–327 (Phase 2 poll), 399–401 (`_SM_GetServiceState`); `DllStructCreate("dword;dword;dword;dword;dword;dword;dword")` (7 fields) at lines 227, 324, 398; `QueryServiceStatusEx` is absent | Static inspection — grep for `QueryServiceStatusEx` in `ServiceManager.au3` returns no matches; all three `QueryServiceStatus` call sites use the 7-DWORD struct. Decision rationale (4 enumerated reasons) is recorded in `REQUIREMENTS.md` REQ-017 per the enterprise prompt alternative-API clause. | static inspection |

---

## Coverage Type Legend

| Type | Meaning |
|------|---------|
| unit | Covered by a pure-logic test function in `Tests/ServiceManager.Tests.au3` that makes no DllCall and runs deterministically |
| SCM integration | Covered by a test function that opens a live Windows SCM handle but issues no stop controls (non-existent service names or empty input) |
| unit + SCM integration | Covered by both a pure-logic test and an SCM integration test |
| unit + static inspection | Core logic covered by unit test; a timing or structural property additionally verified by code reading |
| static inspection | No executable test exists; coverage is provided solely by code reading with documented justification |

---

## Flagged Items — REQs With No Test and No Documented Justification

None. All 17 REQs with a static-inspection coverage type have an explicit justification recorded in this matrix and/or in `REQUIREMENTS.md`. The justifications are:

- **REQ-003**: Temporal ordering of two separate `For`/`While` loops is a structural property; confirming Phase 1 completes before Phase 2 begins requires only reading the loop boundaries. No `Sleep` call appears in Phase 1.
- **REQ-004**: Access-right constants are hex literals declared by name; absence of `ALL_ACCESS` flags is verifiable by grep. MSDN confirms the declared rights are sufficient.
- **REQ-005**: Handle lifetime is traceable by following each `OpenServiceW` result through its ContinueLoop and pending-list paths; every path terminates with a `CloseServiceHandle` or a timeout-loop close.
- **REQ-006**: `@error` capture on the immediately following line is a textual property; no logic branch or runtime state can affect whether the next line is `Local $i*DllErr = @error`.
- **REQ-007**: `"handle"` vs `"long"` is a string literal in source; grep is definitive.
- **REQ-008**: `DllStructCreate` call and `DllStructGetPtr` pass-through are textual; the 7-DWORD field count matches MSDN `SERVICE_STATUS` exactly.
- **REQ-010**: Array literal with 9 elements; count and names are textual.
- **REQ-011**: Global variable declaration is textual; AU3Check would flag absence.
- **REQ-012**: `#include` and `HotKeySet` counts are textual; duplicates are absent.
- **REQ-013**: Constant value `10` and its call-site usage are textual.
- **REQ-014**: Relative-path form in `#include` and `#AutoIt3Wrapper_*` directives is textual.
- **REQ-015**: `Sleep($iPollIntervalMs)` with default 500 is textual; runtime timing cannot be verified without Windows.
- **REQ-017**: `QueryServiceStatusEx` absence is grep-verifiable; decision rationale is recorded in `REQUIREMENTS.md`.

---

## Summary

| Coverage type | REQ count | REQs |
|--------------|-----------|------|
| unit | 1 | REQ-002 |
| unit + SCM integration | 2 | REQ-001, REQ-009 |
| unit + static inspection | 1 | REQ-016 |
| static inspection only | 13 | REQ-003, REQ-004, REQ-005, REQ-006, REQ-007, REQ-008, REQ-010, REQ-011, REQ-012, REQ-013, REQ-014, REQ-015, REQ-017 |
| **Total** | **17** | |

**Uncovered REQs (no test AND no documented justification): 0**

All 17 REQs have IMPLEMENTED status in `REQUIREMENTS.md`. All 17 have either executable test coverage, a documented static-inspection justification, or both. No gap is flagged.

---

## Notes on Runtime Limitations

The test harness is explicitly marked NOT RUN in this Linux sandbox environment. AutoIt v3 is a Windows-only runtime. The following REQs have static-inspection-only coverage specifically because their verification property requires Windows:

- REQ-003 (temporal ordering of stop-control dispatch vs. poll)
- REQ-005 (handle leak detection requires OS-level handle tracking)
- REQ-015 (500 ms `Sleep` interval requires a live timer)
- REQ-016 (20-second deadline requires a live `TimerDiff` loop)

These are accepted limitations documented in `REQUIREMENTS.md` with the annotation "NOT RUN — Windows required". They do not constitute coverage gaps for the purposes of this review.
