# BUG-10 — Hotkey Re-entrancy and Concurrency Hazards

**Date**: 2026-11-12
**Scope**: `Stop Services Processes.au3`, `Includes/ServiceManager.au3`
**Hotkeys investigated**: `Shift+F1` (`ToggleScript`), `ScrollLock+PAUSE` (`_Exit`), `Ctrl+Alt+Shift+9` (`LockProcessPriority`)
**Status**: Confirmed bugs documented; no code changes made (findings only)

---

## Background: AutoIt Hotkey Delivery Model

AutoIt hotkeys are **not asynchronous interrupts**. They are delivered cooperatively at a yield point: the runtime checks the hotkey queue only when the current thread yields — specifically inside `Sleep()`, `MsgBox()`, `InputBox()`, and similar blocking calls. Between yield points, the hotkey is queued but does not fire.

Critically:
- **Hotkey callbacks are not re-entrant by the interrupt model** — but they *can* be invoked again the moment a yield point is reached inside a callback that is already running. If callback A calls `MsgBox()` or `Sleep()`, and a hotkey fires while that call is blocking, the callback executes again (or a different callback runs) before A returns.
- There is **no built-in debounce or exclusion guard**. AutoIt does not prevent the same hotkey callback from being entered a second time if a yield point is hit during the first execution.
- The main passive loop (`While 1 / Sleep(50) / WEnd`) runs only when no hotkey callback is executing. While a callback runs, the passive loop is suspended. This means `_PriorityWatchdog` (registered via `AdlibRegister`) can fire during any `Sleep()` or blocking dialog call inside a hotkey callback.

This delivery model is established in ADR-0010 and confirmed by the AutoIt documentation: hotkeys and Adlib callbacks share the same cooperative scheduling surface.

---

## Issue 1: `ToggleScript` — Double-Activation on Rapid Toggle Press

### Code (lines 150–173)

```autoit
Func ToggleScript()
    If $bScriptRunning Then
        _LogMessage("F1 pressed - Pausing script", ...)
        MsgBox($MB_SYSTEMMODAL, "AutoIT Script", "Script paused!", 1)   ; <-- yield point
        $bScriptRunning = False
    Else
        _LogMessage("F1 pressed - Starting script", ...)
        MsgBox($MB_SYSTEMMODAL, "AutoIT Script", "Script started!", 1)  ; <-- yield point
        $bScriptRunning = True
    EndIf

    While $bScriptRunning
        ...
        Sleep($MAIN_LOOP_SLEEP_MS)   ; <-- yield point
        ...
    WEnd
EndFunc
```

### Finding: BUG — `$bScriptRunning` is set AFTER the `MsgBox` yield point, not before

**Sequence of events on a double press**:

1. User presses `Shift+F1` while script is idle (`$bScriptRunning = False`).
2. `ToggleScript()` is entered. The `Else` branch is taken.
3. `MsgBox(...)` is called — this is a **yield point**. The UI blocks, waiting for the 1-second timeout or user dismissal.
4. User presses `Shift+F1` again **before** the `MsgBox` times out or is dismissed.
5. The hotkey is queued. Because the current thread is blocked in `MsgBox`, AutoIt can deliver the queued hotkey *immediately into the same execution context* — `ToggleScript()` is called a second time.
6. Second invocation: `$bScriptRunning` is still `False` (it was not set yet — line `$bScriptRunning = True` has not executed). The `Else` branch is taken again.
7. Second `MsgBox` fires. Eventually both `MsgBox` calls complete. Both invocations set `$bScriptRunning = True`. Both reach `While $bScriptRunning` and enter the monitoring loop body.
8. **Two concurrent monitoring loops are now running.** Both call `_KillProcessList()` and `_RunServiceBatchStop()` on their own timers, which are initialized independently.

**Consequence**: Two parallel instances of the monitoring loop run simultaneously. Each polls the service batch independently, so `_SM_StopServicesBatch` is called twice per cycle with no coordination. Both instances hold separate `$iLastStopServices` / `$iLastStopProcesses` timer values. The second instance will not terminate correctly either: when the first instance sets `$bScriptRunning = False` (via a later `Shift+F1`), both loops exit — but only by accident because they share the global flag. If the user presses `Shift+F1` an odd number of times rapidly, one loop may toggle the flag out of sync with the other.

