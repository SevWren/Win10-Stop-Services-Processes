# Bug and Issue Tracker

**Repository:** `arch/service-manager-migration`
**Produced by:** BUG-01 through BUG-12 investigation series plus second-pass code review (CR2-01 through CR2-40) and architecture-opportunities survey
**Date:** 2026-11-12
**Owner of this file:** docs/reviews/bugs/BUG-INDEX.md

> **Note on BUG-12**: No BUG-12 report file was produced during the investigation series. The slot covers the cross-file naming and duplicate-constant violations identified by CR2-08. The entry below is derived from that review directly.

---

## Critical (must fix before merge)

### CRIT-01 — `$LOG_LEVEL_*` and `$LOG_TYPE_*` declared in two files simultaneously

| Field | Value |
|---|---|
| **ID** | CRIT-01 |
| **Source** | CR2-08 Findings 3.1 and 3.2; BUG-12 (no report file — derived from CR2-08) |
| **File / line** | `Includes/ServiceManager.au3` lines 100–102, 108–109; `Stop Services Processes.au3` lines 54–56, 60, 62 |
| **Status** | OPEN |
| **Fixer** | Unassigned |

`$LOG_LEVEL_ERROR`, `$LOG_LEVEL_INFO`, `$LOG_LEVEL_VERBOSE`, `$LOG_TYPE_SYSTEM`, and `$LOG_TYPE_SERVICE` carry `Global Const` declarations in both `ServiceManager.au3` and `Stop Services Processes.au3`. Because `ServiceManager.au3` is `#include`d by the main script, both definitions land in the same compilation unit. `AU3Check -w 3 -w 4` flags these as redeclaration warnings, breaking the `CODING_STANDARDS.md` §AU3Check Compliance gate.

The root cause is that `ServiceManager.au3` redeclared the constants so the test harness (`Tests/ServiceManager.Tests.au3`) could compile independently of the main script. The correct long-term fix is a shared `Includes/LogConstants.au3` included by both. The immediate fix acceptable for merge is to remove the five duplicate declarations from `ServiceManager.au3` lines 100–102 and 108–109 and annotate why the test harness must now include the main script (or the new shared file) to compile.

---

### CRIT-02 — `_exit` function name violates `_UnderscorePascalCase` convention

| Field | Value |
|---|---|
| **ID** | CRIT-02 |
| **Source** | CR2-08 Finding 1.1; BUG-12 (no report file — derived from CR2-08) |
| **File / line** | `Stop Services Processes.au3` line 637 (`Func _exit()`); line 33 (`HotKeySet("{ScrollLock}{PAUSE}", "_exit")`) |
| **Status** | OPEN |
| **Fixer** | Unassigned |

`Func _exit()` uses all-lowercase after the underscore. `CODING_STANDARDS.md` §Function Naming requires `_UnderscorePascalCase`; the correct name is `_Exit`. The `HotKeySet` string on line 33 must also be updated to `"_Exit"` when the rename is applied. AU3Check does not catch naming convention violations; the rename must be applied manually. The grep pattern `^Func _[a-z]` applied across all `.au3` files will confirm the fix.

---

## High (fix before next session)

### HIGH-01 — `ServiceControl.au3` missing `#include-once`

| Field | Value |
|---|---|
| **ID** | HIGH-01 |
| **Source** | CR2-07 §S-1; `docs/architecture-opportunities.md` Candidate 2; ADR-0011 (known gap) |
| **File / line** | `Includes/ServiceControl.au3` — top of file (directive absent) |
| **Status** | OPEN |
| **Fixer** | Unassigned |

`ServiceControl.au3` has no `#include-once` directive. Including it more than once in a compilation unit redefines all 51 `Global` constants, triggering duplicate-declaration warnings under `AU3Check -w 3 -w 4`. `ServiceManager.au3` correctly carries `#include-once`; this file does not. ADR-0011 documented the missing directive as a known consequence of the convention-only boundary. Fix: add `#include-once` as the first line.

---

### HIGH-02 — 51 Win32 constants in `ServiceControl.au3` declared `Global` instead of `Global Const`

| Field | Value |
|---|---|
| **ID** | HIGH-02 |
| **Source** | `docs/architecture-opportunities.md` Candidate 2; CR2-07 |
| **File / line** | `Includes/ServiceControl.au3` lines 2–82 |
| **Status** | OPEN |
| **Fixer** | Unassigned |

Every SCM access mask, service control code, service type, start type, and error control value in `ServiceControl.au3` is declared `Global` (mutable). None are ever reassigned; they are fixed Win32 API constants. `ServiceManager.au3` uses `Global Const` for all equivalent constants. The mutable declarations mean `AU3Check -w 3 -w 4` cannot catch accidental overwrite, and any code in the compilation unit can silently corrupt a value like `$SERVICE_STOP` before the `DllCall` that depends on it. Fix: change all 51 `Global` declarations to `Global Const` in a single mechanical pass. Best combined with HIGH-01 (the `#include-once` add) as a single commit.

