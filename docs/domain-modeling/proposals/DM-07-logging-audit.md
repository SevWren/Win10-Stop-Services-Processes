# DM-07 — Logging and Audit Trail Domain Modeling Proposals

**Focus area:** Log levels, log file structure, what constitutes an "audit event" in this tool.
**Date:** 2026-11-12
**Status:** Proposed — not yet merged into GLOSSARY.md

---

## 1. What Was Analyzed

Sources examined:

- `Stop Services Processes.au3` — `_LogMessage`, log file initialization block, log-rotation function, all call sites
- `Includes/ServiceManager.au3` — all `_LogMessage` call sites within `_SM_StopServicesBatch` and `_SM_GetServiceState`
- `Log File/closure_log.txt` — repo-tracked sample of the actual on-disk log
- `CLAUDE.md` — the canonical description of `_LogMessage` signature and level semantics

---

## 2. Findings

### 2.1 Log Levels Exist and Are Defined — but Only in CLAUDE.md, Not in the Code

The `$iLevel` parameter of `_LogMessage` takes three integer values. CLAUDE.md documents them:

| Value | Name    |
|-------|---------|
| 0     | Error   |
| 1     | Info    |
| 2     | Verbose |

The global `$iLogLevel = 2` sets the ceiling. Any call where `$iLevel > $iLogLevel` is silently dropped.

The names "Error", "Info", "Verbose" do not appear as named constants anywhere in the source. They exist only as inline integer literals (`0`, `1`, `2`) at every call site. There is no `$LOG_ERROR`, `$LOG_INFO`, or `$LOG_VERBOSE` constant. The mapping lives only in prose documentation.

**Consequence for the domain model:** "log level" is a real concept in this codebase, with real semantics, but it is currently undeclared as domain vocabulary. Its three values need canonical names.

### 2.2 Log Type Strings: Named in Prose, Unnamed in Code

The `$sType` parameter accepts string values. CLAUDE.md lists them:

- `"System"` — script lifecycle events (start, stop, toggle)
- `"Process"` — process kill actions
- `"Service"` — service stop actions (used by both main script and ServiceManager.au3)
- `"ProcessPriority"` — one-shot priority set actions
- `"PriorityWatchdog"` — watchdog lifecycle and drift events

These five strings appear as bare literals at every call site. There are no constants for them. Each is a distinct category of event, and they map closely to the subsystems of the script.

### 2.3 "Log Entry" vs "Audit Event": The Distinction Is Implicit but Real

Every call to `_LogMessage` appends one line to the log file. The format produced is:

```
{time} {date} [{Type}] {message}
```

Example from `Log File/closure_log.txt` (pre-refactor format):

```
12:34:29 PM 05/08/2024 - Service 'wuauserv' was closed.
```

Example from the current `_LogMessage` implementation:

```
12:34:29 PM 05/08/2024 [Service] Service stopped: wuauserv
```

Both formats record a timestamped record of a named action against a named target. This is what most systems would call an **audit event** — a durable record that a specific action occurred at a specific time.

However, not all log entries are equal from an audit standpoint:

- `iLevel=0` (Error) entries record failures — things that **should have** happened but did not. These are diagnostic.
- `iLevel=1` (Info) entries record completed actions (service stopped, process closed, script toggled). These are the audit-worthy events: they assert that an action succeeded and was observed.
- `iLevel=2` (Verbose) entries record expected-negative observations (service already stopped, service not found on this machine). These are noise for auditing purposes — routine non-events.

The codebase does not use the word "audit" anywhere. It uses "log" for everything. There is no structural distinction between a diagnostic trace entry and a record of a completed suppression action.

### 2.4 Log File Structure: Defined in Code, Unnamed in Domain

The log file is a single append-only plaintext file at a fixed path (`@HomeDrive\login\closure_log.txt`). It is:

- Initialized at script startup if absent
- Rotated (deleted) when older than 7 days (`$iLogMaxAgeDays`)
- Mirrored to the SciTE console when `$bLogToConsole = True`

The repo-tracked sample at `Log File/closure_log.txt` uses an older format (dash separator, no bracketed type). The current code produces bracketed-type format. This discrepancy in the sample log is worth noting — the sample predates the current `_LogMessage` implementation.

The file path string `"closure_log.txt"` is the only name in the codebase for this file. The term "log file" appears in comments and CLAUDE.md but is not defined as a domain term.

### 2.5 No Distinction Between Debug Log, Operation Log, Audit Log

The codebase uses a single log file for all three concerns:

- **Diagnostic / debug output**: `ConsoleWrite("DEBUG: ...")` calls during initialization, plus `$bLogToConsole` mirroring — these never reach the file in the DEBUG case; they are console-only.
- **Operational log**: the persistent on-disk file, capturing all events at or below `$iLogLevel`.
- **Audit log**: there is no separate audit log. The operational log is the only persistent record of suppression actions.

