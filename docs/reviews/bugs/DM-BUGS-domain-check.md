# DM-BUGS — Domain Modeling Check: Bug Investigation Concepts

**Date**: 2026-11-12
**Scope**: BUG-08, BUG-09, BUG-10
**Verdict**: No new glossary entries warranted.

---

## Concepts Evaluated

### 1. Re-entrancy guard (`$g_bLogBusy`)

**Source**: BUG-09-B — the recommended fix for `_LogMessage` being interrupted by an `AdlibRegister` callback.

**Verdict: Does not qualify.**

A re-entrancy guard (a boolean flag that blocks a second entry into a function while the first is still executing) is standard software engineering vocabulary. It appears in any language and any context where cooperative or interrupt-driven concurrency exists. The specific variable name `$g_bLogBusy` is an implementation detail, not a domain concept. The guard pattern itself is not unique to this project.

---

### 2. Atomic append

**Source**: BUG-08 — the description of the correct insertion pattern for the three parallel watchlist arrays (`$aPriorityWatchPIDs`, `$aPriorityWatchTargets`, `$aPriorityWatchNames`), where all three must be appended to together or rolled back together.

**Verdict: Does not qualify.**

"Atomic" and "atomic operation" are general SE terms. The pattern of needing to append to multiple data structures in an all-or-nothing fashion is a standard transactional concept, not a concept invented by or specific to this project. The underlying cause — that AutoIt has no struct arrays, forcing the use of parallel globals — is an implementation constraint worth noting in a code comment, not a domain term. The existing glossary term **Watchlist** already covers the data structure itself.

---

### 3. Hotkey debounce

**Source**: BUG-10, Issue 1 — the absence of a mechanism to prevent rapid double-activation of `ToggleScript` via `Shift+F1`.

**Verdict: Does not qualify.**

Debouncing is a well-established general term from both electronics and software UI development. It describes preventing repeated triggering of an action within a short time window. It is not unique to this project's domain and belongs to general SE/UX vocabulary.

---

### 4. Sleep overshoot

**Source**: BUG-06 (referenced in task briefing as a Phase 2 timeout arithmetic finding) — the condition where a `Sleep()` call returns later than requested, causing elapsed time to exceed the intended deadline.

**Verdict: Does not qualify.**

Sleep overshoot (a timer or sleep call returning later than its nominal duration) is a well-known property of cooperative schedulers and OS timer resolution. It is discussed in general systems programming literature under terms like "timer jitter" and "sleep imprecision." It is not a concept coined by or unique to this project.

---

## Existing Coverage

All concepts encountered in BUG-08, BUG-09, and BUG-10 operate within domain vocabulary that is already adequately covered in `GLOSSARY.md`:

| Concept from bug reports | Covered by existing term |
|---|---|
| The three parallel watchlist arrays | **Watchlist** |
| Watchdog firing on a timer | **Priority Watchdog** |
| Watchdog detecting and correcting priority | **Priority Drift** |
| File written on each log event | **Log Entry**, **Log File** |
| File deleted and recreated on age threshold | **Log Rotation** |
| Script switching between idle and active | **Toggle**, **Monitoring Loop** |
| Hotkey callbacks sharing cooperative scheduling | Covered in ADR-0010; not a domain term |

---

## GLOSSARY.md Changes

None. No entries added, removed, or modified.
