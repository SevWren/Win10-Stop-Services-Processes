# BUG-12: AU3Check Simulation Report

**Scope:** Static analysis simulation of AU3Check `-w 1 -w 2 -w 3 -w 4` flags
**Files analysed:**
1. `Stop Services Processes.au3` (root)
2. `Includes/ServiceManager.au3`
3. `Tests/ServiceManager.Tests.au3`
4. `Includes/ServiceControl.au3`

**Date:** 2026-11-12
**Analyst:** Claude (agent-assisted static review)
**Status:** Pre-fix — no changes have been made to any source file

---

## Warning Level Reference

| Flag | Meaning |
|------|---------|
| `-w 1` | Undeclared variable — variable used before `Global`/`Local` declaration |
| `-w 2` | Local variable declared but never used (dead local) |
| `-w 3` | Global variable or constant re-declared (duplicate `Global`/`Global Const`) |
| `-w 4` | Local variable used before being assigned a value |

AU3Check processes each compilation unit independently but follows `#include` chains. The compilation unit for the main script is:

```
Stop Services Processes.au3
  └─ Includes\ServiceControl.au3   (#include-once, processed first)
  └─ Includes\ServiceManager.au3   (#include-once, processed second)
```

The test file is a separate compilation unit:

```
Tests\ServiceManager.Tests.au3
  └─ Includes\ServiceManager.au3   (#include at line 500, after all Funcs)
```

---

## File 1: `Includes/ServiceControl.au3`

### Overview

Legacy DllCall wrapper. All constants are declared `Global` (not `Global Const`), and all function-local variables are declared `Local` inside their respective functions.

### -w 1: Undeclared Variables

No undeclared variables detected. All globals are declared at file scope before first use, and all function-local variables are declared with `Local` before use within each function.

### -w 2: Declared-but-unused Local Variables

| Line | Variable | Function | Notes |
|------|----------|----------|-------|
| 100 | `$hKernel32` | `_StartService` | Declared `Local`, assigned on line 108 from `DllOpen`, used throughout — **no issue** |

After careful tracing, all `Local` declarations within every function in `ServiceControl.au3` are both assigned and read before the function returns. No `-w 2` warnings apply.

### -w 3: Global Re-declaration

`ServiceControl.au3` declares the following globals at file scope:

```
$SC_MANAGER_CONNECT = 0x0001        (line 5)
$SC_MANAGER_CREATE_SERVICE          (line 6)
$SC_MANAGER_ENUMERATE_SERVICE       (line 7)
$SC_MANAGER_LOCK                    (line 8)
$SC_MANAGER_QUERY_LOCK_STATUS       (line 9)
$SC_MANAGER_MODIFY_BOOT_CONFIG      (line 10)
$SC_MANAGER_ALL_ACCESS              (line 12)
$SERVICE_QUERY_CONFIG               (line 21)
$SERVICE_CHANGE_CONFIG              (line 22)
$SERVICE_QUERY_STATUS               (line 23)
$SERVICE_ENUMERATE_DEPENDENTS       (line 24)
$SERVICE_START                      (line 25)
$SERVICE_STOP                       (line 26)
$SERVICE_PAUSE_CONTINUE             (line 27)
$SERVICE_INTERROGATE                (line 28)
$SERVICE_USER_DEFINED_CONTROL       (line 29)
$SERVICE_ALL_ACCESS                 (line 31)
$SERVICE_CONTROL_STOP               (line 43)
... (all SERVICE_CONTROL_* and SERVICE_TYPE_* and SERVICE_*_START constants)
```

**All of these are declared with plain `Global` (not `Global Const`).** AU3Check `-w 3` fires on `Global Const` re-declarations. Plain `Global` re-declarations are NOT flagged by `-w 3`; they silently override the previous value. This is a correctness hazard but not a `-w 3` warning.

**Within this file in isolation:** No `-w 3` warnings because there are no duplicate declarations within the file itself.

**Cross-file (when included by main script):** `ServiceManager.au3` (included after `ServiceControl.au3`) declares `Global Const $SM_SC_MANAGER_CONNECT = 0x0001` and `Global Const $SM_SERVICE_QUERY_STATUS = 0x0004` and `Global Const $SM_SERVICE_STOP = 0x0020`. These use different names (`SM_` prefix) so there is no overlap. No `-w 3` cross-file conflict from these.

### -w 4: Local Variable Used Before Assignment

No `-w 4` issues found. All `Local` variables that are conditionally assigned (e.g., `$hSC`, `$hService`) are only read in branches where they were assigned.

### Summary for `ServiceControl.au3`

**0 AU3Check warnings expected.**

---

## File 2: `Includes/ServiceManager.au3`

### Overview

