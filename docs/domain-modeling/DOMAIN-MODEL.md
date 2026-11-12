# Domain Model

## Overview

Win10-Stop-Services-Processes is an AutoIt v3 script that runs as a persistent background process on Windows 10/11. Its purpose is to suppress Windows Update and related telemetry activity by periodically killing a fixed list of processes and stopping their backing Windows services via the Service Control Manager. Secondary features include process priority management and an autonomous priority watchdog.

## Domain Areas

The domain is divided into five areas, each with its own section in `GLOSSARY.md`:

| Area | What it covers |
|---|---|
| **Service Lifecycle** | Windows services, SCM handles, service states, stop eligibility, batch-stop operations, and per-service outcomes |
| **Process Management** | OS processes, PIDs, process kill operations, priority classes, and the priority watchdog |
| **Script Behaviour** | The monitoring loop, the toggle mechanism, timing constants, tray notifications, and misc popup handling |
| **Logging** | Log levels, log types, log entries, log rotation, and suppression events |
| **Testing** | The test harness, test case/function/suite vocabulary, stubs, and deterministic vs. integration tests |

An **Architecture** section in `GLOSSARY.md` also names the cross-cutting structural patterns: deep module, seam, and module extraction.

## Key Concepts

The 13 most important terms. One-line descriptions only — see [GLOSSARY.md](../../GLOSSARY.md) for full definitions.

| Term | One-line description |
|---|---|
| **Service Control Manager (SCM)** | The Windows authority for starting, stopping, and querying all registered services |
| **Service** | A Windows OS component managed by the SCM — distinct from the process that may host it |
| **Process** | A running executable instance managed via kernel32; has no SCM entry |
| **Service State** | One of seven named lifecycle positions (`STOPPED`, `RUNNING`, `STOP_PENDING`, etc.) reported by the SCM |
| **Stop-Eligible State** | The four states from which a stop control is accepted (`RUNNING`, `PAUSED`, `PAUSE_PENDING`, `CONTINUE_PENDING`) |
| **Batch Stop** | A single operation that issues stop controls to a group of services without serial waiting and measures each against one shared deadline |
| **Stop Outcome** | One of five result codes per service after a Batch Stop: `STOPPED`, `ALREADY_STOPPED`, `UNAVAILABLE`, `FAILED`, `TIMED_OUT` |
| **Result Row** | A six-element record (name, initial state, final state, outcome, Win32 error, note) returned per service from a Batch Stop |
| **Priority Watchdog** | An autonomous periodic mechanism that detects and corrects Priority Drift for every PID in the Watchlist |
| **Priority Drift** | The condition where a watched PID's current priority no longer matches its locked target |
| **Monitoring Loop** | The active state the script enters when toggled on, driving all process-kill and service-stop cycles |
| **Service Inventory** | The fixed set of Windows service names the script attempts to stop each cycle |
| **Process Inventory** | The fixed set of process executable names the script attempts to kill each cycle |

## Domain Relationships

### Service stopping

The **Monitoring Loop** fires on a 10-second interval and triggers a **Batch Stop**. A Batch Stop opens one **SCM Handle**, iterates the **Service Inventory**, and routes each service based on its **Service State**:

- **Stop-Eligible States** (`RUNNING`, `PAUSED`, `PAUSE_PENDING`, `CONTINUE_PENDING`) receive a **Stop Control** and become **Pending Services** tracked in the **Pending List**.
- `STOPPED` and `START_PENDING` are routed immediately to `ALREADY_STOPPED` or `FAILED` without issuing a control.
- `STOP_PENDING` services are added directly to the Pending List (already transitioning).

A shared deadline then polls all Pending Services until each reaches `STOPPED` or the deadline expires. Each service receives a **Result Row** with a **Stop Outcome**.

```
Monitoring Loop
  └── every 10 s: Batch Stop
        ├── SCM Handle (one per batch)
        ├── Phase 1: for each service in Service Inventory
        │     Service State → routing decision
        │       Stop-Eligible?  → Stop Control → Pending List
        │       Already STOPPED? → ALREADY_STOPPED result
        │       START_PENDING?  → FAILED result
        │       STOP_PENDING?   → Pending List (no control sent)
        └── Phase 2: poll Pending List against shared deadline
              → STOPPED or TIMED_OUT per service
              → Result Row (name, states, Stop Outcome, Win32 error)
```

### Process killing

The **Monitoring Loop** also fires on a 2-second interval and performs a **Process Kill** against every name in the **Process Inventory**. This is unconditional and immediate — no SCM involvement, no outcome tracking.

`TrustedInstaller` appears in both inventories: as a **Service Name** in the Service Inventory (stopped via SCM) and as a process executable name in the Process Inventory (killed via kernel32). These are different OS objects.

### Priority management

`LockProcessPriority` (hotkey) adds a **PID** to the **Watchlist** with a target **AutoIt Priority Constant**. The **Priority Watchdog** fires every 10 seconds, reads each watched PID's current **Priority Class** via `GetPriorityClass`, converts it via `_WinAPIPriorityClassToAutoItConst`, and restores the target if **Priority Drift** is detected. Dead PIDs are evicted.

### Logging

Every subsystem writes **Log Entries** via `_LogMessage`. The **Log Level** (0=Error, 1=Info, 2=Verbose) controls which entries reach the **Log File**. Entries that record a completed process kill or service stop are **Suppression Events** (Info level). The Log File is rotated by age.

