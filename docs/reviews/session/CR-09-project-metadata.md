# CR-09 — Project Metadata Review

**Fixed point:** `ab5b012`
**HEAD commits in range:**
- `1d8a5ea` feat: replace broken service-stop path with native SCM batch-stop module
- `2a62801` chore(cleanup)
- `09b99ba` Added claude skill sets

**Files reviewed:** `CODING_STANDARDS.md`, `GLOSSARY.md`, `docs/wiki/index.md`,
`docs/wiki/environment.md`, `docs/wiki/decisions.md`, `docs/wiki/blockers.md`,
`docs/agents/domain.md`, `docs/agents/issue-tracker.md`

**Standards sources:** `CLAUDE.md`, `.agents/skills/domain-modeling/SKILL.md`,
`.agents/skills/domain-modeling/GLOSSARY-FORMAT.md`, Fowler smell baseline (code-review SKILL.md §3)

**Spec source:** `Enterprise-Grad_Multi-Agent_Engineering_Implementation_Testing_Adversarial_Audit_AutoIt_prompt.md`

---

## Standards

### S-01 — Undocumented naming-convention extension (Hard violation)

**File:** `CODING_STANDARDS.md` — Function Naming section

`CODING_STANDARDS.md` introduces a third function-naming tier `_SM_PascalCase` (e.g.,
`_SM_StopServicesBatch`, `_SM_GetServiceState`) that does not exist in `CLAUDE.md`. The
preamble declares the file is "derived from `CLAUDE.md`", not an extension of it. `CLAUDE.md`
defines exactly two tiers: `PascalCase` for hotkey-triggered/public, `_UnderscorePascalCase`
for internal/private. Adding a module-prefix tier without an authoritative decision creates
a divergence between the two authoritative documents and would cause the Standards reviewer
to flag any `_SM_*` name as a violation of `CLAUDE.md`.

**Fix:** Either remove the `_SM_PascalCase` tier and fold these functions into
`_UnderscorePascalCase`, or add an ADR recording the decision to extend the naming scheme
and update `CLAUDE.md` to match.

---

### S-02 — GLOSSARY.md uses wrong structural format (Hard violation)

**File:** `GLOSSARY.md` — all entries

GLOSSARY-FORMAT.md requires:
1. A `## Language` section header containing entries in bold-term format (`**Term**:`).
2. An `_Avoid_` line under each term that has known synonyms.

`GLOSSARY.md` instead uses H2 headings for each term (`## Service Handle`, `## Batch Stop`,
etc.) and has no `_Avoid_` lines anywhere. This is a structural mismatch with the prescribed
format. Terms with obvious synonyms that need `_Avoid_` entries include at minimum:
- **Service Handle** — avoid: service descriptor, service reference
- **Priority Class** — avoid: priority level, priority value
- **Service Inventory** / **Process Inventory** — avoid: service list, process list, watchlist
- **Batch Stop** — avoid: bulk stop, batch kill

---

### S-03 — GLOSSARY.md contains implementation details (Hard violation)

**File:** `GLOSSARY.md` — entries: Batch Stop, Result Row, Priority Watchdog, Timing Constants

GLOSSARY-FORMAT.md rule and `domain-modeling/SKILL.md` are unambiguous: "GLOSSARY.md should
be totally devoid of implementation details." The following entries violate this:

- **Batch Stop**: names `_SM_StopServicesBatch()` with its call signature shape and internal
  polling behavior — this is a function spec, not a domain term.
- **Result Row**: defines a six-element AutoIt array `[$sName, $iInitialState, $iFinalState,
  $sOutcome, $iWin32Error, ""]` — this is a data structure definition.
- **Priority Watchdog**: names internal global arrays `$aPriorityWatchPIDs`,
  `$aPriorityWatchTargets`, `$aPriorityWatchNames` — these are implementation artifacts.
- **Timing Constants**: lists AutoIt variable names and numeric values (`$PROC_POLL_INTERVAL_SEC
  = 2`, `$SVC_BATCH_TIMEOUT_MS = 20000`, etc.) — this is a configuration spec.

Domain terms should define what a concept *is*, not how it is implemented.

---

### S-04 — Partial smell baseline embedded in CODING_STANDARDS.md (Judgement call)

**File:** `CODING_STANDARDS.md` — "Smell Baseline" section

