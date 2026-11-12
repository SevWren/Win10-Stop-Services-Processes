# CR-01 — Code Review: Stop Services Processes.au3

**Fixed point:** `ab5b012`
**HEAD commits in scope:**
- `1d8a5ea` feat: replace broken service-stop path with native SCM batch-stop module
- `2a62801` chore(cleanup)
- `09b99ba` Added claude skill sets

**Spec sources:** `.scratch/service-manager-migration/issues/04-integration.md`,
`docs/REQUIREMENTS.md` (REQ-010 – REQ-014)

**Standards sources:** `CODING_STANDARDS.md`, `CLAUDE.md`

---

## Standards

Standards evaluated against `CODING_STANDARDS.md` and the Fowler smell baseline.
"Hard violation" = documented standard breach. "Judgement call" = smell heuristic.

### Pre-existing issues carried forward (not introduced by this diff)

**1. Function naming — `_miscpopups` (pre-existing, carried forward)**
`CODING_STANDARDS.md` §Function Naming requires internal/private functions to use
`_UnderscorePascalCase`. `_miscpopups` is all-lowercase and was present before `ab5b012`.
The diff moves the function to a new location in the file but does not rename it.
This is not a new violation but it is unresolved.

**2. `_TrayNotify` auto-clear interval mismatch (pre-existing, carried forward)**
`CLAUDE.md` documents auto-clear after 3 seconds. `_ClearTrayNotify` is registered with
`AdlibRegister("_ClearTrayNotify", 2000)` — 2 seconds. Unchanged from baseline.

### Violations correctly fixed by this diff

**3. Duplicate `#include`, `HotKeySet`, `Global` declarations — FIXED**
`CODING_STANDARDS.md` §Duplicate Prevention prohibits duplicate `#include` directives and
duplicate `HotKeySet` calls. The old code had `#include <WinAPI.au3>` twice, duplicate
`HotKeySet("+^9", ...)` and `HotKeySet("^!+9", ...)`, and duplicate `Global` declarations
for `$sProcesses`, `$bScriptRunning`, `$iLogLevel`, `$bLogToConsole`, `$PROCESS_IDLE`,
and all three `$aPriorityWatch*` arrays. All removed.

**4. Hardcoded absolute paths in `#include` and wrapper directives — FIXED**
`CODING_STANDARDS.md` §Path Portability: "No hardcoded checkout roots, user-profile paths,
or desktop paths in source or docs." Old directives:
- `#AutoIt3Wrapper_Outfile_x64=..\..\..\Users\mmuel\Desktop\Stop Services - Processes.Exe`
- `#AutoIt3Wrapper_Res_Icon_Add=C:\github\my-github-info\...\ff7.ico`
- `#include "C:\github\my-github-info\...\ServiceControl.au3"`
All replaced with working-directory-relative equivalents.

**5. Direct `ConsoleWrite` in `_miscpopups` — FIXED**
`CODING_STANDARDS.md` §Logging: "Direct `ConsoleWrite` calls outside of
initialization/debug code are NOT permitted." Old `_miscpopups` used `ConsoleWrite`.
New version uses `_LogMessage`.

### New code — no violations introduced

**6. `@error` capture in `_GetProcessPriorityByPID`**
Pattern is correct and unchanged in logic. Comments `; capture IMMEDIATELY` and
`; before CloseHandle` are added for clarity. Conforms to `CODING_STANDARDS.md` §@error Capture.

**7. Handle ownership in `_GetProcessPriorityByPID`**
`CloseHandle` is called on every path after `OpenProcess` succeeds.
Conforms to `CODING_STANDARDS.md` §Handle Ownership.

**8. `_RunServiceBatchStop` naming**
`_UnderscorePascalCase` — correct for a private internal function.

### Smell baseline

**9. Data Clumps — judgement call (pre-existing, unchanged)**
`$aPriorityWatchPIDs`, `$aPriorityWatchTargets`, `$aPriorityWatchNames` are three parallel
global arrays that always travel together. Candidate for a typed record. Not introduced by
this diff.

**10. Duplicated Code — judgement call (pre-existing, unchanged)**
`_PriorityWatchdog` contains two nearly identical three-array-delete blocks (one at
"process not found", one at "exited between drift detection and restore"). Not introduced
by this diff.

