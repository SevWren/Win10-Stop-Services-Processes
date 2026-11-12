# Domain Modeling Proposal: DM-01 — Service Lifecycle

**Status**: proposed
**Date**: 2026-11-12
**Scope**: Windows service lifecycle — service states, state transitions, SCM operations, control codes
**Sources examined**: `GLOSSARY.md`, `Includes/ServiceManager.au3`, `Includes/ServiceControl.au3`, `docs/research/windows-scm-api.md`

---

## Summary

The current `GLOSSARY.md` has one entry for `Service State` that lists the seven state integers but does not distinguish stable from transient states, does not name the concept of stop eligibility, and conflates two different Windows APIs. Several concepts that are central to the batch-stop design — the SCM Handle, the Service Name vs. Display Name distinction, Control Codes, Stop Eligibility, and the Pending Service — are absent entirely. One conflict between `ServiceControl.au3` and `ServiceManager.au3` creates a hidden semantic split in what "running" means. The proposals below address each gap.

---

## Issues found in current GLOSSARY.md

### 1. "Service State" conflates `QueryServiceStatus` and `QueryServiceStatusEx`

Current text: _"One of seven values returned by `QueryServiceStatus` / `QueryServiceStatusEx`"_

These two functions do not return the same struct. `QueryServiceStatus` fills a 7-field `SERVICE_STATUS`. `QueryServiceStatusEx` fills a 9-field `SERVICE_STATUS_PROCESS` (adds PID and service flags). The `dwCurrentState` field is field 2 in both and carries the same 1–7 integer — but conflating the two APIs obscures which is actually used (the codebase uses `QueryServiceStatus` exclusively).

**Fix**: Remove `QueryServiceStatusEx` from the `Service State` definition. Mention only `QueryServiceStatus`.

### 2. "Service State" does not distinguish stable states from transient states

The seven states are not equally stable. RUNNING, STOPPED, and PAUSED are stable (a service sits in them until an operation moves it). The four `_PENDING` states are transient (the SCM is in the middle of a transition). This distinction drives all polling and eligibility logic in the codebase.

**Fix**: Add `Stable Service State` and `Transient Service State` terms.

### 3. No term for "stop-eligible state"

`_SM_IsStopEligible()` encodes the rule: RUNNING, PAUSED, PAUSE_PENDING, and CONTINUE_PENDING accept a stop control. This is the central routing decision in `_SM_StopServicesBatch()`. It has no name in the glossary.

**Fix**: Add `Stop-Eligible State`.

### 4. No term for "SCM Handle" separate from "Service Handle"

The glossary has one `Service Handle` entry that covers handles opened with `OpenServiceW`. The SCM-level handle opened with `OpenSCManagerW` has a different lifetime (batch-scoped, not per-service), different access rights (`SC_MANAGER_CONNECT` vs. service access rights), and a different failure mode (batch-level vs. per-service-level). They are distinct domain objects.

**Fix**: Add `SCM Handle`. Narrow the existing `Service Handle` entry to per-service handles only.

### 5. No terms for "Service Name" vs. "Display Name"

The codebase always uses internal service names (`wuauserv`, `FDResPub`, etc.) passed to `OpenServiceW`. The user-visible display name shown in `services.msc` is a different field. The `Service Inventory` glossary entry lists internal names without explaining what kind of name they are.

**Fix**: Add `Service Name` and `Display Name`.

### 6. No term for "Control Code"

`SERVICE_CONTROL_STOP`, `SERVICE_CONTROL_INTERROGATE`, `SERVICE_CONTROL_PAUSE`, and `SERVICE_CONTROL_CONTINUE` are DWORD constants sent as the second argument to `ControlService`. They represent distinct semantic operations. The concept of a "control code" is unnamed in the glossary.

**Fix**: Add `Control Code`.

### 7. No term for "Stop Control" (the act) vs. reaching "STOPPED" state (the result)

`_SM_StopServicesBatch()` explicitly separates sending the stop control (Phase 1) from the service actually reaching `STOPPED` (Phase 2 polling). The glossary `Batch Stop` entry describes the whole operation but provides no vocabulary for these two phases or for the intermediate moment between them.

