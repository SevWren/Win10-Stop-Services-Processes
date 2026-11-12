# CR2-34 — Final Mission Alignment Review

**Reviewer**: Second-Pass Integration Review Agent (independent context)
**Date**: 2026-11-12
**Branch**: arch/service-manager-migration
**Source documents read**:
- `Enterprise-Grad_Multi-Agent_Engineering_Implementation_Testing_Adversarial_Audit_AutoIt_prompt.md` (the original mission)
- `docs/IMPLEMENTATION-AND-VERIFICATION.md` (overall verdict and evidence record)
- `Includes/ServiceManager.au3` (delivered SCM module)
- `Stop Services Processes.au3` (modified entry point)
- `Tests/ServiceManager.Tests.au3` (deterministic test harness)
- `docs/BASELINE-INVENTORY.md` (T01 baseline record)
- `docs/reviews/session/CR-10-integration-review.md` (prior cross-file integration review)
- `docs/reviews/REVIEW-ServiceManager.au3.md` (T05 per-file review)
- `docs/ARCHITECTURE.md`, `docs/REQUIREMENTS.md`, `GLOSSARY.md`, `docs/wiki/blockers.md`
- `docs/adr/` (ADR-0001 through ADR-0010)
- `docs/domain-modeling/proposals/` (DM-01 through DM-10)

---

## Review Scope

This review answers seven specific questions and renders a final mission-alignment verdict on the totality of the codebase, documentation, and evidence record. It does not repeat line-by-line analysis already performed in T05 and CR-10; it cross-checks the enterprise mission checklist against the delivered artefacts and identifies what remains between CONDITIONALLY ACCEPTED and ACCEPTED.

---

## Question 1 — Core Mission: Replace Broken `_stopservicescustom` Path

**Finding: DONE**

The baseline (`docs/BASELINE-INVENTORY.md`) documents three root defects in the old path:

1. `_ServiceRunning()` used `SERVICE_CONTROL_INTERROGATE` to test state — unreliable against protected services that reject the control even when running.
2. `_StopService()` returned on control-accepted, not on service-stopped — a stop request was treated as proof of a stop.
3. `ControlService` received `"str", ""` as the `lpServiceStatus` parameter instead of a valid `SERVICE_STATUS` struct pointer — undefined behavior and the proximate cause of unreliable stopping.

All three defects are addressed in `Includes/ServiceManager.au3`:

- State is queried with `QueryServiceStatus` (not `INTERROGATE`), via a correct 7-DWORD `DllStructCreate` struct.
- Stop control is dispatched in Phase 1 without serial waiting; Phase 2 polls against a shared deadline until `dwCurrentState` reaches `SERVICE_STOPPED` (state integer 1) — not until the control is accepted.
- `ControlService` receives `DllStructGetPtr($tCtrlStatus)` as `"ptr"` with a properly allocated 7-DWORD structure.

The integration point in `Stop Services Processes.au3` is `_RunServiceBatchStop()` (line 237), which replaces the former `_stopservicescustom()` call. `ServiceControl.au3`'s `_StopService` is no longer called from the main script. The module boundary is clean: `ServiceManager.au3` owns all SCM and service handle lifecycle; the main script receives only the result array.

---

## Question 2 — All 9 Required Services in Target List

**Finding: CONFIRMED**

The enterprise mission specifies exactly these nine services:

> `FDResPub`, `fdPHost`, `TrustedInstaller`, `wuauserv`, `UsoSvc`, `DoSvc`, `WaaSMedicSvc`, `SSDPSRV`, `sppsvc`

The delivered configuration block in `Stop Services Processes.au3` (lines 84–86):

```autoit
Global $aSvcTargetNames[9] = [ _
    "FDResPub", "fdPHost", "TrustedInstaller", "wuauserv", _
    "UsoSvc", "DoSvc", "WaaSMedicSvc", "SSDPSRV", "sppsvc"]
```

This is a word-for-word match of all nine names in the same order as the enterprise prompt. Count: 9. No additions, removals, or renames.