**11. Mysterious Name — judgement call (pre-existing, unchanged)**
`$taskcloseran` is declared in globals but its purpose is not evident from the name and it
appears unused in the visible diff. Not introduced by this diff.

---

## Spec

Spec evaluated against `04-integration.md` checklist and `REQUIREMENTS.md` REQ-010 – REQ-014.

### Requirements satisfied

**REQ-010 — Service inventory matches enterprise prompt (9 services)**
`_RunServiceBatchStop` declares:
```
Local $aNames[9] = ["FDResPub", "fdPHost", "TrustedInstaller", "wuauserv",
    "UsoSvc", "DoSvc", "WaaSMedicSvc", "SSDPSRV", "sppsvc"]
```
Exactly the canonical 9-service list from REQ-010. Satisfied.

**REQ-011 — `$iLastStopProcesses` declared**
`Global $iLastStopProcesses = 0` added to globals, with comment `; timer for
process-kill cycle (0 → fires on first check)`. Satisfied.

**REQ-012 — Duplicate `#include` and `HotKeySet` lines removed**
All documented duplicates removed. Satisfied.

**REQ-013 — Service poll interval changed to 10 seconds**
`$SVC_POLL_INTERVAL_SEC = 10` declared as a named constant.
`ToggleScript` calls `CheckElapsedTime($iLastStopServices, $SVC_POLL_INTERVAL_SEC)`.
Satisfied.

**REQ-014 — Include paths portable**
`"Includes\ServiceControl.au3"`, `"Includes\ServiceManager.au3"`, and
`.\release\Stop Services - Processes.exe` — all working-directory-relative. Satisfied.

**04-integration.md checklist items**
- Named timing constants added: `$PROC_POLL_INTERVAL_SEC`, `$SVC_POLL_INTERVAL_SEC`,
  `$MAIN_LOOP_SLEEP_MS`, `$PRIORITY_WATCHDOG_MS`, `$SVC_BATCH_TIMEOUT_MS`,
  `$SVC_BATCH_POLL_MS`. All used at their call sites. Satisfied.
- `_stopservicescustom()` removed; `_RunServiceBatchStop()` calls
  `_SM_StopServicesBatch($aNames, $SVC_BATCH_TIMEOUT_MS, $SVC_BATCH_POLL_MS)`. Satisfied.
- Each `_SM` result row outcome logged at appropriate level (0=Error, 1=Info, 2=Verbose)
  via a `Select` block mapping every `$SM_OUTCOME_*` constant. Satisfied.
- All 4 hotkeys preserved, no duplicates. Satisfied.
- Priority watchdog, popups, logging, log rotation all preserved. Satisfied.

### Missing requirements

None found. All 04-integration.md checklist items and all in-scope REQs are implemented
and verifiable from the diff.

### Scope creep

None found. The only change outside the explicit checklist is the upgrade of `_miscpopups`
from `ConsoleWrite` to `_LogMessage`, which corrects a pre-existing standards violation and
aligns with the stated "preserve logging" intent of the task.

### Implementation correctness

**`sppsvc` special handling removed — correct**
The old `_stopservicescustom()` had a second block that called `ProcessClose("sppsvc.exe")`
as a fallback after `_stopservice`. The spec says "Replace `_stopservicescustom()` body
with `_SM_StopServicesBatch()` call" and does not ask for the fallback to be preserved.
`sppsvc` remains in the 9-service batch array. The removal is consistent with the spec.

**`$iLastStopProcesses = 0` — correct per REQ-011**
REQ-011 explicitly specifies `= 0` ("fires on first check"). CLAUDE.md had `TimerInit()`
but REQ-011 is the governing spec for this change. No conflict.

---

**Summary:** Standards axis — 2 findings (pre-existing naming violation `_miscpopups` and
`_TrayNotify` 2 s/3 s mismatch carried forward; no violations introduced by this diff);
worst issue: `_miscpopups` naming violates `CODING_STANDARDS.md` §Function Naming.
Spec axis — 0 findings; all checklist items and REQs satisfied; no missing requirements,
no scope creep, no incorrect implementations.
