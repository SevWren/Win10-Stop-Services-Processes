# CR3-06: AU3Check Round-2 Simulation — Post-BUG-12 Fix Verification

**Scope:** Second-pass static analysis simulation of AU3Check `-q -d -w 1 -w 2 -w 3 -w 4`
**Files analysed:**
1. `Tests/ServiceManager.Tests.au3`
2. `Includes/ServiceManager.au3`
3. `Stop Services Processes.au3`
4. `Includes/ServiceControl.au3`

**Date:** 2026-11-12
**Analyst:** Claude (agent-assisted static review — second pass)
**Predecessor report:** `docs/reviews/bugs/BUG-12-au3check-simulation.md`
**Purpose:** Verify which BUG-12 warnings are now resolved and which remain open

---

## Summary Table — RESOLVED vs STILL OPEN

| ID | File | Warning | BUG-12 Severity | Round-2 Status |
|----|------|---------|-----------------|----------------|
| R1 | `Tests/ServiceManager.Tests.au3` | `#include` moved to top; all `$SM_*` constants visible in function bodies | CRITICAL (-w 1, 40+) | **RESOLVED** |
| R2 | `Includes/ServiceManager.au3` | `Local $iPendLen` now declared before Phase 1 loop | MEDIUM (-w 4) | **RESOLVED** |
| R3 | `Includes/ServiceManager.au3` | `_SM_GetServiceState` removed | Maintenance finding | **RESOLVED** |
| O1 | `Includes/ServiceManager.au3` | `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` name mismatch — NEW finding | — | **NEW CRITICAL (-w 1)** |
| O2 | `Stop Services Processes.au3` | `Local $iPriorityConst` still has no initialiser in `SetProcessPriority()` | HIGH (-w 4) | **STILL OPEN** |
| O3 | `Stop Services Processes.au3` | `Local $sPriorityName` still has no initialiser in `SetProcessPriority()` | HIGH (-w 4) | **STILL OPEN** |
| O4 | `Stop Services Processes.au3` | `Local $iWin32` declared outside Select; dead in 4 of 5 branches | MEDIUM (-w 2) | **STILL OPEN** |
| O5 | `Stop Services Processes.au3` | `Dim` at global scope (lines 120, 126, 127) | Maintenance | **STILL OPEN** |
| O6 | `Includes/ServiceControl.au3` | All constants use plain `Global` (not `Global Const`) | Maintenance | **STILL OPEN** |

---

## Detailed Findings

---

### File 1: `Tests/ServiceManager.Tests.au3`

#### RESOLVED — R1: `#include` moved to top (CRITICAL -w 1, 40+ warnings)

**BUG-12 finding:** The `#include "Includes\ServiceManager.au3"` appeared at line 500, after all `Func` definitions. AU3Check processes the compilation unit top-to-bottom; every `$SM_STATE_*`, `$SM_OUTCOME_*`, and `$SM_ERR_*` constant referenced inside the function bodies (lines ~169–494) was therefore undeclared at the point of use, generating 40+ individual `-w 1` warnings.

**Current state (line 90–94):**

```autoit
#Region ;Includes
#include <AutoItConstants.au3>
#include <MsgBoxConstants.au3>
#include "Includes\ServiceManager.au3"
#EndRegion
```

The `#include "Includes\ServiceManager.au3"` is now at line 93, inside the top `#Region ;Includes` block, before all `Func` definitions. All `$SM_STATE_*`, `$SM_OUTCOME_*`, and `$SM_ERR_*` constants are now declared before first use in every function body.

**Verification of specific constants referenced in function bodies:**

