# `ServiceManager.au3` deliberately uses a different error convention than `ServiceControl.au3`

`ServiceControl.au3` functions (`_StopService`, `_StartService`, `_ServiceExists`, etc.) follow a scalar convention: return `1` on success, return `0` on failure, and encode the Win32 error code directly in `@error`. `ServiceManager.au3` does not follow this convention: it returns a 2D result array and uses `@error` only for the batch-level SCM-open failure.

The two modules co-exist in the same include chain and operate on the same Windows SCM API. A developer familiar with `ServiceControl.au3`'s `1` / `0` / `@error` pattern will misread `_SM_StopServicesBatch`'s `@error = 0` return as "all services stopped successfully" when it actually means "the batch ran; check each row".

This divergence is intentional and cannot be avoided without losing the per-service outcome data that is the reason `ServiceManager.au3` was written (see D-002 in `docs/wiki/decisions.md`). `_StopService` sends a stop control and returns before the service has actually stopped; it cannot return per-service state transitions. Conforming `_SM_StopServicesBatch` to `ServiceControl.au3`'s scalar return style would eliminate the structured result array that makes outcome classification possible.

**Consequence**: the two modules must never be used interchangeably for stop operations. Any future function added to either module that performs stop operations should follow `ServiceManager.au3`'s result-array convention, not `ServiceControl.au3`'s scalar convention. The split is permanent as long as both modules coexist.

## Considered Options

- **Adapt `ServiceControl.au3`'s `_StopService` to return structured results**: rejected — would require changing an existing function that may have callers outside this codebase; the function comment explicitly states "does not check to see if the service has stopped successfully", which is a documented limitation not a bug.
- **Wrap `_SM_StopServicesBatch` in a `1`/`0`/`@error` façade**: rejected — a façade that collapses per-service outcomes to a scalar discards the information the module was built to produce.
- **Accept the incompatibility and document it**: chosen — both modules are retained with their native conventions; callers must choose the right one for their use case.
