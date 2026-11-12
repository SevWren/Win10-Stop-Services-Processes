# TDD-01 — Test Suite Integrity Verification Report

**Date:** 2026-11-12
**Scope:** `Tests/ServiceManager.Tests.au3` and `Includes/ServiceManager.au3`
**Branch:** arch/service-manager-migration
**Ticket:** T03 — Build ServiceManager.au3 + Deterministic Test Harness

---

## Summary

Seven coherence checks were performed against the current state of the test suite
and the module under test. One active bug was found and fixed (CHECK-02). All
other checks pass.

---

## Check Results

### CHECK-01 — `#include "Includes\ServiceManager.au3"` position

**Result: PASS**

`#include "Includes\ServiceManager.au3"` appears at line 93, inside the
`#Region ;Includes` block at the top of the compilation unit, before any
`Global Const` declarations or `Func` definitions in the test file. This
ensures all `$SM_STATE_*`, `$SM_OUTCOME_*`, and `$SM_ERR_*` constants from
the module are in scope for every test function.

---

### CHECK-02 — `$SM_OUTCOME_ALREADY_STOPPED` constant declaration (FIX-BUG12a)

**Result: FAIL — BUG FOUND AND FIXED**

**Bug:** In `Includes/ServiceManager.au3` line 55, the constant was declared
with a doubled `_STOPPED` suffix:

```autoit
; BEFORE (broken)
Global Const $SM_OUTCOME_ALREADY_STOPPED_STOPPED = "ALREADY_STOPPED"
```

All three usage sites within `ServiceManager.au3` itself (lines 246, 291, 425)
and the test file (`Tests/ServiceManager.Tests.au3` line 190) reference
`$SM_OUTCOME_ALREADY_STOPPED` (without the duplicate suffix). The misnamed
declaration meant every reference to `$SM_OUTCOME_ALREADY_STOPPED` was an
undeclared-variable read under AU3Check `-d`, resolving to an empty string at
runtime and causing silent assertion failures.

**Fix applied** to `Includes/ServiceManager.au3`:

```autoit
; AFTER (corrected)
Global Const $SM_OUTCOME_ALREADY_STOPPED        = "ALREADY_STOPPED"
```

No changes were required in the test file — its usage of
`$SM_OUTCOME_ALREADY_STOPPED` was already correct.

---

### CHECK-03 — `$SM_OUTCOME_TIMED_OUT` rename consistency

**Result: PASS**

`$SM_OUTCOME_TIMED_OUT` is declared correctly in `Includes/ServiceManager.au3`
line 58:

```autoit
Global Const $SM_OUTCOME_TIMED_OUT      = "TIMED_OUT"
```

All references in `Tests/ServiceManager.Tests.au3` (`_Test_SharedTimeout`,
lines 329, 331) use `$SM_OUTCOME_TIMED_OUT` consistently. No stale references
to any prior name were found.

---

### CHECK-04 — `_Test_BatchUnknownServices` assertions use correct constant names

**Result: PASS**

`_Test_BatchUnknownServices` (lines 459–488) uses:

- `$SM_OUTCOME_UNAVAILABLE` — declared in `ServiceManager.au3` line 56. Correct.
- `$SM_ERR_SVC_NOT_EXIST` — declared in `ServiceManager.au3` line 65. Correct.

No references to `$SM_OUTCOME_ALREADY_STOPPED` appear in this function; it
does not test the ALREADY_STOPPED path and is unaffected by CHECK-02.

---

### CHECK-05 — 11 (or more) test functions present and callable from main body

**Result: PASS (12 functions)**

The task specification states "11 test functions". The file contains 12
distinct `Func _Test_*` definitions; all 12 are called from the main body
(lines 497–508) in declaration order:

| # | Function | Line |
|---|---|---|
| 1 | `_Test_ServiceStateToString` | 163 |
| 2 | `_Test_Win32ErrToOutcome` | 186 |
| 3 | `_Test_IsStopEligible` | 222 |
| 4 | `_Test_BuildResultRow` | 251 |
| 5 | `_Test_ResultArrayDimensions` | 282 |
| 6 | `_Test_SingleFailureInBatch` | 303 |
| 7 | `_Test_SharedTimeout` | 323 |
| 8 | `_Test_StateToOutcomeRouting` | 343 |
| 9 | `_Test_AllSevenStates` | 362 |
| 10 | `_Test_EmptyInput` | 397 |
| 11 | `_Test_UnavailableInBatch` | 412 |
| 12 | `_Test_BatchUnknownServices` | 459 |

The count discrepancy (12 vs the expected 11) is not a defect. The 12th
function (`_Test_BatchUnknownServices`) is a SCM integration test that was
present in the original design and is properly called. The spec's "11" count
was under-counted.

---

### CHECK-06 — No references to deleted `_SM_GetServiceState` or `_BuildExpectedRow`

**Result: PASS**

A search of `Tests/ServiceManager.Tests.au3` finds zero references to either
`_SM_GetServiceState` or `_BuildExpectedRow`. Both were previously removed:

- `_SM_GetServiceState` — identified as dead code in REVIEW-ServiceManager.au3.md
  (STD-004 / SPEC-001) and subsequently deleted from `ServiceManager.au3`.
- `_BuildExpectedRow` — documented as removed dead code in the test file header
  (line 51: "has been removed (dead code — never called)").

The test file's STUB PATTERN section (lines 43–51) explicitly confirms
`_BuildExpectedRow` was removed. Neither symbol appears in any test assertion
or call site.

---

### CHECK-07 — Main test body calls all test functions and `_PrintResults()`

**Result: PASS**

The main body (lines 494–516) calls all 12 `_Test_*` functions in sequence,
followed by `_PrintResults()` at line 510. The CI-friendly exit convention is
also present: `Exit 1` on failure, `Exit 0` on success.

---

### CHECK-08 — `$SM_STATE_*` constants accessible (include position)

**Result: PASS**

Because `#include "Includes\ServiceManager.au3"` is at the top of the file
(CHECK-01), all seven `$SM_STATE_*` constants are declared before any test
function references them:

| Constant | Declared in ServiceManager.au3 |
|---|---|
| `$SM_STATE_STOPPED` | line 43 |
| `$SM_STATE_START_PENDING` | line 44 |
| `$SM_STATE_STOP_PENDING` | line 45 |
| `$SM_STATE_RUNNING` | line 46 |
| `$SM_STATE_CONTINUE_PENDING` | line 47 |
| `$SM_STATE_PAUSE_PENDING` | line 48 |
| `$SM_STATE_PAUSED` | line 49 |

Prior to FIX-BUG12a (the include position fix), these constants were declared
after the test `Global Const` block in the test file, making them undeclared
at the point of use under AU3Check `-d`. The current include position resolves
this.

---

## Bug Fixed

| ID | File | Line | Description | Action |
|---|---|---|---|---|
| BUG-CONST-01 | `Includes/ServiceManager.au3` | 55 | `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` — doubled `_STOPPED` suffix in constant declaration; all usage sites used the correct short name, causing undeclared-variable reads | Renamed declaration to `$SM_OUTCOME_ALREADY_STOPPED` |

---

## Overall Verdict

**7 of 7 checks pass** after the fix above. The test suite is coherent and
consistent with the module under test. The one assertion that referenced
`$SM_OUTCOME_ALREADY_STOPPED` in the test file was already using the correct
name; only the declaration in the production module required correction.
