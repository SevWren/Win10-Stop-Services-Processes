# CR3-03: Code Review — Tests/ServiceManager.Tests.au3

**Fixed point:** `c113a6f`
**HEAD commit:** `de1353e`
**File scope:** `Tests/ServiceManager.Tests.au3` only
**Spec sources:** `docs/reviews/bugs/BUG-12-au3check-simulation.md`, `docs/reviews/bugs/BUG-04-outcome-names.md`
**Standards source:** `CODING_STANDARDS.md`
**Date:** 2026-11-12

---

## Standards

### S-01 — `#include` position: PASS with observation

BUG-12 required moving `#include "Includes\ServiceManager.au3"` from line 500 (after all `Func` definitions) to the top of the file so AU3Check can resolve `$SM_*` constants when it processes function bodies.

**Current state:** The include now appears inside `#Region ;Includes` at line 93, between `#include <MsgBoxConstants.au3>` and `#EndRegion`. It is before all `Global Const` declarations (lines 97–104) and before all `Func` definitions. This fully satisfies the BUG-12 requirement.

**CODING_STANDARDS.md — Duplicate Prevention** states: "No `#include` directive may appear twice in the same file." The diff confirms the bottom-of-file `#include "Includes\ServiceManager.au3"` (old line 500) was removed. Only one include of `ServiceManager.au3` exists in the file. No violation.

**Observation — region label missing closing tag match:** The `#Region ;Includes` block at line 90 closes with `#EndRegion` at line 94 (no label on the closing tag). CODING_STANDARDS.md §Region Structure requires: "All `#Region` / `#EndRegion` blocks must carry a matching label on both the opening and closing tag." The correct form is `#EndRegion ;Includes`. This is a standards violation inherited from the pre-fix file; the diff did not introduce it, but it was not corrected by this change. **Hard violation — existing, not introduced by this diff.**

### S-02 — Stale deferred-include comment: PASS

BUG-12's pre-fix state included a comment block explaining the deferred include rationale (lines 96–99 of the old file, text beginning "Service state and outcome constants are defined in ServiceManager.au3. They are NOT redeclared here to avoid Global Const redefinition conflicts…"). The diff removes this comment in its entirety. No residual stale text about the deferred include pattern remains in the file. PASS.

### S-03 — BUG-04 rename in test file — `$SM_OUTCOME_ALREADY_STOPPED`: PARTIAL PASS / BLOCKER IN DEPENDENCY

BUG-04 renamed `$SM_OUTCOME_ALREADY` → `$SM_OUTCOME_ALREADY_STOPPED` and `$SM_OUTCOME_TIMEDOUT` → `$SM_OUTCOME_TIMED_OUT`. The test file has four usage sites identified in BUG-04 §Files changed.

**`$SM_OUTCOME_ALREADY_STOPPED` — test file usage sites (all 4 expected):**

| Line | Context | Renamed? |
|------|---------|----------|
| 190 | `_TestAssert("win32 1062 → ALREADY_STOPPED", ... = $SM_OUTCOME_ALREADY_STOPPED, $SM_OUTCOME_ALREADY_STOPPED, ...)` | Yes |
| (no additional `$SM_OUTCOME_ALREADY` or `$SM_OUTCOME_ALREADY_STOPPED` usage sites exist in the test file beyond line 190) | | |

Grep across the test file for the old name `$SM_OUTCOME_ALREADY[^_]` returns zero matches. The old name is fully gone from the test file. PASS for the test file side.

**`$SM_OUTCOME_TIMED_OUT` — test file usage sites:**

| Line | Context | Renamed? |
|------|---------|----------|
| 329 | `$aResults[1][3] = $SM_OUTCOME_TIMED_OUT` (assignment in simulation) | Yes |
| 331 | `$aResults[1][3] = $SM_OUTCOME_TIMED_OUT` (assertion comparison) | Yes |
| 331 | `$SM_OUTCOME_TIMED_OUT` (expected string arg to `_TestAssert`) | Yes |

Old name `$SM_OUTCOME_TIMEDOUT` returns zero matches in the test file. PASS for the test file side.

