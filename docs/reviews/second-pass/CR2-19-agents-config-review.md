# CR2-19 — Agent Configuration Files Review

**Review date:** 2026-11-12
**Files reviewed:**
- `docs/agents/domain.md`
- `docs/agents/issue-tracker.md`
- `docs/agents/triage-labels.md`

**Spec sources:**
- `.agents/skills/setup-matt-pocock-skills/domain.md` (seed template)
- `.agents/skills/setup-matt-pocock-skills/issue-tracker-local.md`
- `.agents/skills/setup-matt-pocock-skills/triage-labels.md`

**Skill used:** `.agents/skills/code-review/SKILL.md`

---

## Standards

### domain.md

**S1 — All 3 operative sections present: PASS**

All three required operative sections are present in the deployed file:

1. `## Before exploring, read these` — the proceed-silently instruction is present and correctly worded: "If any of these files don't exist, **proceed silently**."
2. `## Use the glossary's vocabulary` — vocabulary enforcement section is present.
3. `## Flag ADR conflicts` — ADR conflict flagging section is present.

**S2 — No ADR-creation guidance in consumer rules: PASS**

The deployed `docs/agents/domain.md` does not contain any ADR-creation guidance. The seed template itself also does not include such guidance. The finding from prior review CR-08 (S3/SP3) that "rule 3 contains ADR-creation guidance" referred to an earlier state of the file. The current deployed file's Consumer Rules section contains only three rules: read GLOSSARY.md before writing, update GLOSSARY.md when new terms are agreed, and keep GLOSSARY.md to domain vocabulary only. None of these is ADR-creation guidance. This finding is resolved in the current file.

**S3 — Points to `docs/adr/` correctly: PASS with caveat**

The file correctly references `docs/adr/` in the "Before exploring, read these" list and in both file-structure diagrams. The reference is accurate as a pointer.

Caveat: `docs/adr/` does not currently exist in the repository (confirmed by filesystem check — no files found under that path). The seed template's proceed-silently instruction covers this case explicitly: agents are instructed not to flag the absence or suggest creating it upfront. The pointer is therefore correct and the missing directory is handled by design. No defect.

---

### issue-tracker.md

**S4 — Points to `.scratch/service-manager-migration/issues/`: PASS**

The file correctly identifies the issue path as `.scratch/service-manager-migration/issues/` throughout — in the header, the Operations section, and the Current Issue Status table.

**S5 — New issue creation instructions present: PASS**

A full "Creating New Issues" section is present (lines 59–88) with a numbered procedure, required field template, and instructions for status assignment and source-reference linking. This section exceeds what the seed template (`issue-tracker-local.md`) provides — the seed template contains no equivalent new-issue creation guidance at all. This is a deliberate extension, not a deviation.

**S6 — Issue lifecycle documented: PASS**

The Operations section documents all lifecycle transitions:
- Claim: set `Status: claimed`
- Resolve: append `## Answer`, set `Status: resolved`, update `docs/wiki/decisions.md`
- Close: move file to `closed/` subdirectory
- Blocking edges: defined per-ticket via `Blocked by:` field

The Current Issue Status table documents the live state of all six open issues with their blocking relationships. This is significantly richer than the seed template, which only describes the generic pattern without any live-state snapshot.

**S7 — Deviation from seed template (resolved pointer): NOTE**

The seed template (`issue-tracker-local.md`) references `triage-labels.md` without a path prefix (line 10: "see `triage-labels.md` for the role strings"). The deployed file correctly uses the full path `docs/agents/triage-labels.md`. This is an improvement, not a defect.

---

### triage-labels.md

**S8 — All 5 canonical labels present: PASS**

The deployed file contains all five canonical labels with correct string values and meanings:

| Label | Present |
|---|---|
| `needs-triage` | Yes |
| `needs-info` | Yes |
| `ready-for-agent` | Yes |
| `ready-for-human` | Yes |
| `wontfix` | Yes |

The deployed file is a verbatim match of the seed template (`setup-matt-pocock-skills/triage-labels.md`). The "Label in our tracker" column uses the same strings as "Label in mattpocock/skills" — a valid choice indicating the repo uses the canonical strings without remapping.

---

## Spec

### Do these files give agents enough context to work in this repo without asking questions?

**domain.md: YES**

An agent reading `docs/agents/domain.md` knows exactly what to read before starting (`GLOSSARY.md`, `GLOSSARY-MAP.md` if present, relevant ADRs under `docs/adr/`), what to do if those files don't exist (proceed silently), how to handle vocabulary (use `GLOSSARY.md` terms verbatim, flag gaps), and what to do if output contradicts an existing ADR (surface it explicitly with the prescribed wording). `GLOSSARY.md` exists and is substantive (346 lines of well-defined domain vocabulary). An agent has everything it needs.

**issue-tracker.md: YES**

An agent reading `docs/agents/issue-tracker.md` knows the storage path, file naming scheme, required fields, status lifecycle, blocking semantics, how to create new issues, and where the wayfinding map and decisions log live. The Current Issue Status table gives an agent immediate situational awareness without requiring a filesystem scan. No unanswered questions remain.

**triage-labels.md: YES**

An agent reading `docs/agents/triage-labels.md` can resolve any triage role mentioned in a skill to the correct local label string. The five-row mapping table covers all roles. The trailing instruction ("When a skill mentions a role... use the corresponding label string from this table") makes the usage pattern explicit.

---

### Is the GLOSSARY.md vocabulary enforcement rule actionable?

**YES, with one gap worth noting.**

The enforcement rule in `docs/agents/domain.md` has two parts:

1. "Use the terms it defines exactly — do not substitute synonyms." — Actionable. `GLOSSARY.md` is present, comprehensive (346 lines, all major domain concepts defined), and each entry includes explicit `_Avoid_` lists of banned synonyms. An agent can apply the rule mechanically.

2. "If the concept you need isn't in the glossary yet, that's a signal: either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `/domain-modeling`)." — Actionable in principle, but the action it prescribes (`/domain-modeling`) names a skill that may or may not be installed. The rule doesn't tell an agent what to do if that skill is absent. This is a minor gap: if the agent cannot invoke `/domain-modeling`, the guidance trails off. A harder fallback ("flag it in a comment and continue" or "raise it in the issue tracker") would make this branch fully actionable.

The enforcement rule is actionable in the common case. The gap only surfaces when an agent discovers a missing glossary term — a less frequent path.

---

## Summary

**Standards axis:** 0 hard violations, 1 informational note (S7, resolved deviation), 1 caveat (S3, `docs/adr/` absent but handled by proceed-silently design). All 3 operative sections in `domain.md` present; no ADR-creation guidance in consumer rules; `docs/adr/` pointer is correct; issue tracker points to the correct path; new-issue creation instructions present; lifecycle documented; all 5 canonical triage labels present.

**Spec axis:** All three files give agents sufficient context to operate without asking questions. The GLOSSARY.md vocabulary enforcement rule is actionable for the common case; the missing-term branch names a skill (`/domain-modeling`) without a fallback for when that skill is absent — minor gap, not a blocker.

**Worst issue per axis:**
- Standards: none (no violations found).
- Spec: the `/domain-modeling` fallback gap in the vocabulary enforcement rule — low severity, affects only the missing-term code path.
