# Second-Pass Code Review: Tests/ServiceManager.Tests.au3
**Review ID**: CR2-05
**File**: `Tests/ServiceManager.Tests.au3`
**Fixed point**: `ab5b012`
**HEAD commits since fixed point**:
```
1d8a5ea feat: replace broken service-stop path with native SCM batch-stop module
2a62801 chore(cleanup)
09b99ba Added claude skill sets
```
**Standards sources**: `CODING_STANDARDS.md`, `.agents/skills/tdd/tests.md`
**Spec source**: `.scratch/service-manager-migration/issues/05-independent-review.md`
**Date**: 2026-11-12

---

## Standards

### S-01 — PASS: `_BuildExpectedRow` is gone (dead code deleted)

The fixed-point version (`ab5b012`) contained `_BuildExpectedRow` (lines 93–103), a stub row-builder that duplicated the signature of `_SM_BuildResultRow` but was never called by any test function. HEAD does not contain `_BuildExpectedRow` at all. The `STUB PATTERN` section in the revised file header explicitly documents the removal: "The term 'stub' in older comments referred to `_BuildExpectedRow`, which has been removed (dead code — never called)." Dead-code elimination is confirmed. PASS.

---

### S-02 — PASS: `ConsoleWrite` usage documented with exception citation

CODING_STANDARDS.md prohibits direct `ConsoleWrite` calls outside of initialization/debug code (Logging section), but grants an explicit exception (CR-03) for test harness files. The fixed-point version had no inline documentation linking its `ConsoleWrite` calls to this exception. HEAD adds a `CONSOLEWRITE EXCEPTION` block in the file header (lines 65–71) that:
- Names the standard being exempted (`CODING_STANDARDS.md`)
- States why `_LogMessage` infrastructure is unavailable in the harness
- Bounds the exception to `Tests/` directory files

The citation is present, accurate, and correctly scoped. PASS.

---

### S-03 — PASS: `#RequireAdmin` scope documented with explanatory comment

The fixed-point version had `#RequireAdmin` on line 1 with no explanation. HEAD adds a `#RequireAdmin SCOPE NOTE` block (lines 3–13) that:
- Identifies the two specific functions requiring SCM access (`_Test_EmptyInput`, `_Test_BatchUnknownServices`)
- Names the Windows API call that requires elevation (`OpenSCManagerW`)
- Notes the nine pure-logic tests that do not need admin
- Explains that AutoIt does not support per-function elevation
- Provides a workaround instruction for running pure-logic tests without admin

The comment accurately describes the constraint. PASS.

---

### S-04 — PASS: `_Test_ResultArrayDimensions` now tests the module, not just UBound

**Fixed-point version** (`ab5b012`): `_Test_ResultArrayDimensions` manually declared `Local $aResults[3][6]`, populated it with inline assignments in a `For` loop, then called `UBound($aResults, 1)` and `UBound($aResults, 2)`. This was a tautological test: the expected values (`3` rows, `6` columns) were guaranteed by the declaration itself, not by any module behaviour. Per `tests.md`, this is a "bad test" — expected value restates the implementation by construction.

**HEAD version**: `_Test_ResultArrayDimensions` now calls `_SM_StopServicesBatch(["__NonExistent_TestSvc_A__", "__NonExistent_TestSvc_B__"])` and asserts:
- row count = 2 (the module must produce one row per input)
- col count = 6 (the module must produce 6 columns per row)
- `$aResults[0][0]` = `"__NonExistent_TestSvc_A__"` (name preserved)
- `$aResults[0][3]` = `$SM_OUTCOME_UNAVAILABLE` (Phase 1 routing)

These assertions can only pass if the module under test returns the correct shape and content; they would catch a regression that changed the column count or outcome routing. The function header comment also explains why the SCM integration path is exercised (lines 275–286). The tautological smell is resolved. PASS.

---

### S-05 — MINOR (judgement call): Duplicate assertions remain between `_Test_IsStopEligible` and `_Test_AllSevenStates`

`_Test_IsStopEligible` (lines 228–251) and `_Test_AllSevenStates` (lines 368–397) both assert the eligibility classification for all 7 states. For example:

- `_SM_IsStopEligible($SM_STATE_RUNNING) = True` appears in both (lines 232 and 386)
- `_SM_IsStopEligible($SM_STATE_PAUSED) = True` appears in both (lines 235 and 396)
- `Not _SM_IsStopEligible($SM_STATE_STOP_PENDING)` appears in both (lines 247 and 383)
- `Not _SM_IsStopEligible($SM_STATE_START_PENDING)` appears in both (lines 250 and 376)

