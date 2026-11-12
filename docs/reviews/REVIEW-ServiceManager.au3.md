# Code Review: Includes/ServiceManager.au3
Reviewer: T05 Independent Review Agent (not the implementation agent)
Date: 2026-11-11
Branch: arch/service-manager-migration

## SHA-256 Hash
b44126b0fb4726e0bac84c065ac0851e807e0ffefb769f0181700a638cbe0117  Includes/ServiceManager.au3

---

## Standards

### Findings

**STD-001** | MINOR | Line ~217, 263 | AU3Check redeclaration of loop-scoped Local variables
`Local $iPendLen` is declared inside an `If` block (line 217) within the Phase 1 `For` loop, and `Local $iPendLen2` appears at line 263 in the same loop iteration. On each subsequent loop iteration AutoIt re-encounters the `Local` declaration. AU3Check `-w 3` may flag "variable used in a previous declaration" warnings. The suffix `2` on `$iPendLen2` is also a code smell (see STD-005).
Evidence: lines 217 (`Local $iPendLen = UBound($aPendingIdx)`) and 263 (`Local $iPendLen2 = UBound($aPendingIdx)`) both inside the `For $i` body.

**STD-002** | MINOR | Line ~324 | Mysterious Name: `$jj` (judgement call)
The timeout-sweep loop variable is named `$jj` (line 324) while the Phase 2 inner poll loop uses `$j` (line 280). There is no naming convention established for a "second j". A descriptive name (`$iTimeoutIdx` or simply `$i` with an outer scope guard) would remove ambiguity.
Evidence: `Local $jj` at line 324 vs `Local $j` at line 280.

**STD-003** | INFORMATIONAL | Lines 217, 263 | Duplicated Code: ReDim pattern repeated (judgement call)
The four-line expand-and-assign pattern for `$aPendingIdx` / `$aPendingHnd` appears identically at lines 217–221 (STOP_PENDING branch) and lines 263–267 (ControlService-accepted branch). Extracting to `_SM_AddToPendingList` would eliminate duplication, but as it stands the duplication is limited to two sites and the function is otherwise simple.
Evidence: Lines 217–221 and 263–267 are structurally identical.

**STD-004** | INFORMATIONAL | Lines 357–370 | Speculative Generality: `_SM_GetServiceState` is never called internally (judgement call)
`_SM_GetServiceState` is defined as an internal helper (documented in the file header) but is not called anywhere within `ServiceManager.au3`. Phase 1 and Phase 2 both call `QueryServiceStatus` directly. The function exists only for the test harness, which is a form of speculative generality in the production module. If the test harness is the only caller, the function could be colocated with the test file, or its "internal" designation should be changed to "test-support export".
Evidence: No call site for `_SM_GetServiceState` exists within this file.

**STD-005** | INFORMATIONAL | Lines 484–493 | Speculative Generality: `_SM_BuildResultRow` is never called internally (judgement call)
Similar to STD-004: `_SM_BuildResultRow` is documented as a "convenience helper used internally and by the test harness" but has no internal call sites. All result-row construction is done inline in `_SM_StopServicesBatch`. The function is exposed solely for the test harness.
Evidence: No call site for `_SM_BuildResultRow` exists within this file.

**STD-006** | PASS | All functions | Function naming: `_SM_PascalCase` convention
All eight functions in the file (`_SM_StopServicesBatch`, `_SM_GetServiceState`, `_SM_ServiceStateToString`, `_SM_Win32ErrToOutcome`, `_SM_IsStopEligible`, `_SM_StateNeedsPolling`, `_SM_StateToAlreadyStopped`, `_SM_BuildResultRow`) follow the `_SM_PascalCase` convention mandated by CODING_STANDARDS.md.

**STD-007** | PASS | All DllCalls | @error captured immediately after every DllCall
Every DllCall in the file is immediately followed by `Local $i<X>DllErr = @error` on the next line (accounting for line-continuation underscores which are part of the same statement). CloseServiceHandle calls are not checked per the documented standard. No violations found.

