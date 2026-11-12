# CR3-01 — Code Review: Stop Services Processes.au3
**Fixed point:** `c113a6f`
**HEAD commit:** `de1353e` — fix: bug investigation, AU3Check hardening, and remaining documented work
**File scope:** `Stop Services Processes.au3` (with necessary cross-references to `Includes/ServiceManager.au3`)
**Spec sources:** BUG-08, BUG-09, BUG-10, CODING_STANDARDS.md

---

## Standards

### BUG-10 fix — `HotKeySet` re-enable placement

The fix disables the hotkey at the first line of `ToggleScript` and re-enables it at the last line before `EndFunc`:

```autoit
Func ToggleScript()
    HotKeySet("+{F1}")  ; line 150 — disable
    If $bScriptRunning Then
        ...
        $bScriptRunning = False
    Else
        ...
        $bScriptRunning = True
    EndIf
    While $bScriptRunning
        ...
        Sleep($MAIN_LOOP_SLEEP_MS)
        ...
    WEnd
    HotKeySet("+{F1}", "ToggleScript")  ; line 173 — re-enable
EndFunc
```

**Single re-enable path analysis:** There is exactly one `EndFunc` and therefore exactly one exit point from `ToggleScript`. The re-enable is placed on the line immediately before `EndFunc`. The function has no early `Return` statements in the diff. All paths — both the `If $bScriptRunning` branch and the `Else` branch, with or without entering the `While` loop — converge at line 173 before the function exits. The single re-enable covers all paths.

**Standards finding:** `CODING_STANDARDS.md` §Function Naming lists `ToggleScript` as PascalCase (hotkey-triggered, public) — no naming violation. No documented standard requires guard-variable ordering within a hotkey function; the placement is correct.

---

### BUG-09 fix — `$g_bLogBusy` guard placement

The guard is placed around only the file I/O block:

```autoit
If $g_bLogBusy Then Return          ; guard check — before FileOpen
$g_bLogBusy = True

Local $hFile = FileOpen($sLogFile, 1)
If $hFile = -1 Then
    $g_bLogBusy = False             ; clear on FileOpen failure
    ConsoleWrite(...)
    Return
EndIf
FileWrite($hFile, $sLogEntry)
FileClose($hFile)
$g_bLogBusy = False                 ; clear after FileClose

If $bLogToConsole Then
    ConsoleWrite($sLogEntry & @CRLF)
EndIf
```

**Does it wrap ONLY file I/O?** Yes. `$g_bLogBusy` is set `True` immediately before `FileOpen` and cleared immediately after `FileClose`. The `ConsoleWrite` call below (`$bLogToConsole` path) runs outside the guard. This is correct per the bug report's intent: the guard prevents re-entrant `FileOpen`, not re-entrant `ConsoleWrite`.

**Does it clear on `FileOpen` failure?** Yes. `$g_bLogBusy = False` is present in the `$hFile = -1` early-return branch. The guard is correctly released on the failure path.

**Standards finding — `g_` prefix in production code:** `CODING_STANDARDS.md` §Test File Conventions states: "The `g_` prefix for global variables in test harnesses is an accepted convention within test files and does not violate the standard variable naming rules applied to production code." The implication is that the `g_` prefix is a test-harness convention; it is not explicitly banned from production code, but the convention is described only in the test-file context. All other global variables in the production script (`$bScriptRunning`, `$aPriorityWatchPIDs`, etc.) use no such prefix. This is a **judgement call (Mysterious Name smell baseline)**: the `g_` prefix is not mysterious per se, but it is inconsistent with the naming pattern of every other global in the same file. Flag for consistency.

---

### BUG-08 fix — `$iPrevLen` capture and rollback order

```autoit
Local $bWasEmpty = (UBound($aPriorityWatchPIDs) = 0)
Local $iPrevLen = UBound($aPriorityWatchPIDs)   ; captured before first add
_ArrayAdd($aPriorityWatchPIDs, $iPID)
If @error Then
    ... Return                                   ; no rollback needed: first add failed
EndIf
_ArrayAdd($aPriorityWatchTargets, $iPriorityConst)
If @error Then
    ReDim $aPriorityWatchPIDs[$iPrevLen]         ; roll back first add
    Return
EndIf
_ArrayAdd($aPriorityWatchNames, $sPriorityName)
If @error Then
    ReDim $aPriorityWatchPIDs[$iPrevLen]         ; roll back first add
    ReDim $aPriorityWatchTargets[$iPrevLen]      ; roll back second add
    Return
EndIf
```