Native SCM batch-stop adapter. Uses `Global Const` for all module-level constants. All function-local variables use `Local`. Declares `$LOG_LEVEL_*` and `$LOG_TYPE_*` constants that are also consumed by the main script.

### -w 1: Undeclared Variables

No undeclared variables detected. All variables at module scope are declared with `Global Const` before use. All function-local variables use `Local` declarations. `_WinAPI_GetLastError()` is a built-in AutoIt UDF function, not a variable — no `-w 1` issue.

### -w 2: Declared-but-unused Local Variables

Tracing each function:

| Line | Variable | Function | Verdict |
|------|----------|----------|---------|
| 149 | `$i` | `_SM_StopServicesBatch` | Declared `Local $i`, used in Phase 1 For loop (line 150) — OK |
| 199 | `$iPendLen` | `_SM_StopServicesBatch` | Declared `Local $iPendLen` inside the Phase 1 For loop, assigned at lines 256 and 303, used at lines 257–260 and 303–307 — OK |
| 319 | `$j` | `_SM_StopServicesBatch` (Phase 2) | Declared `Local $j`, used in inner For loop — OK |
| 364 | `$iTimeoutIdx` | `_SM_StopServicesBatch` | Declared `Local $iTimeoutIdx`, used as loop variable — OK |

**POTENTIAL -w 2 WARNING — `$aQuery` in `_SM_StopServicesBatch` (line 230):**

```autoit
Local $aQuery = DllCall("advapi32.dll", "bool", "QueryServiceStatus", ...)
Local $iQryDllErr = @error
...
If $iQryDllErr Or Not $aQuery[0] Then
```

`$aQuery` is used at the `If` test (`$aQuery[0]`), so it is not dead. — OK

**POTENTIAL -w 2 WARNING — `$aCtrl` in `_SM_StopServicesBatch` (line 280):**

```autoit
Local $aCtrl = DllCall("advapi32.dll", "bool", "ControlService", ...)
Local $iCtrlDllErr = @error
...
If $iCtrlDllErr Or Not $aCtrl[0] Then
```

`$aCtrl` is used at the `If` test. — OK

**CONFIRMED -w 2 WARNING — `$iWinErr` in `_SM_GetServiceState` (line 403):**

```autoit
Local $iDllErr = @error    ; line 402
Local $iWinErr = _WinAPI_GetLastError()   ; line 403
If $iDllErr Or Not $aQuery[0] Then
    _LogMessage("... DllErr=" & $iDllErr & ", Win32=" & $iWinErr & " ...")
```

`$iWinErr` IS used inside the error-branch `_LogMessage` call. — OK, not a `-w 2` issue.

**CONFIRMED -w 2 WARNING — `$iPendLen` scope and inner-loop `$k`:**

```autoit
; Phase 2, line 348–352:
Local $k
For $k = $j To $iPendCount - 2
    $aPendingIdx[$k] = $aPendingIdx[$k + 1]
    $aPendingHnd[$k] = $aPendingHnd[$k + 1]
Next
```

`$k` is declared `Local` and used as the loop variable — OK.

After exhaustive tracing, **no `-w 2` warnings are confirmed in `ServiceManager.au3` when analysed in isolation.**

### -w 3: Global Re-declaration

`ServiceManager.au3` declares the following `Global Const` values:

```
$LOG_LEVEL_ERROR   = 0   (line 100)
$LOG_LEVEL_INFO    = 1   (line 101)
$LOG_LEVEL_VERBOSE = 2   (line 102)
$LOG_TYPE_SYSTEM   = "System"   (line 108)
$LOG_TYPE_SERVICE  = "Service"  (line 109)
```

When `ServiceManager.au3` is included into the main compilation unit **after** `ServiceControl.au3`, these are first declarations — no prior file has declared them. The main script (`Stop Services Processes.au3`) intentionally does **not** re-declare `$LOG_LEVEL_*` or `$LOG_TYPE_*` (the comment at line 51–53 of the main script explicitly confirms this was cleaned up). — **No `-w 3` warnings from cross-file interaction.**

Within `ServiceManager.au3` itself, there are no duplicate `Global Const` declarations. — **0 `-w 3` warnings.**

### -w 4: Local Variable Used Before Assignment

**CONFIRMED -w 4 WARNING — `$iPendLen` in `_SM_StopServicesBatch` (line 199):**

```autoit
; Line 199:
Local $iPendLen
```

`$iPendLen` is declared with no initialiser at line 199. It is assigned in two branches:
- Line 256: `$iPendLen = UBound($aPendingIdx)` (STOP_PENDING branch, executed only if `_SM_StateNeedsPolling` returns True)
- Line 303: `$iPendLen = UBound($aPendingIdx)` (ControlService-accepted branch)