**Context note**: The baseline repository (`main` branch before this migration) listed only six services (`TrustedInstaller`, `wuauserv`, `UsoSvc`, `DoSvc`, `WaaSMedicSvc`, `sppsvc`) declared locally inside `_stopservicescustom()`. The three additions (`FDResPub`, `fdPHost`, `SSDPSRV`) are sourced from the enterprise prompt's configured inventory and from the zip-extracted version referenced in `docs/BASELINE-INVENTORY.md`. REQ-010 (`docs/REQUIREMENTS.md`) records this delta explicitly. The addition is documented and traceable.

---

## Question 3 — `ServiceManager.au3` Is a Proper Deep Module with Structured Outcomes

**Finding: DONE**

The module delivers the full contract specified by the enterprise mission (Task 3 public contract):

**Public interface** (`_SM_StopServicesBatch`):
- Takes a ByRef 1D array of service names, batch timeout (default 20 000 ms), and poll interval (default 500 ms).
- Returns a 2D array `[n][6]` with one row per input service containing: `[0]` name, `[1]` initial state integer, `[2]` final state integer, `[3]` outcome string, `[4]` Win32 error code, `[5]` human-readable note.
- Sets `@error=1` on SCM open failure (batch-level); `@error=0` on per-service-only failures.

**All five outcome codes** are implemented and exercised:
- `STOPPED` — service reached state 1 during Phase 2 polling.
- `ALREADY_STOPPED` — state was 1 at first query (no control sent) or Win32 error 1062.
- `UNAVAILABLE` — `OpenServiceW` returned Win32 error 1060.
- `FAILED` — control rejected or query failed (errors 5, 1051, 1052, 1061, 1068, 1072, and others).
- `TIMED_OUT` — service remained in a non-stopped state after the batch deadline.

**All seven service states** are interpreted and routed:
- State 1 (STOPPED): `_SM_StateToAlreadyStopped` → `ALREADY_STOPPED`, handle closed, loop continues.
- State 2 (START_PENDING): `_SM_IsStopEligible` returns False, `_SM_StateNeedsPolling` returns False → `FAILED` with Win32 1061, handle closed.
- State 3 (STOP_PENDING): `_SM_StateNeedsPolling` returns True → added to pending list, polled in Phase 2.
- States 4, 5, 6, 7 (RUNNING, CONTINUE_PENDING, PAUSE_PENDING, PAUSED): `_SM_IsStopEligible` returns True → `ControlService` issued, then polled.

**Two-phase design** satisfies the "batch dispatch without serial waiting" requirement: Phase 1 iterates all services and issues stop controls without blocking; Phase 2 polls all pending services against one shared deadline using a backward-iterating shrinking-array pattern. A failure for one service in Phase 1 does not prevent Phase 1 work for subsequent services (each service has its own `ContinueLoop` path).

**Handle ownership** is unambiguous: every `OpenServiceW` success has exactly one `CloseServiceHandle` call reachable from every exit path. `$hSCM` is closed after all per-service handles are resolved. The `CloseServiceHandle` for a timed-out service is in the post-Phase-2 timeout sweep, not abandoned.

**Minimum access rights** are enforced: `SC_MANAGER_CONNECT` (0x0001) for the SCM handle; `SERVICE_QUERY_STATUS | SERVICE_STOP` (0x0024) for service handles. No broader rights requested.

**`"handle"` type strings** are used for all SC_HANDLE and HANDLE DllCall parameters throughout, correcting the `"long"` truncation defect in `ServiceControl.au3`.

---

## Question 4 — Deterministic Test Harness

**Finding: DONE**

`Tests/ServiceManager.Tests.au3` delivers 11 test functions covering 42 individual assertions (based on code inspection of all `_TestAssert` calls). The harness structure satisfies REQ-009 (no live stop controls):

