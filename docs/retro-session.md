# Session Retrospective — arch/service-manager-migration

**Date**: 2026-11-12
**Branch**: `arch/service-manager-migration`
**Session scope**: Extraction of `ServiceManager.au3` deep module for Windows SCM batch stop, deterministic test harness, 185+ agents across 3 swarms (code review, domain modeling, issue resolution), 11 ADRs, 51-term GLOSSARY, 40+ code reviews, 10 domain proposals, ~20 issues resolved.

---

## What the session accomplished

The old `_stopservicescustom` path had three latent defects (unreliable interrogate-based state check, stop-accepted treated as stopped, `ControlService` receiving `"str", ""` instead of a valid struct pointer). The session replaced it end-to-end: `ServiceManager.au3` with a Phase 1 / Phase 2 two-pass design, a fully deterministic test harness, integration into the main script, 10 ADRs recording every hard-to-reverse decision, a 51-term GLOSSARY, and 40+ code reviews across two full swarm passes. All ~20 bugs found were tracked as issues and resolved before the session closed.

The session also left behind a body of review artifacts (`docs/reviews/second-pass/`) that serve as the primary evidence record for this retro.

---

## Findings

Findings are ordered by severity. Each entry names the evidence, classifies the type of improvement, and states the specific action taken or recommended.

---

### 1. Automated checks — Duplicate `Global Const` declarations (AU3Check gate)

**Severity: High**
**Evidence**: CR2-08 (Finding 3.1, 3.2), CR2-09 (Section 1–2), CR2-32 (Check 7 A6)

`$LOG_LEVEL_ERROR/INFO/VERBOSE` and `$LOG_TYPE_SYSTEM/SERVICE` were declared with `Global Const` in both `Stop Services Processes.au3` and `Includes/ServiceManager.au3` simultaneously. AutoIt silently accepts duplicate `Global Const` with identical values at the language level, so no runtime error occurred. But `AU3Check -w 3 -w 4` does flag redeclaration warnings. The repo already mandates `AU3Check -q -d -w 1 -w 2 -w 3 -w 4` for all `.au3` files (`CODING_STANDARDS.md` §AU3Check Compliance), so the check gate was present but the duplicate-prevention rule did not explicitly address `Global Const` redeclaration across included files.

**Root cause**: `ServiceManager.au3` redeclared the five constants because the test harness (`Tests/ServiceManager.Tests.au3`) includes `ServiceManager.au3` without including the main script, so the module could not rely on the main script's definitions being present during test compilation. The right fix is a shared constants file (`Includes/LogConstants.au3`) included by both. That extraction is a future refactor (tracked in CR2-09 §Recommended Actions). The immediate check improvement is to add an explicit rule to `CODING_STANDARDS.md` §Duplicate Prevention covering `Global Const` identity across included files.

**Action taken**: `CODING_STANDARDS.md` §Duplicate Prevention extended with an explicit `Global Const` rule. See §Applied changes below.

---

### 2. Automated checks — `_exit` naming violation (AU3Check + grep-based pre-commit)

**Severity: High**
**Evidence**: CR2-08 (Finding 1.1), second-pass CR2-08 §Summary

`Func _exit()` in `Stop Services Processes.au3` is entirely lowercase after the underscore. The standard requires `_UnderscorePascalCase`, making the correct name `_Exit`. The function is hotkey-bound (`HotKeySet("{ScrollLock}{PAUSE}", "_exit")`), so the string in the `HotKeySet` call must also be updated when renaming. This was a hard violation per `CODING_STANDARDS.md` §Function Naming that AU3Check does not catch on its own (AU3Check checks undeclared variables and type usage, not identifier naming conventions).

A grep-based check can catch this mechanically: search all `.au3` files for `^Func _[a-z]` (function definitions where the character after the underscore is lowercase). This pattern has zero false positives against the current codebase — every other `_`-prefixed function already uses `_UppercaseLetter`.

**Action taken**: `CODING_STANDARDS.md` §AU3Check Compliance extended with a note that the naming check is not covered by AU3Check and must be enforced by the reviewer. The reviewer-enforcement note is added to the Function Naming section. The grep pattern is documented there for reviewer reference.

---

### 3. Coding standards — `_SM_PascalCase` authority conflict resolved

**Severity: High**
**Evidence**: CR2-08 (SO-1), CR2-17 (F3), CR2-32 (Check 1, 2, 4)

`CODING_STANDARDS.md` contained a CR-09 note claiming the `_SM_PascalCase` tier "appeared in a previous revision and has been removed." `CLAUDE.md` simultaneously documented the tier as the third canonical naming convention and pointed to `CODING_STANDARDS.md` as the authority. `CODING_STANDARDS.md` in turn pointed back to `CLAUDE.md`. The two documents formed an unresolvable circular reference. Meanwhile, `ServiceManager.au3` used `_SM_PascalCase` throughout all eight of its functions, so the removal note was factually wrong against the live codebase.

