# ServiceControl.au3 — Analysis for Contributors

**Date**: 2026-11-12
**Branch**: arch/service-manager-migration
**Status**: reference document

---

## 1. What ServiceControl.au3 does

`ServiceControl.au3` is a shallow library that wraps five Win32 SCM operations via direct
`DllCall` to `advapi32.dll`. Each function is independent: it opens the SCM, performs one
operation, and closes all handles before returning.

### Public functions

| Function | Signature | Description |
|---|---|---|
| `_StartService` | `($sComputerName, $sServiceName)` | Opens the SCM and sends `StartService` to the named service. Does not verify the service has fully started. |
| `_StopService` | `($sComputerName, $sServiceName)` | Opens the SCM and sends `ControlService(SERVICE_CONTROL_STOP)` to the named service. Does not wait for the service to reach STOPPED state. |
| `_ServiceExists` | `($sComputerName, $sServiceName)` | Returns 1 if `OpenService` with `SERVICE_INTERROGATE` succeeds, 0 otherwise. No @error set on failure. |
| `_ServiceRunning` | `($sComputerName, $sServiceName)` | Returns the raw `ControlService(SERVICE_CONTROL_INTERROGATE)` return value (non-zero = running). Relies on the fact that only a running service responds to the interrogate control. |
| `_CreateService` | `($sComputerName, $sServiceName, $sDisplayName, $sBinaryPath [, ...])` | Creates a new service entry in the SCM database via `CreateService`. Does not create the service if it already exists (silently succeeds). Dependencies cannot be specified. |
| `_DeleteService` | `($sComputerName, $sServiceName)` | Opens the named service with `SERVICE_ALL_ACCESS` and calls `DeleteService`. Marks the service for deletion; actual removal is deferred until all handles are closed. |

### Constants block

The file also defines the full set of Win32 SCM and service access-right constants
(`$SC_MANAGER_*`, `$SERVICE_*`), service-type constants, start-type constants, error-control
constants, and the full `$SERVICE_CONTROL_*` control code set. These are global — they are
available to any file that includes `ServiceControl.au3`.

---

## 2. Architecture

### Shallow library

`ServiceControl.au3` matches the definition of a **shallow library**: a collection of
loosely related utilities, each of which closely mirrors the Win32 operation it wraps.
There is no shared state between calls.

Compare this to `ServiceManager.au3`, which is a **deep module**: a large amount of
behaviour (batch coordination, two-phase state machine, timeout polling, structured outcome
classification) hidden behind a single small public interface. See DM-08 §1 and §2.

### Per-call SCM open

Every function opens the SCM with `OpenSCManager`, performs its work, then closes the SCM
handle before returning. This means:

- Each call bears the overhead of an `OpenSCManager` / `CloseServiceHandle` round-trip.
- There is no shared deadline or coordination across calls.
- A failure to open the SCM aborts that one call; it has no effect on any other call.

This pattern is in deliberate contrast to `ServiceManager.au3`, which opens the SCM **once
per batch** and uses it for all services in the batch. That design decision is recorded in
DM-09 (Change 5 / ADR candidate A) and ADR-0001.

### Binary return values

All functions return 1 on success and 0 on failure, with `@error` set to the Win32 error
code. There are no structured outcomes. The caller cannot distinguish:

- A service that failed to stop from one that was not running.
- A service that does not exist from one where access was denied.
- A transient failure from a permanent one.

This is the core reason `_StopService` was superseded for stop operations (see ADR-0001).

---

## 3. Relationship to ServiceManager.au3

The two files divide SCM responsibilities **by convention, not by interface**. There is no
compile-time enforcement. The boundary is maintained only by the naming and inclusion
conventions documented in ADR-0001 and in this file.

### The division

| Operation | Owned by |
|---|---|
| Stop a service (monitoring hot path) | `ServiceManager.au3` — `_SM_StopServicesBatch` |
| Check whether a service exists | `ServiceControl.au3` — `_ServiceExists` |
| Check whether a service is running | `ServiceControl.au3` — `_ServiceRunning` |
| Start a service | `ServiceControl.au3` — `_StartService` |
| Create a service entry | `ServiceControl.au3` — `_CreateService` |
| Delete a service entry | `ServiceControl.au3` — `_DeleteService` |

### Functions superseded by ServiceManager.au3

**`_StopService`** is the only function in `ServiceControl.au3` that has been superseded.
`_SM_StopServicesBatch` replaces it for all stop operations on the monitoring hot path.

The reasons for supersession are documented in ADR-0001:

- `_StopService` sends one stop control per call, serially, with no state inspection before
  issuing the control.
- It does not wait for the STOPPED transition; the caller cannot tell whether the service
  actually stopped.
- Its binary return cannot distinguish ALREADY_STOPPED, UNAVAILABLE, TIMED_OUT, or FAILED.
- It opens the SCM once per service call rather than once per batch.

`_StopService` is **retained in the file** and not deleted, because there may be callers
outside this codebase. It must not be called on the monitoring hot path.

### Functions that remain useful

All other `ServiceControl.au3` functions remain on the active path and have no equivalent
in `ServiceManager.au3`:

- `_ServiceExists` — used to guard conditional logic before attempting operations.
- `_ServiceRunning` — used to check service state without issuing a stop control.
- `_StartService` — no batch-start equivalent exists.
- `_CreateService` / `_DeleteService` — administrative operations; no equivalent in
  `ServiceManager.au3`.

---

## 4. Known issues

### The `"long"` handle-type bug

Throughout `ServiceControl.au3`, Win32 handles are passed to `DllCall` with the type
annotation `"long"` rather than `"handle"`. Examples:

```autoit
; In _StartService (line 109):
$arRet = DllCall($hAdvapi32, "long", "OpenSCManager", ...)
$hSC = $arRet[0]
$arRet = DllCall($hAdvapi32, "long", "OpenService", "long", $hSC, ...)
```

The correct type for a Win32 `HANDLE` or `SC_HANDLE` is `"handle"` in AutoIt's DllCall
vocabulary. Using `"long"` truncates the handle on 64-bit Windows, where handles are
64-bit values. On a 32-bit process this is harmless, but it is technically incorrect and
can cause silent failures on 64-bit builds.

`ServiceManager.au3` uses `"handle"` throughout and is not affected by this bug. It also
uses the wide-character variants (`OpenSCManagerW`, `OpenServiceW`) whereas
`ServiceControl.au3` uses the ANSI variants (`OpenSCManager`, `OpenService`).

### `ControlService` third-argument type mismatch

`_StopService` and `_ServiceRunning` both pass a `"str"` (empty string) as the third
argument to `ControlService`:

```autoit
$arRet = DllCall($hAdvapi32, "int", "ControlService", _
        "long", $hService, _
        "long", $SERVICE_CONTROL_STOP, _
        "str", "")
```

The Win32 `ControlService` third parameter is `LPSERVICE_STATUS` — a pointer to a
`SERVICE_STATUS` structure (7 DWORDs). Passing an empty string here means the returned
status is discarded and AutoIt fills a string buffer instead of a struct. The call may
still succeed (Windows writes the status to the provided pointer), but the returned state
information is unusable. `ServiceManager.au3` correctly uses `DllStructCreate` to allocate
a `SERVICE_STATUS` buffer and passes its pointer.

### AU3Check findings

Under `AU3Check -q -d -w 1 -w 2 -w 3 -w 4` (the project's configured flags):

- The `"long"` handle-type usage described above will not produce a compiler warning —
  AU3Check does not validate DllCall type strings.
- The file lacks `#include-once`, which means including it twice in one compilation unit
  would redefine all global constants and trigger AU3Check duplicate-declaration warnings.
  `ServiceManager.au3` correctly includes `#include-once`.
- The `$STANDARD_RIGHTS_REQUIRED2` constant name has a trailing `2` to avoid a collision
  with a constant of the same base name elsewhere. This is a naming workaround, not a
  functional issue, but it is a source of confusion.

---

## 5. Guidance for future contributors

### Use ServiceManager.au3 for all stop operations

If you are writing code that needs to stop one or more services — especially on the
monitoring hot path — use `_SM_StopServicesBatch`. Do not call `_StopService` from
`ServiceControl.au3` for this purpose. See ADR-0001 for the full rationale.

`_SM_StopServicesBatch` returns a 2D result array where each row contains the service
name, initial state, final state, outcome string (`STOPPED`, `ALREADY_STOPPED`,
`UNAVAILABLE`, `FAILED`, `TIMED_OUT`), Win32 error code, and a diagnostic note. Use this
information to route log output correctly by level.

### Use ServiceControl.au3 for all non-stop SCM operations

For existence checks, running checks, start, create, and delete operations, use the
corresponding `ServiceControl.au3` function. There is no `ServiceManager.au3` equivalent
for these operations.

### Do not add stop operations to ServiceControl.au3

The boundary between the two files is a convention enforced only by documentation and
code review. Adding stop-operation logic to `ServiceControl.au3` would silently break the
convention, bypass the batch algorithm and structured outcomes in `ServiceManager.au3`, and
reintroduce the binary-return and per-call-SCM-open problems that motivated the extraction.

### Do not mix the two files' constants

`ServiceControl.au3` and `ServiceManager.au3` define overlapping but separate constant
sets. For example, both define a stop-control code, but under different names
(`$SERVICE_CONTROL_STOP` vs. `$SM_SERVICE_CONTROL_STOP`) and different scopes. When
working in `ServiceManager.au3`, use `$SM_*` constants. When working in
`ServiceControl.au3`, use the unscoped constants defined at the top of that file. Do not
cross-reference constants between files.

### Be aware of the `"long"` handle type

If you extend or modify `ServiceControl.au3`, be aware that existing calls use `"long"` for
handle types. Changing these to `"handle"` would be the correct fix, but it is a
mechanical change across every `DllCall` in the file and should be done as a dedicated
clean-up commit, not mixed with functional changes.

### The boundary is not enforced by an interface

As noted in DM-08 §7, there is no compile-time or runtime interface separating the two
files. Both are included in the same main script. Future work could formalise this boundary
(e.g., by adding an AU3Check-compatible lint step or a convention check), but no such
enforcement exists today. The constraint is: **stop operations go through
`ServiceManager.au3`; all other SCM operations go through `ServiceControl.au3`**.
