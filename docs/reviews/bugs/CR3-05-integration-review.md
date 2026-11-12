# CR3-05 — Cross-File Integration Review

**Fixed point:** `c113a6f`
**HEAD commit:** `de1353e` — "fix: bug investigation, AU3Check hardening, and remaining documented work"
**Scope:** All 4 active `.au3` files:
- `Stop Services Processes.au3`
- `Includes/ServiceManager.au3`
- `Includes/ServiceControl.au3`
- `Tests/ServiceManager.Tests.au3`

**Date reviewed:** 2026-11-12

---

## Standards

### S-01 — `$SM_OUTCOME_ALREADY_STOPPED` rename: PARTIAL PASS with one defect

**Check:** Old names `$SM_OUTCOME_ALREADY` and `$SM_OUTCOME_TIMEDOUT` renamed in all three files that referenced them.

**Finding:** The old names are fully gone from all three files. `$SM_OUTCOME_TIMED_OUT` is correctly declared and used in `ServiceManager.au3` (line 58), `Stop Services Processes.au3` (line 249), and `Tests/ServiceManager.Tests.au3` (lines 329, 331). However, the new name for `$SM_OUTCOME_ALREADY_STOPPED` has a **double-word typo** in its declaration:

```autoit
; ServiceManager.au3, line 55:
Global Const $SM_OUTCOME_ALREADY_STOPPED_STOPPED = "ALREADY_STOPPED"
```

The constant is declared as `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` (double `_STOPPED`). Every use site in all three files correctly references `$SM_OUTCOME_ALREADY_STOPPED` (single `_STOPPED`):

- `ServiceManager.au3` line 246: `$aResults[$i][3] = $SM_OUTCOME_ALREADY_STOPPED`
- `ServiceManager.au3` line 291: `If $sCtrlOutcome = $SM_OUTCOME_ALREADY_STOPPED Then`
- `ServiceManager.au3` line 425: `Return $SM_OUTCOME_ALREADY_STOPPED`
- `Stop Services Processes.au3` line 247: `Case $sOutcome = $SM_OUTCOME_ALREADY_STOPPED`
- `Tests/ServiceManager.Tests.au3` line 190: `_SM_Win32ErrToOutcome(1062) = $SM_OUTCOME_ALREADY_STOPPED`

**Impact:** This is a **compile-breaking defect**. Under AU3Check `-d`, every use site will produce an "undeclared variable" error because `$SM_OUTCOME_ALREADY_STOPPED` is never declared — only `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` is. At runtime, AutoIt would treat `$SM_OUTCOME_ALREADY_STOPPED` as an undeclared variable (empty string), causing the `Case` branch in `_RunServiceBatchStop` and the comparison in `_SM_Win32ErrToOutcome` to silently fail: already-stopped services would fall through to the `Case Else` / FAILED branch instead.

**Verdict:** FAIL — declaration name and all use sites are mismatched. The declaration must be corrected to `$SM_OUTCOME_ALREADY_STOPPED`.

---

### S-02 — `_Exit()` rename and HotKeySet registration: PASS

**Check:** `HotKeySet("{ScrollLock}{PAUSE}", "_Exit")` registration matches the renamed function `_Exit`.

**Finding:** Confirmed clean:
- Registration at `Stop Services Processes.au3` line 33: `HotKeySet("{ScrollLock}{PAUSE}", "_Exit")`
- Function definition at line 654: `Func _Exit()`

The string `"_Exit"` in the HotKeySet call exactly matches the function name. No residual `"_exit"` lowercase registration exists anywhere in the file. No other file registers a `{ScrollLock}{PAUSE}` hotkey. PASS.

---

### S-03 — `$g_bLogBusy` visibility: PASS

**Check:** `$g_bLogBusy` declared Global in main script; used inside `_LogMessage` — is it visible to all function scopes?

**Finding:** Declared at `Stop Services Processes.au3` line 112:

```autoit
Global $g_bLogBusy = False
```

The declaration is at file scope (inside `#Region ;Variables/Logging`, outside any function), so it is a true AutoIt `Global` and is visible to all functions in the compilation unit, including `_LogMessage`. Confirmed at lines 270, 271, 275, 281. No local shadowing of `$g_bLogBusy` exists anywhere in the file. PASS.

---

### S-04 — `$LOG_LEVEL_*` and `$LOG_TYPE_*` ownership, no duplicate declarations: PASS

**Check:** `ServiceManager.au3` owns the shared log constants; main script declares only the 3 unique ones; no duplicate declarations remain.

**Finding:**

`ServiceManager.au3` declares (lines 99–108):
- `$LOG_LEVEL_ERROR`, `$LOG_LEVEL_INFO`, `$LOG_LEVEL_VERBOSE`
- `$LOG_TYPE_SYSTEM`, `$LOG_TYPE_SERVICE`

`Stop Services Processes.au3` lines 50–59 carry an explicit comment that the shared constants are defined in `ServiceManager.au3` ("Duplicate definitions removed to fix AU3Check duplicate-declaration errors") and declares only the three file-unique types:
- `$LOG_TYPE_PROCESS`, `$LOG_TYPE_PROCESS_PRIORITY`, `$LOG_TYPE_PRIORITY_WATCHDOG`

No cross-file duplicates for any of these names are present. `Tests/ServiceManager.Tests.au3` and `ServiceControl.au3` declare none of them. PASS.

---

### S-05 — `_SM_GetServiceState` deleted; test harness still compiles: PASS