**STD-008** | PASS | All DllCalls | Handle type: `"handle"` used for all SC_HANDLE parameters
No `"long"` type string is used for any SC_HANDLE, HANDLE, or related parameter. All handle returns and handle inputs consistently use `"handle"`.

**STD-009** | PASS | All paths | Handle ownership: exactly one CloseServiceHandle per opened handle
Traced all acquisition and release paths — see REQ-005 in the Spec Axis for the full trace. No leak found.

**STD-010** | PASS | Line 239 | ControlService struct: 7-DWORD `DllStructCreate`
`DllStructCreate("dword;dword;dword;dword;dword;dword;dword")` with `DllStructGetPtr($tCtrlStatus)` passed as `"ptr"`. Correct. No `"str", ""` pattern present.

**STD-011** | PASS | File | No hardcoded paths
No checkout root, user-profile, or desktop paths present. All log routing goes through `_LogMessage`. No path portability violations.

**STD-012** | PASS | Line 38 | `#include-once` present
`#include-once` appears at line 38 as the first non-comment, non-blank line.

### Summary

| Severity | Count |
|---|---|
| BLOCKER | 0 |
| CRITICAL | 0 |
| MAJOR | 0 |
| MINOR | 2 (STD-001, STD-002) |
| INFORMATIONAL | 3 (STD-003, STD-004, STD-005) |

---

## Spec

### Findings

**SPEC-001** | MAJOR | REQ-N/A (Architecture contract) | `_SM_GetServiceState` signature diverges from ARCHITECTURE.md
ARCHITECTURE.md (Module Map section) documents the internal helper as:
```
_SM_GetServiceState($hAdvapi32, $hService)
```
The implementation at line 357 is:
```autoit
Func _SM_GetServiceState($hService)
```
Only one parameter. The `$hAdvapi32` DLL handle parameter is absent; the function uses an inline `"advapi32.dll"` string instead of a pre-opened DLL handle. The architecture document and the implementation are out of sync. Any caller that follows the architecture contract and passes two arguments will trigger AU3Check parameter-count warnings.
Evidence: ARCHITECTURE.md line "\_SM\_GetServiceState(\$hAdvapi32, \$hService)"; ServiceManager.au3 line 357 `Func _SM_GetServiceState($hService)`.

**SPEC-002** | INFORMATIONAL | REQ-N/A | `_SM_Win32ErrToOutcome` contains a dead branch for 1060 from ControlService context
The function's header comment states it is used to classify ControlService failures. However, `ERROR_SERVICE_DOES_NOT_EXIST` (1060) is not a documented return code of `ControlService` — it is an `OpenServiceW` error. The implementation correctly handles the OpenServiceW 1060 case separately (lines 171–174) before this function is ever called. The `Case $iWin32Err = $SM_ERR_SVC_NOT_EXIST` branch in `_SM_Win32ErrToOutcome` is therefore dead code in its current calling context. The mapping is harmless and would safely classify a 1060 if one somehow arrived, but the header comment is misleading.
Evidence: windows-scm-api.md ControlService error table does not list 1060; `_SM_Win32ErrToOutcome` line 417 handles it.

**SPEC-003** | PASS | REQ-001 | `_SM_StopServicesBatch` returns [n][6] 2D array, one row per input service
Verified: `Local $aResults[$iCount][6]` at line 122. Columns 0–5 match specification exactly:
[0]=service name, [1]=initial state, [2]=final state, [3]=outcome string, [4]=Win32 error, [5]=note.
Empty-input path returns `$aResults[0][6]` (zero rows) with @error=0 (lines 116–119). Fully compliant.

