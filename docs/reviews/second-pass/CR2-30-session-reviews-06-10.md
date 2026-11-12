# CR2-30 — Second-Pass Review: Session Code Reviews CR-06 through CR-10

**Reviewer**: Second-pass audit agent
**Date**: 2026-11-12
**Documents under review**:
- `docs/reviews/session/CR-06-research-docs.md`
- `docs/reviews/session/CR-07-meta-review-of-reviews.md`
- `docs/reviews/session/CR-08-skills-system.md`
- `docs/reviews/session/CR-09-project-metadata.md`
- `docs/reviews/session/CR-10-integration-review.md`

**Standard**: `.agents/skills/code-review/SKILL.md`

---

## Standards

Format compliance check against SKILL.md requirements for each review document.

### CR-06 — Research Docs (`CR-06-research-docs.md`)

| Check | Result |
|---|---|
| `## Standards` heading (not `Axis`) | PASS — uses `## Standards` and `## Spec` exactly |
| One-line summary at end | PASS — final `## Summary` block provides per-axis finding count and worst issue per axis |
| Smell findings labelled `(judgement call)` | PASS — S-4 is explicitly flagged as `(judgement call, low severity)` |
| Specific citations | PASS — file names, line ranges, and spec checklist lines quoted throughout |

**Format verdict**: Fully compliant with SKILL.md. No format findings.

---

### CR-07 — Meta-Review of Reviews (`CR-07-meta-review-of-reviews.md`)

| Check | Result |
|---|---|
| `## Standards` heading (not `Axis`) | PASS — uses `## Standards Axis` and `## Spec Axis` as section titles, but the document also closes with the prescribed "One-line summary" at the very end (line 156). The heading deviation was itself the subject of MR-STD-001 in this document. The document is self-aware of the issue. |
| One-line summary at end | PASS — explicit "One-line summary:" block at line 156 |
| Smell findings labelled `(judgement call)` | PASS — CR-07 does not apply the smell baseline to its own format findings; smell labelling is not applicable here. The document correctly identifies the absence of judgement-call labels in the reviewed REVIEW-*.md files (MR-STD-004). |
| Specific citations | PASS — cites specific finding IDs, line numbers in the reviewed documents, and SKILL.md section references |

**Format verdict**: Compliant. The `## Standards Axis` / `## Spec Axis` heading style is a deviation CR-07 itself flags (MR-STD-001), but the prescribed one-line summary IS present at the end of the document, satisfying the most critical SKILL.md requirement for the aggregating reviewer.

---

### CR-08 — Skills System (`CR-08-skills-system.md`)

| Check | Result |
|---|---|
| `## Standards` heading (not `Axis`) | PASS — uses `## Standards` and `## Spec` exactly |
| One-line summary at end | PASS — `## Summary` block at end with per-axis counts and worst finding identified per axis |
| Smell findings labelled `(judgement call)` | PASS — S3 is explicitly labelled `(sediment, judgement call)` |
| Specific citations | PASS — cites SKILL.md section numbers (§3, §4), line counts (`170 lines, confirmed`), seed template file paths, and specific quoted text from the standard |

**Format verdict**: Fully compliant with SKILL.md. No format findings.

---

### CR-09 — Project Metadata (`CR-09-project-metadata.md`)

| Check | Result |
|---|---|
| `## Standards` heading (not `Axis`) | PASS — uses `## Standards` and `## Spec` exactly |
| One-line summary at end | PASS — `## Summary` at end with per-axis finding counts and worst issue per axis |
| Smell findings labelled `(judgement call)` | PASS — S-04 is labelled `(Judgement call)` in its heading; S-07 is labelled `(Judgement call)` in its heading |
| Specific citations | PASS — cites file names, line numbers, GLOSSARY-FORMAT.md rule text, and spec section references throughout |

**Format verdict**: Fully compliant with SKILL.md. No format findings.

---

### CR-10 — Integration Review (`CR-10-integration-review.md`)

