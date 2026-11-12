# Glossary Section — ServiceManager API Surface

Domain vocabulary for the `ServiceManager.au3` module. Terms here describe the
concepts this module introduces; they do not duplicate terms already defined in
the root `GLOSSARY.md` (Service Control Manager, Service Handle, Service State,
Batch Stop, Result Row).

Where a term in this section overlaps with a root-glossary entry, the note
"See also: root glossary" is used to signal the relationship without repeating
the definition.

---

## Language

**ServiceManager**:
The module (`Includes/ServiceManager.au3`) that owns the project's authoritative
service-stop logic. It is a deep module: a single narrow public entry point
conceals a two-phase SCM interaction (issue all stop controls without serial
waiting, then poll against a shared deadline), handle lifecycle management, and
a structured per-service result scheme. It is not a thin wrapper around
`ServiceControl.au3` and not an adapter over a generic Windows API helper —
it encodes the project's specific batch-stop policy.
_Avoid_: service wrapper, service adapter, service utility, SCM wrapper

---

**Batch Stop**:
An operation that attempts to stop a group of services as a unit under one
shared deadline, rather than stopping each service serially with its own
independent timeout. All stop controls are issued before any waiting begins;
services that do not reach the STOPPED state before the deadline expires
receive a TIMED_OUT outcome. The shared deadline is the defining characteristic:
a slow service and a fast service both count against the same clock.
_Avoid_: service stop loop, sequential stop, batch service call

> Cross-reference: the root glossary "Batch Stop" entry names the implementing
> function and describes the two-phase mechanics. This entry defines the
> domain concept without reference to implementation.

---

**Result Row**:
A six-column record produced for each service in a Batch Stop, capturing the
complete outcome of that service's stop attempt. The six columns are, in order:

| Index | Field | Type | Content |
|---|---|---|---|
| 0 | Service Name | string | The service name as supplied to the batch operation |
| 1 | Initial State | integer 1–7, or -1 | Service State at first query; -1 means the service could not be opened |
| 2 | Final State | integer 1–7, or -1 | Service State after polling completes; -1 means no query was ever made |
| 3 | Outcome | string | Per-Service Outcome — one of `STOPPED`, `ALREADY_STOPPED`, `UNAVAILABLE`, `FAILED`, `TIMED_OUT` |
| 4 | Win32 Error | integer | Win32 error code at the last failure; 0 when no error occurred |
| 5 | Note (`$sNote`) | string | Diagnostic detail for outcomes that require explanation; empty string otherwise |

Column 5 (`$sNote`) is non-empty in exactly two situations: when a service is
found in `START_PENDING` state and cannot accept a stop control, and when a
service's stop has not completed before the shared deadline expires. In all
other outcomes the field is an empty string.
_Avoid_: result record, service result, outcome row

---

**Result Array**:
The two-dimensional array returned by a Batch Stop: one Result Row per input
service, giving the array the shape `[n][6]` where `n` is the number of service
names supplied. If the input list is empty, the array has zero rows (`[0][6]`)
and is not an error condition. If the SCM cannot be opened at all, the returned
array also has zero rows, but that case is signalled as a Batch-Level Error.
_Avoid_: results array, output array, batch result

---

**Batch-Level Error**:
The condition where the Service Control Manager itself cannot be opened, making
it impossible to attempt any per-service work. It is signalled by `@error = 1`
on the return from the Batch Stop operation. A Batch-Level Error is distinct
from any per-service failure: it means no service was inspected and no Result
Row carries meaningful data. The only operation that can produce a Batch-Level
Error is the SCM open call; per-service failures (access denied, service not
found, timeout) are never Batch-Level Errors — they appear as Per-Service
Outcomes in their respective Result Rows.
_Avoid_: batch failure, SCM error, @error 1, top-level error

---

**Per-Service Outcome**:
The classification of a single service's result within a Batch Stop, encoded
as a string constant in column 3 of its Result Row. There are five possible
values:

| Value | Meaning |
|---|---|
| `STOPPED` | The service reached the STOPPED state before the shared deadline |
| `ALREADY_STOPPED` | The service was already stopped when first queried; no stop control was needed |
| `UNAVAILABLE` | The service does not exist on this machine |
| `FAILED` | A stop control was issued but was rejected, or the service could not be opened for a reason other than non-existence |
| `TIMED_OUT` | The stop control was accepted and the service entered STOP_PENDING, but did not reach STOPPED before the shared deadline |

A Per-Service Outcome is never expressed in `@error`. `@error` on a Batch Stop
result carries only the Batch-Level Error signal (`@error = 1`); `@error = 0`
means the batch ran to completion and each service's outcome must be read from
its Result Row. A batch that returns `@error = 0` may still contain rows with
`FAILED` or `TIMED_OUT` outcomes.
_Avoid_: outcome code, result code, status code, outcome string

---

## Audit notes (not part of the glossary proper)

The following observations were made during cross-audit against `GLOSSARY.md`,
`DM-04`, and `DM-10`. They are recorded here for review; none of them modify
`GLOSSARY.md` directly.

**Result Row — column 5 omission in root glossary.**
The root `GLOSSARY.md` "Result Row" entry lists the sixth element as `""` (a
bare empty string) with no name or description. The code names it `$sNote` and
populates it with diagnostic text in the `START_PENDING` and `TIMED_OUT` cases.
The definition above corrects this. The root-glossary entry should be updated to
match.

**Batch Stop — function-spec language in root glossary.**
The root `GLOSSARY.md` "Batch Stop" entry names `_SM_StopServicesBatch()` and
describes its internal phases. Per `GLOSSARY-FORMAT.md`, function names and
algorithm steps are implementation details, not domain vocabulary. The
definition above rewrites Batch Stop as a domain concept. The root-glossary
entry should be replaced with the concept-only form.

**Outcome column index.**
The root `GLOSSARY.md` "Result Row" entry lists the outcome at position 3 and
names it `$sOutcome`. The code confirms this is column index `[i][3]`. There
is no discrepancy on column index — only the missing `$sNote` description at
index 5.

**`@error` two-level contract — not documented in root glossary.**
The asymmetry between `@error = 1` (SCM open failure only) and `@error = 0`
(batch ran; inspect rows) is a deliberate design decision with real failure-mode
consequences for callers. It is captured here as the Batch-Level Error /
Per-Service Outcome distinction. DM-04 §3.3 proposes a companion ADR
(`docs/adr/0003-batch-stop-two-level-error-convention.md`).