**SPEC-004** | PASS | REQ-002 | All 7 service states handled in `_SM_ServiceStateToString`
Cases 1 (STOPPED), 2 (START_PENDING), 3 (STOP_PENDING), 4 (RUNNING), 5 (CONTINUE_PENDING), 6 (PAUSE_PENDING), 7 (PAUSED) all present. `Case Else` returns "UNKNOWN". All 7 states covered.

**SPEC-005** | PASS | REQ-003 | Phase 1 issues all stop controls before Phase 2 polls — two distinct loops confirmed
Phase 1 is a `For $i = 0 To $iCount - 1` loop (lines 159–269) with no `Sleep` call. Phase 2 is a separate `While` loop (lines 276–321) beginning after Phase 1 completes. No serial wait exists inside Phase 1. Architecture requirement met.

**SPEC-006** | PASS | REQ-004 | Minimum access rights only
OpenSCManagerW: `$SM_SC_MANAGER_CONNECT` = 0x0001. No extra bits.
OpenServiceW: `$SM_SERVICE_QUERY_AND_STOP` = BitOR(0x0004, 0x0020) = 0x0024 = `SERVICE_QUERY_STATUS | SERVICE_STOP`. No extra bits. Confirmed against windows-scm-api.md Access Rights table.

**SPEC-007** | PASS | REQ-005 | Every opened handle has exactly one cleanup path

Handle acquisition and release trace:

| Handle | Opened at | Closed at (all paths) |
|---|---|---|
| `$hSCM` | Line 138/149 | Line 336 (single cleanup, always reached before Return) |
| `$hService` — OpenService fails | Never opened | No close needed (line 180 ContinueLoop) |
| `$hService` — QueryServiceStatus fails | Line 164/182 | Line 198 |
| `$hService` — already STOPPED | Line 164/182 | Line 211 |
| `$hService` — STOP_PENDING at query | Line 164/182 | Added to `$aPendingHnd`; closed at line 303 (stopped) or line 331 (timeout) |
| `$hService` — not stop-eligible | Line 164/182 | Line 232 |
| `$hService` — ControlService fails | Line 164/182 | Line 258 |
| `$hService` — ControlService accepted | Line 164/182 | Added to `$aPendingHnd`; closed at line 303 (stopped) or line 331 (timeout) |

No leaks identified. The SCM-open-failure path (lines 143–148) returns before `$hSCM` is assigned; no close needed.

**SPEC-008** | PASS | REQ-006 | @error captured immediately after each DllCall

All DllCall sites verified:

| Line | DllCall | @error capture line |
|---|---|---|
| 138–141 | OpenSCManagerW | 142 (`Local $iScmDllErr = @error`) |
| 164–167 | OpenServiceW | 168 (`Local $iSvcDllErr = @error`) |
| 189–191 | QueryServiceStatus (Phase 1) | 192 (`Local $iQryDllErr = @error`) |
| 198 | CloseServiceHandle | Not checked — intentional per standard |
| 211 | CloseServiceHandle | Not checked — intentional |
| 232 | CloseServiceHandle | Not checked — intentional |
| 240–243 | ControlService | 244 (`Local $iCtrlDllErr = @error`) |
| 258 | CloseServiceHandle | Not checked — intentional |
| 285–287 | QueryServiceStatus (Phase 2) | 288 (`Local $iPollDllErr = @error`) |
| 303 | CloseServiceHandle | Not checked — intentional |
| 331 | CloseServiceHandle | Not checked — intentional |
| 336 | CloseServiceHandle | Not checked — intentional |
| 359–361 | QueryServiceStatus (_SM_GetServiceState) | 362 (`Local $iDllErr = @error`) |

No violations. Fully compliant.

**SPEC-009** | PASS | REQ-007 | `"handle"` type string used for all SC_HANDLE parameters
Every SC_HANDLE return type and every SC_HANDLE input parameter uses `"handle"`. No `"long"` appears for handle parameters anywhere in the file.