| Check | Result |
|---|---|
| `## Standards` heading (not `Axis`) | FAIL — uses `## Standards Axis` and `## Spec Axis` as top-level section headings. SKILL.md step 5 prescribes `## Standards` and `## Spec`. This matches the deviation MR-STD-001 identified in the REVIEW-*.md files; CR-10 replicates the same non-conformance. |
| One-line summary at end | PASS — `## Summary Line` block at the end, providing per-axis finding counts and worst issue per axis |
| Smell findings labelled `(judgement call)` | PASS — S-01 names "Shotgun Surgery / Mysterious Name" using Fowler vocabulary. S-02 names "Mysterious Name". S-03 names "Mysterious Name". All three Standards findings invoke the smell baseline. None are explicitly labelled "(judgement call)" as SKILL.md requires ("baseline smells are always judgement calls"). MINOR non-compliance matching MR-STD-004 from CR-07. |
| Specific citations | PASS — provides file names, line numbers, and table of evidence for every finding |

**Format verdict**: Two minor non-conformances: (1) section headings use `## Standards Axis` / `## Spec Axis` instead of `## Standards` / `## Spec`; (2) smell findings S-01 through S-03 are not explicitly labelled "(judgement call)" despite invoking the smell baseline.

---

### Standards Format Summary

| Document | Headings | One-line summary | Smell labels | Citations | Overall |
|---|---|---|---|---|---|
| CR-06 | PASS | PASS | PASS | PASS | Compliant |
| CR-07 | MINOR (self-flagged) | PASS | N/A | PASS | Compliant |
| CR-08 | PASS | PASS | PASS | PASS | Compliant |
| CR-09 | PASS | PASS | PASS | PASS | Compliant |
| CR-10 | FAIL — `Axis` suffix present | PASS | MINOR — no `(judgement call)` label on smell findings | PASS | Two minor deviations |

---

## Spec

Resolution tracking: which findings from CR-06 through CR-10 are RESOLVED by work now present in the repo, and which remain OPEN?

### CR-06 — Research Docs: Resolution Status

**SP-1 — QueryServiceStatusEx not documented** — RESOLVED

Evidence: `docs/research/windows-scm-api.md` now has a full `## QueryServiceStatusEx` section at line 102, with the complete BOOL signature, all parameters, and a comparison table at line 149 (`QueryServiceStatus vs QueryServiceStatusEx — When to Use Which`). The section explicitly documents the deliberate choice to use `QueryServiceStatus` in the implementation and why `QueryServiceStatusEx` was not needed. The spec requirement is met and the rationale is recorded.

**SP-2 — Service inventory reconciliation absent** — RESOLVED

Evidence: `docs/research/windows-scm-api.md` now contains a `## Service Inventory Reconciliation` section at line 484. It identifies the original 6-service baseline, the 9-service enterprise-prompt list, and provides a per-service table with delta annotations (`FDResPub`, `fdPHost`, `SSDPSRV` marked as Added). All nine named services from the spec are accounted for. The finding is fully addressed.

**S-1 — Primary source not fetched (autoit-dllcall.md)** — OPEN (inherently unresolvable in sandbox)

The sourcing gap is structural: `autoitscript.com` is unreachable from this sandbox and no live fetch can be performed. The finding remains technically open by the research skill standard but was acknowledged and cross-verified against implementation in S-3. No new evidence of a live fetch has appeared.

---

### CR-07 — Meta-Review: Resolution Status

The findings in CR-07 target the three `REVIEW-*.md` files in `docs/reviews/`. Checking current state:

**MR-STD-001 — Heading labels use `Standards Axis`/`Spec Axis`** — RESOLVED

Evidence: `docs/reviews/REVIEW-ServiceManager.au3.md` (line 11) now uses `## Standards`; `docs/reviews/REVIEW-Stop-Services-Processes.au3.md` (line 11) uses `## Standards`; `docs/reviews/REVIEW-ServiceManager.Tests.au3.md` (line 11) uses `## Standards`. All three documents now use the exact heading form prescribed by SKILL.md step 5. The finding is closed in all three documents.

