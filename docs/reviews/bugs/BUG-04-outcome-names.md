# BUG-04: Outcome Constant Name/Value Mismatch

**Status:** Fixed
**Severity:** Medium — naming mismatch, no active silent bug at time of investigation, but a latent trap
**Date:** 2026-11-12
**Files owned:** `Includes/ServiceManager.au3`, `Stop Services Processes.au3`, `Tests/ServiceManager.Tests.au3`

---

## Summary

Two outcome constants had abbreviated names that did not match their string values:

| Old constant name     | String value       | Mismatch?                        |
|-----------------------|--------------------|----------------------------------|
| `$SM_OUTCOME_ALREADY` | `"ALREADY_STOPPED"` | Yes — name drops `_STOPPED`     |
| `$SM_OUTCOME_TIMEDOUT`| `"TIMED_OUT"`       | Yes — name runs words together, value uses underscore |
| `$SM_OUTCOME_STOPPED` | `"STOPPED"`         | No — name matches value exactly |
| `$SM_OUTCOME_FAILED`  | `"FAILED"`          | No — name matches value exactly |
| `$SM_OUTCOME_UNAVAILABLE` | `"UNAVAILABLE"` | No — name matches value exactly |

---

## Investigation

### Phase 1: Exact constant definitions (ServiceManager.au3 lines 55–59)

```autoit
Global Const $SM_OUTCOME_STOPPED        = "STOPPED"
Global Const $SM_OUTCOME_ALREADY        = "ALREADY_STOPPED"   ; ← abbreviated name
Global Const $SM_OUTCOME_UNAVAILABLE    = "UNAVAILABLE"
Global Const $SM_OUTCOME_FAILED         = "FAILED"
Global Const $SM_OUTCOME_TIMEDOUT       = "TIMED_OUT"          ; ← abbreviated name
```

### Phase 2: String literal comparisons in .au3 files

A full search across all `.au3` files for direct string comparisons (`"ALREADY"`, `"TIMEDOUT"`, `"TIMED_OUT"`, `"ALREADY_STOPPED"`) found no instances where code compared against those string literals directly instead of using the constants.

The only plain string occurrences of the values are:
- The constant definition lines themselves (lines 56 and 59).
- A documentation comment in the function header (line 128) listing outcome values.
- A comment on the `$SM_ERR_NOT_ACTIVE` error code constant explaining the mapping.

**Conclusion:** No silent comparison bug exists today — all comparisons use the constant, not the string. However, the mismatch is a maintenance hazard. A developer reading `$SM_OUTCOME_ALREADY` could reasonably guess its value is `"ALREADY"` and write a raw string comparison or log message incorrectly. Similarly, `$SM_OUTCOME_TIMEDOUT` looks like it should be `"TIMEDOUT"` (no underscore), but the actual value is `"TIMED_OUT"` (with underscore).

### Phase 3: _RunServiceBatchStop (Stop Services Processes.au3)

The `_RunServiceBatchStop` function uses a `Select / Case $sOutcome = $SM_OUTCOME_*` pattern throughout. It compares `$sOutcome` (extracted from the result array) against the constants, never against string literals. Safe.

```autoit
Case $sOutcome = $SM_OUTCOME_ALREADY    ; old name — now $SM_OUTCOME_ALREADY_STOPPED
Case $sOutcome = $SM_OUTCOME_TIMEDOUT   ; old name — now $SM_OUTCOME_TIMED_OUT
```

### Phase 4: Tests/ServiceManager.Tests.au3

All outcome assertions go through the constants:

```autoit
_TestAssert("win32 1062 → ALREADY_STOPPED", _SM_Win32ErrToOutcome(1062) = $SM_OUTCOME_ALREADY, ...)
_TestAssert("timed-out service: outcome = TIMED_OUT", $aResults[1][3] = $SM_OUTCOME_TIMEDOUT, ...)
```

No string literals used in comparisons. Safe, but names were inconsistent with values.

---

## Fix Applied

Renamed both constants to exactly mirror their string values:

| Old name              | New name                   | Value (unchanged)  |
|-----------------------|----------------------------|--------------------|
| `$SM_OUTCOME_ALREADY` | `$SM_OUTCOME_ALREADY_STOPPED` | `"ALREADY_STOPPED"` |
| `$SM_OUTCOME_TIMEDOUT`| `$SM_OUTCOME_TIMED_OUT`    | `"TIMED_OUT"`      |

All references updated across all three owned files. No string values were changed — this is a pure identifier rename.

### Files changed

| File | Occurrences updated |
|------|---------------------|
| `Includes/ServiceManager.au3` | 5 (definition + 4 usages) |
| `Stop Services Processes.au3` | 2 (in `_RunServiceBatchStop` `Select` block) |
| `Tests/ServiceManager.Tests.au3` | 4 (assertions in `_Test_Win32ErrToOutcome`, `_Test_SharedTimeout`, plus inline result construction) |

**Total: 11 identifiers renamed, 0 string values changed, 0 logic altered.**

### Post-fix verification

A regex search for `SM_OUTCOME_ALREADY[^_]` and `SM_OUTCOME_TIMEDOUT` across all `.au3` files returned no matches — the old names are fully removed from the codebase.

---

## Why no active bug

Every comparison in production code and in the test harness was already against the constant, not against the raw string. The mismatch was latent: the naming inconsistency was a readability and future-maintenance risk, not an active runtime defect. Any future developer using the constant name as a hint to construct a string literal (e.g. in a log parser or external tool) would have produced a wrong value.

---

## BackUp/ directory

Per `CLAUDE.md`, files in `BackUp/` are historical snapshots and are not edited. The old names remain in those snapshots, which is expected and correct — they are not part of the active codebase.
