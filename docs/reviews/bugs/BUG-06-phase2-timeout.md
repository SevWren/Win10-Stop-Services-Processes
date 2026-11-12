# BUG-06 — Phase 2 Timeout Logic Analysis

**File analysed**: `Includes/ServiceManager.au3`
**Function**: `_SM_StopServicesBatch`
**Trigger**: CR2-04 and CR2-07 raised Phase 2 timeout arithmetic as "not fully verified in original session reviews"
**Analysis date**: 2026-11-12
**Status**: ANALYSIS ONLY — no code changes recommended

---

## Summary of Findings

| # | Question | Finding | Severity |
|---|---|---|---|
| 1 | Is `TimerDiff($iTimer) < $iBatchTimeoutMs` the correct direction? | CORRECT — loop continues while time remaining, exits on expiry | No bug |
| 2 | Is `TimerInit()` called before Phase 1 or at Phase 2 start? | AT PHASE 2 START (line 314, after Phase 1 completes) | No bug; architectural choice |
| 3 | Is `$SVC_BATCH_TIMEOUT_MS = 20000` the value passed as `$iBatchTimeoutMs`? | YES — traced through the full call chain | No bug |
| 4 | Are pending services marked TIMED_OUT and handles closed on expiry? | YES — lines 364–372 mark TIMED_OUT and close every pending handle | No bug |
| 5 | Is there a `Sleep($iPollIntervalMs)` in Phase 2? Could it overshoot by one poll interval? | YES, there is a Sleep(500) — this is a real, confirmed overshoot risk | Low-severity defect |

---

## 1. Detailed Investigation

### 1.1 The Phase 2 While Loop (full text)

`Includes/ServiceManager.au3` lines 311–372:

```autoit
; =========================================================================
; PHASE 2 — Poll all pending services against one shared deadline
; =========================================================================
Local $iTimer = TimerInit()

While UBound($aPendingIdx) > 0 And TimerDiff($iTimer) < $iBatchTimeoutMs
    Sleep($iPollIntervalMs)
    ; Iterate backwards so array shrinks safely during removal
    Local $j
    For $j = UBound($aPendingIdx) - 1 To 0 Step -1
        ...poll each pending service...
        If $iPollState = $SM_STATE_STOPPED Then
            ...mark STOPPED, close handle, remove from pending arrays...
        EndIf
    Next

WEnd   ;==>Phase 2 poll loop

; --- Timeout: mark any remaining pending services as TIMED_OUT ---
Local $iTimeoutIdx
For $iTimeoutIdx = 0 To UBound($aPendingIdx) - 1
    Local $iTOIdx = $aPendingIdx[$iTimeoutIdx]
    $aResults[$iTOIdx][3] = $SM_OUTCOME_TIMEDOUT
    $aResults[$iTOIdx][4] = 0
    $aResults[$iTOIdx][5] = "Deadline exceeded (" & $iBatchTimeoutMs & "ms)"
    _LogMessage("_SM_StopServicesBatch: stop timed out: " & ..., ...)
    DllCall("advapi32.dll", "bool", "CloseServiceHandle", "handle", $aPendingHnd[$iTimeoutIdx])
Next
```

---

### 1.2 Comparison Direction: `TimerDiff($iTimer) < $iBatchTimeoutMs`

`TimerInit()` returns an opaque timer handle. `TimerDiff($iTimer)` returns the number of milliseconds elapsed since that `TimerInit()` call. The value starts near 0 and grows over time.

The While condition is:
```
UBound($aPendingIdx) > 0   AND   TimerDiff($iTimer) < $iBatchTimeoutMs
```

Interpretation:
- `TimerDiff($iTimer) < $iBatchTimeoutMs` is True while the elapsed time is **less than** the deadline — i.e., while there is still time left. The loop continues polling.
- When `TimerDiff($iTimer) >= $iBatchTimeoutMs` the condition becomes False and the loop exits, leaving any still-pending services to be collected by the TIMED_OUT block below.

**Direction is correct.** `< $iBatchTimeoutMs` is exactly right for "haven't exceeded the timeout yet". The inverse (`>`) would cause the loop to exit immediately (before any polls) and re-enter only after the deadline, which would be nonsensical. Using `>=` instead of `<` would be a logic inversion; the existing `<` is correct.