The Standards section of `CODING_STANDARDS.md` embeds four of the twelve Fowler smells
(Mysterious Name, Duplicated Code, Speculative Generality, Shotgun Surgery). The authoritative
full baseline lives in `.agents/skills/code-review/SKILL.md` and is designed to be pasted
verbatim into every Standards sub-agent prompt. Embedding a partial subset in
`CODING_STANDARDS.md` creates a secondary, truncated baseline that could drift from the
canonical one and cause reviewers to skip the eight unlisted smells. This is Speculative
Generality: it adds a secondary smell list for a need already covered by the review toolchain.

**Fix:** Remove the "Smell Baseline" section from `CODING_STANDARDS.md`. The review SKILL.md
already mandates pasting the full baseline into each Standards sub-agent.

---

### S-05 — Path portability standard conflicts with CLAUDE.md frozen paths (Hard violation)

**File:** `CODING_STANDARDS.md` — "Path Portability" section

`CODING_STANDARDS.md` states: "All project asset paths derive from `@ScriptDir`." However,
`CLAUDE.md` explicitly documents and freezes machine-specific paths that do not derive from
`@ScriptDir`:

- `$iconfile` = `%HOMEDRIVE%\Users\mmuel\Documents\AutoIT\ff7.ico`
- `$sLogFile` = `@HomeDrive & "\login\closure_log.txt"`
- `#AutoIt3Wrapper_Outfile_x64` = `..\..\..\Users\mmuel\Desktop\Stop Services - Processes.Exe`

`CLAUDE.md` says these "must not be changed without explicit instruction." The standard as
written would require changing them, contradicting a higher-authority document. The standard
should carve out the `CLAUDE.md`-frozen paths explicitly, or limit the portability rule to
newly written code only.

---

### S-06 — docs/agents/domain.md references a non-existent ADR directory (Hard violation)

**File:** `docs/agents/domain.md` — Consumer Rules §3

`docs/agents/domain.md` instructs agents to "create an ADR in `docs/adr/` following the
format in `.agents/skills/domain-modeling/ADR-FORMAT.md`." No `docs/adr/` directory is
created in this diff or exists in the repo. Meanwhile, `docs/wiki/decisions.md` has been
established as the decisions log for this effort. These two mechanisms are incompatible:
the domain doc points to a directory that does not exist; the wiki uses a flat decisions log
that is not an ADR file per ADR-FORMAT.md. Neither document acknowledges the other.

**Fix:** Either create `docs/adr/` and migrate D-001/D-002 to proper ADR files, or update
`docs/agents/domain.md` to point to `docs/wiki/decisions.md` and explain why ADR-FORMAT.md
is not being used.

---

### S-07 — Glossary terms not aligned with any codebase identifiers (Judgement call)

**File:** `GLOSSARY.md` — "Service Inventory", "Process Inventory"

"Service Inventory" is defined as the list passed to `_SM_StopServicesBatch()`, but the
existing codebase uses `$aServiceNames[]`. "Process Inventory" maps to `$sProcesses[]` and
`$sProcesses2[]`. Neither term appears as an identifier or comment in the existing AutoIt
source (`CLAUDE.md` documents `$sProcesses[]` / `$sProcesses2[]` / `$aServiceNames[]`
directly). Glossary vocabulary and code identifiers are misaligned, which is Mysterious Name
in reverse: the glossary names something that the code does not name the same way.

---

## Spec

### P-01 — Four spec-mandated documents are absent (Missing requirement — Major)

**Spec ref:** §File Map

The spec explicitly mandates creation of:
- `docs/BASELINE-INVENTORY.md` (Task 1 deliverable)
- `docs/REQUIREMENTS.md` (Task 2 deliverable, REQ-ID rows required)
- `docs/ARCHITECTURE.md` (Task 2 deliverable, frozen module contract)
- `docs/IMPLEMENTATION-AND-VERIFICATION.md` (Task 6 deliverable, commands/results/evidence)

None of these files appear in the diff. `docs/wiki/index.md` (a status table),
`docs/wiki/decisions.md` (an informal decision log), and `docs/agents/domain.md` are not
substitutes. The spec is unambiguous that these are named deliverables with specific content
requirements (REQ-ID rows, gate evidence, file hashes, etc.).

