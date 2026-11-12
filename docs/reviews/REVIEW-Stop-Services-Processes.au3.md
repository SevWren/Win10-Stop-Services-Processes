# Code Review: Stop Services Processes.au3
Reviewer: T05 Independent Review Agent
Date: 2026-11-11
Branch: arch/service-manager-migration

## SHA-256 Hash
d2722fe34fe2c697d8179e803f753be732fca4ff6e6f925ad44724350465dab9  Stop Services Processes.au3

---

## Standards

### Findings

**STD-01 — PASS — Function Naming: Public Hotkey Handlers (PascalCase)**
All four hotkey-bound functions use PascalCase as required:
- `ToggleScript` (Shift+F1)
- `SetProcessPriority` (Ctrl+Shift+9)
- `LockProcessPriority` (Ctrl+Alt+Shift+9)
- `_exit` (ScrollLock+Pause) — this is a private exit function, correctly prefixed with underscore

**STD-02 — PASS — Function Naming: Private/Internal Functions (_UnderscorePascalCase)**
All internal functions correctly prefixed:
`_CloseInstaller`, `_RunServiceBatchStop`, `_LogMessage`, `_CheckAndRotateLogFile`,
`_PriorityWatchdog`, `_GetProcessPriorityByPID`, `_WinAPIPriorityClassToAutoItConst`,
`_PriorityConstantToName`, `_TrayNotify`, `_ClearTrayNotify`, `_miscpopups`, `_exit`

One naming note: `CheckElapsedTime` (line 255) is a private helper but lacks the `_` prefix.
This is a pre-existing baseline condition; `CODING_STANDARDS.md` does not explicitly require
the underscore on every non-hotkey function (only "internal/private" ones). Flagging as
MINOR since it deviates from the implied convention.
Severity: MINOR

**STD-03 — PASS — Duplicate #include Directives**
Baseline had 3 duplicate includes (`<WinAPI.au3>`, `<WinAPIProc.au3>`, `<Array.au3>`) and an
absolute-path include for `ServiceControl.au3`. Current file has exactly 8 unique `#include`
directives — no duplicates detected. REQ-012 addressed.

**STD-04 — PASS — Duplicate HotKeySet Registrations**
Baseline had 2 duplicate `HotKeySet` entries (`"+^9"` and `"^!+9"`). Current file has exactly
4 `HotKeySet` registrations — one per hotkey, no duplicates. REQ-012 addressed.

**STD-05 — PASS — $iLastStopProcesses Global Declaration**
Line 65: `Global $iLastStopProcesses = 0` is present, uncommented, and in the globals section.
Baseline had it commented out (`; Global $iLastStopProcesses`). REQ-011 addressed.

