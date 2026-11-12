# Implementation and Verification
Branch: arch/service-manager-migration
Date: 2026-11-11
Ticket: T06 — Validate, Compile, Deliver Acceptance Report

---

## Changed / Created Files

| File | Status | Action |
|---|---|---|
| `Stop Services Processes.au3` | Modified | Integrated ServiceManager, fixed all baseline defects |
| `Includes/ServiceManager.au3` | Created | Native SCM batch-stop adapter |
| `Tests/ServiceManager.Tests.au3` | Created | Deterministic test harness |
| `CODING_STANDARDS.md` | Created | Reviewer-enforced coding standards |
| `GLOSSARY.md` | Created | Domain vocabulary |
| `docs/BASELINE-INVENTORY.md` | Created | T01 baseline record |
| `docs/REQUIREMENTS.md` | Created | REQ-001 through REQ-014 |
| `docs/ARCHITECTURE.md` | Created | Module interface and DllCall contracts |
| `docs/research/autoit-dllcall.md` | Created | AutoIt DllCall/DllStructCreate research |
| `docs/research/windows-scm-api.md` | Created | Windows SCM API research |
| `docs/reviews/REVIEW-ServiceManager.au3.md` | Created | Independent review — APPROVED WITH CONDITIONS |
| `docs/reviews/REVIEW-Stop-Services-Processes.au3.md` | Created | Independent review — APPROVED WITH CONDITIONS |
| `docs/reviews/REVIEW-ServiceManager.Tests.au3.md` | Created | Independent review — APPROVED WITH CONDITIONS |
| `docs/wiki/index.md` | Created | Chief-of-Staff wiki index |
| `docs/wiki/environment.md` | Created | Pit-of-success improvements |
| `docs/wiki/decisions.md` | Created | Architecture decisions log |
| `docs/wiki/blockers.md` | Created | Known environment blockers |
| `docs/agents/domain.md` | Created | Domain documentation layout |
| `docs/agents/issue-tracker.md` | Created | Issue tracker configuration |
| `.scratch/service-manager-migration/issues/` | Created | 6 ticket markdown files (T01–T06) |
| `.git/hooks/pre-commit` | Created | AU3Check gate reminder hook |
| `Enterprise-Grad_Multi-Agent_Engineering_Implementation_Testing_Adversarial_Audit_AutoIt_prompt.md` | Added | Enterprise implementation plan (from project zip) |
| `.agents/skills/` | Added | Matt Pocock skill set (ask-matt, chief-of-staff, etc.) — outside the spec's File Map; included because it is required by the agent workflow environment that executed this migration. It has no effect on the AutoIt deliverables and is not part of the migration scope. |
| `README.md` | Not updated in T04 (no visible behavior change to paths or hotkeys beyond already documented) |

---

## Verification Gates

### Gate 1 — AU3Check Static Analysis

**Status**: NOT RUN — Windows environment required (see `docs/wiki/blockers.md` B-001)

**Command** (run on Windows with AutoIt installed):
```
Au3Check.exe -q -d -w 1 -w 2 -w 3 -w 4 "Stop Services Processes.au3"
Au3Check.exe -q -d -w 1 -w 2 -w 3 -w 4 "Includes\ServiceManager.au3"
Au3Check.exe -q -d -w 1 -w 2 -w 3 -w 4 "Tests\ServiceManager.Tests.au3"
```

**Expected exit code**: 0 (no warnings at -w 1 through -w 4)

**Why not run**: `Au3Check.exe` is a Windows-only binary; it is not available in the Linux
sandbox. This gate must be run by a Windows developer before merging. Results must be
pasted into this section verbatim (tool output only — no predicted outcomes).

**Baseline defects addressed in source** (pre-conditions for Gate 1 to pass — verified by
code inspection during T04/T05, not by tool output):

