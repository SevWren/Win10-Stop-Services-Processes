# Section 08 — Conflict Resolution

**Produced by**: forensic cross-auditor (T2-10)
**Consumed by**: synthesis agent T2-11
**Date**: 2026-11-12
**Purpose**: Identify every inter-proposal and proposal-vs-GLOSSARY.md conflict, provide
a resolution rationale for each, and supply a GLOSSARY-FORMAT.md-compliant canonical
entry the synthesis agent can drop directly into the merged glossary.

---

## How to read this document

Each conflict is structured as:

```
## Conflict: [Term]
### Evidence
### Resolution
### Canonical Entry
```

The **Evidence** section names the exact source(s) in conflict and quotes the
disagreeing text. The **Resolution** explains which definition to adopt and why.
The **Canonical Entry** is formatted per GLOSSARY-FORMAT.md and is ready for
direct inclusion.

---

## Conflict 1: SCM Handle — DM-01 vs DM-09

### Evidence

**DM-01** (§4, "New terms") proposes:

> **SCM Handle**: An opaque handle to the SCM database, returned by `OpenSCManagerW`
> and held for the lifetime of a batch operation. Grants `SC_MANAGER_CONNECT` access
> — sufficient to open individual service handles. Must be released with
> `CloseServiceHandle` after all per-service handles are closed.
> _Avoid_: SCM database handle, manager handle

**DM-09** (Change 5) proposes:

> **SCM Handle**: An opaque value representing an open connection to the Service
> Control Manager, distinct from a Service Handle. One SCM Handle is opened at the
> start of each Batch Stop cycle and covers all per-service operations within that
> cycle.
> _Avoid_: SCM connection, manager handle

**DM-04** (§4.1) proposes a third wording:

> **SCM Handle**: An opaque `SC_HANDLE` value returned by `OpenSCManagerW` that
> grants the caller the right to open individual services on the local machine.
> Within a batch stop, one SCM Handle is held for the duration of the entire batch
> and released by `CloseServiceHandle` before the function returns.
> _Avoid_: SCM handle, manager handle, hSCM (code variable names do not belong
> in the glossary)

**Root disagreement**: DM-01 and DM-04 name `OpenSCManagerW` and `CloseServiceHandle`
in the definition text, violating the GLOSSARY-FORMAT.md rule that implementation
details do not belong in the glossary. DM-09 omits them and focuses on the domain
concept. The three proposals also disagree on the _Avoid_ list: DM-04 adds `hSCM`
(a code variable), which DM-04 itself acknowledges should not appear. DM-09 adds
`SCM connection` as an avoid term that neither DM-01 nor DM-04 mention.

### Resolution

Adopt DM-09's concept-only framing as the base, because it correctly strips API names
(`OpenSCManagerW`, `CloseServiceHandle`, `SC_MANAGER_CONNECT`) that are implementation
details per GLOSSARY-FORMAT.md rules and DM-10 §4 which explicitly flags these as
"implementation contamination."

Retain DM-01's clarification that the handle is batch-scoped (not per-service), because
that is the defining domain property — it is what distinguishes an SCM Handle from a
Service Handle. DM-04 also confirms this.

The _Avoid_ list should include `manager handle` (all three agree) and `SCM connection`
(DM-09). Drop `hSCM` (a code variable name) from the avoid list per DM-04's own note
that code variable names do not belong there.

Code confirms: `ServiceManager.au3` line 184 (`Local $hSCM = $aScmOpen[0]`) and the
comment block at lines 160–165 establish the batch-scoped lifetime and the distinction
from `$hService`. The canonical entry must reflect this.

### Canonical Entry

**SCM Handle**:
An opaque value representing an open connection to the Service Control Manager, distinct
from a Service Handle. One SCM Handle is held for the lifetime of a single Batch Stop
cycle — opened once before any service handles, closed after all service handles have
been released.
_Avoid_: manager handle, SCM connection

---

## Conflict 2: Service State — DM-01 vs DM-09 vs current GLOSSARY.md

### Evidence

**Current GLOSSARY.md**:

> One of seven values returned by `QueryServiceStatus` / `QueryServiceStatusEx`:
> `STOPPED` (1), `START_PENDING` (2), `STOP_PENDING` (3), `RUNNING` (4),
> `CONTINUE_PENDING` (5), `PAUSE_PENDING` (6), `PAUSED` (7).

**DM-01** (§1 "Revise existing: Service State") proposes:

> One of seven integer values in `dwCurrentState` (field 2 of `SERVICE_STATUS`),
> returned by `QueryServiceStatus`. Values: `STOPPED` (1), `START_PENDING` (2),
> `STOP_PENDING` (3), `RUNNING` (4), `CONTINUE_PENDING` (5), `PAUSE_PENDING` (6),
> `PAUSED` (7). The canonical state read in this codebase is always from
> `QueryServiceStatus`, not from `SERVICE_CONTROL_INTERROGATE` response.
> _Avoid_: service status (overloaded with the struct name `SERVICE_STATUS`)

**DM-09** (Change 3) proposes:

> One of seven values reported by the SCM for a registered service:
> `STOPPED` (1), `START_PENDING` (2), `STOP_PENDING` (3), `RUNNING` (4),
> `CONTINUE_PENDING` (5), `PAUSE_PENDING` (6), `PAUSED` (7).
> The integer encoding is preserved verbatim in the Initial State and Final State
> fields of a Result Row.

**DM-10** (§2b, §3b, §4b) adds:

> The numeric values are Windows API constants, not domain vocabulary. The named states
> themselves (STOPPED, RUNNING, PAUSED, etc.) are domain vocabulary; their integers are
> not. ... Define Service State as the lifecycle position of a Windows service, and name
> the seven values without enumerating their numeric codes.

**Root disagreements**:

1. GLOSSARY.md names both `QueryServiceStatus` and `QueryServiceStatusEx` — DM-01
   says only `QueryServiceStatus` is used in this codebase; DM-09 strips all API names.
   DM-01 is factually correct (the codebase uses `QueryServiceStatus` exclusively —
   confirmed by `ServiceManager.au3` lines 228–230 and 325–327). DM-09's total removal
   of API names is consistent with DM-10's "implementation contamination" principle.

