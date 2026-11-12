# DM-09 — Windows SCM API Domain Mapping

**Date**: 2026-11-12
**Status**: proposed
**Scope**: GLOSSARY.md additions and clarifications arising from the Win32 SCM API surface
**Do not modify**: GLOSSARY.md directly — apply proposals from this file after review

---

## Purpose

The project calls `OpenSCManagerW`, `OpenServiceW`, `QueryServiceStatus`, `ControlService`,
and `CloseServiceHandle` through two different layers: the legacy `ServiceControl.au3`
(raw `DllCall` per function call) and the new `ServiceManager.au3` (`_SM_StopServicesBatch`).
Neither layer's terms are fully captured in the glossary. This document analyses the mapping
between Win32 concepts and the AutoIt-level abstractions, identifies gaps, and proposes
the minimal set of glossary changes needed to give future contributors a clear vocabulary.

---

## Analysis

### 1. Win32 function → project-level term mapping

#### `OpenSCManager` / `OpenSCManagerW`

Win32 opens a handle to the SCM database. At the project level this handle is an
implementation detail inside `_SM_StopServicesBatch`; it is never exposed to the
calling script. The glossary already defines **Service Control Manager (SCM)** as the
Windows component. `OpenSCManagerW` is the mechanism for obtaining access to it, not a
domain concept in its own right.

**Verdict**: `OpenSCManagerW` is an implementation detail hidden behind ServiceManager.
No glossary term is needed for the act of opening the SCM. The existing "Service Control
Manager (SCM)" entry covers the concept.

**Proposed clarification to existing entry**: the current definition mentions
`OpenSCManagerW` by name, which is an implementation detail leaking into the glossary.
Recommend removing the API name from the definition text. Proposed replacement wording
(no API names):

> The Windows component (`services.msc`) that is the authority for starting, stopping,
> querying, and configuring services. The script acquires a session-scoped connection to
> it at the start of each Batch Stop cycle and releases it when the cycle completes.

#### `OpenService` / `OpenServiceW`

Returns a **Service Handle** granting specific access rights to one service. The glossary
already defines "Service Handle" precisely. `OpenServiceW` is again the mechanism —
an implementation detail inside `_SM_StopServicesBatch` and `ServiceControl.au3`
functions. It is not a domain concept.

**Verdict**: implementation detail. No new term needed.

#### `QueryServiceStatus`

Reads the current **Service State** from the SCM. Used both in Phase 1 (initial state
classification) and Phase 2 (polling). The glossary already defines "Service State".
`QueryServiceStatus` is the mechanism.

**Verdict**: implementation detail. No new term needed. The distinction between
`QueryServiceStatus` (7-field `SERVICE_STATUS`) and `QueryServiceStatusEx`
(9-field `SERVICE_STATUS_PROCESS`) is an implementation detail relevant to
`ServiceManager.au3` correctness but not a domain concept.

#### `ControlService`

Delivers a control code to a running service. At the project level the only control code
used is `SERVICE_CONTROL_STOP`. The glossary has "Batch Stop" as the high-level concept;
`ControlService` is the Win32 mechanism.

**Verdict**: implementation detail. No new term needed. The stop control itself is
already captured in the "Batch Stop" and "Result Row" entries.

**Note**: `SERVICE_CONTROL_INTERROGATE` is used in `ServiceControl.au3` → `_ServiceRunning`
to test whether a service is responsive. This is a distinct usage pattern from stop
operations, but it is still a mechanism, not a domain concept.

---

### 2. Is "DllCall" a first-class term or an implementation detail?

`DllCall` is AutoIt's built-in function for invoking exported Win32 API functions at
runtime. It appears on nearly every line of both `ServiceControl.au3` and
`ServiceManager.au3`, but it is a language-level mechanism, not a domain concept
specific to this project.

The glossary rule is clear: "Only include terms specific to this project's context."
`DllCall` is a general AutoIt programming construct. It belongs in `docs/research/` and
`CLAUDE.md` (where it already lives) but not in `GLOSSARY.md`.

**Verdict**: `DllCall` is an implementation detail. It must not appear in the glossary.

---

### 3. Capitalization and status of "SCM"

The acronym **SCM** appears throughout the codebase:

- `ServiceManager.au3` uses it in variable names (`$hSCM`), comments, and log messages
- `docs/research/windows-scm-api.md` uses it as the standard short form
- `GLOSSARY.md` uses the full expansion "Service Control Manager (SCM)" as its heading
- `CLAUDE.md` uses "SCM" unadorned in the ServiceControl.au3 description

