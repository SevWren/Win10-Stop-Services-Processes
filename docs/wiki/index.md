---
created: 2026-11-11
goal: Replace broken service-stop path with verified, portable, native SCM implementation
branch: arch/service-manager-migration
---

# Wiki Index — Win10-Stop-Services-Processes Rework

## Goal

Replace the unverified `ServiceControl.au3`-based service-stop path with a native, portable
Windows SCM implementation that passes AU3Check, compiles x86+x64, and has independent
code-review approvals.

## Pages

| Page | Summary |
|---|---|
| [environment.md](environment.md) | Pit-of-success improvements and agent guardrails |
| [decisions.md](decisions.md) | Architecture decisions log |
| [blockers.md](blockers.md) | Known blockers and resolution status |

## Status

| Ticket | Status | Agent | Notes |
|---|---|---|---|
| T01 Baseline Discovery | pending | — | — |
| T02 Contracts + API Verification | pending | — | Blocked by T01 |
| T03 ServiceManager.au3 + Tests | pending | — | Blocked by T02 |
| T04 Integration | pending | — | Blocked by T03 |
| T05 Independent Code Review | pending | — | Blocked by T04 |
| T06 Validation + Delivery | pending | — | Blocked by T05 |
