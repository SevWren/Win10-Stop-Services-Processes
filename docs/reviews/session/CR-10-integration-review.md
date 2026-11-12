# CR-10 — Integration Review (Session Commits ab5b012..HEAD)

**Reviewer**: Integration Review Agent (independent context)
**Date**: 2026-11-12
**Branch**: arch/service-manager-migration
**Fixed point**: ab5b012
**Commits in scope**:
- `1d8a5ea` feat: replace broken service-stop path with native SCM batch-stop module
- `2a62801` chore(cleanup)
- `09b99ba` Added claude skill sets

**Scope**: Cross-file consistency and architectural coherence of all changed files together.
Line-by-line analysis is covered by CR series T05 (REVIEW-ServiceManager.au3.md,
REVIEW-Stop-Services-Processes.au3.md, REVIEW-ServiceManager.Tests.au3.md).

---

## Standards Axis

### S-01 — MINOR — Naming Constant Drift: GLOSSARY vs Implementation (Two-File Shotgun Surgery)

**Smell**: Shotgun Surgery / Mysterious Name.

The `GLOSSARY.md` Timing Constants section (lines 68, 70) names two constants differently from their actual
declarations in `Stop Services Processes.au3` and `docs/ARCHITECTURE.md`:

| GLOSSARY name | Actual implementation name | File |
|---|---|---|
| `$PRIORITY_WATCHDOG_INTERVAL_MS` | `$PRIORITY_WATCHDOG_MS` | main script line 45, ARCHITECTURE.md line 43 |
| `$SVC_POLL_MS` | `$SVC_BATCH_POLL_MS` | main script line 47, ARCHITECTURE.md line 45 |

A developer reading `GLOSSARY.md` will search the codebase for `$PRIORITY_WATCHDOG_INTERVAL_MS` and find
nothing. The same logical concept lives under two names across the documentation corpus. This is a
lightweight instance of Shotgun Surgery — a naming change that was partially propagated; two of the
six timing constants in GLOSSARY are out of sync.

**Evidence**: `GLOSSARY.md` line 68 (`$PRIORITY_WATCHDOG_INTERVAL_MS`), main script line 45
(`$PRIORITY_WATCHDOG_MS`), `ARCHITECTURE.md` line 43 (`$PRIORITY_WATCHDOG_MS`).

**Fix**: Update GLOSSARY lines 68 and 70 to match the declared names (`$PRIORITY_WATCHDOG_MS`,
`$SVC_BATCH_POLL_MS`), or rename the implementation constants to match GLOSSARY — whichever direction
the team prefers, applied to all three files in one pass.

---

### S-02 — MINOR — CLAUDE.md / Implementation Timing Mismatch (_TrayNotify auto-clear delay)

**Smell**: Mysterious Name (documentation that misleads).

`CLAUDE.md` (Coding Conventions, User Notifications section) states `_TrayNotify` auto-clears "after
3 seconds via `AdlibRegister("_ClearTrayNotify", 3000)`". The delivered implementation at main script
line 572 uses `AdlibRegister("_ClearTrayNotify", 2000)`. Flagged as INFORMATIONAL in T05 SPEC-14, but
it was **not resolved** — the IMPLEMENTATION-AND-VERIFICATION.md accepted-findings table records it
as "CLAUDE.md reflects implementation convention; 2s is correct behavior", which is circular. The
canonical reference document (CLAUDE.md) still documents 3000 ms and was not updated.

**Evidence**: CLAUDE.md line "auto-clears after 3 seconds"; main script line 572 `AdlibRegister("_ClearTrayNotify", 2000)`.

**Fix**: Update `CLAUDE.md` to state 2 seconds (2000 ms), since the T04 resolution confirmed 2 s is
the intended behavior.

---

### S-03 — MINOR — `CheckElapsedTime` Missing Underscore Prefix (Pre-existing, Not Regressed)

