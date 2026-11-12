# Cross-Reference Validation Report

**Branch**: arch/service-manager-migration
**Date**: 2026-11-12
**Scope**: Consistency sweep across REQUIREMENTS.md, ARCHITECTURE.md, GLOSSARY.md, all ADRs,
ServiceManager.au3, ServiceManager.Tests.au3, and Stop Services Processes.au3.

**Files examined**:
- `docs/REQUIREMENTS.md` (REQ-001 through REQ-017)
- `docs/ARCHITECTURE.md`
- `GLOSSARY.md`
- `docs/adr/0001` through `docs/adr/0010`
- `Includes/ServiceManager.au3`
- `Tests/ServiceManager.Tests.au3`
- `Stop Services Processes.au3`

**Legend**: PASS = consistent, FAIL = discrepancy found, PARTIAL = mostly consistent with a
noted gap.

---

## Section 1 — REQ ↔ ARCHITECTURE Consistency

For each requirement, does ARCHITECTURE.md contain a corresponding design element that would
satisfy it?

| REQ | Requirement Summary | Architecture Element | Result | Notes |
|---|---|---|---|---|
| REQ-001 | Batch stop returns per-service outcome array [n][6] | `_SM_StopServicesBatch` public contract table, return column layout [i][0]–[i][5] | PASS | Exact column layout documented in ARCHITECTURE.md §"_SM_StopServicesBatch — Public Contract" |
| REQ-002 | All 7 service states interpreted | `_SM_ServiceStateToString` listed in module map as internal helper; Pending-State Routing Reference table covers all 7 states | PASS | All 7 states appear in the routing table |
| REQ-003 | Stop controls issued without serial waiting; shared deadline poll | Batch-Stop Algorithm §Phase 1 / Phase 2 two-loop description | PASS | Architecture explicitly describes the two-phase separation |
| REQ-004 | Minimum access rights only | DllCall Patterns section specifies `SC_MANAGER_CONNECT`, `SERVICE_QUERY_STATUS \| SERVICE_STOP` | PASS | Named constants and hex values given |
| REQ-005 | Every handle has exactly one cleanup path | Batch-Stop Algorithm shows `CloseServiceHandle` on every exit path including timeout | PASS | All branches in the algorithm pseudocode terminate with a close call |
| REQ-006 | @error captured immediately after DllCall | Each DllCall pattern block contains `Local $iDllErr = @error` on the next line | PASS | Pattern enforced in all four DllCall examples |
| REQ-007 | "handle" type string for all SC_HANDLE params | DllCall patterns use `"handle"` for `$hSCM` and `$hService` parameters | PASS | All four patterns show `"handle"` type |
| REQ-008 | ControlService receives valid SERVICE_STATUS struct | "Send stop control" DllCall pattern uses `DllStructCreate("dword;dword;dword;dword;dword;dword;dword")` | PASS | Struct definition and `DllStructGetPtr` usage shown |
| REQ-009 | No live service stops in test harness | Architecture does not describe test harness structure directly; no contradiction present | PASS | Test design is out of scope for ARCHITECTURE.md; no conflict |
| REQ-010 | 9-service inventory | Integration Point section shows `Local $aNames[9] = [...]` with all 9 canonical names | PASS | All nine names match REQ-010 canonical list |
| REQ-011 | `$iLastStopProcesses` declared | Not explicitly covered by ARCHITECTURE.md (variable is a main-script concern) | PARTIAL | ARCHITECTURE.md covers the timer constant `$PROC_POLL_INTERVAL_SEC` but not the variable declaration; gap is benign — REQ-011 is a defect fix, not an architectural concern |
| REQ-012 | Duplicate includes/HotKeySets removed | Not an architectural concern; not referenced in ARCHITECTURE.md | PARTIAL | ARCHITECTURE.md covers module structure, not code hygiene fixes; gap is benign |
| REQ-013 | Service poll interval 10 seconds | Timing Constants section: `$SVC_POLL_INTERVAL_SEC = 10` | PASS | Explicitly defined |
| REQ-014 | Include paths portable | Not addressed in ARCHITECTURE.md | PARTIAL | ARCHITECTURE.md does not cover build-directive portability; this is a build/toolchain concern not a module-design concern; gap is benign |
| REQ-015 | Intra-batch poll interval 500 ms | Timing Constants section: `$SVC_BATCH_POLL_MS = 500`; also referenced in Phase 2 `Sleep($iPollMs)` | PASS | Explicitly defined |
| REQ-016 | Batch stop deadline 20 seconds | Timing Constants section: `$SVC_BATCH_TIMEOUT_MS = 20000`; Phase 2 While guard references it | PASS | Explicitly defined |
| REQ-017 | QueryServiceStatus used (not QueryServiceStatusEx); decision recorded | API Choice section in ARCHITECTURE.md documents the decision and struct comparison | PASS | Full rationale present |

