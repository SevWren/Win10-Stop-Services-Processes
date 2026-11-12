# Code Review: Tests/ServiceManager.Tests.au3
Reviewer: T05 Independent Review Agent
Date: 2026-11-11
Branch: arch/service-manager-migration

## SHA-256 Hash
929f7fa47ee4db7bd42530ca8c54bd2adadbed1eb448098be0e1826a14b6f6b6

---

## Standards

### Findings

#### STD-001 — BLOCKER: Duplicate Global Const definitions cause AU3Check redefinition conflict

**Severity**: BLOCKER

**Location**: Lines 36–49 (test file) vs Lines 44–59 (Includes/ServiceManager.au3)

The test file declares the following as `Global Const`:

```
$SM_STATE_STOPPED, $SM_STATE_START_PENDING, $SM_STATE_STOP_PENDING,
$SM_STATE_RUNNING, $SM_STATE_CONTINUE_PENDING, $SM_STATE_PAUSE_PENDING,
$SM_STATE_PAUSED, $SM_OUTCOME_STOPPED, $SM_OUTCOME_ALREADY,
$SM_OUTCOME_UNAVAILABLE, $SM_OUTCOME_FAILED, $SM_OUTCOME_TIMEDOUT
```

`Includes/ServiceManager.au3` defines the identical names as `Global Const` (lines 44–59). When `#include "Includes\ServiceManager.au3"` is processed at line 397 of the test file, AutoIt 3.3.x encounters already-declared `Global Const` symbols and raises AU3Check warnings under `-w 3` / `-w 4`. The project's AU3Check invocation (`-q -d -w 1 -w 2 -w 3 -w 4`) will surface these as compilation warnings; depending on the AutoIt version and build toolchain, this may escalate to a compile error that prevents the test harness from running.

**Recommended fix**: Remove lines 36–49 from the test file entirely. The `#include` at line 397 is placed after all function definitions; because AutoIt compiles all `Func` blocks before executing the main body, the constants defined in `ServiceManager.au3` will be in scope when the test call sites (lines 402–414) execute. The test functions themselves reference these constants but are only *called* after the `#include` has been processed, so no forward-reference problem exists. Removing the duplicates eliminates the redefinition conflict with no functional change.

**Note on `$ERR_*` constants (lines 52–59)**: These use different names (`$ERR_ACCESS_DENIED`, `$ERR_SVC_NOT_EXIST`, etc.) from ServiceManager.au3's `$SM_ERR_*` constants, so they do NOT conflict and may be retained.

---

#### STD-002 — INFORMATIONAL: `#include` placement (line 397)

**Severity**: INFORMATIONAL

The `#include "Includes\ServiceManager.au3"` appears at line 397, well after all function definitions. The comment in the file correctly notes that AutoIt compiles all `Func` blocks first, making placement irrelevant to function availability. This is not a defect, but reviewers should be aware that any constants or globals defined in `ServiceManager.au3` are only available to the main-body code that runs after line 397 — not to the function bodies themselves at compile time. Since the functions only *call* these constants, and calls happen post-include, there is no actual issue. PASS with note.

---

#### STD-003 — PASS: `#RequireAdmin` present

Line 1 of the test file. Required by CODING_STANDARDS.md and CLAUDE.md. PASS.

---

#### STD-004 — PASS: Function naming conventions

- Framework helpers: `_TestAssert`, `_PrintResults`, `_BuildExpectedRow` — no `_Test_` prefix, correctly distinguishing framework from test cases.
- Test functions: `_Test_ServiceStateToString`, `_Test_Win32ErrToOutcome`, `_Test_IsStopEligible`, `_Test_BuildResultRow`, `_Test_ResultArrayDimensions`, `_Test_SingleFailureInBatch`, `_Test_SharedTimeout`, `_Test_StateToOutcomeRouting`, `_Test_AllSevenStates`, `_Test_EmptyInput`, `_Test_UnavailableInBatch` — all follow `_Test_PascalCase`.
- PASS.

---

#### STD-005 — PASS: Includes

Only `<AutoItConstants.au3>`, `<MsgBoxConstants.au3>`, and `Includes\ServiceManager.au3` are included. No disallowed production includes. PASS.

---

#### STD-006 — PASS: Variable declarations

All variables in function bodies use `Local`. Global test counters (`$g_iTestCount`, etc.) use `Global`. No undeclared variables detected. PASS.

---

#### STD-007 — PASS: `ConsoleWrite` usage in test harness

CODING_STANDARDS.md restricts direct `ConsoleWrite` calls for production runtime log messages. The test harness is not production code; `ConsoleWrite` for test output is the correct and expected pattern. PASS.

---

### Summary

One BLOCKER identified: duplicate `Global Const` definitions for the 12 `$SM_STATE_*` and `$SM_OUTCOME_*` constants conflict with the same declarations in `ServiceManager.au3`. This will produce AU3Check warnings under the project's required flags and may prevent compilation. All other standards checks pass.

---

## Spec

### Findings

#### SPEC-001 — PASS: REQ-009 — No live stop controls to production services

