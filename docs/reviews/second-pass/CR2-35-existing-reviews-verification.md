# CR2-35: Second-Pass Verification of Existing Review Documents
Reviewer: Independent Verification Agent
Date: 2026-11-12
Scope: Post-T1-12 format compliance check against `.agents/skills/code-review/SKILL.md`

Documents verified:
- `docs/reviews/REVIEW-ServiceManager.Tests.au3.md`
- `docs/reviews/REVIEW-ServiceManager.au3.md`
- `docs/reviews/REVIEW-Stop-Services-Processes.au3.md`

---

## Verification Checklist Results

### Check 1 — Headings: `## Standards` and `## Spec` (not `## Standards Axis` / `## Spec Axis`)

**Result: PASS on all three documents.**

The original CR-07 meta-review (MR-STD-001) flagged all three documents for using `## Standards Axis` and `## Spec Axis`. After T1-12 fixes, all three documents now use the SKILL.md-prescribed headings exactly:

| Document | Standards heading | Spec heading |
|---|---|---|
| REVIEW-ServiceManager.Tests.au3.md | `## Standards` | `## Spec` |
| REVIEW-ServiceManager.au3.md | `## Standards` | `## Spec` |
| REVIEW-Stop-Services-Processes.au3.md | `## Standards` | `## Spec` |

This check is fully resolved.

---

### Check 2 — All smell findings labeled `(judgement call)`

**Result: PARTIAL PASS — two gaps remain.**

SKILL.md requires: "baseline smells are always judgement calls" and that the distinction between hard violations and judgement calls must be explicit.

**REVIEW-ServiceManager.au3.md**: STD-002, STD-003, STD-004, STD-005 all include `(judgement call)` in their finding headers. This is correct and fully compliant.

**REVIEW-Stop-Services-Processes.au3.md**: Two issues:

1. STD-13 carries `(judgement call)` in its header (`STD-13 — INFORMATIONAL — CheckElapsedTime Missing Underscore Prefix (judgement call)`). Correct.
2. STD-02 (`CheckElapsedTime` missing underscore prefix) is documented inside the STD-02 body as "Severity: MINOR" — but the STD-02 header reads `STD-02 — PASS — Function Naming: Private/Internal Functions`. The naming-inconsistency note at the bottom of STD-02 is a judgement-call smell (naming convention / implied Mysterious Name), and it is not labelled `(judgement call)`. This is the same finding that STD-13 covers more completely, but STD-02's inline severity note lacks the label.

**REVIEW-ServiceManager.Tests.au3.md**: No smell-baseline findings invoked. Acceptable — no applicable smell was identified by the reviewer.

**Gap**: STD-02 in REVIEW-Stop-Services-Processes.au3.md embeds a MINOR severity note inside a PASS-headed finding block without a `(judgement call)` label. Minor non-conformance; STD-13 covers the same point correctly.

---

### Check 3 — One-line summary at end of each file

**Result: PASS on all three documents.**

Each document ends with a bold one-line summary in the form prescribed by SKILL.md step 5 (total findings per axis, worst issue per axis):

| Document | Summary present | Form correct |
|---|---|---|
| REVIEW-ServiceManager.Tests.au3.md | Yes (final line, bold) | Yes — counts Standards and Spec findings, worst issue named per axis |
| REVIEW-ServiceManager.au3.md | Yes (final line, bold) | Yes — counts Standards findings (5: 1 hard, 4 judgement call), 2 Spec findings, worst per axis stated |
| REVIEW-Stop-Services-Processes.au3.md | Yes (final line, bold) | Yes — counts findings, worst Standards and Spec issue named |

This check is fully resolved.

---

### Check 4 — No contradictory PASS/MINOR labels

**Result: FAIL — one structural contradiction remains in REVIEW-Stop-Services-Processes.au3.md.**

CR-07 flagged MR-STD-006: STD-06 header reads `PASS` but the body concludes MINOR, and STD-13 is a near-duplicate of the same point. This was a T1-12 fix target. Current state:

**STD-06** header: `**STD-06 — MINOR — Logging via _LogMessage**`

The STD-06 header now correctly reads MINOR (not PASS) — this portion of the fix is confirmed.

However, **STD-02** still exhibits a contradictory label: its header reads `**STD-02 — PASS — Function Naming: Private/Internal Functions (_UnderscorePascalCase)**`, but the body concludes with `Severity: MINOR` (the `CheckElapsedTime` naming note). A PASS-headed finding that concludes MINOR internally is a formatting contradiction. This is a residual issue not addressed by T1-12.

Summary of label contradictions:
| Finding | Header label | Body conclusion | Contradiction? |
|---|---|---|---|
| STD-02 (Stop-Services) | PASS | MINOR (CheckElapsedTime note) | YES — residual |
| STD-06 (Stop-Services) | MINOR | MINOR | No — resolved |

