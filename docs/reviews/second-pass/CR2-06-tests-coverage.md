# CR2-06 — Second-Pass Code Review: Tests/ServiceManager.Tests.au3
Reviewer: Second-Pass Review Agent
Date: 2026-11-12
Branch: arch/service-manager-migration
Fixed point: ab5b012
File under review: Tests/ServiceManager.Tests.au3
Prior review: docs/reviews/REVIEW-ServiceManager.Tests.au3.md

---

## Diff Summary

`git diff ab5b012...HEAD -- Tests/ServiceManager.Tests.au3` shows the file is new at HEAD
(added entirely in the diff window). Commits since `ab5b012`:

```
1d8a5ea feat: replace broken service-stop path with native SCM batch-stop module
2a62801 chore(cleanup)
09b99ba Added claude skill sets
```

The diff covers three distinct change classes compared to the first-pass baseline:

1. **Header expansion**: Four new documentation blocks added — `#RequireAdmin SCOPE NOTE`,
   `TEST DESIGN PHILOSOPHY`, `STUB PATTERN`, `DETERMINISTIC DESIGN CONSTRAINT`, and
   `CONSOLEWRITE EXCEPTION`.

2. **BLOCKER fix**: The duplicate `Global Const` declarations for `$SM_STATE_*` and
   `$SM_OUTCOME_*` (first-pass finding STD-001) have been removed. Only the `$ERR_*`
   constants remain at the top.

3. **Test function changes**:
   - `_Test_ResultArrayDimensions` was rewritten from a manually-constructed array scenario
     into a live SCM integration test (calls `_SM_StopServicesBatch` with two nonsensical
     names).
   - `_Test_BatchUnknownServices` added as a new 3-service live SCM integration test.
   - Both new live-SCM tests are added to the main call sequence.
   - `_Test_StateToOutcomeRouting` gained two additional assertions about `_SM_StateNeedsPolling`.

---

## Standards

### STD2-01 — PASS: First-pass BLOCKER resolved (duplicate Global Const)

The duplicate `Global Const` declarations for `$SM_STATE_*` and `$SM_OUTCOME_*` identified
as a BLOCKER in `docs/reviews/REVIEW-ServiceManager.Tests.au3.md` (STD-001) are absent from
HEAD. Only the `$ERR_*` constants (line 103–110) remain at the top of the file, which do not
conflict with ServiceManager.au3's `$SM_ERR_*` names. AU3Check redefinition conflict: RESOLVED.

---

### STD2-02 — PASS: Function naming convention

All test functions follow `_Test_PascalCase`:

| Function | Convention |
|---|---|
| `_Test_ServiceStateToString` | PASS |
| `_Test_Win32ErrToOutcome` | PASS |
| `_Test_IsStopEligible` | PASS |
| `_Test_BuildResultRow` | PASS |
| `_Test_ResultArrayDimensions` | PASS |
| `_Test_SingleFailureInBatch` | PASS |
| `_Test_SharedTimeout` | PASS |
| `_Test_StateToOutcomeRouting` | PASS |
| `_Test_AllSevenStates` | PASS |
| `_Test_EmptyInput` | PASS |
| `_Test_UnavailableInBatch` | PASS |
| `_Test_BatchUnknownServices` | PASS |

Framework helpers (`_TestAssert`, `_PrintResults`) correctly use `_UnderscorePascalCase`
without the `_Test_` prefix.

CODING_STANDARDS.md §Function Naming: test files follow the same two-tier naming as production
code (`PascalCase` / `_UnderscorePascalCase`). No violations.

---

### STD2-03 — PASS: `g_` prefix on framework globals is justified

CODING_STANDARDS.md §Test File Conventions explicitly states: "The `g_` prefix for global
variables in test harnesses is an accepted convention within test files and does not violate
the standard variable naming rules applied to production code."

The four framework globals (`$g_iTestCount`, `$g_iPassCount`, `$g_iFailCount`, `$g_sTestLog`)
all carry the `g_` prefix and are global in scope. Convention is correct and documented.

---

### STD2-04 — PASS: ConsoleWrite usage

CODING_STANDARDS.md §Logging, CR-03 exception: test harness files in `Tests/` may use
`ConsoleWrite` directly. All `ConsoleWrite` calls are for test-runner output only. The
`CONSOLEWRITE EXCEPTION` section in the file header correctly documents the exception
and its scope limitation.

---

### STD2-05 — INFORMATIONAL: `_SM_PascalCase` naming in module under test

CODING_STANDARDS.md §Function Naming (Note CR-09) states that the `_SM_PascalCase` tier was
removed and is not defined in CLAUDE.md. The test file calls functions like `_SM_StopServicesBatch`,
`_SM_ServiceStateToString`, `_SM_Win32ErrToOutcome`, `_SM_IsStopEligible`, etc. — names that
carry the `_SM_` prefix belonging to the removed tier.

