---
created: 2026-11-11
updated: 2026-11-12
branch: arch/service-manager-migration
---

# Wiki Index — Win10-Stop-Services-Processes Rework

## Project Overview

An AutoIt v3 script that runs as a persistent background process (system tray) on Windows 10/11.
It suppresses Windows Update and related telemetry activity by periodically terminating a
hardcoded list of processes and stopping their backing services. Secondary features include
process priority management and a priority watchdog. Requires administrator privileges
(`#RequireAdmin`).

The `arch/service-manager-migration` branch extracts SCM stop logic into a new deep module
(`Includes/ServiceManager.au3`), replacing the shallow `_StopService()` path in
`ServiceControl.au3` for all stop operations. The extraction introduced a two-phase batch-stop
algorithm with structured per-service outcomes; it was not a mechanical lift-and-shift.

See [docs/ARCHITECTURE.md](../ARCHITECTURE.md) for the full module map, public contract, DllCall
patterns, and batch-stop algorithm. See [GLOSSARY.md](../../GLOSSARY.md) for canonical
architecture-pattern vocabulary (deep module, seam, module extraction).

No ADR directory exists yet in this repository. Architecture decision rationale is recorded in
`docs/ARCHITECTURE.md` and `docs/domain-modeling/proposals/DM-08-architecture-patterns.md`.

## Module Structure

| File | Role |
|---|---|
| `Stop Services Processes.au3` | Main orchestration script: hotkeys, scheduling loop, process termination, logging |
| `Includes/ServiceManager.au3` | Deep module — authoritative for all service-stop operations; single public entry point `_SM_StopServicesBatch` |
| `Includes/ServiceControl.au3` | Shallow library — retained for `_ServiceExists`, `_ServiceRunning`, `_StartService`, `_CreateService`, `_DeleteService`; `_StopService` is not called on the monitoring hot path |
| `Tests/ServiceManager.Tests.au3` | Deterministic test harness for `ServiceManager.au3` — no live service stops |

## Pages

| Page | Summary |
|---|---|
| [environment.md](environment.md) | Sandbox environment, include requirements, AU3Check, test harness location |
| [decisions.md](decisions.md) | Architecture decisions log |
| [blockers.md](blockers.md) | Known blockers and resolution status |

## Status

| Ticket | Status | Notes |
|---|---|---|
| T01 Baseline Discovery | complete | — |
| T02 Contracts + API Verification | complete | ARCHITECTURE.md produced |
| T03 ServiceManager.au3 + Tests | complete | Includes/ServiceManager.au3 and Tests/ServiceManager.Tests.au3 delivered |
| T04 Integration | complete | Main script calls `_SM_StopServicesBatch` via `_RunServiceBatchStop` |
| T05 Independent Code Review | complete | — |
| T06 Validation + Delivery | complete | — |

**Branch commit count**: 5 commits on `arch/service-manager-migration` (above the pre-branch baseline).

**Third-pass investigation**: A third pass of bug investigation was completed (2026-11-12), producing D-011 through D-014 in `decisions.md` and BUG-08 through BUG-10 fix decisions. See [decisions.md](decisions.md) for entries.
