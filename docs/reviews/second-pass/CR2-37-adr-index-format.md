# CR2-37 — ADR Index and Format Review

**Scope:** `docs/adr/README.md` and ADR files 0001–0010
**Standard:** `ADR-FORMAT.md` (`CLAUDE/skills/domain-modeling/ADR-FORMAT.md`)
**Date:** 2026-11-12

---

## 1. README.md Index Checks

### 1.1 All 10 ADRs indexed (0001–0010)?

FAIL. The README index table contains only 9 rows (0001–0009). ADR-0010
(`0010-main-loop-sleep-timing.md`) exists on disk and was validated against the
codebase, but it has no entry in the index table.

### 1.2 Sequential numbering — no gaps, no duplicates?

The 9 entries that are present are sequential (0001–0009) with no duplicates.
The gap is ADR-0010, which is simply absent from the index (see 1.1 above).

### 1.3 Each ADR's one-line summary accurate?

Checked each indexed entry against the corresponding file. All 9 summaries
accurately reflect the file content. No misleading or outdated phrasing found.

| ADR | Summary in README | Accurate? |
|---|---|---|
| 0001 | Extract batch service-stop into `ServiceManager.au3`, single public function, structured outcomes, one SCM open per batch cycle. | Yes |
| 0002 | `START_PENDING` services are stop-ineligible; `_SM_IsStopEligible` returns `False`; outcome `FAILED` (1061); retry on next cycle. | Yes |
| 0003 | `@error 1` only for batch-level SCM-open failure; per-service failures in outcome strings at `[i][3]`, not in `@error`. | Yes |
| 0004 | `ServiceManager.au3` returns a 2D result array; never interchangeable with `ServiceControl.au3` scalar convention for stop operations. | Yes |
| 0005 | Graceful `SERVICE_CONTROL_STOP` only; no `TerminateProcess` fallback; `TIMED_OUT` services retried on the next cycle. | Yes |
| 0006 | One SCM handle for the entire batch; single fast-fail abort if SCM unavailable; no per-service `OpenSCManagerW` round-trips. | Yes |
| 0007 | Process priorities stored and compared as AutoIt integers (0–5); Windows API hex values converted once at the read boundary. | Yes |
| 0008 | Five SCM APIs called via direct `DllCall` to advapi32.dll; not AutoIt built-ins or `_WinAPI_*` wrappers. | Yes |
| 0009 | `QueryServiceStatus` with 7-DWORD struct used instead of `QueryServiceStatusEx` / 9-DWORD struct. | Yes |
| 0010 | **Missing from index.** | N/A |

### 1.4 "How to Read ADRs" section present?

Pass. The README contains a well-developed "How to Read ADRs" section (lines
93–143) covering:
- Structure of each file (H1 title, context paragraph, optional sections, status)
- When to create a new ADR (all three criteria from the skill)
- Numbering convention

This section is thorough and correctly references the format standard.

### 1.5 Cross-reference to GLOSSARY.md and architecture docs?

Pass. The README contains a "Where to find related documentation" table
(lines 137–144) that links:

| Resource | Path |
|---|---|
| Domain glossary | `GLOSSARY.md` (repo root) |
| Architecture overview | `docs/ARCHITECTURE.md` |
| Coding standards | `CODING_STANDARDS.md` (repo root) |
| ADR format template | `CLAUDE/skills/domain-modeling/ADR-FORMAT.md` |
| Domain modeling skill | `CLAUDE/skills/domain-modeling/SKILL.md` |
| Agent domain configuration | `docs/agents/domain.md` |

Both `GLOSSARY.md` and `docs/ARCHITECTURE.md` are cross-referenced. No issue.

---

## 2. Per-ADR Format Compliance

The format standard (`ADR-FORMAT.md`) requires:
- **H1 title** — short statement of the decision, written as a fact
- **Opening paragraph** — context, decision, and reason (1–3 sentences minimum; longer
  is acceptable when context is genuinely complex)