| Baseline Issue | Change Made | REQ |
|---|---|---|
| `$iLastStopProcesses` undeclared (-w 1) | Declared `Global $iLastStopProcesses = 0` | REQ-011 |
| Duplicate `#include <WinAPI.au3>` | Removed duplicate pairs | REQ-012 |
| Duplicate `#include <WinAPIProc.au3>` | Removed duplicate pairs | REQ-012 |
| Duplicate `#include <Array.au3>` | Removed duplicate pairs | REQ-012 |
| Duplicate `HotKeySet("+^9", ...)` | Removed duplicate pairs | REQ-012 |
| Duplicate `HotKeySet("^!+9", ...)` | Removed duplicate pairs | REQ-012 |
| Test file `Global Const` redefinition conflict | Removed duplicate const declarations from test file | T05 STD-001 |

These source changes are necessary pre-conditions but are not a substitute for running
the tool. Gate 1 status remains NOT RUN until a Windows developer records actual tool output.

---

### Gate 2 — Compile x86 and x64

**Status**: NOT RUN — Windows environment required

**Command** (run on Windows with AutoIt3Wrapper):
```
AutoIt3Wrapper.exe /in "Stop Services Processes.au3" /x86
AutoIt3Wrapper.exe /in "Stop Services Processes.au3" /x64
```

**Expected output**:
- `.\release\Stop Services - Processes.exe` (x64)
- Path is relative to working directory — portable ✓

**Migration from baseline**:
- `#AutoIt3Wrapper_Outfile_x64` changed from `..\..\..\Users\mmuel\Desktop\Stop Services - Processes.Exe`
  to `.\release\Stop Services - Processes.exe`
- `#AutoIt3Wrapper_Res_Icon_Add` changed from absolute path to `ff7.ico` (relative)

---

### Gate 3 — Test Harness

**Status**: NOT RUN — Windows environment required

**Command**:
```
AutoIt3.exe "Tests\ServiceManager.Tests.au3"
```

**Expected exit code**: 0 (all tests pass)

**Test coverage (11 test functions, verified by T05 code review)**:

| Test | Coverage |
|---|---|
| `_Test_ServiceStateToString` | All 7 states + 3 out-of-range |
| `_Test_Win32ErrToOutcome` | 8 required Win32 error codes |
| `_Test_IsStopEligible` | All 7 states classified |
| `_Test_BuildResultRow` | Column layout [0]–[5] |
| `_Test_ResultArrayDimensions` | 2D array structure |
| `_Test_SingleFailureInBatch` | Failure isolation |
| `_Test_SharedTimeout` | TIMED_OUT accounting |
| `_Test_StateToOutcomeRouting` | ALREADY_STOPPED, polling, eligible routing |
| `_Test_AllSevenStates` | REQ-002 — all 7 states covered |
| `_Test_EmptyInput` | Empty array → empty result, @error=0 |
| `_Test_UnavailableInBatch` | UNAVAILABLE alongside STOPPED |

**Win32 error codes tested**: 5, 1051, 1052, 1060, 1061, 1062, 1068, 1072 ✓

**Live SCM calls**: None in deterministic tests. Only `_Test_EmptyInput` calls
`_SM_StopServicesBatch` — with an empty array, which returns before opening SCM.

---

### Gate 4 — Portable Path Contract

**Status**: VERIFIED (static inspection)

Checked all paths in `Stop Services Processes.au3`:

| Path | Before | After | Portable? |
|---|---|---|---|
| `#include ServiceControl.au3` | `C:\github\...\Includes\ServiceControl.au3` | `Includes\ServiceControl.au3` | ✓ |
| `#include ServiceManager.au3` | N/A (new file) | `Includes\ServiceManager.au3` | ✓ |
| `#AutoIt3Wrapper_Outfile_x64` | `..\..\..\Users\mmuel\Desktop\...` | `.\release\Stop Services - Processes.exe` | ✓ |
| `#AutoIt3Wrapper_Res_Icon_Add` | `C:\github\...\ff7.ico` | `ff7.ico` | ✓ |
| `$iconfile` | `@ScriptDir & "\ff7.ico"` | unchanged (already portable) | ✓ |
| `$sLogFile` | `@HomeDrive & "\login\closure_log.txt"` | unchanged (acceptable) | ✓ |

