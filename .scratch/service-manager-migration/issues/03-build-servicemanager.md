# 03: Build ServiceManager.au3 + Deterministic Test Harness

**What to build:** Create Includes/ServiceManager.au3 with the verified SCM adapter
and Tests/ServiceManager.Tests.au3 with the deterministic test harness. No live
service stops in tests. Must pass AU3Check -q -d -w 1 -w 2 -w 3 -w 4 (gate marked
NOT RUN in Linux sandbox). Must pass independent code-review (Standards + Spec axes).

**Blocked by:** 02 (Contracts and API verification must be complete first)

**Status:** ready-for-agent

- [ ] Research subagent: verify DllStructCreate layout for SERVICE_STATUS (7 DWORDs)
- [ ] Write Tests/ServiceManager.Tests.au3 (TDD: red first)
      Test all 7 service states, stop eligibility, missing service, access denied,
      single-service failure in a batch, shared timeout, per-service result rows
- [ ] Write Includes/ServiceManager.au3 (green pass)
      Public: _SM_StopServicesBatch(ByRef $aNames, $iBatchMs, $iPollMs)
      Returns 2D array: one row per service with [name, initial, final, outcome, win32err, ""]
- [ ] AU3Check gate (NOT RUN — Windows only; note in IMPLEMENTATION-AND-VERIFICATION.md)
- [ ] Code-review subagent (independent): Standards + Spec axes
- [ ] Write docs/reviews/REVIEW-ServiceManager.au3.md
- [ ] Write docs/reviews/REVIEW-ServiceManager.Tests.au3.md