| Constant | First use (function) | Declared (ServiceManager.au3) | Visible after move? |
|----------|---------------------|-------------------------------|---------------------|
| `$SM_STATE_RUNNING` | `_Test_IsStopEligible` (line ~226) | line 47 | Yes |
| `$SM_STATE_PAUSED` | `_Test_IsStopEligible` (line ~229) | line 50 | Yes |
| `$SM_STATE_CONTINUE_PENDING` | `_Test_IsStopEligible` (line ~232) | line 48 | Yes |
| `$SM_STATE_PAUSE_PENDING` | `_Test_IsStopEligible` (line ~235) | line 49 | Yes |
| `$SM_STATE_STOPPED` | `_Test_IsStopEligible` (line ~238) | line 44 | Yes |
| `$SM_STATE_STOP_PENDING` | `_Test_IsStopEligible` (line ~241) | line 46 | Yes |
| `$SM_STATE_START_PENDING` | `_Test_IsStopEligible` (line ~244) | line 45 | Yes |
| `$SM_OUTCOME_ALREADY_STOPPED` | `_Test_Win32ErrToOutcome` (line ~190) | line 55 (see O1 below) | Conditional — see O1 |
| `$SM_OUTCOME_FAILED` | `_Test_Win32ErrToOutcome` (line ~193) | line 57 | Yes |
| `$SM_OUTCOME_UNAVAILABLE` | `_Test_Win32ErrToOutcome` (line ~214) | line 56 | Yes |
| `$SM_OUTCOME_TIMED_OUT` | `_Test_SharedTimeout` (line ~329) | line 58 | Yes |
| `$SM_OUTCOME_STOPPED` | `_Test_BuildResultRow` (line ~254) | line 54 | Yes |
| `$SM_ERR_SVC_NOT_EXIST` | `_Test_BatchUnknownServices` (line ~483) | line 65 | Yes |

**All 40+ CRITICAL `-w 1` warnings from BUG-12 are eliminated by this fix.** One new warning introduced — see O1 below.

**Global constant declarations (lines 97–111) — no `-w 1`:** The test-file's own `Global Const $ERR_*` constants (lines 97–104) use unprefixed names that do not collide with the `$SM_ERR_*` names from `ServiceManager.au3`. No `-w 3` re-declaration warnings introduced. The test framework globals (`$g_iTestCount`, `$g_iPassCount`, `$g_iFailCount`, `$g_sTestLog`, lines 109–112) are plain `Global` and are all written before read. No `-w 1`, `-w 2`, `-w 3`, or `-w 4` issues in the test framework itself.

**Round-2 status for `Tests/ServiceManager.Tests.au3`: 0 AU3Check warnings** (subject to O1 propagating from ServiceManager.au3 — see O1).

---

### File 2: `Includes/ServiceManager.au3`

#### RESOLVED — R2: `Local $iPendLen` now declared before Phase 1 loop (MEDIUM -w 4)

**BUG-12 finding:** `Local $iPendLen` was declared inside the `For $i = 0 To $iCount - 1` loop body (Phase 1), causing AU3Check to flag it as used-before-assignment because there were code paths (ALREADY_STOPPED and FAILED branches, both of which hit `ContinueLoop`) where the variable was declared but never assigned before the loop iteration ended.

**Current state (lines 189–197):**

```autoit
; $iPendLen declared at function scope — not inside the Phase 1 loop — so
; AU3Check -w 3 does not emit a redeclaration-in-loop warning (BUG-02 fix).
; Assigned before every read site inside the loop body below.
Local $iPendLen

; =========================================================================
; PHASE 1 — Inspect each service and issue stop controls without serial waiting
; =========================================================================
For $i = 0 To $iCount - 1
```

`Local $iPendLen` is now at line 192, before the `For` loop at line 197. The comment correctly notes that it is "assigned before every read site inside the loop body below."

**Analysis of -w 4 for the moved declaration:** The declaration is now at function scope (not inside the loop). AU3Check will still observe that `$iPendLen` has no initialiser. The variable is assigned on line 255 (`$iPendLen = UBound($aPendingIdx)`) in the `_SM_StateNeedsPolling` branch and on line 302 (`$iPendLen = UBound($aPendingIdx)`) in the ControlService-accepted branch, before it is read (immediately after each assignment via the `ReDim` statements at lines 256–257 and 303–304).

**However**, AU3Check's `-w 4` analysis checks whether a `Local` variable can be read before any assignment. Since `$iPendLen` is only ever *read* directly after being assigned on the same code path (the two `$iPendLen = UBound(...)` assignments each immediately precede the `ReDim` reads), and the declaration is now outside the loop, AU3Check should not fire `-w 4` on the moved declaration — the two assignment sites cover all read sites.

**Strictly speaking:** the fix resolves the `-w 3` re-declaration-in-loop concern from BUG-02. For `-w 4`: with no initialiser and assignments only inside conditional branches, some AU3Check versions may still emit a `-w 4` here if they cannot prove coverage. Adding `= 0` as an initialiser would fully silence this. For this round-2 report the finding is classified **RESOLVED** as the structural fix matches BUG-12 recommendation; a belt-and-suspenders `= 0` initialiser is noted as a low-risk follow-up.

