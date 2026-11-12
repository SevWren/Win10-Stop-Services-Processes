# CR2-09 — Constants Completeness Audit

**Date**: 2026-11-12
**Scope**: All production `.au3` files — `Stop Services Processes.au3`, `Includes/ServiceManager.au3`, `Includes/ServiceControl.au3`, `Tests/ServiceManager.Tests.au3`, `test_process_close.au3`
**Standards sources**: `CODING_STANDARDS.md`, `CLAUDE.md`, `docs/ARCHITECTURE.md`
**Method**: Full file read + targeted grep for bare literals vs constant usage at all call sites

---

## Summary Table

| Constant Family | Defined? | All Call Sites Use Constants? | Bare Literals Found? | Verdict |
|---|---|---|---|---|
| Log Level (`$LOG_LEVEL_ERROR/INFO/VERBOSE`) | Yes — duplicated definition (2 files) | Yes — all 56 `_LogMessage` calls | None | PASS with defect: duplicate definition |
| Log Type (`$LOG_TYPE_SYSTEM/PROCESS/SERVICE/PROCESS_PRIORITY/PRIORITY_WATCHDOG`) | Partial — main script has all 5; `ServiceManager.au3` redeclares only 2; `ServiceControl.au3` has none | Yes — all calls in production files use constants | Bare string literals in `ServiceControl.au3` body (not `_LogMessage` calls) | PASS with defect: duplicate + incomplete secondary definition |
| AutoIt Priority (`$AUTOIT_PRIORITY_IDLE` through `$AUTOIT_PRIORITY_REALTIME`) | Yes — single definition in main script | Yes — all `ProcessSetPriority` call sites | None | PASS |
| Service Outcome (`$SM_OUTCOME_STOPPED` etc.) | Yes — `ServiceManager.au3` lines 55–59 | Yes — all assignment and comparison sites | None | PASS |
| Stop-eligible state (`$SM_STOP_ELIGIBLE_STATES`) | Yes — `ServiceManager.au3` line 91 | No — constant is never read; `_SM_IsStopEligible` uses a hardcoded `Switch` | Constant is effectively unused dead data | DEFECT: orphaned constant |

---

## 1. Log Level Constants

### Definition

| Constant | Value | File | Lines |
|---|---|---|---|
| `$LOG_LEVEL_ERROR` | 0 | `Stop Services Processes.au3` | 54 |
| `$LOG_LEVEL_INFO` | 1 | `Stop Services Processes.au3` | 55 |
| `$LOG_LEVEL_VERBOSE` | 2 | `Stop Services Processes.au3` | 56 |
| `$LOG_LEVEL_ERROR` | 0 | `Includes/ServiceManager.au3` | 100 |
| `$LOG_LEVEL_INFO` | 1 | `Includes/ServiceManager.au3` | 101 |
| `$LOG_LEVEL_VERBOSE` | 2 | `Includes/ServiceManager.au3` | 102 |

The same three constants are declared `Global Const` in two separate files. Because `ServiceManager.au3` is `#include`d by the main script, both declarations are active in the same compilation unit. AutoIt does not raise an error for duplicate `Global Const` declarations with identical values, but this arrangement creates a maintenance hazard: the values must be kept in sync manually, and there is no single authoritative source file.

### Bare Literal Search Result

Grep for `_LogMessage\([^,]+,\s*[012]\s*[,)]` across all `.au3` files: **zero matches**.

Every `_LogMessage` call in both `Stop Services Processes.au3` and `Includes/ServiceManager.au3` passes a `$LOG_LEVEL_*` constant in the third argument. No call passes a raw integer `0`, `1`, or `2`.

### Verdict

**PASS on bare-literal enforcement. DEFECT: duplicate definition.**

`$LOG_LEVEL_ERROR/INFO/VERBOSE` are defined twice — once in the main script (the canonical location per `CLAUDE.md` and `docs/domain-modeling/proposals/DM-07-logging-audit.md`) and once in `Includes/ServiceManager.au3`. The `ServiceManager.au3` copy is redundant. Because the module is a library included by the main script, it inherits the main script's definitions at runtime; the redeclaration in `ServiceManager.au3` is unnecessary and misleading about ownership.

