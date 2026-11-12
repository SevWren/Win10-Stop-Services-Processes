# CR2-17 — CLAUDE.md Code Review

**Reviewer**: Agent (second-pass series)
**Date**: 2026-11-12
**Fixed point**: current codebase (`Stop Services Processes.au3`, `Includes/ServiceManager.au3`, `Includes/ServiceControl.au3`)
**Spec sources**: `.agents/skills/setup-matt-pocock-skills/SKILL.md` (skills block format); current codebase; `CODING_STANDARDS.md`

---

## Summary

CLAUDE.md is in good shape for most of the checklist items. Five findings require attention: two are correctness issues (stale function names from pre-rework code), two are gaps (DllCall conventions and two-library architecture are underdocumented relative to what a new agent needs), and one is a naming-tier conflict between CLAUDE.md and CODING_STANDARDS.md that the two files resolve in opposite directions.

| # | Axis | Severity | Title |
|---|---|---|---|
| F1 | Standards | MINOR | `_CloseInstaller` and `_miscpopups` survive in the Architecture section despite being renamed |
| F2 | Standards | MAJOR | `CheckElapsedTime` referenced without underscore; current function is `_CheckElapsedTime` |
| F3 | Standards | MAJOR | `_SM_PascalCase` tier: CLAUDE.md documents it, CODING_STANDARDS.md removes it — authority claim conflicts |
| F4 | Spec | MINOR | DllCall type-signature and struct-layout conventions are underdocumented in CLAUDE.md |
| F5 | Spec | MINOR | Two-library architecture (ServiceControl vs ServiceManager) is not fully articulated |

No findings were raised for the following items — they are confirmed correct:

- `## Agent skills` block: **present**, with `### Issue tracker` and `### Domain docs` sub-headings. Format matches the SKILL.md template.
- `_TrayNotify` timeout: **documented as 2 seconds** (`AdlibRegister("_ClearTrayNotify", 2000)`). Correct.
- `docs/adr/` pointer: **present** in the `### Domain docs` sub-heading (`docs/adr/`). Correct.
- `_SM_PascalCase` reference with CODING_STANDARDS.md authority note: **present** (see F3 for the conflict with CODING_STANDARDS.md's own text, which is a separate problem).

---

## Standards Axis

### F1 — Stale function names: `_CloseInstaller` and `_miscpopups` (MINOR)

**Location**: CLAUDE.md §"Active Monitoring Loop (`ToggleScript`)", lines 58–61

CLAUDE.md documents the monitoring loop as calling:

```
- `_CloseInstaller()` — kills processes in `$sProcesses[]` array every ~2 seconds
- `_stopservicescustom()` — stops services in `$aServiceNames[]` every ~2 seconds
- `_miscpopups()` — closes specific application registration dialogs
```

Current state of `Stop Services Processes.au3`:

| Old name in CLAUDE.md | Current function | Note |
|---|---|---|
| `_CloseInstaller()` | `_KillProcessList()` | Renamed; `_CloseInstaller` does not exist in the codebase |
| `_stopservicescustom()` | `_RunServiceBatchStop()` | Replaced entirely by the ServiceManager rework |
| `_miscpopups()` | `_MiscPopups()` | AutoIt names are case-insensitive so this resolves, but the capitalisation is wrong and the doc looks stale |

Additionally, the loop description says "every ~2 seconds" for service stops. The current code uses `$SVC_POLL_INTERVAL_SEC = 10` for the service cycle; only the process-kill cycle runs every `$PROC_POLL_INTERVAL_SEC = 2` seconds. The "~2 seconds" annotation is therefore wrong for services.

**Required fix**: Update the monitoring-loop bullet list to reflect `_KillProcessList`, `_RunServiceBatchStop`, and `_MiscPopups`. Correct the per-service interval description to 10 seconds.

---

### F2 — `CheckElapsedTime` referenced without underscore (MAJOR)

**Location**: CLAUDE.md §"Active Monitoring Loop (`ToggleScript`)", line 61

> Timing uses `TimerInit()` / `TimerDiff()` via `CheckElapsedTime($iStartTime, $iIntervalSeconds)`.

The current function defined in `Stop Services Processes.au3` is `_CheckElapsedTime`, with a leading underscore (private naming convention). The CLAUDE.md reference omits the underscore. This is not a cosmetic issue: the underscore is the project's naming convention signal for private/internal functions (documented in the same CLAUDE.md under "Coding Conventions → Function Naming"). A new agent reading this will see the name without an underscore and infer it is a public hotkey-triggered function, which it is not.

The parameter name `$iIntervalSeconds` is also stale; the current signature is `_CheckElapsedTime($iStartTime, $iInterval)`.

**Required fix**: Correct to `_CheckElapsedTime($iStartTime, $iInterval)`.

---

### F3 — `_SM_PascalCase` naming tier: CLAUDE.md documents it, CODING_STANDARDS.md removes it (MAJOR)

**Location**: CLAUDE.md §"Coding Conventions → Function Naming", lines 75–77; CODING_STANDARDS.md §"Function Naming", lines 11–13

CLAUDE.md states:

> Service-manager module: `_SM_PascalCase` — `_SM_StopServicesBatch`, `_SM_GetServiceState`

And then declares CODING_STANDARDS.md as the authority:

> `CODING_STANDARDS.md` is the authority on naming conventions, including the `_SM_` prefix tier introduced there.

However, CODING_STANDARDS.md explicitly removes the `_SM_PascalCase` tier:

> **Note (CR-09)**: A third tier `_SM_PascalCase` appeared in a previous revision of this file but is not defined in `CLAUDE.md`. It has been removed. Any module-prefixed helpers (e.g., service-manager functions) must follow the standard `_UnderscorePascalCase` convention unless `CLAUDE.md` is explicitly updated to introduce a new tier.

The two files are contradictory. CLAUDE.md says the tier exists and was introduced in CODING_STANDARDS.md. CODING_STANDARDS.md says the tier was removed because CLAUDE.md never introduced it. The actual codebase resolves in favour of `_SM_PascalCase`: `ServiceManager.au3` uses `_SM_StopServicesBatch`, `_SM_GetServiceState`, `_SM_IsStopEligible`, etc. throughout — the naming tier is live in production code and in the ADRs.

The authority chain is broken. CLAUDE.md points to CODING_STANDARDS.md as the authority, CODING_STANDARDS.md points back to CLAUDE.md as the place where the tier must be introduced, neither file unambiguously introduces it, yet the codebase uses it.

**Required fix**: One of:
- CLAUDE.md explicitly introduces the `_SM_PascalCase` tier (the tier exists in code, so this is the least-surprise option), and CODING_STANDARDS.md removes the CR-09 note that says it was deleted; or
- CODING_STANDARDS.md re-introduces the tier with CLAUDE.md as the authority source.

Either resolution must leave both files in agreement and consistent with the live codebase.

---

## Spec Axis

### F4 — DllCall type-signature conventions underdocumented (MINOR)

**Location**: CLAUDE.md §"WinAPI Priority Reading Pattern" and §"ServiceControl.au3"

CLAUDE.md documents the kernel32.dll DllCall pattern for `OpenProcess`/`GetPriorityClass` in reasonable detail under "WinAPI Priority Reading Pattern". However, the advapi32.dll calling conventions used by both `ServiceControl.au3` and `ServiceManager.au3` receive almost no documentation. A new agent working in `ServiceManager.au3` would need to know:

- Why `"handle"` is used as the return type for `OpenSCManagerW` and `OpenServiceW` (instead of `"long"` or `"ptr"`).
- The `SERVICE_STATUS` struct layout: `"dword;dword;dword;dword;dword;dword;dword"` (seven DWORDs), and that `dwCurrentState` is field 2.
- Why `"wstr"` is used for wide-string parameters in `ServiceManager.au3` (Unicode entry points `OpenSCManagerW`, `OpenServiceW`) while `ServiceControl.au3` uses `"str"` (ANSI entry points).
- Why `"ptr"` is passed for the `lpMachineName` parameter of `OpenSCManagerW` as `0` (null pointer) rather than an empty string.

ADR-0008 covers the rationale for direct DllCall over wrappers. It does not document the type-signature mechanics themselves. These details are currently scattered across inline comments in `ServiceManager.au3` and in `docs/research/autoit-dllcall.md` (if it exists), but are absent from CLAUDE.md.

This gap means a new agent editing or extending `ServiceManager.au3` has no single document to verify type signatures against and may silently introduce type mismatches (e.g., using `"long"` where `"handle"` is required, or `"str"` on a Unicode API).

**Recommended addition**: A "DllCall Conventions" section in CLAUDE.md covering the type aliases used for SCM API calls, the `SERVICE_STATUS` struct layout, and the ANSI vs Unicode entry point distinction between the two libraries.

---

### F5 — Two-library architecture not fully articulated (MINOR)

**Location**: CLAUDE.md §"ServiceControl.au3" (single section); no corresponding section for ServiceManager

The current architecture uses two libraries for service operations:

| Library | Responsibility |
|---|---|
| `Includes/ServiceControl.au3` | `_ServiceExists`, `_ServiceRunning`, `_StartService`, `_CreateService`, `_DeleteService` |
| `Includes/ServiceManager.au3` | `_SM_StopServicesBatch` — the authoritative stop path |

CLAUDE.md has a "ServiceControl.au3" section that describes the library accurately, including the note that `_StopService` in ServiceControl.au3 is no longer called. However:

1. There is no "ServiceManager.au3" section. A new agent reading CLAUDE.md would not know the library exists, what its public interface is (`_SM_StopServicesBatch` returning a `[n][6]` 2D array), or how the two-level error convention works (`@error 1` for SCM failure vs per-row outcome strings for individual services).

2. The "Repository Layout" section lists `ServiceControl.au3` only: `Includes/ServiceControl.au3 ← custom DllCall service library (advapi32.dll)`. `ServiceManager.au3` is not in the layout table.

3. ADR-0004 documents that the two modules are deliberately incompatible at their return-value conventions and must not be used interchangeably for stop operations. This is an important constraint for any agent integrating a new service call site. It is not reflected in CLAUDE.md.

**Recommended additions**:
- Add `Includes/ServiceManager.au3` to the repository layout table with a one-line description.
- Add a "ServiceManager.au3" section to CLAUDE.md covering: public function signature, return array schema `[n][6]`, the two-level error convention (ADR-0003), and the incompatibility with ServiceControl's scalar return convention (ADR-0004).
- Update the ServiceControl.au3 section to explicitly cross-reference ServiceManager.au3 as the stop-path replacement, not just note that `_StopService` is no longer called.

---

## Adequacy Assessment — Can a new agent work in this repo from CLAUDE.md alone?

A new agent reading only CLAUDE.md would be able to:

- Understand the execution model (passive main loop, hotkey-driven, AdlibRegister callbacks). Correct.
- Identify the monitoring loop entry point and use the right hotkeys. Mostly correct (impaired by F1/F2).
- Follow the naming convention for new functions — with caveats. The `_SM_PascalCase` tier is documented but its authority is disputed by the other file the agent would read (F3).
- Understand why `TrayTip` is avoided and how to use `_TrayNotify`. Correct.
- Apply the kernel32.dll DllCall pattern for process priority. Correct.
- Apply the same pattern to advapi32.dll SCM calls in ServiceManager.au3. Not without additional research (F4).
- Know that two service libraries coexist and choose the right one for a stop operation. Not without reading ServiceManager.au3's header (F5).

Overall: adequate for understanding the script's behaviour and adding process-side features; inadequate for safe additions to the service-stop path without reading code that CLAUDE.md does not point to.

---

## Checklist Verdicts

| Check | Verdict | Evidence |
|---|---|---|
| `## Agent skills` block present | PASS | CLAUDE.md lines 168–177 |
| `### Issue tracker` sub-heading | PASS | Line 170 |
| `### Domain docs` sub-heading | PASS | Line 174 |
| `_TrayNotify` documented as 2 seconds | PASS | Line 154: `AdlibRegister("_ClearTrayNotify", 2000)` |
| `_SM_PascalCase` referenced with CODING_STANDARDS.md authority | PASS (but conflicted) | Line 77; see F3 |
| Pointer to `docs/adr/` | PASS | Line 176 |
| No reference to `_miscpopups` (lowercase) | FAIL | Line 59; see F1 |
| No reference to `_CloseInstaller` | FAIL | Line 58; see F1 |
| `CheckElapsedTime` has leading underscore | FAIL | Line 61; see F2 |
| DllCall conventions documented | PARTIAL | kernel32 yes; advapi32 no; see F4 |
| Two-library architecture documented | PARTIAL | ServiceControl yes; ServiceManager absent; see F5 |
