# CR2-16 — README.md Second-Pass Code Review

**Review date:** 2026-11-12
**Fixed point:** `README.md` (current) vs. `Stop Services Processes.au3` (current)
**Spec source:** Current codebase (`Stop Services Processes.au3`, `Includes/ServiceManager.au3`)
**Reviewer:** Sub-agent pair (smell-baseline axis + spec axis), merged single report

---

## Executive Summary

The README is largely accurate and well-aligned with the current codebase. Two substantive defects were found: (1) the process list in the README is **incomplete** — three process names present in `$sProcesses[]` are absent from the documented list, and (2) the README never states the **process-kill polling interval** (2 seconds), only the service-stop interval (10 seconds), which creates an asymmetric gap in the timing documentation. All smell-baseline checklist items pass. No false feature claims were found.

---

## Smell-Baseline Axis

### SB-1 — 9 services listed (not 6)?

**PASS.**

README line 57: "Stops a batch of 9 services each cycle". Script line 84: `Global $aSvcTargetNames[9]`. The array is 9 elements. The count matches.

---

### SB-2 — 10-second polling mentioned (not 2-second)?

**PASS with observation.**

README line 57 states the service batch runs "every 10 seconds". Script constant: `$SVC_POLL_INTERVAL_SEC = 10` (line 43). Correct.

README line 24 states the priority watchdog monitors "every ~10 seconds". Script constant: `$PRIORITY_WATCHDOG_MS = 10000` (line 45). Correct.

**Observation (not a defect on this checklist item, but see SB-2a below):** The README never documents the *process-kill* polling interval (2 seconds, `$PROC_POLL_INTERVAL_SEC = 2`, line 42). This omission is recorded as a spec-axis finding SF-2.

---

### SB-3 — `Includes/ServiceManager.au3` mentioned?

**PASS.**

README references `Includes/ServiceManager.au3` in two places: the Services section (line 57) and the Module Structure table (line 75). Both are accurate.

---

### SB-4 — Portable include paths mentioned?

**PASS.**

README Setup step 2 (line 83): "All include paths are working-directory-relative (e.g., `#include "Includes\ServiceManager.au3"`), so no hardcoded paths need to be updated when moving the script."

Script lines 18–20 confirm both includes use bare relative paths (`"Includes\ServiceControl.au3"`, `"Includes\ServiceManager.au3"`). Statement is accurate.

---

### SB-5 — Stale "paths are hardcoded" known limitation removed?

**PASS.**

The Known Limitations section (lines 113–117 of README) contains no blanket "hardcoded paths" claim. It now reads: "The icon path (`$iconfile`) and log file path (`$sLogFile`) may need to be updated for your system if the defaults do not apply." This is accurate and appropriately scoped.

---

### SB-6 — Module structure table present?

**PASS.**

README lines 71–77 contain a four-row Module Structure table covering `Stop Services Processes.au3`, `Includes/ServiceManager.au3`, `Includes/ServiceControl.au3`, and `Tests/ServiceManager.Tests.au3`. Roles described are accurate.

---

## Spec Axis

### SF-1 — Service list accuracy (all 9 names)

**PASS.**

README lines 59–67 list:

| README name | In `$aSvcTargetNames[9]` |
|---|---|
| `FDResPub` | Yes (index 0) |
| `fdPHost` | Yes (index 1) |
| `TrustedInstaller` | Yes (index 2) |
| `wuauserv` | Yes (index 3) |
| `UsoSvc` | Yes (index 4) |
| `DoSvc` | Yes (index 5) |
| `WaaSMedicSvc` | Yes (index 6) |
| `SSDPSRV` | Yes (index 7) |
| `sppsvc` | Yes (index 8) |

All nine service names match exactly (case-sensitive) with `$aSvcTargetNames` declared at script line 84–86.

---

### SF-2 — Process list accuracy and completeness

**DEFECT — Incomplete documentation.**

The README Processes section (lines 39–54) lists 16 named processes. The actual `$sProcesses[18]` array (script lines 96–100) contains 18 entries (note: `xgamehelper.exe` occupies both index 15 and 16, making the effective unique count 17).

Processes present in code but **absent from the README**:

| Process | Array index | Note |
|---|---|---|
| `UserOOBEBroker.exe` | — | Not listed in README at all |
| `backgroundTaskHost.exe` | 17 | Not listed in README at all |
| `xgamehelper.exe` | 15 and 16 | Appears twice in array (documented in BASELINE-INVENTORY.md as a preserved harmless no-op); README does not list it at any index |

The README also does not mention the array length (18) or the duplicate `xgamehelper.exe` entry.

**Severity:** Low — documentation gap, not a behavioural discrepancy. The script will terminate these processes despite their absence from the README.

---

### SF-3 — Hotkey documentation accuracy