**Pure-logic tests (no SCM calls)**:
- `_Test_ServiceStateToString` — all 7 valid states plus 3 out-of-range values (0, -1, 99).
- `_Test_Win32ErrToOutcome` — all 8 required Win32 error codes from the enterprise mission (5, 1051, 1052, 1060, 1061, 1062, 1068, 1072) plus an unknown-error default.
- `_Test_IsStopEligible` — all 7 states classified for stop eligibility.
- `_Test_BuildResultRow` — 6-column layout verified including the UNAVAILABLE `-1` state variant.
- `_Test_SingleFailureInBatch` — failure isolation: one FAILED row does not corrupt adjacent STOPPED rows.
- `_Test_SharedTimeout` — TIMED_OUT outcome with correct final state preserved.
- `_Test_StateToOutcomeRouting` — ALREADY_STOPPED routing and STOP_PENDING mutual-exclusivity of routing predicates.
- `_Test_AllSevenStates` — all 7 states covered via predicate calls, confirming REQ-002.
- `_Test_UnavailableInBatch` — UNAVAILABLE alongside STOPPED in a 2-service simulated result.

**SCM integration tests (open SCM, issue no stop controls)**:
- `_Test_EmptyInput` — calls `_SM_StopServicesBatch` with empty array; verifies `@error=0` and row count 0.
- `_Test_ResultArrayDimensions` — calls with 2 nonsensical names; verifies row count, column count, name preservation, and UNAVAILABLE outcome from Win32 1060.
- `_Test_BatchUnknownServices` — calls with 3 nonsensical names; verifies per-row name, outcome, win32, and both state columns for the Phase 1 UNAVAILABLE path.

The harness resolves the BLOCKER identified in T05 (duplicate `Global Const` declarations for `$SM_STATE_*` and `$SM_OUTCOME_*`) by not redeclaring these constants — the `#include "Includes\ServiceManager.au3"` appears at line 500 (after all Func definitions) and makes the constants available at call time, exploiting AutoIt's compile-all-funcs-first compilation model. This is documented in the file header.

**One acknowledged gap**: There is no live Phase 2 polling test — no test exercises the scenario where a service receives a stop control and transitions from STOP_PENDING to STOPPED. This is explicitly accepted under REQ-009 (no live stop controls) and the Linux sandbox constraint (B-003 in `docs/wiki/blockers.md`). The gap is correctly classified as INFORMATIONAL (SPEC-009 in the T05 review).

---

## Question 5 — All Existing Behaviors Preserved

**Finding: DONE**

Cross-checking the enterprise mission's preservation requirements against the delivered `Stop Services Processes.au3`:

| Required behavior | Delivery status | Evidence |
|---|---|---|
| `#RequireAdmin` | Present | Line 1 |
| `Shift+F1` → `ToggleScript()` | Present | Line 34 |
| `ScrollLock+Pause` → `_exit()` | Present | Line 33 |
| `Ctrl+Shift+9` → `SetProcessPriority()` | Present | Line 35 |
| `Ctrl+Alt+Shift+9` → `LockProcessPriority()` | Present | Line 36 |
| Hotkey registration (no duplicate) | Present — baseline duplicates removed | Lines 33–36, 4 unique registrations |
| `_PriorityWatchdog()` with TOCTOU re-check | Present | Lines 467–516 |
| `_GetProcessPriorityByPID()` with direct DllCall | Present | Lines 530–551 |
| `_WinAPIPriorityClassToAutoItConst()` | Present | Lines 558–575 |
| Process inventory (18 entries, `$sProcesses[]`) | Present, preserved as-is | Lines 96–100 |
| `xgamehelper.exe` duplicate preserved | Present | Indices 15 and 16, with comment |
| `_LogMessage()` with 3 levels, file + console | Present | Lines 269–285 |
| 7-day log rotation | Present | `$iLogMaxAgeDays = 7`, `_CheckAndRotateLogFile` |
| `_MiscPopups()` both popup checks | Present | Lines 623–631 |
| `_TrayNotify()` via `ToolTip()` not `TrayTip` | Present | Lines 607–615 |
| AdlibRegister intervals as named constants | Present and improved | Lines 42–47 |
| Process polling at 2 seconds | Present | `$PROC_POLL_INTERVAL_SEC = 2` |
| Service polling at 10 seconds | Present | `$SVC_POLL_INTERVAL_SEC = 10` |
| Priority watchdog at 10 seconds | Present | `$PRIORITY_WATCHDOG_MS = 10000` |
| Real-time priority never automatic | Present — `LockProcessPriority` requires explicit user input of "5" |
| Portable working-directory paths | Present — all include/build paths migrated | Gate 4 in IMPLEMENTATION-AND-VERIFICATION.md |
| No duplicate `#include` lines | Present — 3 baseline duplicates removed | Lines 18–27 |

