# CR-07: Meta-Review of Session Code-Review Documents

**Meta-reviewer**: Aggregating agent (CR-07)
**Date**: 2026-11-12
**Fixed point**: ab5b012
**Documents under review**:
- `docs/reviews/REVIEW-ServiceManager.Tests.au3.md`
- `docs/reviews/REVIEW-ServiceManager.au3.md`
- `docs/reviews/REVIEW-Stop-Services-Processes.au3.md`

**Spec source for this meta-review**: `.agents/skills/code-review/SKILL.md`

---

## Standards Axis — Do the review docs conform to the SKILL.md format?

The SKILL.md defines the following mandatory structural and behavioural requirements for a conforming review document:

1. Two explicit top-level sections: `## Standards` and `## Spec` (or equivalent).
2. Both axes run as parallel sub-agents with separate contexts; findings should not pollute each other.
3. Each finding must cite specific lines or hunks from the diff.
4. Hard violations (documented-standard breaches) must be distinguished from judgement calls (smell-baseline findings).
5. Smell-baseline findings must be named using the Fowler vocabulary and labelled as judgement calls.
6. A one-line summary at the end: total findings per axis and worst issue per axis.
7. Findings must be under 400 words per axis (the brief says "under 400 words" per sub-agent report).

### Findings

**MR-STD-001 | MINOR | All three documents | Heading labels differ from SKILL.md prescription**

SKILL.md step 5 says: "Present the two reports under `## Standards` and `## Spec` headings." All three review documents use `## Standards Axis` and `## Spec Axis` instead. This is a cosmetic deviation and does not impair readability, but it is a literal departure from the prescribed format.

**MR-STD-002 | PASS | All three documents | Both axes present**

Every review document contains both a Standards section and a Spec section. The two-axis requirement is fully satisfied.

**MR-STD-003 | PASS | All three documents | Line citations present**

All findings include explicit line-number references (e.g., "Line 36–49", "line 217", "lines 588, 592"). The SKILL.md requirement to "cite specific lines/hunks" is met across all three documents.

**MR-STD-004 | MINOR | REVIEW-ServiceManager.au3.md | Hard violations vs judgement calls not consistently labelled**

SKILL.md requires distinguishing hard violations from judgement calls, with smell-baseline findings always labelled as judgement calls. In `REVIEW-ServiceManager.au3.md`:

- STD-001 (`Local` redeclaration in a loop) is labelled MINOR but is not explicitly flagged as a hard violation or a judgement call. It straddles both: it is a documented-standard concern (AU3Check `-w 3`) but also a code smell.
- STD-002 (`$jj` Mysterious Name) is a smell-baseline finding. It is correctly cited against the Fowler smell by name but is not explicitly labelled "judgement call" as SKILL.md requires ("baseline smells are always judgement calls").
- STD-003, STD-004, STD-005 are smell findings (Duplicated Code, Speculative Generality) that are labelled INFORMATIONAL but are not explicitly marked as judgement calls.

`REVIEW-ServiceManager.Tests.au3.md` and `REVIEW-Stop-Services-Processes.au3.md` do not invoke the smell baseline at all, which is acceptable only if no applicable smell was found. However, `REVIEW-Stop-Services-Processes.au3.md` includes `CheckElapsedTime` missing an underscore prefix (STD-14), which is a judgement-call smell (Mysterious Name / naming convention) but is not labelled as such.

**MR-STD-005 | MINOR | All three documents | No one-line summary at the document level**

SKILL.md step 5 mandates ending the aggregated report with "a one-line summary: total findings per axis, and the worst issue within each axis." All three documents have per-section summaries but none provides a single one-line document-level summary in the prescribed form. The closest is the "Disposition" section appended to each, but this is a verdict, not the prescribed one-liner with per-axis finding counts and worst-issue identification per axis.

**MR-STD-006 | INFORMATIONAL | REVIEW-Stop-Services-Processes.au3.md | STD-06 and STD-13 are duplicate entries**

STD-06 is marked "PASS" in its header yet its body documents a MINOR violation (bare `ConsoleWrite` in `_miscpopups`). STD-13 then re-states the same finding. The same finding appears under two IDs with contradictory top-level labels. The correct pattern would be a single finding labelled MINOR. This is a formatting inconsistency internal to the document.
Evidence: STD-06 header reads "PASS" but body contains a MINOR severity conclusion; STD-13 is a verbatim re-statement.

**MR-STD-007 | PASS | All three documents | Smell-baseline vocabulary used where applied**

Where smell-baseline smells are invoked in `REVIEW-ServiceManager.au3.md` (Mysterious Name, Duplicated Code, Speculative Generality), the Fowler vocabulary from SKILL.md is used correctly and by name.