---

### Check 5 — No duplicate findings

**Result: PARTIAL — STD-02 / STD-13 duplication persists in REVIEW-Stop-Services-Processes.au3.md.**

CR-07 flagged STD-06/STD-13 as a duplicate pair with contradictory labels. After T1-12:
- STD-06 is now labelled MINOR and covers `_miscpopups` bare ConsoleWrite calls.
- STD-13 covers `CheckElapsedTime` missing underscore prefix — a different finding.

The original STD-06/STD-13 duplication is **resolved**. However, the same underlying finding (`CheckElapsedTime` missing `_` prefix) is now documented twice:
- In the body of STD-02 (unnamed inline note, labelled Severity: MINOR)
- In STD-13 (standalone INFORMATIONAL finding, labelled `(judgement call)`)

These two entries cover the same code location with different severity labels (MINOR vs INFORMATIONAL). This is a residual duplicate-with-contradictory-severity situation, though lower impact than the original STD-06/STD-13 pair since both concern the same private helper.

No duplicate findings detected in REVIEW-ServiceManager.au3.md or REVIEW-ServiceManager.Tests.au3.md.

---

### Check 6 — SPEC-15 PASS finding confirming `_stopservicescustom` removed (Stop-Services)

**Result: PASS — SPEC-15 is present and correctly formed.**

`REVIEW-Stop-Services-Processes.au3.md` contains:

> **SPEC-15 — PASS — Superseded function `_stopservicescustom` confirmed removed**

The finding (lines 199–204) explicitly confirms that no definition or call site for `_stopservicescustom` exists in the current file, and that the monitoring loop calls `_RunServiceBatchStop()` exclusively. This directly addresses MR-SPEC-003 from CR-07.

---

### Check 7 — STD-06 header correctly shows MINOR (not PASS) (Stop-Services)

**Result: PASS — STD-06 header now reads MINOR.**

Before T1-12, STD-06 header read `STD-06 — PASS — Logging via _LogMessage` while the body concluded MINOR. The current document shows:

> `**STD-06 — MINOR — Logging via _LogMessage**`

The header label is now consistent with the body severity. This specific fix is confirmed.

---

## Findings Outdated by Team 1 Fixes

Based on the fix record in `docs/IMPLEMENTATION-AND-VERIFICATION.md` (Gate 6 and Accepted Minor/Informational Findings table), the following findings in the existing reviews are now outdated because the underlying code defects have been remediated:

### REVIEW-Stop-Services-Processes.au3.md

| Finding | Original issue | T1 fix | Current status |
|---|---|---|---|
| STD-06 MINOR — `_miscpopups` bare ConsoleWrite | Lines 588, 592 used `ConsoleWrite` directly | T1-11: replaced with `_LogMessage` | **Outdated — code fixed.** STD-06 describes a defect that no longer exists in the source. The finding should be marked RESOLVED or annotated as fixed. |
| STD-13 INFORMATIONAL — `CheckElapsedTime` missing `_` prefix | Naming inconsistency | No T1 fix recorded | Still active — not remediated. |
| STD-02 inline MINOR — same `CheckElapsedTime` note | Same as STD-13 | No T1 fix recorded | Still active. |

**Notable**: STD-06 is now a stale finding. It documents a MINOR violation that the IMPLEMENTATION-AND-VERIFICATION.md Gate 6 explicitly records as "RESOLVED — replaced with `_LogMessage`". Readers of the review document will see a standing MINOR finding that no longer reflects the source code state. The review document was not updated to mark STD-06 as RESOLVED after the fix.

### REVIEW-ServiceManager.au3.md

| Finding | Original issue | T1 fix | Current status |
|---|---|---|---|
| STD-002 MINOR — `$jj` Mysterious Name | Loop variable `$jj` at line 324 | T1-12: renamed to `$iTimeoutIdx` per IMPLEMENTATION-AND-VERIFICATION.md "RESOLVED" row | **Outdated — code fixed.** The finding documents a variable name that no longer exists. |
| SPEC-001 MAJOR — `_SM_GetServiceState` signature diverges from ARCHITECTURE.md | One-param vs two-param signature | T1-12: ARCHITECTURE.md updated per IMPLEMENTATION-AND-VERIFICATION.md "RESOLVED — updated ARCHITECTURE.md" | **Outdated — documentation fixed.** The divergence was resolved by updating the architecture document. |

Both SPEC-001 and STD-002 in REVIEW-ServiceManager.au3.md are recorded as RESOLVED in the implementation report but remain as open findings in the review document with no inline RESOLVED annotation.

### REVIEW-ServiceManager.Tests.au3.md