2. DM-01 retains the struct field reference (`dwCurrentState`, `SERVICE_STATUS`,
   field 2) — DM-09 and DM-10 regard these as implementation details.

3. DM-01 adds a cross-reference note about `SERVICE_CONTROL_INTERROGATE` vs
   `QueryServiceStatus` — DM-09 omits this. The note is accurate (supported by
   DM-01's issue §9 analysis) but constitutes implementation detail according to
   GLOSSARY-FORMAT.md.

4. DM-10 §3b argues the numeric codes themselves (`STOPPED (1)`, etc.) should be
   removed. This conflicts with DM-01 and DM-09, which both retain them.

### Resolution

The numeric codes (`1`–`7`) should be retained. DM-10's argument that they are "Windows
API constants, not domain vocabulary" is partially correct — but in this project the
integer values appear verbatim in Result Row columns `[i][1]` (Initial State) and
`[i][2]` (Final State), making them observable domain data, not pure implementation
detail. DM-09 itself acknowledges this: "The integer encoding is preserved verbatim
in the Initial State and Final State fields of a Result Row." Removing them would leave
the glossary unable to describe what a Result Row initial/final state integer means.

Strip all API names (`QueryServiceStatus`, `QueryServiceStatusEx`, `dwCurrentState`,
`SERVICE_STATUS`, `SERVICE_CONTROL_INTERROGATE`) in accordance with DM-09 Change 3 and
DM-10 §4b. The INTERROGATE-vs-QueryServiceStatus note belongs in an ADR or code comment,
not the glossary.

Add `_Avoid_: service status` from DM-01, which correctly flags the overloading with
the Windows struct name.

Add DM-09's backward-link to Result Row — it is domain-level content, not an API detail.

### Canonical Entry

**Service State**:
One of seven values reported by the SCM for a registered service: `STOPPED` (1),
`START_PENDING` (2), `STOP_PENDING` (3), `RUNNING` (4), `CONTINUE_PENDING` (5),
`PAUSE_PENDING` (6), `PAUSED` (7). The integer encoding is preserved verbatim in the
Initial State and Final State fields of a Result Row.
_Avoid_: service status (overloaded with the name of the Windows struct that carries this field)

---

## Conflict 3: Stop Outcome — DM-01 vs DM-03

### Evidence

**DM-01** (§8, "New terms") proposes:

> **Stop Outcome**: The result classification for a single service after a batch-stop
> attempt. One of five values: `STOPPED` (reached `STOPPED` state within the deadline),
> `ALREADY_STOPPED` (was `STOPPED` or not active before the control was sent),
> `UNAVAILABLE` (service does not exist in the SCM database), `FAILED` (control
> rejected or access denied), `TIMED_OUT` (remained in `STOP_PENDING` past the batch
> deadline).
> _Avoid_: result code, stop result

**DM-03** (§3, "New term: Stop Outcome") proposes:

> **Stop Outcome**: The per-service result of a Batch Stop cycle. One of five values:
> `STOPPED` (service reached the STOPPED state within the deadline), `ALREADY_STOPPED`
> (service was not running when the batch started), `UNAVAILABLE` (service does not
> exist on this machine), `FAILED` (SCM or ControlService returned a non-recoverable
> error), `TIMED_OUT` (service did not reach STOPPED before the shared deadline).
> _Avoid_: "result", "status" (which is overloaded with Service State)

**Root disagreements**:

1. DM-01 defines `ALREADY_STOPPED` as "was `STOPPED` **or not active** before the
   control was sent." DM-03 defines it as "service was not running when the batch
   started." These are subtly different: DM-01's definition is broader and more
   accurate. The code in `ServiceManager.au3` confirms: `ALREADY_STOPPED` is set
   in two distinct paths — (a) `_SM_StateToAlreadyStopped` returns True (state was
   `STOPPED` at first query, line 247) and (b) `ControlService` returns Win32 error
   1062 `ERROR_SERVICE_NOT_ACTIVE` (line 292). Win32 error 1062 can be returned even
   if the service was not in `STOPPED` state at the initial query (the service could
   have stopped between the query and the control dispatch). DM-01's wording covers
   both cases; DM-03's "was not running" only covers case (a).

2. DM-01 defines `FAILED` as "control rejected or access denied." DM-03 defines it
   as "SCM or ControlService returned a non-recoverable error." DM-03 is more precise
   and broader — `FAILED` is also set when `OpenServiceW` returns an error that is
   not `ERROR_SERVICE_DOES_NOT_EXIST` (line 215 of `ServiceManager.au3`). DM-01's
   "access denied" is too narrow.

3. The _Avoid_ lists conflict: DM-01 avoids `result code, stop result`; DM-03 avoids
   `result, status`. Both are valid but incomplete. The union of both avoid lists
   is correct.

4. DM-03 uses "per-service result of a Batch Stop cycle." DM-01 says "result
   classification for a single service after a batch-stop attempt." These are
   semantically equivalent; DM-01's phrasing is tighter.

**DM-10** (§1) also proposes an "Outcome Code" term (not "Stop Outcome") with wording:
> One of five string values (`STOPPED`, `ALREADY_STOPPED`, `UNAVAILABLE`, `FAILED`,
> `TIMED_OUT`) that classifies the result of a single service-stop attempt within a
> Batch Stop.
> _Avoid_: result code, status code, outcome string

This introduces a third name ("Outcome Code") for the same concept. DM-01 and DM-03
both use "Stop Outcome." The existing `GLOSSARY.md` entry for "Result Row" uses the
term `$sOutcome` (the variable name) but does not name the concept. "Stop Outcome"
(DM-01, DM-03) is preferred over "Outcome Code" (DM-10) because "code" in Windows
contexts often implies an integer (like a Win32 error code), whereas these values are
string constants.

### Resolution

Adopt the term "Stop Outcome" (DM-01 and DM-03 both agree on the name; DM-10's
"Outcome Code" is a minority of one and introduces ambiguity with numeric codes).

For `ALREADY_STOPPED`: use DM-01's broader definition ("was `STOPPED` or not active
before the stop control was delivered"), because it correctly covers both the initial-
state path and the Win32-1062 path confirmed in the code.

For `FAILED`: use DM-03's broader framing ("a non-recoverable error from the SCM"),
because it correctly covers OpenServiceW failures, ControlService failures, and access
denial — all mapped to `FAILED` by the code.

Merge both _Avoid_ lists: `result code, stop result, status` (the word "status" is
correctly flagged by DM-03 as overloaded with Service State).

### Canonical Entry

**Stop Outcome**:
The result classification for a single service within a Batch Stop. One of five string
values: `STOPPED` (reached the `STOPPED` state within the shared deadline),
`ALREADY_STOPPED` (was already stopped or not active when the stop control was
delivered), `UNAVAILABLE` (service does not exist on this machine), `FAILED` (a
non-recoverable error was returned by the SCM), `TIMED_OUT` (did not reach `STOPPED`
before the shared deadline expired).
_Avoid_: result code, stop result, status (overloaded with Service State)

---

## Conflict 4: Batch Stop — DM-01 vs DM-03 vs DM-04 vs DM-10 vs current GLOSSARY.md

### Evidence

**Current GLOSSARY.md**:

> A single call to `_SM_StopServicesBatch()` that opens SCM once, issues stop controls
> to all eligible services without serial waiting, then polls all pending services
> against one shared deadline, and returns one result row per input service.

**DM-01** (§, "Revise existing: Batch Stop") proposes:

> A single call to `_SM_StopServicesBatch()` that opens the SCM once (one SCM Handle),
> dispatches stop controls to all stop-eligible services without serial waiting
> (Phase 1), then polls all Pending Services against one shared batch deadline until
> each reaches `STOPPED` or the deadline expires (Phase 2), and returns one Result Row
> per input service.
> _Avoid_: bulk stop, mass stop

**DM-03** (§2.6) says the existing definition is "correct and complete" and proposes
only appending: "All stop operations in a batch are cooperative (graceful); there is no
force-kill fallback for services that do not respond."

**DM-04** (§4.6) proposes:

> A single call to `_SM_StopServicesBatch()` that opens SCM once, issues stop controls
> to all eligible services without serial waiting (Phase 1), then polls all pending
> services against one **shared** deadline — not a per-service timeout — and returns one
> Result Row per input service (Phase 2). The shared deadline means a slow service and
> a fast service both count against the same clock.

**DM-10** (§2c) says the current entry "names `_SM_StopServicesBatch()`, a specific
function identifier" and proposes a concept-only rewrite:

> A single operation that attempts to stop a group of services as a unit, issuing all
> stop controls without serial waiting and measuring the outcome of each service against
> one shared deadline.
> (No _Avoid_ list provided.)

**Root disagreements**:

1. All proposals except DM-10 name the function `_SM_StopServicesBatch()` in the
   definition text. DM-10 and GLOSSARY-FORMAT.md rules say this is an implementation
   detail.

2. DM-01 and DM-04 add "Phase 1" and "Phase 2" labels — these are internal algorithm
   names, confirmed as implementation details by DM-08's analysis of module depth.

3. DM-03 adds the "graceful/no force-kill" property. This is a domain-level assertion
   (it describes the behavior, not the mechanism), not an implementation detail.

4. DM-04's addition about the shared clock ("a slow service and a fast service both
   count against the same clock") is a valuable clarification about what "shared"
   means — it is domain-level, not implementation-level.

5. DM-01 uses "SCM Handle" and "Pending Services" (which are terms proposed elsewhere)
   as cross-references. DM-04 and DM-10 do not. Using cross-references is correct
   per GLOSSARY-FORMAT.md, but only for terms that are confirmed canonical.

### Resolution

The core concept is DM-10's: a group operation under one shared deadline. Strip the
function name (`_SM_StopServicesBatch()`) per DM-10 and GLOSSARY-FORMAT.md. Strip
"Phase 1" / "Phase 2" as internal algorithm labels per DM-08.

Retain DM-03's "cooperative (graceful)" property — it is a domain behavior assertion,
not an implementation detail, and it distinguishes Batch Stop from a hypothetical
force-kill batch.

Retain DM-04's "shared deadline" clarification.

Add cross-references to `Result Row` and `Stop Outcome` (terms that are canonical
across all proposals and the existing glossary).

Add `_Avoid_: bulk stop, mass stop` from DM-01.

### Canonical Entry

**Batch Stop**:
A single operation that attempts to stop a group of services as a unit: all stop
controls are issued without serial waiting, and each service's outcome is measured
against one shared deadline — not an individual per-service timeout. All stop operations
within a batch are cooperative; there is no force-kill fallback. Returns one Result Row
per input service.
_Avoid_: bulk stop, mass stop

---

## Conflict 5: Service Handle — DM-01 vs DM-04 vs DM-09 vs current GLOSSARY.md

### Evidence

**Current GLOSSARY.md**:

> An opaque value returned by `OpenServiceW` that grants the rights requested (e.g.,
> `SERVICE_STOP`, `SERVICE_QUERY_STATUS`). Every acquired service handle must be
> released with exactly one `CloseServiceHandle` call.

**DM-01** (§, "Revise existing: Service Handle") proposes:

> An opaque per-service handle returned by `OpenServiceW`, granting the access rights
> requested at open time (e.g., `SERVICE_QUERY_STATUS | SERVICE_STOP` = 0x0024 for
> batch stop). Every acquired service handle must be released with exactly one
> `CloseServiceHandle` call. Distinct from the SCM Handle, which is batch-scoped and
> opened with `OpenSCManagerW`.
> _Avoid_: service object handle

**DM-04** (§4.2) proposes:

> An opaque `SC_HANDLE` value returned by `OpenServiceW` for a specific named service,
> granting the access rights requested (e.g., `SERVICE_STOP`, `SERVICE_QUERY_STATUS`).
> Every acquired Service Handle must be released with exactly one `CloseServiceHandle`
> call. A Service Handle is distinct from an SCM Handle: it refers to one service, not
> to the manager itself.
> _Avoid_: service object handle, hService (code variable names do not belong in the
> glossary)

**DM-09** (Change 2) proposes a minimal API-stripped version:

> An opaque value that grants specific access rights to one registered service. Each
> handle is opened with the minimum rights required for the intended operation and must
> be released exactly once when the operation completes or fails.

**Root disagreements**:

1. DM-01 and DM-04 name `OpenServiceW`, `CloseServiceHandle`, `SERVICE_QUERY_STATUS`,
   `SERVICE_STOP` — all Win32 API names. DM-09 strips them all. DM-10 §4a explicitly
   flags these as "implementation contamination."

2. DM-01 adds the hex value `0x0024` — clearly an implementation detail.

3. DM-04 adds `SC_HANDLE` (the Win32 type name) — an implementation detail.

4. DM-04 adds `hService` to the _Avoid_ list — a code variable name that DM-04's own
   parenthetical note says should not appear in the glossary. Contradictory inclusion.

5. All three proposals (DM-01, DM-04, DM-09) agree on the core concept: per-service,
   distinct from SCM Handle, must be released. DM-09 expresses this most cleanly.

### Resolution

Adopt DM-09's API-free framing as the base. The critical domain property is the
per-service scope and the distinction from the batch-scoped SCM Handle — this must
be explicit. DM-09's current wording ("one registered service") captures the per-
service scope. Add the SCM Handle distinction sentence from DM-01/DM-04 (stripping
the API names).

The release obligation ("must be released exactly once") is a domain contract, not
an implementation detail — it drives correctness of the codebase's handle lifecycle
management. Retain it.

Strip `hService`, `SC_HANDLE`, `OpenServiceW`, `CloseServiceHandle`, access right
constants, and the hex value.

_Avoid_ list: `service object handle` (DM-01, DM-04 agree). Drop `hService` from
the avoid list (a variable name is not a term the domain might use).

### Canonical Entry

**Service Handle**:
An opaque value that grants specific access rights to one registered service, distinct
from an SCM Handle which covers the entire batch. Each Service Handle must be released
exactly once when the per-service operation it was opened for completes or fails.
_Avoid_: service object handle

---

## Conflict 6: Stop-Eligible State — DM-01 vs DM-09

### Evidence

**DM-01** (§3, "New terms") proposes:

> **Stop-Eligible State**: Any service state from which the SCM will accept a
> `SERVICE_CONTROL_STOP` control code without returning `ERROR_SERVICE_CANNOT_ACCEPT_CTRL`
> (1061): `RUNNING` (4), `PAUSED` (7), `PAUSE_PENDING` (6), and `CONTINUE_PENDING` (5).
> Services in `STOPPED` (1), `STOP_PENDING` (3), or `START_PENDING` (2) are not
> stop-eligible in this codebase.
> _Avoid_: stoppable, can-stop

**DM-09** (Change 4) proposes:

> **Stop-Eligible State**: A Service State from which a stop control can be accepted:
> `RUNNING`, `PAUSED`, `PAUSE_PENDING`, or `CONTINUE_PENDING`. Services in `STOPPED`,
> `STOP_PENDING`, or `START_PENDING` are not stop-eligible and are routed to
> `ALREADY_STOPPED`, pending-poll, or `FAILED` respectively without a stop control
> being issued.
> _Avoid_: stoppable, controllable

**Root disagreements**:

1. DM-01 names `SERVICE_CONTROL_STOP`, `ERROR_SERVICE_CANNOT_ACCEPT_CTRL`, and Win32
   error code 1061 in the definition. DM-09 strips these API names. Per DM-09's own
   Change 3 principle and GLOSSARY-FORMAT.md, they are implementation details.

2. DM-01 retains the numeric state codes `(4)`, `(7)`, `(6)`, `(5)`, `(1)`, `(3)`,
   `(2)`. DM-09 omits them from this entry. Since the integer codes are confirmed
   domain data (they appear in Result Rows), and since the Service State canonical
   entry retains them, it is consistent to retain them here as well for precise
   identification of the four eligible states.

3. DM-09 adds the routing consequences ("routed to `ALREADY_STOPPED`, pending-poll, or
   `FAILED` respectively") — this describes Batch Stop phase-1 routing logic, which is
   an implementation detail, not a definition of what "stop-eligible" means.

4. The _Avoid_ lists differ: DM-01 avoids `can-stop`; DM-09 avoids `controllable`.
   Both are valid; include both.

Code confirms (ServiceManager.au3 `_SM_IsStopEligible`, lines 476–483): eligible states
are `RUNNING (4)`, `PAUSED (7)`, `PAUSE_PENDING (6)`, `CONTINUE_PENDING (5)`.

### Resolution

Use DM-09's concept-only framing (strip Win32 API names and error codes) as the base.
Retain the numeric state codes from DM-01 for precision (they are domain data, not
implementation detail — same reasoning as the Service State conflict above). Remove
DM-09's routing-consequence sentence (implementation detail of Batch Stop Phase 1).

Merge _Avoid_ lists: `stoppable, can-stop, controllable`.

### Canonical Entry

**Stop-Eligible State**:
A Service State from which a stop control can be delivered: `RUNNING` (4), `PAUSED` (7),
`PAUSE_PENDING` (6), or `CONTINUE_PENDING` (5). Services in `STOPPED` (1),
`STOP_PENDING` (3), or `START_PENDING` (2) are not stop-eligible.
_Avoid_: stoppable, can-stop, controllable

---

## Conflict 7: Batch Stop — graceful-only property (DM-03 addition vs others)

### Evidence

This is a narrower sub-conflict within Conflict 4. DM-03 (§2.6) explicitly says the
existing Batch Stop definition should append: "All stop operations in a batch are
cooperative (graceful); there is no force-kill fallback for services that do not
respond."

No other proposal includes this sentence. DM-01 and DM-04's revisions do not mention
it. DM-10's concept-only rewrite omits it.

**Root disagreement**: Is "graceful only" a domain property of Batch Stop (belongs in
the glossary) or an architectural decision (belongs in an ADR)?

### Resolution

DM-03 §4 itself acknowledges this meets the ADR three-gate test and proposes an ADR
for it. However, the _concept_ "cooperative / graceful" is still a defining property of
what a Batch Stop *is* in this domain — not an implementation mechanism. Saying "a
Batch Stop is cooperative" is a domain-level statement analogous to saying "a Service
Stop is a request, not a force." It belongs in one sentence in the glossary definition.
The ADR covers the architectural rationale for _why_ it is cooperative; the glossary
states _that_ it is.

This resolution is already baked into the Conflict 4 canonical entry above.

**No separate canonical entry needed.** The property is part of the Batch Stop entry.

---

## Conflict 8: Service Name — DM-01 vs DM-04 vs no current GLOSSARY.md entry

### Evidence

**DM-01** (§5, "New terms") proposes:

> **Service Name**: The internal, case-insensitive identifier of a service as registered
> in the SCM database (e.g., `wuauserv`, `FDResPub`). This is the string passed to
> `OpenServiceW`. Max 256 characters; no forward or back slashes.
> _Avoid_: service key name

**DM-04** (§4.3) proposes:

> **Service Name**: The short internal identifier for a Windows service — the string
> passed to `OpenServiceW` and stored in the registry under
> `HKLM\SYSTEM\CurrentControlSet\Services`. This is what `_SM_StopServicesBatch`
> accepts and what `Result Row[0]` contains. Examples: `"wuauserv"`,
> `"TrustedInstaller"`.
> _Avoid_: service key, service identifier, service string

**Root disagreements**:

1. Both name `OpenServiceW` — an implementation detail.
2. DM-04 adds the registry path — an implementation detail.
3. DM-04 names `_SM_StopServicesBatch` — a function name, implementation detail per
   GLOSSARY-FORMAT.md.
4. DM-01 adds the 256-character limit — a Windows API constraint, not a domain concept.
5. DM-04 provides the more useful cross-reference: "what `Result Row[0]` contains"
   — this connects Service Name to Result Row at the domain level (not API level).

### Resolution

Strip all implementation details (API names, registry path, function names, character
limits). Retain the domain-level content: internal identifier, case-insensitive,
examples, and the DM-04 cross-reference to Result Row[0].

Merge _Avoid_ lists: `service key name` (DM-01), `service key, service identifier,
service string` (DM-04). `service identifier` is the best of these to avoid as it
implies any kind of ID; drop the others from the final list as redundant.

### Canonical Entry

**Service Name**:
The short, case-insensitive internal identifier used to address a registered service
(e.g., `wuauserv`, `FDResPub`, `TrustedInstaller`). This is what all service-stop
operations in this codebase accept as input and what appears in column 0 of a Result Row.
_Avoid_: service key name, service identifier

---

## Conflict 9: Display Name — DM-01 vs DM-04 vs no current GLOSSARY.md entry

### Evidence

**DM-01** (§5, "New terms") proposes:

> **Display Name**: The human-readable label shown for a service in `services.msc`
> (e.g., "Windows Update"). Not used by any SCM API call in this codebase; all
> operations use the Service Name.
> _Avoid_: friendly name, label

**DM-04** (§4.4) proposes:

> **Display Name**: The human-readable label for a Windows service shown in
> `services.msc` and Task Manager. Distinct from Service Name. `ServiceManager.au3`
> does not use or return Display Names — all operations use Service Names exclusively.
> _Avoid_: service label, friendly name

**Root disagreements**:

1. DM-04 names `ServiceManager.au3` — a file name, implementation detail.
2. DM-04 adds "and Task Manager" to the UI reference — a minor factual addition.
3. DM-01 avoids `label`; DM-04 avoids `service label`. Neither is a term that appears
   in any proposal, so both are low-priority. The important avoid term is `friendly name`
   (which both proposals agree on).

### Resolution

Minor conflict only. Strip the module file name from DM-04. Merge _Avoid_ lists.
Use "this codebase" language (DM-01 style) rather than naming the specific file.

### Canonical Entry

**Display Name**:
The human-readable label shown for a service in `services.msc` (e.g., "Windows Update").
Distinct from Service Name. This codebase uses only Service Names for all operations;
Display Names do not appear as inputs or outputs.
_Avoid_: friendly name, service label

---

## Conflict 10: Process Inventory — GLOSSARY.md vs current code (code-usage conflict)

### Evidence

**Current GLOSSARY.md**:

> The array(s) of process executable names (`$sProcesses[]`, `$sProcesses2[]`) that
> `_CloseInstaller()` terminates every ~2 seconds when the monitoring loop is active.

**Code** (`Stop Services Processes.au3`, line 96):

> `Global $sProcesses[18] = [...]`

`$sProcesses2[]` does not exist anywhere in `Stop Services Processes.au3`. DM-10 §2a
confirms this: "`$sProcesses2[]` does not exist in the current codebase."

**Root conflict**: GLOSSARY.md defines a concept around two arrays; only one array
exists in the code.

Additional issue (DM-06 §4): DM-06 proposes renaming "Process Inventory" to "Process
Target List" as the more precise domain term. DM-10 §5 notes the current entries are
"accurate but carry implementation detail."

### Resolution

The reference to `$sProcesses2[]` is a factual error in GLOSSARY.md — it describes
something that does not exist in the current codebase. Remove it.

The variable name `$sProcesses[]` and the function name `_CloseInstaller()` are
implementation details per GLOSSARY-FORMAT.md. Remove them.

The timing claim "every ~2 seconds" duplicates the Timing Constants entry and is
implementation detail. Remove it.

On the naming question (DM-06 "Process Target List" vs existing "Process Inventory"):
the existing term "Process Inventory" is well-established (it appears in GLOSSARY.md,
DM-10, and DM-06 itself). DM-06 notes the two terms can coexist. Keep "Process
Inventory" as the canonical term (renaming it would affect all proposals that reference
it); DM-06's "Process Target List" is a synonym, not a replacement.

### Canonical Entry

**Process Inventory**:
The fixed set of process executable names the script attempts to kill each monitoring
cycle. Entries are executable base names (e.g., `TrustedInstaller.exe`), not service
names — the same string `TrustedInstaller` in the Service Inventory refers to the SCM
service, a distinct object.
_Avoid_: process list, process target list (synonym; Process Inventory is canonical here)

---

## Conflict 11: Timing Constants — GLOSSARY.md vs current code (code-usage conflict)

### Evidence

**Current GLOSSARY.md** entry for Timing Constants lists:

> `$PRIORITY_WATCHDOG_INTERVAL_MS = 10000` — AdlibRegister interval for priority watchdog
> `$SVC_POLL_MS = 500` — per-poll sleep inside batch-stop wait loop

**Code** (`Stop Services Processes.au3`, lines 44–47):

> `Global Const $PRIORITY_WATCHDOG_MS = 10000`
> `Global Const $SVC_BATCH_POLL_MS = 500`

DM-10 §2b confirms: "The glossary uses different identifiers: `$PRIORITY_WATCHDOG_INTERVAL_MS`
and `$SVC_POLL_MS`. Neither of those names appears anywhere in the current source."

Also missing from GLOSSARY.md: `$SVC_BATCH_TIMEOUT_MS = 20000`, which DM-10 flags as
"the most consequential timing value in the new batch-stop design."

Additional finding: GLOSSARY-FORMAT.md rules say variable names and values are
implementation details that should not appear in a domain glossary. The entire Timing
Constants entry as written is implementation-contaminated.

### Resolution

The Timing Constants entry should define the *concept* — the named set of configuration
values governing cycle intervals — without enumerating variable names or values (which
are implementation details per GLOSSARY-FORMAT.md). The specific names and values belong
in CLAUDE.md and the code (where they already live with correct names).

### Canonical Entry

**Timing Constants**:
The named configuration values that govern all interval and deadline durations in the
script: the process-kill cycle interval, the service-stop cycle interval, the monitoring
loop sleep, the priority watchdog interval, the batch-stop shared deadline, and the
batch-stop poll sleep. All timing constants are declared in a single region and
consumed without redeclaration.
_Avoid_: timing settings, interval configuration

---

## Conflict 12: Result Row — DM-04 adds column 5; current GLOSSARY.md omits it

### Evidence

**Current GLOSSARY.md**:

> A six-element array `[$sName, $iInitialState, $iFinalState, $sOutcome, $iWin32Error, ""]`
> returned for each service in a batch. `$sOutcome` is one of:
> `STOPPED`, `ALREADY_STOPPED`, `UNAVAILABLE`, `FAILED`, `TIMED_OUT`.

**DM-04** (§4.5) proposes:

> **Result Row**: A six-element array `[$sName, $iInitialState, $iFinalState,
> $sOutcome, $iWin32Error, $sNote]` returned for each service in a Batch Stop.
> `$sOutcome` is one of: `STOPPED`, `ALREADY_STOPPED`, `UNAVAILABLE`, `FAILED`,
> `TIMED_OUT`. `$sNote` carries a human-readable explanation when the outcome
> requires one (e.g., `"Service in START_PENDING state; stop control not accepted"`
> or `"Deadline exceeded (20000ms)"`); empty string otherwise.

**Root conflict**: Current GLOSSARY.md uses `""` as a placeholder for column 5 and
does not name or describe it. DM-04 names it `$sNote` and defines its contents. Code
confirms: `ServiceManager.au3` uses `$sNote` as the sixth field, populated in
the `START_PENDING` case (line 269: `"Service in START_PENDING state; stop control not
accepted"`) and timeout case (line 369: `"Deadline exceeded (" & $iBatchTimeoutMs & "ms)"`).

The trailing `""` in the current definition is therefore inaccurate as a definition —
it describes the most common value (empty), not the field itself.

### Resolution

Adopt DM-04's correction. The variable-name-style array syntax (`$sName`,
`$iInitialState`, etc.) in a glossary definition is borderline — DM-10 §5 says the
"array syntax is borderline but acceptable since it is the precise shape the entire
project uses." Accept this for Result Row specifically since the structural contract
is what callers depend on.

