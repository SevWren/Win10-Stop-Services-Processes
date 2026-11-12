# Issue Tracker

## Type: Local Markdown

Issues for this effort live as markdown files under:
`.scratch/service-manager-migration/issues/`

Numbered `01`–`06` in dependency order (blockers first).

## Conventions

- One feature per directory: `.scratch/<feature-slug>/`
- The spec is `.scratch/<feature-slug>/spec.md`
- Implementation issues are one file per ticket at `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01`, never a single combined tickets file
- Triage state is recorded as a `Status:` line near the top of each issue file (see `docs/agents/triage-labels.md` for the role strings)
- Comments and conversation history append to the bottom of the file under a `## Comments` heading

## Triage Labels

See `docs/agents/triage-labels.md` for the full label map. The five canonical roles are:

| Status string       | Meaning                                          |
| ------------------- | ------------------------------------------------ |
| `needs-triage`      | Maintainer needs to evaluate this issue          |
| `needs-info`        | Waiting on reporter for more information         |
| `ready-for-agent`   | Fully specified, ready for an AFK agent          |
| `ready-for-human`   | Requires human implementation                    |
| `wontfix`           | Will not be actioned                             |

## Current Issue Status

All six issues are in `.scratch/service-manager-migration/issues/`. None have been moved to `closed/`; all are open. Status is as found in each file's `Status:` line:

| File                                 | Title                                          | Status            | Blocked by |
| ------------------------------------ | ---------------------------------------------- | ----------------- | ---------- |
| `01-baseline-discovery.md`           | Discover and Freeze the Baseline               | `ready-for-agent` | None       |
| `02-contracts-and-api-verification.md` | Define Contracts and Verify Windows SCM APIs | `ready-for-agent` | 01         |
| `03-build-servicemanager.md`         | Build ServiceManager.au3 + Deterministic Test Harness | `ready-for-agent` | 02  |
| `04-integration.md`                  | Integrate ServiceManager into Main Script      | `ready-for-agent` | 03         |
| `05-independent-review.md`           | Independent Code Review — All Modified .au3 Files | `ready-for-agent` | 04      |
| `06-validation-and-delivery.md`      | Validate, Compile, Deliver Acceptance Report   | `ready-for-agent` | 05         |

Frontier (open, unblocked, unclaimed): **01** only. All subsequent issues are blocked until their predecessors are resolved.

## Operations

**List issues**: `ls .scratch/service-manager-migration/issues/`

**Read an issue**: `cat .scratch/service-manager-migration/issues/01-baseline-discovery.md`

**Claim an issue**: Set `Status: claimed` in the file and save before starting any work.

**Resolve an issue**: Append the answer under an `## Answer` heading, set `Status: resolved`, then append a context pointer to `docs/wiki/decisions.md` under Decisions-so-far.

**Close an issue**: After resolving, move the file to `.scratch/service-manager-migration/issues/closed/`

**Blocking edges**: Listed in each issue file's `**Blocked by**` field. A ticket is unblocked when every file it lists is `resolved`.

## Creating New Issues (for open findings from session reviews)

When a session review (e.g. `docs/reviews/session/`) surfaces findings that require follow-up work, create a new issue file as follows:

1. Determine the next available issue number by running `ls .scratch/service-manager-migration/issues/` and incrementing past the highest `NN` present.
2. Create `.scratch/service-manager-migration/issues/<NN>-<slug>.md` — one file per ticket, never bundle multiple findings into one file.
3. Required fields at the top of the file:
   ```
   # <NN>: <Short title>

   **What to build:** <one-paragraph description of the deliverable>

   **Blocked by:** <NN, NN or "None">

   **Status:** needs-triage
   ```
4. Add a checklist of concrete tasks under the header fields.
5. Set `Status: needs-triage` until a maintainer or agent has evaluated the finding; promote to `ready-for-agent` once the scope is confirmed.
6. Reference the source review finding (e.g. `CR-08-skills-system.md §S1`) in the issue body so the link back to evidence is preserved.

**Open findings from CR-08 that require new issues:**

The session review `docs/reviews/session/CR-08-skills-system.md` identified the following findings that are not covered by issues 01–06 and need new issues created:

- **SP1 / S1** — `CLAUDE.md` `## Agent skills` block was never written. (Hard violation; primary wiring output of `setup-matt-pocock-skills`.)
- **SP2** — `docs/agents/triage-labels.md` was never written. (Missing requirement; `triage` skill is installed but its label map file is absent.)
- **S2 / SP3** — `docs/agents/domain.md` is missing operative rules from the seed template: "Before exploring, read these" / "proceed silently" instruction, "Use the glossary's vocabulary" section, and "Flag ADR conflicts" section.
- **S3 / SP5** — `docs/agents/domain.md` rule 3 contains ADR-creation guidance that belongs in `domain-modeling/SKILL.md`, not in the consumer document (judgement call / scope creep).

Create one issue file per finding group above, using the next available numbers after `06`.

## Wayfinding Operations

The map for this effort is the enterprise prompt at:
`Enterprise-Grad_Multi-Agent_Engineering_Implementation_Testing_Adversarial_Audit_AutoIt_prompt.md`

Decisions-so-far are tracked in `docs/wiki/decisions.md`.
