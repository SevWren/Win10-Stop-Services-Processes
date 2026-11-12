# CR2-33 — Second-Pass Review: Scratch Issue Status Accuracy

**Reviewer**: Second-Pass Review Agent
**Date**: 2026-11-12
**Scope**: `.scratch/service-manager-migration/issues/01` through `06`; `docs/agents/issue-tracker.md`
**Standard**: `docs/agents/issue-tracker.md` (issue tracker conventions)

---

## Review Method

Each issue file was read in full. The claimed status in the `## Status` section was compared against:

1. The issue's own checklist items and "What remains open" disclosures.
2. Referenced evidence files (`CR-10-integration-review.md`, `REVIEW-ServiceManager.Tests.au3.md`, `README.md`).
3. The specific follow-up commits cited in the task brief (T1-10 for README; T1-08 for `_Test_BatchUnknownServices`).
4. The git log to confirm no PR has been pushed.

---

## Per-Issue Findings

### Issue 01 — `01-baseline-discovery.md`

**Claimed status**: `CLOSED`

**Verdict**: ACCURATE

The `## Status: CLOSED` section is present, correctly positioned at the bottom of the file, and fully supported. All checklist items are addressed by the delivered artifacts (`docs/BASELINE-INVENTORY.md`, toolchain availability entries in `docs/wiki/blockers.md`). No conditions or open items are recorded. Nothing remains open.

No action required.

---

### Issue 02 — `02-contracts-and-api-verification.md`

**Claimed status**: `CLOSED`

**Verdict**: ACCURATE

The `## Status: CLOSED` section is present and supported by the full set of delivered artifacts (`docs/REQUIREMENTS.md`, `docs/ARCHITECTURE.md`, two research docs, `GLOSSARY.md`). The status section itself acknowledges the naming drift finding from CR-10 (S-01) and correctly characterises it as a documentation drift defect that is not a blocker on the issue's deliverables.

No action required.

---

### Issue 03 — `03-build-servicemanager.md`

**Claimed status**: `CONDITIONALLY CLOSED`

**Task brief question**: T1-08 added `_Test_BatchUnknownServices`. Is this sufficient to resolve the Phase 2 test-gap condition, or does the condition remain?

**Finding**: The condition does NOT resolve. The original condition, as stated in the issue's "What remains open" section, is:

> "The two-phase batch algorithm (Phase 1 stop dispatch, Phase 2 shared-deadline polling) has no behavioral test coverage. `_Test_EmptyInput` is the only test that calls `_SM_StopServicesBatch` directly, and it passes an empty array — exercising only the SCM-open and early-return path. The Phase 2 polling loop is untested by the harness."

`_Test_BatchUnknownServices` (now present in `Tests/ServiceManager.Tests.au3` at line 465, called at line 516) calls `_SM_StopServicesBatch` with three deliberately non-existent service names. Because those services do not exist, `OpenServiceW` returns Win32 error 1060 for each one in Phase 1 — they are routed to `UNAVAILABLE` and removed from the pending list before Phase 2 begins. The test's own inline comment confirms this: "Phase 1: OpenServiceW → 1060" and "without entering Phase 2." See also the test-file header at lines 58–62.

The Phase 2 polling loop (`_SM_StopServicesBatch` polling pending services against a shared deadline) therefore remains untested by any test in the harness, including `_Test_BatchUnknownServices`. The test adds meaningful Phase 1 UNAVAILABLE-path coverage and a live SCM open/close exercise on Windows, which is valuable. But it does not address the specific gap the condition describes.

**Verdict**: `CONDITIONALLY CLOSED` status is accurate. The condition (Phase 2 polling loop untested) REMAINS unresolved. The issue status must not be changed to `CLOSED`.

No change to the issue file is required; the existing "What remains open" text already accurately describes the gap. The addition of `_Test_BatchUnknownServices` is correctly captured by the `Tests/ServiceManager.Tests.au3` artifact but does not retire the condition.

---

### Issue 04 — `04-integration.md`

**Claimed status**: `CONDITIONALLY CLOSED`

**Task brief question**: T1-10 is noted as having fixed the README. Is the README condition now RESOLVED?

**Finding**: The condition IS RESOLVED. `README.md` has been updated. Inspection confirms:

- The Service Management section now states "Stops a batch of **9 services** each cycle (every **10 seconds**) via `_SM_StopServicesBatch()` in `Includes/ServiceManager.au3`."
- All nine service names (`FDResPub`, `fdPHost`, `TrustedInstaller`, `wuauserv`, `UsoSvc`, `DoSvc`, `WaaSMedicSvc`, `SSDPSRV`, `sppsvc`) are enumerated with descriptions.
- The structured outcome codes (`STOPPED`, `ALREADY_STOPPED`, `UNAVAILABLE`, `FAILED`, `TIMED_OUT`) are documented.
- The batch-stop algorithm (single SCM open, shared deadline, no serial waiting) is described.
- Include paths are described as relative in the Module Structure section.

The issue's "What remains open" block stated: "README.md was not updated. CR-10 (SP-05, MINOR) confirms: the README still describes the old 6-service 2 s polling behavior." The README no longer describes old behavior. The SP-05 finding is satisfied.