**MR-STD-008 | INFORMATIONAL | All three documents | Word-count compliance unverified but structurally plausible**

SKILL.md specifies that sub-agent reports should be "under 400 words." The review sections are substantially longer than 400 words each (each document exceeds 400 words even for a single axis). The SKILL.md word limit applies to the sub-agent's returned report, not necessarily to the final stored document, but if the stored document is the verbatim sub-agent output, all three documents likely exceed the guidance. This is a low-severity process note; the content quality is not degraded by verbosity.

### Standards Axis Summary

| ID | Severity | Description |
|---|---|---|
| MR-STD-001 | MINOR | Heading labels use "Standards Axis"/"Spec Axis" instead of "Standards"/"Spec" |
| MR-STD-002 | PASS | Both axes present in all three documents |
| MR-STD-003 | PASS | Line citations present throughout |
| MR-STD-004 | MINOR | Smell findings not consistently labelled as "judgement call" per SKILL.md |
| MR-STD-005 | MINOR | No document-level one-line summary in prescribed form (findings count + worst per axis) |
| MR-STD-006 | INFORMATIONAL | STD-06/STD-13 duplicate finding with contradictory PASS/MINOR labels in Stop-Services review |
| MR-STD-007 | PASS | Fowler smell vocabulary correctly applied where used |
| MR-STD-008 | INFORMATIONAL | Axis sections likely exceed 400-word sub-agent guidance |

Total: 3 MINOR, 2 INFORMATIONAL, 3 PASS.

---

## Spec Axis — Do the review docs cover all significant changes?

The spec for this axis is: do the review documents actually address all material changes visible in `git diff ab5b012...HEAD -- docs/reviews/`? Since the diff creates three brand-new review files (not modifications to existing code), the relevant question is: does each review document cover all significant changes in the *source file it reviews*? The SKILL.md brief for the Spec sub-agent is to identify missing or partial requirements, scope creep, and wrong implementations.

The diff shows three new files. Each is a full-document review written from scratch, so coverage gaps are assessed against what the source files are known to contain (inferred from the review documents themselves and from CLAUDE.md/repo context).

### Findings

**MR-SPEC-001 | PASS | REVIEW-ServiceManager.Tests.au3.md | Core spec coverage complete**

The document addresses all nine significant aspects of the test file: all 7 service states (SPEC-002, SPEC-008), all 5 outcome codes (SPEC-003), all 8 Win32 error code mappings (SPEC-007), single-service failure isolation (SPEC-004), shared-timeout behaviour (SPEC-005), empty-input path (SPEC-006), no-live-stop constraint (SPEC-001). The compilation-breaking duplicate constants finding (STD-001) is the most material issue in the file and is correctly identified as a BLOCKER. No significant omissions found.

**MR-SPEC-002 | PASS | REVIEW-ServiceManager.au3.md | Core spec coverage complete**

The document addresses all nine spec requirements documented in the architecture (REQ-001 through REQ-009), verifies the two-phase loop architecture (SPEC-005), handle ownership (SPEC-007 / full trace table), @error capture (SPEC-008 / full table), access rights (SPEC-006), and the public function signature contract (SPEC-012). The architecture signature divergence for `_SM_GetServiceState` (SPEC-001, rated MAJOR) is identified correctly. No significant omissions found.

**MR-SPEC-003 | MINOR | REVIEW-Stop-Services-Processes.au3.md | New wrapper function _RunServiceBatchStop not fully spec-verified**

The review confirms `_RunServiceBatchStop` calls `_SM_StopServicesBatch` (SPEC-06) and handles all 5 outcome codes (SPEC-07). However, it does not verify:
- Whether `_RunServiceBatchStop` itself is called from the correct place in the monitoring loop (the `ToggleScript` / `_stopservicescustom` replacement path). The review does not confirm whether `_stopservicescustom` was removed or whether `_RunServiceBatchStop` correctly replaces it in the call chain.
- Whether the old `_stopservicescustom` function (which called `ServiceControl.au3` directly) is absent from the new file. This is a scope-creep / regression risk: retaining the old function alongside the new one would be a silent correctness defect.

Evidence: SPEC-06 says only "Line 202: `Local $aResults = _SM_StopServicesBatch(...)`" without confirming the caller or the absence of the superseded function.

**MR-SPEC-004 | MINOR | REVIEW-ServiceManager.au3.md | Phase 2 timeout boundary condition not checked**