**Root cause**: The guard variable `$bScriptRunning` is set *after* a yield point, not *before*. The correct fix would be to set `$bScriptRunning = True` as the first statement in the `Else` branch (before `MsgBox`), and `$bScriptRunning = False` as the first statement in the `If` branch (before `MsgBox`). This is a code change and is not made here — this document records the finding only.

**Additional observation — no spam guard**: There is no mechanism to prevent 10 rapid `Shift+F1` presses from queuing 10 invocations. Each press beyond the first is queued and will be delivered in turn at the next yield point inside `ToggleScript`. The `MsgBox` calls create a cascade: each invocation blocks, the next hotkey fires, another `MsgBox` appears, and so on. The user must dismiss (or wait out) up to N stacked dialogs.

---

## Issue 2: `_Exit()` — Hard `Exit` During Active Batch Stop

### Code (lines 632–636)

```autoit
Func _Exit()
    _LogMessage("Script termination requested", ...)
    _LogMessage("Script Was Terminated by _Exit()", ...)
    Exit
EndFunc
```

### Finding: DESIGN GAP — `Exit` can fire while `_SM_StopServicesBatch` holds open handles

**Delivery window**: `_Exit()` is registered as a hotkey (`ScrollLock+PAUSE`). It can fire at any `Sleep()` call. Inside `_SM_StopServicesBatch`, Phase 2 polls with `Sleep($iPollIntervalMs)` (500 ms by default). During that sleep, the `ScrollLock+PAUSE` hotkey is deliverable.

**What `_Exit` does**: Calls `Exit` unconditionally after two log writes. `Exit` terminates the AutoIt process immediately.

**What is left open**:
- `$hSCM` — the batch-scoped SCM handle opened by `OpenSCManagerW`, still open in `_SM_StopServicesBatch`.
- `$aPendingHnd[*]` — zero or more per-service handles opened by `OpenServiceW`, still in the pending list.

**Are these a real resource leak?** On Windows, all kernel handles owned by a process are closed by the OS when the process terminates. AutoIt's `Exit` triggers the normal process exit path, which causes the kernel to clean up all open `SC_HANDLE` values. The SCM and service handles will be released by the OS even without an explicit `CloseServiceHandle` call.

**Consequence in practice**: No handle leak persists after process exit. However:
1. Services in `STOP_PENDING` that were being polled lose their watcher. They will continue stopping (or timing out internally) on the OS side regardless — this is benign for stop operations.
2. If `Exit` fires between `ControlService` sending the stop command and the Phase 2 poll completing, the service will continue shutting down without the script's deadline enforcement. This is not harmful.
3. There is **no log entry** recording which services were mid-operation at exit time. The two log writes in `_Exit()` are generic. If a timed-out service is later found in a bad state, there is no audit trail.

**Verdict**: Not a handle leak bug due to OS cleanup guarantees. The gap is the absence of a log entry capturing the in-progress batch state at exit. This is a diagnostic gap, not a correctness bug.

---

## Issue 3: `LockProcessPriority` Re-entrancy While `_PriorityWatchdog` Is Executing

### Code — `LockProcessPriority` (lines 371–455)

The function collects PID and priority via two `InputBox` calls, performs validation, sets priority immediately, then appends to the three parallel global watchlist arrays (`$aPriorityWatchPIDs`, `$aPriorityWatchTargets`, `$aPriorityWatchNames`). It calls `AdlibRegister("_PriorityWatchdog", ...)` only when the array was previously empty.

### Code — `_PriorityWatchdog` (lines 462–511)

Iterates the same three global arrays backwards, using `_ArrayDelete` to remove dead PIDs, `ProcessSetPriority` to restore drifted priorities, and `AdlibUnRegister` when the array becomes empty.

### Finding: BUG — `_PriorityWatchdog` can interrupt `LockProcessPriority` mid-array-mutation