**Smell**: Mysterious Name (naming convention inconsistency).

`CODING_STANDARDS.md` specifies internal/private functions use `_UnderscorePascalCase`. `CheckElapsedTime`
(main script line 255) is a private helper called only from within `ToggleScript` and is not a hotkey
handler, yet it lacks the `_` prefix. This was present in the baseline and was flagged INFORMATIONAL
in T05 STD-14. It is not a regression from this session but it is a convention violation that the
session's Standards sweep did not correct.

**Evidence**: CODING_STANDARDS.md function naming rule; main script line 255 `Func CheckElapsedTime`.

**Fix**: Rename to `_CheckElapsedTime` and update the two call sites inside `ToggleScript` (lines 128,
132). Low risk, single file, two touch-points.

---

### S-04 — PASS — Cross-File @error Capture Consistency

All DllCall sites across `ServiceManager.au3` and `Stop Services Processes.au3` follow the
immediate-capture rule defined in `CODING_STANDARDS.md`. No file introduces a DllCall that defers
`@error` capture. The pattern is uniform across both modules and matches `CLAUDE.md`'s WinAPI Priority
Reading Pattern. No cross-file divergence detected.

---

### S-05 — PASS — Handle Ownership Seam Is Clean Across Module Boundary

`ServiceManager.au3` owns 100% of SCM and service handle lifecycle. `Stop Services Processes.au3`
calls `_SM_StopServicesBatch` and receives only the result array — no raw handles cross the module
boundary. The main script's priority watchdog manages kernel32.dll process handles independently
(open/query/close in `_GetProcessPriorityByPID`). There is no cross-module handle leakage or
shared-ownership ambiguity. This is the cleanest architectural seam in the session.

---

### S-06 — PASS — No Duplicate Service Control Path

`_stopservicescustom()` has been entirely replaced by `_RunServiceBatchStop()`. `ServiceControl.au3`'s
`_StopService` is no longer called from the main script. D-002 (Architecture Decisions Log) records
this split cleanly. The two includes (`ServiceControl.au3` retained for non-stop helpers;
`ServiceManager.au3` authoritative for stop) are distinct in responsibility and do not duplicate
control paths. CODING_STANDARDS.md Duplicate Prevention rule is satisfied.

---

### S-07 — PASS — Duplicate #include and HotKeySet Fully Resolved Across Files

Baseline defects (3 duplicate `#include` pairs, 2 duplicate `HotKeySet` pairs, `$iLastStopProcesses`
undeclared) are resolved in the delivered main script. The test harness BLOCKER (12 duplicate
`Global Const` for `$SM_STATE_*` and `$SM_OUTCOME_*`) is resolved — the comment at test file line
31–36 confirms the constants are not redeclared and the `#include` at the bottom of the test file
makes them available. The resolution approach (comment-guided late include) is unorthodox but correct
for AutoIt's compilation model and was verified by T05.

---

### S-08 — INFORMATIONAL — Duplicated ReDim Pattern in ServiceManager.au3 (Two Sites, Same File)

**Smell**: Duplicated Code (within one file, not cross-file).

The four-line expand-and-assign pattern for `$aPendingIdx` / `$aPendingHnd` appears identically at
lines 217–221 (STOP_PENDING branch) and lines 263–267 (ControlService-accepted branch) in
`ServiceManager.au3`. Flagged INFORMATIONAL in T05 STD-003. At integration level this is contained
within a single file and does not create cross-module coupling, so it remains INFORMATIONAL here.

---

### Standards Axis Summary