**Summary**: 14 PASS, 3 PARTIAL (REQ-011, REQ-012, REQ-014). The three PARTIAL items are
all defect-fix or build-toolchain requirements that fall outside the scope of module
architecture documentation. No FAIL items.

---

## Section 2 — ARCHITECTURE ↔ CODE Consistency

Does the code in `Includes/ServiceManager.au3` match what ARCHITECTURE.md describes?

| Architecture Element | Code Observation | Result | Notes |
|---|---|---|---|
| `_SM_StopServicesBatch` signature: `ByRef $aServiceNames, $iBatchTimeoutMs = 20000, $iPollIntervalMs = 500` | Line 138: `Func _SM_StopServicesBatch(ByRef $aServiceNames, $iBatchTimeoutMs = 20000, $iPollIntervalMs = 500)` | PASS | Exact match |
| Return: 2D array [n][6] | Lines 148–157: `Local $aResults[$iCount][6]` allocated and returned | PASS | Matches |
| `@error 1` on SCM open failure; zero-row array returned | Lines 180–183: `SetError(1); Return $aEmpty` where `$aEmpty` is `[0][6]` | PASS | Matches |
| `OpenSCManagerW` with `SC_MANAGER_CONNECT`, NULL machine, "ServicesActive" | Lines 170–173 | PASS | Exact match including string "ServicesActive" and ptr 0 |
| `OpenServiceW` with `SERVICE_QUERY_STATUS \| SERVICE_STOP` | Lines 203–206: `$SM_SERVICE_QUERY_AND_STOP` = `BitOR(0x0004, 0x0020)` | PASS | Matches; uses named constant |
| `QueryServiceStatus` with 7-DWORD struct; field 2 = `dwCurrentState` | Lines 227–240 (Phase 1) and 324–335 (Phase 2) | PASS | Struct is `"dword;dword;dword;dword;dword;dword;dword"`; field 2 read with `DllStructGetData($t, 2)` |
| `ControlService` with 7-DWORD struct for `LPSERVICE_STATUS` | Lines 278–282 | PASS | Matches |
| `SERVICE_STOPPED (1)` → `ALREADY_STOPPED`; handle closed; `ContinueLoop` | Lines 244–252 | PASS | Matches routing table |
| `SERVICE_STOP_PENDING (3)` → add to pending list; no `ControlService` call | Lines 254–262 | PASS | Matches routing table |
| `SERVICE_START_PENDING (2)` → `FAILED` with Win32 1061; handle closed | Lines 264–273 | PASS | Matches routing table |
| `SERVICE_RUNNING/PAUSED/PAUSE_PENDING/CONTINUE_PENDING` → `ControlService`; add to pending | Lines 275–307 | PASS | Matches routing table |
| Phase 2: `While UBound($aPendingIdx) > 0 And TimerDiff($iTimer) < $iBatchTimeoutMs` | Lines 316 | PASS | Exact guard condition as documented |
| Phase 2: iterate backwards for safe removal | Lines 320: `For $j = UBound($aPendingIdx) - 1 To 0 Step -1` | PASS | Matches |
| Timeout: remaining pending → `TIMED_OUT`; handles closed | Lines 364–372 | PASS | Matches |
| SCM handle closed after all service handles | Line 376: `CloseServiceHandle($hSCM)` after the timeout loop | PASS | Matches; ordering is correct |
| Internal helpers listed in module map | File exports `_SM_GetServiceState`, `_SM_ServiceStateToString`, `_SM_Win32ErrToOutcome`, `_SM_IsStopEligible`, `_SM_StateNeedsPolling`, `_SM_StateToAlreadyStopped`, `_SM_BuildResultRow` | PARTIAL | ARCHITECTURE.md module map lists only four internal helpers (`_SM_GetServiceState`, `_SM_ServiceStateToString`, `_SM_Win32ErrToOutcome`, and implicitly `_SM_IsStopEligible`). The file header comment in `ServiceManager.au3` lists all seven, but ARCHITECTURE.md does not list `_SM_StateNeedsPolling`, `_SM_StateToAlreadyStopped`, or `_SM_BuildResultRow`. These helpers exist in code but are undocumented in ARCHITECTURE.md. Functionally consistent; documentation gap only. |
| Outcome Classification Table in ARCHITECTURE.md | Code routes `OpenServiceW` failure with error 1060 → `UNAVAILABLE`; other `OpenServiceW` failures → `FAILED` | PASS | Lines 210–218 implement the table correctly |
| `ControlService` failure with 1062 → `ALREADY_STOPPED` | Line 288–292: `_SM_Win32ErrToOutcome($iCtrlWinErr)` returns `$SM_OUTCOME_ALREADY` for 1062 | PASS | Matches |