- **Optional sections** — Considered Options, Consequences, Status — only where warranted
- **Status** — when present, must be one of `proposed`, `accepted`, `deprecated`,
  `superseded by ADR-NNNN`

### ADR-0001 — ServiceManager Module Extraction

- Title: Pass. Short, declarative.
- Opening paragraph: Pass. Clear context (limitation of `_StopService`), explicit decision
  (new module `ServiceManager.au3`, single public function, batch algorithm), and reasoning.
- Optional sections: Considered Options and Consequences present. Both are warranted given
  the architectural significance. Three alternatives documented with rejection rationale.
- Status: Not stated in frontmatter. README lists "Accepted". Acceptable per format standard
  ("When absent, treat the ADR as accepted").
- Format compliance: Pass.

### ADR-0002 — START_PENDING Stop-Ineligible

- Title: Pass.
- Opening paragraph: Pass. The first paragraph provides context (non-deterministic Windows
  behaviour for `START_PENDING`) and the second explains the decision rationale (conservative
  rule, deterministic test harness). The decision is clear.
- Optional sections: Considered Options and Consequences present and warranted.
- Status: Not stated. README lists "Accepted". Pass.
- Format compliance: Pass.

### ADR-0003 — Batch Stop Two-Level Error Convention

- Title: Pass.
- Opening paragraph: Pass. Combined context, decision, and consequence-warning in the first
  paragraph. Concise and clear.
- Optional sections: Considered Options present and warranted.
- Status: Not stated. README lists "Accepted". Pass.
- Format compliance: Pass.

### ADR-0004 — ServiceManager Incompatible with ServiceControl Error Convention

- Title: Pass. Descriptive of the deliberate incompatibility.
- Opening paragraph: Pass. Context (co-existence in same include chain, risk of
  misinterpretation), decision (intentional divergence), and reason (preserving per-service
  outcome data) all present.
- Optional sections: Considered Options and Consequences present. Both warranted.
- Status: Not stated. README lists "Accepted". Pass.
- Format compliance: Pass.

### ADR-0005 — Graceful-Only Service Stop

- Title: Pass.
- Opening paragraph: Pass. First paragraph (line 3–5) states the decision and the mechanism
  clearly.
- Optional sections: This ADR uses an expanded template with explicit ## Context, ## Decision,
  ## Considered options, and ## Consequences sections. This is more verbose than the minimum
  format but is not non-compliant; the standard permits optional sections "when they add
  genuine value." The subject matter (force-kill risks with `NT AUTHORITY\SYSTEM` services)
  justifies the expanded treatment.
- Status: Explicit `**Status:** Accepted` frontmatter on line 3. Pass.
- Format compliance: Pass. Slightly more structured than the minimal template, appropriately so.

### ADR-0006 — Batch-Scoped SCM Handle

- Title: Pass.
- Opening paragraph: Pass. First paragraph covers the decision (one SCM open, held for the
  full batch, closed once) and the deliberate contrast with `ServiceControl.au3`.
- Optional sections: Considered Options and Consequences (including a "Non-obvious" note)
  present and warranted.
- Status: Not stated. README lists "Accepted". Pass.
- Format compliance: Pass.

### ADR-0007 — AutoIt Priority Constants Canonical

- Title: Pass.
- Opening paragraph: Pass. Opens with the problem (two incompatible numbering schemes),
  states the decision (AutoIt integers as canonical; convert at read boundary), and names
  the conversion function.
- Optional sections: Considered Options and Consequences present and warranted.
- Status: Not stated. README lists "Accepted". Pass.
- Format compliance: Pass.

### ADR-0008 — Direct DllCall to advapi32.dll

- Title: Pass.
- Opening paragraph: Pass. Names the five API calls, states the mechanism (DllCall directly),
  and gives the reason (AutoIt built-ins do not expose `SERVICE_STATUS` struct).
- Optional sections: Considered Options and Consequences present and warranted.
- Status: Not stated. README lists "Accepted". Pass.
- Format compliance: Pass.

### ADR-0009 — QueryServiceStatus API Selection