---

## 2. Log Type Constants

### Definition

**Main script (`Stop Services Processes.au3`, lines 60–64) — full set of 5:**

| Constant | Value |
|---|---|
| `$LOG_TYPE_SYSTEM` | `"System"` |
| `$LOG_TYPE_PROCESS` | `"Process"` |
| `$LOG_TYPE_SERVICE` | `"Service"` |
| `$LOG_TYPE_PROCESS_PRIORITY` | `"ProcessPriority"` |
| `$LOG_TYPE_PRIORITY_WATCHDOG` | `"PriorityWatchdog"` |

**`Includes/ServiceManager.au3` (lines 108–109) — partial redeclaration of 2:**

| Constant | Value |
|---|---|
| `$LOG_TYPE_SYSTEM` | `"System"` |
| `$LOG_TYPE_SERVICE` | `"Service"` |

`$LOG_TYPE_PROCESS`, `$LOG_TYPE_PROCESS_PRIORITY`, and `$LOG_TYPE_PRIORITY_WATCHDOG` are not referenced by `ServiceManager.au3` (which is correct — the module only logs `System` and `Service` messages). However, the partial redeclaration of the two it does use adds the same maintenance risk as the Log Level duplication above.

**`Includes/ServiceControl.au3`**: This file contains no `_LogMessage` calls and no log type constant declarations. It is a legacy library predating the logging infrastructure and is used only for non-stop service helpers (`_ServiceExists`, `_ServiceRunning`, `_StartService`, `_CreateService`, `_DeleteService`). No log type bare literals appear here because there is no logging at all in this file.

### Bare Literal Search at `_LogMessage` Call Sites

Grep for `_LogMessage\([^,]+,\s*"(System|Process|Service|ProcessPriority|PriorityWatchdog)"` across all `.au3` files: **zero matches**.

Every `_LogMessage` call passes a `$LOG_TYPE_*` constant in the second argument. No call passes a bare string literal `"System"`, `"Process"`, `"Service"`, `"ProcessPriority"`, or `"PriorityWatchdog"` directly.

One edge case: in the `Variables/Logging` region of `Stop Services Processes.au3` (line 133), the initialization code writes a log entry directly via `FileWrite` rather than `_LogMessage`, using the bare expression `$LOG_TYPE_SYSTEM` as a bracket-interpolated token:

```autoit
Dim $sLogEntry = $sDateTime & " [" & $LOG_TYPE_SYSTEM & "] Log file initialized"
```

This is not a `_LogMessage` call and therefore is not subject to the bare-literal rule; it uses the constant correctly.

### Verdict

**PASS on bare-literal enforcement. DEFECT: duplicate partial definition in `ServiceManager.au3`.**

The two `$LOG_TYPE_*` constants redeclared in `ServiceManager.au3` should be removed; the module relies on the main script's definitions at include time and the redeclarations serve no purpose.

---

## 3. AutoIt Priority Constants

### Definition

Defined once, in `Stop Services Processes.au3` lines 72–77 (`#Region ;Configuration — AutoIt process priority constants`):

| Constant | Value |
|---|---|
| `$AUTOIT_PRIORITY_IDLE` | 0 |
| `$AUTOIT_PRIORITY_BELOW_NORMAL` | 1 |
| `$AUTOIT_PRIORITY_NORMAL` | 2 |
| `$AUTOIT_PRIORITY_ABOVE_NORMAL` | 3 |
| `$AUTOIT_PRIORITY_HIGH` | 4 |
| `$AUTOIT_PRIORITY_REALTIME` | 5 |

No other file declares or redefines these constants.

### Call Site Coverage

All `ProcessSetPriority` calls in production code:

| File | Line | Argument | Uses Constant? |
|---|---|---|---|
| `Stop Services Processes.au3` | 352 | `$iPriorityConst` (derived from `$AUTOIT_PRIORITY_*` via Switch) | Yes |
| `Stop Services Processes.au3` | 444 | `$iPriorityConst` (validated against `$AUTOIT_PRIORITY_IDLE` / `$AUTOIT_PRIORITY_REALTIME`) | Yes |
| `Stop Services Processes.au3` | 503 | `$iPriorityConst` (from watchdog array populated via `$AUTOIT_PRIORITY_*`) | Yes |

No `ProcessSetPriority` call passes a bare integer literal. The validation range check at line 429 uses `$AUTOIT_PRIORITY_IDLE` and `$AUTOIT_PRIORITY_REALTIME` as bounds rather than `0` and `5`, which is correct.

The `Switch` block at lines 318–329 in `SetProcessPriority()` accepts a user string `"1"`, `"2"`, `"3"` and maps it to the appropriate `$AUTOIT_PRIORITY_*` constant. The user-visible strings are input labels, not constant values, and do not constitute bare literals passed to `ProcessSetPriority`.

### Note on `$AUTOIT_PRIORITY_HIGH` and `$AUTOIT_PRIORITY_IDLE`

`SetProcessPriority()` exposes only three priority levels to the user (1=Below Normal, 2=Normal, 3=Above Normal). `$AUTOIT_PRIORITY_IDLE` (0), `$AUTOIT_PRIORITY_HIGH` (4), and `$AUTOIT_PRIORITY_REALTIME` (5) are defined but not reachable through `SetProcessPriority`. They are reachable through `LockProcessPriority()`, which accepts the full 0–5 range and uses these constants correctly in the prompt string and bounds check. The constancy is complete; no speculative-generality issue arises because `LockProcessPriority` does use all six values.

### Verdict

**PASS. Single definition point. All `ProcessSetPriority` call sites use constants.**

---

## 4. Service Outcome Constants

### Definition

Defined once, in `Includes/ServiceManager.au3` lines 55–59:

| Constant | Value |
|---|---|
| `$SM_OUTCOME_STOPPED` | `"STOPPED"` |
| `$SM_OUTCOME_ALREADY` | `"ALREADY_STOPPED"` |
| `$SM_OUTCOME_UNAVAILABLE` | `"UNAVAILABLE"` |
| `$SM_OUTCOME_FAILED` | `"FAILED"` |
| `$SM_OUTCOME_TIMEDOUT` | `"TIMED_OUT"` |

### Call Site Coverage

All sites where an outcome string is assigned (`$aResults[$i][3] = ...`) or compared (`Case $sOutcome = ...`):

**Assignment sites in `Includes/ServiceManager.au3` (all within `_SM_StopServicesBatch` and `_SM_Win32ErrToOutcome`):**

| Line | Assignment | Constant Used? |
|---|---|---|
| 211 | `$SM_OUTCOME_UNAVAILABLE` | Yes |
| 215 | `$SM_OUTCOME_FAILED` | Yes |
| 234 | `$SM_OUTCOME_FAILED` | Yes |
| 247 | `$SM_OUTCOME_ALREADY` | Yes |
| 267 | `$SM_OUTCOME_FAILED` | Yes |
| 340 | `$SM_OUTCOME_STOPPED` | Yes |
| 367 | `$SM_OUTCOME_TIMEDOUT` | Yes |
| 456 | `$SM_OUTCOME_ALREADY` (return) | Yes |
| 458 | `$SM_OUTCOME_UNAVAILABLE` (return) | Yes |
| 460 | `$SM_OUTCOME_FAILED` (return) | Yes |

**Comparison sites in `Stop Services Processes.au3` (`_RunServiceBatchStop`, lines 249–260):**

| Line | Comparison | Constant Used? |
|---|---|---|
| 249 | `$SM_OUTCOME_STOPPED` | Yes |
| 251 | `$SM_OUTCOME_ALREADY` | Yes |
| 253 | `$SM_OUTCOME_TIMEDOUT` | Yes |
| 255 | `$SM_OUTCOME_UNAVAILABLE` | Yes |
| 257 | `$SM_OUTCOME_FAILED` | Yes |

