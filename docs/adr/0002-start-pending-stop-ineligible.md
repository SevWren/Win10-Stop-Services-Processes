# START_PENDING services are treated as stop-ineligible

`_SM_IsStopEligible()` in `ServiceManager.au3` returns `False` for a service in the `START_PENDING` state, causing `_SM_StopServicesBatch()` to record outcome `FAILED` (Win32 error 1061) for any such service rather than attempting to send `SERVICE_CONTROL_STOP`.

The Windows documentation for `ControlService` describes `START_PENDING` ambiguously: a stop control is "dispatched if accepted," meaning the SCM may forward it to the service's control handler if the service has already registered one by calling `SetServiceStatus` to advance its checkpoint. Whether the control is accepted depends on the service's internal startup progress at the exact moment the call is made — it is non-deterministic from the caller's perspective.

The codebase targets background suppression of Windows Update and telemetry services on a live system. Services caught mid-startup are rare edge cases. Attempting to stop them introduces a timing-dependent code path that is difficult to test deterministically, could leave a handle open if `ControlService` returns a partial success, and offers little practical benefit given that the services are polled again on the next cycle every 10 seconds. The conservative rule — never send stop controls into `START_PENDING` — keeps `Phase 1` of the batch-stop logic free of ambiguous cases and makes the test harness fully deterministic.

## Considered options

- **Attempt the stop control and handle the result**: Theoretically correct per MSDN. Rejected because the success condition is non-deterministic (depends on the service having registered its control handler), making it untestable without real SCM interaction.
- **Treat START_PENDING as a Pending Service (poll only)**: Rejected because there is no guarantee the service will reach RUNNING before the batch deadline, and no stop control has been sent to transition it toward STOPPED.
- **Mark FAILED immediately (chosen)**: Predictable, deterministic, testable. The service will be retried on the next batch-stop cycle once it has reached a stable state.

## Consequences

A service that starts and completes its transition to `RUNNING` between two successive batch-stop cycles will be caught on the next cycle. The worst-case extra delay is `$SVC_POLL_INTERVAL_SEC` (10 seconds). This is acceptable for the suppression use case.
