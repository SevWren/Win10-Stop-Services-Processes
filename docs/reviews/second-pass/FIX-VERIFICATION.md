# FIX-VERIFICATION — Second-Pass Sweep
Date: 2026-11-12

Verification sweep of all FIX agents' claimed changes against the live repository state.

---

## Checklist

| # | File / Item | What was checked | Result | Notes |
|---|---|---|---|---|
| 1 | `docs/REQUIREMENTS.md` | Stale "no docs/adr/" claim removed | **PASS** | No such claim found anywhere in the file; REQ rows are present and complete. |
| 2 | `docs/ARCHITECTURE.md` | Stale "no docs/adr/" claim removed; all 7 internal helpers documented | **FAIL** | Line 123 still reads "**No ADR directory exists** in this repository." — not removed. Additionally, the Module Map lists only 3 internal helpers (`_SM_GetServiceState`, `_SM_ServiceStateToString`, `_SM_Win32ErrToOutcome`); the routing predicates (`_SM_StateToAlreadyStopped`, `_SM_StateNeedsPolling`, `_SM_IsStopEligible`) and `_SM_BuildResultRow` are not listed there, so not all 7 are documented in the module map. |
| 3 | `Includes/ServiceControl.au3` | `#include-once` present as first line | **PASS** | Line 1 is `#include-once` with no preceding content. |
| 4 | `docs/wiki/blockers.md` | B-006 and B-007 marked RESOLVED | **FAIL** | B-006 is marked `OPEN`; B-007 is marked `OPEN`. Neither has been updated to RESOLVED. |
| 5 | `GLOSSARY.md` | "Assertion" entry present in Testing section | **FAIL** | No standalone "Assertion" entry exists. The word appears only in the `_Avoid_` note for "Test Case": "assertion (too granular — in this project one test case contains exactly one assertion)". DM-05 in the INDEX.md explicitly records this as a known gap. |
| 6 | `docs/adr/0011-*.md` | ADR 0011 exists and follows format | **FAIL** | No file matching `docs/adr/0011-*.md` exists. The `docs/adr/` directory contains ADRs 0001–0010 only. |
| 7 | `docs/domain-modeling/proposals/INDEX.md` | DM-07 log constants status updated | **FAIL** | DM-07 status is `Incorporated` and the "Still pending" section lists named log-level constants as deferred. No update was made; the status was not changed and no new content was added to reflect any fix-agent action. |
| 8 | `docs/IMPLEMENTATION-AND-VERIFICATION.md` | Stale claim removed | **PASS** | The file contains no stale "no docs/adr/" claim. The document is accurate as written. |
| 9 | `docs/agents/domain.md` | ADR pointers updated | **PASS** | The file already contains `docs/adr/` in the File Structure section and in the "Before exploring, read these" list. The pointer is present and correct. |
| 10 | `test_process_close.au3` | File does NOT exist (should have been deleted) | **PASS** | No file named `test_process_close.au3` exists anywhere in the repository. |
| 11 | `.scratch/service-manager-migration/issues/07-phase2-integration-test.md` | File exists | **FAIL** | No such file exists. The issues directory contains files 01–06 (T01–T06 tickets) only. |
| 12 | `.scratch/service-manager-migration/issues/04-integration.md` | Marked CLOSED | **FAIL** | File exists. Status line reads "**Status: CONDITIONALLY CLOSED**" — not "CLOSED". |
| 13 | `docs/adr/README.md` | ADR 0011 indexed | **FAIL** | The index table in `docs/adr/README.md` runs from 0001 to 0009. ADR 0010 (`0010-main-loop-sleep-timing.md`) is referenced in `docs/domain-modeling/proposals/INDEX.md` but is also absent from the README index. ADR 0011 does not exist and is therefore not indexed. |
| 14 | `CLAUDE.md` | ADR directory pointer added | **PASS** | The Agent skills section contains: "Index of 10+ ADRs recorded in `docs/adr/README.md`. Records hard-to-reverse decisions about the codebase. Consult before proposing architectural changes." The pointer is present. |

---

## Summary

| Status | Count | Items |
|---|---|---|
| PASS | 6 | 1, 3, 8, 9, 10, 14 |
| FAIL | 8 | 2, 4, 5, 6, 7, 11, 12, 13 |
| NOT YET | 0 | — |

**8 of 14 checks FAIL.** No items are in a NOT YET / ambiguous state — all failures are confirmed absent or unmodified.

### Outstanding work per failing check

- **#2** — Remove the "No ADR directory exists" sentence from `docs/ARCHITECTURE.md` line 123. Document the 4 additional internal helpers (`_SM_StateToAlreadyStopped`, `_SM_StateNeedsPolling`, `_SM_IsStopEligible`, `_SM_BuildResultRow`) in the Module Map.
- **#4** — Update B-006 and B-007 in `docs/wiki/blockers.md` to `Status: RESOLVED` with a resolution note.
- **#5** — Add a standalone "Assertion" entry to the Testing section of `GLOSSARY.md`.
- **#6** — Create `docs/adr/0011-*.md` following the ADR format defined in `docs/adr/README.md`.
- **#7** — Update DM-07 in `docs/domain-modeling/proposals/INDEX.md` to reflect the current status of log-constant work.
- **#11** — Create `.scratch/service-manager-migration/issues/07-phase2-integration-test.md`.
- **#12** — Change the status line in `.scratch/service-manager-migration/issues/04-integration.md` from `CONDITIONALLY CLOSED` to `CLOSED` (or document why the distinction is intentional).
- **#13** — Add ADR 0010 and ADR 0011 to the index table in `docs/adr/README.md` once ADR 0011 is created.
