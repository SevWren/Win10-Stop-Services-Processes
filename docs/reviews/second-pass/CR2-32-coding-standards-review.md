# CR2-32 — CODING_STANDARDS.md Second-Pass Review

**Date**: 2026-11-12
**Reviewer**: Code-review agent (Standards axis)
**Subject file**: `CODING_STANDARDS.md`
**Authority document**: `CLAUDE.md`
**Codebase snapshot**: `Stop Services Processes.au3`, `Includes/ServiceManager.au3`, `Tests/ServiceManager.Tests.au3`

---

## Executive Summary

`CODING_STANDARDS.md` is largely well-structured and covers most enforced conventions. However, it contains one significant accuracy defect (the `_SM_PascalCase` removal note is factually wrong with respect to the live codebase), one authority-inversion defect (which document wins on conflicts is stated oppositely in each file), and two coverage gaps (`#Region` naming conventions and constant naming patterns). These are all actionable items; none require large rewrites.

---

## Check 1 — Is the `_SM_PascalCase` tier resolved correctly?

**Status: DEFECT — Removal note is incorrect against current codebase.**

CODING_STANDARDS.md line 13 (CR-09 note) states that `_SM_PascalCase` "appeared in a previous revision of this file" and "has been removed." It instructs that module-prefixed helpers "must follow the standard `_UnderscorePascalCase` convention."

This is factually inconsistent with the current codebase:

- `Includes/ServiceManager.au3` exists and declares eight functions using `_SM_PascalCase`: `_SM_StopServicesBatch`, `_SM_GetServiceState`, `_SM_ServiceStateToString`, `_SM_Win32ErrToOutcome`, `_SM_IsStopEligible`, `_SM_StateNeedsPolling`, `_SM_StateToAlreadyStopped`, `_SM_BuildResultRow`.
- `Stop Services Processes.au3` calls `_SM_StopServicesBatch` directly (line 238).
- `Tests/ServiceManager.Tests.au3` calls all eight `_SM_*` functions throughout.
- CLAUDE.md line 75 explicitly defines `_SM_PascalCase` as the third naming tier: "Service-manager module: `_SM_PascalCase` — `_SM_StopServicesBatch`, `_SM_GetServiceState`"

The CR-09 note in CODING_STANDARDS.md describes a state that no longer exists. The `_SM_` tier is active production code and is documented in CLAUDE.md. The removal note must be retracted and replaced with a formal definition of the third tier.

**Required correction**: Remove the CR-09 removal note. Add `_SM_PascalCase` as a third canonical naming tier with the definition matching CLAUDE.md line 75.

---

## Check 2 — Test file conventions section

**Status: PRESENT and ACCURATE.**

CODING_STANDARDS.md contains a "Test File Conventions" section (lines 69–74) covering:

- File locations (`Tests/*.au3`, `*.Tests.au3` suffix) — matches `Tests/ServiceManager.Tests.au3`.
- `g_` prefix acceptance for test harness globals — confirmed in `Tests/ServiceManager.Tests.au3` lines 115–118 (`$g_iTestCount`, `$g_iPassCount`, `$g_iFailCount`, `$g_sTestLog`).
- `ConsoleWrite` exception — cross-referenced to the Logging section CR-03 exception.
- Two-tier naming applies in test files — accurate; no `_SM_*` naming appears in test helper functions.

No defects found in this section.

---

## Check 3 — Naming tiers: are `PascalCase` and `_UnderscorePascalCase` still the two canonical tiers?

**Status: DEFECT — There are three canonical tiers, not two.**

CODING_STANDARDS.md defines exactly two tiers (lines 10–11):
- Hotkey-triggered (public): `PascalCase`
- Internal/private: `_UnderscorePascalCase`

The CR-09 note (line 13) reinforces the two-tier framing by asserting that `_SM_PascalCase` was removed.

As documented under Check 1, `_SM_PascalCase` is an active third tier used across three files. The CODING_STANDARDS.md Function Naming section must be updated to reflect three tiers:

| Tier | Convention | Examples |
|---|---|---|
| Hotkey-triggered (public) | `PascalCase` | `ToggleScript`, `SetProcessPriority`, `LockProcessPriority` |
| Internal/private | `_UnderscorePascalCase` | `_CloseInstaller`, `_LogMessage`, `_PriorityWatchdog` |
| Service-manager module | `_SM_PascalCase` | `_SM_StopServicesBatch`, `_SM_GetServiceState` |