This finding is against the module under test (`Includes/ServiceManager.au3`), not against the
test file itself. The test file correctly calls whatever names the module exposes. If the naming
inconsistency in `ServiceManager.au3` is unresolved, it will surface in a separate review of
that module. No action required in the test file.

---

### STD2-06 — PASS: Smell baseline

**Duplicated Code**: `_Test_ResultArrayDimensions` and `_Test_BatchUnknownServices` both
exercise the UNAVAILABLE path via `_SM_StopServicesBatch`. The two tests are not redundant:
`_Test_ResultArrayDimensions` uses 2 names and focuses on array shape (row count, column count,
name preservation, outcome); `_Test_BatchUnknownServices` uses 3 names and asserts all six
columns per row in a loop. The overlap is intentional coverage layering, not copy-paste
duplication. No smell.

**Speculative Generality**: The `$sExpected` / `$sActual` optional parameters in `_TestAssert`
are used throughout; not speculative.

**Mysterious Name**: `_TestAssert`, `_PrintResults`, `_Test_*` naming is clear. `$g_sTestLog`
accumulates formatted output lines — name is adequately descriptive.

No baseline smells found.

---

### Standards Summary

One BLOCKER from the first pass (STD-001, duplicate Global Const) is resolved. All naming
conventions, `g_` prefix justification, `ConsoleWrite` exemption, and smell baseline checks
pass. One informational note on `_SM_PascalCase` naming belongs to the module under test, not
the test file.

**Worst Standards issue**: none (BLOCKER resolved; all checks pass).

---

## Spec

### REQ Coverage Map

| REQ | Description | Test(s) covering it |
|---|---|---|
| REQ-001 | Batch returns per-service outcomes; 5 outcome codes; 6-column row layout | `_Test_ResultArrayDimensions` (shape + UNAVAILABLE), `_Test_BuildResultRow` (column layout), `_Test_SingleFailureInBatch` (FAILED isolation), `_Test_SharedTimeout` (TIMED_OUT), `_Test_UnavailableInBatch` (UNAVAILABLE accounting), `_Test_Win32ErrToOutcome` (ALREADY_STOPPED, FAILED variants), `_Test_BatchUnknownServices` (UNAVAILABLE per-row) |
| REQ-002 | All 7 service states interpreted | `_Test_ServiceStateToString` (all 7 + 3 OOB), `_Test_AllSevenStates` (routing classification per state) |
| REQ-003 | Phase 1 issues stop controls without serial waiting; Phase 2 polls shared deadline | **No dedicated test.** See SPEC2-01 below. |
| REQ-004 | Minimum access rights only | No test (code-inspection-only requirement; outside test-harness scope) |
| REQ-005 | Every handle has exactly one cleanup path | No test (code-inspection-only requirement) |
| REQ-006 | @error captured immediately after DllCall | No test (code-inspection-only requirement) |
| REQ-007 | "handle" type string for all SC_HANDLE params | No test (code-inspection-only requirement) |
| REQ-008 | ControlService receives valid SERVICE_STATUS struct | No test (code-inspection-only requirement) |
| REQ-009 | Deterministic test harness has no live service stops | `_Test_EmptyInput`, `_Test_BatchUnknownServices` (no-stop property; see SPEC2-02 and SPEC2-03) |
| REQ-010 | 9-service inventory | No test (inventory lives in main script, not ServiceManager.au3) |
| REQ-011 | Undeclared $iLastStopProcesses fixed | No test (variable declaration in main script) |
| REQ-012 | Duplicate #include and HotKeySet removed | No test (static structure in main script) |
| REQ-013 | Poll interval = 10 seconds | No test (constant in main script) |
| REQ-014 | Include paths portable | No test (path inspection; not a runtime behavior) |
| REQ-015 | Intra-batch poll interval = 500 ms | No test (constant value; Phase 2 behavior not reachable in test harness) |
| REQ-016 | Batch deadline = 20 seconds | No test (constant value; Phase 2 timeout not reachable in test harness) |
| REQ-017 | QueryServiceStatus (not QueryServiceStatusEx) used | No test (code-inspection-only requirement) |

REQ-004 through REQ-008, REQ-010 through REQ-017: these are all recorded in REQUIREMENTS.md
as verified by code inspection, not by the test harness. Their absence from the test file is
correct — they are structural or constant-value properties that cannot be meaningfully exercised
by a deterministic test harness under REQ-009 and the Linux environment gate. No gap.

---

### SPEC2-01 — DOCUMENTED GAP (expected): REQ-003 Phase 2 behavioral gap

