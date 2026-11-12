# CR-08: Skills System Addition

**Commit reviewed:** `09b99ba` (Added claude skill sets)
**Fixed point:** `ab5b012`
**Reviewer:** agent (code-review skill)
**Date:** 2026-11-12

---

## Standards

Standards sources consulted: `writing-for-agents/SKILL.md`, `writing-for-agents/SKILL-MECHANICS.md`, smell baseline (Fowler, _Refactoring_ ch.3).

### S1 — `CLAUDE.md` is missing the `## Agent skills` block (hard violation)

`setup-matt-pocock-skills/SKILL.md` step 4 specifies that after setup, the following block must be written into `CLAUDE.md` (the file that already exists):

```markdown
## Agent skills

### Issue tracker
[one-line summary]. See `docs/agents/issue-tracker.md`.

### Domain docs
[one-line summary]. See `docs/agents/domain.md`.
```

No such block exists anywhere in `CLAUDE.md` (170 lines, confirmed). Without it, `docs/agents/issue-tracker.md` and `docs/agents/domain.md` have no context pointer and are unreachable by agents loading `CLAUDE.md`. The files are only accessible via cognitive load — the human must remember they exist and hand them to the agent. The standard states: "The pointer's _wording_, not its target, decides when the agent reaches the material." There is no pointer. Standard: `setup-matt-pocock-skills/SKILL.md` §4 (Write); `writing-for-agents/SKILL.md` §Context pointers.

### S2 — `docs/agents/domain.md` deviates from the seed template, dropping operative rules (hard violation)

The seed template at `.agents/skills/setup-matt-pocock-skills/domain.md` (51 lines) contains these operative sections that are absent from the deployed `docs/agents/domain.md` (19 lines):

- **"Before exploring, read these"** with the "proceed silently" instruction: _"If any of these files don't exist, proceed silently. Don't flag their absence; don't suggest creating them upfront."_ This is a behavioural rule that changes agent output. Its absence means agents may flag missing `GLOSSARY.md` or `docs/adr/` unnecessarily.
- **"Use the glossary's vocabulary"** section: instructs agents to use glossary terms exactly and treat missing terms as a signal for `/domain-modeling`. Absent.
- **"Flag ADR conflicts"** section: instructs agents to surface ADR contradictions explicitly. Absent.

`setup-matt-pocock-skills/SKILL.md` step 4: "write the docs files using the seed templates in this skill folder as a starting point." The deployed file is not based on the seed; it is a reduced manual version. Standard: `setup-matt-pocock-skills/SKILL.md` §4 seed reference.

### S3 — `docs/agents/domain.md` rule 3 contains production guidance that belongs elsewhere (sediment, judgement call)

Rule 3 in `docs/agents/domain.md` reads: _"When a decision is hard-to-reverse, surprising, and was a real trade-off, create an ADR in `docs/adr/` following the format in `.agents/skills/domain-modeling/ADR-FORMAT.md`."_ This is authoring guidance (when to create an ADR), not a consumer rule (how to read existing domain docs). The seed template (`setup-matt-pocock-skills/domain.md`) places ADR guidance under a "Flag ADR conflicts" heading as a reading rule, not a creation rule. The creation rule lives properly in `domain-modeling/SKILL.md`. Placing it here bloats the consumer document with guidance that fires on a different branch. Standard: `writing-for-agents/SKILL.md` §Progressive disclosure — inline what every branch needs, disclose what only some branches reach.

---

## Spec

Spec sources: `docs/agents/issue-tracker.md` (what the issue tracker config must describe), `docs/agents/domain.md` (what the domain config must describe), `setup-matt-pocock-skills/SKILL.md` (the process that produced them).

### SP1 — `CLAUDE.md` `## Agent skills` block was never written (missing requirement)

Spec: `setup-matt-pocock-skills/SKILL.md` §3 (Confirm and edit): _"Show the user a draft of: The `## Agent skills` block to add to whichever of `CLAUDE.md` / `AGENTS.md` is being edited."_ §4 (Write): _"If `CLAUDE.md` exists, edit it."_ Result: `CLAUDE.md` has no `## Agent skills` block. This is the primary output of running `setup-matt-pocock-skills`; every other skill that says "The issue tracker should have been provided to you. If not, tell the user to run `/setup-matt-pocock-skills`" (e.g., `code-review`, `implement-spec`) relies on this block to locate tracker and domain config. The wiring was never completed.

### SP2 — `docs/agents/triage-labels.md` was never written (missing requirement)

Spec: `setup-matt-pocock-skills/SKILL.md` §4: _"Include the `### Triage labels` sub-block, and write `docs/agents/triage-labels.md`, only when `triage` is installed and Section B ran."_ The `triage` skill IS installed at `.agents/skills/triage/SKILL.md`. Per spec, Section B should have run and `docs/agents/triage-labels.md` should exist. It does not. The seed template at `.agents/skills/setup-matt-pocock-skills/triage-labels.md` (the five canonical roles: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`) was never deployed. The `triage` skill reads this file when applying labels.

### SP3 — `docs/agents/domain.md` missing operative rules from spec (partial implementation)

Spec: the seed template `setup-matt-pocock-skills/domain.md` defines the full set of consumer rules. The deployed `docs/agents/domain.md` omits three spec-required sections (see S2 above). Most consequential: the missing "proceed silently" rule. Without it, an agent following only `docs/agents/domain.md` will behave differently from one following the full seed — it may surface noise about absent files, conflicting with the intended silent-proceed behaviour. Spec line: _"If any of these files don't exist, **proceed silently**."_

### SP4 — Issue tracker configuration is correctly implemented (no gap)

`docs/agents/issue-tracker.md` correctly reflects the local-markdown tracker at `.scratch/service-manager-migration/issues/`, numbered `01`–`06` in dependency order. The directory exists with six issue files. The operations section (list, read, close, blocking edges) matches the local-markdown template. The wayfinding section correctly points to the enterprise prompt and `docs/wiki/decisions.md`. No spec gap on the issue tracker.

### SP5 — `docs/agents/domain.md` rule 3 is out of scope (scope creep)

The seed template `setup-matt-pocock-skills/domain.md` does not include an ADR-creation rule. That is authoring guidance belonging to `domain-modeling/SKILL.md`. Adding it here introduces scope the spec did not ask for. Spec line (seed template): the domain.md consumer rules cover reading behaviour only. The creation rule is an addition beyond spec.

---

## Summary

**Standards:** 3 findings — 2 hard violations (missing `## Agent skills` block in `CLAUDE.md`; `docs/agents/domain.md` stripped of operative rules from seed), 1 judgement call (sediment in domain.md rule 3). Worst: S1 — `CLAUDE.md` has no context pointers to any agent config file, leaving the entire skills configuration unreachable by agents.

**Spec:** 4 findings — 2 missing requirements (no `## Agent skills` block; no `triage-labels.md`), 1 partial implementation (`docs/agents/domain.md` missing "proceed silently" rule), 1 scope creep (ADR creation rule in domain.md). Worst: SP1 — the primary output of `setup-matt-pocock-skills` (wiring `CLAUDE.md` → `docs/agents/`) was never produced, so no other skill can locate tracker or domain config autonomously.
