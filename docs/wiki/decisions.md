---
updated: 2026-11-11
---

# Architecture Decisions Log

Decisions recorded here are those that are hard to reverse, surprising without context,
and the result of a real trade-off. Each entry cites the ticket that produced it.

## D-001 — Local Markdown Issue Tracker (2026-11-11)

**Decision**: Use local markdown files under `.scratch/service-manager-migration/issues/`
as the issue tracker for this effort.

**Why**: No GitHub authentication is available in the Maton sandbox environment.
The `gh` CLI is not installed. Local markdown is the supported fallback per
`setup-matt-pocock-skills`.

**How to apply**: All ticket references in this effort use the format `T01`–`T06`
pointing to `.scratch/service-manager-migration/issues/0N-*.md`.

## D-002 — ServiceManager.au3 Supersedes ServiceControl.au3 for Stopping (2026-11-11)

**Decision**: `Includes/ServiceManager.au3` becomes the single authoritative path
for service-stop operations. `Includes/ServiceControl.au3` is retained for
`_ServiceExists`, `_ServiceRunning`, `_StartService`, `_CreateService`, and `_DeleteService`
(functions not duplicated in ServiceManager). The `_StopService` function in
ServiceControl.au3 is no longer called from the main script.

**Why**: ServiceControl.au3's `_StopService` sends a stop control but does not wait for
the service to reach STOPPED state, making it impossible to verify outcome. The enterprise
prompt requires per-service outcome classification (STOPPED, ALREADY_STOPPED, UNAVAILABLE,
FAILED, TIMED_OUT).

**How to apply**: `_stopservicescustom()` in the main script is replaced with a call to
`_SM_StopServicesBatch()`. ServiceControl.au3 stays included for its non-stop helpers.