---

### HIGH-03 — `ServiceControl.au3` uses `"long"` for all Win32 handles — 64-bit handle truncation

| Field | Value |
|---|---|
| **ID** | HIGH-03 |
| **Source** | BUG-07 (`docs/reviews/bugs/BUG-07-servicecontrol-bugs.md`) §Bug B; CR2-07 §S-2 |
| **File / line** | `Includes/ServiceControl.au3` — all six functions; representative: lines 109, 118, 135 |
| **Status** | OPEN |
| **Fixer** | Unassigned |

Every handle-typed parameter and return value in `ServiceControl.au3` uses `"long"` (a 32-bit signed integer) instead of `"handle"` (pointer-sized). On 64-bit Windows — the script's primary target (`#AutoIt3Wrapper_UseX64=y`) — 64-bit handle values are silently truncated to 32 bits, corrupting every `SC_HANDLE` returned by `OpenSCManagerW` and `OpenServiceW`. All subsequent calls using those handles fail silently. No `ServiceControl.au3` function is on the active code path today (all service-stop operations route through `ServiceManager.au3`), so there is no current runtime failure. However, the bug becomes High-severity the moment any of the five non-stop helper functions is called in a 64-bit build. Fix: change `"long"` to `"handle"` for all handle-typed parameters and return types across all six functions. This change must be coordinated with fixing HIGH-04 (the `ControlService` struct bug) in a single pass.

---

### HIGH-04 — `ControlService` called with `"str", ""` instead of `LPSERVICE_STATUS` struct pointer

| Field | Value |
|---|---|
| **ID** | HIGH-04 |
| **Source** | BUG-07 (`docs/reviews/bugs/BUG-07-servicecontrol-bugs.md`) §Bug A; CR2-07 §S-3 |
| **File / line** | `Includes/ServiceControl.au3`: `_StopService` lines 187–190; `_ServiceRunning` lines 276–279 |
| **Status** | OPEN |
| **Fixer** | Unassigned |

Both `_StopService` and `_ServiceRunning` pass `"str", ""` as the third argument to `ControlService`, where the Win32 API requires `LPSERVICE_STATUS` — a pointer to a 7-DWORD `SERVICE_STATUS` struct. The kernel writes the struct to the caller-supplied pointer; a string buffer is too small and the data is inaccessible to AutoIt. Within each function's current contract the missing struct data has no behavioral effect (`_StopService` only reads the BOOL return; `_ServiceRunning` uses the BOOL as its running indicator). However, any future caller needing `dwCurrentState` or `dwWaitHint` after the control call would find the struct unreadable. Fix: introduce `DllStructCreate("dword;dword;dword;dword;dword;dword;dword")` and pass `"ptr", DllStructGetPtr(...)` as the third argument, matching the pattern used throughout `ServiceManager.au3`. Must be combined with HIGH-03.

---

### HIGH-05 — `ToggleScript` guard variable set after `MsgBox` yield — dual monitoring loop on double-press

| Field | Value |
|---|---|
| **ID** | HIGH-05 |
| **Source** | BUG-10 (`docs/reviews/bugs/BUG-10-hotkey-reentrancy.md`) Issue 1 |
| **File / line** | `Stop Services Processes.au3` lines 150–173 (`ToggleScript`) |
| **Status** | OPEN |
| **Fixer** | Unassigned |

`$bScriptRunning = True` is set after the `MsgBox(...)` yield point in the `Else` branch of `ToggleScript`. AutoIt delivers queued hotkeys at yield points. If the user presses `Shift+F1` a second time during the 1-second `MsgBox`, a second invocation of `ToggleScript` is entered while `$bScriptRunning` is still `False`. Both invocations set `$bScriptRunning = True` and enter the `While $bScriptRunning` monitoring loop. Two independent monitoring loops then run simultaneously, calling `_KillProcessList` and `_RunServiceBatchStop` on separate timers with no coordination. Fix: move `$bScriptRunning = True` to the first statement of the `Else` branch (before `MsgBox`), and `$bScriptRunning = False` to the first statement of the `If $bScriptRunning` branch (before `MsgBox`).

---

### HIGH-06 — `_LogMessage` is not re-entrant safe — `AdlibRegister` interrupt can corrupt log entries

| Field | Value |
|---|---|
| **ID** | HIGH-06 |
| **Source** | BUG-09 (`docs/reviews/bugs/BUG-09-log-rotation.md`) §BUG-09-B |
| **File / line** | `Stop Services Processes.au3` lines 264–280 (`_LogMessage`) |
| **Status** | OPEN |
| **Fixer** | Unassigned |

