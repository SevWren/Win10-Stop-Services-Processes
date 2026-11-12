# CR2-31 — Second-Pass Review: Domain Modeling Documents

**Date**: 2026-11-12
**Branch**: arch/service-manager-migration
**Reviewer**: Second-pass automated audit
**Scope**: Six domain-modeling documents reviewed for accuracy, completeness, and
internal consistency against current code and other project artifacts.

---

## 1. DOMAIN-MODEL.md

### 1a. ASCII flow diagram accuracy

The diagram at lines 53–66 is **accurate**. The two-phase batch-stop structure (Phase 1
routing, Phase 2 polling) matches the implementation in `Includes/ServiceManager.au3`.
The routing branches (`Stop-Eligible → Stop Control → Pending List`, `ALREADY_STOPPED`,
`FAILED` for `START_PENDING`, `STOP_PENDING` direct-to-pending) all correspond to the
actual switch-case logic in the file.

The timing claims in surrounding prose are also accurate: "10-second interval" for Batch
Stop matches `$SVC_POLL_INTERVAL_SEC = 10`; "2-second interval" for process killing
matches `$PROC_POLL_INTERVAL_SEC = 2`. The Priority Watchdog "every 10 seconds" claim
matches `$PRIORITY_WATCHDOG_MS = 10000`.

**No inaccuracies found in the diagram or surrounding prose.**

### 1b. ADR links

All 10 ADRs (ADR-0001 through ADR-0010) are listed in the Decisions table with correct
relative paths (`../adr/0001-servicemanager-module-extraction.md` etc.).

**Verification gap**: `docs/adr/` was not found by directory glob, which may indicate the
review sandbox lacks the files, but `CROSS-REFERENCE-VALIDATION.md` Section 4 confirms
all 10 ADRs exist and their decisions are implemented in code. The ADR table in
`DOMAIN-MODEL.md` lists all 10 entries as required.

**All 10 ADRs are linked. No missing links.**

### 1c. Term alignment with GLOSSARY.md

The 13 key terms in the Key Concepts table were checked against `GLOSSARY.md`:

| Term | Alignment |
|---|---|
| Service Control Manager (SCM) | PASS — matches glossary definition |
| Service | PASS — matches |
| Process | PASS — matches; TrustedInstaller disambiguation present in both |
| Service State | PASS — seven named values listed consistently |
| Stop-Eligible State | PASS — same four states in both |
| Batch Stop | PASS — shared-deadline, two-phase concept consistent |
| Stop Outcome | PASS — same five values (`STOPPED`, `ALREADY_STOPPED`, `UNAVAILABLE`, `FAILED`, `TIMED_OUT`) |
| Result Row | PASS — six-element record consistent |
| Priority Watchdog | PASS — consistent |
| Priority Drift | PASS — consistent |
| Monitoring Loop | PASS — consistent |
| Service Inventory | PASS — consistent; nine canonical entries |
| Process Inventory | PASS — consistent |

**All 13 terms match current GLOSSARY.md. No mismatches.**

### 1d. Overall verdict for DOMAIN-MODEL.md

**PASS.** The document is accurate and complete against current code. No corrections
required.

---

## 2. IMPLEMENTATION-REPORT.md

### 2a. Open issues list accuracy

The 27-item open issues list was checked against current repo state.

**Items that appear RESOLVED by current code (not reflected in the report):**

**Item 14 — GLOSSARY.md timing constant names** (CR-10 S-01, DM-10 §2b):
The report states `$PRIORITY_WATCHDOG_INTERVAL_MS` and `$SVC_POLL_MS` are the wrong
names in `GLOSSARY.md`. The current `GLOSSARY.md` Timing Constants entry uses no specific
variable names at all — it was rewritten to describe the concept without enumerating
identifiers (confirmed in `proposals/INDEX.md` DM-10 "Recommendations acted on" and
visible in the current GLOSSARY.md text). The specific wrong-name issue described in item
14 no longer applies to `GLOSSARY.md` itself. However, `docs/wiki/blockers.md` B-007
still records this as OPEN with a table showing the stale names. The discrepancy is that
B-007 names the problem but the fix has already been applied to GLOSSARY.md. Item 14 as
written in the report was partially resolved: GLOSSARY.md no longer contains the wrong
names, though the blocker record was not updated to RESOLVED.

**Items confirmed still OPEN (not resolved):**

Items 1–4 (Windows environment gates), 5–13 (documentation fixes), 15–17 (agent skills),
18–27 (code quality) remain unresolved based on static inspection of current files.
`docs/REQUIREMENTS.md` still carries "Implementation pending" status fields (confirmed
by cross-reference with `CROSS-REFERENCE-VALIDATION.md` noting the stale statements).