**Fix**: Add `Stop Control` and `Pending Service`.

### 8. "Result Row" outcome constants are defined in the glossary but the concept of "stop outcome" is not

The `Result Row` entry lists the five `$sOutcome` string constants but treats them as a list, not as a type. The glossary should name the concept so the five values can be understood as an enumeration of a type.

**Fix**: Add `Stop Outcome`.

### 9. Semantic conflict: `_ServiceRunning()` vs. `dwCurrentState = RUNNING`

`ServiceControl.au3`'s `_ServiceRunning()` determines "running" by sending `SERVICE_CONTROL_INTERROGATE` and checking whether `ControlService` returns nonzero. `ServiceManager.au3` determines state by reading `dwCurrentState` from `QueryServiceStatus`. These two definitions of "running" are not identical:
- INTERROGATE succeeds for RUNNING and also for PAUSED (a paused service still responds to interrogate).
- `dwCurrentState = 4` is narrowly RUNNING only.

The glossary `Service State` entry does not surface this split. The `_ServiceRunning()` approach was inherited from an older library and is not used by the batch-stop path, but a future reader consulting the glossary would not know that.

**Fix**: The `Service State` entry should note that the canonical state query in this codebase is `QueryServiceStatus → dwCurrentState`. The `_ServiceRunning()` function (INTERROGATE-based) is in `ServiceControl.au3` and is retained only for its legacy callers — it is not an authoritative state check. This note belongs in `GLOSSARY.md` only as a clarifying sentence on `Service State`, not as an implementation detail.

---

## Proposed additions and changes (GLOSSARY-FORMAT.md format)

The following are ready to be applied to `GLOSSARY.md`. Terms are grouped under a new `## Service Lifecycle` subheading, except where they refine existing entries.

---

### Revise existing: `Service State`

**Service State**:
One of seven integer values in `dwCurrentState` (field 2 of `SERVICE_STATUS`), returned by `QueryServiceStatus`. Values: `STOPPED` (1), `START_PENDING` (2), `STOP_PENDING` (3), `RUNNING` (4), `CONTINUE_PENDING` (5), `PAUSE_PENDING` (6), `PAUSED` (7). The canonical state read in this codebase is always from `QueryServiceStatus`, not from `SERVICE_CONTROL_INTERROGATE` response.
_Avoid_: service status (overloaded with the struct name `SERVICE_STATUS`)

---

### New terms

**Stable Service State**:
A service state in which the service remains until an operation explicitly moves it: `RUNNING`, `STOPPED`, or `PAUSED`. Contrast with Transient Service State.
_Avoid_: steady state, final state

**Transient Service State**:
A service state the SCM is passing through during an in-progress operation: `START_PENDING`, `STOP_PENDING`, `PAUSE_PENDING`, or `CONTINUE_PENDING`. A service in a transient state may or may not accept control codes, depending on which transition is in progress.
_Avoid_: pending state, intermediate state

**Stop-Eligible State**:
Any service state from which the SCM will accept a `SERVICE_CONTROL_STOP` control code without returning `ERROR_SERVICE_CANNOT_ACCEPT_CTRL` (1061): `RUNNING` (4), `PAUSED` (7), `PAUSE_PENDING` (6), and `CONTINUE_PENDING` (5). Services in `STOPPED` (1), `STOP_PENDING` (3), or `START_PENDING` (2) are not stop-eligible in this codebase.
_Avoid_: stoppable, can-stop

**SCM Handle**:
An opaque handle to the SCM database, returned by `OpenSCManagerW` and held for the lifetime of a batch operation. Grants `SC_MANAGER_CONNECT` access — sufficient to open individual service handles. Must be released with `CloseServiceHandle` after all per-service handles are closed.
_Avoid_: SCM database handle, manager handle

**Service Name**:
The internal, case-insensitive identifier of a service as registered in the SCM database (e.g., `wuauserv`, `FDResPub`). This is the string passed to `OpenServiceW`. Max 256 characters; no forward or back slashes.
_Avoid_: service key name