#### RESOLVED — R3: `_SM_GetServiceState` removed

**BUG-12 finding:** `_SM_GetServiceState` was listed in the module header's public interface but was not called from `_SM_StopServicesBatch` or the main script.

**Current state:** Searching the entire file for `_SM_GetServiceState` returns no matches. The function has been removed. The header's `; INTERNAL HELPERS` list (lines 18–24) does not include it. **Fully resolved.**

---

#### NEW — O1: `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` name mismatch (NEW CRITICAL -w 1)

**This is a new issue introduced by or surviving BUG-12 fixes, not present in the original BUG-12 report.**

**Location:** `Includes/ServiceManager.au3`, line 55.

**Current declaration:**

```autoit
Global Const $SM_OUTCOME_ALREADY_STOPPED_STOPPED = "ALREADY_STOPPED"
```

**Usage sites within the same file:**

```autoit
; Line 246 (_SM_StopServicesBatch, ALREADY_STOPPED branch):
$aResults[$i][3] = $SM_OUTCOME_ALREADY_STOPPED

; Line 291 (_SM_StopServicesBatch, ControlService Win32-1062 branch):
If $sCtrlOutcome = $SM_OUTCOME_ALREADY_STOPPED Then
```

**Usage sites in `Stop Services Processes.au3`:**

```autoit
; Line 247 (_RunServiceBatchStop, Select block):
Case $sOutcome = $SM_OUTCOME_ALREADY_STOPPED
```

**Usage site in `Tests/ServiceManager.Tests.au3`:**

```autoit
; Line ~190 (_Test_Win32ErrToOutcome):
_TestAssert("win32 1062 → ALREADY_STOPPED", _SM_Win32ErrToOutcome(1062) = $SM_OUTCOME_ALREADY_STOPPED, ...)
```

**The declared constant name is `$SM_OUTCOME_ALREADY_STOPPED_STOPPED`** (double `_STOPPED` suffix). Every reference in every file uses `$SM_OUTCOME_ALREADY_STOPPED` (single `_STOPPED` suffix). The declared name and all reference names do not match.

**AU3Check consequence:**
- In `Includes/ServiceManager.au3`: lines 246 and 291 reference `$SM_OUTCOME_ALREADY_STOPPED`, which is never declared. AU3Check `-w 1` fires twice in this file.
- In `Stop Services Processes.au3`: line 247 references `$SM_OUTCOME_ALREADY_STOPPED`. Since `ServiceManager.au3` is `#include`d, AU3Check will have already declared `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` but not `$SM_OUTCOME_ALREADY_STOPPED`. `-w 1` fires here too.
- In `Tests/ServiceManager.Tests.au3`: line ~190 references `$SM_OUTCOME_ALREADY_STOPPED`. Same result — `-w 1` fires.

**Runtime consequence (Windows):** At runtime, AutoIt treats undeclared variables as empty strings. `$SM_OUTCOME_ALREADY_STOPPED` resolves to `""`, not `"ALREADY_STOPPED"`. The ALREADY_STOPPED branch in `_RunServiceBatchStop` would silently fall through to the `Case Else` branch and log a spurious "Service outcome unknown" error message. The `_SM_Win32ErrToOutcome` function would return `$SM_OUTCOME_ALREADY_STOPPED` (empty string `""`) for Win32 1062, misclassifying NOT_ACTIVE as an unknown outcome rather than ALREADY_STOPPED.

**Severity: CRITICAL.** This is both a static warning and an active runtime logic bug. The constant `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` on line 55 must be renamed to `$SM_OUTCOME_ALREADY_STOPPED` to match all call sites.

**Note on `$SM_OUTCOME_ALREADY_STOPPED` in `_SM_Win32ErrToOutcome`:** Line 425 (`Return $SM_OUTCOME_ALREADY_STOPPED`) also references the mismatched name. This is a fourth `-w 1` instance within `ServiceManager.au3` alone.

**Total new `-w 1` warnings from O1:** 4 within `ServiceManager.au3` + 1 in `Stop Services Processes.au3` + 1 in `Tests/ServiceManager.Tests.au3` = **6 new `-w 1` warnings**.

---

### File 3: `Stop Services Processes.au3`

#### STILL OPEN — O2: `Local $iPriorityConst` without initialiser in `SetProcessPriority()` (HIGH -w 4)