**STD-06 — MINOR — Logging via _LogMessage**
All runtime log messages route through `_LogMessage`. `ConsoleWrite` appears only in:
- Initialization/log-setup code (lines 82–105): acceptable per CODING_STANDARDS.md ("only in
  init code is acceptable").
- Inside `_LogMessage` itself as the console mirror (line 247): correct.
- Inside `_miscpopups` (lines 588, 592): these are bare `ConsoleWrite` calls inside a
  function body that runs during the monitoring loop, not initialization code.

Severity: MINOR — `_miscpopups` uses `ConsoleWrite` directly instead of `_LogMessage`.
Specifically lines 588 (`"Closing AdvancedRenamer Popup"`) and 592 (`"Closing Sublime Popup"`).
This is a low-impact finding since `_miscpopups` is a cosmetic utility function, but it
violates the standard that "direct ConsoleWrite calls outside of initialization/debug code
are NOT permitted."

**STD-07 — PASS — Timing Constants Defined as Global Const in Named Region**
All 6 required constants are present in the `#Region ;Timing constants` block (lines 39–48):
- `Global Const $PROC_POLL_INTERVAL_SEC   = 2`
- `Global Const $SVC_POLL_INTERVAL_SEC    = 10`
- `Global Const $MAIN_LOOP_SLEEP_MS       = 500`
- `Global Const $PRIORITY_WATCHDOG_MS     = 10000`
- `Global Const $SVC_BATCH_TIMEOUT_MS     = 20000`
- `Global Const $SVC_BATCH_POLL_MS        = 500`

**STD-08 — PASS — AdlibRegister Uses Named Constant**
Line 419: `AdlibRegister("_PriorityWatchdog", $PRIORITY_WATCHDOG_MS)`
Uses `$PRIORITY_WATCHDOG_MS`, not a hardcoded literal. Correct.

**STD-09 — PASS — Path Portability**
Baseline had three machine-specific paths. All three are now portable:
- `#include "Includes\ServiceControl.au3"` (line 18) — relative, no absolute path.
- `#include "Includes\ServiceManager.au3"` (line 20) — new module, relative.
- `#AutoIt3Wrapper_Outfile_x64=.\release\Stop Services - Processes.exe` (line 4) — relative.
- `#AutoIt3Wrapper_Res_Icon_Add=ff7.ico` (line 9) — relative (filename only).
- `$iconfile = @ScriptDir & "\ff7.ico"` (line 67) — `@ScriptDir` macro, portable.
- `$sLogFile = @HomeDrive & "\login\closure_log.txt"` (line 70) — `@HomeDrive` macro, portable.
No hardcoded `C:\github\`, `%HOMEDRIVE%\Users\mmuel\`, or desktop paths found. REQ-014 addressed.

**STD-10 — PASS — #include-once Not Present**
`#include-once` does not appear in the file. Correct for an entry-point script.

**STD-11 — PASS — $PROCESS_IDLE Declared as Global Const**
Line 74: `Global Const $PROCESS_IDLE = 0` — declared correctly.

**STD-12 — PASS — TrayNotify Uses ToolTip via _TrayNotify**
`_TrayNotify` (line 570) calls `ToolTip(...)`, not `TrayTip(...)`. All watchdog notifications
route through `_TrayNotify`. No bare `TrayTip` calls found.

**STD-13 — INFORMATIONAL — CheckElapsedTime Missing Underscore Prefix (judgement call)**
`CheckElapsedTime` at line 255 is a private helper but does not follow `_UnderscorePascalCase`.
This was present in the baseline and is not a regression, but it is a mild naming inconsistency.
Severity: INFORMATIONAL

### Summary

Standards axis: 12 of 12 required checks pass. Two additional findings:
- 1 MINOR: `_miscpopups` uses bare `ConsoleWrite` (STD-06)
- 1 INFORMATIONAL: `CheckElapsedTime` missing `_` prefix (STD-13, judgement call)

No BLOCKERs or CRITICALs on the Standards axis.

---

## Spec

### Findings

**SPEC-01 — PASS — REQ-010: Service Inventory Has Exactly 9 Services**
`_RunServiceBatchStop()` (lines 198–200) declares:
```autoit
Local $aNames[9] = [ _
    "FDResPub", "fdPHost", "TrustedInstaller", "wuauserv", _
    "UsoSvc", "DoSvc", "WaaSMedicSvc", "SSDPSRV", "sppsvc"]
```
Exactly 9 services. All 9 from the REQ-010 canonical list are present.
Baseline had only 6 services and was missing `FDResPub`, `fdPHost`, `SSDPSRV`. Fixed.

**SPEC-02 — PASS — REQ-011: $iLastStopProcesses Declared as Global**
Line 65: `Global $iLastStopProcesses = 0` — present, not commented out.
Baseline had it commented out. Fixed.

**SPEC-03 — PASS — REQ-012: Duplicate #include and HotKeySet Removed**
All 3 duplicate `#include` pairs and 2 duplicate `HotKeySet` pairs from the baseline are absent.

**SPEC-04 — PASS — REQ-013: Service Polling Uses $SVC_POLL_INTERVAL_SEC (10)**
Line 132: `If CheckElapsedTime($iLastStopServices, $SVC_POLL_INTERVAL_SEC) Then`
`$SVC_POLL_INTERVAL_SEC = 10` (line 43). Baseline used hardcoded `2`. Fixed.

**SPEC-05 — PASS — REQ-014: Include Paths Portable**
Confirmed under STD-09. All includes are relative. No machine-specific paths.

**SPEC-06 — PASS — Architecture Integration: _RunServiceBatchStop Calls _SM_StopServicesBatch**
Line 202: `Local $aResults = _SM_StopServicesBatch($aNames, $SVC_BATCH_TIMEOUT_MS, $SVC_BATCH_POLL_MS)`
Correctly passes named constants for timeout and poll interval.

**SPEC-07 — PASS — Architecture Integration: All 5 Outcome Codes Logged**
The `Select` block in `_RunServiceBatchStop` (lines 212–225) handles all 5 outcome codes
defined in ARCHITECTURE.md:
- `$SM_OUTCOME_STOPPED` → logged at level 1
- `$SM_OUTCOME_ALREADY` → logged at level 2
- `$SM_OUTCOME_TIMEDOUT` → logged at level 0
- `$SM_OUTCOME_UNAVAILABLE` → logged at level 2
- `$SM_OUTCOME_FAILED` → logged at level 0 with Win32 error code

Additionally a `Case Else` branch logs unknown outcomes (line 223–224). This is a defensive
addition beyond spec; no objection.

One observation: the architecture spec uses string literals `"STOPPED"`, `"ALREADY_STOPPED"`,
etc. in its reference implementation snippet. The actual code uses symbolic constants
`$SM_OUTCOME_STOPPED`, `$SM_OUTCOME_ALREADY`, etc., which are presumably defined in
`Includes/ServiceManager.au3`. This is correct practice (symbolic constants preferred over
string literals), but reviewers should verify those constants are defined in ServiceManager.au3
with the expected string values to confirm the match. This review covers the main script only.

**SPEC-08 — PASS — All 4 Hotkeys Preserved**
- `{ScrollLock}{PAUSE}` → `_exit` (line 33)
- `+{F1}` → `ToggleScript` (line 34)
- `+^9` → `SetProcessPriority` (line 35)
- `^!+9` → `LockProcessPriority` (line 36)
All four hotkeys present, no duplicates. Correct.

**SPEC-09 — PASS — Priority Watchdog Functions Fully Preserved**
All four watchdog functions are present:
- `_PriorityWatchdog` (line 430)
- `_GetProcessPriorityByPID` (line 493)
- `_WinAPIPriorityClassToAutoItConst` (line 521)
- `_PriorityConstantToName` (line 544)
Implementation matches the WinAPI priority reading pattern in CLAUDE.md:
`PROCESS_QUERY_LIMITED_INFORMATION`, direct `DllCall`, immediate `@error` capture,
`_WinAPI_GetLastError()` before `CloseHandle`.

**SPEC-10 — PASS — Log Rotation Preserved: _CheckAndRotateLogFile Called with $iLogMaxAgeDays = 7**
Line 69: `Global $iLogMaxAgeDays = 7`
Line 104: `_CheckAndRotateLogFile($sLogFile, $iLogMaxAgeDays)` — called correctly in init block.
Function is fully defined at lines 145–160.

**SPEC-11 — PASS — _miscpopups Preserved with Both Checks**
Lines 587–593: `_miscpopups()` checks for both:
- `[CLASS:TPleaseRegisterForm]` (AdvancedRenamer popup)
- `"This is an unregistered copy"` (Sublime Text popup)
Both checks present as required.

**SPEC-12 — PASS — _exit Preserved**
Lines 600–604: `_exit()` calls `_LogMessage` twice, then `Exit`. Correct.

**SPEC-13 — INFORMATIONAL — $SM_OUTCOME_* Constants Source Not Verified in This Review**
`_RunServiceBatchStop` references `$SM_OUTCOME_STOPPED`, `$SM_OUTCOME_ALREADY`,
`$SM_OUTCOME_TIMEDOUT`, `$SM_OUTCOME_UNAVAILABLE`, `$SM_OUTCOME_FAILED`. These are expected
to be declared in `Includes/ServiceManager.au3`. Verification of that file is out of scope for
this review (which covers the main script only), but should be confirmed in the ServiceManager
review pass.
Severity: INFORMATIONAL

**SPEC-15 — PASS — Superseded function `_stopservicescustom` confirmed removed**
MR-SPEC-003 noted that the review had not verified whether the old `_stopservicescustom` function
(which called `ServiceControl.au3` directly) was removed from the file. Inspection of
`Stop Services Processes.au3` confirms: no definition or call site for `_stopservicescustom`
exists anywhere in the current file. The monitoring loop (line 133) calls `_RunServiceBatchStop()`
exclusively. The superseded function has been fully removed with no residual dead code.

**SPEC-14 — INFORMATIONAL — CLAUDE.md _TrayNotify Auto-Clear Discrepancy**
CLAUDE.md (line 151) states `_TrayNotify` auto-clears "after 3 seconds via
`AdlibRegister("_ClearTrayNotify", 3000)`". The actual implementation at line 572 uses
`AdlibRegister("_ClearTrayNotify", 2000)` (2 seconds). This is a documentation/implementation
mismatch. The behavior is functional either way; the CLAUDE.md description is stale.
Severity: INFORMATIONAL

### Summary

Spec axis: 13 of 13 required checks pass. Zero BLOCKERs, CRITICALs, or MAJORs on the Spec axis.
Two INFORMATIONAL findings: $SM_OUTCOME_* constant values to be verified in ServiceManager review
(SPEC-13); _TrayNotify clear delay documented as 3s but implemented as 2s (SPEC-14).
SPEC-15 (new): Superseded `_stopservicescustom` function confirmed absent from the file.

---

## Disposition

**APPROVED WITH CONDITIONS**

The file satisfies all BLOCKER and CRITICAL requirements. All baseline defects targeted by
REQ-010 through REQ-014 are correctly resolved. The architecture integration contract
(_RunServiceBatchStop calling _SM_StopServicesBatch with all 5 outcome codes) is implemented
correctly. All hotkeys, the priority watchdog, log rotation, and _miscpopups are intact.

Conditions to resolve before final APPROVED status:

1. (MINOR — STD-06) Replace the two bare `ConsoleWrite` calls in `_miscpopups` (lines
   588 and 592) with `_LogMessage` calls. This is a standards violation, not a spec defect,
   but it should be corrected to maintain logging hygiene.

2. (INFORMATIONAL — SPEC-13) Confirm in the ServiceManager.au3 review that `$SM_OUTCOME_STOPPED`,
   `$SM_OUTCOME_ALREADY`, `$SM_OUTCOME_TIMEDOUT`, `$SM_OUTCOME_UNAVAILABLE`, and
   `$SM_OUTCOME_FAILED` are defined with the string values expected by _RunServiceBatchStop.

3. (INFORMATIONAL — SPEC-14) Correct CLAUDE.md to reflect the actual 2000 ms auto-clear delay
   (or change the implementation to 3000 ms if 3s was intentional).

---

**Summary:** 2 Standards findings (1 hard, 1 judgement call), 2 Spec findings; worst Standards issue: MINOR — bare `ConsoleWrite` calls in `_miscpopups` violate the no-direct-ConsoleWrite-outside-init standard (STD-06); worst Spec issue: none above INFORMATIONAL — superseded `_stopservicescustom` confirmed removed (SPEC-15 PASS); two open INFORMATIONALs are `$SM_OUTCOME_*` constant cross-verification (SPEC-13) and CLAUDE.md auto-clear delay mismatch (SPEC-14).