**SPEC-010** | PASS | REQ-008 | ControlService receives valid SERVICE_STATUS struct
Line 239: `Local $tCtrlStatus = DllStructCreate("dword;dword;dword;dword;dword;dword;dword")` — 7 DWORDs matching `SERVICE_STATUS`. Line 243: passed as `"ptr", DllStructGetPtr($tCtrlStatus)`. No `"str", ""` anti-pattern. Correct.

**SPEC-011** | PASS | REQ-009 | No live stop controls in this module file
`ServiceManager.au3` is a module file. It contains no hardcoded production service names and no test-side calls to `_SM_StopServicesBatch` with real service names. REQ-009 applies to the test harness (`Tests/ServiceManager.Tests.au3`), which is a separate file not under review here.

**SPEC-012** | PASS | Architecture public contract — function signature and defaults
Implemented signature: `Func _SM_StopServicesBatch(ByRef $aServiceNames, $iBatchTimeoutMs = 20000, $iPollIntervalMs = 500)`
Architecture contract: `_SM_StopServicesBatch(ByRef $aNames, $iBatchTimeoutMs, $iPollIntervalMs)` with defaults `$SVC_BATCH_TIMEOUT_MS=20000`, `$SVC_BATCH_POLL_MS=500`.
Parameter names differ slightly (`$aServiceNames` vs `$aNames`) but that is not a contract violation in AutoIt. Default values 20000 and 500 match. Compliant.

**SPEC-013** | PASS | Architecture — empty input array
Lines 116–119: `If $iCount = 0 Then` returns `Local $aEmptyResult[0][6]` without calling `SetError`. @error remains 0. Compliant with architecture specification.

### Summary

| Severity | Count |
|---|---|
| BLOCKER | 0 |
| CRITICAL | 0 |
| MAJOR | 1 (SPEC-001) |
| MINOR | 0 |
| INFORMATIONAL | 1 (SPEC-002) |

---

## Disposition

**APPROVED WITH CONDITIONS**

### Issues that must be resolved before merge

**SPEC-001 (MAJOR)**: The internal helper `_SM_GetServiceState` has a one-parameter signature (`$hService`) that conflicts with the two-parameter signature (`$hAdvapi32, $hService`) documented in `ARCHITECTURE.md`. One of the following must happen before merge:
- Update `ARCHITECTURE.md` to remove the stale `$hAdvapi32` parameter from the helper's documented signature, OR
- Add `$hAdvapi32` as a parameter to the implementation (if the architecture intent was to pass a pre-opened DLL handle for performance).

The function is an internal helper not called from the main script, so there is no runtime breakage today, but the documentation/implementation divergence will cause confusion for future contributors and may trip AU3Check if any generated test stub follows the architecture contract signature.

### Advisory items (should be addressed but do not block merge)

- **STD-001 (MINOR)**: Consider hoisting `$iPendLen` and `$iPendLen2` to the top of the function (or renaming and merging into one variable reused per branch) to avoid repeated `Local` declarations inside loop branches.
- **STD-002 (MINOR)**: Rename `$jj` to a descriptive loop variable name.
- **STD-003/STD-004/STD-005 (INFORMATIONAL)**: The duplicated ReDim pattern and the two never-internally-called helpers are acceptable pending the test harness implementation; re-evaluate at T03 completion.
- **SPEC-002 (INFORMATIONAL)**: Update the header comment of `_SM_Win32ErrToOutcome` to clarify that the 1060 branch is a defensive catch that is not expected from ControlService.

---

**Summary:** 5 Standards findings (1 hard, 4 judgement call), 2 Spec findings; worst Standards issue: MINOR — `Local` redeclaration inside loop branches (STD-001) may surface AU3Check `-w 3` warnings; worst Spec issue: MAJOR — `_SM_GetServiceState` signature (`$hService` only) diverges from `ARCHITECTURE.md` contract (`$hAdvapi32, $hService`) (SPEC-001).
