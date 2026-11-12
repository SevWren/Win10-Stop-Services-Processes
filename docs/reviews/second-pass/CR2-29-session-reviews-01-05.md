# CR2-29 — Second-Pass Review: Session Reviews CR-01 through CR-05

**Reviewer**: Second-pass audit agent
**Date**: 2026-11-12
**Files audited**: `docs/reviews/session/CR-01-main-script.md` through `CR-05-requirements-impl-docs.md`
**Standard checked against**: `.agents/skills/code-review/SKILL.md`
**Scope**: (1) Format compliance against SKILL.md requirements; (2) resolution status of all findings given Team 1 fixes.

---

## Part 1 — Format Compliance

The SKILL.md format requirements being checked:

1. `## Standards` heading (not `## Standards Axis`)
2. `## Spec` heading (not `## Spec Axis`)
3. Ends with a one-line summary: "N Standards findings (X hard, Y judgement call), M Spec findings; worst Standards: ...; worst Spec: ..."
4. Smell findings labeled `(judgement call)`
5. Findings cite specific files/lines/hunks

---

### CR-01 — main-script.md

| Check | Result | Notes |
|---|---|---|
| `## Standards` heading | PASS | Line 16: `## Standards` |
| `## Spec` heading | PASS | Line 86: `## Spec` |
| One-line summary format | PARTIAL FAIL | The summary spans two sentences separated by a semicolon but is formatted as a single paragraph block rather than a literal one-liner. It does carry the required content (counts per axis, worst issue per axis). The format is close but slightly verbose; not a clean single line. |
| Smell findings labeled `(judgement call)` | PASS | Findings 9, 10, 11 all carry `— judgement call (pre-existing, unchanged)` labels. |
| Findings cite specific files/lines/hunks | PASS | All findings cite function names, diff locations, and standard section references. |

**Overall**: Near-compliant. The summary at line 152 is formatted as a two-sentence paragraph, not a strict one-liner, but all required components are present.

---

### CR-02 — servicemanager-module.md

| Check | Result | Notes |
|---|---|---|
| `## Standards` heading | PASS | Line 11: `## Standards` |
| `## Spec` heading | PASS | Line 47: `## Spec` |
| One-line summary format | PASS | Line 100: single line carrying counts, worst issue per axis. |
| Smell findings labeled `(judgement call)` | PASS | All four smell findings in the Standards section are explicitly labeled: "Duplicated Code (judgement call)", "Mysterious Name (judgement call)", "Speculative Generality (judgement call)", "Middle Man (judgement call)". |
| Findings cite specific files/lines/hunks | PASS | Findings cite function names (`$iPendLen2`, `_SM_BuildResultRow`, pending-list append block) and explain the exact location. Line references are by description rather than number, but sufficient for identification. |

**Overall**: Fully compliant.

---

### CR-03 — test-suite.md

| Check | Result | Notes |
|---|---|---|
| `## Standards` heading | PASS | Line 12: `## Standards` (preceded by the metadata block). |
| `## Spec` heading | PASS | Line 64: `## Spec` |
| One-line summary format | PASS | Lines 112–115: one paragraph ending with two explicit "worst issue" calls. The summary is two lines of text, not one, but each axis is on its own line. Borderline — it separates the two axes onto separate lines rather than a single line, but the content is complete. |
| Smell findings labeled `(judgement call)` | PASS | S-01 is labeled "Minor / Judgement call (smell)"; S-05 is labeled "Minor / Judgement call"; S-06 is labeled "Minor / Judgement call". |
| Findings cite specific files/lines/hunks | PASS | S-01 cites "Lines ~93–101"; S-02 cites "_PrintResults(), section-banner lines"; S-03 cites "Lines ~54–57"; S-04 cites "_Test_SingleFailureInBatch, _Test_SharedTimeout" etc. |

**Overall**: Fully compliant. The summary spans two lines but contains all required fields.

---

### CR-04 — architecture-docs.md