Remove the specific example note strings from the definition (those are code-level
content); retain the description of when the field is populated vs empty.

Align `$sOutcome` reference with the new canonical term "Stop Outcome" established in
Conflict 3 above, using it as a cross-reference.

### Canonical Entry

**Result Row**:
A six-element array `[$sName, $iInitialState, $iFinalState, $sOutcome, $iWin32Error, $sNote]`
returned for each service in a Batch Stop. `$sOutcome` is a Stop Outcome value.
`$sNote` carries a human-readable explanation when the outcome requires additional
context; it is an empty string otherwise.
_Avoid_: result record, service result

---

## Conflict 13: Priority Watchdog — GLOSSARY.md vs DM-02 (implementation contamination)

### Evidence

**Current GLOSSARY.md**:

> The `AdlibRegister`-driven mechanism (`_PriorityWatchdog`) that fires every 10 seconds,
> checks the current priority of each watched PID via `GetPriorityClass`, and restores it
> if drift is detected. Uses three parallel global arrays: `$aPriorityWatchPIDs`,
> `$aPriorityWatchTargets`, `$aPriorityWatchNames`.

**DM-02** (§, "CHANGE — Priority Watchdog") proposes:

> An autonomous periodic mechanism that detects and corrects Priority Drift for every PID
> in the watchlist. It is registered once via `AdlibRegister` when the first PID is
> added, fires every `$PRIORITY_WATCHDOG_MS` (10 seconds), and unregisters itself
> (`AdlibUnRegister`) when the watchlist is empty. Per tick it also evicts dead PIDs
> (those where `ProcessExists` returns false). Implemented in `_PriorityWatchdog()` with
> state held in three parallel global arrays: `$aPriorityWatchPIDs`,
> `$aPriorityWatchTargets`, `$aPriorityWatchNames`.
> _Avoid_: priority monitor, priority keeper

