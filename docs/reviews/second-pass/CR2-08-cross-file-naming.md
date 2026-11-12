# CR2-08 — Cross-File Naming Consistency Audit (Standards Axis)

**Date:** 2026-11-12
**Auditor:** Standards sub-agent
**Scope:** All `.au3` files in `/home/vercel-sandbox/repo` (production + test; BackUp/ excluded per CLAUDE.md)
**Standards sources:** `CODING_STANDARDS.md`, `CLAUDE.md`

---

## Files Examined

| File | Role |
|---|---|
| `Stop Services Processes.au3` | Primary script |
| `Includes/ServiceControl.au3` | Custom advapi32.dll wrapper library |
| `Includes/ServiceManager.au3` | Batch-stop adapter (new module) |
| `Tests/ServiceManager.Tests.au3` | Test harness |
| `test_process_close.au3` | Scratch/standalone test script |
| `Includes/Date.au3`, `Includes/Misc.au3`, `Includes/AutoItConstants.au3`, `Includes/MsgBoxConstants.au3` | Bundled standard AutoIt includes (read-only; not subject to repo standards) |

---

## Check 1 — Private helper functions use `_UnderscorePascalCase`

**Standard:** `CODING_STANDARDS.md` §Function Naming — internal/private helpers must be `_UnderscorePascalCase`.

### Finding 1.1 — VIOLATION: `_exit` in `Stop Services Processes.au3` (line 637)

```autoit
Func _exit()
```

`_exit` is entirely lowercase after the underscore. The standard requires `_UnderscorePascalCase`, which would be `_Exit`. This is a hotkey-bound function (`HotKeySet("{ScrollLock}{PAUSE}", "_exit")`, line 33); by CLAUDE.md it is classified as internal/private and must carry a leading underscore (which it does) but the body must be PascalCase.

**Severity:** Hard violation — documented standard (CODING_STANDARDS.md §Function Naming).

### Finding 1.2 — PASS: All other private helpers

All other `_`-prefixed functions in production code follow `_UnderscorePascalCase`:
`_CheckAndRotateLogFile`, `_KillProcessList`, `_RunServiceBatchStop`, `_LogMessage`, `_CheckElapsedTime`, `_PriorityWatchdog`, `_GetProcessPriorityByPID`, `_WinAPIPriorityClassToAutoItConst`, `_PriorityConstantToName`, `_TrayNotify`, `_ClearTrayNotify`, `_MiscPopups`.

All `_SM_*` helpers in `Includes/ServiceManager.au3` follow `_SM_PascalCase` as permitted by CLAUDE.md §Coding Conventions — Function Naming.

> **Note on `CODING_STANDARDS.md` vs `CLAUDE.md` conflict:** `CODING_STANDARDS.md` removed the `_SM_PascalCase` tier in its CR-09 note, instructing all helpers to use plain `_UnderscorePascalCase`. However, `CODING_STANDARDS.md` §Function Naming explicitly states "If this section and `CODING_STANDARDS.md` ever conflict, `CODING_STANDARDS.md` wins" — but that statement is *in* `CODING_STANDARDS.md` and refers to `CLAUDE.md` as the authority. Cross-reading both documents: `CLAUDE.md` §Coding Conventions defines the `_SM_PascalCase` tier; `CODING_STANDARDS.md` CR-09 note says the tier "is not defined in `CLAUDE.md`" and was removed. The CR-09 note is itself contradicted by `CLAUDE.md` line 75 which still lists `_SM_PascalCase` as a named convention. This is a **standards conflict between the two documents**, not a code violation — it is flagged separately in §Supplementary Observations below. The ServiceManager.au3 functions are consistent with `CLAUDE.md` and are not marked as violations here.

### Finding 1.3 — PASS (test file): Test harness functions

`Tests/ServiceManager.Tests.au3` uses `_TestAssert`, `_PrintResults`, `_Test_*` — all `_UnderscorePascalCase`. No violation.

---