AutoIt `AdlibRegister` callbacks fire between bytecode instructions, including inside `_LogMessage`. If `_PriorityWatchdog` fires between `FileOpen` and `FileWrite` in an outer `_LogMessage` call, the inner `_LogMessage` (from the watchdog) opens a second append handle to the same log file, writes, and closes it. When the outer `_LogMessage` resumes with its still-open handle, its internal file pointer is stale (pointing to the pre-inner-write end-of-file). The outer write then overwrites the watchdog's log entry rather than appending after it, causing silent log data loss. The probability per call is low (microsecond-window interrupt), but cumulative risk is non-trivial under high log volume. Fix: add a boolean re-entrancy guard global that `_LogMessage` checks on entry; if already set, queue or directly write the message after the outer `FileClose`.

---

### HIGH-07 — Parallel watchdog arrays have no `@error` guard on `_ArrayAdd` — desync on memory failure

| Field | Value |
|---|---|
| **ID** | HIGH-07 |
| **Source** | BUG-08 (`docs/reviews/bugs/BUG-08-watchdog-arrays.md`) Finding 2a |
| **File / line** | `Stop Services Processes.au3` lines 447–449 (`LockProcessPriority`) |
| **Status** | OPEN |
| **Fixer** | Unassigned |

Three `_ArrayAdd` calls append to `$aPriorityWatchPIDs`, `$aPriorityWatchTargets`, and `$aPriorityWatchNames` sequentially with no `@error` checks. If any one call fails (e.g., memory pressure), the arrays diverge in size. All subsequent index-parallel reads in `_PriorityWatchdog` assume size parity; on desynced arrays AutoIt silently returns `""` for out-of-range reads, causing `ProcessSetPriority` to receive priority `0` (Idle) instead of the locked target — silent wrong-priority restores. Fix: check `@error` after each `_ArrayAdd` and roll back the preceding successful adds on any failure, or abort `LockProcessPriority` and notify the user.

---

### HIGH-08 — B-004 / B-005: Phase 2 integration test gap and `QueryServiceStatusEx` requirements staleness

| Field | Value |
|---|---|
| **ID** | HIGH-08 |
| **Source** | `docs/wiki/blockers.md` B-004, B-005; `docs/architecture-opportunities.md` Candidate 5 |
| **File / line** | `Tests/ServiceManager.Tests.au3` (gap); `docs/REQUIREMENTS.md` (stale REQ rows); `docs/IMPLEMENTATION-AND-VERIFICATION.md` Gate 1 (predicted assertions) |
| **Status** | OPEN (B-004), OPEN (B-005) |
| **Fixer** | Unassigned — requires Windows environment |

Two related open blockers:

**B-004**: The two-phase batch-stop algorithm in `_SM_StopServicesBatch` — Phase 1 stop dispatch and Phase 2 shared-deadline polling — has zero end-to-end behavioral test coverage. `STOPPED` and `TIMED_OUT` outcomes are never exercised. All assertions about Phase 2 behavior rest on static inspection. A stub-layer approach intercepting `DllCall` sites or a Windows-only integration test against a real benign service (e.g., `W32Time`) is required.

**B-005**: `docs/REQUIREMENTS.md` has no REQ row verifying or confirming the `QueryServiceStatus` API selection (ADR-0009). All 14 REQ rows still carry stale "Implementation pending (T03/T04)" status fields. `docs/IMPLEMENTATION-AND-VERIFICATION.md` Gate 1 contains predicted compliance assertions in a NOT RUN gate, violating the spec's prohibition on predicted outcomes.

---

## Medium (fix when convenient)

### MED-01 — `$sProcesses[18]` declared in `Variables/Logging` region instead of `Configuration — Target lists`

| Field | Value |
|---|---|
| **ID** | MED-01 |
| **Source** | `docs/architecture-opportunities.md` Candidate 1; CR2-38 Check 2; `docs/reviews/second-pass/CR2-38-config-region-audit.md` |
| **File / line** | `Stop Services Processes.au3` lines 93–100 (inside `#Region ;Variables/Logging`) |
| **Status** | OPEN |
| **Fixer** | Unassigned |

`$sProcesses[18]` (the process kill target list) is a user-editable configuration input, identical in nature to `$aSvcTargetNames[9]`. `$aSvcTargetNames` correctly lives in `#Region ;Configuration — Target lists` (line 80). `$sProcesses` sits in the `Variables/Logging` region alongside runtime state (`$bScriptRunning`, `$iLastStopServices`, etc.). This breaks locality: a contributor editing process targets must navigate to the wrong region. Fix: move the `$sProcesses[18]` declaration into the existing `Configuration — Target lists` region (or a sibling block), immediately after `$aSvcTargetNames`. No callers change — variable name is unchanged.