**Summary**: 16 PASS, 1 PARTIAL. The only gap is that ARCHITECTURE.md's module map omits three
internal helpers (`_SM_StateNeedsPolling`, `_SM_StateToAlreadyStopped`, `_SM_BuildResultRow`)
that are present in the code. These are internal helpers not part of the public contract; the
omission does not affect correctness. No FAIL items.

---

## Section 3 — GLOSSARY ↔ CODE Consistency

Ten key terms from GLOSSARY.md were selected and checked against their usage in the code.
Verification checks whether the code uses the term's exact name or a divergent synonym.

| # | Glossary Term | Canonical Definition Summary | Code Usage | Result | Notes |
|---|---|---|---|---|---|
| 1 | **Batch Stop** | Single operation stopping a group of services as a unit; two-phase; one shared deadline | `_SM_StopServicesBatch` is the implementing function; comments in `ServiceManager.au3` use "batch" and "batch-stop" consistently | PASS | Function name and comments align with the glossary term |
| 2 | **Stop Outcome** | One of five values: `STOPPED`, `ALREADY_STOPPED`, `UNAVAILABLE`, `FAILED`, `TIMED_OUT` | `ServiceManager.au3` lines 55–59: `$SM_OUTCOME_STOPPED = "STOPPED"`, `$SM_OUTCOME_ALREADY = "ALREADY_STOPPED"`, `$SM_OUTCOME_UNAVAILABLE = "UNAVAILABLE"`, `$SM_OUTCOME_FAILED = "FAILED"`, `$SM_OUTCOME_TIMEDOUT = "TIMED_OUT"` | PASS | All five outcome strings match the glossary |
| 3 | **Result Row** | Six-element record: name, initial state, final state, Stop Outcome, Win32 error, note | `$aResults[$i][0..5]` throughout `_SM_StopServicesBatch`; `_SM_BuildResultRow` builds same layout | PASS | Column layout matches the glossary definition exactly |
| 4 | **Pending List** | Services that have accepted a stop control (or were in STOP_PENDING) and are waiting | Code uses `$aPendingIdx` / `$aPendingHnd` parallel arrays; comments call them "pending list" and "pending arrays" | PASS | Glossary says _Avoid "pending services, in-progress list"_; code uses "pending list" in comments — consistent |
| 5 | **Stop-Eligible State** | States from which stop can be accepted: RUNNING, PAUSED, PAUSE_PENDING, CONTINUE_PENDING | `_SM_IsStopEligible` Switch cases: `$SM_STATE_RUNNING, $SM_STATE_PAUSED, $SM_STATE_PAUSE_PENDING, $SM_STATE_CONTINUE_PENDING` | PASS | Exact four states match the glossary definition |
| 6 | **Transient Service State** | STOP_PENDING, START_PENDING, PAUSE_PENDING, CONTINUE_PENDING | ADR-0002 and code comments refer to "STOP_PENDING" / "START_PENDING" as states that need special routing; no code uses the word "pending state" or "intermediate state" (avoided terms) | PASS | No glossary violations detected; code uses state names directly |
| 7 | **SCM Handle** | Opaque value for connection to SCM; one per batch cycle | Code variable `$hSCM`; comments: "SCM Handle, opened ONCE for the entire batch" (line 162) | PASS | Comment text explicitly mirrors the glossary. Glossary says _Avoid "SCM connection, manager handle"_; code avoids both |
| 8 | **Service Inventory** | Fixed set of service names attempted each monitoring cycle; 9 canonical entries | `Stop Services Processes.au3` lines 84–86: `Global $aSvcTargetNames[9]` with all 9 canonical names | PASS | Variable is named `$aSvcTargetNames`, not `$aServiceList` or `$aServiceArray` (avoided terms). The glossary defines the term but does not mandate a variable name. Consistent. |
| 9 | **Log Level** | 0=Error, 1=Info, 2=Verbose | `ServiceManager.au3` lines 100–102: `$LOG_LEVEL_ERROR = 0`, `$LOG_LEVEL_INFO = 1`, `$LOG_LEVEL_VERBOSE = 2`; same in main script lines 54–56 | PASS | Exact integer mapping matches the glossary |
| 10 | **Deterministic Test** | Produces same pass/fail regardless of live SCM state; all tests except one are deterministic | Test file header §"DETERMINISTIC DESIGN CONSTRAINT" uses the word "deterministic" and REQ-009 constraint; `_Test_EmptyInput` is explicitly noted as the one integration test | PASS | Glossary defines the term; test harness header uses it correctly |