**Delivery window**: `LockProcessPriority` calls `InputBox` twice. Each `InputBox` is a yield point that can last seconds (waiting for user input). `_PriorityWatchdog` fires every 10 000 ms via `AdlibRegister` and will execute at any `Sleep()` or blocking call — including `InputBox`.

**Race scenario**:

1. `_PriorityWatchdog` has an active registration (at least one PID in the watchlist).
2. User invokes `LockProcessPriority` (Ctrl+Alt+Shift+9). The function passes PID validation and enters the priority `InputBox` (second dialog). The user has not dismissed it yet.
3. `_PriorityWatchdog` fires at the 10-second interval. Because `InputBox` is a yield point, the watchdog executes fully, iterating and potentially mutating `$aPriorityWatchPIDs`, `$aPriorityWatchTargets`, `$aPriorityWatchNames` via `_ArrayDelete` calls.
4. The watchdog completes. Control returns to `LockProcessPriority` at the point after `InputBox`.
5. `LockProcessPriority` reads `UBound($aPriorityWatchPIDs)` to decide whether to call `AdlibRegister` (`$bWasEmpty` check at line 446). But the watchdog may have removed the last PID from the array and already called `AdlibUnRegister`. The array size read by `LockProcessPriority` now reflects the post-watchdog state, not the pre-InputBox state.

**Consequence**:
- If the watchdog removed the last remaining PID (calling `AdlibUnRegister`) between the two `InputBox` calls, `$bWasEmpty` will be `True` at line 446, and `LockProcessPriority` will correctly call `AdlibRegister`. This case resolves correctly.
- If the watchdog removed some (but not all) PIDs between the two `InputBox` calls, `$bWasEmpty` remains `False`. `AdlibRegister` is not called — also correct.
- **The problematic case**: The watchdog fires *after* the PID existence check (`ProcessExists($iPID)` at line 433) and the priority set (`ProcessSetPriority` at line 439), but *before* the `_ArrayAdd` calls at lines 447–449. The PID is set successfully, but then the watchdog runs and finds the array in a consistent state (the new PID is not yet appended). No crash occurs, but the new PID misses this watchdog tick — it will be picked up on the next tick (10 seconds later). This is a timing gap, not a data corruption.
- **Array integrity**: `_ArrayDelete` and `_ArrayAdd` in AutoIt operate on the same global arrays. If `_PriorityWatchdog` calls `_ArrayDelete` on `$aPriorityWatchPIDs[$i]` while `LockProcessPriority` is about to call `_ArrayAdd($aPriorityWatchPIDs, $iPID)`, the final array state is correct — `_ArrayAdd` appends to whatever the array contains at the time it executes. No index corruption occurs because AutoIt is single-threaded; the two functions do not literally execute simultaneously.

**Verdict**: The re-entrancy is real (watchdog can run during InputBox), but the resulting array state is always self-consistent due to AutoIt's cooperative (non-preemptive) execution model. The worst observable outcome is a one-tick delay (10 seconds) before the newly added PID is first checked. This is a timing gap, not a data corruption bug. It should be documented as a known latency characteristic rather than treated as a correctness defect.

---

## Issue 4: `ToggleScript` Called While Already Running — `$bScriptRunning` Guard Ordering

This is an extension of Issue 1 focused specifically on the stop-side race.

**Stop-side sequence** (Shift+F1 pressed while monitoring loop is active):

1. `ToggleScript()` is entered. `$bScriptRunning` is `True`.
2. `If $bScriptRunning` branch: `_LogMessage` is called, then `MsgBox(..., 1)` with a 1-second auto-dismiss.
3. During that 1 second, the monitoring loop's `Sleep($MAIN_LOOP_SLEEP_MS)` is not running — `ToggleScript` is on the call stack. The monitoring loop **cannot advance** because AutoIt is single-threaded. This means the race described here is between the first `Shift+F1` callback and a *second* `Shift+F1` press, not between the callback and the loop itself.
4. If the user presses `Shift+F1` again during the 1-second `MsgBox`, a second invocation is queued. When `MsgBox` returns and the first invocation sets `$bScriptRunning = False`, the monitoring `While` loop exits and `ToggleScript` returns.
5. The second invocation then executes. `$bScriptRunning` is now `False`. It takes the `Else` branch, shows "Script started!", sets `$bScriptRunning = True`, and enters the monitoring loop again.