---

### MED-02 — `$PROCESS_IDLE` dead compatibility shim duplicates `$AUTOIT_PRIORITY_IDLE`

| Field | Value |
|---|---|
| **ID** | MED-02 |
| **Source** | BUG-05 (`docs/reviews/bugs/BUG-05-process-idle-shim.md`); CR2-02 §STD-S6 |
| **File / line** | `Stop Services Processes.au3` former line 108 (shim); line 72 (`$AUTOIT_PRIORITY_IDLE`) |
| **Status** | RESOLVED — deleted in BUG-05 fix pass |
| **Fixer** | BUG-05 investigation agent (2026-11-12) |

`Global Const $PROCESS_IDLE = 0` was a compatibility shim added because `$PROCESS_IDLE` was absent from the bundled `AutoItConstants.au3`. After the `$AUTOIT_PRIORITY_*` region was introduced, `$PROCESS_IDLE` was never referenced again. BUG-05 confirmed zero call sites and deleted the declaration. No AU3Check warnings are introduced: removing a declared-but-unused global eliminates a potential lint warning.

---

### MED-03 — `$SM_OUTCOME_ALREADY` / `$SM_OUTCOME_TIMEDOUT` abbreviated names did not match string values

| Field | Value |
|---|---|
| **ID** | MED-03 |
| **Source** | BUG-04 (`docs/reviews/bugs/BUG-04-outcome-names.md`); `docs/architecture-opportunities.md` Candidate 4 |
| **File / line** | `Includes/ServiceManager.au3` lines 55–59 (definitions); `Stop Services Processes.au3` `_RunServiceBatchStop`; `Tests/ServiceManager.Tests.au3` assertions |
| **Status** | RESOLVED — renamed in BUG-04 fix pass |
| **Fixer** | BUG-04 investigation agent (2026-11-12) |

`$SM_OUTCOME_ALREADY` resolved to `"ALREADY_STOPPED"` (name omitted `_STOPPED`); `$SM_OUTCOME_TIMEDOUT` resolved to `"TIMED_OUT"` (name ran words together). Both were renamed to match their string values exactly: `$SM_OUTCOME_ALREADY_STOPPED` and `$SM_OUTCOME_TIMED_OUT`. 11 identifiers renamed across 3 files; no string values or logic changed. All comparisons already used the constant rather than raw strings, so no active silent bug existed — this was a maintenance hazard.

---

### MED-04 — `$taskcloseran` dead global never read or written

| Field | Value |
|---|---|
| **ID** | MED-04 |
| **Source** | BUG-01 (`docs/reviews/bugs/BUG-01-taskcloseran.md`); CR2-29 / CR2-11 Finding 11 |
| **File / line** | `Stop Services Processes.au3` former line 86 (`Global $taskcloseran = 0`) |
| **Status** | RESOLVED — deleted in BUG-01 fix pass |
| **Fixer** | BUG-01 investigation agent (2026-11-12) |

`Global $taskcloseran = 0` was declared in every historical version and never read or written outside its initialization line. It originated as a boolean guard from an earlier linear architecture, made redundant by the `$bScriptRunning` / loop-based design. Confirmed dead across all 19 `BackUp/` snapshots and in the live file. Deletion is safe: no read site, no write site, no function call argument, no cross-file reference.

---

### MED-05 — `_SM_GetServiceState` dead internal helper (Speculative Generality)

| Field | Value |
|---|---|
| **ID** | MED-05 |
| **Source** | BUG-03 (`docs/reviews/bugs/BUG-03-sm-getservicestate.md`); `docs/architecture-opportunities.md` Candidate 3 |
| **File / line** | `Includes/ServiceManager.au3` former lines 382–410 |
| **Status** | RESOLVED — deleted in BUG-03 fix pass |
| **Fixer** | BUG-03 investigation agent (2026-11-12) |

`_SM_GetServiceState($hService)` wrapped a single `QueryServiceStatus` DllCall and was listed as an INTERNAL HELPER in the module header. It had zero callers: not called from `_SM_StopServicesBatch`, not called from the test harness, not called from the main script. The module already inlines the identical DllCall pattern at two points in `_SM_StopServicesBatch` (Phase 1 and Phase 2) for the correct reason — `@error` capture must be immediate and cannot cross a function call boundary safely in AutoIt 3. Function definition (lines 382–410) and its header listing were deleted.

---

### MED-06 — `_StopService` has no deprecation notice directing callers to `ServiceManager.au3`

| Field | Value |
|---|---|
| **ID** | MED-06 |
| **Source** | CR2-07 §SP-3; `docs/domain-modeling/servicecontrol-analysis.md` §3 and §5 |
| **File / line** | `Includes/ServiceControl.au3` lines 148–156 (comment block above `_StopService`) |
| **Status** | OPEN |
| **Fixer** | Unassigned |