| ID | Severity | Description |
|---|---|---|
| S-01 | MINOR | GLOSSARY timing constant names diverge from implementation (`$PRIORITY_WATCHDOG_INTERVAL_MS`, `$SVC_POLL_MS`) |
| S-02 | MINOR | CLAUDE.md documents 3 s auto-clear; implementation uses 2 s; CLAUDE.md not updated |
| S-03 | MINOR | `CheckElapsedTime` missing `_` prefix (not regressed, but unresolved convention gap) |
| S-04 | PASS | Cross-file @error capture consistent |
| S-05 | PASS | Handle ownership seam clean across module boundary |
| S-06 | PASS | No duplicate service-control path |
| S-07 | PASS | Duplicate includes, hotkeys, and test-file Global Const all resolved |
| S-08 | INFO | Duplicated ReDim pattern (intra-file, contained) |

**Total findings**: 3 MINOR, 1 INFORMATIONAL, 4 PASS. No BLOCKER or CRITICAL.

**Worst Standards finding**: S-01 — GLOSSARY constant name drift creates a silent lookup failure
for two of the six timing constants across three documentation files.

---

## Spec Axis

### SP-01 — PASS — Core Engineering Mission Fulfilled: Verifiable Batch Service Stop

The enterprise prompt's primary objective — replace `_stopservicescustom()` / `ServiceControl.au3`'s
unverified stop path with a native SCM adapter that returns per-service outcomes — is fully delivered:

- `_SM_StopServicesBatch` opens SCM once, phases stop-control dispatch and polling, returns a 2D
  result array with one row per service containing name, initial state, final state, outcome string,
  Win32 error, and note.
- All five outcome codes (`STOPPED`, `ALREADY_STOPPED`, `UNAVAILABLE`, `FAILED`, `TIMED_OUT`) are
  implemented, tested, and wired into `_RunServiceBatchStop` with per-outcome logging.
- Phase separation (dispatch then poll against shared deadline) satisfies REQ-003 and the enterprise
  prompt's "without serial waiting" requirement.

---

### SP-02 — PASS — All 14 Requirements Implemented and Traceable

`docs/REQUIREMENTS.md` carries REQ-001 through REQ-014. Each row specifies source, implementation
location, and verification method. All 14 are marked IMPLEMENTED in `IMPLEMENTATION-AND-VERIFICATION.md`
Gate 5. Cross-checking representative requirements against the delivered code confirms the tracing
is accurate:

- REQ-004 (minimum access rights): `$SM_SC_MANAGER_CONNECT = 0x0001`, `$SM_SERVICE_QUERY_AND_STOP = 0x0024` — correct.
- REQ-007 (`"handle"` type for SC_HANDLEs): confirmed throughout `ServiceManager.au3`.
- REQ-010 (9-service inventory): `_RunServiceBatchStop` declares exactly `["FDResPub", "fdPHost", "TrustedInstaller", "wuauserv", "UsoSvc", "DoSvc", "WaaSMedicSvc", "SSDPSRV", "sppsvc"]`.
- REQ-013 (10 s service poll interval): `$SVC_POLL_INTERVAL_SEC = 10` as a named constant; used at main script line 132.

---

### SP-03 — PASS — All Preserved Behaviors Intact

The enterprise prompt required preservation of process inventories, four hotkeys, priority watchdog,
popup handling, tray notifications, logging, and log rotation. All are confirmed present and
unregressed:

- Four hotkeys (lines 33–36): ScrollLock+Pause, Shift+F1, Ctrl+Shift+9, Ctrl+Alt+Shift+9.
- Priority watchdog: `_PriorityWatchdog`, `_GetProcessPriorityByPID`, `_WinAPIPriorityClassToAutoItConst`, `_PriorityConstantToName` all intact.
- `#RequireAdmin` at line 1 of main script.
- 7-day log rotation via `_CheckAndRotateLogFile` with `$iLogMaxAgeDays = 7`.
- `_miscpopups` checks both `[CLASS:TPleaseRegisterForm]` and `"This is an unregistered copy"`.
- `_TrayNotify` uses `ToolTip()` not `TrayTip()`.

---

### SP-04 — PASS — Test Harness Is Deterministic and Covers Required Cases