**Named constants for log levels and log type strings (items derived from DM-07):**
The report does not list these as open issues in its numbered list (items 1–27), because
they are recorded under Priority 3 in Recommended Next Steps ("deferred to maintainer")
rather than as numbered open issues. However, the actual code shows these constants ARE
now declared:
- `Stop Services Processes.au3` lines 54–64: `$LOG_LEVEL_ERROR = 0`,
  `$LOG_LEVEL_INFO = 1`, `$LOG_LEVEL_VERBOSE = 2`, plus five `$LOG_TYPE_*` constants.
- `Includes/ServiceManager.au3` lines 100–109: same log-level and log-type constants.

The DM-07 concern ("no named constants; mapping lives only in CLAUDE.md") and the
Recommended Next Steps item ("Named constants for log levels — deferred to maintainer")
are **both stale**: the constants have been added to the codebase. The report does not
reflect this resolution.

**Finding**: The open issues list is substantially accurate for items 1–13 and 15–27.
Item 14 is partially stale (GLOSSARY.md fix applied; blocker not closed). The DM-07
"deferred to maintainer" recommendation regarding log constants is stale — the constants
exist in the current code.

### 2b. Overall verdict for IMPLEMENTATION-REPORT.md

**CONDITIONALLY PASS.** Two staleness issues:
1. Item 14 (timing constant names in GLOSSARY.md) — the GLOSSARY.md fix was applied;
   the item should be marked RESOLVED or removed from the open list.
2. The DM-07 "deferred to maintainer" treatment of log constants is superseded by the
   actual presence of `$LOG_LEVEL_*` and `$LOG_TYPE_*` constants in both `.au3` files.
   The Recommended Next Steps section should note this as DONE.

---

## 3. CROSS-REFERENCE-VALIDATION.md

### 3a. B-006 and B-007 status claims

The document does not reference B-006 or B-007 by those identifiers — the blocker labels
are used in `docs/wiki/blockers.md`, not in the cross-reference validation document.
`CROSS-REFERENCE-VALIDATION.md` addresses the same underlying issues through its own
findings:

- The README.md staleness problem (B-006) is noted in the final bullet of Section 4
  (ADR ↔ CODE Consistency): "README.md not updated despite T04/T06 checklist requirement"
  is called out in the CR-10 row of `IMPLEMENTATION-REPORT.md`. The cross-reference
  document itself notes the stale "No `docs/adr/` directory" statement (Section 4,
  Notable Finding) but does not specifically address README.md content accuracy.

- The GLOSSARY.md timing constant drift (B-007) is **not flagged** in
  `CROSS-REFERENCE-VALIDATION.md` Section 3 (GLOSSARY ↔ CODE Consistency). The ten
  terms checked in that section do not include Timing Constants. This is a gap in the
  cross-reference document's scope: B-007 identifies a discrepancy between glossary
  variable names and actual code constant names, but Section 3 of the validation document
  did not examine the Timing Constants entry. As noted in item 2b above, the GLOSSARY.md
  entry has since been rewritten to remove specific variable names, so the original B-007
  discrepancy no longer exists in GLOSSARY.md — but the cross-reference document still
  does not record this.

**Neither B-006 nor B-007 is noted as RESOLVED in `CROSS-REFERENCE-VALIDATION.md`**,
because the document predates or omits those blocker identifiers.

**Finding (the check asked for):** The cross-reference document does not contain stale
"B-006 / B-007 RESOLVED" claims — it does not reference those identifiers at all, so
there is nothing incorrectly marked as resolved. The concern raised in the review task
was whether the document falsely claimed these were resolved; it does not. The gap is
the absence of any note on these items rather than a false resolution claim.

### 3b. "No docs/adr/ directory" stale statement

Section 4 and the Overall Summary both correctly flag the stale statement in
`docs/REQUIREMENTS.md` and `docs/ARCHITECTURE.md` ("No `docs/adr/` directory exists")
as a known inaccuracy. This is accurately documented as a stale artefact, not a code
defect. No correction needed in the cross-reference document itself.

### 3c. Overall verdict for CROSS-REFERENCE-VALIDATION.md

**PASS with one gap noted.** The document accurately records 53 PASS / 18 PARTIAL / 0 FAIL
across five consistency dimensions. The B-006/B-007 identifiers are absent from the
document (they live in `blockers.md`), which is appropriate — the cross-reference document
uses its own finding vocabulary. No false RESOLVED claims exist. The one gap is that the
Timing Constants glossary entry was not included in the Section 3 sample, leaving B-007
unaddressed by this document; this is a scope limitation, not an error.

---