## Decisions

Ten architectural decisions shaped this domain model. The most consequential:

| ADR | Decision |
|---|---|
| [0001](../adr/0001-servicemanager-module-extraction.md) | Service-stop behaviour extracted into `ServiceManager.au3` as a deep module; `ServiceControl.au3` retained for non-stop helpers only |
| [0002](../adr/0002-start-pending-stop-ineligible.md) | `START_PENDING` services are stop-ineligible — marked `FAILED` immediately rather than attempting a stop control |
| [0003](../adr/0003-batch-stop-two-level-error-convention.md) | Batch Stop reports at two levels: `@error 1` for SCM-open failure; per-row outcome strings for per-service results |
| [0004](../adr/0004-servicemanager-incompatible-with-servicecontrol-error-convention.md) | `ServiceManager.au3` deliberately uses a different error convention than `ServiceControl.au3`; the split is permanent |
| [0005](../adr/0005-graceful-only-service-stop.md) | Graceful-only service stop via SCM; no `TerminateProcess` fallback for unresponsive services |
| [0006](../adr/0006-batch-scoped-scm-handle.md) | SCM handle opened once per Batch Stop cycle, not once per service |
| [0007](../adr/0007-autoit-priority-constants-canonical.md) | AutoIt integers (0–5) are the canonical internal form for priority; Windows API hex constants are converted on read |
| [0008](../adr/0008-direct-dllcall-advapi32.md) | Direct `DllCall` to `advapi32.dll` instead of AutoIt `_WinAPI_*` wrappers for all SCM operations |
| [0009](../adr/0009-queryservicestatus-api-selection.md) | `QueryServiceStatus` (7-DWORD `SERVICE_STATUS`) used instead of `QueryServiceStatusEx`; `dwProcessId` is not needed |
| [0010](../adr/0010-main-loop-sleep-timing.md) | Passive main loop sleeps 50 ms (hotkey responsiveness); active monitoring loop sleeps 500 ms (CPU efficiency) |

## Glossary

Full definitions for all terms: [GLOSSARY.md](../../GLOSSARY.md)

The glossary is organised into six sections: Service Lifecycle, Process Management, Script Behaviour, Logging, Testing, and Architecture.

## Proposals (Session Work)

The ten proposal files below record the domain-modeling session that produced the current `GLOSSARY.md`. Each file is a point-in-time analysis; the accepted terms have been merged into `GLOSSARY.md` and the ADRs written to `docs/adr/`.

| File | What it found |
|---|---|
| [DM-01](proposals/DM-01-service-lifecycle.md) | Service lifecycle gaps: missing terms for SCM Handle, Service Name, Stop-Eligible State, Stop Control, Pending Service, Stop Outcome; conflict between `_ServiceRunning()` (INTERROGATE-based) and `QueryServiceStatus` (state-integer-based) definitions of "running" |
| [DM-02](proposals/DM-02-process-management.md) | Process management gaps: "process" used in two senses, PID lifetime semantics undocumented, two incompatible priority numbering schemes coexisting, Priority Drift undefined, AutoClose does not exist as a term |
| [DM-03](proposals/DM-03-stop-terminate-semantics.md) | Stop/kill/terminate/close semantic analysis: service stop is always graceful (SCM cooperative); process kill is always unconditional (`TerminateProcess`); "close" is overloaded between `_CloseInstaller` (kill) and `WinClose` (cooperative window close) |
| [DM-04](proposals/DM-04-servicemanager-api.md) | ServiceManager public API catalogue: SCM Handle vs. Service Handle distinction, two-level error convention, Result Row column-5 (`$sNote`) unnamed, `ServiceControl.au3` error convention incompatibility; proposed ADRs 0003 and 0004 |
| [DM-05](proposals/DM-05-test-vocabulary.md) | Test vocabulary: Test Harness, Test Case, Test Function, Test Suite, Stub vs. Mock vs. Fake distinction, Deterministic Test vs. Unit Test vs. Integration Test; Environment Gate (Windows-only runtime) |
| [DM-06](proposals/DM-06-configuration-lists.md) | Configuration and list structure: Service/Process Target List as domain terms; timing constants are configuration, hardcoded target lists are not; "AutoClose" and "whitelist" do not exist in this codebase |
| [DM-07](proposals/DM-07-logging-audit.md) | Logging domain: Log Level, Log Type, Log Entry, Log File, Suppression Event defined; log level values are magic integers with no named constants; "closure log" is a legacy filename, not a domain term |
| [DM-08](proposals/DM-08-architecture-patterns.md) | Architecture vocabulary: `ServiceManager.au3` is a deep module (not a wrapper or library); `ServiceControl.au3` is a shallow library; seam location identified; "migration" in the branch name understates what actually happened (module extraction with interface redesign) |
| [DM-09](proposals/DM-09-windows-scm-mapping.md) | Windows SCM API mapping: Win32 function names (`OpenSCManagerW`, `ControlService`, etc.) are implementation details, not domain terms; `DllCall` must not appear in GLOSSARY.md; proposed ADRs 0006 and 0008; cleanup of three GLOSSARY.md entries that leaked API names |
| [DM-10](proposals/DM-10-glossary-audit.md) | Full GLOSSARY.md completeness audit: 10 missing terms, 3 conflicting definitions (stale `$sProcesses2[]` reference, wrong timing-constant names, Batch Stop written as function spec), 2 overloaded terms, 5 entries contaminated with implementation detail |