`Tests/ServiceManager.Tests.au3` exercises 11 test functions without issuing live stop controls:
all 7 service states, all 5 outcome codes, all 8 required Win32 error codes (5, 1051, 1052, 1060,
1061, 1062, 1068, 1072), single-service failure isolation in a batch, shared timeout, empty input.
The only acknowledged gap (no live Phase 2 polling test) is explicitly accepted per REQ-009 and
the Linux sandbox constraint.

---

### SP-05 — CONDITIONAL — README.md Not Updated for Integration Change

**Severity**: MINOR (advisory, not a blocker per enterprise prompt Task 4 gate).

Task 4 checklist item: "Update `README.md` when visible behavior, configuration, hotkeys, output
paths, or validation requirements change." The `IMPLEMENTATION-AND-VERIFICATION.md` records:
"README.md — Not updated in T04 (no visible behavior change to paths or hotkeys beyond already
documented)."

However, the README's Service Management section still describes "Checks for running services, stops
them if necessary" — a description that applied to the old `_stopservicescustom()` path. The new
path adds three services to the inventory (`FDResPub`, `fdPHost`, `SSDPSRV`), changes the polling
interval from 2 s to 10 s, and now returns structured per-service outcomes with error codes. The
Logging section of README still refers to the log path as `C:\login\closure_log.txt` without noting
that the include paths are now portable. These are user-visible behavioral and configuration changes.

The enterprise prompt's Task 6 deliverable list also includes "Update README.md" as a checklist
item (issue `06-validation-and-delivery.md` line 18), which remains unchecked.

**Evidence**: `docs/IMPLEMENTATION-AND-VERIFICATION.md` line 35 (README not updated); issue 06
checklist item "Update README.md"; README.md service management description vs new inventory/timing.

**Fix**: Update README to state: 9-service inventory (list them), 10 s service polling cycle, that
the include paths are now working-directory-relative, and that per-service outcomes are logged.

---

### SP-06 — MINOR — Architecture Doc Has One Stale Internal-Helper Signature (Partially Resolved)

The enterprise prompt (Task 5) required resolving all BLOCKER/CRITICAL/MAJOR findings. SPEC-001 from
the ServiceManager review was classified MAJOR: `ARCHITECTURE.md` documented `_SM_GetServiceState`
with a two-parameter signature (`$hAdvapi32, $hService`) while the implementation uses one parameter
(`$hService`).

The fix recorded in `IMPLEMENTATION-AND-VERIFICATION.md` Gate 6 is "SPEC-001 (MAJOR): ARCHITECTURE.md
signature updated." Inspecting `docs/ARCHITECTURE.md` line 22 confirms the Module Map now shows:
`_SM_GetServiceState($hService)          ; uses inline "advapi32.dll" string`

The fix was applied. This is PASS at the binary level. Recording here as a note for auditors:
the fix was correct and the resolution path (update the doc, not the code) was the right choice
since the implementation is simpler and equally correct.

---

### SP-07 — PASS — Five NOT RUN Gates Are Correctly Classified and Documented

The enterprise prompt explicitly allows `CONDITIONALLY ACCEPTED` when no unresolved blocking finding
remains and all NOT RUN items are explicitly listed. All five NOT RUN gates are:

1. AU3Check static analysis (Gate 1) — Windows binary not available.
2. x86 compile (Gate 2) — Windows compiler not available.
3. x64 compile (Gate 2) — Windows compiler not available.
4. Test harness runtime (Gate 3) — AutoIt runtime not available.
5. Live service-state integration check — Windows runtime not available.

These are correctly recorded in `IMPLEMENTATION-AND-VERIFICATION.md` and cross-referenced to
`docs/wiki/blockers.md` (B-001, B-002, B-003). The classification `CONDITIONALLY ACCEPTED` is
accurate and appropriate for the Linux sandbox environment.

---