No test calls `_SM_StopServicesBatch` with real Windows service names (wuauserv, TrustedInstaller, UsoSvc, etc.). The only call to `_SM_StopServicesBatch` is in `_Test_EmptyInput()` (line 368) with a zero-length array. The implementation returns immediately for empty input without opening the SCM, making this safe. PASS.

---

#### SPEC-002 — PASS: REQ-002 — All 7 service states covered

`_Test_ServiceStateToString()` explicitly tests states 1 through 7 and three out-of-range values (-1, 0, 99). `_Test_AllSevenStates()` additionally verifies the routing classification (ALREADY_STOPPED, polling, eligible, ineligible) for each of the 7 states. PASS.

---

#### SPEC-003 — PASS: REQ-001 — All 5 outcome codes tested

| Outcome | Test location |
|---|---|
| STOPPED | `_Test_ResultArrayDimensions` (line 253), `_Test_SingleFailureInBatch` (line 274), `_Test_UnavailableInBatch` (line 385) |
| ALREADY_STOPPED | `_Test_Win32ErrToOutcome` (line 155), `_Test_StateToOutcomeRouting` (line 309) |
| UNAVAILABLE | `_Test_Win32ErrToOutcome` (line 179), `_Test_UnavailableInBatch` (line 388) |
| FAILED | `_Test_Win32ErrToOutcome` (lines 158–176), `_Test_SingleFailureInBatch` (line 279) |
| TIMED_OUT | `_Test_SharedTimeout` (line 296) |

PASS.

---

#### SPEC-004 — PASS: REQ-001 — Single-service failure in batch tested

`_Test_SingleFailureInBatch()` constructs a 3-service batch where service[1] fails with WIN32=5 (ACCESS_DENIED) and asserts that services[0] and [2] retain STOPPED outcomes. PASS.

---

#### SPEC-005 — PASS: REQ-001 — Shared timeout tested

`_Test_SharedTimeout()` simulates a 2-service batch where one service times out (TIMED_OUT, final state STOP_PENDING=3) and the other stops successfully (STOPPED). PASS.

---

#### SPEC-006 — PASS: Empty input array tested

`_Test_EmptyInput()` calls `_SM_StopServicesBatch` with a zero-length array and asserts `@error = 0` and `UBound($aResults) = 0`. PASS.

---

#### SPEC-007 — PASS: All 8 required Win32 error code mappings tested

`_Test_Win32ErrToOutcome()` covers all error codes required by the spec:

| Code | Test line |
|---|---|
| 5 (ACCESS_DENIED) | 158 |
| 1051 (DEPENDENT_RUNNING) | 161 |
| 1052 (INVALID_CTRL) | 164 |
| 1060 (SVC_NOT_EXIST) | 179 |
| 1061 (CANNOT_ACCEPT) | 167 |
| 1062 (NOT_ACTIVE) | 155 |
| 1068 (DEPENDENCY_FAIL) | 170 |
| 1072 (MARKED_DELETE) | 173 |

PASS.

---

#### SPEC-008 — PASS: `_Test_AllSevenStates` covers all 7 states

States 1–7 are each addressed with at least one assertion testing their routing classification. State 2 (START_PENDING) additionally verifies the WIN32=1061 outcome mapping. PASS.

---

#### SPEC-009 — INFORMATIONAL: No integration-level coverage of Phase 2 polling loop

**Severity**: INFORMATIONAL

The test harness validates state/outcome accounting via simulated result arrays and verifies the pure-logic helpers. It does not test the Phase 2 polling loop in `_SM_StopServicesBatch` with a stub SCM layer (e.g., injected DllCall stubs or a mock service handle). This is consistent with the REQ-009 no-live-stop constraint and the ENVIRONMENT GATE note in the file header. The gap is acknowledged and acceptable for the current ticket scope (T03). Note for a future ticket: a Windows-side integration smoke test against a user-controllable test service would fully exercise the polling and timeout paths.

---

### Summary

All mandatory spec requirements (REQ-001, REQ-002, REQ-009) are satisfied. All 7 service states, all 5 outcome codes, all 8 Win32 error codes, single-service failure isolation, shared timeout, and empty input are explicitly tested. The only gap is the absence of a live Phase 2 polling integration test, which is explicitly out of scope per REQ-009 and T03.

---

## Disposition

**APPROVED WITH CONDITIONS**

The test harness is well-structured, correctly deterministic, and provides complete coverage of all spec requirements. One BLOCKER must be resolved before AU3Check compilation can succeed under the project's required flags:

**Required before merge**: Remove the duplicate `Global Const` declarations for `$SM_STATE_*` and `$SM_OUTCOME_*` from lines 36–49 of `Tests/ServiceManager.Tests.au3`. The `$ERR_*` constants (lines 52–59) are not duplicated in `ServiceManager.au3` and must be retained.

No spec deficiencies. No naming or structural violations beyond the constant conflict.

---

**Summary:** 1 Standards finding (1 hard, 0 judgement call) plus 1 INFORMATIONAL note; 0 Spec findings; worst Standards issue: BLOCKER — duplicate `Global Const` declarations for `$SM_STATE_*`/`$SM_OUTCOME_*` will cause AU3Check redefinition errors under the project's required flags; worst Spec issue: none (all requirements satisfied).