## 4. servicecontrol-analysis.md

### 4a. `#include-once` missing status

The document states at lines 168–170:
> "The file lacks `#include-once`, which means including it twice in one compilation unit
> would redefine all global constants and trigger AU3Check duplicate-declaration warnings."

**Current status verified**: The first 10 lines of `Includes/ServiceControl.au3` were
read. Line 1 is `Global $STANDARD_RIGHTS_REQUIRED2 = 0x000F0000` — there is no
`#include-once` directive at the top of the file. A grep for `include-once`
(case-insensitive) in `ServiceControl.au3` returned no matches.

**The `#include-once` missing status is accurate. This remains an open issue.**

### 4b. Overall verdict for servicecontrol-analysis.md

**PASS.** The document accurately describes the file's architecture, known bugs (`"long"`
handle type, `ControlService` third-argument type mismatch), and the `#include-once`
absence. All described issues remain present in the current code. The document is
up-to-date.

---

## 5. test-process-close-analysis.md

### 5a. Deletion recommendation

The document's Section 4 (lines 46–55) contains an explicit and clearly argued
**recommendation to delete `test_process_close.au3`**. The rationale is:

1. No test value — no assertions, no regression protection.
2. Duplicate of production behaviour (`_KillProcessList` already kills `TCPSVCS.EXE`).
3. Not a candidate for `Tests/ServiceManager.Tests.au3` (wrong domain; REQ-009 prohibits
   live-termination tests).
4. Not a candidate for standalone archival (no documented context, no reproducible
   outcome).

**Verification**: `test_process_close.au3` still exists at the repo root (confirmed by
file glob). The deletion recommendation has not been acted on.

### 5b. Overall verdict for test-process-close-analysis.md

**PASS.** The deletion recommendation is clearly stated and well-supported. The file
remains undeleted as of this review — the recommendation is pending action, which is
expected (this is a documentation/analysis document, not an enforcement mechanism).
No inaccuracies found in the document itself.

---

## 6. proposals/INDEX.md

### 6a. DM-07 log constants status vs. T1-07/T1-11 actuals

The INDEX.md "Still Pending" table at the bottom of the document includes:

> | Named constants for log levels (`$LOG_ERROR`, etc.) | DM-07 | Code-level improvement;
> deferred to maintainer |
> | Named constants for log type strings | DM-07 | Code-level improvement; deferred to
> maintainer |

The DM-07 section body also states:
> "Named constants for log levels (`$LOG_ERROR = 0`, `$LOG_INFO = 1`,
> `$LOG_VERBOSE = 2`) were suggested as a code-level improvement but are an
> implementation decision deferred to the maintainer"

**However, the constants have been added to the codebase.** Current code shows:

In `Stop Services Processes.au3` (lines 54–64):
```
Global Const $LOG_LEVEL_ERROR   = 0
Global Const $LOG_LEVEL_INFO    = 1
Global Const $LOG_LEVEL_VERBOSE = 2
Global Const $LOG_TYPE_SYSTEM           = "System"
Global Const $LOG_TYPE_PROCESS          = "Process"
Global Const $LOG_TYPE_SERVICE          = "Service"
Global Const $LOG_TYPE_PROCESS_PRIORITY = "ProcessPriority"
Global Const $LOG_TYPE_PRIORITY_WATCHDOG = "PriorityWatchdog"
```

In `Includes/ServiceManager.au3` (lines 100–109): same `$LOG_LEVEL_*` and two
`$LOG_TYPE_*` constants are declared.

**Note on naming**: DM-07 proposed `$LOG_ERROR`, `$LOG_INFO`, `$LOG_VERBOSE`; the
actual constants use `$LOG_LEVEL_ERROR`, `$LOG_LEVEL_INFO`, `$LOG_LEVEL_VERBOSE`.
Similarly, log type constants use `$LOG_TYPE_*` prefix. The intent of DM-07 was
fulfilled even though the exact names differ slightly from what DM-07 sketched.

The task description refers to "T1-07 and T1-11" adding these constants. No files with
those ticket identifiers were found in the repository (no `T1-07` or `T1-11` markdown
files exist under `.scratch/` or `docs/`), but the constants' presence in both `.au3`
files is confirmed by direct code inspection.

**Finding**: The INDEX.md "Still Pending" table entry "Named constants for log levels —
deferred to maintainer" and "Named constants for log type strings — deferred to
maintainer" are **stale**. These items have been implemented. The DM-07 entry's "Still
pending" section in the body of the index is also stale for the same reason.

### 6b. DM-07 overall status label