**DM-10** (§4d) flags the current entry for "implementation mechanics" contamination:
names `AdlibRegister`, the specific interval, three parallel global arrays, and
the callback function name — all implementation details.

**Root conflict**: Both the current GLOSSARY.md entry and DM-02's proposed replacement
contain implementation details (function names, constant names, array names, interval
value, `AdlibRegister` mechanism). DM-10 correctly identifies these as contamination
but does not provide a clean replacement text.

DM-02 does add value by introducing the concept of "Priority Drift" as the trigger, and
"watchlist" as the subject of the mechanism. These are domain-level concepts.

### Resolution

Strip all implementation details: `AdlibRegister`, `AdlibUnRegister`, `_PriorityWatchdog`,
`GetPriorityClass`, `ProcessExists`, `$PRIORITY_WATCHDOG_MS`, the three array names,
"10 seconds" (implementation fact from code).

Retain domain-level content: autonomous periodic mechanism, detects and corrects
Priority Drift, covers all PIDs in the Watchlist, evicts dead PIDs (this is a domain
contract — callers expect dead PIDs to be automatically removed).

Use cross-references to "Priority Drift" and "Watchlist" (both are canonical terms from
DM-02 and DM-10).

### Canonical Entry

**Priority Watchdog**:
An autonomous periodic mechanism that detects and corrects Priority Drift for every PID
in the Watchlist. It is activated when the first PID is added to the Watchlist and
deactivates itself when the Watchlist becomes empty. On each check cycle it also removes
PIDs whose processes have exited.
_Avoid_: priority monitor, priority keeper