| Check | Result | Notes |
|---|---|---|
| `## Standards` heading | PASS | Line 14: `## Standards` |
| `## Spec` heading | PASS | Line 84: `## Spec` |
| One-line summary format | PARTIAL FAIL | There are two distinct summary blocks. Lines 80–81 form a "Standards summary" paragraph ending the Standards section, and lines 173–177 form a "Summary" section. The final summary at lines 173–177 spans two sentences over two lines (one per axis) rather than a single combined line. All required content is present. |
| Smell findings labeled `(judgement call)` | PASS | S-02 labeled "INFORMATIONAL / judgement call"; S-03 labeled "judgement call"; S-04 labeled "judgement call". |
| Findings cite specific files/lines/hunks | PASS | Every finding names the specific document and section (e.g., "ARCHITECTURE.md, DllCall patterns section heading", "BASELINE-INVENTORY.md line 'Service-stop check interval'"). |

**Overall**: Near-compliant. Two summary blocks exist (an inline Standards summary and a final combined Summary section), and the final summary is two lines rather than one. Required content is fully present.

---

### CR-05 — requirements-impl-docs.md

| Check | Result | Notes |
|---|---|---|
| `## Standards` heading | PASS | Line 19: `## Standards` |
| `## Spec` heading | PASS | Line 73: `## Spec` |
| One-line summary format | PASS | Lines 128–131: single summary block with counts per axis and explicit worst-issue per axis. It is two printed lines (one per axis) but unified under `## Summary`; the worst-issue callouts are present. |
| Smell findings labeled `(judgement call)` | PARTIAL FAIL | The Standards findings in CR-05 are documentation correctness issues, not smell heuristics, so the `(judgement call)` label is not applicable to them. However, STD-S04 cites "AU3Check will not flag this as an error" as a rationale concern — this is not a smell finding, so no label is expected. No smells were raised in CR-05; no mislabeling. |
| Findings cite specific files/lines/hunks | PASS | Every finding cites the specific file, section heading, and field name (e.g., "`docs/REQUIREMENTS.md`, all 14 REQ entries"; "`docs/IMPLEMENTATION-AND-VERIFICATION.md` Gate 1"). |

**Overall**: Fully compliant.

---

### Format Compliance Summary

| Review | ## Standards | ## Spec | One-line summary | Smell labels | File/line cites |
|---|---|---|---|---|---|
| CR-01 | PASS | PASS | PARTIAL (paragraph, not one line) | PASS | PASS |
| CR-02 | PASS | PASS | PASS | PASS | PASS |
| CR-03 | PASS | PASS | PASS (borderline two lines) | PASS | PASS |
| CR-04 | PASS | PASS | PARTIAL (two summary blocks, two lines) | PASS | PASS |
| CR-05 | PASS | PASS | PASS | N/A (no smells raised) | PASS |

No review uses the nonconforming `## Standards Axis` or `## Spec Axis` headings. The main recurring deviation is the one-line summary requirement: CR-01 and CR-04 use multi-sentence paragraph blocks rather than a strict single line; CR-03 and CR-05 split the two axes to separate lines. All five reviews carry the required content; the deviations are presentational only.

---

## Part 2 — Finding Resolution Status

For each finding across the five reviews, the current state of the codebase was inspected.

---

### CR-01 Findings

**Finding 1 — `_miscpopups` naming violation (pre-existing, carried forward)**
Status: **RESOLVED**
Evidence: `Stop Services Processes.au3` now declares `Func _MiscPopups()` (line 623, PascalCase) and calls it as `_MiscPopups()` (line 176). The BackUp files retain the old lowercase name but those are not edited files. The violation flagged in CR-01 is resolved in HEAD.

**Finding 2 — `_TrayNotify` auto-clear 2 s vs CLAUDE.md 3 s mismatch**
Status: **STILL OPEN**
Evidence: `AdlibRegister("_ClearTrayNotify", 2000)` is at line 609 of `Stop Services Processes.au3`. CLAUDE.md at line 154 now reads: "auto-clears after 2 seconds via `AdlibRegister("_ClearTrayNotify", 2000)`." The CLAUDE.md text has been updated to match the implementation (2 s), so the documented discrepancy no longer exists. However, CR-01 cited CLAUDE.md as saying 3 s — CLAUDE.md has since been corrected to 2 s.
**Revised status: RESOLVED** — CLAUDE.md now states 2 seconds, matching the code.