All touched paths are now portable. Moving the project directory requires no source edits.

---

### Gate 5 — Requirement Rows Updated

| REQ | Status | Evidence |
|---|---|---|
| REQ-001 | IMPLEMENTED | `_SM_StopServicesBatch` returns [n][6] array; T05 review SPEC-003; result-row column layout (columns [0]–[5]: service name, initial state, final state, outcome, Win32 error, note) defined in `GLOSSARY.md` §Result Row and `docs/ARCHITECTURE.md` §_SM_StopServicesBatch return contract |
| REQ-002 | IMPLEMENTED | All 7 states in `_SM_ServiceStateToString`; T05 review SPEC-004 |
| REQ-003 | IMPLEMENTED | Phase 1/2 two-loop design; T05 review SPEC-005 |
| REQ-004 | IMPLEMENTED | Minimum access rights; T05 review SPEC-006 |
| REQ-005 | IMPLEMENTED | Handle trace complete; T05 review SPEC-007 |
| REQ-006 | IMPLEMENTED | @error capture verified; T05 review SPEC-008 |
| REQ-007 | IMPLEMENTED | "handle" type strings; T05 review SPEC-009 |
| REQ-008 | IMPLEMENTED | 7-DWORD DllStruct; T05 review SPEC-010 |
| REQ-009 | IMPLEMENTED | No live SCM calls in tests; T05 review SPEC-001 |
| REQ-010 | IMPLEMENTED | 9 services in `_RunServiceBatchStop`; T05 review SPEC-011 |
| REQ-011 | IMPLEMENTED | `Global $iLastStopProcesses = 0`; T05 review STD-05 |
| REQ-012 | IMPLEMENTED | Duplicate includes/HotKeySets removed; T05 review STD-03/STD-04 |
| REQ-013 | IMPLEMENTED | `$SVC_POLL_INTERVAL_SEC = 10`; T05 review SPEC-04 |
| REQ-014 | IMPLEMENTED | Relative include/build paths; T05 review SPEC-05 |
| REQ-015 | IMPLEMENTED | `$SVC_BATCH_POLL_MS = 500` in config region; `Sleep($iPollIntervalMs)` in Phase 2 of `_SM_StopServicesBatch` |
| REQ-016 | IMPLEMENTED | `$SVC_BATCH_TIMEOUT_MS = 20000` in config region; `TimerDiff($iTimer) < $iBatchTimeoutMs` guard in Phase 2 |
| REQ-017 | IMPLEMENTED | Decision recorded in `docs/adr/0009-queryservicestatus-api-selection.md`; 7-DWORD struct used throughout `ServiceManager.au3` |

---

### Gate 6 — Code Review Final Status

| File | Reviewer | Disposition | Blocking Findings Resolved? |
|---|---|---|---|
| `Includes/ServiceManager.au3` | T05 Independent Agent | APPROVED WITH CONDITIONS | Yes — SPEC-001 (MAJOR): ARCHITECTURE.md signature updated |
| `Stop Services Processes.au3` | T05 Independent Agent | APPROVED WITH CONDITIONS | Yes — STD-06/STD-13 (MINOR): `_miscpopups` now uses `_LogMessage` |
| `Tests/ServiceManager.Tests.au3` | T05 Independent Agent | APPROVED WITH CONDITIONS | Yes — STD-001 (BLOCKER): duplicate `Global Const` removed |

All conditions resolved. No unresolved BLOCKER, CRITICAL, or MAJOR findings remain.

---

## Preserved Behaviors (verified by T04/T05)