The DM-07 entry carries **Status: Incorporated** at the top. This status refers to the
glossary additions (Log Level, Log Type, Log Entry, Log File, Log Rotation, Suppression
Event), which were acted on and are confirmed present in `GLOSSARY.md`. The status label
is correct for the glossary work. The staleness is confined to the "Still pending" items
within DM-07 and the global "Still Pending" table, not the top-level status.

### 6c. Other proposals status accuracy

The remaining proposals (DM-01 through DM-06, DM-08 through DM-10) were spot-checked.
Their status labels (Incorporated / Partially Incorporated / Proposed) and "Still
pending" items are consistent with the current `GLOSSARY.md` content and ADR file list.
No additional staleness was found beyond the DM-07 log-constants items.

### 6d. Overall verdict for proposals/INDEX.md

**FAIL on two items; otherwise accurate.**

The two "Still Pending" entries for log constants (DM-07) are stale — both the named
log-level constants and the named log-type constants have been declared in the codebase.
These entries should be updated to reflect that the implementation was completed.

---

## Summary Table

| Document | Verdict | Key Findings |
|---|---|---|
| `DOMAIN-MODEL.md` | PASS | Diagram accurate; all 10 ADRs linked; all 13 terms match GLOSSARY.md |
| `IMPLEMENTATION-REPORT.md` | CONDITIONALLY PASS | Item 14 stale (GLOSSARY.md fix applied); DM-07 log-constant "deferred" note superseded by actual code |
| `CROSS-REFERENCE-VALIDATION.md` | PASS (gap noted) | No false RESOLVED claims for B-006/B-007; Timing Constants entry not in Section 3 sample (scope gap, not error) |
| `servicecontrol-analysis.md` | PASS | `#include-once` still missing (accurately reported); all other findings confirmed current |
| `test-process-close-analysis.md` | PASS | Deletion recommendation clearly stated; file not yet deleted (pending action) |
| `proposals/INDEX.md` | FAIL (2 items) | Log-level and log-type constant entries in "Still Pending" table are stale — constants implemented in both `.au3` files |

---

## Required Corrections

### High priority

**proposals/INDEX.md — DM-07 "Still Pending" entries:**
Remove or mark DONE the two entries:
- "Named constants for log levels (`$LOG_ERROR`, etc.) | DM-07 | Code-level improvement;
  deferred to maintainer"
- "Named constants for log type strings | DM-07 | Code-level improvement; deferred to
  maintainer"

Replace with a note reflecting the actual implementation: constants declared as
`$LOG_LEVEL_ERROR/INFO/VERBOSE` and `$LOG_TYPE_*` in both `Stop Services Processes.au3`
and `Includes/ServiceManager.au3`.

Also update the DM-07 section body's "Still pending" paragraph to remove the log-constant
items, noting they were resolved outside the DM session (precise ticket reference
unavailable; implementer should supply).

### Medium priority

**IMPLEMENTATION-REPORT.md — Item 14 and Recommended Next Steps:**
Item 14 ("GLOSSARY.md timing constants") is partially stale. GLOSSARY.md was rewritten
to avoid specific variable names; the wrong-name issue no longer applies to GLOSSARY.md.
However, `docs/wiki/blockers.md` B-007 still reads OPEN and contains the old variable
name table. The report's item 14 should note the GLOSSARY.md fix was applied, while
flagging that B-007 in blockers.md has not been closed.

The "Priority 3" Recommended Next Steps paragraph mentioning log constants as "deferred
to maintainer" should be updated to note the constants are now present in the code.

### Low priority (informational)

**CROSS-REFERENCE-VALIDATION.md:** No corrections required. The scope limitation
(Timing Constants not sampled in Section 3) is acceptable; the document does not claim
comprehensive glossary coverage. A note could be appended to the Section 3 Summary
acknowledging that the Timing Constants entry was not sampled, but this is optional.

---

## Incidental Findings

**`docs/wiki/blockers.md` B-007 status not updated**: B-007 (GLOSSARY.md Timing
Constant Name Drift) still reads OPEN. The underlying GLOSSARY.md fix (removing specific
variable names from the Timing Constants entry) has been applied. B-007 should be
updated to RESOLVED with a note pointing to the GLOSSARY.md rewrite. This file is
outside the six documents under review but is directly related to claims in
`IMPLEMENTATION-REPORT.md` item 14.

**`test_process_close.au3` still present**: The deletion recommended in
`test-process-close-analysis.md` has not been executed. This is an action item for the
maintainer, not a documentation defect.

**`#include-once` in `ServiceControl.au3`**: Confirmed missing. The analysis document
is accurate. This remains an open implementation risk (duplicate-declaration AU3Check
warnings if the file is included twice). No correction to the analysis document is
needed; the finding should be tracked as an open code-quality item.