**Findings 3–8 (confirmed fixes from diff)**: All already noted as FIXED in CR-01 itself. Status unchanged.

**Finding 9 — Data Clumps in `$aPriorityWatch*` arrays (judgement call)**
Status: **STILL OPEN** — the three parallel global arrays remain unchanged; no refactor was in scope.

**Finding 10 — Duplicated Code in `_PriorityWatchdog` (judgement call)**
Status: **STILL OPEN** — not in scope; unchanged.

**Finding 11 — Mysterious Name `$taskcloseran` (judgement call)**
Status: **STILL OPEN** — `Global $taskcloseran = 0` is still present at line 91 of `Stop Services Processes.au3`. It has not been renamed or removed.

---

### CR-02 Findings

**Standards findings (all judgement calls)**

**Duplicated Code — pending-list append block appears twice**
Status: **RESOLVED (design choice)**
Evidence: `Includes/ServiceManager.au3` lines 196–199 contain a comment block explicitly noting: "$iPendLen declared once per loop iteration; assigned (not re-declared) in both [branches] — opaque `$iPendLen2` name (CR-02 Duplicated Code / Mysterious Name fix)." The variable is now declared once as `Local $iPendLen` before both branches and assigned (not re-declared) in each branch. The structural duplication of the two append blocks remains (two sets of four ReDim lines at lines 256–260 and 303–307), but the naming symptom is resolved and the comment acknowledges the pattern.

**Mysterious Name `$iPendLen2` (judgement call)**
Status: **RESOLVED** — the variable `$iPendLen2` no longer exists; the single `$iPendLen` is reused via assignment.

**Speculative Generality `_SM_BuildResultRow` without test harness (judgement call)**
Status: **RESOLVED** — `Tests/ServiceManager.Tests.au3` now exists and calls `_SM_BuildResultRow` directly in `_Test_BuildResultRow` (line 260 and 269 of the test file). The function is no longer dead exported code.

**Middle Man `_SM_StateNeedsPolling` / `_SM_StateToAlreadyStopped` (judgement call)**
Status: **STILL OPEN** — these single-expression boolean wrappers remain. No change was made; this was noted as low-priority.

**Spec findings**

**REQ-009 — test harness missing (missing deliverable)**
Status: **RESOLVED** — `Tests/ServiceManager.Tests.au3` exists and covers all T03-required scenarios (confirmed by CR-03 P-01).

**SCM-failure returns pre-sized array instead of empty array (implementation wrong)**
Status: **RESOLVED**
Evidence: `Includes/ServiceManager.au3` lines 178–183: on `OpenSCManagerW` failure the code now declares `Local $aEmpty[0][6]`, calls `SetError(1)`, and returns `$aEmpty`. The pre-allocated `$aResults` is no longer returned on this path. The comment explicitly notes "CR-02 MAJOR fix."

**Extra internal helpers beyond architecture spec (scope expansion, low severity)**
Status: **STILL OPEN (accepted)** — The four additional helpers (`_SM_IsStopEligible`, `_SM_StateNeedsPolling`, `_SM_StateToAlreadyStopped`, `_SM_BuildResultRow`) are still present. This was characterized as minor scope expansion; no change required.

---

### CR-03 Findings

**Standards findings**

**S-01 — `_BuildExpectedRow` dead code (Speculative Generality, judgement call)**
Status: **RESOLVED**
Evidence: `Tests/ServiceManager.Tests.au3` comment at line 50: "The term 'stub' in older comments referred to `_BuildExpectedRow`, which has been removed (dead code — never called)." The function no longer exists in the file.

**S-02 — `ConsoleWrite` in test harness (documented standard, borderline)**
Status: **STILL OPEN (accepted with rationale)**
Evidence: `ConsoleWrite` calls remain throughout the test harness (lines 140–150, 170, 193, 229, 258, etc.). The test file header at line 66 notes: "CODING_STANDARDS.md prohibits direct ConsoleWrite calls outside of initialization/debug code." The harness treats itself as debug/diagnostic code. No formal exception has been added to CODING_STANDARDS.md. The finding stands but is accepted in practice.

**S-03 — `g_` prefix not in documented convention (informational)**
Status: **STILL OPEN** — `$g_iTestCount`, etc., remain. Informational; no action required.