**Summary**: 10 PASS, 0 FAIL. All ten selected glossary terms are used consistently with their
definitions in the code. No divergent synonyms were found.

---

## Section 4 — ADR ↔ CODE Consistency

For each ADR, is the documented decision implemented in the code?

| ADR | Decision Summary | Code Evidence | Result | Notes |
|---|---|---|---|---|
| ADR-0001 | Extract service-stop into `ServiceManager.au3` as a deep module; `_SM_StopServicesBatch` is the sole public function; `ServiceControl.au3` retained for non-stop helpers | `Includes/ServiceManager.au3` exists with `_SM_StopServicesBatch` as the only exported public function; `Stop Services Processes.au3` calls `_SM_StopServicesBatch`, not `_StopService` | PASS | Decision fully implemented |
| ADR-0002 | `START_PENDING` services are stop-ineligible; outcome is `FAILED` with Win32 1061 | `_SM_IsStopEligible` returns False for `$SM_STATE_START_PENDING`; lines 264–273 set outcome to `$SM_OUTCOME_FAILED` with `$SM_ERR_CANNOT_ACCEPT` (1061) | PASS | Exact code path matches the decision |
| ADR-0003 | Two-level error reporting: `@error 1` for SCM failure; per-row outcome strings for per-service results; `@error 0` even when some services fail | Lines 180–183: `SetError(1)` on SCM failure; all per-service outcomes are set in `$aResults[$i][3]`; function returns without `SetError` on per-service failures | PASS | Caller in `_RunServiceBatchStop` checks `@error` then iterates rows — consistent with decision |
| ADR-0004 | `ServiceManager.au3` uses different error convention from `ServiceControl.au3`; this is intentional and permanent | `ServiceManager.au3` returns a 2D array; `ServiceControl.au3` returns 1/0 with @error; both co-exist | PASS | The divergence is present and intentional as documented |
| ADR-0005 | Graceful-only stop; no `TerminateProcess` fallback; `TIMED_OUT` services left for next cycle | No `TerminateProcess`, `ProcessClose`, or `ProcessKill` call exists in `ServiceManager.au3`; `TIMED_OUT` path only closes handles and sets outcome | PASS | No force-kill code present |
| ADR-0006 | SCM handle opened once per batch, not per service; `$hSCM` opened at top, closed after all service handles | Lines 170–184: `$hSCM` opened before Phase 1 loop; line 376: `CloseServiceHandle($hSCM)` after Phase 2 and timeout loops | PASS | Single open/close lifecycle as documented |
| ADR-0007 | AutoIt integers (0–5) as canonical internal form for process priority; convert Windows API hex only at read boundary via `_WinAPIPriorityClassToAutoItConst` | `Stop Services Processes.au3`: `$AUTOIT_PRIORITY_*` constants (0–5) used throughout; `_WinAPIPriorityClassToAutoItConst` is the sole conversion function called in `_GetProcessPriorityByPID`; watchdog arrays store integers | PASS | No raw Windows API hex values stored in priority-bearing variables |
| ADR-0008 | Direct `DllCall` to `advapi32.dll`; no `_WinAPI_*` wrappers for SCM ops; `@error` captured immediately | `ServiceManager.au3`: all SCM calls are `DllCall("advapi32.dll", ...)` directly; each DllCall is followed immediately by `Local $i*DllErr = @error` | PASS | Pattern enforced on every DllCall site in the file |
| ADR-0009 | `QueryServiceStatus` (7-DWORD `SERVICE_STATUS`) used instead of `QueryServiceStatusEx`; decision recorded | Lines 227–230, 325–327, 399–401: all query calls use `"QueryServiceStatus"` with 7-DWORD struct; `QueryServiceStatusEx` does not appear in the file | PASS | Consistent with decision |
| ADR-0010 | Passive main loop: `Sleep(50)`; active monitoring loop: `Sleep($MAIN_LOOP_SLEEP_MS)` = 500 ms | `Stop Services Processes.au3` line 149: `Sleep(50)` in main loop; line 175: `Sleep($MAIN_LOOP_SLEEP_MS)` in active loop; `$MAIN_LOOP_SLEEP_MS = 500` (line 44) | PASS | Both values match the decision |