**`$iPrevLen` captured before first add:** Correct. `$iPrevLen = UBound($aPriorityWatchPIDs)` is evaluated before any `_ArrayAdd` call, so it holds the pre-mutation length.

**Rollback order:** The third `_ArrayAdd` failure rolls back `$aPriorityWatchPIDs` first, then `$aPriorityWatchTargets`. Since neither of those two arrays depends on the other during a `ReDim` (each is independent), order does not matter for correctness here. However, the semantically correct order for rollback is last-added-first-removed (i.e., `$aPriorityWatchTargets` should be rolled back before `$aPriorityWatchPIDs` to mirror the inverse of the insertion sequence `PIDs → Targets → Names`). The implemented order is `PIDs → Targets`, which is not last-in-first-out. In practice this produces the same final state since both `ReDim` calls are independent, but it deviates from the conventional rollback principle. This is a **judgement call**.

**Standards finding:** No hard violation. The fix correctly guards each `_ArrayAdd` with `@error` per the `CODING_STANDARDS.md` §@error Capture requirement (which applies to `DllCall`; `_ArrayAdd` is an AutoIt stdlib function that also sets `@error`, so the spirit of the standard applies). The rollback order is a style concern only.

---

### Dead code deletions

**`$taskcloseran`:** Deleted from globals. `git show c113a6f` confirms it was declared at line 86 (`Global $taskcloseran = 0`) and is not present in the current file. No read site for `$taskcloseran` appears anywhere in the diff. Deletion is correct. No standard is violated.

**`$PROCESS_IDLE`:** Deleted from globals (was line 108). The variable was a shim for a missing constant in this AutoIt version. All prior read sites have been replaced by `$AUTOIT_PRIORITY_IDLE` (defined in `#Region ;Configuration — AutoIt process priority constants`). `$PROCESS_IDLE` does not appear anywhere in the current file. Deletion is correct.

**`_exit` → `_Exit` rename:** The old file has `Func _Exit()` (already `PascalCase`) at line 629; the `HotKeySet` at line 33 uses `"_Exit"`. The diff shows no change to either site — `_Exit` was already the correct name in the old file. The task description refers to this as a rename, but the diff shows no change to the function name or the hotkey registration. No naming violation exists; `_Exit` is correctly named per `CODING_STANDARDS.md` §Function Naming (`_UnderscorePascalCase`).

**`$SM_OUTCOME_ALREADY_STOPPED` / `$SM_OUTCOME_TIMED_OUT` renames (HARD VIOLATION):**

The diff to `Includes/ServiceManager.au3` shows:

| Old name | New declaration name | New name at all read sites |
|---|---|---|
| `$SM_OUTCOME_ALREADY` | `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` | `$SM_OUTCOME_ALREADY_STOPPED` |
| `$SM_OUTCOME_TIMEDOUT` | `$SM_OUTCOME_TIMED_OUT` | `$SM_OUTCOME_TIMED_OUT` |

The `$SM_OUTCOME_TIMED_OUT` rename is consistent: the declaration and all four read sites in `ServiceManager.au3` match, and the main script uses `$SM_OUTCOME_TIMED_OUT`. Correct.

The `$SM_OUTCOME_ALREADY_STOPPED` rename has a **typo in the declaration**: the constant is declared as `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` (doubled `_STOPPED` suffix) at line 55 of `ServiceManager.au3`, but all four read sites within `ServiceManager.au3` reference `$SM_OUTCOME_ALREADY_STOPPED` (without the duplication), and the main script's `_RunServiceBatchStop()` also uses `$SM_OUTCOME_ALREADY_STOPPED`. At runtime, `$SM_OUTCOME_ALREADY_STOPPED` is an undeclared identifier — AU3Check with `-w 1` would flag this as an undeclared variable. `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` is declared but never read. This is a **hard standards violation** (`CODING_STANDARDS.md` §AU3Check Compliance: all `.au3` files must satisfy `AU3Check -q -d -w 1 -w 2 -w 3 -w 4`; `-d` checks undeclared variables).

---

### `#EndRegion` labels — 5 previously bare regions

The old file had 5 bare `#EndRegion` tags (lines 37, 48, 60, 73, 82 in the old numbering — the five regions `hotkeys`, `Timing constants`, `Configuration — Log constants`, `Configuration — AutoIt process priority constants`, `Configuration — Target lists`). The diff adds the matching label to each:

| `#EndRegion` | Old | New |
|---|---|---|
| hotkeys | bare | `;hotkeys` |
| Timing constants | bare | `;Timing constants` |
| Configuration — Log constants | bare | `;Configuration — Log constants` |
| Configuration — AutoIt process priority constants | bare | `;Configuration — AutoIt process priority constants` |
| Configuration — Target lists | bare | `;Configuration — Target lists` |

