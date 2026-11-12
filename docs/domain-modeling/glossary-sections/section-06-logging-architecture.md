# Section 06 — Logging/Audit and Architecture Patterns

**Source proposals:** DM-07-logging-audit.md, DM-08-architecture-patterns.md, DM-10-glossary-audit.md
**Status:** Authoritative — ready for merge into GLOSSARY.md
**Date:** 2026-11-12

---

## Audit Notes

### Cross-source reconciliation performed

All ten terms below were verified against three source proposals and the primary source files
(`Stop Services Processes.au3`, `docs/ARCHITECTURE.md`). Where proposals disagreed or contained
implementation contamination, the primary source governs. Specific reconciliation decisions are
noted per term.

### Terms excluded (per task specification)

- `#include` — an AutoIt preprocessor directive, not an architectural concept (DM-08 §4 confirms)
- `DllCall` — a language construct, not a project concept
- Win32 function names (`OpenSCManagerW`, `ControlService`, etc.) — platform API, not domain vocabulary

---

## Language

### Logging and Audit

**Log Level**

One of three integer values passed to `_LogMessage` as `$iLevel` that determines whether a
message is written: `0` (Error — failure events), `1` (Info — completed-action events), `2`
(Verbose — expected-negative observations such as a service already stopped). A message is
dropped silently if its level exceeds the current ceiling value.

_Avoid_: severity, priority (overloaded with process priority in this codebase), verbosity level

---

**Reconciliation note — Log Level:** DM-07 §2.1 found that level names existed only in prose
documentation and that no named constants were declared in the source. As of the current source,
this is resolved: `$LOG_LEVEL_ERROR = 0`, `$LOG_LEVEL_INFO = 1`, `$LOG_LEVEL_VERBOSE = 2` are
declared as `Global Const` in `Stop Services Processes.au3` lines 54–56. The term definition
above reflects the current code, not the historical gap.

---

**Log Type**

A string tag attached to every log entry that identifies which subsystem produced it. The five
defined values are `"System"` (script lifecycle events), `"Process"` (process kill actions),
`"Service"` (service stop actions), `"ProcessPriority"` (one-shot priority set actions), and
`"PriorityWatchdog"` (watchdog lifecycle and drift events). Rendered bracketed in the on-disk
format: `[Service]`.

_Avoid_: category, channel, logger name

---

**Reconciliation note — Log Type:** DM-07 §2.2 found that the five type strings existed only as
bare literals at every call site. As of the current source, named constants are declared:
`$LOG_TYPE_SYSTEM`, `$LOG_TYPE_PROCESS`, `$LOG_TYPE_SERVICE`, `$LOG_TYPE_PROCESS_PRIORITY`,
`$LOG_TYPE_PRIORITY_WATCHDOG` (lines 60–64). The five string values themselves are unchanged.
The definition above names the values as domain vocabulary; the constant names are implementation
detail and are excluded from the glossary entry.

---

**Log Entry**

A single line appended to the log file by one call to `_LogMessage`. Format:
`{time} {date} [{LogType}] {message}`. Each entry records exactly one event from one subsystem
at one point in time.

_Avoid_: log line, log record, event (too ambiguous in this context)

---

**Reconciliation note — Log Entry format:** DM-07 §2.3 noted that the repo-tracked sample at
`Log File/closure_log.txt` uses an older format (dash separator, no bracketed type). That sample
predates the current `_LogMessage` implementation. The authoritative format is the one produced
by the current code (lines 272–273 of `Stop Services Processes.au3`), which is what the
definition above reflects.

---

**Log File**

The single append-only plaintext file at `@HomeDrive\login\closure_log.txt` that persists all
log entries across script sessions. Created on first run if absent; deleted and recreated (rotated)
when older than the configured maximum age. The only durable record of suppression actions in
this project.