- Title: Pass.
- Opening paragraph: The ADR opens by explaining the prompt-vs-implementation deviation and
  naming the reviews that flagged it, then states the decision. Slightly non-standard
  structure (context leads with audit history rather than technical context) but the
  decision and rationale are clear. Acceptable.
- Optional sections: Explicit ## Decision, ## Rationale, ## Considered options, ##
  Consequences sections. More structured than the minimum; justified by the multi-review
  audit history and the need to document both struct layouts.
- Status: `**Status**: accepted` inline on line 8. Lowercase "accepted" rather than
  "Accepted" — cosmetic inconsistency with ADR-0005 but not a format violation.
- Stale claim check: The ADR does **not** say "No docs/adr/ directory exists." It correctly
  describes the `QueryServiceStatus` selection. Pass.
- Format compliance: Pass.

### ADR-0010 — Main Loop Sleep Timing

- Title: Pass. Descriptive, states both values.
- Opening paragraph: Pass. First paragraph provides context (CR-09 conflation of two loops),
  decision (50 ms passive / 500 ms active), and reasoning (timer gates make sub-500 ms
  unnecessary in the active loop).
- Optional sections: Considered Options and Consequences present and warranted.
- Status: Not stated in frontmatter. README does not list this ADR at all (see finding F-01).
  When present in the index, should be listed as "Accepted."
- Format compliance: Pass.

---

## 3. Stale Claims — "No docs/adr/ directory exists"

The original concern from the task brief was that ADR-0009 might still contain the claim
"No docs/adr/ directory exists." It does not. ADR-0009 (`0009-queryservicestatus-api-selection.md`)
makes no such claim; it is a correctly-scoped record of the `QueryServiceStatus` API selection.

No ADR in the set contains the stale claim. This concern is fully resolved.

---

## 4. Findings Summary

| ID | Severity | File | Finding |
|---|---|---|---|
| F-01 | Major | `docs/adr/README.md` | ADR-0010 is missing from the index table. The file `0010-main-loop-sleep-timing.md` exists and is validated, but has no row in the README's index. |
| F-02 | Minor | `docs/adr/README.md` | The "Validation Notes" section (lines 25–89) covers ADRs 0001–0009 only. ADR-0010 has no corresponding validation note. |
| F-03 | Cosmetic | `docs/adr/0009-queryservicestatus-api-selection.md` | Status written as `**Status**: accepted` (lowercase) rather than `Accepted` as used in ADR-0005. No functional impact. |

---

## 5. Required Actions

**F-01 (Major) — Add ADR-0010 to the README index table.**

The missing row should read:

```
| 0010 | Main Loop Sleep Timing | Accepted | — | The passive main loop retains 50 ms sleep for hotkey/tray responsiveness; the active monitoring loop uses 500 ms because all real work is gated on 2 s / 10 s timers, making a tighter sleep wasteful. |
```

**F-02 (Minor) — Add a validation note for ADR-0010 in the README's Validation Notes section.**

Consistent with the format of the existing nine notes. Should confirm that
`$MAIN_LOOP_SLEEP_MS = 500` and `Sleep(50)` in the passive main loop are verified in the
codebase.

**F-03 (Cosmetic) — Optional.** Capitalise "accepted" to "Accepted" in ADR-0009 for
visual consistency. Low priority.

---

## 6. What Passes

- Numbering is sequential with no gaps for the 9 indexed entries.
- No duplicates in the index.
- All 9 indexed summaries are accurate.
- "How to Read ADRs" section is present and complete.
- Cross-references to `GLOSSARY.md` and `docs/ARCHITECTURE.md` are present.
- All 10 ADRs comply with the format standard (H1 title, opening paragraph with context +
  decision + reason, optional sections only where warranted).
- No ADR contains the stale claim "No docs/adr/ directory exists."
- Status values, where present, use valid terms from the format standard.
- ADR-0005 and ADR-0009 use expanded structures that are within the format standard's
  explicitly permitted optional-sections mechanism.