**Net effect of stop + immediate re-press**: The script toggles off and immediately back on. This is arguably correct behavior. But if the user presses stop, start, stop in rapid succession, the queued invocations can produce an inverted final state (script running when user expected it stopped).

---

## Issue 5: `LockProcessPriority` Called While Already in Progress

**Finding**: `LockProcessPriority` has no guard preventing a second invocation while the first is blocked in an `InputBox`. The user could press `Ctrl+Alt+Shift+9` a second time during the PID prompt, launching a second concurrent execution of `LockProcessPriority`. Both invocations would proceed through validation and independently append to the watchlist arrays. This is safe from a data corruption standpoint (the duplicate-PID check at lines 393–399 prevents the same PID from being added twice), but two stacked `InputBox` dialogs will appear, potentially confusing the user.

---

## Summary Table

| Issue | Hotkey | Scenario | Severity | Data Corrupt? | Handle Leak? |
|---|---|---|---|---|---|
| 1 | `Shift+F1` (`ToggleScript`) | Double-press during `MsgBox` yield | **High** — two concurrent monitoring loops | No (global flag is shared) | No |
| 2 | `ScrollLock+PAUSE` (`_Exit`) | `Exit` fires during batch stop Phase 2 `Sleep` | Low — OS cleans up handles | No | No (OS releases) |
| 3 | `Ctrl+Alt+Shift+9` (`LockProcessPriority`) | Watchdog fires during `InputBox` yield | Low — timing gap only | No | No |
| 4 | `Shift+F1` | Rapid stop+start produces inverted state | Medium — depends on press count parity | No | No |
| 5 | `Ctrl+Alt+Shift+9` | Double-press stacks two InputBox dialogs | Low — UI confusion only | No (dup-PID guard) | No |

---

## AutoIt Hotkey Behavior: Queued vs. Interrupt

To confirm: AutoIt hotkeys are **queued and delivered cooperatively**, not injected as interrupts. The key facts:

- A hotkey pressed while a callback (or the main loop) is executing between yield points is **queued**, not lost and not immediately injected.
- The queued hotkey fires at the **next yield point** reached by the running code — `Sleep()`, `MsgBox()`, `InputBox()`, `WinWait()`, etc.
- Once at a yield point, AutoIt can deliver multiple queued hotkeys in sequence. If `ToggleScript` is blocked in `MsgBox` and three `Shift+F1` presses are queued, all three will fire in sequence once `MsgBox` returns and successive yield points are reached.
- `AdlibRegister` callbacks share this same cooperative queue. `_PriorityWatchdog` fires at any yield point, interleaved with hotkey callbacks.

No notes in `CLAUDE.md` or any ADR describe a different model. ADR-0010 confirms the sleep-driven cooperative approach and explicitly states hotkeys are driven by the passive 50 ms loop.

---

## No Correct Test Seam Exists for These Bugs

The diagnosing-bugs skill (Phase 5) requirement: document if no correct seam exists. For all bugs described here, the failure modes require:

- Real AutoIt runtime execution on Windows (not available in this Linux sandbox).
- Real hotkey delivery timing (requires a human or a Windows-side automation tool).
- Multiple coordinated keypresses within specific timing windows.

A unit-level AutoIt test cannot replicate the concurrent `ToggleScript` double-activation because the test harness cannot inject a hotkey press during a `MsgBox` yield. The correct seam would be an integration test on a live Windows machine using `ControlSend` or AutoIt's own `Send()` function directed at the running script. This is an **Environment Gate** (see GLOSSARY.md) — the test harness is excluded from this environment.

The skill's Phase 1 feedback loop cannot be built in this environment. The findings are based on static code analysis of the cooperative execution model and the AutoIt hotkey delivery contract.