_Avoid_: audit log, operation log, closure log (the filename predates multi-subsystem use and
understates the file's current scope)

---

**Suppression Event**

A log entry produced at Log Level `Info` that records a completed suppression action: a process
that was successfully killed or a service that reached the `STOPPED` state. These are the
semantically significant entries — they assert that the script's core purpose was carried out.
Suppression events are a strict subset of all log entries; error and verbose entries are not
suppression events.

_Avoid_: audit event (no explicit audit concept exists in this codebase), action log entry

---

**Log Rotation**

The act of deleting the log file when its age exceeds the configured maximum (currently 7 days),
which causes a fresh file to be created on the next log write. This project uses delete-on-age,
not the rename-and-compress pattern common in server software.

_Avoid_: log cleanup, log pruning, log archiving

---

**Reconciliation note — Log Rotation:** DM-10 §1 proposed this term. DM-07 §2.4 described the
mechanism. Both are consistent. The implemented function is `_CheckAndRotateLogFile` (lines
184–199 of `Stop Services Processes.au3`). The function name and the `$iLogMaxAgeDays` variable
are excluded from the glossary entry per GLOSSARY-FORMAT.md rules.

---

### Architecture Patterns

**Deep Module**

A module that exposes a small public interface while encapsulating a large and complex
implementation. `ServiceManager.au3` is the canonical example in this codebase: its sole public
entry point accepts three parameters and returns a single result array, while its internals
manage a two-phase batch algorithm, parallel pending state, per-service outcome classification,
and handle lifecycle — none of which are visible to the caller.

_Avoid_: library (implies loosely related utilities with many independent entry points), wrapper
(implies the interface mirrors the underlying thing), adapter (implies a seam with alternatives;
`ServiceManager.au3` owns the seam, it is not one side of it)

---

**Shallow Library**

A collection of independent functions with no shared state across calls, whose interface closely
mirrors the underlying operations it exposes. `ServiceControl.au3` is the canonical example in
this codebase: each function opens its own SCM handle, performs one operation, and closes.

_Avoid_: utility library (acceptable but generic), wrapper (conflates with Shallow Library's
distinct architectural meaning)

---

**Reconciliation note — Shallow Library:** DM-08 §2 uses the term "library (shallow)" as the
canonical term for `ServiceControl.au3`. This section renders it as "Shallow Library" (noun
phrase, adjective first) for parallel construction with "Deep Module". The meaning is identical.
DM-10 does not propose this term; its absence from DM-10 is not a conflict — DM-10 focused on
missing terms found in code and docs, not on architecture-pattern vocabulary.

---

**Module Seam**

The named boundary between the main script's monitoring loop and `ServiceManager.au3`, located
at the `_RunServiceBatchStop()` call in `ToggleScript`. Code on one side of the seam (the
monitoring loop) knows only the public interface; code on the other side (the module) owns the
implementation. The seam is what makes the module independently testable and replaceable without
changing the caller.

_Avoid_: boundary (overloaded), interface (the seam is the location; the interface is what
crosses it), integration point

---

**Reconciliation note — Module Seam vs Seam:** DM-08 §6 proposed the term "Seam". DM-08 §3
describes two seams: the primary seam between `ToggleScript` and `_SM_StopServicesBatch`, and a
secondary seam between `ServiceManager.au3` and `advapi32.dll`. The task specification names
the term "Module Seam" and scopes it to the boundary between `Stop Services Processes.au3` and
`ServiceManager.au3` — the primary architectural seam. The secondary seam (between
`ServiceManager.au3` and the Win32 API) is an implementation detail of the module, not a
project-level architectural term. This definition reflects that scoping decision.

---

**Module Extraction**

The architectural transformation in which a coherent body of behaviour is moved out of a larger
script into its own module with a newly designed public interface. The creation of
`ServiceManager.au3` from `arch/service-manager-migration` is the canonical instance: the
stop-services behaviour was not merely relocated — the batch algorithm, two-phase design,
per-service result rows, and outcome classification were all redesigned as part of the
extraction.

_Avoid_: migration (acceptable as a branch-name shorthand but understates that the interface
was redesigned, not just moved), refactor (too generic), extraction (use the full term to
distinguish from mechanical code moves)

---

**Reconciliation note — Module Extraction:** DM-08 §5 distinguishes two senses of "migration":
the extraction decision (Module Extraction) and the call-site update (call-site migration). Only
Module Extraction belongs in the glossary as a domain term — call-site migration is a
consequence of the extraction, not an independent concept. DM-08 is the sole source for this
term; DM-07 and DM-10 do not address it.

---

## Coverage summary

| # | Term | Primary source | Reconciliation required |
|---|---|---|---|
| 1 | Log Level | DM-07 §2.1; source lines 54–56 | Yes — constants now declared in source |
| 2 | Log Type | DM-07 §2.2; source lines 60–64 | Yes — constants now declared in source |
| 3 | Log Entry | DM-07 §2.3; source lines 272–273 | Yes — old sample log format excluded |
| 4 | Log File | DM-07 §2.4; source line 109 | No — "closure log" avoidance confirmed |
| 5 | Suppression Event | DM-07 §2.3, §3; DM-10 §1 | No — consistent across proposals |
| 6 | Log Rotation | DM-07 §2.4; DM-10 §1; source lines 184–199 | No — consistent across proposals |
| 7 | Deep Module | DM-08 §1 | No — canonical term confirmed |
| 8 | Shallow Library | DM-08 §2 | Yes — term form adjusted for parallel construction |
| 9 | Module Seam | DM-08 §3, §6 | Yes — scoped to primary seam only |
| 10 | Module Extraction | DM-08 §5 | Yes — "call-site migration" excluded as non-term |
