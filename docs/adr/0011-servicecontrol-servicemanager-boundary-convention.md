# The boundary between `ServiceControl.au3` and `ServiceManager.au3` is enforced by convention only

Both files are included in the same compilation unit via `#include`. AutoIt has no namespace or module system, so there is no compile-time mechanism that prevents a caller from mixing their functions or constants. The boundary — stop operations belong exclusively to `ServiceManager.au3`; all other SCM operations belong to `ServiceControl.au3` — is a convention maintained by documentation and code review alone.

## Context

`ServiceControl.au3` and `ServiceManager.au3` divide Windows SCM responsibility:

| Operation | Owned by |
|---|---|
| Stop a service (monitoring hot path) | `ServiceManager.au3` — `_SM_StopServicesBatch` |
| Check whether a service exists | `ServiceControl.au3` — `_ServiceExists` |
| Check whether a service is running | `ServiceControl.au3` — `_ServiceRunning` |
| Start a service | `ServiceControl.au3` — `_StartService` |
| Create a service entry | `ServiceControl.au3` — `_CreateService` |
| Delete a service entry | `ServiceControl.au3` — `_DeleteService` |

Both files are `#include`d into the same main script. AutoIt's preprocessor performs textual inclusion: all functions and globals from both files land in a single flat symbol space. There is no package boundary, no access modifier, and no interface type that would prevent a caller from invoking `_StopService` from `ServiceControl.au3` on the monitoring hot path, or from referencing `$SERVICE_CONTROL_STOP` (defined in `ServiceControl.au3`) inside code that is meant to run through `ServiceManager.au3`.

`ServiceControl.au3` also lacks `#include-once`, which means including it twice in one compilation unit redefines all its global constants and produces AU3Check duplicate-declaration warnings. `ServiceManager.au3` correctly includes `#include-once`.

The two files also define overlapping constant sets under different names: `ServiceControl.au3` exposes `$SERVICE_CONTROL_STOP`; `ServiceManager.au3` exposes `$SM_SERVICE_CONTROL_STOP`. Both resolve to `0x00000001`. Mixing them silently compiles and produces correct behaviour, which removes any runtime signal that the convention has been violated.

## Decision

The boundary is maintained by convention only. The rules are:

1. All stop operations on the monitoring hot path go through `_SM_StopServicesBatch` in `ServiceManager.au3`.
2. `ServiceControl.au3`'s `_StopService` is deprecated for stop operations on the monitoring hot path but is not removed.
3. No stop-operation logic is to be added to `ServiceControl.au3`.
4. When working in `ServiceManager.au3`, use `$SM_*` constants. When working in `ServiceControl.au3`, use the unscoped constants defined at the top of that file. Do not cross-reference constants between files.

## Considered Options

- **Remove `_StopService` from `ServiceControl.au3`**: rejected. `_StopService` may have callers outside this codebase that have not migrated. Its function comment explicitly states "does not check to see if the service has stopped successfully" — this is a documented limitation, not a bug. Removing it would silently break any such caller with no compile-time warning under the ANSI AutoIt build.
- **Add compile-time enforcement** (e.g., an AU3Check-compatible lint step, a preprocessor guard, or a wrapper that raises an error if `_StopService` is called): rejected for now. AutoIt provides no native module or namespace mechanism. Adding enforcement would require a new external tool or a preprocessor macro convention that does not yet exist in this project. The cost is not justified while the codebase has a single known consumer of stop operations (`_RunServiceBatchStop` in the main script).
- **Accept the convention-only boundary and document it**: chosen. Both modules are retained with their native conventions and responsibilities; contributors must learn the convention from documentation and code review.

## Consequences

- Future contributors must know the convention. It will not be caught by the compiler, by AU3Check under the project's configured flags (`-q -d -w 1 -w 2 -w 3 -w 4`), or by any existing lint step.
- A caller that adds a new stop operation to `ServiceControl.au3`, or that calls `_StopService` on the monitoring hot path, will silently bypass the two-phase batch algorithm, the per-service structured outcome array, the shared-deadline polling, and the outcome classification (`STOPPED`, `ALREADY_STOPPED`, `UNAVAILABLE`, `FAILED`, `TIMED_OUT`) that `_SM_StopServicesBatch` provides. The failure mode is incorrect log routing and loss of per-service diagnostic data, not a runtime crash.
- Any future formalisation of this boundary (e.g., an external lint rule that flags direct calls to `_StopService`) is not blocked by this decision, but it is not required by it either.