The existing comment above `_StopService` says only "This function does not check to see if the service has stopped successfully." `servicecontrol-analysis.md` §3 and ADR-0004 both establish that `_StopService` has been superseded by `_SM_StopServicesBatch` and that callers must use `ServiceManager.au3` for all service-stop operations. No in-source deprecation notice exists to steer future callers. Fix: add a deprecation comment to the `_StopService` header block noting that it is superseded by `_SM_StopServicesBatch` in `Includes/ServiceManager.au3`, per ADR-0011.

---

### MED-07 — `$iPendLen` declared with `Local` inside a `For` loop — AU3Check `-w 3` warning

| Field | Value |
|---|---|
| **ID** | MED-07 |
| **Source** | BUG-02 (`docs/reviews/bugs/BUG-02-ipendlen-redecl.md`); CR2-34 |
| **File / line** | `Includes/ServiceManager.au3` line 199 (inside Phase 1 `For` loop, lines 194–309) |
| **Status** | RESOLVED — moved to function scope in BUG-02 fix pass |
| **Fixer** | BUG-02 investigation agent (2026-11-12) |

`Local $iPendLen` was declared at line 199 inside the Phase 1 `For` loop body. AutoIt's scoping model is function-level; a `Local` declaration inside a loop re-runs the declaration on every iteration, which `AU3Check -w 3` flags as a redeclaration warning. No runtime data bug existed (the variable was always assigned before each read). Fix: move `Local $iPendLen` to before the Phase 1 loop (after the pending tracking array declarations), removing the `Local` keyword from the intra-loop position.

---

### MED-08 — Phase 2 `Sleep` at top of loop causes up to 500 ms overshoot past deadline

| Field | Value |
|---|---|
| **ID** | MED-08 |
| **Source** | BUG-06 (`docs/reviews/bugs/BUG-06-phase2-timeout.md`) §1.6 |
| **File / line** | `Includes/ServiceManager.au3` Phase 2 While loop (line ~316); `Sleep($iPollIntervalMs)` at top of body |
| **Status** | OPEN — no code change required unless strict deadline enforcement is mandated |
| **Fixer** | Unassigned |

The Phase 2 `While` loop evaluates the deadline condition (`TimerDiff($iTimer) < $iBatchTimeoutMs`) at the top of each iteration, then immediately calls `Sleep($iPollIntervalMs)` (500 ms) before any `QueryServiceStatus` calls. The last iteration may enter the loop body when ~19 600 ms has elapsed, sleep for 500 ms (bringing actual elapsed to ~20 100 ms), execute the poll queries, and only then re-evaluate the condition and exit. TIMED_OUT marking occurs at approximately `deadline + one poll interval` (nominally 20 500 ms). The overshoot is bounded, deterministic, and consistent. The practical impact within the 10-second outer monitoring cycle is negligible. Fix if needed: move `Sleep` to the end of the loop body, or use `Min($iPollIntervalMs, $iBatchTimeoutMs - TimerDiff($iTimer))` as the sleep argument.

---

### MED-09 — `WaaSMedicSvc` permanently fails with Win32=5 — no user-facing documentation

| Field | Value |
|---|---|
| **ID** | MED-09 |
| **Source** | BUG-11 (`docs/reviews/bugs/BUG-11-protected-service.md`) |
| **File / line** | `README.md` Known Limitations section; `Includes/ServiceManager.au3` `_SM_Win32ErrToOutcome` |
| **Status** | OPEN |
| **Fixer** | Unassigned |

On Windows 10 1803+, `WaaSMedicSvc` is protected at the kernel level; `ControlService(SERVICE_CONTROL_STOP)` reliably returns `ERROR_ACCESS_DENIED` (Win32=5). The script correctly routes this to a `FAILED` outcome and logs it at `LOG_LEVEL_ERROR` on every 10-second cycle, with no user notification beyond the log. Users who observe the repeated error entries have no in-product explanation. `docs/research/windows-scm-api.md` already documents the protection mechanism accurately. Fix: add a Known Limitations note to `README.md` explaining that `WaaSMedicSvc` cannot be stopped on modern builds, that `Win32=5` errors are expected and not a misconfiguration, and that users may remove the service from `$aSvcTargetNames` to suppress the log noise. ADR-0005 Consequences text should also be corrected from "TIMED_OUT" to "FAILED or TIMED_OUT" for protected services.

---

### MED-10 — `_exit` / `_Exit` hotkey re-entrancy produces no batch-stop audit trail on forced exit