| Finding | Original issue | T1 fix | Current status |
|---|---|---|---|
| STD-001 BLOCKER — duplicate `Global Const` declarations | Lines 36–49 of test file redeclared constants from ServiceManager.au3 | T1-12: duplicate declarations removed per IMPLEMENTATION-AND-VERIFICATION.md "RESOLVED" row | **Outdated — code fixed.** The BLOCKER no longer applies to the current source. |

STD-001 remains labelled BLOCKER in the review document with no inline annotation indicating it was resolved. The Disposition section says "Required before merge: Remove the duplicate `Global Const` declarations" — this reads as an open action item, not a closed one. For a reader encountering only this review document, the most critical finding appears unresolved.

---

## Summary by Document

### REVIEW-ServiceManager.Tests.au3.md

| Check | Result |
|---|---|
| `## Standards` / `## Spec` headings | PASS |
| Smell findings labelled `(judgement call)` | PASS (no smell findings invoked) |
| One-line summary present | PASS |
| No contradictory PASS/MINOR labels | PASS |
| No duplicate findings | PASS |
| Outdated findings (T1 fixes) | STD-001 BLOCKER outdated — fix applied but document not annotated |

### REVIEW-ServiceManager.au3.md

| Check | Result |
|---|---|
| `## Standards` / `## Spec` headings | PASS |
| Smell findings labelled `(judgement call)` | PASS |
| One-line summary present | PASS |
| No contradictory PASS/MINOR labels | PASS |
| No duplicate findings | PASS |
| Outdated findings (T1 fixes) | STD-002 MINOR and SPEC-001 MAJOR both outdated — fixes applied but document not annotated |

### REVIEW-Stop-Services-Processes.au3.md

| Check | Result |
|---|---|
| `## Standards` / `## Spec` headings | PASS |
| Smell findings labelled `(judgement call)` | PARTIAL — STD-02 inline MINOR note lacks `(judgement call)` label |
| One-line summary present | PASS |
| No contradictory PASS/MINOR labels | FAIL — STD-02 header reads PASS, body concludes MINOR |
| No duplicate findings | PARTIAL — STD-02 and STD-13 both document `CheckElapsedTime` with differing severities |
| SPEC-15 present (\_stopservicescustom removed) | PASS |
| STD-06 header correctly shows MINOR | PASS |
| Outdated findings (T1 fixes) | STD-06 MINOR outdated — fix applied (T1-11) but document not annotated RESOLVED |

---

## Recommended Actions

The following are discrete items that would bring the review documents into full compliance and accuracy. None are blockers to the branch merge (the implementation fixes have already been applied); these are documentation hygiene items.

1. **REVIEW-ServiceManager.Tests.au3.md — STD-001**: Annotate the finding and Disposition section to record that the duplicate `Global Const` declarations were removed by T1-12. The BLOCKER label should be followed by `[RESOLVED — T1-12]`.

2. **REVIEW-ServiceManager.au3.md — STD-002**: Annotate the `$jj` finding as `[RESOLVED — T1-12: renamed to $iTimeoutIdx]`.

3. **REVIEW-ServiceManager.au3.md — SPEC-001**: Annotate the architecture signature divergence finding as `[RESOLVED — T1-12: ARCHITECTURE.md updated to match one-parameter implementation]`.

4. **REVIEW-Stop-Services-Processes.au3.md — STD-06**: Annotate the `_miscpopups` ConsoleWrite finding as `[RESOLVED — T1-11: replaced with _LogMessage calls]`.

5. **REVIEW-Stop-Services-Processes.au3.md — STD-02**: Either (a) change the header label from PASS to MINOR to match the body conclusion, or (b) extract the inline MINOR note into a standalone finding. Either way, add `(judgement call)` to the label since it is a naming-convention smell.

6. **REVIEW-Stop-Services-Processes.au3.md — STD-02 / STD-13 duplication**: STD-13 already covers the `CheckElapsedTime` naming issue as a proper standalone INFORMATIONAL `(judgement call)` finding. The inline note in STD-02 is redundant and contradicts STD-13's severity. Consider removing the inline severity note from STD-02's body, deferring entirely to STD-13.

---

**Summary:** All three review documents now use `## Standards` / `## Spec` headings (Check 1 — PASS) and all three have correct one-line summaries (Check 3 — PASS). The STD-06 header in Stop-Services correctly shows MINOR (Check 7 — PASS). SPEC-15 confirming `_stopservicescustom` removal is present (Check 6 — PASS). Two residual format issues exist in REVIEW-Stop-Services-Processes.au3.md: STD-02's PASS header contradicts its MINOR body conclusion (Check 4 — FAIL), and STD-02/STD-13 cover the same finding with differing severities (Check 5 — PARTIAL). Three review documents contain findings that are now outdated due to T1-11 (STD-06 ConsoleWrite fix) and T1-12 (STD-001 BLOCKER resolved, STD-002 $jj renamed, SPEC-001 architecture doc updated) — none annotated RESOLVED in-document.
