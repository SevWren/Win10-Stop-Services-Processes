# CR-03 — Code Review: Test Suite
**File reviewed:** `Tests/ServiceManager.Tests.au3`
**Diff base:** `ab5b012`
**Commits in session:**
- `1d8a5ea` feat: replace broken service-stop path with native SCM batch-stop module
- `2a62801` chore(cleanup)
- `09b99ba` Added claude skill sets

**Standards sources:** `CODING_STANDARDS.md`, `CLAUDE.md`, Fowler smell baseline (from SKILL.md)
**Spec sources:** `docs/REQUIREMENTS.md`, `.scratch/service-manager-migration/issues/03-build-servicemanager.md`, `.scratch/service-manager-migration/issues/05-independent-review.md`

---

## Standards

### S-01 — Unused function: `_BuildExpectedRow` (Speculative Generality)
**Severity:** Minor / Judgement call (smell)
**Location:** Lines ~93–101

`_BuildExpectedRow` is defined but never called anywhere in the file. It was presumably scaffolded to construct expected result rows independently of `_SM_BuildResultRow`, but all actual test assertions either call `_SM_BuildResultRow` directly or build arrays inline. The function is dead code.

> Fowler: *Speculative Generality* — abstraction or hooks added for needs not in the spec. → delete it; inline back until a real need shows.

### S-02 — ConsoleWrite in non-initialization code (Documented standard)
**Severity:** Minor (borderline)
**Location:** `_PrintResults()`, section-banner lines in each `_Test_*` function, main body

`CODING_STANDARDS.md` states: "Direct `ConsoleWrite` calls outside of initialization/debug code are NOT permitted." The test harness uses `ConsoleWrite` pervasively as its primary output mechanism — section banners, the results summary, and the pass/fail log.

This standard is aimed at production code routing through `_LogMessage`. A test harness is fundamentally a diagnostic tool and has no access to `_LogMessage` without dragging in the full main-script logging infrastructure. The standard does carve out "initialization/debug code" as an exception; whether a test harness qualifies depends on interpretation. Flagged as borderline rather than hard violation, but worth a team decision to document the exception explicitly in CODING_STANDARDS.md.

### S-03 — `g_` prefix on globals not in documented convention
**Severity:** Informational
**Location:** Lines ~54–57 (`$g_iTestCount`, `$g_iPassCount`, `$g_iFailCount`, `$g_sTestLog`)

CODING_STANDARDS.md documents the `$SM_` module prefix for ServiceManager but no global-variable prefix convention for other modules. The `g_` prefix is a reasonable convention but is not in the standard. Not a violation — informational only.

### S-04 — Colon-separated inline assignments reduce readability
**Severity:** Informational
**Location:** `_Test_SingleFailureInBatch`, `_Test_SharedTimeout`, `_Test_UnavailableInBatch` (multiple lines)

Lines like:
```autoit
$aResults[1][0] = "WaaSMedicSvc"  : $aResults[1][3] = $SM_OUTCOME_FAILED : $aResults[1][4] = 5
```
use AutoIt's colon as a statement separator to pack multiple assignments on one line. This is syntactically valid but is not a documented style and reduces readability. No standard explicitly prohibits it; informational.

### S-05 — `#RequireAdmin` on a "no live SCM calls" harness
**Severity:** Minor / Judgement call
**Location:** Line 1

The file header and REQ-009 both state no live stop controls are issued. The directive `#RequireAdmin` is present because `_Test_EmptyInput` calls `_SM_StopServicesBatch` with an empty array, which does open the SCM manager handle. Admin is therefore needed at runtime for that one test. However, it creates a gap: running the harness without admin will fail entirely at the OS level before any test runs, even though 10 of 11 test functions need no elevated privileges. Consider splitting `_Test_EmptyInput` into a separate integration-level file, or gating it on an environment variable so the pure-logic tests are runnable without admin.

### S-06 — Overlapping assertions between `_Test_StateToOutcomeRouting` and `_Test_AllSevenStates` (Duplicated Code smell)
**Severity:** Minor / Judgement call
**Location:** Lines ~276–336

Both functions assert on `_SM_IsStopEligible($SM_STATE_STOP_PENDING)`, `_SM_IsStopEligible($SM_STATE_RUNNING)`, `_SM_StateNeedsPolling($SM_STATE_STOP_PENDING)`, and `_SM_StateNeedsPolling($SM_STATE_RUNNING)`. The overlap means those state/function combinations are tested twice with no additional coverage. The boundary between the two functions is not clearly differentiated by their names or comments.

