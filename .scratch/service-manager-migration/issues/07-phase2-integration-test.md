# 07: Phase 1/Phase 2 Integration Tests for `_SM_StopServicesBatch`

**What to build:** Integration tests that call `_SM_StopServicesBatch` with a non-trivial service list — services in RUNNING or STOP_PENDING state — and verify that the two-phase batch algorithm executes correctly end-to-end. Phase 1 (stop-control dispatch to all eligible services without serial waiting) and Phase 2 (shared-deadline polling across all pending services until each reaches STOPPED or the deadline expires) currently have zero behavioral test coverage. All existing batch-level assertions use manually constructed result arrays; they test outcome-accounting logic in isolation, not the algorithm that produces those outcomes. The one SCM-touching integration test added this session (`_Test_BatchUnknownServices`) exercises only the UNAVAILABLE path in Phase 1 — services that do not exist never enter the Phase 2 `While` loop. A new test file (or new test functions in a Windows-only harness) must call the real `_SM_StopServicesBatch` with services that are actually RUNNING or STOP_PENDING at test time and assert on the Phase 2 result: either all polled services reach `$SM_OUTCOME_STOPPED` within the shared deadline, or at least one reaches `$SM_OUTCOME_TIMEDOUT` with a final state of STOP_PENDING, depending on which scenario is exercised.

**Blocked by:** B-001 (Windows toolchain — AU3Check, AutoIt runtime not available in Linux sandbox)

**Status:** needs-triage

---

## Background

The two-phase design is specified in REQ-003 and documented in `docs/ARCHITECTURE.md`. The gap was first identified in the independent code review as CR-03 P-03 ("the two-phase batch algorithm has no behavioral test coverage; all batch-level tests use manually constructed arrays rather than exercising `_SM_StopServicesBatch` with any input that reaches Phase 2") and is recorded as an open blocker in `docs/wiki/blockers.md` B-004.

The constraint driving the gap: the existing test harness (`Tests/ServiceManager.Tests.au3`) is written under REQ-009, which prohibits live stop controls against production service names. The only SCM-touching tests use names guaranteed not to exist (`__TestHarness_NX_Svc1__`, etc.), ensuring Phase 1 routes all services to UNAVAILABLE and returns before Phase 2 begins. This is intentional and correct for the deterministic harness, but it means Phase 2 has never been exercised by any test.

---

## Acceptance Criteria

- [ ] At least one test calls `_SM_StopServicesBatch` with a list of one or more services that are genuinely RUNNING or STOP_PENDING at the time of the call.
- [ ] The test asserts on Phase 2 completion behavior: either `$SM_OUTCOME_STOPPED` for every service (success path) or `$SM_OUTCOME_TIMEDOUT` with `finalState = $SM_STATE_STOP_PENDING` for any service that does not stop within the shared deadline (timeout path).
- [ ] The test asserts that `@error = 0` (SCM opened successfully) and that the result array has one row per input service with 6 columns.
- [ ] The test asserts that the shared-deadline property holds: no individual service is given its own independent timeout; all services are polled against the same deadline timestamp.
- [ ] The test file carries a clear environment gate comment (Windows + admin required; NOT RUN in the Linux sandbox) and uses `#RequireAdmin`.
- [ ] AU3Check passes at `-q -d -w 1 -w 2 -w 3 -w 4` with no warnings.

---

## Suggested Approach

Two non-exclusive strategies:

**Strategy A — Live safe-to-stop services (preferred for the timeout path)**

Identify one or two Windows services that are safe to stop in a test environment (e.g., `Spooler` on a machine with no active print jobs, or a purpose-created dummy service registered with `sc create`). Start them, call `_SM_StopServicesBatch`, and assert the STOPPED outcome. This exercises the full Phase 1 → Phase 2 happy path with a real state transition.

For the timeout path: use a deliberately short `$SM_TIMEOUT_SEC` override (or a wrapper that injects a near-zero deadline) with a service that is known to take longer than that to stop, then assert `$SM_OUTCOME_TIMEDOUT`.

**Strategy B — DllCall stub/intercept layer (preferred for deterministic CI)**

Introduce a stub layer that intercepts the `OpenSCManagerW`, `OpenServiceW`, `QueryServiceStatus`, and `ControlService` DllCall sites in `ServiceManager.au3`. The stub returns controlled state sequences (e.g., RUNNING on first query, STOP_PENDING on second, STOPPED on third) without touching the live SCM. This allows Phase 2 polling to be exercised deterministically in any environment, including CI, without admin and without real services. This requires either a DllCall interception mechanism or a refactor of `ServiceManager.au3` to accept injected function references for the SCM calls.

Strategy B is the more robust long-term solution but requires a design decision about how to wire in the stubs (ADR candidate).

---

## Tasks

- [ ] Decide between Strategy A, Strategy B, or both (maintainer triage decision — record outcome here)
- [ ] If Strategy A: identify one or two safe-to-stop services available on the target Windows environment; document them in a comment in the test file
- [ ] If Strategy B: draft an ADR for DllCall interception / function-reference injection in `ServiceManager.au3`; get it reviewed before implementation
- [ ] Write test functions targeting Phase 2 happy path (all services reach STOPPED)
- [ ] Write test functions targeting Phase 2 timeout path (at least one service remains STOP_PENDING past deadline)
- [ ] Verify `@error = 0`, row count, column count, and per-row outcome fields in both paths
- [ ] Run AU3Check `-q -d -w 1 -w 2 -w 3 -w 4` on the new test file — confirm zero warnings
- [ ] Run the test harness on Windows with AutoIt installed — confirm all new assertions pass
- [ ] Update `docs/wiki/blockers.md` B-004 status from OPEN to RESOLVED once tests pass
- [ ] Update `docs/agents/issue-tracker.md` issue table to include this ticket

---

## Source references

- Blocker: `docs/wiki/blockers.md` §B-004
- Original finding: `docs/reviews/session/CR-03-test-suite.md` §P-03
- Current test state: `Tests/ServiceManager.Tests.au3` — `_Test_BatchUnknownServices` (Phase 1 UNAVAILABLE path only)
- Requirement: `docs/REQUIREMENTS.md` REQ-003 (two-phase batch design)
- Windows toolchain blocker: `docs/wiki/blockers.md` §B-001

## Comments

*(none yet)*