All 5 previously unlabeled `#EndRegion` tags now carry labels. The `#Region ;Variables/Logging` / `#EndRegion ;Variables/Logging` and `#Region ;traytips` / `#EndRegion ;traytips` pairs were already labeled and remain so. The `#Region ;**** Directives... ****` / `#EndRegion` pair at lines 2/11 was also already labeled. All `#EndRegion` tags in the file now carry a matching label. Fully compliant with `CODING_STANDARDS.md` §Region Structure.

---

### Smell baseline

**Speculative Generality (judgement call):** `$bWasEmpty` and `$iPrevLen` are computed from the same `UBound($aPriorityWatchPIDs)` call and both initialized on adjacent lines. `$bWasEmpty` could be replaced by `($iPrevLen = 0)` after `$iPrevLen` is captured, eliminating one `UBound` call. This is a minor duplication rather than speculative generality. Low priority.

**No other smell findings:** The changes are tightly scoped to the four bug fixes and the region-label cleanup. No new abstractions, parameters, or hooks not demanded by the specs are introduced.

---

## Spec

### BUG-10 — Hotkey re-entrancy fix

**Spec requirement (BUG-10, Issue 1):** Set `$bScriptRunning` before the `MsgBox` yield points, or use `HotKeySet` to disable/re-enable the hotkey, to prevent double-activation.

BUG-10 §Issue 1 describes the root cause as "`$bScriptRunning` is set AFTER the `MsgBox` yield point" and states: "The correct fix would be to set `$bScriptRunning = True` as the first statement in the `Else` branch (before `MsgBox`), and `$bScriptRunning = False` as the first statement in the `If` branch." The implemented fix disables the hotkey entirely (`HotKeySet("+{F1}")`) at function entry instead.

**Assessment:** The spec's recommended fix (guard-variable reordering) was not implemented. The implemented fix (hotkey disable/re-enable) is an alternative approach that also prevents double-activation. However, there is a **behavioral deviation**: the guard-variable approach still allows the `MsgBox` to appear while the hotkey is queued (it just prevents the queued press from launching a second loop), whereas the `HotKeySet` disable approach silently drops all keypresses during the function's execution window. The spec does not prohibit this alternative approach, but the spec's described fix pattern is not the one applied.

Additionally, BUG-10 §Issue 1 also identifies "no spam guard" — rapid presses queue multiple invocations. The `HotKeySet` disable at function entry means that presses during the function body are dropped rather than queued, which addresses the spam concern more completely than the guard-variable approach. This is an improvement beyond the spec.

**Deviation from spec:** Partial — the fix achieves the specified goal (prevent double-activation) by a different mechanism than described. The spec says "set `$bScriptRunning` before `MsgBox`"; the implementation uses `HotKeySet` suppression. Functionally correct; not a spec failure, but the method diverges.

---

### BUG-09 — `$g_bLogBusy` guard

**Spec requirement (BUG-09-B):** "Use a guard variable (a boolean global flag) that `_LogMessage` sets on entry and clears on exit. If the flag is already set when `_LogMessage` is entered (re-entrant call from an `AdlibRegister` interrupt), the re-entrant message should either be queued or written via a separate direct `FileWrite` call... A simpler alternative is to open the file, acquire the write, close it — and accept that AutoIt's single-threaded interrupt model means the guard flag approach is sufficient."

The implementation sets `$g_bLogBusy = True` before `FileOpen` and clears it after `FileClose` (or on `FileOpen` failure). Re-entrant calls that find the flag set return immediately — the message is silently dropped.

**Assessment:** The spec acknowledges "queued or written via a separate direct `FileWrite` call" as one option, but then endorses the simpler "guard flag is sufficient" approach. The implementation matches the simpler approach. The spec's "queued message would need to be flushed after the outer `FileClose`" is not implemented — messages that arrive during the busy window are dropped. This is within spec (the spec says "either be queued or written... or accept that the guard flag is sufficient").

**Minor deviation:** The spec says the guard should be set "on entry" and cleared "on exit." The implementation sets the guard after the `iLevel` filter check and after computing `$sDateTime`/`$sLogEntry`, not at the absolute first line of the function. This means the guard does not prevent re-entrant computation of the timestamp/log-entry string — only the file I/O is guarded. This is consistent with the spec's intent ("prevents the nested `FileOpen` from occurring") and is not a spec violation.

**No deviation from spec.**

---

### BUG-08 — `$iPrevLen` rollback