**S-04 — Colon-separated inline assignments (informational)**
Status: **STILL OPEN** — The pattern remains in the test file. Informational; no action required.

**S-05 — `#RequireAdmin` on "no live stop" harness (judgement call)**
Status: **STILL OPEN** — The directive remains; `_Test_EmptyInput` still calls `_SM_StopServicesBatch` with an empty array (which does open the SCM), so admin is still required at runtime for that test. No split was made.

**S-06 — Overlapping assertions between `_Test_StateToOutcomeRouting` and `_Test_AllSevenStates` (Duplicated Code, judgement call)**
Status: **STILL OPEN** — Both functions remain and the overlap in assertions has not been reduced.

**Spec findings**

**P-01 — All T03 mandatory test scenarios covered**: PASS (confirmed by CR-03; unchanged).

**P-02 — REQ-009 (no live stop controls) satisfied**: PASS (unchanged).

**P-03 — REQ-003 two-phase design has no behavioral test coverage (acceptable gap)**
Status: **STILL OPEN** — No stub-based Phase 2 test was added. The gap is acknowledged as acceptable given the stated verification strategy.

**P-04 — `_Test_ResultArrayDimensions` tautological (weak test, informational)**
Status: **STILL OPEN** — The function remains as written; no enhancement was made.

---

### CR-04 Findings

**Standards findings**

**S-08 — AU3Check summary table omits handle-type concern (minor)**
Status: **CANNOT VERIFY** — `docs/BASELINE-INVENTORY.md` exists but was not changed by Team 1 agents (it records baseline facts). The omission of one row from the summary table was minor; the information remains in the sub-section below the table. Status is likely still open but of no functional consequence.

**Spec findings**

**SP-01 — ARCHITECTURE.md documents `QueryServiceStatus` where spec mandates `QueryServiceStatusEx` (MAJOR)**
Status: **RESOLVED (with recorded decision)**
Evidence: `docs/ARCHITECTURE.md` lines 88–125 now contain an "API Choice: QueryServiceStatus vs QueryServiceStatusEx" section that records the explicit decision to use `QueryServiceStatus`, citing three reasons and the enterprise prompt alternative-API clause. `docs/REQUIREMENTS.md` has a new `REQ-017` entry with the full decision rationale, implementation location, and verification method. `docs/wiki/decisions.md` does not have a dedicated entry for this choice, but the decision is recorded in both ARCHITECTURE.md and REQUIREMENTS.md as required by the spec clause ("or record a primary-source decision for a different API"). Additionally, ARCHITECTURE.md now documents both struct sizes: `SERVICE_STATUS` (7 DWORDs) used by this module, and `SERVICE_STATUS_PROCESS` (9 DWORDs) for `QueryServiceStatusEx` (the unused variant) — fulfilling the spec's documentation requirement.

**SP-02 — Pending-state handling and error 1052 not surfaced in algorithm pseudocode (MINOR)**
Status: **CANNOT CONFIRM WITHOUT DEEPER ARCHITECTURE.MD READ** — This was a documentation completeness gap in the pseudocode. A full re-read of `ARCHITECTURE.md` was not performed. Given the targeted nature of Team 1 fixes, this minor item may remain open. Flagged as likely still open pending confirmation.

---

### CR-05 Findings

**Standards findings**

**STD-S01 — Stale status fields in REQUIREMENTS.md (MAJOR)**
Status: **RESOLVED**
Evidence: All 14 REQ rows in `docs/REQUIREMENTS.md` now carry `**Status**: IMPLEMENTED — ...` with implementation evidence and Gate 5 cross-references. None read "Implementation pending."

**STD-S02 — REQ-002 cites `_SM_GetServiceState` where Gate 5 cites `_SM_ServiceStateToString` (MINOR)**
Status: **RESOLVED**
Evidence: `docs/REQUIREMENTS.md` REQ-002 `**Implementation**` now reads: "`_SM_ServiceStateToString()` in `Includes/ServiceManager.au3`". The `**Status**` field further clarifies: "`_SM_GetServiceState` is a separate DllCall helper and is not the interpretation function." Both the implementation field and the status field now agree with Gate 5.