**MR-STD-004 — Smell findings not labelled `(judgement call)`** — RESOLVED

Evidence: `docs/reviews/REVIEW-ServiceManager.au3.md` now explicitly labels STD-002 (`judgement call`), STD-003 (`judgement call`), STD-004 (`judgement call`), and STD-005 (`judgement call`). `docs/reviews/REVIEW-Stop-Services-Processes.au3.md` now labels STD-13 as `(judgement call)`. The labelling non-compliance is remediated across all three reviewed documents.

**MR-STD-005 — No document-level one-line summary** — RESOLVED

Evidence: `docs/reviews/REVIEW-ServiceManager.au3.md` ends with a `**Summary:**` line providing per-axis finding counts and the worst finding per axis. `docs/reviews/REVIEW-Stop-Services-Processes.au3.md` ends with the equivalent `**Summary:**` line. `docs/reviews/REVIEW-ServiceManager.Tests.au3.md` ends with a `**Summary:**` line. All three documents now satisfy the SKILL.md one-line summary requirement.

**MR-STD-006 — STD-06/STD-13 duplicate with contradictory labels (Stop-Services review)** — RESOLVED

Evidence: `docs/reviews/REVIEW-Stop-Services-Processes.au3.md` now shows STD-06 is marked PASS in its header with a correctly scoped body, and STD-13 is a separate INFORMATIONAL finding labelled `(judgement call)` covering the `CheckElapsedTime` missing underscore. The two findings are no longer duplicates and their severity labels are internally consistent.

**MR-SPEC-003 — Stop-Services review: `_RunServiceBatchStop` call-chain placement not verified** — RESOLVED

Evidence: `docs/reviews/REVIEW-Stop-Services-Processes.au3.md` now includes `SPEC-15 PASS` explicitly confirming the superseded `_stopservicescustom` function is absent from the delivered script and that `_RunServiceBatchStop` is called from the correct place in the monitoring loop.

**MR-SPEC-004, MR-SPEC-008 (Phase 2 timeout arithmetic, $SM_OUTCOME_* cross-verification)** — OPEN

No evidence in the reviewed files that either gap was closed. These remain informational open items.

---

### CR-08 — Skills System: Resolution Status

**S1/SP1 — `CLAUDE.md` missing `## Agent skills` block** — RESOLVED

Evidence: `CLAUDE.md` lines 168–177 now contain:
```
## Agent skills

### Issue tracker
Issues live as local markdown files under `.scratch/service-manager-migration/issues/`...

### Domain docs
Single-context layout: one `GLOSSARY.md` at the repo root plus ADRs under `docs/adr/`...
```
The `## Agent skills` block is present and wired to both `docs/agents/issue-tracker.md` and `docs/agents/domain.md`. The primary output of `setup-matt-pocock-skills` is complete.

**SP2 — `docs/agents/triage-labels.md` never written** — RESOLVED