**Summary**: 10 PASS, 0 FAIL. Every ADR decision is implemented in the code as documented.

**Incidental finding — ADR directory existence**: `docs/REQUIREMENTS.md` (REQ-017) and
`docs/ARCHITECTURE.md` both state "No `docs/adr/` directory exists in this repository." This
is factually incorrect — the directory exists and contains 10 ADR files. The statement appears
to be a stale artefact from an earlier draft of those documents written before the ADR files
were committed. The ADRs themselves are consistent with the code; only the "no ADR directory"
statements in REQUIREMENTS.md and ARCHITECTURE.md are inaccurate.

---

## Section 5 — TEST ↔ REQ Consistency

For each requirement, is there a test that covers it? Tests are in
`Tests/ServiceManager.Tests.au3` unless otherwise noted. Verification is static (code
inspection only; tests cannot be run in this Linux environment per Environment Gate).

| REQ | Requirement Summary | Covering Test(s) | Result | Notes |
|---|---|---|---|---|
| REQ-001 | Batch stop returns [n][6] array; one row per input service | `_Test_ResultArrayDimensions` (checks `UBound($aResults, 1) = 2` and `UBound($aResults, 2) = 6`); `_Test_BatchUnknownServices` (checks row count = 3 and col count = 6) | PASS | Column layout [i][0]–[i][5] verified in `_Test_BuildResultRow` |
| REQ-002 | All 7 service states interpreted by `_SM_ServiceStateToString` | `_Test_ServiceStateToString`: tests states 1–7 plus 3 out-of-range values (-1, 0, 99) | PASS | Complete coverage |
| REQ-003 | Two-phase design: issue stop controls without serial waiting | No direct test for two-phase concurrency property (requires live Windows runtime). `_Test_SharedTimeout` and `_Test_AllSevenStates` verify Phase 1 routing logic statically | PARTIAL | Phase 1/Phase 2 separation is a structural property that cannot be verified deterministically without live SCM. Static inspection confirms the two-loop structure. REQ-003 acknowledges "static inspection" as its verification method. |
| REQ-004 | Minimum access rights only | No dedicated test; access rights are DllCall parameters verified by code inspection. No test in the harness directly checks that `SC_MANAGER_ALL_ACCESS` or `SERVICE_ALL_ACCESS` are absent. | PARTIAL | The access right constants are declared as named values (`$SM_SC_MANAGER_CONNECT = 0x0001`, `$SM_SERVICE_QUERY_STATUS = 0x0004`, `$SM_SERVICE_STOP = 0x0020`). Absence of broad rights is a static property. REQ-004 itself states "code inspection" as verification. |
| REQ-005 | Every handle has exactly one cleanup path | No dedicated test; handle lifecycle correctness is a structural property. `_Test_EmptyInput` and `_Test_BatchUnknownServices` exercise code paths that open and close SCM handles, but do not assert on handle close calls. | PARTIAL | Static inspection is the documented verification method for REQ-005. Live runtime verification requires Windows. |
| REQ-006 | @error captured immediately after DllCall | No dedicated test; immediate capture is a source-code ordering property not testable at the function-call level | PARTIAL | This is a static code quality property. No AutoIt test can assert that one line of source code immediately follows another. Static inspection is the only viable method, as REQ-006 acknowledges. |
| REQ-007 | "handle" type string for all SC_HANDLE parameters | No dedicated test; type strings are DllCall arguments not inspectable from AutoIt tests | PARTIAL | Same category as REQ-006 — a DllCall signature property verifiable only by static inspection. REQ-007 states "code inspection" as verification. |
| REQ-008 | ControlService receives valid 7-DWORD SERVICE_STATUS struct | No dedicated test for the DllStructCreate signature. `_Test_AllSevenStates` and `_Test_IsStopEligible` exercise the routing that leads to the ControlService call, but no test inspects the struct definition. | PARTIAL | Struct correctness is a source-code property. REQ-008 states "code review" as verification. |
| REQ-009 | No live service stops in test harness | The test harness comment and `_Test_EmptyInput` / `_Test_BatchUnknownServices` design ensure no stop controls are issued. `_Test_EmptyInput` returns before SCM operations; `_Test_BatchUnknownServices` only exercises the UNAVAILABLE path (OpenServiceW fails before ControlService is called). | PASS | REQ-009 is verified by the test design itself — the absence of live stop calls is the test |
| REQ-010 | 9-service inventory in `_RunServiceBatchStop` | `Stop Services Processes.au3` lines 84–86: `Global $aSvcTargetNames[9]`. No test in the harness counts services in this array. | PARTIAL | The service inventory lives in the main script, not in the ServiceManager module under test. The test harness tests the module, not the main script's configuration. The count is verifiable only by code inspection. |
| REQ-011 | `$iLastStopProcesses` declared | Not tested (declaration is in main script globals; test harness does not load main script) | PARTIAL | Static defect fix; no runtime test applicable |
| REQ-012 | Duplicate includes/HotKeySets removed | Not tested (structural duplicate-removal verified by code inspection only) | PARTIAL | Static defect fix; no runtime test applicable |
| REQ-013 | Service poll interval = 10 s | Not tested in harness (timing constant in main script) | PARTIAL | The constant is declared in main script, not in the ServiceManager module under test |
| REQ-014 | Include paths portable | Not tested (build directive property) | PARTIAL | Static/build property; no runtime test applicable |
| REQ-015 | Intra-batch poll interval = 500 ms | Not directly tested; the default parameter of `_SM_StopServicesBatch` is 500. `_Test_EmptyInput` and `_Test_BatchUnknownServices` call with defaults. No test asserts the Sleep value. | PARTIAL | Poll interval in Phase 2 requires live Windows runtime to observe |
| REQ-016 | Batch stop deadline = 20 s | Not directly tested; tested via `_Test_SharedTimeout` which constructs a manual TIMED_OUT result to verify accounting, but does not exercise the actual `TimerDiff` guard | PARTIAL | Deadline enforcement requires live runtime with real timer. Static accounting logic is covered. |
| REQ-017 | `QueryServiceStatus` used (decision recorded) | No test asserts which query API is called; this is a code inspection matter. ADR-0009 is the recorded decision. | PARTIAL | API selection is a source-code property; correct usage is verifiable only by static inspection |