**`_SM_BuildResultRow` in `Includes/ServiceManager.au3`:** The function accepts `$sOutcome` as a string parameter and places it in `$aRow[3]` without comparison. No bare literals are passed at any call site — all callers pass `$SM_OUTCOME_*` constants.

**Historical note:** `docs/ARCHITECTURE.md` section "Integration Point" contains documentation code that shows bare string literals `"STOPPED"`, `"ALREADY_STOPPED"`, `"TIMED_OUT"`, `"UNAVAILABLE"`, `"FAILED"` in a pseudocode example. This is documentation (not production code) showing the pre-constant design; the actual implementation at lines 249–260 of the main script uses constants throughout. No bare outcome string literals appear in any `.au3` production file.

### Verdict

**PASS. Constants defined. All assignment and comparison sites use constants.**

---

## 5. Stop-Eligible State Constant (`$SM_STOP_ELIGIBLE_STATES`)

### Definition

Defined once, in `Includes/ServiceManager.au3` line 91:

```autoit
Global Const $SM_STOP_ELIGIBLE_STATES = "RUNNING,PAUSED,PAUSE_PENDING,CONTINUE_PENDING"
```

### Usage

Grep for `\$SM_STOP_ELIGIBLE_STATES` across all `.au3` files returns exactly one match — the definition line itself. The constant is never read anywhere in the codebase.

The `_SM_IsStopEligible` function (lines 476–483 of `ServiceManager.au3`) implements the same information using a `Switch` statement over `$SM_STATE_*` integer constants:

```autoit
Func _SM_IsStopEligible($iState)
    Switch $iState
        Case $SM_STATE_RUNNING, $SM_STATE_PAUSED, $SM_STATE_PAUSE_PENDING, $SM_STATE_CONTINUE_PENDING
            Return True
        Case Else
            Return False
    EndSwitch
EndFunc
```

The comment block above `$SM_STOP_ELIGIBLE_STATES` (lines 86–91) says the constant is "Used by `_SM_IsStopEligible`", but the function does not reference it. The constant encodes the eligible states as a comma-delimited string, which is not usable in a `Switch` statement anyway — a `Switch` over string constants would require comparing `$iState` to string names rather than integers, which would require `_SM_ServiceStateToString($iState)` as an intermediate step. The constant appears to have been written as documentation or for external consumers that were never implemented.

### Verdict

**DEFECT: Orphaned constant. `$SM_STOP_ELIGIBLE_STATES` is defined but never read. The comment claiming it is "Used by `_SM_IsStopEligible`" is incorrect. The constant has no functional role in the codebase.**

This is a Fowler "Speculative Generality" smell: an abstraction created for a purpose that does not exist. It is not harmful to correctness but misleads readers into thinking there is an indirection or configuration point that does not exist.

---

## Cross-Cutting: Duplicate Constant Definitions (Log Level + Log Type)

The following constants are defined in two files simultaneously:

| Constant | Main Script Line | `ServiceManager.au3` Line |
|---|---|---|
| `$LOG_LEVEL_ERROR` | 54 | 100 |
| `$LOG_LEVEL_INFO` | 55 | 101 |
| `$LOG_LEVEL_VERBOSE` | 56 | 102 |
| `$LOG_TYPE_SYSTEM` | 60 | 108 |
| `$LOG_TYPE_SERVICE` | 62 | 109 |

Because `ServiceManager.au3` uses `#include-once` and is consumed via `#include` in the main script, both declarations appear in the same compilation unit. AutoIt silently accepts duplicate `Global Const` declarations as long as the values match; it does not enforce single-definition-point semantics at the language level.

The canonical location for all log constants is the main script per `CLAUDE.md` ("Logging") and `docs/domain-modeling/proposals/DM-07-logging-audit.md` §4. The `ServiceManager.au3` redeclarations were presumably added so the module could be compiled standalone or run in a context where the main script was not included. However:

