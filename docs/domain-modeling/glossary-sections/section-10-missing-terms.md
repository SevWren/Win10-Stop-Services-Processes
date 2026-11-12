# Section 10 — Missing Terms (Glossary Audit)

**Source proposals:** DM-10 (10 identified), DM-01 through DM-09 (additional sweep)
**Date:** 2026-11-12
**Status:** Ready for integration into GLOSSARY.md — do not apply until proposals are accepted

This file lists every domain term confirmed absent from `GLOSSARY.md` as of this audit.
Each entry is written in GLOSSARY-FORMAT.md format: a one- or two-sentence definition of
what the concept IS (not how it is implemented), an optional _Avoid_ list, and _See also_
cross-references where relevant.

Terms are ordered: the 10 mandated by DM-10 first, then additional terms discovered by
sweeping DM-01 through DM-09 and re-reading the source files directly.

---

## Part 1 — The 10 Terms Identified in DM-10

---

**Monitoring Loop**:
The active operating state the script enters when toggled on, during which it repeatedly
applies the process kill cycle and the service stop cycle on their respective intervals until
toggled off.
_Avoid_: active loop, running state, script running
_See also_: Toggle, Timing Constants, Process Inventory, Service Inventory

---

**Toggle**:
The user action (Shift+F1) that transitions the script between its idle state and its
Monitoring Loop state; a second press of the same hotkey stops the loop.
_Avoid_: start, enable, activate, pause
_See also_: Monitoring Loop

---

**Outcome Code**:
One of five string values that classifies the result of a single service-stop attempt within
a Batch Stop: `STOPPED`, `ALREADY_STOPPED`, `UNAVAILABLE`, `FAILED`, `TIMED_OUT`. Stored in
column 3 of a Result Row.
_Avoid_: result code, status code, outcome string
_See also_: Result Row, Batch Stop, Stop-Eligible State

---

**Pending List**:
The set of services within a single Batch Stop that have had a stop control issued — or were
already in `STOP_PENDING` at first query — and are waiting for their Service State to reach
`STOPPED` before the shared batch deadline expires.
_Avoid_: pending services, in-progress list
_See also_: Batch Stop, Service State, Timing Constants

---

**Watchlist**:
The set of PIDs that the Priority Watchdog is currently monitoring for Priority Drift. A PID
is added to the watchlist via the Lock Priority hotkey and removed when the process exits or
when the watchlist becomes empty and the watchdog unregisters itself.
_Avoid_: watchdog list, PID list, monitored processes
_See also_: Priority Watchdog, Priority Drift, PID

---

**Priority Drift**:
The condition where a watched PID's current Windows priority class no longer matches the
target priority class recorded when the PID was added to the Watchlist. When drift is
detected, the Priority Watchdog restores the target priority.
_Avoid_: priority change, priority mismatch
_See also_: Priority Watchdog, Watchlist, Priority Class

---

**Log Level**:
A numeric threshold passed to `_LogMessage` that controls whether a message is written:
`0` = Error (failure events), `1` = Info (completed-action events), `2` = Verbose
(expected-negative observations such as a service already being stopped). A message is
written only when its level is less than or equal to the current `$iLogLevel` ceiling.
_Avoid_: verbosity, log severity, priority (overloaded with process priority in this codebase)
_See also_: Log Type, Log Entry, Log File

---

**Log Rotation**:
The act of deleting the log file when it is found to be older than the configured maximum age
(`$iLogMaxAgeDays`), causing a fresh file to be created on the next log write. This codebase
rotates by deletion, not by renaming or compressing.
_Avoid_: log cleanup, log pruning, log archiving
_See also_: Log File

---

**Tray Notification**:
A small tooltip displayed at the bottom-right corner of the desktop to report Priority
Watchdog events (drift detected, PID exited, priority restored) to the user. Implemented via
`ToolTip()`, not `TrayTip()`, specifically to avoid producing a Windows 10/11 toast
notification in the Action Center.
_Avoid_: tray tip, tray alert, toast notification (which this deliberately is not)
_See also_: Priority Watchdog