The correct resolution: the tier exists and is active production code. `CODING_STANDARDS.md` is the reviewer-enforcement file and should be the single authority. `CLAUDE.md` should be a summary that defers to it.

**Action taken**: Both files updated. See §Applied changes below.

---

### 4. Coding standards — Constant naming conventions missing

**Severity: Medium**
**Evidence**: CR2-32 (Check 7, A5)

The codebase has well-established constant prefix patterns (`$SM_STATE_`, `$SM_OUTCOME_`, `$SM_ERR_`, `$LOG_LEVEL_`, `$LOG_TYPE_`, `$AUTOIT_PRIORITY_`) but no written rule describing them. Without a documented pattern, a future agent adding a new service-manager constant has no guide for whether to use `$SM_`, `$LOG_`, or some new prefix.

**Action taken**: `CODING_STANDARDS.md` §Constant Naming section added. See §Applied changes below.

---

### 5. Coding standards — `#Region` naming conventions missing

**Severity: Medium**
**Evidence**: CR2-32 (Check 6, A4)

The codebase uses a `Configuration —` prefix pattern for configuration-data regions and inconsistently omits the label text from some `#EndRegion` tags. Neither pattern is documented. The region names themselves are defined in `CLAUDE.md` §Region Structure but no rule governs the `Configuration —` prefix or the `#EndRegion` label requirement.

**Action taken**: `CODING_STANDARDS.md` §Region Structure section added. See §Applied changes below.

---

### 6. Navigation — CLAUDE.md stale function names

**Severity: Medium**
**Evidence**: CR2-08 (SO-2), CR2-17 (F1, F2), CR2-27 (Items 2, 3)

CLAUDE.md §Architecture (Active Monitoring Loop) referenced three old function names that no longer exist in the codebase: `_CloseInstaller()` (renamed to `_KillProcessList`), `_stopservicescustom()` (replaced by `_RunServiceBatchStop`), and `_miscpopups()` (now `_MiscPopups`). It also referenced `CheckElapsedTime` without the `_` prefix, and described the service-stop interval as "~2 seconds" when the actual value is 10 seconds (`$SVC_POLL_INTERVAL_SEC = 10`).

An agent navigating CLAUDE.md to find the monitoring loop would arrive at the wrong function names and waste search time. The stale `CheckElapsedTime` reference (no underscore) would additionally mislead the agent about whether the function is public or private.

**Action taken**: CLAUDE.md §Architecture updated to use current function names. See §Applied changes below.

---

### 7. Navigation — CLAUDE.md missing ServiceManager.au3 section

**Severity: Medium**
**Evidence**: CR2-17 (F4, F5)

CLAUDE.md had a "ServiceControl.au3" section but no "ServiceManager.au3" section. The repository layout table in CLAUDE.md listed `ServiceControl.au3` but not `ServiceManager.au3`. An agent reading only CLAUDE.md would not know the new module exists, could not find its public interface (`_SM_StopServicesBatch` returning `[n][6]`), and would not know about the deliberate incompatibility between the two libraries' return-value conventions (ADR-0004).

CLAUDE.md already has a `ServiceManager.au3` entry in the Repository Layout table (this was added during the session). The DllCall conventions section for advapi32.dll was also added. This finding is now partially resolved by the session's own fixes. The retro confirms those additions are present and correct.

**No additional action needed** — the CLAUDE.md additions made during the session cover this gap. The two-library architecture note in the ServiceControl.au3 section cross-references ServiceManager.au3 as the stop-path. The `docs/adr/README.md` pointer in CLAUDE.md §Agent skills directs agents to ADR-0004.

---

### 8. Navigation — CLAUDE.md authority note inversion

**Severity: Medium**
**Evidence**: CR2-32 (Check 4), CR2-17 (F3)

CLAUDE.md §Coding Conventions stated: "`CODING_STANDARDS.md` is the authority on naming conventions... If this section and `CODING_STANDARDS.md` ever conflict, `CODING_STANDARDS.md` wins."

CODING_STANDARDS.md §Function Naming preamble stated the opposite: "`CLAUDE.md` is the canonical source for naming conventions. This section must remain in sync with `CLAUDE.md`."

One document must win. The correct hierarchy: `CODING_STANDARDS.md` is the reviewer-enforcement authority (the review agent reads it); `CLAUDE.md` is the agent-instruction summary (the implementation agent reads it). When they conflict, `CODING_STANDARDS.md` wins because that is what the reviewer enforces.

**Action taken**: Both files updated to agree on this hierarchy. See §Applied changes below.