## Check 2 — `$SM_*` prefix used exclusively for ServiceManager module constants/globals

**Standard:** `CLAUDE.md` §Coding Conventions — only the service-manager module uses `_SM_` prefix.

**Result: PASS.**

`$SM_*` variables appear in exactly three files:
- `Includes/ServiceManager.au3` — defined here (all `Global Const $SM_*`)
- `Stop Services Processes.au3` — consumed only via `$SM_OUTCOME_*` constants in `_RunServiceBatchStop` (lines 249–257)
- `Tests/ServiceManager.Tests.au3` — consumed in assertions

No other file defines or introduces a `$SM_*` variable. The prefix is used exclusively by and for the ServiceManager module.

---

## Check 3 — `$LOG_LEVEL_*` and `$LOG_TYPE_*` defined in exactly ONE place

**Standard:** No global constant should be redefined across files; duplicates cause AU3Check `-w 3`/`-w 4` warnings.

### Finding 3.1 — VIOLATION: `$LOG_LEVEL_*` defined in TWO files

`$LOG_LEVEL_ERROR`, `$LOG_LEVEL_INFO`, and `$LOG_LEVEL_VERBOSE` are declared with `Global Const` in both:

- `Stop Services Processes.au3` lines 54–56
- `Includes/ServiceManager.au3` lines 100–102

Both carry identical values (0, 1, 2). Because `ServiceManager.au3` is `#include`d by the main script (line 20), both definitions are in scope simultaneously. This is a `Global Const` redefinition that AU3Check `-w 3`/`-w 4` will flag.

**Severity:** Hard violation — `CODING_STANDARDS.md` §AU3Check Compliance (all files must satisfy AU3Check `-w 3 -w 4`). The duplicate in `ServiceManager.au3` lines 100–102 should be removed; the authoritative definition belongs in `Stop Services Processes.au3`.

### Finding 3.2 — VIOLATION: `$LOG_TYPE_SYSTEM` and `$LOG_TYPE_SERVICE` defined in TWO files

`$LOG_TYPE_SYSTEM = "System"` and `$LOG_TYPE_SERVICE = "Service"` are declared with `Global Const` in both:

- `Stop Services Processes.au3` lines 60 and 62
- `Includes/ServiceManager.au3` lines 108–109

Same redefinition issue as 3.1.

**Severity:** Hard violation — same `AU3Check` compliance rule.

**Note:** `$LOG_TYPE_PROCESS`, `$LOG_TYPE_PROCESS_PRIORITY`, and `$LOG_TYPE_PRIORITY_WATCHDOG` are defined only in `Stop Services Processes.au3` — no violation for those.

---

## Check 4 — `$AUTOIT_PRIORITY_*` defined once, used consistently

**Standard:** Constants must be defined in exactly one place (AU3Check compliance; no-duplicate rule).

**Result: PASS.**

`$AUTOIT_PRIORITY_IDLE` through `$AUTOIT_PRIORITY_REALTIME` are declared exclusively in `Stop Services Processes.au3` lines 72–77. No other `.au3` file in the production or test tree defines any `$AUTOIT_PRIORITY_*` name. All usages in `Stop Services Processes.au3` reference these constants by name consistently.

---

## Check 5 — `$aSvcTargetNames` is a global config, not a local in a function

**Standard:** Per `CLAUDE.md` architecture notes and `CODING_STANDARDS.md` §Configuration, the service target list is a global config array.

**Result: PASS.**

```
Stop Services Processes.au3:84: Global $aSvcTargetNames[9] = [ _
```

Declared `Global` at line 84 in the Configuration region. No `Local $aSvcTargetNames` exists anywhere in the codebase.

---

## Check 6 — Old function names do not exist

**Standard:** `CODING_STANDARDS.md` §Function Naming — the following old names must not appear: `_miscpopups` (lowercase), `_CloseInstaller`, `CheckElapsedTime` (without `_` prefix).

### Finding 6.1 — PASS: `_miscpopups` (lowercase call) does not exist