---

## Conflict 14: Priority Class — GLOSSARY.md vs DM-02 (split into two terms)

### Evidence

**Current GLOSSARY.md**:

> A Windows API constant returned by `GetPriorityClass` (kernel32.dll): `IDLE_PRIORITY_CLASS`
> (0x40), `BELOW_NORMAL_PRIORITY_CLASS` (0x4000), `NORMAL_PRIORITY_CLASS` (0x20),
> `ABOVE_NORMAL_PRIORITY_CLASS` (0x8000), `HIGH_PRIORITY_CLASS` (0x80),
> `REALTIME_PRIORITY_CLASS` (0x100). These differ from AutoIt's `ProcessSetPriority`
> constants (0–5) — always convert via `_WinAPIPriorityClassToAutoItConst()`.

**DM-02** (§, "CHANGE — Priority Class") proposes splitting into two entries:

> **Priority Class** (Windows API term): One of six values returned by
> `GetPriorityClass` (`kernel32.dll`): `IDLE_PRIORITY_CLASS` (0x40), etc.
> These are Windows API hex constants.
> _Avoid_: priority constant, priority level (when the Windows API layer is meant)
>
> **AutoIt Priority Constant** (AutoIt layer term): The integer (0–5) passed to
> `ProcessSetPriority` and stored in `$aPriorityWatchTargets[]`.
> _Avoid_: priority class (when the AutoIt integer layer is meant)