---

**Misc Popup**:
An application registration dialog from a third-party program — specifically AdvancedRenamer
(`TPleaseRegisterForm` window class) or Sublime Text ("This is an unregistered copy" title)
— that the script closes automatically during the Monitoring Loop via `WinClose`.
_Avoid_: popup, dialog, registration dialog, window
_See also_: Monitoring Loop

---

## Part 2 — Additional Missing Terms (DM-01 through DM-09 Sweep)

The following terms appear consistently in the proposals, source code, and architecture
documentation but have no entry in GLOSSARY.md. Each has been verified against the domain
concept test: it is specific to this project's context, not a general programming concept.

---

**Process**:
A running Windows executable instance, identified by a PID and managed via kernel32.dll and
AutoIt's `ProcessXxx` functions. Distinct from a Service: a process has no SCM entry and
cannot be started or stopped via the Service Control Manager.
_Avoid_: task, program, executable (use "process" unless referring to the `.exe` file on disk)
_See also_: PID, Service, Process Inventory

---

**Service**:
A Windows OS component registered with the Service Control Manager, manageable via
advapi32.dll. A service may or may not be backed by a running process at any given moment;
stopping a service via the SCM is a different operation from killing its host process.
_Avoid_: daemon, background process (which implies a process, not a service)
_See also_: Service Control Manager (SCM), Process, Service Inventory

---

**PID (Process ID)**:
The numeric identifier Windows assigns to a running process. Valid only for the lifetime of
the process; once the process exits the PID may be reassigned by the OS to a new process.
Any code holding a PID must re-validate it with `ProcessExists` before using it.
_Avoid_: process handle (a handle is a different Windows object returned by `OpenProcess`)
_See also_: Process, Watchlist, Priority Watchdog

---

**Process Kill**:
The act of force-terminating every running instance of a process name in the Process
Inventory via AutoIt's `ProcessClose`, which maps to Windows `TerminateProcess`. The process
receives no opportunity to run cleanup code. Runs on every process kill cycle while the
Monitoring Loop is active.
_Avoid_: process stop, process close, terminate process (all used inconsistently in older
comments; "process kill" is the canonical term for this unconditional operation)
_See also_: Process Inventory, Monitoring Loop, Timing Constants

---

**Stop-Eligible State**:
Any Service State from which the SCM will accept a stop control without returning an error:
`RUNNING`, `PAUSED`, `PAUSE_PENDING`, and `CONTINUE_PENDING`. Services in `STOPPED`,
`STOP_PENDING`, or `START_PENDING` are not stop-eligible and are routed to `ALREADY_STOPPED`,
the Pending List, or `FAILED` respectively without a stop control being issued.
_Avoid_: stoppable, controllable, can-stop
_See also_: Service State, Stop Control, Outcome Code, Batch Stop

---

**Stop Control**:
The act of requesting that a service stop by sending `SERVICE_CONTROL_STOP` via the SCM.
Issuing a stop control does not immediately stop the service; it transitions the service
toward `STOP_PENDING` while the service handles shutdown internally. The stop control is
distinct from the service reaching the `STOPPED` state.
_Avoid_: stopping a service (too broad — conflates the control dispatch with the final state)
_See also_: Batch Stop, Pending List, Service State, Stop-Eligible State

---

**SCM Handle**:
An opaque value representing an open connection to the Service Control Manager, distinct
from a Service Handle. One SCM Handle is opened at the start of each Batch Stop cycle,
covers all per-service operations within that cycle, and is closed after all Service Handles
for that cycle have been released.
_Avoid_: SCM connection, manager handle
_See also_: Service Handle, Batch Stop, Service Control Manager (SCM)

---

