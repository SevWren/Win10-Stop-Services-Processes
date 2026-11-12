# Delete `ServiceControl.au3` rather than fix it

`ServiceControl.au3` has zero callers anywhere in the codebase: none of its five non-stop helper functions (`_ServiceRunning`, `_ServiceExists`, `_StartService`, `_CreateService`, `_DeleteService`) is invoked from `Stop Services Processes.au3`, `ServiceManager.au3`, or any test file. `_StopService` is likewise uncalled — `Stop Services Processes.au3` line 17 explicitly notes it is no longer used. Because there are no callers, deletion introduces no breaking changes and no migration work.

The file also carries two latent Win32 correctness bugs that would become high-severity the moment any function were called in a 64-bit build: every `DllCall` annotates `SC_HANDLE`/`HANDLE` return types and input parameters as `"long"` rather than `"handle"`, which silently truncates 64-bit handles to 32 bits; and `_StopService` and `_ServiceRunning` pass `"str", ""` as the `LPSERVICE_STATUS` output parameter to `ControlService`, discarding all returned state data. The target platform is Windows 10/11 x64 with `#AutoIt3Wrapper_UseX64=y`, so Bug B (handle truncation) is active on every target machine. Keeping the file means inheriting these bugs into every future build.

The fix path (mechanical `"long"` → `"handle"` substitution across all six functions, plus `DllStructCreate` for the `ControlService` calls) is well-understood and documented in BUG-07 and issue 08. It is not difficult. The objection is not cost of fixing but cost of keeping: a file with zero callers, two latent 64-bit bugs, an ANSI entry-point mismatch with `ServiceManager.au3` (which uses `OpenSCManagerW`/`OpenServiceW`), and a constant-naming workaround (`$STANDARD_RIGHTS_REQUIRED2`) adds surface area with no current benefit.

**Decision**: delete `Includes/ServiceControl.au3`.

## Considered Options

- **Keep and fix**: the fix is mechanical and issue 08 has a complete checklist. Rejected because the file has no callers. Zero callers means the fix produces no runtime benefit and no regression protection — there is nothing exercising the corrected code paths.
- **Keep deprecated, fix later**: prolongs the latent-bug surface area indefinitely. Rejected for the same reason: no callers means no urgency and no payoff, and the file's presence invites future callers to depend on still-buggy code before the fix lands.
- **Delete**: chosen. Zero callers means the deletion is clean. If start, create, delete, or exist-check operations are needed in the future, they should be written against the correct patterns already established in `ServiceManager.au3` (`"handle"` types, W-suffix entry points, `DllStructCreate` for output buffers).

## Consequences

- `Stop Services Processes.au3` includes `ServiceControl.au3` via a hardcoded `#include` path. That `#include` directive and its associated comment block (lines 14–17) must be removed as part of the deletion.
- The 51 Win32 SCM constants defined in `ServiceControl.au3` (`$SC_MANAGER_*`, `$SERVICE_*`, `$SERVICE_CONTROL_*`, service-type and start-type constants) will no longer be in scope. Any future file that needs these constants must declare them locally or in a dedicated constants include. `ServiceManager.au3` already declares its own scoped copies of the constants it uses (`$SM_*`); it is not affected.
- ADR-0011's convention (stop operations belong to `ServiceManager.au3`; non-stop SCM operations belong to `ServiceControl.au3`) becomes moot. The boundary document remains accurate as historical record but need not be updated.
- Issue 08 (`08-servicecontrol-technical-debt.md`) is resolved by deletion rather than by the fix checklist. The issue can be closed.
- If a future feature requires starting, creating, or deleting a service, the implementation must be written from scratch following the patterns in `ServiceManager.au3`: `"handle"` type annotations, W-suffix entry points, `DllStructCreate` for output buffers, and the `1`/`0`/`@error` scalar return convention required by ADR-0004.