1. `ServiceManager.au3` is not a standalone script — it has no main body and cannot execute independently.
2. The test harness (`Tests/ServiceManager.Tests.au3`) includes `ServiceManager.au3` at line 500 (`#include "Includes\ServiceManager.au3"`). The test file does not include the main script. Therefore, the redeclarations in `ServiceManager.au3` are the only source of `$LOG_LEVEL_*` and `$LOG_TYPE_SERVICE/SYSTEM` for the test harness — they are functionally necessary for the test compilation unit to resolve those symbols.

This creates a genuine architectural ambiguity: the constants appear in `ServiceManager.au3` not as documentation redundancy but as a practical workaround for the test harness's standalone compilation context. Removing them from `ServiceManager.au3` would break the test file compilation (the test file would have undefined `$LOG_LEVEL_*` and `$LOG_TYPE_*` symbols at the `_LogMessage` call sites inside `ServiceManager.au3`).

**Revised verdict for duplicate definitions: Structurally necessary for the current test harness layout, but represents a design smell.** The correct long-term resolution would be a shared constants include (e.g., `Includes/LogConstants.au3`) included by both the main script and `ServiceManager.au3`, making `ServiceManager.au3` self-sufficient without duplicating constants owned by the main script. This is out of scope for this audit but should be tracked.

---

## Findings Summary

| # | Finding | Severity | File(s) | Line(s) |
|---|---|---|---|---|
| F-01 | `$LOG_LEVEL_ERROR/INFO/VERBOSE` declared in two files; functionally required by test harness layout but architecturally unclean | Minor | `Stop Services Processes.au3` L54–56; `Includes/ServiceManager.au3` L100–102 | — |
| F-02 | `$LOG_TYPE_SYSTEM` and `$LOG_TYPE_SERVICE` declared in two files; same root cause as F-01 | Minor | `Stop Services Processes.au3` L60,62; `Includes/ServiceManager.au3` L108–109 | — |
| F-03 | `$SM_STOP_ELIGIBLE_STATES` is defined but never read; comment claiming it is "Used by `_SM_IsStopEligible`" is false | Minor | `Includes/ServiceManager.au3` | L86–91 |
| F-04 | `docs/ARCHITECTURE.md` "Integration Point" section shows bare outcome string literals in pseudocode example — documentation only, not production code; no action required | Informational | `docs/ARCHITECTURE.md` | — |

---

## No Findings (Confirmed Clean)

- No bare integer `0`, `1`, or `2` passed to `_LogMessage` third argument anywhere in the codebase.
- No bare string `"System"`, `"Process"`, `"Service"`, `"ProcessPriority"`, or `"PriorityWatchdog"` passed to `_LogMessage` second argument anywhere.
- No bare integer passed to `ProcessSetPriority` — all three call sites use a variable derived from `$AUTOIT_PRIORITY_*` constants.
- `$SM_OUTCOME_*` constants cover all five outcome strings; no bare string literal (`"STOPPED"`, `"ALREADY_STOPPED"`, etc.) appears at any assignment or comparison site in production code.
- `_SM_BuildResultRow` in `ServiceManager.au3` does not embed bare outcome literals — it accepts `$sOutcome` as a parameter and all callers supply constants.
- `test_process_close.au3` does not call `_LogMessage` or `ProcessSetPriority`; it is a standalone scratch file and not subject to these rules.
- `Includes/ServiceControl.au3` does not call `_LogMessage` or `ProcessSetPriority`; its constant set predates the logging infrastructure and is not in scope for this audit.

---

## Recommended Actions

| Priority | Action | Owner |
|---|---|---|
| Medium | Extract `$LOG_LEVEL_*` and `$LOG_TYPE_*` constants into `Includes/LogConstants.au3`; include from both main script and `ServiceManager.au3`; remove duplicate declarations | Future refactor ticket |
| Low | Remove `$SM_STOP_ELIGIBLE_STATES` or correct its comment to accurately state it is documentation-only and not consumed by `_SM_IsStopEligible` | `Includes/ServiceManager.au3` |
| None | Bare-literal usage at `_LogMessage` and `ProcessSetPriority` call sites — no remediation needed; codebase is clean | — |