**Verdict**: The condition cited in the `CONDITIONALLY CLOSED` status is now resolved. The issue **should be updated from `CONDITIONALLY CLOSED` to `CLOSED`**.

**Required change to issue file**: Update the `## Status` line from `CONDITIONALLY CLOSED` to `CLOSED`, update the opening sentence to remove "README.md was not updated despite being a checklist requirement," and add a resolution note referencing T1-10.

---

### Issue 05 — `05-independent-review.md`

**Claimed status**: `CONDITIONALLY CLOSED`

**Verdict**: ACCURATE

The status section is present and the MINOR open findings (S-01 through S-03, SP-05) are correctly listed with an accurate explanation that none required escalation under the enterprise prompt rule (BLOCKER/CRITICAL/MAJOR only). SP-05 (README not updated) is cross-referenced to issue 04; now that issue 04's condition is resolved, the SP-05 reference in this file is stale but does not change the issue's own disposition. Issue 05's work (three independent reviews, cross-file audit, all BLOCKER/CRITICAL/MAJOR findings resolved) is complete. The remaining open items in this file are all MINOR and explicitly accepted.

The `CONDITIONALLY CLOSED` status reflects that MINOR items remain acknowledged but not escalated — which is accurate per the enterprise prompt. Whether to downgrade to `CLOSED` now that SP-05 is resolved is a maintainer call; the other three MINOR items (S-01, S-02, S-03) remain open. `CONDITIONALLY CLOSED` is still defensible and accurate.

No required change. Status is accurate as-is.

---

### Issue 06 — `06-validation-and-delivery.md`

**Claimed status**: `CONDITIONALLY CLOSED`

**Task brief question**: "No PR opened" — is this still the case?

**Finding**: YES, still the case. The git log confirms the last three commits on `arch/service-manager-migration` are `1d8a5ea`, `2a62801`, and `09b99ba`. There is no push commit and no PR-creation commit in the log. No `gh pr create` or push-to-remote has been recorded. The branch has not been pushed to GitHub; `git push` and PR creation were not performed.

The issue's "What remains open" block lists both "No PR opened" and the README not updated. The README is now updated (T1-10), which retires one of the two open items. However, no PR has been opened, so the second open item stands.

**Verdict**: `CONDITIONALLY CLOSED` status is accurate. The condition "No PR opened" remains. The README condition has been resolved (see issue 04 above), so the issue's "What remains open" text is now partially stale on the README item — but the PR condition alone is sufficient to hold `CONDITIONALLY CLOSED`.

**Recommended (non-blocking) update**: The "What remains open" block in this file lists README not updated as an open item. Since T1-10 resolved the README, that bullet should be removed or updated to reflect resolution. The PR bullet remains. This is a documentation accuracy fix, not a status change.

---

## `docs/agents/issue-tracker.md` Accuracy Check

**Finding**: The issue tracker index is significantly stale. It reflects the state of the repository at or before the start of agent work, not the current post-completion state. Specific inaccuracies:

| Column | Current index value | Actual current value |
|---|---|---|
| Status for all six issues | `ready-for-agent` | 01: CLOSED; 02: CLOSED; 03: CONDITIONALLY CLOSED; 04: CONDITIONALLY CLOSED (should be CLOSED after T1-10); 05: CONDITIONALLY CLOSED; 06: CONDITIONALLY CLOSED |
| "Frontier (open, unblocked, unclaimed)" | "01 only" | No frontier — all issues have been worked; the frontier description is wholly inaccurate |
| "All six issues are in ... None have been moved to closed/" | Implies none are closed | Issues 01 and 02 are CLOSED; issues 03–06 are CONDITIONALLY CLOSED |

The `## Current Issue Status` section of `docs/agents/issue-tracker.md` was written at triage time and was never updated to reflect execution outcomes. The status table shows `ready-for-agent` for all six rows, which is factually wrong for every row.

**Verdict**: `docs/agents/issue-tracker.md` does NOT accurately reflect current issue statuses. The status table must be updated.

---

## Summary of Required Actions

| Item | Action | Priority |
|---|---|---|
| Issue 04 `## Status` | Change from `CONDITIONALLY CLOSED` to `CLOSED`; add T1-10 resolution note | Required |
| Issue 06 "What remains open" | Remove or update the README bullet (now resolved by T1-10); retain PR bullet | Recommended |
| `docs/agents/issue-tracker.md` status table | Update all six rows from `ready-for-agent` to their actual closed/conditional statuses; update frontier text | Required |

Issues 01, 02, 03, and 05 require no changes. Issue 03's `CONDITIONALLY CLOSED` status is correct; `_Test_BatchUnknownServices` does not resolve the Phase 2 coverage gap condition.

---

## Disposition

Three of the six issue files are accurate as written (01, 02, 05). One issue (03) has an accurate status but its condition is confirmed unresolved by `_Test_BatchUnknownServices`. One issue (04) has a stale `CONDITIONALLY CLOSED` status that should now be `CLOSED` following T1-10. One issue (06) has an accurate status but a partially stale "What remains open" block. The `docs/agents/issue-tracker.md` status table is entirely stale and requires a full update.