**DM-10** (§4e) says the current entry's hex values and function references are
implementation details and proposes: "The domain concept is simply: the scheduling tier
assigned to a process by the operating system, expressed on a six-level scale."

**Root conflict**: The current entry conflates two distinct things into one entry and
includes implementation detail (hex constants, DLL name, function name). DM-02 is
correct to split them. DM-10 is correct to strip the hex constants.

However: the named constants (`IDLE_PRIORITY_CLASS`, `NORMAL_PRIORITY_CLASS`, etc.) are
used by name in the codebase (confirmed: `Stop Services Processes.au3` lines 559–572,
`_WinAPIPriorityClassToAutoItConst` switch cases). The hex values (`0x40`, etc.) are
implementation facts. The named constants are domain vocabulary here because they appear
directly in switch cases and in the CLAUDE.md priority mapping table that all developers
consult. Remove the hex values, keep the named constants.

Similarly, the AutoIt integers (0–5) appear in `$aPriorityWatchTargets[]`, in
`ProcessSetPriority` calls, and in the CLAUDE.md mapping table. They are observable
domain values, not pure implementation details.

### Resolution

Adopt DM-02's split into two terms. Strip hex values, DLL name (`kernel32.dll`), and
function names (`GetPriorityClass`, `ProcessSetPriority`, `_WinAPIPriorityClassToAutoItConst`)
per DM-10. Retain the named constants for Priority Class and the 0–5 integers for
AutoIt Priority Constant because they are observable in domain-level code.

