# Graceful-only service stop; no force-kill fallback

**Status:** Accepted

Windows services are stopped exclusively by sending `SERVICE_CONTROL_STOP` to the SCM via `ControlService` and polling for the `STOPPED` state. If a service does not reach `STOPPED` within the shared batch deadline (`$SVC_BATCH_TIMEOUT_MS = 20 s`), it is marked `TIMED_OUT` and left running until the next monitoring cycle. No `TerminateProcess` call is ever made on a service's host process.

## Context

`_SM_StopServicesBatch` in `Includes/ServiceManager.au3` sends `SERVICE_CONTROL_STOP` (0x00000001) to each eligible service via `ControlService`. This is a cooperative request: the SCM forwards it to the service's control handler, which is responsible for transitioning to `STOPPED`. If the service does not respond within the shared polling deadline, the per-service outcome is `TIMED_OUT` and the service handle is closed. The monitoring loop retries on the next `$SVC_POLL_INTERVAL_SEC` (10 s) tick.

The target services (`wuauserv`, `TrustedInstaller`, `WaaSMedicSvc`, etc.) frequently run as `NT AUTHORITY\SYSTEM`, may have dependent services, and may be protected by Windows. The goal of this tool is to suppress update activity temporarily, not to guarantee immediate termination of a service on any given cycle.

## Decision

Graceful-only stop via `SERVICE_CONTROL_STOP`. No force-kill fallback is implemented. A service that does not stop within the batch deadline receives outcome `TIMED_OUT` and is retried on the next cycle.

## Considered options

**Force-kill on timeout:** Call `TerminateProcess` on the service host PID after a `TIMED_OUT` result. Rejected for three reasons:

1. Resolving the host PID from a service name requires `EnumProcesses` / `QueryFullProcessImageName` calls that are not currently in scope and add non-trivial complexity.
2. Target services run as `NT AUTHORITY\SYSTEM`; force-killing their host process can leave the SCM database in an inconsistent state and strand dependent services.
3. The 10-second retry cadence already provides a sufficient recovery path; the marginal gain of force-kill does not justify the stability risk.

## Consequences

**Positive:**
- The SCM database stays consistent. No orphaned service entries, no dangling dependent-service relationships.
- The implementation stays within the SCM cooperative-stop contract, which is the documented and supported path for all Windows service types.

**Negative:**
- A service that persistently ignores `SERVICE_CONTROL_STOP` (e.g., a protected or malfunctioning service) will never be stopped by this tool. The outcome will remain `TIMED_OUT` on every cycle until the service is stopped by other means.