**Display Name**:
The human-readable label shown for a service in `services.msc` (e.g., "Windows Update"). Not used by any SCM API call in this codebase; all operations use the Service Name.
_Avoid_: friendly name, label

**Control Code**:
A DWORD constant sent as the second argument to `ControlService`, instructing the SCM to deliver a command to the service's control handler. This codebase uses only `SERVICE_CONTROL_STOP` (0x00000001). Other defined codes include `SERVICE_CONTROL_PAUSE` (0x00000002), `SERVICE_CONTROL_CONTINUE` (0x00000003), and `SERVICE_CONTROL_INTERROGATE` (0x00000004).
_Avoid_: control command, service command

**Stop Control**:
The act of calling `ControlService` with the `SERVICE_CONTROL_STOP` control code. Issuing a stop control does not immediately stop the service; it transitions the service to `STOP_PENDING` and the service's main thread handles the shutdown asynchronously. The stop control is distinct from the service reaching the `STOPPED` state.
_Avoid_: stopping a service (too broad — conflates the control dispatch with the final state)

**Pending Service**:
A service that has accepted a stop control (or was already in `STOP_PENDING` at first query) but has not yet reached the `STOPPED` state. Pending services are tracked across poll cycles in `_SM_StopServicesBatch()` Phase 2 until the shared batch deadline expires.
_Avoid_: in-progress service, stopping service

**Stop Outcome**:
The result classification for a single service after a batch-stop attempt. One of five values: `STOPPED` (reached `STOPPED` state within the deadline), `ALREADY_STOPPED` (was `STOPPED` or not active before the control was sent), `UNAVAILABLE` (service does not exist in the SCM database), `FAILED` (control rejected or access denied), `TIMED_OUT` (remained in `STOP_PENDING` past the batch deadline).
_Avoid_: result code, stop result

---

### Revise existing: `Service Handle`

**Service Handle**:
An opaque per-service handle returned by `OpenServiceW`, granting the access rights requested at open time (e.g., `SERVICE_QUERY_STATUS | SERVICE_STOP` = 0x0024 for batch stop). Every acquired service handle must be released with exactly one `CloseServiceHandle` call. Distinct from the SCM Handle, which is batch-scoped and opened with `OpenSCManagerW`.
_Avoid_: service object handle

---

### Revise existing: `Batch Stop`

**Batch Stop**:
A single call to `_SM_StopServicesBatch()` that opens the SCM once (one SCM Handle), dispatches stop controls to all stop-eligible services without serial waiting (Phase 1), then polls all Pending Services against one shared batch deadline until each reaches `STOPPED` or the deadline expires (Phase 2), and returns one Result Row per input service.
_Avoid_: bulk stop, mass stop

---

## Conflicts not addressed by glossary changes

The following conflict requires a code-level note rather than a glossary entry, because the glossary must be devoid of implementation details:

- `ServiceControl.au3`'s `_StopService()` passes a bare empty string `""` as the `SERVICE_STATUS` output struct argument to `ControlService`. This is a type mismatch against the Win32 signature (which requires a pointer to a 7-DWORD `SERVICE_STATUS` struct). This is the documented reason `ServiceManager.au3` was written as a replacement. The glossary entry for `Control Code` and `Stop Control` above is written to describe correct behavior; the broken code path is not reflected in domain vocabulary.

---

## ADR recommendation

One decision meets all three ADR criteria (hard to reverse, surprising without context, result of a real trade-off):

**`START_PENDING` is treated as stop-ineligible.**

`_SM_IsStopEligible()` excludes `START_PENDING` and marks any service found in that state as `FAILED` with Win32 error 1061. The Windows documentation for `ControlService` states that a stop control sent to a `START_PENDING` service is "dispatched if accepted" — meaning the SCM may let it through depending on whether the service has called `SetServiceStatus` to advance its checkpoint. The code takes the conservative position: never attempt to stop a `START_PENDING` service. This is surprising (the docs suggest it might work), hard to reverse (test suite encodes this as correct behavior), and was a real choice between safety/predictability and theoretical completeness. An ADR has been written at `docs/adr/0001-start-pending-stop-ineligible.md`.