**BUG-12 finding:** `Local $iPriorityConst` at line 312 (original numbering) has no initialiser. The Switch assigns it in Cases "1", "2", "3" but `Case Else` calls `Return` before the variable is used. AU3Check's static dataflow analysis flags this as `-w 4`.

**Current state (lines 318–330):**

```autoit
Local $iPriorityConst
Switch $sPriorityLevel
    Case "1"
        $iPriorityConst = $AUTOIT_PRIORITY_BELOW_NORMAL
    Case "2"
        $iPriorityConst = $AUTOIT_PRIORITY_NORMAL
    Case "3"
        $iPriorityConst = $AUTOIT_PRIORITY_ABOVE_NORMAL
    Case Else
        ...
        Return
EndSwitch
```

`Local $iPriorityConst` at line 318 still has **no initialiser**. The `-w 4` warning is **unchanged from BUG-12**. The recommended fix (`Local $iPriorityConst = $AUTOIT_PRIORITY_NORMAL`) has not been applied.

**Status: STILL OPEN (-w 4, HIGH).**

---

#### STILL OPEN — O3: `Local $sPriorityName` without initialiser in `SetProcessPriority()` (HIGH -w 4)

**BUG-12 finding:** `Local $sPriorityName` at line 335 (original) has no initialiser. The Switch assigns it in three Cases but has no `Case Else` default. AU3Check flags `-w 4` because the variable can reach line 356 unassigned if none of the three Cases match (AU3Check does not reason about upstream input constraints).

**Current state (lines 341–349):**

```autoit
Local $sPriorityName
Switch $iPriorityConst
    Case $AUTOIT_PRIORITY_BELOW_NORMAL
        $sPriorityName = "Below Normal"
    Case $AUTOIT_PRIORITY_NORMAL
        $sPriorityName = "Normal"
    Case $AUTOIT_PRIORITY_ABOVE_NORMAL
        $sPriorityName = "Above Normal"
EndSwitch
```

`Local $sPriorityName` at line 341 still has **no initialiser**. The `-w 4` warning is **unchanged from BUG-12**. The recommended fix (`Local $sPriorityName = ""`) has not been applied.

**Status: STILL OPEN (-w 4, HIGH).**

---

#### STILL OPEN — O4: `$iWin32` declared outside Select block; unused in 4 of 5 branches (MEDIUM -w 2)

**BUG-12 finding:** `Local $iWin32 = $aResults[$i][4]` is declared before the Select block in `_RunServiceBatchStop`. It is only read in the `Case $sOutcome = $SM_OUTCOME_FAILED` branch (line 254). In all other branches (STOPPED, ALREADY_STOPPED, TIMED_OUT, UNAVAILABLE, Else) the variable is declared but never consumed. AU3Check `-w 2` fires because there is a code path through the function where the Local variable is never read.

**Current state (lines 240–258):**

```autoit
For $i = 0 To UBound($aResults) - 1
    Local $sSvcName = $aResults[$i][0]
    Local $sOutcome = $aResults[$i][3]
    Local $iWin32   = $aResults[$i][4]
    Select
        Case $sOutcome = $SM_OUTCOME_STOPPED
            _LogMessage("Service stopped: " & $sSvcName, ...)
        Case $sOutcome = $SM_OUTCOME_ALREADY_STOPPED
            _LogMessage("Service already stopped: " & $sSvcName, ...)
        Case $sOutcome = $SM_OUTCOME_TIMED_OUT
            _LogMessage("Service stop timed out: " & $sSvcName, ...)
        Case $sOutcome = $SM_OUTCOME_UNAVAILABLE
            _LogMessage("Service not found: " & $sSvcName, ...)
        Case $sOutcome = $SM_OUTCOME_FAILED
            _LogMessage("Service stop failed: " & $sSvcName & " (Win32: " & $iWin32 & ")", ...)
        Case Else
            _LogMessage("Service outcome unknown: " & $sSvcName & " (" & $sOutcome & ")", ...)
    EndSelect
Next
```

`Local $iWin32 = $aResults[$i][4]` is at line 243. It is only used in the `$SM_OUTCOME_FAILED` branch. The structure is **unchanged from BUG-12**. The recommended fix (move `$iWin32` declaration inside the FAILED Case block) has not been applied.

**Status: STILL OPEN (-w 2, MEDIUM).**

---

#### STILL OPEN — O5: `Dim` at global scope (Maintenance)