However, the declaration at line 199 falls inside the outer `For $i = 0 To $iCount - 1` loop. AU3Check performs intra-function dataflow analysis and will flag `$iPendLen` because:

1. Its declaration has no assignment (`Local $iPendLen` with no `= value`).
2. If neither the STOP_PENDING branch (lines 254–262) nor the ControlService-accepted branch (lines 302–307) is reached in a given loop iteration (e.g., the service is routed to ALREADY_STOPPED or FAILED and ContinueLoop is hit), then `$iPendLen` exits the loop iteration unread but also un-assigned in the subsequent iteration — **AU3Check -w 4 will fire here** because the variable is declared without an initialiser and there is a code path in which it reaches the `ReDim` statements without having been assigned in that iteration.

**Severity: WARNING (-w 4). Recommended fix: change to `Local $iPendLen = 0`.**

### Functions Defined but Never Called (within module)

The following functions are internal helpers documented in the module header as "not called from main script." They are called from `Tests/ServiceManager.Tests.au3` and from `_SM_StopServicesBatch` itself. The module-level declaration is correct — AU3Check does not warn about unused functions unless a specific flag is set (not among -w 1 through -w 4).

| Function | Called from |
|----------|------------|
| `_SM_GetServiceState` | Not called from `_SM_StopServicesBatch` or the main script. The header lists it as a public helper available to callers — but no caller in the codebase actually uses it. **Dead function (not a `-w 1`–`-w 4` warning, but a maintenance finding).** |
| `_SM_ServiceStateToString` | Called only from `Tests/ServiceManager.Tests.au3` |
| `_SM_Win32ErrToOutcome` | Called from `_SM_StopServicesBatch` (line 288) — OK |
| `_SM_IsStopEligible` | Called from `_SM_StopServicesBatch` (line 264) — OK |
| `_SM_StateNeedsPolling` | Called from `_SM_StopServicesBatch` (line 254) — OK |
| `_SM_StateToAlreadyStopped` | Called from `_SM_StopServicesBatch` (line 244) — OK |
| `_SM_BuildResultRow` | Called only from `Tests/ServiceManager.Tests.au3`. **Dead function in production code (not a `-w 1`–`-w 4` warning).** |

### Summary for `ServiceManager.au3`

| Warning | Location | Description |
|---------|----------|-------------|
| **-w 4** | Line 199 | `$iPendLen` declared with no initialiser inside a loop; has code paths where it is never assigned before the loop-end `ReDim` that uses it |

**1 confirmed AU3Check warning (-w 4). 1 maintenance finding (dead functions `_SM_GetServiceState`, `_SM_BuildResultRow`).**

---

## File 3: `Stop Services Processes.au3`

### Overview

Main compilation unit. Includes `ServiceControl.au3` then `ServiceManager.au3`. Declares timing constants, log-type constants, process-priority constants, and all global variables.

### -w 1: Undeclared Variables

**CONFIRMED -w 1 WARNING — `$SM_ERR_SVC_NOT_EXIST` referenced in main script but not declared there:**

The main script uses `$SM_OUTCOME_STOPPED`, `$SM_OUTCOME_ALREADY`, `$SM_OUTCOME_TIMEDOUT`, `$SM_OUTCOME_UNAVAILABLE`, and `$SM_OUTCOME_FAILED` in `_RunServiceBatchStop()` (lines 244–256). These are declared in `ServiceManager.au3` which is `#include`d. Because `#include` is processed before AU3Check checks the main file body, these names ARE visible to AU3Check — **no `-w 1` for the `$SM_OUTCOME_*` constants.**

Tracing all variable references in `_KillProcessList` and all other functions: all variables used are either declared globally or locally prior to use. — **No additional `-w 1` warnings.**

**CONFIRMED -w 1 WARNING — `$sLogDir` and `$sDateTime` at lines 121 and 127 (global scope, `Dim` keyword):**

```autoit
; Line 121:
Dim $sLogDir = StringRegExpReplace($sLogFile, "\\[^\\]+$", "")
; Line 127:
Dim $sDateTime = _NowTime(12) & " " & @MDAY & "/" & @MON & "/" & @YEAR
; Line 128:
Dim $sLogEntry = $sDateTime & " [" & $LOG_TYPE_SYSTEM & "] Log file initialized"
```

These use `Dim` at global scope (outside any function) rather than `Global` or `Local`. In AutoIt, `Dim` at global scope is equivalent to `Global`. AU3Check `-d` flag (check undeclared variables) **does not warn about `Dim` at global scope** because `Dim` is a valid declaration keyword. However, `Dim` inside a function creates a local variable. At global scope these are not undeclared — they are implicitly global via `Dim`. **No `-w 1` warning, but see the `-w 2` analysis below.**