**BUG-04 count vs. diff:** BUG-04 §Files changed states "Tests/ServiceManager.Tests.au3 — 4 occurrences updated." The diff shows two hunks touching the test file for outcome renames: one replacing `$SM_OUTCOME_ALREADY` with `$SM_OUTCOME_ALREADY_STOPPED` (1 occurrence), and one replacing two occurrences of `$SM_OUTCOME_TIMEDOUT` with `$SM_OUTCOME_TIMED_OUT` (2 occurrences). That is 3 occurrences in the diff. BUG-04 claims 4. The discrepancy is explained by counting each argument position separately — line 190 has two positions (`= $SM_OUTCOME_ALREADY_STOPPED` and the expected-string argument `$SM_OUTCOME_ALREADY_STOPPED`) but the diff shows the old line had only `$SM_OUTCOME_ALREADY` appearing twice on that line. Count is consistent when the two positions on line 190 are both counted. No unresolved rename.

### S-04 — Assertion values match actual string values: PASS

After the renames, the test file uses `$SM_OUTCOME_ALREADY_STOPPED` and `$SM_OUTCOME_TIMED_OUT` as both the comparison target and the expected-value argument in `_TestAssert`. The string values of these constants (defined in `ServiceManager.au3`) are `"ALREADY_STOPPED"` and `"TIMED_OUT"` respectively, which match what the assertion test names describe. No mismatch between constant name and string value in the test file's assertions.

**HOWEVER — critical defect in `ServiceManager.au3` (dependency, in scope for `-w 3` check):**

The diff to `ServiceManager.au3` introduced a typo at line 55:

```autoit
; Current (HEAD):
Global Const $SM_OUTCOME_ALREADY_STOPPED_STOPPED = "ALREADY_STOPPED"

; Required:
Global Const $SM_OUTCOME_ALREADY_STOPPED = "ALREADY_STOPPED"
```

The constant was renamed `$SM_OUTCOME_ALREADY` → `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` (double `_STOPPED` suffix) instead of `$SM_OUTCOME_ALREADY_STOPPED`. Every usage site in `ServiceManager.au3` (lines 246, 291, 425) and in `Stop Services Processes.au3` (line 247) correctly references `$SM_OUTCOME_ALREADY_STOPPED` — the intended name — which is now **undeclared** in the compilation unit because the definition carries the wrong identifier. The test file's usage at line 190 also references `$SM_OUTCOME_ALREADY_STOPPED`.

Impact:
- AU3Check `-w 1` will fire on every reference to `$SM_OUTCOME_ALREADY_STOPPED` across all three files — the same class of error BUG-12 was intended to fix.
- At AutoIt runtime, `$SM_OUTCOME_ALREADY_STOPPED` resolves to an empty string (AutoIt default for undeclared variables), so the already-stopped routing branch silently misbehaves: services that are already stopped will be recorded with outcome `""` instead of `"ALREADY_STOPPED"`, and the `_RunServiceBatchStop` Select block will fall through to the `Else` branch.
- The mis-named constant `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` is itself dead — declared but never read anywhere.

This defect is in `Includes/ServiceManager.au3`, which is outside the stated file scope of this review (`Tests/ServiceManager.Tests.au3` only). It is called out here because: (a) the standards check item explicitly asks "No `-w 3` conflicts with ServiceManager.au3 constants after the include move?" — the `-w 1` conflicts are introduced by the bad rename in the dependency; and (b) the test file cannot be evaluated as AU3Check-clean without its include resolving correctly.

**Severity: BLOCKER.** The test file's include of `ServiceManager.au3` pulls in the broken constant name. The test at line 190 will fail at runtime (comparison against an undeclared/empty constant). Fix required in `Includes/ServiceManager.au3` line 55: rename `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` to `$SM_OUTCOME_ALREADY_STOPPED`.

### S-05 — AU3Check `-w 3` conflicts after include move: PASS (modulo S-04 blocker)

The test file declares `$ERR_*` constants (lines 97–104) with no `$SM_` prefix. `ServiceManager.au3` declares `$SM_ERR_*` constants with the `$SM_` prefix. After the include move, `ServiceManager.au3` is included before the `$ERR_*` declarations. There is no name collision between `$ERR_ACCESS_DENIED` (test file) and `$SM_ERR_ACCESS_DENIED` (ServiceManager.au3), nor between any other pair. No `-w 3` warnings are introduced by the include move. PASS.