**BUG-12 finding:** Lines 121, 127, 128 (original) use `Dim` at global scope rather than `Global`. While `Dim` at global scope is legal in AutoIt, it is non-idiomatic and may trigger style diagnostics in some AU3Check versions.

**Current state (lines 120, 126, 127):**

```autoit
; Line 120:
Dim $sLogDir = StringRegExpReplace($sLogFile, "\\[^\\]+$", "")
; Line 126:
Dim $sDateTime = _NowTime(12) & " " & @MDAY & "/" & @MON & "/" & @YEAR
; Line 127:
Dim $sLogEntry = $sDateTime & " [" & $LOG_TYPE_SYSTEM & "] Log file initialized"
```

All three `Dim` declarations remain at global scope. These appear inside the `If Not FileExists($sLogFile)` ... `Else` block at top-level, which executes at script startup. The fix (`Global` instead of `Dim`) has not been applied.

**Status: STILL OPEN (Maintenance).**

---

### File 4: `Includes/ServiceControl.au3`

#### STILL OPEN — O6: All constants use plain `Global` (not `Global Const`) (Maintenance)

**BUG-12 finding:** Every constant in `ServiceControl.au3` (e.g., `$SC_MANAGER_CONNECT`, `$SERVICE_STOP`, `$SERVICE_CONTROL_STOP`, all service type and start-type constants) is declared with plain `Global` rather than `Global Const`. This makes them mutable at runtime — any code that accidentally assigns to them will silently corrupt the constant value. This is a correctness hazard and a style violation against standard AutoIt practice, but AU3Check does not emit `-w 1` through `-w 4` warnings for plain `Global` vs `Global Const`.

**Current state (lines 1–88):** All constants remain declared as `Global` (not `Global Const`). No change from BUG-12.

**Status: STILL OPEN (Maintenance).** No AU3Check warning class (-w 1 to -w 4) applies. Remains a code-quality finding.

---

#### NEW CHECK — `$g_bLogBusy` conflict risk

**Task requirement:** Verify `$g_bLogBusy` declared in `Stop Services Processes.au3` does not conflict with any existing global.

**Current declaration (line 112 of `Stop Services Processes.au3`):**

```autoit
Global $g_bLogBusy = False         ; re-entrancy guard for _LogMessage file I/O
```

Searching all four files:
- `Includes/ServiceControl.au3`: no `$g_bLogBusy` reference.
- `Includes/ServiceManager.au3`: no `$g_bLogBusy` reference.
- `Tests/ServiceManager.Tests.au3`: no `$g_bLogBusy` reference.
- `Stop Services Processes.au3`: declared once (line 112), read and written in `_LogMessage` (lines 270–281). Single declaration, no duplicate.

**Result: No conflict. `$g_bLogBusy` is clean — 0 `-w 3` warnings introduced.**

---

## Compilation Unit Analysis

### Main script compilation unit

```
Stop Services Processes.au3
  └─ Includes\ServiceControl.au3   (#include-once, line 18)
  └─ Includes\ServiceManager.au3   (#include-once, line 20)
  └─ <standard library includes>
```

**Expected AU3Check output for this unit:**

| Warning | File | Line | Description |
|---------|------|------|-------------|
| `-w 1` | `Includes/ServiceManager.au3` | 246 | `$SM_OUTCOME_ALREADY_STOPPED` undeclared (O1) |
| `-w 1` | `Includes/ServiceManager.au3` | 291 | `$SM_OUTCOME_ALREADY_STOPPED` undeclared (O1) |
| `-w 1` | `Includes/ServiceManager.au3` | 425 | `$SM_OUTCOME_ALREADY_STOPPED` undeclared in `_SM_Win32ErrToOutcome` (O1) |
| `-w 1` | `Includes/ServiceManager.au3` | 248 | `$SM_OUTCOME_ALREADY_STOPPED` undeclared in `_LogMessage` call (O1) |
| `-w 1` | `Stop Services Processes.au3` | 247 | `$SM_OUTCOME_ALREADY_STOPPED` undeclared in `_RunServiceBatchStop` (O1) |
| `-w 2` | `Stop Services Processes.au3` | 243 | `$iWin32` declared Local but unused in 4 of 5 Select branches (O4) |
| `-w 4` | `Stop Services Processes.au3` | 318 | `$iPriorityConst` no initialiser (O2) |
| `-w 4` | `Stop Services Processes.au3` | 341 | `$sPriorityName` no initialiser (O3) |