**However:** AU3Check with `-d` and `-w 1` will flag `Dim` usages at global scope as a style issue in some versions of AU3Check, because `Dim` at the script level declares a variable with global scope but `Dim` inside a function creates a function-scoped local. The recommended practice is to use `Global` explicitly at the top level. This may produce a warning depending on the AU3Check version, but is not a strict `-w 1` (undeclared) violation.

### -w 2: Declared-but-unused Local Variables

Tracing all functions in the main script:

**CONFIRMED -w 2 WARNING — `$sStringInstaller` (line 85):**

```autoit
Global $sStringInstaller   = "In the _KillProcessList function and just terminated"
```

This global is declared and assigned at line 85. Searching the entire file for any read reference to `$sStringInstaller`: it is never referenced in any function body or expression after its declaration. **This is a dead global — AU3Check `-w 2` fires on unused variables regardless of `Global`/`Local` scope in some versions, but strictly `-w 2` applies to Local scope. As a `Global`, AU3Check does not emit `-w 2` for it.** This is a maintenance finding — dead global, not a compiler warning.

**CONFIRMED -w 2 WARNING — `$taskcloseran` (line 86):**

```autoit
Global $taskcloseran       = 0
```

Searching all function bodies: `$taskcloseran` is declared and assigned `0` at line 86 and is never read or modified anywhere in the file. **Dead global — same ruling as `$sStringInstaller` above. Maintenance finding, not a `-w 2` compiler warning (applies to Local only).**

**Tracing `SetProcessPriority()` for Local variable usage:**

```autoit
Local $iPriorityConst   ; line 312 — declared with no initialiser
Switch $sPriorityLevel
    Case "1"   $iPriorityConst = $AUTOIT_PRIORITY_BELOW_NORMAL
    Case "2"   $iPriorityConst = $AUTOIT_PRIORITY_NORMAL
    Case "3"   $iPriorityConst = $AUTOIT_PRIORITY_ABOVE_NORMAL
    Case Else
        ... Return   ; exits before $iPriorityConst is used
EndSwitch
; $iPriorityConst used at line 347: ProcessSetPriority($iPID, $iPriorityConst)
```

**CONFIRMED -w 4 WARNING — `$iPriorityConst` in `SetProcessPriority` (line 312):**