**One minor inconsistency noted (from CR-10 S-02)**: `CLAUDE.md` documents `_TrayNotify` auto-clear as 3 seconds; the implementation uses 2 seconds. The T04 resolution confirmed 2 s is correct, but `CLAUDE.md` was not updated. This is a documentation-only issue (MINOR, not a behavior regression).

---

## Question 6 — Documentation Complete

**Finding: SUBSTANTIALLY COMPLETE; TWO MINOR GAPS REMAIN**

The enterprise mission's File Map required: `docs/BASELINE-INVENTORY.md`, `docs/REQUIREMENTS.md`, `docs/ARCHITECTURE.md`, `docs/IMPLEMENTATION-AND-VERIFICATION.md`, and per-file reviews.

**Delivered and present**:

| Required document | File | Status |
|---|---|---|
| Baseline inventory | `docs/BASELINE-INVENTORY.md` | Present — covers all source files, baseline defects, toolchain, timing values, service/process inventories |
| Requirements register | `docs/REQUIREMENTS.md` | Present — REQ-001 through REQ-014 with source, implementation, verification, and evidence |
| Architecture document | `docs/ARCHITECTURE.md` | Present — module interfaces, DllCall contracts, timing constants, handle ownership rules |
| Implementation and verification | `docs/IMPLEMENTATION-AND-VERIFICATION.md` | Present — 6 gates with status and evidence, acceptance verdict |
| Per-file review: ServiceManager.au3 | `docs/reviews/REVIEW-ServiceManager.au3.md` | Present — APPROVED WITH CONDITIONS; all blocking findings resolved |
| Per-file review: Stop Services Processes.au3 | `docs/reviews/REVIEW-Stop-Services-Processes.au3.md` | Present — APPROVED WITH CONDITIONS; all blocking findings resolved |
| Per-file review: ServiceManager.Tests.au3 | `docs/reviews/REVIEW-ServiceManager.Tests.au3.md` | Present — APPROVED WITH CONDITIONS; BLOCKER resolved |
| GLOSSARY | `GLOSSARY.md` | Present at repo root |
| ADRs | `docs/adr/0001` through `0010` | Present — 10 ADRs covering module extraction, state eligibility, error conventions, API selection, handle scoping, priority constants, timing |
| Wiki | `docs/wiki/index.md`, `environment.md`, `decisions.md`, `blockers.md` | Present |

**Beyond the minimum file map**, the session also delivered: `CODING_STANDARDS.md`, `docs/domain-modeling/` (10 proposals + glossary sections + cross-reference validation + implementation report + domain model), `docs/research/` (windows-scm-api.md, autoit-dllcall.md), and `docs/reviews/session/` (CR-01 through CR-10 session reviews).

**Two minor gaps** carried forward from CR-10:

1. **README.md not updated** (CR-10 SP-05, MINOR): The enterprise prompt Task 4 and Task 6 checklists both require updating README.md when visible behavior, configuration, or validation requirements change. Three changes are undocumented in README: the 9-service inventory (vs. 6 in baseline), the 10-second polling cycle (vs. 2 seconds), and the portable include paths. The current README still describes the old behavior. This is not a blocking enterprise-mission requirement (the mission's acceptance criteria do not list README coverage as a gate condition), but it is an open checklist item.

2. **GLOSSARY timing constant names drift** (CR-10 S-01, MINOR): `GLOSSARY.md` names two timing constants (`$PRIORITY_WATCHDOG_INTERVAL_MS`, `$SVC_POLL_MS`) that do not match the declared names in the implementation (`$PRIORITY_WATCHDOG_MS`, `$SVC_BATCH_POLL_MS`) or `docs/ARCHITECTURE.md`. A developer searching the codebase for the GLOSSARY-documented names will find nothing.

Neither gap constitutes a BLOCKER, CRITICAL, or MAJOR finding. Both are MINOR.

---

## Question 7 — What Would It Take to Move from CONDITIONALLY ACCEPTED to ACCEPTED?

The enterprise mission's acceptance criteria (Task 6, final paragraph) state:

> `ACCEPTED` requires all mandatory checks to have passed, all material files to have final-hash independent approvals, and no unresolved blocking finding.

The five NOT RUN gates documented in `IMPLEMENTATION-AND-VERIFICATION.md` are the only barrier. All are Windows-toolchain dependencies unavailable in the Linux sandbox. Each gate and its specific requirements follow.

### Gate 1 — AU3Check Static Analysis

**Command to run on Windows**:
```
Au3Check.exe -q -d -w 1 -w 2 -w 3 -w 4 "Stop Services Processes.au3"
Au3Check.exe -q -d -w 1 -w 2 -w 3 -w 4 "Includes\ServiceManager.au3"
Au3Check.exe -q -d -w 1 -w 2 -w 3 -w 4 "Tests\ServiceManager.Tests.au3"
```

**Required outcome**: Exit code 0, no warnings, for all three files.

**Pre-conditions already addressed by the delivered source**:
- `$iLastStopProcesses` declared as `Global $iLastStopProcesses = 0`.
- 3 duplicate `#include` pairs removed.
- 2 duplicate `HotKeySet` pairs removed.
- `Global Const` redefinition conflict in the test file resolved (constants not redeclared; sourced via late `#include`).
- `$iPendLen2` renamed to `$iPendLen` (reused), eliminating the second `Local` declaration in the loop body.
- `$jj` renamed to `$iTimeoutIdx`.

**Residual risk**: AU3Check's behavior with `Local` declared inside a loop body (even once per iteration) under `-w 3`/`-w 4` is not fully deterministic without running the tool. The T05 review (STD-001) assessed this as likely not an error, but the gate is NOT RUN until confirmed by tool output.

**To pass**: Paste the verbatim tool output (command, all warnings/errors, exit code) into Gate 1 of `docs/IMPLEMENTATION-AND-VERIFICATION.md`. If new warnings appear, resolve them and re-run. Each resolve-and-rerun cycle invalidates the per-file reviews and requires re-review of the affected files at their new hash.

### Gate 2 — Compile x86 and x64

**Command to run on Windows**:
```
AutoIt3Wrapper.exe /in "Stop Services Processes.au3" /x86
AutoIt3Wrapper.exe /in "Stop Services Processes.au3" /x64
```

**Required outcome**: Both compilers exit cleanly; output artifact at `.\release\Stop Services - Processes.exe` (portable relative path, confirmed by Gate 4).

**To pass**: Record compiler path, version, command, exit code, output artifact path, and any warnings in Gate 2 of `docs/IMPLEMENTATION-AND-VERIFICATION.md`. If the compiler emits warnings, treat them as AU3Check-equivalent findings and resolve before accepting.

### Gate 3 — Test Harness Runtime

**Command to run on Windows**:
```
AutoIt3.exe "Tests\ServiceManager.Tests.au3"
```

**Required outcome**: Exit code 0 (`ALL TESTS PASSED`). The harness is designed to open the Windows SCM for `_Test_EmptyInput`, `_Test_ResultArrayDimensions`, and `_Test_BatchUnknownServices` — these require Windows and an active SCM, which is why `#RequireAdmin` is at the top of the test file. All three SCM-touching tests use deliberately nonsensical service names, ensuring no stop controls are issued.

**Expected test count**: 42 assertions across 11 functions (based on code inspection). A passing run will print the full assertion log to stdout/console.

**To pass**: Record the full console output (every PASS/FAIL line and the summary line) in Gate 3 of `docs/IMPLEMENTATION-AND-VERIFICATION.md`. If any test fails, it represents a correctness defect in the module under test; resolve and re-run. A test failure at Gate 3 would likely elevate to a MAJOR or CRITICAL finding, invalidate the ServiceManager.au3 file review, and require re-review at the corrected hash.

**Partial note**: If the test run reveals that AU3Check produces warnings that required source changes (from Gate 1), re-run the test harness after those changes. Gates 1 and 3 interact if any source change is made between them.

### Additional Step After All Three Gates Pass: Re-confirm File Review Hashes

The enterprise mission requires that final-hash independent approvals exist for all material `.au3` files. The existing reviews (`REVIEW-ServiceManager.au3.md`, `REVIEW-Stop-Services-Processes.au3.md`, `REVIEW-ServiceManager.Tests.au3.md`) record SHA-256 hashes of the files as reviewed. If Gates 1 or 3 require any source change, those hashes will be invalidated and the affected file review must be repeated for the new hash. The review process is:

1. Compute new SHA-256 for the modified file.
2. Dispatch an independent reviewer (not the implementation agent).
3. Reviewer inspects the full final file at the new hash and either confirms the previous findings still apply or issues new findings.
4. Record the updated hash and reviewer decision in the review document.

If no source changes are required by Gates 1 and 3, the existing review hashes remain valid and no re-review is needed. In that scenario, all three file reviews are already at APPROVED WITH CONDITIONS with all conditions resolved, and the transition to ACCEPTED is complete upon recording Gate 1, 2, and 3 evidence in `docs/IMPLEMENTATION-AND-VERIFICATION.md`.

### Summary Path to ACCEPTED

```
1. Check out the branch on Windows (AutoIt 3.3.16.1 or later, Au3Check, AutoIt3Wrapper installed).
2. Run Gate 1 (Au3Check × 3 files). Record output verbatim. If warnings: fix, re-run, re-review affected files.
3. Run Gate 2 (AutoIt3Wrapper x86 + x64). Record output verbatim. If warnings: fix, re-run.
4. Run Gate 3 (AutoIt3.exe test harness). Record full console output verbatim.
   If tests fail: diagnose, fix, re-run Gates 1–3 on changed files, re-review changed files.
5. If no source changes were required: update IMPLEMENTATION-AND-VERIFICATION.md Gate 1, 2, 3 sections
   with verbatim tool output and change outcome from CONDITIONALLY ACCEPTED to ACCEPTED.
6. If source changes were required: repeat the per-file review for each changed .au3 file at its new hash,
   then update IMPLEMENTATION-AND-VERIFICATION.md and change outcome to ACCEPTED.
```

No architectural changes, no new requirements, and no re-scoping are anticipated. The source is written to satisfy AU3Check by construction. The highest-probability Gate 1 risk is the `Local $iPendLen` redeclaration-in-loop pattern (T05 STD-001); if AU3Check flags it, the fix is trivial (declare once before the loop) and would not change observable behavior.

---

## Overall Verdict

The codebase meets the enterprise mission at every substantive level. The mission's core objective is delivered: the broken `_stopservicescustom` path is replaced by a native SCM batch-stop module that correctly queries state, dispatches stop controls without serial waiting, polls against a shared deadline, and returns a structured per-service result for each of the nine required services. All existing behaviors are preserved and verified by code inspection. The documentation corpus — REQUIREMENTS, ARCHITECTURE, GLOSSARY, ADRs, wiki, and per-file reviews — is complete and internally consistent, with two MINOR naming/update gaps that do not affect correctness or compliance.

The gap between the current outcome (CONDITIONALLY ACCEPTED) and ACCEPTED is narrow and entirely mechanical: it requires a Windows developer to run three gates (Au3Check, compile, test harness), record the verbatim output, and update `docs/IMPLEMENTATION-AND-VERIFICATION.md`. No code changes are anticipated to be necessary, though the AU3Check loop-scoped `Local` pattern carries a small residual risk that could require a one-line fix and re-review.

**Mission alignment verdict: CONDITIONALLY ACCEPTED — READY FOR WINDOWS TOOLCHAIN GATES**
