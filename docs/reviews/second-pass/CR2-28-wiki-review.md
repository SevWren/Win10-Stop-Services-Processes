---
review: CR2-28
reviewer: second-pass agent
date: 2026-11-12
scope: docs/wiki/index.md, docs/wiki/environment.md, docs/wiki/decisions.md, docs/wiki/blockers.md
standards: CODING_STANDARDS.md, codebase state
verdict: CONDITIONAL PASS — 2 defects require resolution before wiki is considered current
---

# CR2-28 — Wiki Second-Pass Review

## Summary

Four wiki documents were reviewed against `CODING_STANDARDS.md` and the current codebase state.
Three of the four documents are accurate and consistent with the codebase. One document
(`blockers.md`) contains two stale OPEN statuses that contradict the task completion record:
B-006 and B-007 are marked OPEN but should be RESOLVED per T1-10 (README fixed) and T2-11
(GLOSSARY fixed) respectively.

---

## index.md

### Module structure table

**PASS.** The table contains four rows:

| File | Verdict |
|---|---|
| `Stop Services Processes.au3` | Present in repo root. Role description accurate. |
| `Includes/ServiceManager.au3` | Present. Deep-module description and public entry point correct. |
| `Includes/ServiceControl.au3` | Present. Retained-only-for-non-stop-helpers description correct. |
| `Tests/ServiceManager.Tests.au3` | Present. Test-harness-only description correct. |

No files are listed that do not exist. No codebase files are omitted from the table.

### Ticket statuses

**PASS — with observation.** All six tickets T01–T06 are present in the Status table. All six
carry status `complete`. The table covers exactly the six work phases of the
`arch/service-manager-migration` effort. No ticket is missing; no extra ticket is listed.

Observation: the Status column uses only the single value `complete` across all rows. There
is no defined ticket-status vocabulary enumerated in the index (e.g., open / in-progress /
complete / blocked). This is not a defect in the wiki — the effort is complete — but future
reviewers should note that this table does not model intermediate ticket states.

### Links

**PASS.**

- `[docs/ARCHITECTURE.md](../ARCHITECTURE.md)` — resolves to `/repo/docs/ARCHITECTURE.md`.
  File exists. Link valid.
- `[GLOSSARY.md](../../GLOSSARY.md)` — resolves to `/repo/GLOSSARY.md`.
  File exists. Link valid.

---

## environment.md

### Linux sandbox limitation

**PASS.** The constraint is documented under "Test Harness → Linux sandbox limitation"
(lines 35–42). The text accurately states that `AutoIt3.exe` and `AutoIt3_x64.exe` are
unavailable and that functional test execution requires a Windows environment with
AutoIt 3.3.16.x installed.

### AU3Check command

**PASS.** The documented command is:

```
au3check -q -d -w 1 -w 2 -w 3 -w 4 <file.au3>
```

This matches the flags specified in `CODING_STANDARDS.md` section "AU3Check Compliance":
`AU3Check -q -d -w 1 -w 2 -w 3 -w 4`. Flag set is complete and correct.

### Codebase files table

**PASS.** The table lists four `.au3` files. All four exist in the repository. Include
directives listed for each file are consistent with the actual `#include` statements used
in the codebase. Notes column accurately identifies the test harness as never `#include`d
by the main script.

### No-workarounds rule — sole stop path naming

**PASS.** The No-Workarounds Rule section (lines 84–87) explicitly names `ServiceManager.au3`
as the sole authoritative stop path:

> `ServiceManager.au3` is the sole authoritative stop path as of T04 integration

`ServiceControl.au3` is correctly identified as not being an active stop path. This is
consistent with D-002 in `decisions.md` and the integration point documented in
`docs/ARCHITECTURE.md`.

---

## decisions.md

### All 8 decisions present (D-001 through D-008)

**PASS.** All eight decision entries are present and in order.

| Entry | Present | Has ADR link |
|---|---|---|
| D-001 — Local Markdown Issue Tracker | Yes | No (pre-ADR decision; none expected) |
| D-002 — ServiceManager Supersedes ServiceControl for Stopping | Yes | No (pre-ADR decision; none expected) |
| D-003 — ServiceManager Module Extraction | Yes | Yes |
| D-004 — START_PENDING Handled as Stop-Ineligible | Yes | Yes |
| D-005 — Graceful-Only Service Stop | Yes | Yes |
| D-006 — Batch-Scoped SCM Handle | Yes | Yes |
| D-007 — AutoIt Priority Constants as Canonical Internal Form | Yes | Yes |
| D-008 — Direct DllCall to advapi32.dll for SCM Operations | Yes | Yes |

### ADR link validity

**PASS.** All six ADR links point to files that exist under `docs/adr/`:

