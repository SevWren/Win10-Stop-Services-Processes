# DM-05 — Test Vocabulary Proposals

**Focus area:** Testing vocabulary and concepts as used in this project.
**Source analyzed:** `Tests/ServiceManager.Tests.au3`, `docs/ARCHITECTURE.md`, `.agents/skills/tdd/tests.md`, `.agents/skills/tdd/mocking.md`
**Status:** Proposal — do not merge to GLOSSARY.md without review

---

## Summary

The project has one test file (`Tests/ServiceManager.Tests.au3`) with a hand-rolled test framework in AutoIt. No third-party test runner exists. The vocabulary below is grounded entirely in what the file actually does and what the project documents say.

---

## Proposed Terms

### Test Harness

The single AutoIt script (`Tests/ServiceManager.Tests.au3`) that runs all tests for `ServiceManager.au3`. It owns the test framework globals, the assertion helper, and the result printer. It is executed directly by the AutoIt runtime (`AutoIt3.exe`) and exits with code 0 (all pass) or 1 (any failure).

_Avoid_: test suite (overloaded; see below), test runner (implies a separate tool, which does not exist here)

---

### Test Case

One call to `_TestAssert(...)` — a named boolean check with an optional expected/actual pair. Each test case increments `$g_iTestCount` and either `$g_iPassCount` or `$g_iFailCount`. A test case maps to a single observable property of the function under test (e.g., `"state 4 (RUNNING) → eligible for stop"`).

_Avoid_: assertion (too granular; in this project one test case = one assertion), test (ambiguous — could mean the whole harness or a single check)

---

### Test Function

An AutoIt `Func` whose name begins with `_Test_` and whose body contains one or more related test cases against a single function under test (e.g., `_Test_IsStopEligible()`). Test functions are called explicitly from the main body of the harness in declaration order. There is no auto-discovery.

_Avoid_: test suite (see below), spec, describe block (terminology from frameworks that do not exist here)

---

### Test Suite

The complete set of test functions in the harness, taken together. In this project the suite is flat: all test functions are peers, there is no nesting or grouping beyond AutoIt `Func` boundaries.

_Avoid_: spec file, test module

---

### Assertion

The boolean expression passed as the second argument to `_TestAssert(...)`. An assertion evaluates to `True` or `False` and determines whether the test case passes or fails. In this project every test case contains exactly one assertion.

_Avoid_: expect, matcher (Jest/Jasmine terminology that does not apply here)

---

### Stub (in this project)

An AutoIt `Func` defined in the test harness that replaces a DllCall-layer function with a fixed, scripted return value, so that the function under test can be exercised without issuing live Windows SCM calls. Stubs in this project have no behavior of their own: they return a predetermined value and nothing else.

Concrete examples:
- `_BuildExpectedRow(...)` — builds a result row with known values, bypassing `_SM_BuildResultRow` internals.
- The harness header states explicitly: "All tests run against stub helper functions defined below that simulate SCM responses. Live SCM calls are NOT made from this harness."

_Avoid_: mock (a mock additionally verifies that it was called in a specific way; nothing in this harness does that), fake (a fake has working internal logic; stubs here are fixed-value-only)

---

### Mock

Not used in this project. The harness does not verify that any function was called, how many times, or with what arguments. The term "mock" appears in comments informally but no mock objects or mock verification are implemented.

Note: `.agents/skills/tdd/mocking.md` defines mocks as appropriate only at system boundaries (external APIs, OS calls). The Windows SCM DllCall layer is exactly such a boundary — but the harness bypasses it via stubs rather than mock objects.

_Avoid_: using "mock" to mean "stub" in this codebase — the two are distinct

---

### Fake

Not used in this project. No fake objects with working internal logic are present in the harness.

---

### Deterministic Test

A test that produces the same pass/fail result regardless of the state of the Windows SCM, running services, or any other live system resource. All tests in this harness are deterministic by design. The harness header marks this as a deliberate property: "No live service stop controls are issued in this harness."

_Avoid_: unit test (see below for the distinction this project actually uses)

---

### Unit Test (in this project)

A test case exercising a **pure-logic or pure-mapping function** — one that takes inputs and returns outputs with no DllCall, no global state mutation, and no I/O. The harness labels four groups explicitly as "pure-logic helpers" or "pure mapping function":

- `_SM_ServiceStateToString` — integer → string mapping
- `_SM_Win32ErrToOutcome` — Win32 error code → outcome string mapping
- `_SM_IsStopEligible` — service state integer → boolean eligibility
- `_SM_BuildResultRow` — constructor for a result row array

These are the closest thing this project has to unit tests in the classic sense.

_Avoid_: "unit" for tests that call `_SM_StopServicesBatch` with a live SCM — those are integration tests (see below)

---

### Integration Test (in this project)

A test case that calls `_SM_StopServicesBatch(...)` against a live SCM handle, exercising the full DllCall chain through `advapi32.dll`. The harness contains one such test (`_Test_EmptyInput`) which calls `_SM_StopServicesBatch` with an empty array and checks that `@error = 0` and the result array is empty.

This is the boundary: `_Test_EmptyInput` calls the real function, which opens a real SCM handle (requiring `#RequireAdmin` at the top of the harness). All other test functions operate on data only and never open a SCM handle.

_Avoid_: calling `_Test_EmptyInput` a unit test — it exercises live Windows APIs

---

### Environment Gate

The constraint that the test harness requires the Windows AutoIt runtime and therefore cannot run in a Linux sandbox. Documented in the harness header: "This harness requires Windows (AutoIt runtime). It is marked NOT RUN in the Linux sandbox." AU3Check static analysis is also Windows-only.

---

### Exit Code Convention

The harness exits with code `0` when all test cases pass and `1` when any test case fails. This is described in the harness as "CI-friendly." No CI pipeline currently consumes this, but the convention is established.

---

## Terms Explicitly Out of Scope for GLOSSARY.md

The following are general programming concepts that the glossary format rules exclude — they should not be added to GLOSSARY.md even though they appear in the harness:

- `@error` — standard AutoIt macro, not project-specific
- `ConsoleWrite` — standard AutoIt built-in
- `Global $g_iTestCount / $g_iPassCount / $g_iFailCount` — implementation detail of the harness, not domain vocabulary
- Win32 error codes (`5`, `1051`, `1060`, etc.) — Windows API constants, not invented by this project

---

## Open Questions for Review

1. **"Stub" vs "helper"**: The harness uses the word "stub" in its own comments (`; Stub result row builder`). Should the glossary adopt "stub" as the canonical term, or is "test helper" less loaded and more accurate given that `_BuildExpectedRow` has no dependency-replacement purpose?

2. **"Deterministic test" vs "unit test"**: The harness avoids the term "unit test" entirely and uses "deterministic" instead. Is "deterministic test" the preferred canonical term for this project, or should "unit test (pure-logic)" be preferred for familiarity?

3. **`_Test_EmptyInput` classification**: This test calls `_SM_StopServicesBatch` with a live SCM. It is currently classified here as an integration test. If the intent was to keep it deterministic, it may be a design oversight worth flagging.