**REQ-003** requires that Phase 1 issues stop controls without serial waiting and Phase 2 polls
all pending services against a single shared deadline. The REQUIREMENTS.md entry for REQ-003
records "Verification: Static inspection — stop loop and poll loop are separate phases" and
does not claim any test coverage.

The test harness correctly documents this gap in the `TEST DESIGN PHILOSOPHY` section (lines
21–63): the Phase 2 polling loop cannot be exercised in this environment because (a) AutoIt
runs only on Windows, (b) real service names are prohibited under REQ-009, and (c) the only
deterministic live-SCM path available in this sandbox is the UNAVAILABLE code path
(OpenServiceW → Win32 1060), which routes services out of Phase 1 before Phase 2 is entered.

The `DETERMINISTIC DESIGN CONSTRAINT` block (lines 53–63) explicitly states: "REQ-009
prohibits live stop controls in this harness. Per-service result arrays for timeout, failure,
and already-stopped scenarios are constructed manually to test outcome-accounting properties
without touching a live SCM. The two SCM integration tests (_Test_EmptyInput,
_Test_BatchUnknownServices) do open a live SCM handle but issue no stop controls: the first
passes an empty list; the second uses names that do not exist on any real Windows install,
ensuring Phase 1 routes all services to UNAVAILABLE and returns without entering Phase 2."

**Verdict**: The gap is accurately documented. The claim in the task brief that this is
"expected: REQ-003 Phase 2 behavioral gap" is confirmed correct. The documentation is not
merely present — it is precise about the mechanical reason (UNAVAILABLE routing exits Phase 1
before Phase 2 begins) and what a future test would require (a Windows-side controllable test
service). No action required.

---

### SPEC2-02 — PASS: `_Test_BatchUnknownServices` correctly asserts UNAVAILABLE outcomes

`_Test_BatchUnknownServices` (lines 465–494) calls `_SM_StopServicesBatch` with three
names guaranteed not to exist on any Windows system: `"__TestHarness_NX_Svc1__"`,
`"__TestHarness_NX_Svc2__"`, `"__TestHarness_NX_Svc3__"`.

For each of the three rows the test asserts:

| Assertion | Expected | Significance |
|---|---|---|
| `$aResults[$i][3] = $SM_OUTCOME_UNAVAILABLE` | UNAVAILABLE | Phase 1 routed via OpenServiceW → Win32 1060 |
| `$aResults[$i][4] = $SM_ERR_SVC_NOT_EXIST` | 1060 | Win32 error correctly propagated |
| `$aResults[$i][1] = -1` | -1 | initState sentinel for unreachable service |
| `$aResults[$i][2] = -1` | -1 | finalState sentinel for unreachable service |
| `$aResults[$i][0] = $aNames[$i]` | name preserved | row identity correctly set |

Batch-level assertions: `@error = 0` (SCM opened; individual absence is not an SCM-open
failure), row count = 3, column count = 6.

The loop across all three rows (lines 487–493) prevents the common mistake of asserting only
row 0. All five per-row columns are checked. The expected values are independent literals or
named constants — not recomputed from the system, so no tautology risk (tdd/tests.md).

**Verdict**: PASS. The function correctly and completely asserts UNAVAILABLE outcomes for
all nonexistent services.

---

### SPEC2-03 — PASS: `_Test_EmptyInput` correctly verifies no stop controls are issued

`_Test_EmptyInput` (lines 403–412) constructs a zero-length array (`Local $aEmpty[0]`) and
passes it to `_SM_StopServicesBatch`. It asserts:

1. `@error = 0` — the function did not set @error=1 (which the module reserves for SCM open
   failure). The comment "not an SCM failure" correctly explains the distinction.
2. `UBound($aResults) = 0` — the returned array is empty; no rows were produced.

The comment in the test (line 406–407) is precise: "@error=1 is reserved for SCM open
failure." This aligns with the module's documented contract.

The name pattern `"__NonExistent_*"` is not used here — the empty array means
`_SM_StopServicesBatch` returns before it ever opens the SCM, so no Win32 calls are issued
at all. This is the strictest form of "no stop controls are issued." The test verifies the
correct observable effects (no @error, empty result) rather than internal call counts
(tdd/tests.md "good tests" criterion: tests observable behavior, not how).

**Verdict**: PASS. The function correctly verifies that an empty input produces an empty
result with @error=0 and that no stop controls or SCM handles are involved.

---

### SPEC2-04 — PASS: TEST DESIGN PHILOSOPHY header is present