The glossary defines the term under the heading "Service Control Manager (SCM)".
The initialism is therefore introduced there. Usage as a bare acronym in code and
documentation is consistent with that definition.

**Findings**:
- "SCM" is always all-caps (it is a standard Windows acronym).
- The glossary correctly introduces it as "(SCM)" at first use and can be referenced as
  "SCM" thereafter.
- No change needed to the glossary heading or capitalization convention.

---

### 4. Windows error codes — named concepts or magic numbers?

`ServiceManager.au3` defines named constants for the four Win32 error codes it acts on:

```autoit
Global Const $SM_ERR_ACCESS_DENIED  = 5
Global Const $SM_ERR_SVC_NOT_EXIST  = 1060   ; ERROR_SERVICE_DOES_NOT_EXIST
Global Const $SM_ERR_CANNOT_ACCEPT  = 1061   ; ERROR_SERVICE_CANNOT_ACCEPT_CTRL
Global Const $SM_ERR_NOT_ACTIVE     = 1062   ; ERROR_SERVICE_NOT_ACTIVE
```

The mapping from these codes to Outcome strings is a deliberate project decision:

- `1060` (service not found) → `UNAVAILABLE`
- `1062` (service not started) → `ALREADY_STOPPED`
- anything else → `FAILED`

The question is whether these error codes belong in the glossary. Applying the glossary
rule: "Only include terms specific to this project's context." The error codes
themselves are Win32 platform constants — not specific to this project. However, the
**semantic classification** that the project imposes on them (which codes mean
"unavailable" vs. "already stopped" vs. "failed") is a project-level decision.

**Verdict**: The Win32 error code names (`ERROR_SERVICE_DOES_NOT_EXIST`, etc.) are
platform constants and do not belong in the glossary. The classification logic lives in
`_SM_Win32ErrToOutcome()` and is fully expressed through the existing "Result Row"
glossary entry (which lists the five `$sOutcome` values). No new glossary term is needed.

The code-level constants (`$SM_ERR_*`) are implementation details.

---

## Proposed GLOSSARY.md changes

### Change 1 — Remove API names from "Service Control Manager (SCM)" definition

**Current text:**
> The Windows component (`services.msc`, accessed via `advapi32.dll`) that manages
> Windows services: starting, stopping, querying, and configuring them. The
> `OpenSCManagerW` API returns a handle to it.

**Problem**: mentions `advapi32.dll` (the DLL name) and `OpenSCManagerW` (the API
function). Both are implementation details. The glossary should describe what the SCM
*is*, not how the code reaches it.

**Proposed replacement:**
> The Windows component (`services.msc`) that is the authority for the lifecycle of all
> registered services on the machine: starting, stopping, querying, and configuring them.
> The script acquires a session-scoped connection at the start of each Batch Stop cycle
> and closes it when the cycle completes.

---

### Change 2 — Remove API names from "Service Handle" definition

**Current text:**
> An opaque value returned by `OpenServiceW` that grants the rights requested (e.g.,
> `SERVICE_STOP`, `SERVICE_QUERY_STATUS`). Every acquired service handle must be released
> with exactly one `CloseServiceHandle` call.

**Problem**: names `OpenServiceW` and `CloseServiceHandle` — Win32 API names that are
implementation details. Also names two specific access-right constants that belong in
research notes, not in domain vocabulary.

**Proposed replacement:**
> An opaque value that grants specific access rights to one registered service. Each
> handle is opened with the minimum rights required for the intended operation and must be
> released exactly once when the operation completes or fails.

---

### Change 3 — Remove API names from "Service State" definition

**Current text:**
> One of seven values returned by `QueryServiceStatus` / `QueryServiceStatusEx`:
> `STOPPED` (1), `START_PENDING` (2), `STOP_PENDING` (3), `RUNNING` (4),
> `CONTINUE_PENDING` (5), `PAUSE_PENDING` (6), `PAUSED` (7).

**Problem**: names the two API functions. The state values and their integer encodings
are domain-relevant (they appear in Result Rows), but the API names are not.

**Proposed replacement:**
> One of seven values reported by the SCM for a registered service:
> `STOPPED` (1), `START_PENDING` (2), `STOP_PENDING` (3), `RUNNING` (4),
> `CONTINUE_PENDING` (5), `PAUSE_PENDING` (6), `PAUSED` (7).
> The integer encoding is preserved verbatim in the Initial State and Final State
> fields of a Result Row.

---

### Change 4 — Add "Stop-Eligible State" term

**Gap**: `_SM_IsStopEligible()` encodes a project-specific rule about which Service
States can receive a stop control. This rule drives Phase 1 of Batch Stop and is
referenced in log messages. The concept is not currently named in the glossary.