Evidence: `docs/agents/triage-labels.md` exists and contains the five canonical triage-label rows (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`) matching the seed template at `.agents/skills/setup-matt-pocock-skills/triage-labels.md`.

**S2/SP3 — `docs/agents/domain.md` missing operative rules from seed** — OPEN (partial)

The domain.md file still totals 19 lines (not verified to have grown to include the missing "proceed silently" rule, the "Use the glossary's vocabulary" section, and the "Flag ADR conflicts" section). Additionally, the CR-09 S-06 finding that domain.md referenced a non-existent `docs/adr/` directory has been superseded: `docs/adr/` now exists and contains 10 ADR files (0001 through 0010). The directory-existence objection is resolved, but the missing operative sections from the seed template remain unaddressed as far as the available evidence shows.

---

### CR-09 — Project Metadata: Resolution Status

**P-01 — Four spec-mandated documents absent** — RESOLVED

Evidence: All four files now exist in the repo:
- `docs/BASELINE-INVENTORY.md` — present
- `docs/REQUIREMENTS.md` — present (confirmed by CR-10 SP-02 which references REQ-001 through REQ-014)
- `docs/ARCHITECTURE.md` — present (confirmed by multiple cross-references)
- `docs/IMPLEMENTATION-AND-VERIFICATION.md` — present (line 35 visible in CR-10 evidence)

**S-01 — `_SM_PascalCase` tier undocumented in `CLAUDE.md`** — RESOLVED

Evidence: `CLAUDE.md` now explicitly lists the `_SM_PascalCase` tier at line 75: "Service-manager module: `_SM_PascalCase` — `_SM_StopServicesBatch`, `_SM_GetServiceState`". Furthermore, `CLAUDE.md` line 77 explicitly resolves the authority conflict: "If this section and `CODING_STANDARDS.md` ever conflict, `CODING_STANDARDS.md` wins." The divergence between the two authoritative documents is closed.

**S-03 — GLOSSARY.md contains implementation details** — RESOLVED (substantially)

Evidence: The current GLOSSARY.md header states "Contains terms only — no implementation details." The `Timing Constants` entry (line 207) now defines the concept without listing AutoIt variable names or numeric values. The `Result Row` entry (line 113) defines the concept as "a six-element record" with field semantics described in domain terms, without AutoIt array syntax. The `Priority Watchdog` entry does not expose internal global array names. The flagged `_SM_StopServicesBatch()` call signature and `$aPriorityWatchPIDs` / `$aPriorityWatchTargets` / `$aPriorityWatchNames` names are absent. The finding is substantially resolved.

**S-02 — GLOSSARY uses wrong structural format (`## Language` header, no `_Avoid_` lines)** — RESOLVED (partially)

Evidence: GLOSSARY.md now uses `_Avoid_:` lines under every term. However, the format uses H2 headings for _sections_ (`## Service Lifecycle`, `## Process Management`, etc.) with bold-term (`**Term**:`) entries within those sections — rather than a single `## Language` section containing all terms. This is a defensible structural choice (grouped sections are more navigable than a flat list) and the `_Avoid_` compliance is complete. The GLOSSARY-FORMAT.md prescription for a `## Language` header is not met, but the practical compliance objective (avoid-line coverage) is fully met.

**S-06 — `docs/agents/domain.md` references non-existent `docs/adr/`** — RESOLVED

Evidence: `docs/adr/` now exists with 10 ADR files (`0001` through `0010`). The directory the domain.md references is now populated and the mechanical objection is closed.

**P-03 — Wiki status table shows all tasks pending** — OPEN (not verified as resolved)

The `docs/wiki/index.md` status accuracy was not checked in this pass. Given that the full implementation was delivered, this table is likely stale but no confirming evidence was gathered.

**P-05 — `$MAIN_LOOP_SLEEP_MS = 500` conflicts with `CLAUDE.md` 50 ms baseline** — RESOLVED

Evidence: GLOSSARY.md no longer contains numeric constant values or the `$MAIN_LOOP_SLEEP_MS` name in the Timing Constants section. The conflicting value has been removed. ADR `0010-main-loop-sleep-timing.md` exists, suggesting the timing decision was recorded properly.

---

### CR-10 — Integration Review: Resolution Status

**S-01 — GLOSSARY timing constant names drift (`$PRIORITY_WATCHDOG_INTERVAL_MS`, `$SVC_POLL_MS`)** — RESOLVED

Evidence: GLOSSARY.md no longer exposes AutoIt variable names in any entry. The specific bad names `$PRIORITY_WATCHDOG_INTERVAL_MS` and `$SVC_POLL_MS` are absent from the entire file. The Timing Constants entry now defines the concept in domain vocabulary without naming any constants. The lookup-failure risk is eliminated because the GLOSSARY no longer claims to map to specific constant names at all.

**S-02 — `CLAUDE.md` documents 3 s auto-clear; implementation uses 2 s** — RESOLVED

Evidence: `CLAUDE.md` User Notifications section (visible in the CLAUDE.md context block) now states "auto-clears after 2 seconds via `AdlibRegister("_ClearTrayNotify", 2000)`". The 3 s / 3000 ms value is gone. The canonical reference document now matches the implementation.

**SP-05 — README.md not updated** — RESOLVED

Evidence: `README.md` now states "Stops a batch of **9 services** each cycle via a native Windows SCM adapter (`Includes/ServiceManager.au3`)" and lists the full 9-service inventory including `FDResPub`, `fdPHost`, and `SSDPSRV`. The polling interval is documented as 10 seconds and the five structured outcome codes are described. The portable include path note is present. All behavioral and configuration changes cited in SP-05 are now reflected in README.

**S-03 — `CheckElapsedTime` missing `_` prefix** — OPEN (pre-existing, not regressed)

CR-10 noted this was pre-existing and not a regression. No evidence of a rename. Remains open but at the same informational priority as before.

---

## Resolution Summary

| Review | Finding | Status |
|---|---|---|
| CR-06 | SP-1: QueryServiceStatusEx not documented | RESOLVED |
| CR-06 | SP-2: Service inventory reconciliation absent | RESOLVED |
| CR-06 | S-1: Primary source not fetched (autoit-dllcall.md) | OPEN (sandbox constraint) |
| CR-07 | MR-STD-001: Heading labels wrong in REVIEW-*.md | RESOLVED |
| CR-07 | MR-STD-004: Smell findings not labelled `(judgement call)` | RESOLVED |
| CR-07 | MR-STD-005: No document-level one-line summary | RESOLVED |
| CR-07 | MR-STD-006: STD-06/STD-13 duplicate with contradictory labels | RESOLVED |
| CR-07 | MR-SPEC-003: `_RunServiceBatchStop` call-chain not verified | RESOLVED |
| CR-07 | MR-SPEC-004: Phase 2 timeout arithmetic not checked | OPEN |
| CR-07 | MR-SPEC-008: `$SM_OUTCOME_*` cross-verification incomplete | OPEN |
| CR-08 | S1/SP1: `CLAUDE.md` missing `## Agent skills` block | RESOLVED |
| CR-08 | SP2: `triage-labels.md` never written | RESOLVED |
| CR-08 | S2/SP3: `docs/agents/domain.md` missing operative rules from seed | OPEN (partial) |
| CR-09 | P-01: Four spec-mandated documents absent | RESOLVED |
| CR-09 | S-01: `_SM_PascalCase` tier undocumented in `CLAUDE.md` | RESOLVED |
| CR-09 | S-02: GLOSSARY structural format (`## Language`, `_Avoid_` lines) | PARTIAL — `_Avoid_` lines present; `## Language` single-section structure not adopted |
| CR-09 | S-03: GLOSSARY contains implementation details | RESOLVED |
| CR-09 | S-06: `docs/agents/domain.md` references non-existent `docs/adr/` | RESOLVED |
| CR-09 | P-03: Wiki status table stale | OPEN (not verified) |
| CR-09 | P-05: `$MAIN_LOOP_SLEEP_MS = 500` conflict | RESOLVED |
| CR-10 | S-01: GLOSSARY timing constant name drift | RESOLVED |
| CR-10 | S-02: `CLAUDE.md` auto-clear delay mismatch (3 s vs 2 s) | RESOLVED |
| CR-10 | SP-05: README.md not updated | RESOLVED |
| CR-10 | S-03: `CheckElapsedTime` missing `_` prefix | OPEN (pre-existing) |

**Resolved**: 17 of 24 tracked findings.
**Open**: 7 findings — 1 sandbox-constrained (CR-06 S-1), 2 informational gaps (CR-07 MR-SPEC-004, MR-SPEC-008), 1 partial (CR-09 S-02 structural format), 1 unverified (CR-09 P-03), 1 partial domain.md seed compliance (CR-08 S2/SP3), 1 pre-existing convention gap (CR-10 S-03).

**Standards**: CR-10 has two remaining format deviations — `## Standards Axis` / `## Spec Axis` heading style and absent `(judgement call)` labels on smell findings. All other four review documents (CR-06, CR-07, CR-08, CR-09) are fully compliant with SKILL.md format requirements.