The term "closure log" (from the filename `closure_log.txt`) is the closest thing to a domain name for the file. It reflects the original purpose: recording process and service closures. It predates the current log format and the broader use of the log for system lifecycle, priority watchdog, and error events.

---

## 3. Proposed Glossary Terms

These are proposed additions to `GLOSSARY.md`. Each term passes the GLOSSARY-FORMAT.md test: it is specific to this project's context, not a general programming concept.

---

### Log Level

One of three integer values controlling whether a log message is written. `0` = Error (failure events); `1` = Info (completed-action events); `2` = Verbose (expected-negative observations, e.g. service already stopped). Messages with a level above `$iLogLevel` are silently dropped.

_Avoid_: severity, priority (overloaded with process priority in this codebase), verbosity level

---

### Log Type

A string tag attached to every log entry that identifies which subsystem produced it. The five defined values are `"System"`, `"Process"`, `"Service"`, `"ProcessPriority"`, and `"PriorityWatchdog"`. Appears bracketed in the on-disk format: `[Service]`.

_Avoid_: category, channel, logger name

---

### Log Entry

A single line appended to the log file by one call to `_LogMessage`. Format: `{time} {date} [{LogType}] {message}`. Each entry records exactly one event from one subsystem at one point in time.

_Avoid_: log line, log record, event (too ambiguous in this context)

---

### Log File

The single append-only plaintext file at `@HomeDrive\login\closure_log.txt` that persists all log entries across sessions. Initialized on first run, rotated (deleted) when older than 7 days. The only durable record of suppression actions.

_Avoid_: audit log, operation log, closure log (the filename predates multi-subsystem use)

---

### Suppression Event

A log entry with `Log Level = Info` that records a completed suppression action: a process kill or a service stop that reached the `STOPPED` state. These are the semantically significant entries — they assert that the script's core purpose was carried out. Suppression events are a subset of all log entries; diagnostic and verbose entries are not suppression events.

_Avoid_: audit event (no explicit audit concept exists in this codebase), action log entry

---

## 4. Issues and Ambiguities to Resolve

### 4.1 Log level values are magic integers at every call site

There are no named constants for `0`, `1`, `2`. Every call site in both the main script and `ServiceManager.au3` hardcodes the integer. If the level scheme ever changed, all call sites would need manual updating with no compiler assistance.

**Question for the owner:** Should `$LOG_ERROR = 0`, `$LOG_INFO = 1`, `$LOG_VERBOSE = 2` be declared as named constants? This is an implementation decision, not a glossary question — but it affects whether "Error", "Info", and "Verbose" become canonical code-level names or remain prose-only.

### 4.2 Log type strings are bare literals, not constants

The five type strings (`"System"`, `"Process"`, `"Service"`, `"ProcessPriority"`, `"PriorityWatchdog"`) have no corresponding `Global Const` declarations. A typo at a call site would silently produce an unrecognized type tag in the log. This is an implementation gap, not a naming gap — the names themselves are clear.

### 4.3 "Closure log" vs "log file" naming tension

The filename `closure_log.txt` implies "records closures" — a name that fit the original single-purpose script. The current log records closures, service stops, priority changes, watchdog events, and system lifecycle. If a future reader encounters the filename, they will underestimate the scope of what the file contains.

**Proposal:** The domain term should be "Log File" (generic, accurate). "Closure log" should be treated as a legacy artifact name, not a domain term. This is a naming clarification only — no file rename is proposed.

### 4.4 Sample log format divergence

`Log File/closure_log.txt` uses the format `{time} {date} - {Type} '{name}' was closed.` (pre-refactor). The current `_LogMessage` produces `{CRLF}{time} {date} [{Type}] {message}`. The repo-tracked sample is stale. It should not be treated as the canonical format.

### 4.5 No formal "audit event" concept exists

The codebase does not distinguish audit-worthy events from diagnostic noise. All entries share the same log file and format. The proposed "Suppression Event" term above provides a domain-level name for the meaningful subset, but whether the project needs a formal audit trail (versus a simple operational log) is an open question.

**Question for the owner:** Is the log's purpose (a) a debug/diagnostic aid for the developer, (b) a record of what the script actually did for verification purposes, or (c) both? The answer determines whether "Suppression Event" as a distinct concept belongs in the glossary or is unnecessary.

---

## 5. ADR Candidate Assessment

Under the three-gate test (hard to reverse, surprising without context, result of a real trade-off):

- **Single log file for all subsystems** — Not surprising; it is the obvious choice for a single-user script. No ADR needed.
- **Integer literals for log level instead of named constants** — Reversible with a find-replace; not surprising. No ADR needed.
- **Rotation by age (delete) rather than by size or rotation/rename** — Marginally surprising (most tools rotate, not delete), but trivially reversible. No ADR needed.
- **Console mirror controlled by `$bLogToConsole`** — Not surprising; a standard development toggle. No ADR needed.

No ADRs are proposed from this analysis.