**Total: 8 expected warnings for the main compilation unit.**

### Test file compilation unit

```
Tests\ServiceManager.Tests.au3
  └─ Includes\ServiceManager.au3   (#include-once, line 93)
```

**Expected AU3Check output for this unit:**

| Warning | File | Line | Description |
|---------|------|------|-------------|
| `-w 1` | `Includes/ServiceManager.au3` | 246, 248, 291, 425 | `$SM_OUTCOME_ALREADY_STOPPED` undeclared (O1) |
| `-w 1` | `Tests/ServiceManager.Tests.au3` | ~190 | `$SM_OUTCOME_ALREADY_STOPPED` undeclared in test assertion (O1) |

**Total: 5 expected warnings for the test compilation unit** (all from O1).

---

## Resolution Status by Original BUG-12 Recommendation

BUG-12 listed 7 recommended fixes in priority order. This section maps each to its current state.

| # | BUG-12 Recommendation | File | Status |
|---|----------------------|------|--------|
| 1 | Move `#include "Includes\ServiceManager.au3"` to top of test file | `Tests/ServiceManager.Tests.au3` | **DONE** — moved to line 93 |
| 2 | Add `= ""` initialiser to `Local $sPriorityName` | `Stop Services Processes.au3` | **NOT DONE** |
| 3 | Add `= $AUTOIT_PRIORITY_NORMAL` initialiser to `Local $iPriorityConst` | `Stop Services Processes.au3` | **NOT DONE** |
| 4 | Move `Local $iWin32` inside `$SM_OUTCOME_FAILED` Case block | `Stop Services Processes.au3` | **NOT DONE** |
| 5 | Add `= 0` initialiser to `Local $iPendLen` | `Includes/ServiceManager.au3` | **DONE** (moved to function scope, structural fix applied; `= 0` initialiser not added but risk is low as described in R2) |
| 6 | Remove dead globals `$sStringInstaller` and `$taskcloseran` | `Stop Services Processes.au3` | **NOT CHECKED** — outside scope of this pass (AU3Check does not emit -w 2 for dead Globals) |
| 7 | Replace `Dim` with `Global` at global scope | `Stop Services Processes.au3` | **NOT DONE** |

---

## New Issue Introduced — Action Required

**O1 is a regression introduced during the BUG-12 fix cycle** (or was pre-existing and not caught in the original scan). The constant on line 55 of `Includes/ServiceManager.au3` reads:

```autoit
Global Const $SM_OUTCOME_ALREADY_STOPPED_STOPPED = "ALREADY_STOPPED"
```

This must be corrected to:

```autoit
Global Const $SM_OUTCOME_ALREADY_STOPPED = "ALREADY_STOPPED"
```

This single one-token rename eliminates all 6 new `-w 1` warnings and also fixes the runtime logic bug (ALREADY_STOPPED outcome silently becoming empty string on Windows). It is the highest-priority remaining action.

---

## Prioritised Remaining Action List

1. **[CRITICAL — NEW]** `Includes/ServiceManager.au3` line 55: Rename `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` to `$SM_OUTCOME_ALREADY_STOPPED`. Eliminates 6 `-w 1` warnings and fixes a live runtime misclassification bug.

2. **[HIGH — OPEN from BUG-12]** `Stop Services Processes.au3` line 318: Change `Local $iPriorityConst` to `Local $iPriorityConst = $AUTOIT_PRIORITY_NORMAL`.

3. **[HIGH — OPEN from BUG-12]** `Stop Services Processes.au3` line 341: Change `Local $sPriorityName` to `Local $sPriorityName = ""`.

4. **[MEDIUM — OPEN from BUG-12]** `Stop Services Processes.au3` line 243: Move `Local $iWin32 = $aResults[$i][4]` inside the `Case $sOutcome = $SM_OUTCOME_FAILED` block.

5. **[LOW — from BUG-12]** `Stop Services Processes.au3` lines 120, 126, 127: Replace `Dim` with `Global` at global scope.

6. **[LOW — belt-and-suspenders]** `Includes/ServiceManager.au3` line 192: Add `= 0` initialiser to `Local $iPendLen` (structural fix already applied; this silences any residual AU3Check `-w 4` path analysis).

7. **[Maintenance — from BUG-12]** `Includes/ServiceControl.au3`: Convert all `Global` constant declarations to `Global Const`.