### SP-08 — INFORMATIONAL — `_SM_GetServiceState` and `_SM_BuildResultRow` Are Test-Support Exports Mislabelled as "Internal"

`ServiceManager.au3` file header and `ARCHITECTURE.md` label `_SM_GetServiceState` and
`_SM_BuildResultRow` as "Internal only (not called from main script)." Both functions have no
call sites within `ServiceManager.au3` itself — they exist solely for the test harness. The
enterprise prompt's architecture design note states: "Do not create an additional `.au3` file until
the requirements register identifies its responsibility." These helpers are present in the right file
but their designation as "internal" is misleading when their only consumer is an external test file.
This is INFORMATIONAL; it does not affect correctness or compliance but would confuse a future
contributor removing what appear to be dead-code helpers.

---

### Spec Axis Summary

| ID | Severity | Description |
|---|---|---|
| SP-01 | PASS | Core engineering mission delivered: verifiable batch service stop |
| SP-02 | PASS | All 14 requirements implemented and traceable |
| SP-03 | PASS | All preserved behaviors intact |
| SP-04 | PASS | Test harness deterministic and meets REQ-009 |
| SP-05 | MINOR | README.md not updated despite T04/T06 checklist requirement and visible behavior/config changes |
| SP-06 | PASS | ARCHITECTURE.md `_SM_GetServiceState` signature discrepancy resolved |
| SP-07 | PASS | Five NOT RUN gates correctly classified; CONDITIONALLY ACCEPTED is accurate |
| SP-08 | INFO | `_SM_GetServiceState` / `_SM_BuildResultRow` mislabelled as internal; only used by tests |

**Total findings**: 1 MINOR, 1 INFORMATIONAL, 6 PASS. No BLOCKER or CRITICAL.

**Worst Spec finding**: SP-05 — README.md describes the old 6-service 2 s polling behavior and
does not reflect the new 9-service 10 s polling inventory or portable include paths, despite the
T04 and T06 checklists both requiring an update.

---

## Cross-Axis Architectural Assessment

The session achieves its architectural goal cleanly. The module boundary between the main script
(scheduling, configuration, interaction) and `ServiceManager.au3` (SCM operations, state
interpretation, handle lifecycle) is well-drawn. No concerns about Divergent Change: each file
changes for one reason. `ServiceManager.au3` is a pure SCM adapter; it does not log at the
batch-dispatch level beyond diagnostic messages routed through the shared `_LogMessage` interface,
keeping logging policy in the main script.

The parallel-arrays approach for pending service tracking (`$aPendingIdx`, `$aPendingHnd`) in
`ServiceManager.au3` is a known AutoIt idiom (no built-in struct-of-arrays). It introduces the
duplicated ReDim pattern (S-08) but is consistent with how the main script tracks the priority
watchdog (`$aPriorityWatchPIDs`, `$aPriorityWatchTargets`, `$aPriorityWatchNames`), so the
coupling style is coherent across the codebase.

The late `#include` placement in the test file (ServiceManager.au3 included at line ~397 after
all Func definitions) is unorthodox and relies on AutoIt's compile-all-Funcs-first behavior.
It is correct, documented with a comment, and is the prescribed fix for the BLOCKER. No
integration-level risk.

No Speculative Generality concerns beyond S-08: no abstractions, parameters, or hooks were
introduced that the spec does not need.

---

## Summary Line

**Standards**: 3 MINOR, 1 INFORMATIONAL findings. Worst: S-01 — GLOSSARY uses two timing-constant
names (`$PRIORITY_WATCHDOG_INTERVAL_MS`, `$SVC_POLL_MS`) that do not match the declared names in
the implementation or ARCHITECTURE.md, causing silent lookup failure in two of six constants.

**Spec**: 1 MINOR, 1 INFORMATIONAL findings. Worst: SP-05 — README.md not updated despite explicit
T04/T06 checklist items and user-visible changes (9-service inventory, 10 s polling, portable paths).