**PASS.**

README documents four hotkeys. Verified against `HotKeySet` calls at script lines 33–36:

| README description | README key combo | Script `HotKeySet` binding | Match |
|---|---|---|---|
| Toggle monitoring loop | `Shift + F1` | `"+{F1}"` | Yes |
| Terminate script | `ScrollLock + PAUSE` | `"{ScrollLock}{PAUSE}"` | Yes |
| Set priority by name | `Shift + Ctrl + 9` | `"+^9"` (AutoIt: Shift+Ctrl+9) | Yes |
| Lock PID priority (watchdog) | `Ctrl + Alt + Shift + 9` | `"^!+9"` (AutoIt: Ctrl+Alt+Shift+9) | Yes |

All hotkey descriptions are accurate.

---

### SF-4 — Process-kill polling interval documentation

**DEFECT — Omission.**

The README documents the service-stop cycle (10 seconds, line 57) and the watchdog check interval (~10 seconds, line 24) but never states the **process-kill cycle interval**. The code defines `$PROC_POLL_INTERVAL_SEC = 2` (line 42) and uses it at line 167 (`_CheckElapsedTime($iLastStopProcesses, $PROC_POLL_INTERVAL_SEC)`).

The Features section says the script "periodically" terminates processes without quantifying the interval. The Setup section (line 89) mentions the `$sProcesses` array but not its timing.

**Severity:** Low — cosmetic documentation gap. No user-visible behaviour is misdescribed.

---

### SF-5 — Batch-stop timeout value

**PASS.**

README line 68: "polls all pending services against a shared 20-second deadline". Script line 46: `$SVC_BATCH_TIMEOUT_MS = 20000`. Accurate.

---

### SF-6 — Outcome codes documentation

**PASS.**

README line 68 and Feature bullet (line 12) list five outcome codes: `STOPPED`, `ALREADY_STOPPED`, `UNAVAILABLE`, `FAILED`, `TIMED_OUT`. `Includes/ServiceManager.au3` lines 55–59 define exactly these five constants (`$SM_OUTCOME_STOPPED`, `$SM_OUTCOME_ALREADY`, `$SM_OUTCOME_UNAVAILABLE`, `$SM_OUTCOME_FAILED`, `$SM_OUTCOME_TIMEDOUT`). Names and count match.

---

### SF-7 — Installation documentation accuracy

**PASS.**

README Setup step 2 correctly describes the relative `Includes\` layout. Steps 3–6 accurately describe configurable globals (`$iconfile`, `$sLogFile`, `$iLogLevel`, `$bLogToConsole`, `$sProcesses`, service array). All referenced variable names exist in the script.

README line 83 uses `#include "Includes\ServiceManager.au3"` as an example — this matches the actual include directive at script line 20.

README line 89 refers to "the service array inside `_RunServiceBatchStop()`" for customization — this is a minor inaccuracy. The service target list is now declared in the Configuration region as `$aSvcTargetNames` (script lines 83–86), not inside `_RunServiceBatchStop()`. The function body reads `$aSvcTargetNames` as a global; it no longer contains the list itself.

**Severity:** Low — instruction still leads the user to the correct outcome (the config region is immediately visible), but the named function is wrong.

---

### SF-8 — Priority watchdog feature description

**PASS.**

README lines 123–128 (Changelog v0.05) and the Hotkeys section (line 24) accurately describe the watchdog behaviour: sets priority immediately, monitors via `AdlibRegister`, auto-restores on drift, self-unregisters when process exits, supports multiple PIDs simultaneously, uses `ToolTip()` instead of `TrayTip()`. All of these behaviours are confirmed in `LockProcessPriority()` and `_PriorityWatchdog()`.

---

## Defect Summary

| ID | Location | Severity | Description |
|---|---|---|---|
| SF-2 | README "Processes" section | Low | Three processes in `$sProcesses[]` are undocumented: `UserOOBEBroker.exe`, `backgroundTaskHost.exe`, and `xgamehelper.exe` (which also appears twice in the array). |
| SF-4 | README "Features" / "Services" sections | Low | 2-second process-kill polling interval (`$PROC_POLL_INTERVAL_SEC = 2`) is never stated; only the 10-second service-stop interval is documented. |
| SF-7b | README Setup step 5 | Low | "the service array inside `_RunServiceBatchStop()`" is stale; the target list is now `$aSvcTargetNames` in the Configuration region, not inside the function body. |

---

## Smell-Baseline Pass/Fail Table

| Check | Result |
|---|---|
| 9 services listed | PASS |
| 10-second polling mentioned | PASS |
| `Includes/ServiceManager.au3` mentioned | PASS |
| Portable include paths mentioned | PASS |
| Stale "paths are hardcoded" limitation removed | PASS |
| Module structure table present | PASS |