> Fowler: *Duplicated Code* — the same logic shape appears in more than one hunk. → extract the shared shape.

---

## Spec

### P-01 — All T03 mandatory test scenarios covered
**Status:** PASS

T03 checklist required: "Test all 7 service states, stop eligibility, missing service, access denied, single-service failure in a batch, shared timeout, per-service result rows."

| Required scenario | Covered by |
|---|---|
| All 7 service states | `_Test_ServiceStateToString`, `_Test_IsStopEligible`, `_Test_AllSevenStates` |
| Stop eligibility | `_Test_IsStopEligible`, `_Test_StateToOutcomeRouting`, `_Test_AllSevenStates` |
| Missing service (UNAVAILABLE) | `_Test_UnavailableInBatch`, `_Test_BuildResultRow` (unavailable row) |
| Access denied (win32=5) | `_Test_Win32ErrToOutcome`, `_Test_SingleFailureInBatch` |
| Single-service failure in batch | `_Test_SingleFailureInBatch` |
| Shared timeout | `_Test_SharedTimeout` |
| Per-service result rows | `_Test_BuildResultRow`, `_Test_ResultArrayDimensions` |

All 7 required scenarios are present.

### P-02 — REQ-009 (no live stop controls) satisfied
**Status:** PASS

REQ-009: "no calls to `_SM_StopServicesBatch` with real service names in tests."

`_Test_EmptyInput` is the only test that calls `_SM_StopServicesBatch` and it passes an empty array — no service names, no stop controls issued. All other tests call pure-logic helpers directly or construct result arrays manually. The file header assertion "No live service stop controls are issued in this harness" is accurate.

### P-03 — REQ-003 (two-phase batch design) has no behavioral test coverage
**Status:** Partial / Acceptable gap

REQ-003 specifies that Phase 1 issues stop controls without serial waiting and Phase 2 polls all pending services against one shared deadline. The test harness explicitly avoids live SCM calls, so the two-phase orchestration in `_SM_StopServicesBatch` is untested by this harness. The REQUIREMENTS.md verification method for REQ-003 is listed as "Static inspection — stop loop and poll loop are separate phases" (not tests), so this gap is by design and acknowledged in the requirements register.

However, `_Test_EmptyInput` calls the real `_SM_StopServicesBatch` with an empty input. This exercises the SCM-open and early-return path but does not validate the two-phase algorithm for non-empty inputs. The harness misses an opportunity to stub the SCM layer and test the phase sequencing under controlled conditions. Not a spec violation given the stated verification strategy, but noted as a coverage gap for future hardening.

### P-04 — `_Test_ResultArrayDimensions` does not test `_SM_StopServicesBatch`
**Status:** Weak test / Informational

This function manually constructs a `$aResults[3][6]` array in test code and then checks `UBound($aResults, 1) = 3` and `UBound($aResults, 2) = 6`. It is effectively testing AutoIt's array mechanics, not any behavior of the module under test. The T03 spec item "per-service result rows" is better covered by `_Test_BuildResultRow`, which calls the actual `_SM_BuildResultRow` helper. The dimensions test adds no unique coverage.

> tests.md: *Tautological tests* — expected value restates the implementation so the test passes by construction.

### P-05 — 05-independent-review.md checklist item satisfied
**Status:** PASS

The issue-05 checklist requires "Review agent 3: Tests/ServiceManager.Tests.au3 final hash." This review satisfies that item. No BLOCKER or CRITICAL findings were identified. The findings above are Minor or Informational and do not need escalation to diagnosing-bugs before T06.

---

## Summary

**Standards axis:** 6 findings — 1 Minor/Documented (S-02 ConsoleWrite), 2 Minor/Judgement (S-01 dead function, S-05 `#RequireAdmin` scope), 1 Minor/Smell (S-06 duplicated assertions), 2 Informational (S-03, S-04). Worst issue: **S-01** — `_BuildExpectedRow` is dead code that should be removed (Speculative Generality).

**Spec axis:** 5 findings — 2 Pass confirmations (P-01, P-02), 1 Acceptable gap (P-03 two-phase design untestable without stubs), 1 Weak test (P-04 tautological dimensions test), 1 Pass confirmation (P-05). Worst issue: **P-03** — the two-phase batch algorithm has no behavioral test coverage; all batch-level tests use manually constructed arrays rather than exercising `_SM_StopServicesBatch` with any input that reaches Phase 2.