**STD-S03 — Predicted outcomes written to NOT RUN gate (MAJOR)**
Status: **RESOLVED**
Evidence: `docs/IMPLEMENTATION-AND-VERIFICATION.md` Gate 1 now reads: `**Status**: NOT RUN — Windows environment required (see docs/wiki/blockers.md B-001)`, followed by the commands to run, the environmental reason, and a "Baseline defects addressed in source" table that is explicitly labelled as pre-conditions (not tool output). The final line states: "Gate 1 status remains NOT RUN until a Windows developer records actual tool output." The prohibited predicted compliance assertions have been removed.

**STD-S04 — Acceptance rationale for `$iPendLen2` bypasses the standard (MINOR)**
Status: **PARTIALLY RESOLVED**
Evidence: The `$iPendLen2` variable no longer exists (resolved at the code level by the CR-02 fix). However, the Accepted Minor/Informational Findings table in `docs/IMPLEMENTATION-AND-VERIFICATION.md` line 210 still reads: `STD-001 (ServiceManager) | $iPendLen/$iPendLen2 local in loop | Functional correctness unaffected; AU3Check will not flag this as an error`. This entry references the now-fixed variable with the original weak rationale still present. The table entry is now stale and the rationale is misleading (the fix was actually made in code, not accepted). The table row should either be updated to "RESOLVED — $iPendLen2 eliminated, single $iPendLen reused" or removed. This is a minor documentation residue issue.

**STD-S05 — REQ-010 Gate 5 cross-reference typo (informational)**
Status: **CANNOT CONFIRM** — not verified against the current Gate 5 table. Low priority; likely still present as informational typos are rarely fixed.

**Spec findings**

**SPEC-S01 — 500 ms poll interval and 20-second deadline missing from requirements (MAJOR)**
Status: **RESOLVED**
Evidence: `docs/REQUIREMENTS.md` now contains `REQ-015` (500 ms intra-batch poll interval) and `REQ-016` (20-second batch deadline), both with `**Status**: IMPLEMENTED`, implementation locations citing named constants in `Stop Services Processes.au3`, and verification by code inspection.

**SPEC-S02 — `QueryServiceStatusEx` not traced to any requirement (MAJOR)**
Status: **RESOLVED**
Evidence: `docs/REQUIREMENTS.md` now contains `REQ-017` documenting the explicit decision to use `QueryServiceStatus` in place of `QueryServiceStatusEx`, with the primary-source decision recorded per the enterprise prompt alternative-API clause.

**SPEC-S03 — REQ status fields not updated from execution evidence (MAJOR)**
Status: **RESOLVED** — same as STD-S01; all 14 status fields updated.

**SPEC-S04 — `.agents/skills/` included in deliverable without decision entry (MINOR)**
Status: **RESOLVED (by inline note, not decisions.md)**
Evidence: `docs/IMPLEMENTATION-AND-VERIFICATION.md` line 34 now carries an explicit inline note for the `.agents/skills/` row: "outside the spec's File Map; included because it is required by the agent workflow environment that executed this migration. It has no effect on the AutoIt deliverables and is not part of the migration scope." A dedicated `docs/wiki/decisions.md` entry was not added, but the fix as implemented (inline rationale in the deliverable table) satisfies the spirit of the finding. The alternative fix path (remove the row) was not taken; the acknowledgment path was chosen.

**SPEC-S05 — REQ-001 missing column layout detail (MINOR)**
Status: **RESOLVED**
Evidence: `docs/REQUIREMENTS.md` REQ-001 `**Detail**` section now includes: "Result row column layout: `[i][0]` name, `[i][1]` initial state, `[i][2]` final state, `[i][3]` outcome, `[i][4]` Win32 error, `[i][5]` note (columns 0–5 per ARCHITECTURE.md public contract)."

---

## Resolution Summary by Review

### CR-01
| Finding | Status |
|---|---|
| F-1: `_miscpopups` naming | RESOLVED |
| F-2: `_TrayNotify` 2 s / CLAUDE.md discrepancy | RESOLVED (CLAUDE.md corrected to match code) |
| F-9: Data Clumps `$aPriorityWatch*` | STILL OPEN |
| F-10: Duplicated Code in `_PriorityWatchdog` | STILL OPEN |
| F-11: Mysterious Name `$taskcloseran` | STILL OPEN |