| Field | Value |
|---|---|
| **ID** | MED-10 |
| **Source** | BUG-10 (`docs/reviews/bugs/BUG-10-hotkey-reentrancy.md`) Issue 2 |
| **File / line** | `Stop Services Processes.au3` lines 632–636 (`_Exit`/`_exit` function) |
| **Status** | OPEN |
| **Fixer** | Unassigned (dependent on CRIT-02 rename being applied first) |

`_Exit()` calls `Exit` unconditionally after two generic log writes. It can fire during Phase 2's `Sleep($iPollIntervalMs)` yield point. OS handle cleanup guarantees there is no handle leak on exit. The gap is diagnostic: no log entry records which services were mid-batch at exit time. Fix: add a log entry capturing the pending service list (from the global or by design convention) before calling `Exit`. Low priority; the OS cleanup is complete.

---

## Low (track for later)

### LOW-01 — 5 bare `#EndRegion` markers missing closing labels

| Field | Value |
|---|---|
| **ID** | LOW-01 |
| **Source** | CR2-01 §STD-01, §STD-02; CR2-38 Check 7 |
| **File / line** | `Stop Services Processes.au3` lines 37, 48, 65, 78, 87 |
| **Status** | OPEN |
| **Fixer** | Unassigned |

Five `#EndRegion` markers in `Stop Services Processes.au3` have no matching label: `;hotkeys` (line 37), `;Timing constants` (line 48), `;Configuration — Log constants` (line 65), `;Configuration — AutoIt process priority constants` (line 78), and `;Configuration — Target lists` (line 87). The other four regions in the file close with labeled `#EndRegion`. AutoIt does not require labels; this is a readability and diff-tracing issue only. Fix: append the opening label to each bare `#EndRegion`, e.g., `#EndRegion ;Timing constants`.

---

### LOW-02 — `$sProcesses[18]` missing "edit here" guidance comment

| Field | Value |
|---|---|
| **ID** | LOW-02 |
| **Source** | CR2-38 Check 6 |
| **File / line** | `Stop Services Processes.au3` line 93 (comment above `$sProcesses[18]`) |
| **Status** | OPEN |
| **Fixer** | Unassigned |

The comment above `$sProcesses[18]` reads `; Process inventory — processes closed every $PROC_POLL_INTERVAL_SEC seconds.` This is a description, not an edit directive. The service target list at line 82 carries `; Edit here to add/remove service targets — do not modify _RunServiceBatchStop body.` No equivalent guidance exists for the process list. Fix: add `; Edit here to add/remove process targets — do not modify _KillProcessList body.` immediately above `$sProcesses[18]`.

---

### LOW-03 — REQ-010 Detail text in `docs/REQUIREMENTS.md` refers to removed local array

| Field | Value |
|---|---|
| **ID** | LOW-03 |
| **Source** | CR2-01 §SPEC-02; CR2-02 §SP-2 |
| **File / line** | `docs/REQUIREMENTS.md` REQ-010 Detail field |
| **Status** | OPEN |
| **Fixer** | Unassigned |

REQ-010 Detail states "9 service names present in `$aServiceNames` local array in `_RunServiceBatchStop()`". The implementation moved the list to a global `$aSvcTargetNames` in the `Configuration — Target lists` region. The requirement intent is fully satisfied; the Detail text is a stale documentation artefact. Fix: update REQ-010 Detail to reference `$aSvcTargetNames` in the `Configuration — Target lists` region.

---

### LOW-04 — `AdlibRegister("_ClearTrayNotify", 2000)` uses bare integer literal (Primitive Obsession)

| Field | Value |
|---|---|
| **ID** | LOW-04 |
| **Source** | CR2-02 §STD-S2 |
| **File / line** | `Stop Services Processes.au3` line 609 |
| **Status** | OPEN |
| **Fixer** | Unassigned |

`AdlibRegister("_ClearTrayNotify", 2000)` uses a bare `2000` ms tooltip-clear interval. No timing constant was introduced for this value. No repo standard explicitly requires a named constant for `AdlibRegister` intervals; this is a minor Primitive Obsession smell. Fix if desired: declare `Global Const $TRAY_NOTIFY_CLEAR_MS = 2000` in the Timing constants region and reference it at the call site.

---

### LOW-05 — CLAUDE.md retains stale references to old function names

| Field | Value |
|---|---|
| **ID** | LOW-05 |
| **Source** | CR2-08 Findings 6.1 note, 6.2 note, 6.3 note; CR2-08 §SO-2 |
| **File / line** | `CLAUDE.md` §Architecture (references `_miscpopups()`, `CheckElapsedTime`, `_CloseInstaller`) |
| **Status** | OPEN |
| **Fixer** | Unassigned |

