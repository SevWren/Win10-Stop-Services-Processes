# Commit Verification Report

**Branch:** arch/service-manager-migration
**Verified:** 2026-11-12
**Target commit:** ccf5ee2

---

## Check Results

| # | Check | Expected | Actual | Result |
|---|-------|----------|--------|--------|
| 1 | Latest commit hash and message | `ccf5ee2` starting "feat: multi-swarm architecture review" | `ccf5ee2 feat: multi-swarm architecture review, domain modeling, and hardening` | PASS |
| 2 | Files changed / insertions | 121 files changed, 18418 insertions | 121 files changed, 18418 insertions(+), 345 deletions(-) | PASS |
| 3 | Working tree clean | No modified, staged, or untracked files | `nothing to commit, working tree clean` | PASS |
| 4 | Key files present in commit | GLOSSARY.md, ServiceManager.au3, Tests, docs/adr | All present (see detail below) | PASS |
| 5 | test_process_close.au3 removed | `git ls-files` returns nothing | No output (file not tracked) | PASS |

---

## Check 4 — Key Files Detail

The following key files were confirmed present in the HEAD commit:

- `GLOSSARY.md`
- `Includes/ServiceManager.au3`
- `Tests/ServiceManager.Tests.au3`
- `docs/adr/0001-servicemanager-module-extraction.md`
- `docs/adr/0002-start-pending-stop-ineligible.md`
- `docs/adr/0003-batch-stop-two-level-error-convention.md`
- `docs/adr/0004-servicemanager-incompatible-with-servicecontrol-error-convention.md`
- `docs/adr/0005-graceful-only-service-stop.md`
- `docs/adr/0006-batch-scoped-scm-handle.md`
- `docs/adr/0007-autoit-priority-constants-canonical.md`
- `docs/adr/0008-direct-dllcall-advapi32.md`
- `docs/adr/0009-queryservicestatus-api-selection.md`
- `docs/adr/0010-main-loop-sleep-timing.md`
- `docs/adr/0011-servicecontrol-servicemanager-boundary-convention.md`
- `docs/adr/README.md`
- `docs/reviews/REVIEW-ServiceManager.Tests.au3.md`
- `docs/reviews/REVIEW-ServiceManager.au3.md`

---

## Overall Verdict: PASS

All 5 checks passed. The commit `ccf5ee2` is verified as correct and complete.