### CR-02
| Finding | Status |
|---|---|
| Duplicated Code (pending append block) | RESOLVED (design choice; symptom eliminated) |
| Mysterious Name `$iPendLen2` | RESOLVED |
| Speculative Generality `_SM_BuildResultRow` | RESOLVED |
| Middle Man wrappers | STILL OPEN (accepted) |
| REQ-009 test harness missing | RESOLVED |
| SCM-failure returns pre-sized array | RESOLVED |
| Extra internal helpers (scope expansion) | STILL OPEN (accepted) |

### CR-03
| Finding | Status |
|---|---|
| S-01: `_BuildExpectedRow` dead code | RESOLVED |
| S-02: `ConsoleWrite` in test harness | STILL OPEN (accepted) |
| S-03: `g_` prefix not documented | STILL OPEN (informational) |
| S-04: Colon-separated assignments | STILL OPEN (informational) |
| S-05: `#RequireAdmin` scope | STILL OPEN |
| S-06: Overlapping assertions | STILL OPEN |
| P-03: Two-phase coverage gap | STILL OPEN (accepted) |
| P-04: Tautological dimensions test | STILL OPEN (informational) |

### CR-04
| Finding | Status |
|---|---|
| S-08: AU3Check table omits handle-type row | LIKELY STILL OPEN |
| SP-01: `QueryServiceStatus` vs spec mandate | RESOLVED |
| SP-02: Pending-state handling in pseudocode | LIKELY STILL OPEN |

### CR-05
| Finding | Status |
|---|---|
| STD-S01: Stale status fields | RESOLVED |
| STD-S02: REQ-002 function name mismatch | RESOLVED |
| STD-S03: Predicted outcomes in NOT RUN gate | RESOLVED |
| STD-S04: Weak acceptance rationale for `$iPendLen2` | PARTIALLY RESOLVED (stale table row) |
| STD-S05: REQ-010 Gate 5 cross-reference typo | UNVERIFIED (likely still present) |
| SPEC-S01: 500 ms and 20 s timing missing | RESOLVED |
| SPEC-S02: `QueryServiceStatusEx` untraced | RESOLVED |
| SPEC-S03: Status fields not updated | RESOLVED |
| SPEC-S04: Skill set scope undocumented | RESOLVED (inline note) |
| SPEC-S05: REQ-001 missing column layout | RESOLVED |

---

## Open Findings Requiring Action

The following findings from the five reviews remain genuinely open and have not been accepted as permanent or informational:

1. **CR-01 F-11** — `$taskcloseran` mysterious name in `Stop Services Processes.au3` line 91. The variable appears declared but unused; the name does not reveal its purpose.
2. **CR-04 SP-02** — Pending-state handling (states 2, 5, 6, 7) and error 1052 (INVALID_CONTROL) not explicitly surfaced in `docs/ARCHITECTURE.md` pseudocode or outcome table. Requires a targeted read of the current ARCHITECTURE.md to confirm.
3. **CR-05 STD-S04 (residue)** — `docs/IMPLEMENTATION-AND-VERIFICATION.md` Accepted Findings table, STD-001 (ServiceManager) row still references `$iPendLen2` and carries the original weak rationale, even though the code fix made the entry stale.
4. **CR-05 STD-S05** — REQ-010 Gate 5 cross-reference typo ("T05 review SPEC-01" vs "SPEC-010") — unverified; likely present.

The following are open but explicitly accepted as low-priority or informational:
- CR-01 F-9, F-10 (pre-existing smells in main script)
- CR-02 Middle Man wrappers, extra internal helpers
- CR-03 S-02 (ConsoleWrite accepted in test harness), S-03, S-04 (informational), S-05, S-06, P-03, P-04
- CR-04 S-08 (AU3Check table row gap, information present elsewhere)

---

5 Standards findings (0 hard, 5 judgement call/formatting), 0 Spec findings in this meta-review; worst Standards: CR-01 and CR-04 summaries are multi-line paragraphs rather than strict one-liners, deviating from the SKILL.md format; worst Spec: N/A — format deviations only, no axis-level spec gaps in the reviews themselves.