`CLAUDE.md` §Architecture prose references three old function names (`_miscpopups`, `CheckElapsedTime`, `_CloseInstaller`) that were renamed in prior sessions. The live code uses `_MiscPopups`, `_CheckElapsedTime`, and `_KillProcessList`. These are documentation accuracy issues, not code violations. Fix: update `CLAUDE.md` §Architecture to use the current function names.

---

### LOW-06 — `BUG-09-A` log rotation uses last-modified time — edge case on idle instances

| Field | Value |
|---|---|
| **ID** | LOW-06 |
| **Source** | BUG-09 (`docs/reviews/bugs/BUG-09-log-rotation.md`) §BUG-09-A |
| **File / line** | `Stop Services Processes.au3` `_CheckAndRotateLogFile` (lines 179–194) |
| **Status** | OPEN — design note, no code change recommended |
| **Fixer** | N/A — monitor |

`_CheckAndRotateLogFile` uses `FileGetTime($sPath, 0, 1)` (last-modified time) rather than creation time. If the script runs in a configuration where the monitoring loop is never started (Shift+F1 never pressed), no writes occur and the last-modified timestamp ages. After 7 days, the log file is deleted on the next startup. This is arguably the intended behavior for GLOSSARY.md's "Log Rotation" definition. Rotation-during-active-write is structurally impossible (rotation runs at startup before any writer is active). No code change is required; the behavior is documented here for awareness.

---

### LOW-07 — `README.md` missing 3 processes and process-kill interval documentation

| Field | Value |
|---|---|
| **ID** | LOW-07 |
| **Source** | CR2-16 (`docs/reviews/second-pass/CR2-16-readme-review.md`) §SF-2, §SF-4, §SF-7b |
| **File / line** | `README.md` Processes section; Features section; Setup step 5 |
| **Status** | OPEN |
| **Fixer** | Unassigned |

Three defects in `README.md`:

1. **SF-2**: `UserOOBEBroker.exe`, `backgroundTaskHost.exe`, and `xgamehelper.exe` (which appears twice in the array — indices 15 and 16) are absent from the documented process list. The array contains 18 entries but the README lists 16.
2. **SF-4**: The 2-second process-kill polling interval (`$PROC_POLL_INTERVAL_SEC = 2`) is never stated. Only the 10-second service-stop interval is documented.
3. **SF-7b**: Setup step 5 refers to "the service array inside `_RunServiceBatchStop()`" for customization; the target list is now `$aSvcTargetNames` in the Configuration region, not inside the function body.

---

## Windows-only (requires Windows environment)

### WIN-01 — Phase 2 behavioral test coverage (B-004 test gap)

| Field | Value |
|---|---|
| **ID** | WIN-01 |
| **Source** | `docs/wiki/blockers.md` B-004; `docs/architecture-opportunities.md` Candidate 5; `docs/reviews/second-pass/CR2-02-stop-services-spec.md` §SP-12 |
| **File / line** | `Tests/ServiceManager.Tests.au3`; `Includes/ServiceManager.au3` Phase 2 (lines 316–372) |
| **Status** | OPEN — blocked by Environment Gate (Windows AutoIt runtime required) |
| **Fixer** | Requires Windows CI or Windows developer machine |

The test harness covers Phase 1 routing deterministically. Phase 2 — the shared-deadline poll loop, backwards-removal pattern, and TIMED_OUT cleanup — has zero test coverage. `STOPPED` and `TIMED_OUT` outcomes are never exercised by any test. The Environment Gate (AutoIt runs only on Windows) is the structural blocker. The pragmatic path: a Windows-only integration test using a real benign service (e.g., `W32Time` or `Spooler`) that stops the service, verifies Phase 2 reaches `STOPPED`, and always restores service state via a cleanup path. Requires `#RequireAdmin` and careful service lifecycle management. A stub-adapter seam via `Call()` is an alternative but would meaningfully complicate the module interface.

---

### WIN-02 — AU3Check `-w 3 -w 4` gate cannot be run in Linux sandbox

| Field | Value |
|---|---|
| **ID** | WIN-02 |
| **Source** | `docs/wiki/blockers.md` B-001 |
| **File / line** | All `.au3` files |
| **Status** | KNOWN, MITIGATED |
| **Fixer** | Windows developer (pre-commit hook installed) |

AU3Check is a Windows binary. All `.au3` files are written to satisfy `-q -d -w 1 -w 2 -w 3 -w 4` by construction, but the gate is marked `NOT RUN — Windows environment required`. The pre-commit hook fires when a Windows developer checks out the branch. The duplicate-constant violations documented in CRIT-01 are the most likely AU3Check failures when the gate runs.

---

### WIN-03 — AutoIt compiler and compilation gates cannot run in Linux sandbox

| Field | Value |
|---|---|
| **ID** | WIN-03 |
| **Source** | `docs/wiki/blockers.md` B-002 |
| **File / line** | `release/Stop Services - Processes.Exe` (compiled output) |
| **Status** | KNOWN, MITIGATED |
| **Fixer** | Windows developer |

