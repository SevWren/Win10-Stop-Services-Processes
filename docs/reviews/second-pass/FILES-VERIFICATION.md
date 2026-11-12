# Files Verification Report

**Date**: 2026-11-12
**Scope**: Critical deliverables check per second-pass verification spec.

---

## Results

| # | Check | Status | Notes |
|---|---|---|---|
| 1 | `docs/adr/README.md` indexes 11 ADRs (0001–0011) | PASS | File exists. README index table contains all 11 entries: 0001 through 0011. |
| 2 | All 11 ADR files exist (0001–0011) | PASS | All 11 files present: `0001-servicemanager-module-extraction.md` through `0011-servicecontrol-servicemanager-boundary-convention.md`. |
| 3 | `GLOSSARY.md` has 51+ terms, zero variable/function names as terms | PASS | 51 bold-term entries counted (`grep -c "^\*\*"`). No term headings start with `$` or `_`. |
| 4 | `Includes/ServiceManager.au3` contains `_SM_StopServicesBatch` and `$LOG_LEVEL_ERROR` | PASS | Both identifiers are present as live code. |
| 5 | `Includes/ServiceManager.au3` does NOT contain `$iPendLen2` as a variable | PASS | `$iPendLen2` appears only inside a comment on line 198 describing a previous fix; it is not declared or used as a variable. |
| 6 | `Tests/ServiceManager.Tests.au3` contains `_Test_BatchUnknownServices` | PASS | Function is defined (line 465) and called (line 516). |
| 7 | `Tests/ServiceManager.Tests.au3` does NOT contain `_BuildExpectedRow` as a function | PASS | `_BuildExpectedRow` appears only in a comment on line 50 describing its prior removal; not defined or called. |
| 8 | `Stop Services Processes.au3` contains `_KillProcessList`, `_MiscPopups`, `_Exit`, `$aSvcTargetNames` | PASS | All four identifiers present as live code. |
| 9 | `Includes/ServiceControl.au3` first line is `#include-once` | PASS | `head -1` output is exactly `#include-once`. |
| 10 | `docs/domain-modeling/DOMAIN-MODEL.md` exists | PASS | File found at `/home/vercel-sandbox/repo/docs/domain-modeling/DOMAIN-MODEL.md`. |
| 11 | `.scratch/service-manager-migration/issues/07-phase2-integration-test.md` exists | PASS | File found at `/home/vercel-sandbox/repo/.scratch/service-manager-migration/issues/07-phase2-integration-test.md`. |
| 12 | `test_process_close.au3` does NOT exist | PASS | File is absent from the repo root. |

---

## Summary

**All 12 checks: PASS.**

No failures, no missing files, no prohibited content found.