**Spec requirement (BUG-08 §8):** "The fix should check `@error` after each `_ArrayAdd` and roll back the preceding successful adds if any subsequent one fails, or abort `LockProcessPriority` and notify the user."

The implementation:
- Checks `@error` after each `_ArrayAdd`. Correct.
- On first `_ArrayAdd` failure: returns with an error log. No rollback needed (no previous add succeeded). Correct.
- On second `_ArrayAdd` failure: `ReDim $aPriorityWatchPIDs[$iPrevLen]`. Rolls back the first add. Correct.
- On third `_ArrayAdd` failure: `ReDim $aPriorityWatchPIDs[$iPrevLen]` then `ReDim $aPriorityWatchTargets[$iPrevLen]`. Rolls back both prior adds. Correct in final state.

**`$iPrevLen` captured before first add:** The spec requires rollback to the pre-mutation state. `$iPrevLen = UBound($aPriorityWatchPIDs)` is captured on the line immediately before the first `_ArrayAdd`, so it holds the correct pre-mutation length. Correct.

**Rollback order:** The spec says "roll back the preceding successful adds." For the third `_ArrayAdd` failure, the two preceding successful adds were `$aPriorityWatchPIDs` (first) and `$aPriorityWatchTargets` (second). The correct last-in-first-out rollback order would be `Targets` first, then `PIDs`. The implementation rolls back `PIDs` first, then `Targets`. As noted in the Standards section, this produces the correct final state since the `ReDim` operations are independent. The spec does not mandate a specific rollback order, only that "the preceding successful adds" be rolled back. **No spec deviation.**

**No deviation from spec.**

---

### Dead code deletions

**`$taskcloseran`:** BUG-01 (referenced in BUG-INDEX.md) identified this as dead. Its deletion is consistent with removing dead globals. No spec covers it in the three provided bug files; it falls under the commit's "remaining documented work." No spec deviation.

**`$PROCESS_IDLE`:** BUG-05 identified this as a shim that was replaced by `$AUTOIT_PRIORITY_IDLE`. Its deletion is correct — `$AUTOIT_PRIORITY_IDLE` now carries the same value (`0`) with a name that follows `CODING_STANDARDS.md` §Constant Naming (`$AUTOIT_PRIORITY_` prefix). No spec deviation.

**`$SM_OUTCOME_ALREADY_STOPPED` rename (SPEC DEVIATION):**

BUG-04 (from the BUG-INDEX) describes the rename from `$SM_OUTCOME_ALREADY` → `$SM_OUTCOME_ALREADY_STOPPED` and from `$SM_OUTCOME_TIMEDOUT` → `$SM_OUTCOME_TIMED_OUT`. The spec intent is for the declaration name and all read sites to be aligned on the new names.

The implementation renamed `$SM_OUTCOME_TIMEDOUT` → `$SM_OUTCOME_TIMED_OUT` correctly everywhere. For `$SM_OUTCOME_ALREADY_STOPPED`, the declaration was renamed to `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` (a doubled-suffix typo), while all read sites use `$SM_OUTCOME_ALREADY_STOPPED`. The spec asked for the declaration name to match the read-site name. The declared identifier `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` does not match what the spec asked for (`$SM_OUTCOME_ALREADY_STOPPED`). **This is a spec deviation and a confirmed bug**: `$SM_OUTCOME_ALREADY_STOPPED` is undeclared at runtime; the value `"ALREADY_STOPPED"` is unreachable via the intended constant name.

---

## Summary

| Axis | Findings | Worst issue |
|---|---|---|
| **Standards** | 5 findings: `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` typo (hard violation, AU3Check `-d` will flag `$SM_OUTCOME_ALREADY_STOPPED` as undeclared); `g_` prefix inconsistency in production code (judgement call); rollback order not last-in-first-out (judgement call); `$bWasEmpty`/`$iPrevLen` minor duplication (judgement call); `_exit`→`_Exit` rename described in task but not reflected in diff (no-op, name was already correct). | **Hard violation**: `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` typo in `Includes/ServiceManager.au3` line 55 — AU3Check `-d` will flag `$SM_OUTCOME_ALREADY_STOPPED` as undeclared across the compilation unit. |
| **Spec** | 2 findings: BUG-10 fix uses `HotKeySet` suppression instead of spec-described guard-variable reordering (alternative approach, goal met); `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` typo deviates from BUG-04's rename spec (confirmed spec deviation — declaration does not match the renamed identifier). | **Confirmed spec deviation**: `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` typo in declaration — the spec asked for `$SM_OUTCOME_ALREADY_STOPPED`; the declared name does not match, leaving the constant undeclared at all read sites. |