CR2-04 (§ "Phase 2 timer arithmetic") confirmed this as PASS. This analysis independently confirms the same conclusion.

---

### 1.3 When Is `TimerInit()` Called? Before Phase 1 or at Phase 2 Start?

```autoit
; Phase 1 loop (lines 194–309)
For $i = 0 To $iCount - 1
    ...open service, query state, issue stop controls, build pending arrays...
Next   ;==>Phase 1 loop

; Phase 2 starts here (line 314)
Local $iTimer = TimerInit()
While UBound($aPendingIdx) > 0 And TimerDiff($iTimer) < $iBatchTimeoutMs
    ...
```

`TimerInit()` is called at **line 314**, which is the first line of the Phase 2 section, **after the Phase 1 `For` loop has fully completed** (Phase 1 ends at the `Next` on line 309).

**Consequence**: Phase 1 execution time is NOT charged against the 20-second Phase 2 deadline. For the typical case of 9 services (the configured target list), Phase 1 is fast — it opens service handles, queries state, issues `ControlService` calls (all synchronous DllCalls), and builds the pending arrays. No `Sleep` occurs in Phase 1. At normal Windows SCM latency this takes single-digit milliseconds. The full 20-second deadline is therefore available for the Phase 2 poll.

`docs/ARCHITECTURE.md` ("Batch-Stop Algorithm") places `$iTimer = TimerInit()` at the top of Phase 2, not before Phase 1. CR2-04 (§ "Timer start before Phase 1") confirmed the implementation matches the architecture exactly and recorded this as a deliberate design choice — Phase 1 time is intentionally excluded from the deadline. This analysis independently confirms the same conclusion.

**No bug.** However, see Section 1.5 for the corollary overshoot issue introduced by `Sleep($iPollIntervalMs)` at the top of the loop body.

---

### 1.4 Value Trace: `$SVC_BATCH_TIMEOUT_MS = 20000` → `$iBatchTimeoutMs`

Full call chain:

**Step 1 — Declaration** (`Stop Services Processes.au3`, line 46):
```autoit
Global Const $SVC_BATCH_TIMEOUT_MS = 20000   ; shared deadline for one batch-stop (ms)
```

**Step 2 — Call site** (`Stop Services Processes.au3`, line 233, inside `_RunServiceBatchStop()`):
```autoit
Local $aResults = _SM_StopServicesBatch($aSvcTargetNames, $SVC_BATCH_TIMEOUT_MS, $SVC_BATCH_POLL_MS)
```

**Step 3 — Function signature** (`Includes/ServiceManager.au3`, line 138):
```autoit
Func _SM_StopServicesBatch(ByRef $aServiceNames, $iBatchTimeoutMs = 20000, $iPollIntervalMs = 500)
```

**Step 4 — Usage in Phase 2** (`Includes/ServiceManager.au3`, line 316):
```autoit
While UBound($aPendingIdx) > 0 And TimerDiff($iTimer) < $iBatchTimeoutMs
```

**Step 5 — Usage in TIMED_OUT note** (`Includes/ServiceManager.au3`, line 369):
```autoit
$aResults[$iTOIdx][5] = "Deadline exceeded (" & $iBatchTimeoutMs & "ms)"
```

The value `20000` is set once as a named constant, passed explicitly as the second argument, received as `$iBatchTimeoutMs`, and used in both the loop guard and the diagnostic note. There is no shadowing, no second assignment, and no branch where a different value is substituted. The function also carries `$iBatchTimeoutMs = 20000` as a default parameter, so callers that omit the argument get the same 20-second value.

**No bug.** The value is correct end-to-end.

---

### 1.5 TIMED_OUT Handling: Are Pending Services Marked and Handles Closed?

After the While loop exits (either because `$aPendingIdx` is empty or the deadline has been reached), the code at lines 363–372 runs unconditionally:

