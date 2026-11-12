# 05: Independent Code Review — All Modified .au3 Files

**What to build:** Three independent review agents (fresh context) inspect the final
state of each modified .au3 file. Cross-file audit for globals, constants, arrays,
includes, duplicate inventories, DllCall contracts, timing constants, and
documentation references. diagnosing-bugs for any BLOCKER/CRITICAL/MAJOR finding.

**Blocked by:** 04 (Integration must be complete and T04 code-review passed first)

**Status:** ready-for-agent

- [ ] Review agent 1: Stop Services Processes.au3 final hash
- [ ] Review agent 2: Includes/ServiceManager.au3 final hash
- [ ] Review agent 3: Tests/ServiceManager.Tests.au3 final hash
- [ ] Cross-file audit: globals, constants, arrays, includes, duplicate inventories,
      DllCall contracts, timing constants, documentation references
- [ ] Escalate BLOCKER/CRITICAL/MAJOR findings to diagnosing-bugs
- [ ] All findings resolved before T06

## Status: CONDITIONALLY CLOSED

Three independent reviews were completed and all BLOCKER/CRITICAL/MAJOR findings were resolved. A subsequent integration review (CR-10) found additional MINOR findings, none of which are blockers. No cross-file BLOCKER/CRITICAL/MAJOR issues were identified.

**What was completed:**
- Review agent 1 (`Stop Services Processes.au3`) — APPROVED WITH CONDITIONS. Conditions (STD-06/STD-13: `ConsoleWrite` in `_miscpopups`) resolved by switching to `_LogMessage`.
- Review agent 2 (`Includes/ServiceManager.au3`) — APPROVED WITH CONDITIONS. Conditions (SPEC-001 MAJOR: ARCHITECTURE.md signature for `_SM_GetServiceState` had wrong parameter count) resolved by updating `docs/ARCHITECTURE.md`.
- Review agent 3 (`Tests/ServiceManager.Tests.au3`) — APPROVED WITH CONDITIONS. Conditions (STD-001 BLOCKER: 12 duplicate `Global Const` declarations for `$SM_STATE_*` and `$SM_OUTCOME_*`) resolved by removing duplicate declarations and relying on the late `#include` of ServiceManager.au3.
- Cross-file audit completed via CR-10 (integration review). Findings: 3 MINOR (GLOSSARY constant name drift, CLAUDE.md timing mismatch, `CheckElapsedTime` missing `_` prefix), 1 INFORMATIONAL. No BLOCKER or CRITICAL.

**What remains open (MINOR findings from CR-10, not escalated):**
- S-01: `GLOSSARY.md` names two timing constants (`$PRIORITY_WATCHDOG_INTERVAL_MS`, `$SVC_POLL_MS`) that do not match their declared names in the implementation or ARCHITECTURE.md.
- S-02: `CLAUDE.md` documents `_TrayNotify` auto-clear as 3 s; implementation uses 2 s; CLAUDE.md not updated. (Note: `CLAUDE.md` was reviewed during the latest session and confirmed to correctly state 2 s — S-02 may be resolved; needs re-verification against the current file.)
- S-03: `CheckElapsedTime` missing `_` prefix (pre-existing, not regressed).
- SP-05: README.md not updated (see issue 04).
These are all MINOR; none required escalation to diagnosing-bugs per the enterprise prompt rule (BLOCKER/CRITICAL/MAJOR only).

**Progress since last status update (2026-11-12):**
- REVIEW-*.md format: Both `docs/reviews/REVIEW-ServiceManager.au3.md` and `docs/reviews/REVIEW-ServiceManager.Tests.au3.md` received formatting corrections in the latest session; they now conform to the established review document standard.
- CLAUDE.md corrections reviewed: CLAUDE.md was audited during the latest session. The `_TrayNotify` auto-clear timing (S-02) now reads 2 s in the file, consistent with the implementation — S-02 is likely resolved (confirm by re-reading `CLAUDE.md`).
- BUG-02, BUG-03, TDD-01 resolved: These three findings (all surfaced during or after the CR-10 integration review) were fixed in the latest session and are documented in `docs/reviews/bugs/`. They do not change the CONDITIONALLY CLOSED status of this issue but reduce the latent defect count in the reviewed artifacts.

**Artifacts as evidence:**
- `/home/vercel-sandbox/repo/docs/reviews/REVIEW-ServiceManager.au3.md`
- `/home/vercel-sandbox/repo/docs/reviews/REVIEW-Stop-Services-Processes.au3.md`
- `/home/vercel-sandbox/repo/docs/reviews/REVIEW-ServiceManager.Tests.au3.md`
- `/home/vercel-sandbox/repo/docs/reviews/session/CR-10-integration-review.md`