### Canonical Entry 1

**Priority Class**:
The Windows scheduling tier assigned to a process, expressed as one of six named levels:
`IDLE_PRIORITY_CLASS`, `BELOW_NORMAL_PRIORITY_CLASS`, `NORMAL_PRIORITY_CLASS`,
`ABOVE_NORMAL_PRIORITY_CLASS`, `HIGH_PRIORITY_CLASS`, `REALTIME_PRIORITY_CLASS`. These
are Windows API constants and differ in value from the AutoIt Priority Constant scheme.
_Avoid_: priority level, priority constant (when the Windows API named constant is meant)

### Canonical Entry 2

**AutoIt Priority Constant**:
The integer (0–5) used in this codebase to represent process scheduling tier at the
AutoIt layer: 0=Idle, 1=Below Normal, 2=Normal, 3=Above Normal, 4=High, 5=Real-time.
These values differ from the Windows Priority Class constants and must be converted when
reading from or writing to Windows APIs.
_Avoid_: priority class (when the AutoIt integer layer is meant), priority constant
(ambiguous between the two schemes)

---

## Conflict 15: Service Control Manager (SCM) — DM-09 Change 1 vs current GLOSSARY.md

### Evidence

**Current GLOSSARY.md**:

> The Windows component (`services.msc`, accessed via `advapi32.dll`) that manages
> Windows services: starting, stopping, querying, and configuring them. The
> `OpenSCManagerW` API returns a handle to it.

**DM-09** (Change 1) proposes:

> The Windows component (`services.msc`) that is the authority for the lifecycle of all
> registered services on the machine: starting, stopping, querying, and configuring them.
> The script acquires a session-scoped connection at the start of each Batch Stop cycle
> and closes it when the cycle completes.