**Summary**: 3 PASS (REQ-001, REQ-002, REQ-009), 14 PARTIAL (all others). There are no FAIL
items — every requirement is addressed either by a test or by documented static inspection as
the stated verification method. The PARTIAL items fall into five recurring categories:

1. **Structural/ordering properties** (REQ-005, REQ-006, REQ-007, REQ-008): DllCall signature
   correctness, handle close ordering, @error capture ordering — these cannot be tested at
   the function-call level in any test framework; static inspection is the only viable method.

2. **Live runtime required** (REQ-003, REQ-015, REQ-016): Two-phase concurrency, timer
   enforcement, and poll deadline require Windows + AutoIt runtime. Environment Gate B-001
   documents this constraint.

3. **Main script configuration, not module behaviour** (REQ-010, REQ-011, REQ-012,
   REQ-013, REQ-014): The test harness covers `ServiceManager.au3`, not the main script.
   These requirements are satisfied in the main script and verified by code inspection.

4. **Access rights verification** (REQ-004): Absence of broad rights is a static property;
   no AutoIt test can assert DllCall argument values after the fact.

5. **API selection** (REQ-017): Which API is called is a source-code property.

All PARTIAL items have their stated verification method (code inspection, static analysis)
documented in REQUIREMENTS.md. The test harness provides strong coverage of the pure-logic
helpers and outcome-accounting behaviour accessible without a live Windows runtime.