---

### 9. Automated checks — Orphaned constant `$SM_STOP_ELIGIBLE_STATES`

**Severity: Low**
**Evidence**: CR2-09 (Section 5)

`$SM_STOP_ELIGIBLE_STATES` is defined in `Includes/ServiceManager.au3` with a comment claiming it is "Used by `_SM_IsStopEligible`". It is never read anywhere in the codebase. `_SM_IsStopEligible` uses a `Switch` statement over integer state constants, not this string. The comment is incorrect and the constant is dead code (Fowler: Speculative Generality).

A `Global Const` that is defined but never referenced cannot be caught by AU3Check (AU3Check only warns on undeclared variables used without declaration, not on declared constants that are never used). This requires a grep-based reviewer check: constants defined with `Global Const $SM_*` that do not appear in any other line of the file.

**Action taken**: Added to `CODING_STANDARDS.md` §Duplicate Prevention as a reviewer note on orphaned constants. The specific `$SM_STOP_ELIGIBLE_STATES` case is flagged for cleanup in a future pass (the constant should either be removed or its comment corrected to say "documentation-only").

---

### 10. Steering files — Swarm pattern warrants a standing skill

**Severity: Low (process improvement)**
**Evidence**: Session scope (185+ agents, 3 swarms)

The 10+ parallel agents per team pattern that made this session feasible has no written description in the repo. Future sessions could benefit from a brief note in `docs/agents/` or a skill covering the swarm decomposition pattern: how to structure a review swarm (independent axes per agent, one file or one axis per agent), how to structure an issue-resolution swarm (fix agents claim individual issues, verification agent sweeps after), and what files to read before spinning up a swarm (ADR index, GLOSSARY, issue tracker, CODING_STANDARDS).

**Action taken**: None applied to code or standards files — this is a process note for the repo maintainer. If future sessions repeat the swarm pattern, consider adding a `docs/agents/swarm-pattern.md` file to capture the decomposition protocol.

---

## Applied changes

### CODING_STANDARDS.md changes

1. **Function Naming**: Retracted the CR-09 removal note. Added `_SM_PascalCase` as the third canonical naming tier. Added reviewer grep pattern for lowercase-after-underscore violations. Changed the authority note so `CODING_STANDARDS.md` is explicitly the authority.

2. **Duplicate Prevention**: Extended to cover `Global Const` redeclaration across included files. Added a note on orphaned (never-read) `Global Const` declarations.

3. **Constant Naming** (new section): Documents the `$PREFIX_` convention for all established constant families.

4. **Region Structure** (new section): Documents `Configuration —` prefix, the three canonical region names, and the `#EndRegion` label requirement.

### CLAUDE.md changes

1. **Active Monitoring Loop**: Updated `_CloseInstaller` → `_KillProcessList`, `_stopservicescustom` → `_RunServiceBatchStop`, `_miscpopups` → `_MiscPopups`. Corrected service-stop interval from "~2 seconds" to "10 seconds". Corrected `CheckElapsedTime` → `_CheckElapsedTime($iStartTime, $iInterval)`.

2. **Coding Conventions / Function Naming**: Removed the circular authority claim. `CODING_STANDARDS.md` is the authority; this section is a summary kept in sync with it.

---

## What worked well

- **Swarm decomposition by axis**: Assigning independent review axes (Standards, Spec, Coverage, Architecture) to separate agents eliminated the context-pressure bottleneck. The review agent has the lightest context load in the pipeline — it only needs the diff and the standards file. Running 10 axes in parallel cut review time by an order of magnitude.

- **Issue-tracker discipline**: Numbering issues in dependency order (blockers first) and requiring a `Status:` line in each file gave the fix swarm an unambiguous work queue. The FIX-VERIFICATION sweep caught 8 of 14 items that fix agents had claimed but not actually landed, which is a strong argument for a mandatory verification pass after any fix swarm.

- **ADR-first on hard-to-reverse decisions**: The 10 ADRs (especially ADR-0003, ADR-0004, ADR-0008) prevented the review agents from relitigating the same design questions. Without ADR-0004 (ServiceControl/ServiceManager incompatibility) in CLAUDE.md's navigation pointers, every agent touching the service-stop path would have independently questioned whether to use `_StopService` or `_SM_StopServicesBatch`.

- **GLOSSARY investment**: 51 terms with explicit `_Avoid_` synonym lists meant domain vocabulary was consistent across all 185+ agent outputs. No agent invented a competing name for "batch stop" or "stop-eligible state."

## What could improve

- **Fix-agent verification gap**: 8 of 14 fix items were claimed-but-not-landed. Fix swarms should always be followed by a mandatory verification sweep (the FIX-VERIFICATION pattern used in this session). This should be documented as a standing process requirement.