---

### P-02 — All added files are scope creep relative to the spec (Scope creep — Informational)

**Spec ref:** §File Map

The spec's File Map does not mention `CODING_STANDARDS.md`, `GLOSSARY.md`, `docs/wiki/`,
or `docs/agents/`. All files in this diff are outside the spec's scope. This is noted as
informational; project scaffolding is reasonable and does not block the work. However, none
of the scaffolding satisfies any spec gate.

---

### P-03 — Wiki status table shows all tasks pending despite prior work existing (Partial — Minor)

**File:** `docs/wiki/index.md` — Status table

All six tickets are marked `pending` with no agent assigned. `docs/agents/issue-tracker.md`
references issues `01`–`06` as already created under `.scratch/service-manager-migration/issues/`.
The git log shows commit `1d8a5ea` ("feat: replace broken service-stop path with native SCM
batch-stop module"), which implies at least some implementation work has occurred. The status
table is inconsistent with the state of the repo and the commit history. If used as a
wayfinding document by agents, it will cause them to repeat already-completed work.

---

### P-04 — D-002 decision lacks a REQ-ID row (Missing requirement — Major)

**File:** `docs/wiki/decisions.md` — D-002

The spec §Evidence Gates requires: "Maintain requirement rows as `REQ-ID | source |
implementation | test or inspection | evidence | status` in `docs/REQUIREMENTS.md`."
D-002 (ServiceManager.au3 supersedes ServiceControl.au3 for stopping) is the most
architecturally significant decision in this diff. It has no corresponding `docs/REQUIREMENTS.md`
entry and no REQ-ID. The decision log captures the rationale but provides none of the
traceability (implementation location, verification method, evidence) the spec demands.

---

### P-05 — Timing constant $MAIN_LOOP_SLEEP_MS conflicts with CLAUDE.md baseline (Wrong implementation)

**File:** `GLOSSARY.md` — "Timing Constants"

The glossary documents `$MAIN_LOOP_SLEEP_MS = 500`. `CLAUDE.md` documents the main loop
as `While 1 / Sleep(50) / WEnd` — a 50 ms sleep. The spec §Preserved behavior requires
"a responsive main loop." A 500 ms main-loop sleep is a 10x increase from the established
baseline (50 ms) and would directly degrade hotkey and tray responsiveness. If 500 ms is
intentional, it requires a REQ-ID row and a spec-level decision. As documented it is an
untracked, unreviewed behavioral change.

**Spec ref:** §Preserved behavior — "do not add a service-specific blocking wait to the
process loop."

---

### P-06 — _SM_PascalCase naming convention not asked for by spec (Scope creep — Minor)

**File:** `CODING_STANDARDS.md` — Function Naming

The spec says to "put native Service Control Manager calls … in one focused include module"
but prescribes no naming convention for it. The `_SM_PascalCase` prefix convention is new
policy invented beyond what the spec asked. This is flagged as minor scope creep; it may be
useful but it was not requested.

---

### P-07 — docs/wiki/decisions.md D-001 not traceable to spec authority (Scope creep — Informational)

**File:** `docs/wiki/decisions.md` — D-001

D-001 explains that a local markdown issue tracker is used instead of GitHub because no
GitHub auth is available. The spec (`SKILL.md` §2) says "if nothing is found, ask the user
where the spec is." It does not authorize the agent to silently create a local markdown
tracker. This decision is reasonable but is self-authorized. The spec's wayfinding mechanism
(`setup-matt-pocock-skills`) was not consulted. Noted as informational.

---

## Summary

**Standards axis:** 7 findings (5 hard violations, 2 judgement calls). Worst issue: **S-03** — GLOSSARY.md contains implementation details (function signatures, array structures, variable names) in direct violation of the GLOSSARY-FORMAT.md rule that the glossary be "totally devoid of implementation details."

**Spec axis:** 7 findings (2 major missing requirements, 1 wrong implementation, 2 minor scope creep, 2 informational). Worst issue: **P-01** — all four spec-mandated documents (`docs/BASELINE-INVENTORY.md`, `docs/REQUIREMENTS.md`, `docs/ARCHITECTURE.md`, `docs/IMPLEMENTATION-AND-VERIFICATION.md`) are absent; no spec gate has been satisfied by any file in this diff.