The `TEST DESIGN PHILOSOPHY` header (line 21) is present in HEAD. It was absent from the
`ab5b012` baseline. The section correctly divides tests into two categories ("Pure-logic unit
tests" and "SCM integration tests") with named examples of each, and explains why the
integration tests are limited to the UNAVAILABLE path. The subsequent sub-sections
(`STUB PATTERN`, `DETERMINISTIC DESIGN CONSTRAINT`, `CONSOLEWRITE EXCEPTION`) provide
traceability from each design decision back to a spec requirement or project constraint.

---

### SPEC2-05 — PASS: Test results tell a complete story about module behavior

The 11 test functions collectively demonstrate:

- **State classification**: All 7 SERVICE_STATUS states are classified by routing category
  (ALREADY_STOPPED, polling-only, eligible for stop control). `_Test_ServiceStateToString`
  and `_Test_AllSevenStates` together cover every state.

- **Win32 error mapping**: All 8 Win32 error codes referenced in the module contract map
  to the correct outcome constant. The default (unknown error → FAILED) is also tested.

- **Result row structure**: Column layout [0..5] verified via `_Test_BuildResultRow` for
  both a normal STOPPED row and an UNAVAILABLE row.

- **Batch isolation**: `_Test_SingleFailureInBatch` demonstrates that FAILED on one service
  does not affect adjacent rows.

- **Timeout accounting**: `_Test_SharedTimeout` demonstrates that TIMED_OUT is set on the
  unfinished service while the finished service retains STOPPED.

- **Array dimensions**: `_Test_ResultArrayDimensions` confirms the live module returns a
  2D array with the correct row and column counts (and UNAVAILABLE outcome) for a 2-service
  batch of nonexistent names.

- **Empty input boundary**: `_Test_EmptyInput` covers the zero-service edge case.

- **UNAVAILABLE accounting (simulated)**: `_Test_UnavailableInBatch` verifies that an
  UNAVAILABLE row alongside a STOPPED row preserves both correctly.

- **UNAVAILABLE accounting (live SCM)**: `_Test_BatchUnknownServices` exercises the actual
  module code path end-to-end for three nonexistent names.

The only behavior not covered is Phase 2 (polling loop and 20-second deadline), which is
correctly recorded as an acknowledged gap (SPEC2-01) with documented rationale.

---

### SPEC2-06 — INFORMATIONAL: `_Test_ResultArrayDimensions` scope change from baseline

At `ab5b012`, `_Test_ResultArrayDimensions` was a pure scenario test: it built a 3-service
result array manually and asserted array shape. At HEAD it is a live SCM integration test
calling `_SM_StopServicesBatch` with 2 nonsensical names and asserting shape plus UNAVAILABLE
outcome.

The new version is strictly more valuable (exercises real module code), and it still asserts
the same shape properties. However, it now requires `#RequireAdmin` and Windows, moving it
from the "pure-logic unit tests" category into the "SCM integration tests" category. The file
header's `#RequireAdmin SCOPE NOTE` correctly documents this. The function name
`_Test_ResultArrayDimensions` now understates what the test does (it also verifies UNAVAILABLE
routing), but the inline comments compensate. Not a defect; noted for awareness.

---

### Spec Summary

All test-harness-applicable requirements are satisfied:

- REQ-001: covered across 7 test functions
- REQ-002: covered by 2 test functions
- REQ-003 Phase 2 behavioral gap: accurately documented (expected; confirmed)
- REQ-009: satisfied by both `_Test_EmptyInput` and `_Test_BatchUnknownServices`

REQ-004 through REQ-017 (excluding REQ-009, REQ-010): correctly out of scope for the test
harness; verified by code inspection as recorded in REQUIREMENTS.md.

**Worst Spec issue**: none; all required coverage present, documented gap accurately described.

---

## Disposition

**APPROVED**

The first-pass BLOCKER (duplicate `Global Const` declarations) is resolved. The test file is
correct on both axes.

**Standards**: All naming conventions pass. `g_` prefix on framework globals is justified by
CODING_STANDARDS.md §Test File Conventions. `ConsoleWrite` usage is exempt under CR-03.
No code smells found. One informational note on `_SM_PascalCase` naming belongs to the module
under test, not this file.

**Spec**: All 17 REQs accounted for. REQ-003 Phase 2 behavioral gap is accurately documented
as expected and confirmed. `_Test_BatchUnknownServices` correctly asserts UNAVAILABLE outcomes
for all nonexistent services across all five relevant columns. `_Test_EmptyInput` correctly
verifies the no-stop-controls property. The `TEST DESIGN PHILOSOPHY` header is present and
substantive. Test results collectively tell a complete story about module behavior within the
constraints of the environment.

---

**Summary:** Standards — 0 hard violations, 1 informational note; Spec — 0 deficiencies,
1 informational note (scope change in `_Test_ResultArrayDimensions`), documented Phase 2 gap
confirmed accurate. Worst Standards issue: none. Worst Spec issue: none.