Similarly, `_Test_StateToOutcomeRouting` (lines 349–361) and `_Test_AllSevenStates` both assert `_SM_StateToAlreadyStopped($SM_STATE_STOPPED) = True` and `_SM_StateNeedsPolling($SM_STATE_STOP_PENDING) = True`.

The file header for `_Test_StateToOutcomeRouting` notes "Assertions on `_SM_IsStopEligible` and `_SM_StateNeedsPolling` per individual state live in `_Test_AllSevenStates` to avoid duplication (CR-03 S-06)." However, `_Test_IsStopEligible` still runs all 7 states independently, and `_Test_AllSevenStates` repeats them. This is **Duplicated Code** per the smell baseline (Fowler ch.3). The duplication is benign in a test harness (failing fast twice on the same function is not harmful) and the per-function test retains value as a focused regression signal, so this is a judgement call, not a hard violation.

**Smell**: Duplicated Code (baseline heuristic).
**Suggested fix**: Remove the per-state eligibility assertions from `_Test_AllSevenStates` that are already covered verbatim in `_Test_IsStopEligible`, or collapse `_Test_IsStopEligible` into `_Test_AllSevenStates`. Either direction is acceptable.

---

### S-06 — PASS: Function naming conventions

All functions follow the two-tier naming rule from CODING_STANDARDS.md:
- Framework helpers: `_TestAssert`, `_PrintResults` — `_UnderscorePascalCase`, no `_Test_` prefix. Correct.
- Test functions: all use `_Test_PascalCase` — consistent with the convention established in prior reviews.
- No `_SM_PascalCase` tier appears in the test file (correctly absent per CR-09 note in CODING_STANDARDS.md).

PASS.

---

### S-07 — PASS: `ConsoleWrite` in test helpers is exempted, not a violation

`_PrintResults` and each `_Test_*` function call `ConsoleWrite` directly. CODING_STANDARDS.md CR-03 exception explicitly permits this for files in `Tests/`. No violation. PASS.

---

### S-08 — PASS: No speculative generality introduced

No new parameters, hooks, or abstractions appear that the spec does not require. The removal of `_BuildExpectedRow` (a never-called stub) reduces speculative generality compared to the fixed point. PASS.

---

### Standards Summary

4 findings: 3 hard PASS, 1 PASS with note, 1 MINOR judgement call, 0 hard violations.

| ID | Finding | Severity |
|----|---------|----------|
| S-01 | `_BuildExpectedRow` deleted | PASS |
| S-02 | `ConsoleWrite` exception cited | PASS |
| S-03 | `#RequireAdmin` scope documented | PASS |
| S-04 | `_Test_ResultArrayDimensions` tests module | PASS |
| S-05 | Duplicate eligibility assertions across `_Test_IsStopEligible` / `_Test_AllSevenStates` | MINOR (judgement call) |
| S-06 | Function naming | PASS |
| S-07 | `ConsoleWrite` exemption | PASS |
| S-08 | No speculative generality | PASS |

**Worst Standards issue**: S-05 — Duplicated Code smell (judgement call, not a hard violation). No hard violations found.

---

## Spec

Spec source: `.scratch/service-manager-migration/issues/05-independent-review.md` — T05 checklist.

The T05 checklist has status CONDITIONALLY CLOSED. The prior review (REVIEW-ServiceManager.Tests.au3.md) found one BLOCKER (STD-001: duplicate `Global Const` for `$SM_STATE_*` / `$SM_OUTCOME_*`) and approved with conditions. This second-pass review checks whether the conditions were resolved and whether the T05 checklist items are now satisfied.

---

### SP-01 — PASS: STD-001 BLOCKER resolved — duplicate `Global Const` declarations removed

The fixed-point version declared 12 `Global Const` symbols (`$SM_STATE_STOPPED` through `$SM_OUTCOME_TIMEDOUT`) that also appear in `Includes/ServiceManager.au3`, producing AU3Check redefinition conflicts under `-w 3`/`-w 4`. HEAD contains none of these duplicates. The only `Global Const` declarations in HEAD are the 8 `$ERR_*` constants (lines 103–110), which use different names from `ServiceManager.au3`'s `$SM_ERR_*` constants and do not conflict. The BLOCKER condition for T05 approval is resolved. PASS.

---

### SP-02 — PASS: `_Test_BatchUnknownServices` is present and correct

**Present**: `_Test_BatchUnknownServices` appears at lines 465–494. It is called in the main body at line 516. PASS on presence.