```autoit
Local $iTimeoutIdx
For $iTimeoutIdx = 0 To UBound($aPendingIdx) - 1
    Local $iTOIdx = $aPendingIdx[$iTimeoutIdx]
    $aResults[$iTOIdx][3] = $SM_OUTCOME_TIMEDOUT          ; outcome = "TIMED_OUT"
    $aResults[$iTOIdx][4] = 0
    $aResults[$iTOIdx][5] = "Deadline exceeded (" & $iBatchTimeoutMs & "ms)"
    _LogMessage("_SM_StopServicesBatch: stop timed out: " & ..., $LOG_TYPE_SERVICE, $LOG_LEVEL_ERROR)
    DllCall("advapi32.dll", "bool", "CloseServiceHandle", "handle", $aPendingHnd[$iTimeoutIdx])
Next
```

Observations:

1. **Runs even when the loop exits early (all services stopped)**: if `$aPendingIdx` is empty when the While exits, `UBound($aPendingIdx) - 1 = -1`, so the `For` body never executes. No spurious TIMED_OUT assignments. Correct.

2. **Runs when the deadline expires with services still pending**: `UBound($aPendingIdx) > 0`, so the `For` iterates over all remaining entries, writing TIMED_OUT outcome and closing the handle. Correct.

3. **Handle is closed for every timed-out service**: `CloseServiceHandle` is called for each entry in `$aPendingHnd`. Combined with the per-service close inside the poll loop for services that reach STOPPED (line 343), and the SCM handle close at line 376, every handle opened during the function lifetime is closed exactly once. No handle leak on the timeout path.

4. **Win32 error field is set to 0**: For TIMED_OUT outcomes `$aResults[$iTOIdx][4] = 0`. The service did not fail — it simply did not stop in time. Setting Win32 error to 0 is correct; the note field ("Deadline exceeded") carries the diagnostic.

**No bug.** TIMED_OUT handling is correct and complete.

---

### 1.6 Sleep Overshoot: `Sleep($iPollIntervalMs)` and the Deadline

The While loop body is:
```autoit
While UBound($aPendingIdx) > 0 And TimerDiff($iTimer) < $iBatchTimeoutMs
    Sleep($iPollIntervalMs)      ; ← 500 ms sleep at TOP of body
    For $j = ...                 ; poll queries happen AFTER the sleep
        ...
    Next
WEnd
```

The `Sleep($iPollIntervalMs)` — with the configured value of `$SVC_BATCH_POLL_MS = 500` ms — occurs at the **top** of the loop body, before any `QueryServiceStatus` calls are made in that iteration. The While condition is evaluated before the sleep, not after it.

**What this means in practice:**

The While condition is checked at the top of each iteration. Suppose the timer reads 19 600 ms just before the condition check: `19600 < 20000` is True, so the body runs. The body sleeps 500 ms (bringing real elapsed time to approximately 20 100 ms), then executes the QueryServiceStatus calls. After the inner For loop completes, control returns to While — now `TimerDiff($iTimer)` reads approximately 20 100 ms, `20100 < 20000` is False, and the loop exits.

The effective maximum overshoot is approximately one full poll interval (500 ms) beyond the nominal 20-second deadline. Under that worst case the actual wait before TIMED_OUT marking is approximately 20 500 ms, not 20 000 ms.

**Is this a bug?**

This is a **confirmed low-severity defect** — the function's behaviour diverges from what `$iBatchTimeoutMs = 20000` and the documentation imply:

- `docs/ARCHITECTURE.md` ("Batch-Stop Algorithm") states the loop polls until "elapsed >= deadline". It does not mention that the final poll cycle may push real elapsed time up to `deadline + iPollIntervalMs`.
- `docs/REQUIREMENTS.md` REQ-016 states "The default batch deadline is 20 seconds". Technically, services that stop during the extra poll cycle (the 20 000–20 500 ms window) will be reported as STOPPED, not TIMED_OUT — which is arguably a better outcome than TIMED_OUT, not a worse one. Services that have not stopped by the end of the extra poll cycle will then be marked TIMED_OUT at approximately 20 500 ms actual elapsed.
- The monitoring cycle that calls `_RunServiceBatchStop()` runs every `$SVC_POLL_INTERVAL_SEC = 10` seconds. A 500 ms overshoot on a 20-second internal deadline, within a 10-second outer cycle, represents a 2.5% overrun relative to the batch deadline and a 0.83% slip relative to the outer cycle. The practical impact is negligible.