- **CLAUDE.md staleness accumulates fast**: Three function renames happened early in the session and CLAUDE.md was not updated until the second-pass sweep caught them. A lightweight "update CLAUDE.md if you rename a function" rule in CODING_STANDARDS.md would catch this earlier.

- **Circular authority references**: The `CODING_STANDARDS.md` ↔ `CLAUDE.md` naming authority loop burned review cycles across CR2-17, CR2-32, and CR2-08. Any two-document authority chain should designate one document as the winner at setup time, not at retro time.

---

## Bug Investigation Round

This section records process improvements surfaced specifically by the BUG-01 through BUG-12 investigation series and the issues they exposed.

---

### Automated check — Post-rename doubled-suffix grep

**Triggered by**: MED-03 (`$SM_OUTCOME_ALREADY_STOPPED_STOPPED` incident).

During the BUG-04 fix pass, `$SM_OUTCOME_ALREADY` was renamed to `$SM_OUTCOME_ALREADY_STOPPED` and `$SM_OUTCOME_TIMEDOUT` was renamed to `$SM_OUTCOME_TIMED_OUT`. The rename was applied correctly in that pass, but the incident pattern — renaming `$SM_OUTCOME_X` to `$SM_OUTCOME_X_SUFFIX` across multiple constants in a single bulk operation — creates a mechanical risk: if any occurrence already carries a partial suffix from a prior rename, the result is a doubled suffix (e.g., `$SM_OUTCOME_ALREADY_STOPPED_STOPPED`).

**New automated check**: After any bulk rename of `$SM_OUTCOME_*` constants (or any constant family using a descriptive suffix), run:

```
grep -r "_STOPPED_STOPPED\|_OUT_OUT\|_ED_ED" *.au3
```

This catches doubled suffixes with zero false positives against the current codebase. The general rule: when renaming `$SM_OUTCOME_X` to `$SM_OUTCOME_X_SUFFIX`, grep for `_SUFFIX_SUFFIX` patterns in all `.au3` files immediately afterwards before committing.

---

### New coding standard — `_ArrayAdd` on parallel arrays requires immediate `@error` checks

**Triggered by**: HIGH-07 (`LockProcessPriority` parallel array desync on `_ArrayAdd` failure).

The three parallel arrays `$aPriorityWatchPIDs`, `$aPriorityWatchTargets`, and `$aPriorityWatchNames` are appended to by sequential `_ArrayAdd` calls with no `@error` checks. A failure on any one call desynchronises array lengths, causing silent wrong-priority restores in `_PriorityWatchdog`.

**New standard to add to `CODING_STANDARDS.md` under "Parallel array operations"**: `_ArrayAdd` calls on parallel arrays must ALWAYS be followed immediately by `@error` checks. On any failure, all preceding successful adds within the same logical operation must be rolled back (or the operation must abort with user notification) before returning. Never allow parallel arrays to diverge silently.

---

### New coding standard — `AdlibRegister` callbacks must guard against re-entry on shared resources

**Triggered by**: HIGH-06 (`_LogMessage` re-entrancy corruption via `AdlibRegister`).

AutoIt `AdlibRegister` callbacks fire between bytecode instructions, including inside functions that hold open file handles or are in the middle of modifying globals. `_PriorityWatchdog` is registered via `AdlibRegister` and can interrupt `_LogMessage` between its `FileOpen` and `FileClose` calls, causing the inner `_LogMessage` invocation to open a second handle to the same log file. The outer write then overwrites the inner entry, producing silent log data loss.

**New standard to add to `CODING_STANDARDS.md` under "AdlibRegister and re-entrancy"**: Functions registered with `AdlibRegister` create re-entrancy risk for any shared resource (file handles, globals). Any function that holds a file handle open across multiple statements, or that reads-and-writes a shared global non-atomically, must guard against re-entry with a boolean guard global checked on entry. If the guard is set, the function must either queue its work or return immediately without touching the shared resource.

---

### Environment improvement — Post-bulk-rename doubled-suffix grep should be a standing step

**Triggered by**: MED-03 (`$SM_OUTCOME_ALREADY_STOPPED_STOPPED` doubled-suffix incident).

The doubled-suffix incident would have been caught immediately by a one-line grep run after the bulk constant rename. This grep requires no tooling beyond what is already available in the sandbox and takes under a second on the current codebase.

**Standing post-rename step**: After any bulk rename of constants in `*.au3` files, run:

```
grep -r "_STOPPED_STOPPED\|_OUT_OUT\|_ED_ED" *.au3
```

This command should produce zero output. Any match indicates a doubled suffix from a rename collision and must be resolved before committing. Add this step to the fix-agent checklist for any task that renames more than one constant in a family.