**Correct**: The function:
1. Declares 3 service names with internal underscores and mixed case designed to avoid any real Windows service name: `["__TestHarness_NX_Svc1__", "__TestHarness_NX_Svc2__", "__TestHarness_NX_Svc3__"]`.
2. Calls `_SM_StopServicesBatch($aNames)` — a live SCM call.
3. Asserts `@error = 0` with the comment "SCM opened successfully even though the individual services do not exist" — testing that a batch-level SCM open failure (`@error=1`) is distinct from per-service failure.
4. Asserts `UBound($aResults, 1) = 3` and `UBound($aResults, 2) = 6` — one row per input, 6 columns per row.
5. Iterates all 3 rows and asserts outcome=UNAVAILABLE, win32=1060, initState=-1, finalState=-1, and name preserved.

The function exercises the Phase 1 UNAVAILABLE routing path in `_SM_StopServicesBatch` without issuing any stop controls (REQ-009 compliant). The name selection, assertion set, and loop structure are all correct. The extended header comment (lines 434–463) explains why this is the testable integration path in a Linux sandbox. PASS on correctness.

---

### SP-03 — PASS: T05 checklist item — harness meets review conditions from prior pass

The prior review (REVIEW-ServiceManager.Tests.au3.md) listed the following conditions for approval:

1. Remove duplicate `Global Const` declarations for `$SM_STATE_*` and `$SM_OUTCOME_*` → **Resolved** (SP-01 above).
2. Retain `$ERR_*` constants (not duplicated in `ServiceManager.au3`) → **Retained** (lines 103–110).

No other conditions were listed. Both conditions are satisfied in HEAD. PASS.

---

### SP-04 — PASS: REQ-009 — no live stop controls issued

`_Test_BatchUnknownServices` and `_Test_ResultArrayDimensions` are the only functions that call `_SM_StopServicesBatch`. Both use names designed to not exist on any real Windows system, ensuring Phase 1 routes all services to UNAVAILABLE and returns without entering Phase 2 (no `ControlService` call is ever made). `_Test_EmptyInput` passes a zero-length array, which causes `_SM_StopServicesBatch` to return immediately. No production service names appear as test inputs. PASS.

---

### SP-05 — PASS: All prior spec requirements still satisfied

The diff adds `_Test_BatchUnknownServices` and rewrites `_Test_ResultArrayDimensions` without removing any previously passing spec coverage. All findings from the prior SPEC-001 through SPEC-008 checklist items (all 7 states, all 5 outcomes, all 8 Win32 error codes, single-service failure isolation, shared timeout, empty input) remain present and unmodified in HEAD. PASS.

---

### SP-06 — INFORMATIONAL: `_Test_BatchUnknownServices` and `_Test_ResultArrayDimensions` now overlap in coverage

Both functions call `_SM_StopServicesBatch` with non-existent service names and both assert row/col counts and UNAVAILABLE outcome. `_Test_ResultArrayDimensions` uses 2 names; `_Test_BatchUnknownServices` uses 3 names and additionally verifies `@error=0`, win32=1060, initState=-1, finalState=-1, and name preservation per row. The overlap is minor — `_Test_ResultArrayDimensions` is a quick dimension smoke test; `_Test_BatchUnknownServices` is the full per-row correctness test. The duplication is not harmful and is consistent with the progressive-assertion style of the harness. INFORMATIONAL only; no action required.

---

### Spec Summary

6 findings: 5 PASS, 1 INFORMATIONAL, 0 failures.

| ID | Finding | Severity |
|----|---------|----------|
| SP-01 | Duplicate `Global Const` BLOCKER resolved | PASS |
| SP-02 | `_Test_BatchUnknownServices` present and correct | PASS |
| SP-03 | All T05 approval conditions satisfied | PASS |
| SP-04 | REQ-009 no live stop controls | PASS |
| SP-05 | All prior spec requirements intact | PASS |
| SP-06 | Overlap between `_Test_ResultArrayDimensions` and `_Test_BatchUnknownServices` | INFORMATIONAL |

**Worst Spec issue**: none — all T05 checklist items satisfied, no requirements missing or incorrectly implemented.

---

## One-Line Summary

**Standards**: 1 finding (1 MINOR judgement call — Duplicated Code smell across `_Test_IsStopEligible` / `_Test_AllSevenStates`), 0 hard violations; worst issue: S-05 duplicate eligibility assertions.
**Spec**: 0 failures, 1 informational note; all T05 checklist items pass including `_Test_BatchUnknownServices` present and correct and the STD-001 BLOCKER resolved.