**Proposed new term:**

**Stop-Eligible State**:
A Service State from which a stop control can be accepted: `RUNNING`, `PAUSED`,
`PAUSE_PENDING`, or `CONTINUE_PENDING`. Services in `STOPPED`, `STOP_PENDING`, or
`START_PENDING` are not stop-eligible and are routed to `ALREADY_STOPPED`, pending-poll,
or `FAILED` respectively without a stop control being issued.
_Avoid_: stoppable, controllable

---

### Change 5 — Add "SCM Handle" term (or fold into SCM entry)

**Gap**: The glossary defines "Service Handle" (for a per-service handle) but does not
distinguish it from the SCM-level connection handle. In `ServiceManager.au3` the two
are clearly different objects: `$hSCM` (opened once per batch, closed at end of batch)
and `$hService` (opened per service, closed per service). A future contributor could
confuse the two.

**Option A** — Add a brief clarifying sentence to the existing "Service Control Manager
(SCM)" entry:
> The connection to the SCM is represented by a separate handle (`$hSCM`) that is
> distinct from per-service Service Handles.

**Option B** — Add a standalone "SCM Handle" term:

**SCM Handle**:
An opaque value representing an open connection to the Service Control Manager, distinct
from a Service Handle. One SCM Handle is opened at the start of each Batch Stop cycle
and covers all per-service operations within that cycle.
_Avoid_: SCM connection, manager handle

**Recommendation**: Option B. The distinction between SCM Handle and Service Handle is
non-obvious and has caused bugs in `ServiceControl.au3` (which opens a new SCM handle
per function call rather than sharing one). Making it a named concept gives future work
a clearer target.

---

## ADR candidates

### Candidate A — Batch-scoped SCM Handle vs. per-call SCM Handle

**Meets all three criteria?**

1. Hard to reverse: yes. Changing to per-call SCM handles means rewriting
   `_SM_StopServicesBatch` and would affect the timing guarantees of Phase 1.
2. Surprising without context: yes. `ServiceControl.au3` opens and closes the SCM on
   every function call; `ServiceManager.au3` deliberately opens once per batch.
   A reader who only knows the `ServiceControl.au3` pattern will be surprised.
3. Real trade-off: yes. Per-call: simpler, independent. Per-batch: more efficient
   (one SCM open/close), enables a single shared deadline, but means one SCM failure
   aborts the whole batch rather than failing individual services.

**Verdict**: ADR warranted. Suggested title: "SCM handle opened once per Batch Stop cycle,
not once per service". File as `docs/adr/0001-batch-scoped-scm-handle.md` (or the next
sequential number if ADRs already exist).

### Candidate B — `DllCall` used directly instead of AutoIt built-in service wrappers

**Meets all three criteria?**

1. Hard to reverse: moderate. AutoIt does have built-in `_WinAPI_*` wrappers but they
   are unreliable (see `CLAUDE.md` compatibility notes).
2. Surprising without context: yes. A new contributor would reach for AutoIt's built-ins.
3. Real trade-off: yes. The `CLAUDE.md` already documents this for the kernel32.dll
   priority-class path. The same reasoning applies to the advapi32.dll SCM path in
   `ServiceControl.au3`.

**Verdict**: ADR warranted if not already recorded. Check `docs/adr/` before creating.
Suggested title: "Direct DllCall to advapi32.dll instead of AutoIt WinAPI wrappers for
SCM operations".

---

## Summary table

| Question | Finding |
|---|---|
| `OpenSCManager` → project term? | Implementation detail inside ServiceManager; no glossary term needed |
| `OpenService` → project term? | Implementation detail; "Service Handle" already covers the result |
| `ControlService` → project term? | Implementation detail; "Batch Stop" covers the concept |
| `QueryServiceStatus` → project term? | Implementation detail; "Service State" covers the result |
| Is "DllCall" a first-class term? | No — general AutoIt mechanism; must not appear in glossary |
| Is "SCM" always capitalized? | Yes — standard Windows acronym; glossary heading is correct |
| Is "SCM" in the glossary? | Yes — defined under "Service Control Manager (SCM)" |
| Win32 error codes — named concepts? | Platform constants; not glossary terms. Classification logic is captured by Result Row outcome strings |
| Glossary entries to clean up | 3 (SCM, Service Handle, Service State — remove API names) |
| New glossary terms to add | 2 (Stop-Eligible State, SCM Handle) |
| ADRs to write | 2 (batch-scoped SCM handle; direct DllCall over AutoIt wrappers) |