The review confirms the two-phase loop structure (SPEC-005) and handle cleanup at timeout (SPEC-007). It does not check whether the shared-batch timeout in Phase 2 uses `$iBatchTimeoutMs` correctly — specifically, whether `TimerDiff($tBatchStart) >= $iBatchTimeoutMs` is the right comparison direction and whether the timer is started before Phase 1 or after. This is a subtle correctness question that belongs on the Spec axis (does the implementation match the architecture's shared-timeout requirement). The review asserts PASS on REQ-003 (two-phase structure) but does not drill into the timeout arithmetic.

**MR-SPEC-005 | INFORMATIONAL | REVIEW-ServiceManager.au3.md | Spec source identity not stated**

SKILL.md step 2 says the spec source must be identified. `REVIEW-ServiceManager.au3.md` cites `ARCHITECTURE.md` throughout its Spec axis but never states explicitly which file/path is the spec source at the top of the Spec section. The document begins with "SPEC-001 | MAJOR | REQ-N/A (Architecture contract)..." without a preamble identifying "spec source: docs/specs/ARCHITECTURE.md" or similar. The other two review documents similarly omit a formal spec-source declaration.

**MR-SPEC-006 | INFORMATIONAL | REVIEW-ServiceManager.Tests.au3.md | Test framework helper coverage implicit**

The review verifies test case functions exhaustively but does not verify that the test framework helpers (`_TestAssert`, `_PrintResults`, `_BuildExpectedRow`) behave correctly (e.g., that `_TestAssert` increments the failure counter on mismatch, that `_PrintResults` outputs a meaningful summary). These are infrastructure correctness questions rather than spec requirements, so their omission is acceptable, but noting them here for completeness.

**MR-SPEC-007 | PASS | REVIEW-Stop-Services-Processes.au3.md | All five target requirements (REQ-010 through REQ-014) covered**

SPEC-01 through SPEC-05 map one-to-one to REQ-010 through REQ-014. All five are verified with line citations and baseline comparisons. The architecture integration requirements (SPEC-06, SPEC-07) are also verified.

**MR-SPEC-008 | INFORMATIONAL | Cross-document | _SM_OUTCOME_* constant-value cross-verification deferred but tracked**

`REVIEW-Stop-Services-Processes.au3.md` SPEC-13 defers verification of `$SM_OUTCOME_*` string values to the ServiceManager review. `REVIEW-ServiceManager.au3.md` does not explicitly close this loop — it verifies the constants exist (they are referenced in the SPEC-003 pass on the results array) but does not state their string values. The chain of verification is incomplete: neither document confirms that e.g. `$SM_OUTCOME_STOPPED` equals `"STOPPED"` as the architecture requires. This is a cross-document coverage gap, not fatal but should have been closed.

### Spec Axis Summary

| ID | Severity | Description |
|---|---|---|
| MR-SPEC-001 | PASS | Tests review covers all spec requirements completely |
| MR-SPEC-002 | PASS | ServiceManager review covers all 9 REQs and architecture contracts |
| MR-SPEC-003 | MINOR | Stop-Services review does not verify call-chain placement of _RunServiceBatchStop or absence of superseded _stopservicescustom |
| MR-SPEC-004 | MINOR | ServiceManager review does not verify Phase 2 timeout arithmetic correctness |
| MR-SPEC-005 | INFORMATIONAL | No explicit spec-source declaration in any review document |
| MR-SPEC-006 | INFORMATIONAL | Test framework helper correctness not verified (acceptable omission) |
| MR-SPEC-007 | PASS | Stop-Services review covers all five targeted requirements |
| MR-SPEC-008 | INFORMATIONAL | $SM_OUTCOME_* constant string values not confirmed in either review; cross-document gap unresolved |

Total: 2 MINOR, 3 INFORMATIONAL, 3 PASS.

---

## Aggregate View by Document

| Document | Standards findings | Spec findings | Overall |
|---|---|---|---|
| REVIEW-ServiceManager.Tests.au3.md | Format deviations only (shared with all docs); content sound | All major requirements covered; no material gaps | Strong |
| REVIEW-ServiceManager.au3.md | Smell findings not labelled as judgement calls | Signature divergence correctly raised; Phase 2 timeout arithmetic unchecked | Good |
| REVIEW-Stop-Services-Processes.au3.md | STD-06/STD-13 duplicate finding with contradictory labels | Call-chain for _RunServiceBatchStop not verified; _stopservicescustom removal not confirmed | Adequate |

---

**One-line summary**: Standards axis — 3 MINOR, 2 INFORMATIONAL across all three documents; worst issue is the absence of a document-level one-line summary and failure to label smell findings as judgement calls (MR-STD-004, MR-STD-005). Spec axis — 2 MINOR, 3 INFORMATIONAL; worst issue is the unverified call-chain placement and absence of superseded function in the Stop-Services review (MR-SPEC-003).