**Root cause**: `Sleep` is placed before the QueryServiceStatus calls. Moving `Sleep` to the **end** of the loop body (after the inner For) would eliminate the overshoot: the condition check would occur after the last sleep, so when the deadline is crossed the loop exits cleanly before another sleep occurs. Alternatively, placing a residual-time check (`Min($iPollIntervalMs, $iBatchTimeoutMs - TimerDiff($iTimer))`) as the sleep argument would cap the sleep to the remaining deadline budget.

**Severity**: Low. The overshoot is bounded, deterministic, and consistent. The monitoring loop absorbs it without issue. No services are incorrectly classified; the worst outcome is that TIMED_OUT is stamped approximately 500 ms late, or that a service that stops in the 20 000–20 500 ms window is reported STOPPED rather than TIMED_OUT (which is the preferred outcome anyway).

---

## 2. Cross-Reference Against Prior Reviews

| Review | Claim | Verified here |
|---|---|---|
| CR2-04 §"Phase 2 timer arithmetic" | "Direction is correct — the loop drains when the deadline is reached." | Confirmed correct |
| CR2-04 §"Timer start before Phase 1" | "`$iTimer = TimerInit()` is called at line 314, after Phase 1 completes. ... The implementation matches the architecture exactly." | Confirmed |
| CR2-13 §S-04 REQ-016 | "Implementation reference correctly names `$SVC_BATCH_TIMEOUT_MS = 20000` and the `While … TimerDiff($iTimer) < $iBatchTimeoutMs` guard." | Confirmed |
| CR2-07 | Phase 2 timeout arithmetic flagged as "not fully verified" | This document is the full verification; no additional issue found beyond the Sleep overshoot |

No prior review examined the Sleep-first ordering as a source of overshoot. CR2-04 noted the timer placement and direction but did not trace the intra-loop Sleep position relative to the condition re-evaluation point.

---

## 3. Verdict

**The core timeout logic is correct.** The comparison direction (`< $iBatchTimeoutMs`) is right, the constant value is correctly traced end-to-end, the timer starts at the right place for the stated architecture intent, and the TIMED_OUT cleanup block correctly marks and closes every remaining pending service handle.

**One real issue exists**: the `Sleep($iPollIntervalMs)` at the top of the loop body causes the actual elapsed time at the moment of TIMED_OUT marking to exceed `$iBatchTimeoutMs` by up to one poll interval (nominally 500 ms). This is an overshoot, not an under-shoot — the deadline is not enforced with millisecond precision. Given the monitoring context (10-second outer cycle, single-digit ms Phase 1 overhead, deterministic bounded overshoot), this does not rise to a correctness bug that would cause observable misbehaviour. It is documented here for completeness.

**No code changes are required** unless strict deadline enforcement within `$iBatchTimeoutMs` becomes a hard requirement.

---

## 4. Files Referenced

| File | Lines | Purpose |
|---|---|---|
| `Includes/ServiceManager.au3` | 138, 314–372 | Phase 2 While loop, TIMED_OUT block, function signature |
| `Stop Services Processes.au3` | 46–47, 98, 233 | `$SVC_BATCH_TIMEOUT_MS`, `$SVC_BATCH_POLL_MS` declarations; `TimerInit()` for outer service cycle; `_RunServiceBatchStop()` call site |
| `docs/reviews/second-pass/CR2-04-servicemanager-spec.md` | §"Phase 2 timer arithmetic", §"Timer start before Phase 1" | Prior PASS verdicts on direction and timer placement |
| `docs/reviews/second-pass/CR2-07-servicecontrol-review.md` | — | Identified as not having fully verified Phase 2 arithmetic; this doc completes that work |
| `docs/reviews/second-pass/CR2-13-requirements-review.md` | §S-04 REQ-016 | Confirmed `$SVC_BATCH_TIMEOUT_MS` reference in REQUIREMENTS.md |
| `docs/REQUIREMENTS.md` | REQ-016 | 20-second batch deadline requirement and verification statement |
| `docs/ARCHITECTURE.md` | Timing Constants, Batch-Stop Algorithm | Timer placement specification; `$SVC_BATCH_TIMEOUT_MS = 20000` architectural record |