**Check:** `_SM_GetServiceState` was deleted from `ServiceManager.au3`. Does the test harness still compile without it?

**Finding:** The diff confirms `_SM_GetServiceState` is deleted from `ServiceManager.au3` (the function body is removed in the diff; the header reference at line ~19 is also removed). A repo-wide grep for `_SM_GetServiceState` across all `.au3` files returns **no matches** — the function is referenced nowhere in the test harness or any other file. This confirms BUG-03's earlier conclusion that the function was never called from any external site. The test harness does not reference `_SM_GetServiceState` and compiles cleanly without it. PASS.

---

## Spec

### SP-01 — `_RunServiceBatchStop` outcome routing after all renames: PASS with note

**Check:** Does `_RunServiceBatchStop` correctly route all outcomes after the rename?

**Finding:** `Stop Services Processes.au3` lines 240–258 show the `Select` block:

```autoit
Case $sOutcome = $SM_OUTCOME_STOPPED
Case $sOutcome = $SM_OUTCOME_ALREADY_STOPPED   ; ← renamed from $SM_OUTCOME_ALREADY
Case $sOutcome = $SM_OUTCOME_TIMED_OUT         ; ← renamed from $SM_OUTCOME_TIMEDOUT
Case $sOutcome = $SM_OUTCOME_UNAVAILABLE
Case $sOutcome = $SM_OUTCOME_FAILED
Case Else
```

All five outcome branches are present. The two renamed constants are used correctly at the call site. However, as noted in S-01, `$SM_OUTCOME_ALREADY_STOPPED` is not declared (the declaration has the double-`_STOPPED` typo), so at compile time this branch will evaluate against an empty string rather than `"ALREADY_STOPPED"`. The routing logic is structurally correct but will fail at runtime due to the S-01 declaration defect. Routing: PASS (structure). Runtime correctness: blocked by S-01 defect.

---

### SP-02 — Test harness `#include` position; `$SM_*` constants resolution: PASS

**Check:** `#include "Includes\ServiceManager.au3"` moved to the top `#Region ;Includes` block; all `$SM_*` constants resolve in all test functions.

**Finding:** The diff confirms the include was moved from the bottom of the file (after all `Func` definitions, line ~491 in the old file) to the `#Region ;Includes` block at the top (line 93 in the current file). The current file structure:

```autoit
#Region ;Includes
#include <AutoItConstants.au3>
#include <MsgBoxConstants.au3>
#include "Includes\ServiceManager.au3"   ; ← now at top
#EndRegion
```

All `$SM_*` constants (`$SM_OUTCOME_STOPPED`, `$SM_OUTCOME_ALREADY_STOPPED`, `$SM_OUTCOME_TIMED_OUT`, `$SM_OUTCOME_UNAVAILABLE`, `$SM_OUTCOME_FAILED`, `$SM_STATE_*`, `$SM_ERR_SVC_NOT_EXIST`) are declared in `ServiceManager.au3` and are therefore available to all functions, to the global-scope `$ERR_*` declarations, and to all inline test code in the test file. No forward-reference problem exists. PASS.

Note: Resolution of `$SM_OUTCOME_ALREADY_STOPPED` specifically is broken by the S-01 typo, not by include ordering.

---

### SP-03 — `ToggleScript` HotKeySet disable/re-enable symmetry: PASS

**Check:** The `HotKeySet` re-enable at the end of `ToggleScript` uses the exact same function name string as the original registration.

**Finding:**

Original registration (line 34, global scope):
```autoit
HotKeySet("+{F1}", "ToggleScript")
```

Inside `ToggleScript` (line 150):
```autoit
HotKeySet("+{F1}")   ; disable — no second argument clears the hotkey
```

Re-enable at end of `ToggleScript` (line 173):
```autoit
HotKeySet("+{F1}", "ToggleScript")   ; re-enable
```

The string `"ToggleScript"` is identical at both the registration and re-enable sites. AutoIt's hotkey registration is case-sensitive for the callback string, so an exact match is required. PASS.

---

## Summary

| Check | Verdict | Axis |
|---|---|---|
| S-01: `$SM_OUTCOME_ALREADY_STOPPED` rename | **FAIL** — declaration has double `_STOPPED` typo; all use sites broken | Standards |
| S-02: `_Exit` HotKeySet registration | PASS | Standards |
| S-03: `$g_bLogBusy` Global visibility | PASS | Standards |
| S-04: `$LOG_LEVEL_*`/`$LOG_TYPE_*` no duplicate declarations | PASS | Standards |
| S-05: `_SM_GetServiceState` deletion; harness compiles | PASS | Standards |
| SP-01: `_RunServiceBatchStop` outcome routing | PASS (structure) / runtime blocked by S-01 | Spec |
| SP-02: `#include` at top; `$SM_*` constants resolve | PASS | Spec |
| SP-03: `ToggleScript` HotKeySet re-enable symmetry | PASS | Spec |

**Standards axis:** 1 finding (FAIL). Worst issue: `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` typo in `ServiceManager.au3` line 55 — AU3Check will reject the entire compilation unit due to undeclared variable errors at every use site.

**Spec axis:** 1 finding (blocked by Standards defect above). Routing structure is complete and correct; runtime behavior of the `ALREADY_STOPPED` branch depends on fixing the declaration name.

**Required fix:** In `Includes/ServiceManager.au3` line 55, rename `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` to `$SM_OUTCOME_ALREADY_STOPPED`.