The `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` typo (S-04) is a `-w 1` issue (undeclared references), not a `-w 3` issue (re-declaration). No `-w 3` conflicts exist.

### S-06 — Smell baseline

**Speculative Generality (judgement call):** The comment block at lines 149–157 ("Unit under test: pure-logic helpers…") partially duplicates the file header's TEST DESIGN PHILOSOPHY section. It was present pre-fix and was not touched by the diff. No action required from this change.

**Duplicated Code (judgement call):** The `_Test_AllSevenStates` function duplicates several assertions already in `_Test_IsStopEligible` (e.g., RUNNING eligible, PAUSED eligible, STOP_PENDING not eligible). The comment at line 340 ("Assertions on `_SM_IsStopEligible` and `_SM_StateNeedsPolling` per individual state live in `_Test_AllSevenStates` to avoid duplication") is internally inconsistent — it says duplication was avoided, but both functions assert the same predicates for RUNNING, PAUSED, STOP_PENDING, and START_PENDING. This pre-exists the diff and was not introduced or worsened by this change. Noted as a maintenance concern.

---

## Spec

### Spec source

BUG-12 §Recommended Fix Priority Order item 1: "Move `#include "Includes\ServiceManager.au3"` to the top of the file (before the first `Func` definition). This eliminates all 40+ `-w 1` warnings."

BUG-04 §Fix Applied: rename `$SM_OUTCOME_ALREADY` → `$SM_OUTCOME_ALREADY_STOPPED` and `$SM_OUTCOME_TIMEDOUT` → `$SM_OUTCOME_TIMED_OUT` at all 4 usage sites in the test file.

### SP-01 — Include moved before all `Func` definitions: PASS

The `#include "Includes\ServiceManager.au3"` now appears at line 93, inside `#Region ;Includes`, before the first `Func` definition (`_TestAssert` at line 118). The spec requirement (BUG-12 item 1) is met.

The spec additionally required the include to be before "ALL `Global Const` and `Func` definitions." The `Global Const $ERR_*` declarations appear at lines 97–104, after the include at line 93. PASS — includes are processed before the constant declarations that follow them, satisfying AU3Check's ordering requirement.

### SP-02 — Stale comment removed: PASS

BUG-12 §Summary for `Tests/ServiceManager.Tests.au3` identified the comment at lines 96–99 (old) as incorrect ("The 'available at call time' reasoning applies to the AutoIt runtime… not to AU3Check's static analysis"). The diff removes the entire comment block. PASS.

### SP-03 — BUG-04 renames — 4 usage sites in test file: PASS

BUG-04 §Files changed specifies 4 occurrences in `Tests/ServiceManager.Tests.au3`. The diff accounts for all 4:

| # | Old name | New name | Line (HEAD) | Hunk |
|---|----------|----------|-------------|------|
| 1 | `$SM_OUTCOME_ALREADY` (comparison) | `$SM_OUTCOME_ALREADY_STOPPED` | 190 | hunk 1 |
| 2 | `$SM_OUTCOME_ALREADY` (expected arg) | `$SM_OUTCOME_ALREADY_STOPPED` | 190 | hunk 1 |
| 3 | `$SM_OUTCOME_TIMEDOUT` (assignment) | `$SM_OUTCOME_TIMED_OUT` | 329 | hunk 2 |
| 4 | `$SM_OUTCOME_TIMEDOUT` (comparison + expected arg) | `$SM_OUTCOME_TIMED_OUT` | 331 | hunk 2 |

All 4 occurrences renamed. No residual old names. PASS.

### SP-04 — Assertion values match string values `"ALREADY_STOPPED"` and `"TIMED_OUT"`: PASS in test file, BLOCKED by dependency

Within the test file: the renamed constants are used consistently as both the comparison target and the descriptive expected-value string in `_TestAssert`. The test names ("win32 1062 → ALREADY_STOPPED", "timed-out service: outcome = TIMED_OUT") match the string values of the constants. PASS for the test file in isolation.

The dependency defect (S-04 above) means the constant `$SM_OUTCOME_ALREADY_STOPPED` resolves to `""` at runtime because the definition in `ServiceManager.au3` has the wrong identifier. The assertion at line 190 will evaluate `_SM_Win32ErrToOutcome(1062) = ""` and fail. This is a runtime correctness failure traceable to the BUG-04 fix in `ServiceManager.au3`, not to the test file itself.