**Service Name**:
The short internal identifier for a Windows service as registered in the SCM database —
the string passed to the SCM when opening or querying a service (e.g., `wuauserv`,
`TrustedInstaller`, `FDResPub`). Distinct from the Display Name shown in `services.msc`.
_Avoid_: service key, service identifier, service string
_See also_: Display Name, Service Inventory, SCM Handle

---

**Display Name**:
The human-readable label for a Windows service shown in `services.msc` (e.g., "Windows
Update" for `wuauserv`). Distinct from the Service Name. No operation in this codebase
uses or returns Display Names — all SCM operations use Service Names exclusively.
_Avoid_: friendly name, service label
_See also_: Service Name

---

**Stop Outcome**:
The per-service result classification produced by a Batch Stop cycle. Identical in meaning
to Outcome Code; "Stop Outcome" is the concept name, "Outcome Code" is the value. One of
five values: `STOPPED`, `ALREADY_STOPPED`, `UNAVAILABLE`, `FAILED`, `TIMED_OUT`.
_Avoid_: result code, stop result, status (overloaded with Service State)
_See also_: Outcome Code, Result Row, Batch Stop

---

**Stable Service State**:
A Service State in which a service remains until an operation explicitly moves it: `RUNNING`,
`STOPPED`, or `PAUSED`. Contrast with Transient Service State.
_Avoid_: steady state, final state, resting state
_See also_: Transient Service State, Service State

---

**Transient Service State**:
A Service State the SCM passes through during an in-progress operation: `START_PENDING`,
`STOP_PENDING`, `PAUSE_PENDING`, or `CONTINUE_PENDING`. A service in a transient state may
or may not accept a stop control depending on which transition is in progress.
_Avoid_: pending state, intermediate state, in-progress state
_See also_: Stable Service State, Service State, Stop-Eligible State

---

**AutoIt Priority Constant**:
The integer (0–5) that AutoIt's `ProcessSetPriority` accepts and that the Priority Watchdog
stores internally: 0 = Idle, 1 = Below Normal, 2 = Normal, 3 = Above Normal, 4 = High,
5 = Real-time. These are AutoIt-specific integers and do not match the Windows API hex
values returned by `GetPriorityClass`. Conversion between the two schemes is mandatory.
_Avoid_: priority class (when the AutoIt integer layer is meant — Priority Class refers to
the Windows API hex values)
_See also_: Priority Class, Priority Watchdog, Watchlist

---

**Service Target List**:
The fixed set of Windows service names that the script attempts to stop on each service stop
cycle while the Monitoring Loop is active. Currently nine names declared as a global array.
_Avoid_: service inventory (use that term for the concept; "Service Target List" is the
canonical name for the declared data structure), service array
_See also_: Service Inventory, Monitoring Loop, Batch Stop, Timing Constants

---

**Process Target List**:
The fixed set of process executable names that the script attempts to kill on each process
kill cycle while the Monitoring Loop is active. Currently 18 entries declared as a global
array.
_Avoid_: process inventory (use that term for the concept; "Process Target List" is the
canonical name for the declared data structure), process array
_See also_: Process Inventory, Monitoring Loop, Process Kill, Timing Constants

---

**Log Type**:
A string tag attached to every log entry that identifies which subsystem produced it. The
five defined values are `"System"` (script lifecycle), `"Process"` (process kill actions),
`"Service"` (service stop actions), `"ProcessPriority"` (one-shot priority set actions), and
`"PriorityWatchdog"` (watchdog lifecycle and drift events). Appears bracketed in the on-disk
log format: `[Service]`.
_Avoid_: category, channel, logger name
_See also_: Log Level, Log Entry

---

**Log Entry**:
A single line appended to the log file by one call to `_LogMessage`. Format:
`{time} {date} [{LogType}] {message}`. Each entry records exactly one event from one
subsystem at one point in time.
_Avoid_: log line, log record, event (too ambiguous in this context)
_See also_: Log Type, Log Level, Log File

---

**Log File**:
The single append-only plaintext file at `@HomeDrive\login\closure_log.txt` that persists
all log entries across script sessions. Initialized on first run, subject to Log Rotation
when older than `$iLogMaxAgeDays` days. The only durable record of suppression actions in
this tool.
_Avoid_: audit log, closure log (the filename predates multi-subsystem use and understates
the file's current scope)
_See also_: Log Entry, Log Rotation, Log Level

---

**Suppression Event**:
A log entry at Log Level Info (`1`) that records a completed suppression action — a process
kill that succeeded or a service stop that reached the `STOPPED` state. These are the
semantically significant entries: they assert that the script's core purpose was carried out.
Diagnostic entries (Log Level Error) and expected-negative observations (Log Level Verbose)
are not suppression events.
_Avoid_: audit event (no formal audit concept exists in this codebase), action log entry
_See also_: Log Level, Log Entry, Process Kill, Outcome Code

---

## Summary Table

| Term | Source | Part |
|---|---|---|
| Monitoring Loop | DM-10, DM-06 | 1 |
| Toggle | DM-10 | 1 |
| Outcome Code | DM-10 | 1 |
| Pending List | DM-10, DM-01 | 1 |
| Watchlist | DM-10, DM-02 | 1 |
| Priority Drift | DM-10, DM-02 | 1 |
| Log Level | DM-10, DM-07 | 1 |
| Log Rotation | DM-10 | 1 |
| Tray Notification | DM-10 | 1 |
| Misc Popup | DM-10 | 1 |
| Process | DM-02 | 2 |
| Service | DM-02 | 2 |
| PID | DM-02 | 2 |
| Process Kill | DM-02, DM-03 | 2 |
| Stop-Eligible State | DM-01, DM-09 | 2 |
| Stop Control | DM-01, DM-03 | 2 |
| SCM Handle | DM-01, DM-04, DM-09 | 2 |
| Service Name | DM-01, DM-04 | 2 |
| Display Name | DM-01, DM-04 | 2 |
| Stop Outcome | DM-01, DM-03 | 2 |
| Stable Service State | DM-01 | 2 |
| Transient Service State | DM-01 | 2 |
| AutoIt Priority Constant | DM-02 | 2 |
| Service Target List | DM-06 | 2 |
| Process Target List | DM-06 | 2 |
| Log Type | DM-07 | 2 |
| Log Entry | DM-07 | 2 |
| Log File | DM-07 | 2 |
| Suppression Event | DM-07 | 2 |

**Total: 29 missing terms** (10 from DM-10 + 19 additional from DM-01–DM-09 sweep)

---

## Terms Considered and Excluded

The following candidates were evaluated and rejected as not meeting the domain-concept test
(GLOSSARY-FORMAT.md: "Only include terms specific to this project's context. General
programming concepts don't belong even if the project uses them extensively."):

- **Deep Module, Seam, Module Extraction** (DM-08) — general software architecture patterns,
  not invented by or specific to this project.
- **Test Harness, Test Case, Test Function, Stub, Deterministic Test** (DM-05) — general
  testing vocabulary; the specific implementations are project details, not domain concepts
  the project coined.
- **Configuration** (DM-06) — general programming concept; this project uses constants but
  did not invent the concept of configuration.
- **Target** (DM-06) — too generic; adequately covered by Service Target List and Process
  Target List.
- **Kill (process)** as a standalone entry — adequately covered by Process Kill.
- **Stop (service)** as a standalone entry — adequately covered by Stop Control and Batch Stop.
- **Control Code** (DM-01) — the specific Windows platform concept; this project uses only
  one value (`SERVICE_CONTROL_STOP`) and that is captured in Stop Control. The general
  concept of a control code is a Windows API term, not project-specific vocabulary.
- **Graceful stop** (DM-03) — general systems programming concept, not specific to this
  project.