**Root conflict**: Current entry names `advapi32.dll` and `OpenSCManagerW` — both
are implementation details per DM-09 Change 1 and DM-10 §4. DM-09's replacement
removes them and adds the "session-scoped connection" lifecycle description.

However, DM-09's replacement introduces "session-scoped connection" — a term that
is not defined in the glossary and leans toward implementation language (a "connection"
to the SCM is what `OpenSCManagerW` returns). It is better to describe this at the
domain level using terms that are canonical after the conflict resolutions above.

DM-10 §5 says the current entry "correctly names the Windows concept without over-
specifying implementation" and that the API names "could be pruned but are borderline
acceptable as they identify the specific platform component." This creates a mild
disagreement with DM-09's stricter stance.

### Resolution

Strip `advapi32.dll` (DLL implementation detail) and `OpenSCManagerW` (API name).
Retain `services.msc` as the domain-visible UI reference — it is how users interact
with the concept and is not a code-level detail.

Replace DM-09's "session-scoped connection" with an SCM Handle cross-reference, since
that is the canonical term established in Conflict 1 above.

### Canonical Entry

**Service Control Manager (SCM)**:
The Windows component (`services.msc`) that manages the lifecycle of all registered
services: starting, stopping, querying, and configuring them. The script acquires one
SCM Handle per Batch Stop cycle to perform stop operations.
_Avoid_: services manager, Windows service manager

---

## Multi-proposal canonical home resolutions

The following four terms were explicitly flagged as requiring a single canonical home.

---

### Term: SCM Handle (appears in DM-01 §4, DM-04 §4.1, DM-09 Change 5, DM-10 §3a)

**Single canonical home**: The resolved entry is fully defined in Conflict 1 above.
The synthesis agent should use that entry and not merge competing wording from DM-04 or
DM-01.

---

### Term: Stop Outcome (appears in DM-01 §8, DM-03 §3, DM-10 §1 as "Outcome Code")

**Single canonical home**: The resolved entry is fully defined in Conflict 3 above.
The term is "Stop Outcome" (not "Outcome Code"). DM-10's minority "Outcome Code"
designation is rejected.

---

### Term: Batch Stop (appears in DM-01 §, DM-03 §2.6, DM-04 §4.6, DM-10 §2c)

**Single canonical home**: The resolved entry is fully defined in Conflict 4 above.
The synthesis agent must not include function names, phase labels, or algorithm steps
in the merged entry.

---

### Term: Service State (appears in DM-01 §1, DM-09 Change 3, DM-10 §2b/3b/4b)

**Single canonical home**: The resolved entry is fully defined in Conflict 2 above.
The synthesis agent should not use DM-10's recommendation to strip numeric codes from
this entry — the codes are domain data observable in Result Rows.

---

## Summary table for synthesis agent T2-11

| # | Term | Primary conflict | Resolution | Key decision |
|---|---|---|---|---|
| 1 | SCM Handle | DM-01 vs DM-04 vs DM-09 | DM-09 concept-only framing + DM-01 lifetime property | Strip all API names; retain batch-scoped lifetime and distinction from Service Handle |
| 2 | Service State | GLOSSARY.md vs DM-01 vs DM-09 vs DM-10 | Strip API names; retain numeric codes | Codes are domain data (appear in Result Rows); `QueryServiceStatusEx` removed as unused |
| 3 | Stop Outcome | DM-01 vs DM-03 vs DM-10 "Outcome Code" | "Stop Outcome" is canonical; DM-01 ALREADY_STOPPED definition; DM-03 FAILED definition | Merge both _Avoid_ lists; reject "Outcome Code" name |
| 4 | Batch Stop | GLOSSARY.md vs DM-01 vs DM-03 vs DM-04 vs DM-10 | Concept-only; strip function name and phase labels; add graceful property | "Shared deadline, not per-service timeout" from DM-04; "cooperative" from DM-03 |
| 5 | Service Handle | GLOSSARY.md vs DM-01 vs DM-04 vs DM-09 | DM-09 API-free framing + explicit SCM Handle distinction | Strip `OpenServiceW`, `CloseServiceHandle`, access right constants, hex values |
| 6 | Stop-Eligible State | DM-01 vs DM-09 | DM-09 framing; retain numeric codes; strip routing-consequences sentence | Routing is Batch Stop implementation, not definition of stop-eligibility |
| 7 | Batch Stop graceful property | DM-03 addition vs others' silence | Included in Batch Stop canonical entry | One sentence: "cooperative; no force-kill fallback" |
| 8 | Service Name | DM-01 vs DM-04 | Strip API names and registry path; retain Result Row[0] cross-reference | "Service identifier" in _Avoid_ |
| 9 | Display Name | DM-01 vs DM-04 | Minor; strip module file name | Use "this codebase" language |
| 10 | Process Inventory | GLOSSARY.md vs code | Factual fix: remove `$sProcesses2[]` reference; strip variable/function names | `$sProcesses2[]` does not exist in current code |
| 11 | Timing Constants | GLOSSARY.md vs code | Strip all variable names and values; define the concept only | Constant names `$PRIORITY_WATCHDOG_INTERVAL_MS`, `$SVC_POLL_MS` are wrong in current GLOSSARY.md |
| 12 | Result Row | GLOSSARY.md vs DM-04 | Add `$sNote` column 5 description; `""` placeholder is not a definition | Column 5 is populated in START_PENDING and TIMED_OUT outcomes |
| 13 | Priority Watchdog | GLOSSARY.md vs DM-02 vs DM-10 | Strip all implementation detail; cross-reference Priority Drift and Watchlist | `AdlibRegister`, array names, function name, interval are all implementation detail |
| 14 | Priority Class | GLOSSARY.md vs DM-02 vs DM-10 | Split into Priority Class (Windows) and AutoIt Priority Constant; strip hex values | Named constants retained; integers 0–5 retained as domain-observable values |
| 15 | Service Control Manager | GLOSSARY.md vs DM-09 | Strip `advapi32.dll` and `OpenSCManagerW`; keep `services.msc`; use SCM Handle cross-reference | `services.msc` is user-visible, not code-level |