### SP-05 — All 11 test functions still correctly cover their intended scenarios: PASS

The 11 test functions called from the main body (lines 497–508) are:

| # | Function | Scenario | Affected by this diff? | Still correct? |
|---|----------|----------|----------------------|----------------|
| 1 | `_Test_ServiceStateToString` | Maps integer states to strings | No | Yes — uses string literals, no constants renamed |
| 2 | `_Test_Win32ErrToOutcome` | Maps Win32 codes to outcome constants | Yes — `$SM_OUTCOME_ALREADY` → `$SM_OUTCOME_ALREADY_STOPPED` at line 190 | Yes in intent; blocked at runtime by S-04 |
| 3 | `_Test_IsStopEligible` | Stop-eligibility predicate for all 7 states | No | Yes |
| 4 | `_Test_BuildResultRow` | Result row constructor, field values | No | Yes |
| 5 | `_Test_ResultArrayDimensions` | Batch returns correct row/col count | No | Yes |
| 6 | `_Test_SingleFailureInBatch` | Failure in one row does not corrupt others | No | Yes |
| 7 | `_Test_SharedTimeout` | `TIMED_OUT` outcome accounting | Yes — `$SM_OUTCOME_TIMEDOUT` → `$SM_OUTCOME_TIMED_OUT` at lines 329, 331 | Yes |
| 8 | `_Test_StateToOutcomeRouting` | Routing predicate mutual exclusivity | No | Yes |
| 9 | `_Test_AllSevenStates` | Eligibility/polling classification for all 7 states | No | Yes |
| 10 | `_Test_EmptyInput` | Empty input returns empty result, @error=0 | No | Yes |
| 11 | `_Test_UnavailableInBatch` | UNAVAILABLE service does not corrupt adjacent row | No | Yes |
| 12 | `_Test_BatchUnknownServices` | Phase 1 UNAVAILABLE path, SCM integration | No | Yes |

Note: 12 functions are listed in the call sequence (lines 497–508), not 11. The original spec/review brief says "11 test functions." Counting the calls: `_Test_ServiceStateToString`, `_Test_Win32ErrToOutcome`, `_Test_IsStopEligible`, `_Test_BuildResultRow`, `_Test_ResultArrayDimensions`, `_Test_SingleFailureInBatch`, `_Test_SharedTimeout`, `_Test_StateToOutcomeRouting`, `_Test_AllSevenStates`, `_Test_EmptyInput`, `_Test_UnavailableInBatch`, `_Test_BatchUnknownServices` = 12 functions. The count discrepancy is benign — scope creep is not indicated because the extra function (`_Test_UnavailableInBatch`) covers a scenario (UNAVAILABLE in a batch with another service) that is distinct from and complementary to `_Test_BatchUnknownServices`. No scenario is missing; no spurious scenario was added by this diff (the diff adds zero new test functions).

The two functions directly modified by this diff (`_Test_Win32ErrToOutcome` and `_Test_SharedTimeout`) retain their intended test scenario coverage after the renames. The renames change only the constant identifiers, not the test logic or the scenario being exercised.

---

## Summary

| Axis | Findings | Worst issue |
|------|----------|-------------|
| Standards | 3 findings: 1 blocker (S-04, `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` typo in dependency), 1 hard violation (S-01, `#EndRegion` missing label — pre-existing), 1 judgement call (S-06, duplicated assertions) | **S-04 — BLOCKER:** `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` typo in `Includes/ServiceManager.au3` line 55 leaves `$SM_OUTCOME_ALREADY_STOPPED` undeclared; causes AU3Check `-w 1` and runtime assertion failure |
| Spec | 1 finding: SP-04/SP-05 blocked at runtime by the same S-04 defect; test file changes are spec-complete | **SP-04 — BLOCKED:** test assertion at line 190 compares against an empty string at runtime; fix is in the dependency (`ServiceManager.au3`), not in the test file |

The changes to `Tests/ServiceManager.Tests.au3` are correct and complete: the include is in the right place, the stale comment is removed, and all 4 BUG-04 renames are applied. The file cannot achieve AU3Check compliance or pass its own assertions until `Includes/ServiceManager.au3` line 55 is corrected from `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` to `$SM_OUTCOME_ALREADY_STOPPED`.