| Decision | ADR path in decisions.md | File exists |
|---|---|---|
| D-003 | `docs/adr/0001-servicemanager-module-extraction.md` | Yes |
| D-004 | `docs/adr/0002-start-pending-stop-ineligible.md` | Yes |
| D-005 | `docs/adr/0005-graceful-only-service-stop.md` | Yes |
| D-006 | `docs/adr/0006-batch-scoped-scm-handle.md` | Yes |
| D-007 | `docs/adr/0007-autoit-priority-constants-canonical.md` | Yes |
| D-008 | `docs/adr/0008-direct-dllcall-advapi32.md` | Yes |

No broken ADR links found. Note that ADRs 0003, 0004, 0009, and 0010 exist in `docs/adr/`
but are not referenced from `decisions.md`; this is expected because those ADRs support
decisions not recorded as named D-NNN entries in this log.

---

## blockers.md

### B-001 through B-007 present

**PASS.** All seven blocker entries are present. Entries B-001, B-002, B-003, B-004, B-005,
B-006, and B-007 all appear in the file in numeric order.

### B-006 — README.md Not Updated

**DEFECT — STALE STATUS.**

Current status in file: `OPEN`

Expected status: `RESOLVED`

Rationale: The task description states that T1-10 fixed README. If T1-10 has been completed
and the README was updated to reflect the new `_SM_StopServicesBatch` / `ServiceManager.au3`
stop path, the expanded 9-service inventory, the revised poll interval, and the
working-directory-relative include paths, then B-006 should be marked `RESOLVED` with a
reference to T1-10 as the resolving ticket.

The blocker body still reads as if the README is currently stale. If T1-10 is complete, this
is misleading to any agent reading the wiki for current project state.

**Required action**: Update B-006 status to `RESOLVED` and append a resolution note citing
T1-10 and the date resolved.

### B-007 — GLOSSARY.md Timing Constant Name Drift

**DEFECT — STALE STATUS.**

Current status in file: `OPEN`

Expected status: `RESOLVED`

Rationale: The task description states that T2-11 fixed GLOSSARY names. If T2-11 has been
completed, the two mismatched constant names (`$PRIORITY_WATCHDOG_INTERVAL_MS` →
`$PRIORITY_WATCHDOG_MS` and `$SVC_POLL_MS` → `$SVC_BATCH_POLL_MS`) should have been
corrected in `GLOSSARY.md`. With that correction applied, B-007 should be marked `RESOLVED`.

Verification step: Confirm that `GLOSSARY.md` now uses `$PRIORITY_WATCHDOG_MS` and
`$SVC_BATCH_POLL_MS` (matching `docs/ARCHITECTURE.md` and the main script) before marking
resolved. The current `GLOSSARY.md` on disk does not contain either `$PRIORITY_WATCHDOG_INTERVAL_MS`
or `$SVC_POLL_MS` in its Timing Constants entry — the constant names are described in prose
without specific variable names, which means the drift is effectively resolved at the content
level even if the blocker status was not updated. The status must be updated to reflect this.

**Required action**: Update B-007 status to `RESOLVED` and append a resolution note citing
T2-11 and confirming which file was updated (GLOSSARY.md aligned to code, or vice versa).

### B-004 — Phase 1/Phase 2 Integration Test Gap

**PASS.** B-004 is correctly marked `OPEN`. The two-phase batch-stop algorithm in
`_SM_StopServicesBatch` has no end-to-end behavioral test coverage in the delivered harness.
This gap remains open and is an accurate reflection of the current test coverage state.
No action required on this entry.

---

## Defect Register

| ID | File | Severity | Description | Required Action |
|---|---|---|---|---|
| CR2-28-D-001 | `docs/wiki/blockers.md` | MINOR | B-006 status is OPEN; should be RESOLVED (T1-10 completed README update) | Update status to RESOLVED; add resolution note with T1-10 reference |
| CR2-28-D-002 | `docs/wiki/blockers.md` | MINOR | B-007 status is OPEN; should be RESOLVED (T2-11 completed GLOSSARY name fix) | Update status to RESOLVED; add resolution note with T2-11 reference |

---

## Verdict

| File | Verdict | Notes |
|---|---|---|
| `docs/wiki/index.md` | PASS | Module table, ticket statuses, and links all accurate |
| `docs/wiki/environment.md` | PASS | Sandbox limitation, AU3Check command, file table, and no-workarounds rule all correct |
| `docs/wiki/decisions.md` | PASS | All 8 decisions present; all 6 ADR links resolve to existing files |
| `docs/wiki/blockers.md` | CONDITIONAL PASS | B-001–B-005 and B-007 body accurate; B-006 and B-007 statuses stale (both should be RESOLVED) |

**Overall: CONDITIONAL PASS.** Two status fields in `blockers.md` must be updated to RESOLVED
before the wiki accurately represents current project state. No structural errors, broken links,
or missing entries were found in any of the four documents.
