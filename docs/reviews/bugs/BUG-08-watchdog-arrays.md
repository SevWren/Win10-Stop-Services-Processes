# BUG-08: Priority Watchdog Parallel Array Alignment

**File under review:** `Stop Services Processes.au3`
**Functions:** `LockProcessPriority` (lines 371–455), `_PriorityWatchdog` (lines 462–511)
**Severity:** Medium — data corruption possible under specific failure scenarios; not exploitable
but produces silent misrouting of watchdog actions.

---

## 1. Array Declarations

The three parallel arrays are declared at the global scope (lines 111–113):

```autoit
Global $aPriorityWatchPIDs[0]      ; PIDs under watchdog
Global $aPriorityWatchTargets[0]   ; corresponding target AutoIt priority constants (0–5)
Global $aPriorityWatchNames[0]     ; corresponding human-readable priority names
```

All three start empty (`[0]`). There is no fourth "size" variable; callers derive length
from `UBound($aPriorityWatchPIDs)` only.

---

## 2. Insertion Path — `LockProcessPriority` (Step 4, lines 446–451)

```autoit
Local $bWasEmpty = (UBound($aPriorityWatchPIDs) = 0)
_ArrayAdd($aPriorityWatchPIDs, $iPID)
_ArrayAdd($aPriorityWatchTargets, $iPriorityConst)
_ArrayAdd($aPriorityWatchNames, $sPriorityName)

If $bWasEmpty Then AdlibRegister("_PriorityWatchdog", $PRIORITY_WATCHDOG_MS)
```

### Finding 2a — _ArrayAdd failure behavior creates a confirmed desync bug

`_ArrayAdd` in AutoIt's standard `Array.au3` resizes the array and appends the value.
On failure (e.g., memory allocation failure) it sets `@error = 1` and returns `-1`
**without modifying the array**. The insertion code does not check `@error` after any of
the three `_ArrayAdd` calls.

If `_ArrayAdd` succeeds for `$aPriorityWatchPIDs` but fails for `$aPriorityWatchTargets`
or `$aPriorityWatchNames`, the arrays diverge: the PID array has N+1 elements but one or
both of the other arrays still has N elements. All subsequent index-parallel reads in
`_PriorityWatchdog` will be off by one for the new entry.

**This is a real bug.** `_ArrayAdd` failure is rare (requires memory pressure) but
the code provides no guard. Each call must be checked independently because there is no
atomic "append to all three" primitive.

### Finding 2b — `AdlibRegister` guard is correct

`$bWasEmpty` is captured before any `_ArrayAdd` call. If `_ArrayAdd` fails on the first
array and the arrays were previously empty, `$bWasEmpty` is `True` and
`AdlibRegister` is called. The watchdog will then fire with one array at size 1 and the
others still at size 0, compounding the desync. However, the guard itself correctly
avoids registering a duplicate Adlib callback — the design intent is correct; it is the
missing `@error` checks that break it.

---

## 3. Deletion Path — `_PriorityWatchdog` (lines 464–505)

The watchdog iterates **backwards** (`Step -1`), which is the standard safe pattern for
in-place deletion using index-based `_ArrayDelete`. Two deletion sites exist:

**Site A — dead PID (lines 470–475):**
```autoit
_ArrayDelete($aPriorityWatchPIDs, $i)
_ArrayDelete($aPriorityWatchTargets, $i)
_ArrayDelete($aPriorityWatchNames, $i)
```

**Site B — TOCTOU exit during drift restore (lines 490–495):**
```autoit
_ArrayDelete($aPriorityWatchPIDs, $i)
_ArrayDelete($aPriorityWatchTargets, $i)
_ArrayDelete($aPriorityWatchNames, $i)
```

### Finding 3a — All three arrays deleted with the same index at both sites

Both deletion sites call `_ArrayDelete` on all three arrays with the identical index `$i`
in immediate succession, with no intervening code that could alter any array. This is
correct.

### Finding 3b — `_ArrayDelete` failure is also unchecked

`_ArrayDelete` sets `@error = 1` if the index is out of range. Because the arrays are
supposed to be in sync, an out-of-range index on one would be out-of-range on all three.
The unchecked failure is therefore symmetric: if the arrays are already desynced (from
Finding 2a) a deletion at a valid index on the larger array would be an invalid index on
the shorter arrays. The first `_ArrayDelete` at that invalid index would no-op and set
`@error`, while the subsequent calls receive the original index unchanged (AutoIt does not
propagate the error as an exception). The result is a partial deletion: one array shrinks
by one, the others do not, further widening the desync.