| Feature | Status |
|---|---|
| `#RequireAdmin` | ✓ Preserved |
| `Shift+F1` → `ToggleScript()` | ✓ Preserved |
| `ScrollLock+Pause` → `_exit()` | ✓ Preserved |
| `Ctrl+Shift+9` → `SetProcessPriority()` | ✓ Preserved |
| `Ctrl+Alt+Shift+9` → `LockProcessPriority()` | ✓ Preserved |
| `_PriorityWatchdog()` with TOCTOU re-check | ✓ Preserved |
| `_GetProcessPriorityByPID()` with direct DllCall | ✓ Preserved |
| `_WinAPIPriorityClassToAutoItConst()` | ✓ Preserved |
| Process inventory (18 entries, `$sProcesses[]`) | ✓ Preserved |
| `_LogMessage()` with 3 levels, file + console | ✓ Preserved |
| 7-day log rotation | ✓ Preserved |
| `_miscpopups()` both popup checks | ✓ Preserved |
| `_TrayNotify()` via `ToolTip()` (not `TrayTip`) | ✓ Preserved |
| AdlibRegister intervals as named constants | ✓ Improved (was hardcoded) |

---

## Accepted Minor/Informational Findings

Per the enterprise prompt: `MINOR` and `INFORMATIONAL` findings are accepted with rationale.

| ID | Finding | Rationale for Acceptance |
|---|---|---|
| STD-001 (ServiceManager) | `$iPendLen`/`$iPendLen2` local in loop | Functional correctness unaffected; AU3Check will not flag this as an error |
| STD-003 (ServiceManager) | Duplicated ReDim pattern | Two sites only; extracting helper would add complexity for marginal gain |
| STD-004/STD-005 (ServiceManager) | Never-internally-called helpers | Intentionally exported for test harness; noted in file header |
| STD-002 (ServiceManager) | Renamed `$jj` → `$iTimeoutIdx` | RESOLVED |
| STD-006/STD-13 (main script) | `ConsoleWrite` in `_miscpopups` | RESOLVED — replaced with `_LogMessage` |
| SPEC-001 (ServiceManager) | Architecture doc signature | RESOLVED — updated ARCHITECTURE.md |
| STD-001 (Tests) | `Global Const` redefinition | RESOLVED — removed duplicate declarations |
| SPEC-14 (main script) | CLAUDE.md 3s vs actual 2s | CLAUDE.md reflects implementation convention; 2s is correct behavior |
| SPEC-009 (Tests) | No live Phase 2 polling test | Accepted per REQ-009 and Linux environment constraint (B-003) |
| SPEC-013 (main script) | `$SM_OUTCOME_*` constants verified | Confirmed in ServiceManager review (SPEC-003/010) |

---

## Acceptance Decision

**Outcome: CONDITIONALLY ACCEPTED**

### Conditions met:
1. ✓ No unresolved BLOCKER, CRITICAL, or MAJOR findings
2. ✓ All 14 requirement rows implemented
3. ✓ All material `.au3` files have independent code-review approvals for their final revision
4. ✓ No hardcoded machine-specific paths in source
5. ✓ Baseline defects (undeclared variable, duplicate includes/hotkeys, wrong struct type) resolved

### Conditions NOT met (explicitly listed, per enterprise prompt):
1. `NOT RUN` — AU3Check static analysis (Gate 1) — Windows binary not available in Linux sandbox
2. `NOT RUN` — x86 compile (Gate 2) — Windows compiler not available
3. `NOT RUN` — x64 compile (Gate 2) — Windows compiler not available
4. `NOT RUN` — Test harness runtime (Gate 3) — AutoIt runtime not available
5. `NOT RUN` — Live service-state integration check — Windows runtime not available

These are all environmental constraints documented in `docs/wiki/blockers.md` (B-001, B-002, B-003).
The branch is ready for a Windows developer to perform the NOT RUN gates.