---

## Check 4 — Does CODING_STANDARDS.md reference CLAUDE.md as the authority for naming?

**Status: DEFECT — Authority attribution is inverted between the two documents.**

CODING_STANDARDS.md preamble (line 8) states:
> "Authority: `CLAUDE.md` is the canonical source for naming conventions. This section must remain in sync with the 'Coding Conventions → Function Naming' section of `CLAUDE.md`."

CLAUDE.md lines 76–77 state the opposite:
> "`CODING_STANDARDS.md` is the authority on naming conventions, including the `_SM_` prefix tier introduced there. If this section and `CODING_STANDARDS.md` ever conflict, `CODING_STANDARDS.md` wins."

These two statements directly contradict each other. Each document defers to the other. This creates an unresolvable loop when the documents diverge — which they currently do on the `_SM_` tier question.

**Required correction**: One document must be designated the single authority. Given that CLAUDE.md is the agent-instruction file and CODING_STANDARDS.md is the reviewer-enforcement file, the logical choice is to designate CODING_STANDARDS.md as the authority for naming (consistent with CLAUDE.md's current intent on line 77), and update CODING_STANDARDS.md's preamble to reflect that it is the authority, while CLAUDE.md's naming section is kept as a summary that must stay in sync.

---

## Check 5 — Are there rules that contradict current code practices?

**Status: ONE ACTIVE CONTRADICTION (covered above), plus one minor observation.**

**Active contradiction**: The CR-09 removal note (CODING_STANDARDS.md line 13) contradicts the existence of `Includes/ServiceManager.au3` and all `_SM_*` function usage. This is the same defect as Checks 1 and 3.

**Minor observation — `ConsoleWrite` in production code**: CODING_STANDARDS.md Logging section states "Direct `ConsoleWrite` calls outside of initialization/debug code are NOT permitted." The main script uses `$bLogToConsole = True` to mirror output via `ConsoleWrite` inside `_LogMessage`. This is consistent with the "initialization/debug code" carve-out since it is gated by a flag inside the logging function itself. No contradiction.

**Minor observation — `$sProcesses2[]`**: CODING_STANDARDS.md Duplicate Prevention section references `$sProcesses2[]` (line 60). This variable does not appear in the current `Stop Services Processes.au3`. It may be a stale reference from a previous version. It does not cause a standards violation but could confuse reviewers. Worth noting as a low-priority cleanup candidate.

---

## Check 6 — Guidance on `#Region` block naming conventions

**Status: MISSING — No guidance exists; a naming pattern has emerged in the codebase.**

CODING_STANDARDS.md has no section on `#Region` / `#EndRegion` naming conventions. CLAUDE.md's "Region Structure" section (lines 87–91) lists the original three regions by name but does not establish a naming rule.

The main script now contains the following `#Region` blocks (observed in `Stop Services Processes.au3` lines 2–89):

```
;**** Directives created by AutoIt3Wrapper_GUI ****
;Includes/Options/Permissions
;hotkeys
;Timing constants
;Configuration — Log constants
;Configuration — AutoIt process priority constants
;Configuration — Target lists
;Variables/Logging
```

A "Configuration —" prefix pattern has emerged for the three configuration regions (lines 50, 67, 80). This pattern is not documented anywhere. Additionally, `#EndRegion` tags on hotkeys and timing constant regions omit the label (lines 37, 48), while other `#EndRegion` tags include the label text. Inconsistent label omission on `#EndRegion` is a minor style gap.

**Recommended addition to CODING_STANDARDS.md**: A brief `#Region` naming rule covering (a) the established region names from CLAUDE.md, (b) the `Configuration —` prefix convention for configuration-data regions, and (c) a requirement that `#EndRegion` carry the matching label text.

---

## Check 7 — Guidance on constant naming (`$LOG_LEVEL_*` prefix pattern)

**Status: MISSING — No guidance exists; multiple active prefix patterns are undocumented.**

CODING_STANDARDS.md has no section on constant naming conventions. The codebase contains the following established prefix patterns:

| Prefix | Examples | Defined in |
|---|---|---|
| `$LOG_LEVEL_` | `$LOG_LEVEL_ERROR`, `$LOG_LEVEL_INFO`, `$LOG_LEVEL_VERBOSE` | `Stop Services Processes.au3` lines 54–56; `ServiceManager.au3` lines 100–102 |
| `$LOG_TYPE_` | `$LOG_TYPE_SYSTEM`, `$LOG_TYPE_SERVICE`, `$LOG_TYPE_PROCESS`, etc. | `Stop Services Processes.au3` lines 60–64; `ServiceManager.au3` lines 108–109 |
| `$SM_STATE_` | `$SM_STATE_STOPPED`, `$SM_STATE_RUNNING`, etc. | `ServiceManager.au3` lines 44–50 |
| `$SM_OUTCOME_` | `$SM_OUTCOME_STOPPED`, `$SM_OUTCOME_FAILED`, etc. | `ServiceManager.au3` lines 55–59 |
| `$SM_ERR_` | `$SM_ERR_ACCESS_DENIED`, `$SM_ERR_SVC_NOT_EXIST`, etc. | `ServiceManager.au3` lines 65–68 |
| `$SM_SC_MANAGER_` / `$SM_SERVICE_` | Access rights constants | `ServiceManager.au3` lines 75–83 |
| `$AUTOIT_PRIORITY_` | `$AUTOIT_PRIORITY_IDLE`, `$AUTOIT_PRIORITY_HIGH`, etc. | `Stop Services Processes.au3` lines 72–77 |

A secondary concern: `$LOG_LEVEL_*` and `$LOG_TYPE_*` are declared in both `Stop Services Processes.au3` and `ServiceManager.au3`. This is a potential duplicate-global defect. AutoIt does not error on duplicate `Global Const` declarations with the same value, but the duplication is undocumented and fragile if values diverge. CODING_STANDARDS.md's Duplicate Prevention section covers `#include` and `HotKeySet` duplicates but does not address duplicate global constant declarations across files.

**Recommended additions to CODING_STANDARDS.md**:
1. A constant naming section documenting the `$PREFIX_Name` convention: module-scoped constants use a module prefix (`$SM_`, `$LOG_`, `$AUTOIT_PRIORITY_`), script-scoped shared constants use the category prefix (`$LOG_LEVEL_`, `$LOG_TYPE_`).
2. An extension to the Duplicate Prevention section: "No `Global Const` with the same identifier may be declared in more than one included file. Shared log-level and log-type constants are defined in `Stop Services Processes.au3` and must not be redeclared in `Includes/*.au3`."

---

## Action Items Summary

| # | Severity | Location | Action |
|---|---|---|---|
| A1 | High | CODING_STANDARDS.md §Function Naming | Retract CR-09 removal note; add `_SM_PascalCase` as third canonical tier |
| A2 | High | CODING_STANDARDS.md preamble (line 8) | Fix authority inversion: CODING_STANDARDS.md is the authority, not CLAUDE.md |
| A3 | High | CLAUDE.md lines 76–77 | Update CLAUDE.md to match: its naming section is a summary, CODING_STANDARDS.md wins |
| A4 | Medium | CODING_STANDARDS.md | Add `#Region` naming conventions section |
| A5 | Medium | CODING_STANDARDS.md | Add constant naming conventions section with `$PREFIX_` patterns |
| A6 | Medium | CODING_STANDARDS.md §Duplicate Prevention | Extend to cover duplicate `Global Const` declarations across included files |
| A7 | Low | CODING_STANDARDS.md §Duplicate Prevention | Assess whether `$sProcesses2[]` reference is stale; remove if no longer in use |

---

## Unchanged / Confirmed Accurate Sections

The following sections were checked against the codebase and require no changes:

- **@error Capture** — pattern in CODING_STANDARDS.md matches `ServiceManager.au3` and `Stop Services Processes.au3` exactly.
- **Handle Ownership** — enforced consistently in `ServiceManager.au3` (SCM handle, service handles all closed on every exit path).
- **WinAPI Patterns** — `PROCESS_QUERY_LIMITED_INFORMATION`, direct `DllCall`, `_TrayNotify()` via `ToolTip()` — all match codebase.
- **Path Portability** — `@ScriptDir` and `@HomeDrive` usage consistent; no hardcoded roots in production code.
- **AU3Check Compliance** — compiler flags in CODING_STANDARDS.md match `#AutoIt3Wrapper_AU3Check_Parameters` in `Stop Services Processes.au3` line 10.
- **Test File Conventions** — accurate as noted in Check 2.
- **Smell Baseline** — Fowler heuristics section is informational; no code-match required.
- **Logging** — `_LogMessage` routing rule and log-type enumeration match production code.