AutoIt3Wrapper and the AutoIt compiler are Windows-only. x86 and x64 `.exe` artifacts cannot be compiled here. Compilation gates in TICKET-06 are marked `NOT RUN — Windows environment required`. Source `.au3` files are written per `CLAUDE.md` conventions. Compilation is left to the Windows developer workflow.

---

### WIN-04 — Hotkey re-entrancy bugs require live Windows AutoIt runtime to reproduce

| Field | Value |
|---|---|
| **ID** | WIN-04 |
| **Source** | BUG-10 (`docs/reviews/bugs/BUG-10-hotkey-reentrancy.md`) §No Correct Test Seam |
| **File / line** | `Stop Services Processes.au3` `ToggleScript`, `LockProcessPriority`, `_Exit`/`_exit` |
| **Status** | OPEN — static analysis only; test seam requires Windows |
| **Fixer** | Requires Windows environment with `ControlSend` or `Send()` automation |

The double-activation race (HIGH-05), the LockProcessPriority watchdog interleave (documented as low-severity timing gap in BUG-10 Issue 3), and the rapid stop+start inversion (BUG-10 Issue 4) all require real hotkey delivery timing to reproduce. No unit-level AutoIt test can inject a hotkey press during a `MsgBox` yield. The correct test seam is a Windows integration test using `ControlSend` or AutoIt's `Send()` directed at the running script. Findings are based on static analysis of the cooperative execution model.

---

### WIN-05 — `ServiceControl.au3` 64-bit handle truncation cannot be observed in Linux sandbox

| Field | Value |
|---|---|
| **ID** | WIN-05 |
| **Source** | BUG-07 §Bug B; `docs/wiki/blockers.md` B-003 |
| **File / line** | `Includes/ServiceControl.au3` — all six functions |
| **Status** | OPEN — confirmed by static analysis; runtime confirmation requires 64-bit Windows |
| **Fixer** | Windows developer |

The `"long"` handle truncation bug (HIGH-03) can only manifest at runtime on a 64-bit Windows process. Static analysis confirms the bug is present and would corrupt handles on the target platform. No `ServiceControl.au3` function is on the active code path, so there is no current observable failure. Verification of the fix (changing `"long"` to `"handle"`) requires running the functions in a 64-bit AutoIt build on Windows 10/11.

---

## Status Summary

| Priority | Total | OPEN | RESOLVED | Mitigated/Design note |
|---|---|---|---|---|
| Critical | 2 | 2 | 0 | 0 |
| High | 8 | 7 | 0 | 1 |
| Medium | 10 | 7 | 3 | 0 |
| Low | 7 | 6 | 0 | 1 |
| Windows-only | 5 | 3 | 0 | 2 |
| **Total** | **32** | **25** | **3** | **3** |

### Resolved items

| ID | Description |
|---|---|
| MED-02 | `$PROCESS_IDLE` dead shim — deleted (BUG-05) |
| MED-03 | `$SM_OUTCOME_ALREADY` / `$SM_OUTCOME_TIMEDOUT` renamed (BUG-04) |
| MED-04 | `$taskcloseran` dead global — deleted (BUG-01) |
| MED-05 | `_SM_GetServiceState` dead function — deleted (BUG-03) |
| MED-07 | `$iPendLen` loop-scoped redeclaration — moved to function scope (BUG-02) |

### Recommended fix order for OPEN items

1. **CRIT-01** — Remove duplicate `Global Const` declarations from `ServiceManager.au3` (AU3Check gate blocker)
2. **CRIT-02** — Rename `_exit` to `_Exit` and update `HotKeySet` string (naming gate blocker)
3. **HIGH-01 + HIGH-02** — Add `#include-once` and change `Global` to `Global Const` in `ServiceControl.au3` (single mechanical pass)
4. **HIGH-03 + HIGH-04** — Fix `"long"` handle types and `"str",""` struct bug in `ServiceControl.au3` (coordinated single pass, needs ADR before implementation)
5. **HIGH-05** — Move `$bScriptRunning` guard assignments before `MsgBox` yield in `ToggleScript`
6. **HIGH-06** — Add re-entrancy guard to `_LogMessage`
7. **HIGH-07** — Add `@error` checks with rollback to `_ArrayAdd` calls in `LockProcessPriority`
8. **HIGH-08** — Update `docs/REQUIREMENTS.md` REQ rows and `IMPLEMENTATION-AND-VERIFICATION.md` Gate 1; schedule Phase 2 test for Windows environment
9. **MED-01** — Move `$sProcesses[18]` to `Configuration — Target lists` region
10. Remaining MED/LOW items in any order