### Finding 3c — Backwards iteration is correct and there is no off-by-one

`UBound($aPriorityWatchPIDs) - 1 To 0 Step -1` is the correct upper bound for a 0-based
array. Because iteration goes from high to low, deleting at index `$i` only shifts
elements at indices `> $i`, which are already processed. No unprocessed entry is skipped.
No off-by-one is present in the loop bounds or the deletion pattern itself.

---

## 4. UBound Parity Check

There is no assertion or guard anywhere in the code that verifies
`UBound($aPriorityWatchPIDs) = UBound($aPriorityWatchTargets)`
`= UBound($aPriorityWatchNames)` before reading parallel indices.
Every read in `_PriorityWatchdog` (lines 465–467) silently assumes the arrays are in
sync. If they have drifted, reads against the shorter array at an index beyond its last
element return an empty string in AutoIt (no out-of-bounds exception), so the bug would
manifest as:

- A watched PID being checked but `$iPriorityConst` resolving to `""` (treated as `0`
  by `ProcessSetPriority`, i.e., Idle priority), causing a spurious restore to Idle.
- A watched PID being checked but `$sPriorityName` resolving to `""`, producing
  misleading log entries.

Neither condition triggers any visible error; both produce silent misbehavior.

---

## 5. Summary of Findings

| # | Location | Finding | Bug? |
|---|----------|---------|------|
| 2a | `LockProcessPriority` lines 447–449 | `@error` from each `_ArrayAdd` is not checked; a failure on any one array desyncs all three | **Yes — confirmed bug** |
| 2b | `LockProcessPriority` line 446 | `$bWasEmpty` capture before `_ArrayAdd` is correct in intent but worsens 2a if first `_ArrayAdd` fails on empty arrays | Latent aggravation of 2a |
| 3a | `_PriorityWatchdog` both deletion sites | All three arrays deleted with same index atomically — correct | No bug |
| 3b | `_PriorityWatchdog` both deletion sites | `@error` from `_ArrayDelete` unchecked; on desynced arrays causes asymmetric partial deletion | **Yes — consequential bug downstream of 2a** |
| 3c | `_PriorityWatchdog` loop bounds | Backwards iteration with `UBound - 1 To 0 Step -1` is correct; no off-by-one | No bug |
| 4  | `_PriorityWatchdog` lines 465–467 | No parity check on three array sizes before parallel read; AutoIt silently returns `""` for out-of-range, causing silent wrong-priority restores | No crash, but silent misbehavior when 2a triggers |

---

## 6. Root Cause Statement

The root cause is that the three parallel arrays have no encapsulation — they are
individual globals mutated by ad-hoc sequential calls to `_ArrayAdd`/`_ArrayDelete`.
AutoIt provides no atomic multi-array append. The insertion code does not check `@error`
after each `_ArrayAdd`, so a mid-sequence failure leaves the arrays at different sizes.
All subsequent operations silently assume size parity.

---

## 7. Notes on Feedback Loop (Skill Phase 1)

The Environment Gate (Windows AutoIt runtime required) prevents building an automated
red/green loop in this sandbox. A feedback loop would require:

1. A Windows machine with AutoIt 3.3.16.1.
2. A test harness that stubs `_ArrayAdd` to simulate a failure after the first call and
   then asserts `UBound($aPriorityWatchPIDs) = UBound($aPriorityWatchTargets)`.
3. A subsequent call into `_PriorityWatchdog` with a live (or stubbed) PID to observe the
   wrong-priority restore.

The absence of a runnable loop is documented per SKILL.md Phase 1 requirements. The
findings above are based on static analysis of the source.

---

## 8. Fix Recommendation (no code changes in this review)

The fix should check `@error` after each `_ArrayAdd` and roll back the preceding
successful adds if any subsequent one fails, or abort `LockProcessPriority` and notify
the user. A single-struct array (one array of records) would eliminate the class of bug
entirely, but that is an architectural change. At minimum, `@error` guards with symmetric
rollback are required at the insertion site.