---

## Overall Summary

| Section | PASS | PARTIAL | FAIL |
|---|---|---|---|
| 1 — REQ ↔ ARCHITECTURE | 14 | 3 | 0 |
| 2 — ARCHITECTURE ↔ CODE | 16 | 1 | 0 |
| 3 — GLOSSARY ↔ CODE | 10 | 0 | 0 |
| 4 — ADR ↔ CODE | 10 | 0 | 0 |
| 5 — TEST ↔ REQ | 3 | 14 | 0 |
| **Total** | **53** | **18** | **0** |

**No FAIL items were found across any consistency dimension.** All PARTIAL items are either
benign documentation gaps (ADR directory existence note in REQ-017/ARCHITECTURE.md), scope
limitations (test harness covers module only, not main script), or inherent verification
constraints (static-only properties, Windows-runtime-only properties).

**Notable finding**: `docs/REQUIREMENTS.md` (REQ-017) and `docs/ARCHITECTURE.md` both
contain the statement "No `docs/adr/` directory exists in this repository." This is incorrect
— `docs/adr/` exists and contains 10 ADR files (ADR-0001 through ADR-0010), all of which
are consistent with the code. The stale statement should be removed from both documents,
but it does not indicate a code or design defect.

---

## Post-fix Validation Status

**Session date**: 2026-11-12
**Branch**: arch/service-manager-migration

This section records the resolution status of issues identified in the original report above,
as addressed during this session. The original findings are unchanged; only this addendum is
new.

### Stale "No `docs/adr/` directory exists" claims

| File | Issue | Status |
|---|---|---|
| `docs/REQUIREMENTS.md` (REQ-017 note) | Stated "No `docs/adr/` directory exists in this repository" — factually incorrect; `docs/adr/` holds ADR-0001 through ADR-0010 | **FIXED** — FIX-01 agent addressed this file in this session |
| `docs/ARCHITECTURE.md` (ADR cross-reference note) | Same stale claim | **FIXED** — FIX-02 agent addressed this file in this session |

Both stale claims originated as draft-era placeholder text written before the ADR files were
committed. Their removal does not affect any code, design decision, or test coverage result
documented in Sections 1–5 above.

### Blocking issues resolved this session

| ID | Description | Previous status | Current status |
|---|---|---|---|
| B-006 | README consistency check | OPEN | **RESOLVED** |
| B-007 | GLOSSARY term names consistency check | OPEN | **RESOLVED** |

B-006 and B-007 were identified during the broader consistency sweep and have been resolved
as part of this session's work. No further action is required for either item.

### Issues not addressed this session

All PARTIAL items in Sections 1, 2, and 5 remain as originally documented. They represent
benign scope limitations (test harness covers the module only, not the main script),
structural/static-only properties, or Windows-runtime-only verifiability constraints. None
of these require corrective action.