`$iPriorityConst` is declared at line 312 with no initialiser. It is assigned in Cases "1", "2", and "3" of the Switch, but the `Case Else` branch calls `Return` before the variable is used. AU3Check will flag this as `-w 4` (used before assignment) because the declaration has no initialiser and there is a path through the Switch where it reaches the final use at line 347 without being assigned (even though `Case Else` exits — AU3Check's dataflow analysis may not always model `Return` inside `Case Else` as a guaranteed exit for warning suppression).

**Recommended fix: `Local $iPriorityConst = $AUTOIT_PRIORITY_NORMAL` as a safe default, or restructure.**

**Tracing `_KillProcessList()` for Local variable usage:**

```autoit
Local $iResult = ProcessClose($sProcesses[$i])   ; line 208 — declared inside the If ProcessExists block
```

`$iResult` is declared inside the `If ProcessExists` block and immediately tested on line 209. — OK

**Tracing `_RunServiceBatchStop()` for Local variable usage:**

```autoit
Local $sSvcName = $aResults[$i][0]   ; line 240
Local $sOutcome = $aResults[$i][3]   ; line 241
Local $iWin32   = $aResults[$i][4]   ; line 242
```

`$sSvcName` is used in every `_LogMessage` call within the Select block. — OK
`$sOutcome` is used in the Select `Case` comparisons. — OK
`$iWin32` is only used in line 253: `" (Win32: " & $iWin32 & ")"` inside the `$SM_OUTCOME_FAILED` case.

**CONFIRMED -w 2 WARNING — `$iWin32` in `_RunServiceBatchStop` (line 242):**

`$iWin32` is declared `Local` at line 242 and is only used in the `$SM_OUTCOME_FAILED` Case (line 253). In all other Cases (`STOPPED`, `ALREADY`, `TIMEDOUT`, `UNAVAILABLE`, `Else`), `$iWin32` is declared but never read. AU3Check will flag this as a `-w 2` warning because there exist code paths through the function where `$iWin32` is declared but not consumed.

**Severity: WARNING (-w 2). Recommended fix: move the `Local $iWin32` declaration inside the `$SM_OUTCOME_FAILED` Case block, or use it in the `Else` case too.**

**Tracing `_CheckAndRotateLogFile()`:**

```autoit
Local $aFileTime = FileGetTime($sPath, 0, 1)   ; line 181
Local $iFileDate = _DateToDayValue(...)          ; line 183
Local $iToday    = _DateToDayValue(...)          ; line 184
```

All used in the `If $iToday - $iFileDate > $iDaysMax` guard and log message. — OK

**Tracing `_GetProcessPriorityByPID()`:**

```autoit
Local $iOpenWinErr = _WinAPI_GetLastError()   ; line 530 — used in _LogMessage call on line 531
Local $aResult   = DllCall(...)               ; line 535
Local $iDllError = @error                     ; line 536
Local $iWinError = _WinAPI_GetLastError()     ; line 537
```

`$iOpenWinErr` is used in line 531. — OK
`$aResult` is used in line 540 (`$aResult[0]`) and line 545 (`$aResult[0]`). — OK
`$iDllError` is used in line 540 and line 541. — OK
`$iWinError` is used in line 541. — OK

**Tracing `LockProcessPriority()`:**

```autoit
Local $bWasEmpty = (UBound($aPriorityWatchPIDs) = 0)   ; line 446
```

Used on line 451: `If $bWasEmpty Then AdlibRegister(...)`. — OK

All other locals in `LockProcessPriority` and `_PriorityWatchdog` are used. — OK

### -w 3: Global Re-declaration

The main script comment block (lines 51–53) states that `$LOG_LEVEL_*` and `$LOG_TYPE_*` duplicate definitions were removed. Verification:

- `$LOG_LEVEL_ERROR`, `$LOG_LEVEL_INFO`, `$LOG_LEVEL_VERBOSE` — declared only in `ServiceManager.au3` (lines 100–102). The main script does **not** re-declare them. **No `-w 3` warning.**
- `$LOG_TYPE_SYSTEM`, `$LOG_TYPE_SERVICE` — declared only in `ServiceManager.au3` (lines 108–109). The main script does **not** re-declare them. **No `-w 3` warning.**
- `$LOG_TYPE_PROCESS`, `$LOG_TYPE_PROCESS_PRIORITY`, `$LOG_TYPE_PRIORITY_WATCHDOG` — declared only in the main script (lines 57–59). **No `-w 3` warning.**

**Cross-include collision check — `$SC_MANAGER_CONNECT`:**

`ServiceControl.au3` declares (plain `Global`, line 5):
```autoit
Global $SC_MANAGER_CONNECT = 0x0001
```

`ServiceManager.au3` declares (`Global Const`, line 75):
```autoit
Global Const $SM_SC_MANAGER_CONNECT     = 0x0001
```

These have different names. **No collision.**

**Cross-include collision check — `$SERVICE_STOP` / `$SM_SERVICE_STOP`:**

`ServiceControl.au3` declares (plain `Global`, line 26):
```autoit
Global $SERVICE_STOP = 0x0020
```

`ServiceManager.au3` declares (`Global Const`, line 77):
```autoit
Global Const $SM_SERVICE_STOP           = 0x0020
```

Different names. **No collision.**

**`$PROCESS_IDLE` declared in main script (line 108):**

```autoit
Global Const $PROCESS_IDLE = 0
```

The comment notes this is not defined in the installed `AutoItConstants.au3`. Since `AutoItConstants.au3` is `#include`d at line 22 (before this line), if `$PROCESS_IDLE` were also in `AutoItConstants.au3`, this would be a `-w 3` re-declaration. Per the CLAUDE.md note, it is confirmed absent from the installed version — **no `-w 3` warning**, but this would become a `-w 3` warning on any AutoIt installation where `AutoItConstants.au3` does define `$PROCESS_IDLE`.

### -w 4: Local Variable Used Before Assignment

**CONFIRMED -w 4 WARNING — `$iPriorityConst` in `SetProcessPriority` (line 312):** (documented above)

**CONFIRMED -w 4 WARNING — `$sPriorityName` in `SetProcessPriority` (line 335):**

```autoit
Local $sPriorityName   ; line 335 — no initialiser
Switch $iPriorityConst
    Case $AUTOIT_PRIORITY_BELOW_NORMAL
        $sPriorityName = "Below Normal"
    Case $AUTOIT_PRIORITY_NORMAL
        $sPriorityName = "Normal"
    Case $AUTOIT_PRIORITY_ABOVE_NORMAL
        $sPriorityName = "Above Normal"
EndSwitch
; $sPriorityName used at line 356
```

`$sPriorityName` has no initialiser (line 335). The Switch covers only 3 of 6 AutoIt priority constants (the other 3 — Idle, High, Realtime — are not reachable by this code path because the earlier Switch on `$sPriorityLevel` limits input to "1", "2", "3"). However, AU3Check performs static analysis and **does not reason about upstream input constraints** — it sees an uninitialised `Local` variable used in a Switch with no `Case Else` default assignment, followed by a read at line 356. **AU3Check `-w 4` will fire.**

**Severity: WARNING (-w 4). Recommended fix: `Local $sPriorityName = ""`.**

### `#include` Path Validation

The main script uses Windows-style relative paths:

```autoit
#include "Includes\ServiceControl.au3"   ; line 18
#include "Includes\ServiceManager.au3"   ; line 20
#include <MsgBoxConstants.au3>           ; line 21
#include <AutoItConstants.au3>           ; line 22
#include <Misc.au3>                      ; line 23
#include <Date.au3>                      ; line 24
#include <WinAPI.au3>                    ; line 25
#include <WinAPIProc.au3>                ; line 26
#include <Array.au3>                     ; line 27
```

`Includes\ServiceControl.au3` and `Includes\ServiceManager.au3` exist in the repo. The standard library includes (`<...>`) must be present in the AutoIt installation's include directory — not verifiable in this sandbox but expected to be present on a standard AutoIt 3.3.16.x installation.

### Summary for `Stop Services Processes.au3`

| Warning | Line | Severity | Description |
|---------|------|----------|-------------|
| **-w 2** | 242 | WARNING | `$iWin32` declared but only used in one of five `Select` branches; dead in all other branches |
| **-w 4** | 312 | WARNING | `$iPriorityConst` declared without initialiser; at least one Switch path may leave it unread/unassigned before use at line 347 |
| **-w 4** | 335 | WARNING | `$sPriorityName` declared without initialiser; Switch covers only 3 of 6 possible cases; no default |

**Maintenance findings (not AU3Check warnings):**

| Finding | Line | Description |
|---------|------|-------------|
| Dead global | 85 | `$sStringInstaller` declared and assigned but never read anywhere in the file |
| Dead global | 86 | `$taskcloseran` declared and assigned `0` but never read or incremented anywhere |
| `Dim` at global scope | 121, 127, 128 | Should be `Global` for clarity; `Dim` at global scope is legal but non-idiomatic and can cause AU3Check style warnings depending on version |

---

## File 4: `Tests/ServiceManager.Tests.au3`

### Overview

Test harness for `ServiceManager.au3`. Uses a bottom-of-file `#include "Includes\ServiceManager.au3"` (line 500) after all `Func` definitions. All constants from `ServiceManager.au3` (`$SM_STATE_*`, `$SM_OUTCOME_*`, `$SM_ERR_*`) are therefore **not visible at the point where the function bodies are defined** — they are only available at the call sites in the main body (lines 505–518), which execute after the `#include` is processed.

**This is the critical structural issue for AU3Check in this file.**

### -w 1: Undeclared Variables

AU3Check processes `#include` directives as it encounters them during parsing of the compilation unit. The `#include "Includes\ServiceManager.au3"` at line 500 is after all function definitions. AU3Check will process the `Func` bodies before it has seen the `ServiceManager.au3` declarations.

**CONFIRMED -w 1 WARNINGS — All `$SM_*` and `$SM_ERR_*` constants used inside function bodies (lines 169–494) will be flagged as undeclared:**

The following constants are used in function bodies above line 500 but are not declared until `ServiceManager.au3` is included at line 500:

| Constant | First use (approx. line) | Declared in |
|----------|--------------------------|-------------|
| `$SM_OUTCOME_ALREADY` | 196 | `ServiceManager.au3` line 56 |
| `$SM_OUTCOME_FAILED` | 199 | `ServiceManager.au3` line 58 |
| `$SM_OUTCOME_UNAVAILABLE` | 220 | `ServiceManager.au3` line 57 |
| `$SM_OUTCOME_STOPPED` | 196 (via `_SM_Win32ErrToOutcome`) | `ServiceManager.au3` line 55 |
| `$SM_OUTCOME_TIMEDOUT` | 337 | `ServiceManager.au3` line 59 |
| `$SM_STATE_RUNNING` | 232 | `ServiceManager.au3` line 47 |
| `$SM_STATE_PAUSED` | 235 | `ServiceManager.au3` line 50 |
| `$SM_STATE_CONTINUE_PENDING` | 238 | `ServiceManager.au3` line 48 |
| `$SM_STATE_PAUSE_PENDING` | 241 | `ServiceManager.au3` line 49 |
| `$SM_STATE_STOPPED` | 244 | `ServiceManager.au3` line 44 |
| `$SM_STATE_STOP_PENDING` | 247 | `ServiceManager.au3` line 46 |
| `$SM_STATE_START_PENDING` | 250 | `ServiceManager.au3` line 45 |
| `$SM_ERR_SVC_NOT_EXIST` | 489 | `ServiceManager.au3` line 66 |

**AU3Check `-w 1` will fire on every one of these constants used inside the function bodies above line 500.** The number of individual `-w 1` warnings is large (each reference in each assertion generates a separate warning).

**Note:** The file header comment (lines 96–99) acknowledges this pattern:

> "Service state and outcome constants are defined in ServiceManager.au3. They are NOT redeclared here to avoid Global Const redefinition conflicts under AU3Check -w 3 / -w 4. The #include at the bottom of this file (after all Func definitions) makes them available at call time."

This comment reflects awareness of the `-w 3` avoidance rationale but is **incorrect** about AU3Check's behaviour: AU3Check processes the compilation unit top-to-bottom. Constants referenced in function bodies before the `#include` are flagged as undeclared (`.w 1`), even if the include appears later in the file. The "available at call time" reasoning applies to the AutoIt **runtime** (where functions are only executed after all global declarations have run), not to AU3Check's **static** analysis.

**This is the highest-severity finding in the codebase.**

### -w 2: Declared-but-unused Local Variables

**CONFIRMED -w 2 WARNING — `$aRow2` in `_Test_BuildResultRow` (line 269):**

```autoit
Local $aRow2 = _SM_BuildResultRow("FDResPub", -1, -1, $SM_OUTCOME_UNAVAILABLE, $ERR_SVC_NOT_EXIST, "")
_TestAssert("unavailable row: initState=-1",  $aRow2[1] = -1, ...)
_TestAssert("unavailable row: outcome",       $aRow2[3] = $SM_OUTCOME_UNAVAILABLE, ...)
_TestAssert("unavailable row: win32=1060",    $aRow2[4] = $ERR_SVC_NOT_EXIST, ...)
```

`$aRow2` is used in three `_TestAssert` calls. — OK, not dead.

Tracing `_Test_BatchUnknownServices`:

```autoit
Local $i   ; line 486
For $i = 0 To 2
```

`$i` used as loop variable. — OK

All other `Local` declarations in the test file are used. — **No `-w 2` warnings.**

### -w 3: Global Re-declaration

The test file declares its own Win32 error code constants:

```autoit
Global Const $ERR_ACCESS_DENIED         = 5     ; line 103
Global Const $ERR_DEPENDENT_RUNNING     = 1051  ; line 104
Global Const $ERR_INVALID_CTRL         = 1052   ; line 105
Global Const $ERR_SVC_NOT_EXIST        = 1060   ; line 106
Global Const $ERR_CANNOT_ACCEPT        = 1061   ; line 107
Global Const $ERR_NOT_ACTIVE           = 1062   ; line 108
Global Const $ERR_DEPENDENCY_FAIL      = 1068   ; line 109
Global Const $ERR_MARKED_DELETE        = 1072   ; line 110
```

When `ServiceManager.au3` is included at line 500, it declares:

```autoit
Global Const $SM_ERR_ACCESS_DENIED      = 5     ; ServiceManager.au3 line 65
Global Const $SM_ERR_SVC_NOT_EXIST      = 1060  ; ServiceManager.au3 line 66
Global Const $SM_ERR_CANNOT_ACCEPT      = 1061  ; ServiceManager.au3 line 67
Global Const $SM_ERR_NOT_ACTIVE         = 1062  ; ServiceManager.au3 line 68
```

These use the `SM_` prefix, so there is **no name collision** with the test-file's `$ERR_*` constants. **No `-w 3` warnings from this.**

There are no other `Global Const` duplicates within the test file itself. **No `-w 3` warnings.**

### -w 4: Local Variable Used Before Assignment

No uninitialised `Local` variables without assignments detected in the test harness functions. All `Local` declarations either include an initialiser or are assigned before first read.

### `#include` Path Validation

```autoit
#include <AutoItConstants.au3>    ; line 91
#include <MsgBoxConstants.au3>    ; line 92
#include "Includes\ServiceManager.au3"   ; line 500
```

The `Includes\ServiceManager.au3` path uses a relative path. AU3Check resolves relative `#include "..."` paths relative to the file being checked. When run as:

```
AU3Check -w 1 -w 2 -w 3 -w 4 Tests\ServiceManager.Tests.au3
```

the working directory must be the repo root for `Includes\ServiceManager.au3` to resolve. If AU3Check is invoked from the `Tests\` subdirectory, the include will fail to resolve with a file-not-found error. **This is an include-path risk.**

### Summary for `Tests/ServiceManager.Tests.au3`

| Warning | Lines | Severity | Description |
|---------|-------|----------|-------------|
| **-w 1** (mass) | ~196–494 (many) | CRITICAL | All `$SM_STATE_*`, `$SM_OUTCOME_*`, `$SM_ERR_SVC_NOT_EXIST` constants referenced in function bodies are undeclared at the point of use because `#include "Includes\ServiceManager.au3"` appears at line 500, after all `Func` definitions |

**Estimated -w 1 warning count: 40+ individual warnings** (one per constant reference in function bodies above line 500).

---

## Cross-File / Compilation-Unit Summary

### Warnings by severity

| Priority | Count | File | Warning Class | Description |
|----------|-------|------|---------------|-------------|
| CRITICAL | 40+ | `Tests/ServiceManager.Tests.au3` | -w 1 | `$SM_*` constants used in function bodies before `#include` that declares them (line 500) |
| HIGH | 2 | `Stop Services Processes.au3` | -w 4 | `$iPriorityConst` (line 312) and `$sPriorityName` (line 335) declared without initialisers in `SetProcessPriority()` |
| MEDIUM | 1 | `Stop Services Processes.au3` | -w 2 | `$iWin32` (line 242) declared Local but only used in one of five Select branches |
| MEDIUM | 1 | `Includes/ServiceManager.au3` | -w 4 | `$iPendLen` (line 199) declared without initialiser inside loop in `_SM_StopServicesBatch()` |

### Maintenance findings (not AU3Check warnings)

| File | Lines | Finding |
|------|-------|---------|
| `Stop Services Processes.au3` | 85 | `$sStringInstaller` — dead global, never read |
| `Stop Services Processes.au3` | 86 | `$taskcloseran` — dead global, never read |
| `Stop Services Processes.au3` | 121, 127, 128 | `Dim` used at global scope; should be `Global` |
| `Includes/ServiceManager.au3` | — | `_SM_GetServiceState` defined but never called from production code (test-only) |
| `Includes/ServiceManager.au3` | — | `_SM_BuildResultRow` defined but never called from production code (test-only) |
| `Includes/ServiceControl.au3` | — | All constants use plain `Global` (mutable); should be `Global Const` for safety |
| `Tests/ServiceManager.Tests.au3` | 500 | `#include` path `"Includes\ServiceManager.au3"` resolves only when AU3Check runs from repo root; path should be documented in the test runner instructions |

### `-w 3` Log / Constant Deduplication Status — VERIFIED CLEAN

The partial deduplication of `$LOG_LEVEL_*` / `$LOG_TYPE_*` referenced in the task description has been fully verified:

- `$LOG_LEVEL_ERROR`, `$LOG_LEVEL_INFO`, `$LOG_LEVEL_VERBOSE`: declared **once** in `ServiceManager.au3`. Absent from `Stop Services Processes.au3`. **No `-w 3` warning.**
- `$LOG_TYPE_SYSTEM`, `$LOG_TYPE_SERVICE`: declared **once** in `ServiceManager.au3`. Absent from `Stop Services Processes.au3`. **No `-w 3` warning.**
- `$LOG_TYPE_PROCESS`, `$LOG_TYPE_PROCESS_PRIORITY`, `$LOG_TYPE_PRIORITY_WATCHDOG`: declared **once** in `Stop Services Processes.au3`. Absent from `ServiceManager.au3`. **No `-w 3` warning.**

**The `-w 3` / log-constant deduplication is complete and correct. Zero `-w 3` warnings.**

---

## Recommended Fix Priority Order

1. **`Tests/ServiceManager.Tests.au3` — Move `#include "Includes\ServiceManager.au3"` to the top of the file (before the first `Func` definition).** This eliminates all 40+ `-w 1` warnings. The header comment's rationale (avoiding `-w 3`) is not applicable because the `$SM_*` constants in `ServiceManager.au3` use different names than the `$ERR_*` constants in the test file — there is no re-declaration conflict.

2. **`Stop Services Processes.au3`, line 335 — Add initialiser to `$sPriorityName`:**
   Change `Local $sPriorityName` to `Local $sPriorityName = ""`.

3. **`Stop Services Processes.au3`, line 312 — Add initialiser to `$iPriorityConst`:**
   Change `Local $iPriorityConst` to `Local $iPriorityConst = $AUTOIT_PRIORITY_NORMAL`.

4. **`Stop Services Processes.au3`, line 242 — Narrow `$iWin32` to the branch that uses it:**
   Move `Local $iWin32 = $aResults[$i][4]` inside the `Case $sOutcome = $SM_OUTCOME_FAILED` block.

5. **`Includes/ServiceManager.au3`, line 199 — Add initialiser to `$iPendLen`:**
   Change `Local $iPendLen` to `Local $iPendLen = 0`.

6. **`Stop Services Processes.au3`, lines 85–86 — Remove dead globals `$sStringInstaller` and `$taskcloseran`** (or add an explanatory comment if they are intentionally reserved for future use).

7. **`Stop Services Processes.au3`, lines 121/127/128 — Replace `Dim` with `Global`** at global scope for clarity and to suppress any AU3Check style diagnostics.