The only occurrences in the codebase are `_MiscPopups()` (correctly cased). The comment on line 619 reads `; Func _MiscPopups` and the declaration on line 623 is `Func _MiscPopups()`. No lowercase `_miscpopups` call or definition exists.

> **Note:** CLAUDE.md §Architecture still references `_miscpopups()` (line 59) as the old name ("calls `_miscpopups()`"). This is a documentation artefact in CLAUDE.md — the live code uses `_MiscPopups()`. Not a code violation but noted as a stale doc reference.

### Finding 6.2 — PASS: `_CloseInstaller` does not exist

No function named `_CloseInstaller` exists in any production file. The process-kill function is now `_KillProcessList()`.

> **Note:** CLAUDE.md §Coding Conventions §Function Naming still lists `_CloseInstaller` as an example of `_UnderscorePascalCase` (line 74). This is a stale example — the actual function was renamed. Not a code violation.

### Finding 6.3 — PASS: `CheckElapsedTime` (unprefixed) does not exist

No `Func CheckElapsedTime` or bare call to `CheckElapsedTime(` exists. The function is `_CheckElapsedTime` throughout.

> **Note:** CLAUDE.md §Architecture (line 61) still references `CheckElapsedTime($iStartTime, $iIntervalSeconds)` without the underscore prefix. This is a stale CLAUDE.md reference — the live code is `_CheckElapsedTime`. Not a code violation.

---

## Supplementary Observations

### SO-1 — Standards conflict: `_SM_PascalCase` tier

`CODING_STANDARDS.md` CR-09 note states the `_SM_PascalCase` tier "is not defined in `CLAUDE.md`" and was removed from `CODING_STANDARDS.md`. However, `CLAUDE.md` §Coding Conventions §Function Naming line 75 still defines it: `_SM_PascalCase — _SM_StopServicesBatch, _SM_GetServiceState`. The two documents disagree. `CODING_STANDARDS.md` §Function Naming also states: "If this section and `CODING_STANDARDS.md` ever conflict, `CODING_STANDARDS.md` wins" — but this statement in `CODING_STANDARDS.md` reads as self-referential. The intent appears to be that `CODING_STANDARDS.md` should override `CLAUDE.md`, meaning the `_SM_` tier is deprecated. This conflict should be resolved by updating `CLAUDE.md` to remove or align the `_SM_PascalCase` entry.

### SO-2 — Stale CLAUDE.md references to old function names

CLAUDE.md references three old names in architecture prose (`_miscpopups`, `CheckElapsedTime`, `_CloseInstaller`) that have been renamed in production code. These are documentation accuracy issues, not naming violations in the code.

### SO-3 — `test_process_close.au3` — not subject to repo standards

`test_process_close.au3` is a standalone scratch/exploratory file with no functions defined. It uses bare `ConsoleWrite` and a plain `While` loop. It is not part of the production build path. No naming standards apply to it; noted for completeness.

---

## Summary

| Check | Result | Severity |
|---|---|---|
| 1. Private helpers use `_UnderscorePascalCase` | **FAIL** — `_exit` is all-lowercase | Hard violation |
| 2. `$SM_*` prefix exclusive to ServiceManager | PASS | — |
| 3. `$LOG_LEVEL_*` / `$LOG_TYPE_*` defined in exactly one place | **FAIL** — both sets redefined in `ServiceManager.au3` | Hard violation (2 findings) |
| 4. `$AUTOIT_PRIORITY_*` defined once, used consistently | PASS | — |
| 5. `$aSvcTargetNames` is global, not local | PASS | — |
| 6. Old names absent (`_miscpopups`, `_CloseInstaller`, `CheckElapsedTime`) | PASS | — |

**Total findings: 3 hard violations across 2 checks.**
**Worst issue:** Check 3 — `$LOG_LEVEL_*` and `$LOG_TYPE_*` redefined in `Includes/ServiceManager.au3` will trigger AU3Check `-w 3`/`-w 4` failures at compile time.
