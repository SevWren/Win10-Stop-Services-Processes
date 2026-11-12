# Glossary Section — Service Lifecycle

**Domain area**: Service Lifecycle
**Output target**: GLOSSARY.md (synthesized by T2-11)
**Sources audited**:
- `GLOSSARY.md` (current, as of 2026-11-12)
- `docs/domain-modeling/proposals/DM-01-service-lifecycle.md`
- `docs/domain-modeling/proposals/DM-09-windows-scm-mapping.md`
- `docs/domain-modeling/proposals/DM-10-glossary-audit.md`
- `Includes/ServiceManager.au3`
- `.agents/skills/domain-modeling/GLOSSARY-FORMAT.md`

---

## Audit disposition key

Each entry is tagged with one of:
- **REPLACE** — the existing GLOSSARY.md entry must be replaced wholesale
- **NEW** — no entry exists; add this entry
- **EXISTING-OK** — entry exists and is structurally correct (not in this domain section)

---

## Entries

---

### Service
**Disposition**: NEW — not present in GLOSSARY.md; absent from all existing entries despite being the primary subject of this domain area.

**Audit note**: The current glossary assumes the reader already knows what a service is and uses "service" freely in definitions of Batch Stop, Service Handle, Service State, etc. Distinguishing Service from Process is essential: the monitoring loop terminates Processes and stops Services via entirely separate code paths (`_CloseInstaller` vs `_SM_StopServicesBatch`). No conflict between proposals; both DM-01 and DM-09 treat "service" as an understood primitive but neither formally defines it.

**Entry**:

**Service**
: A Windows program registered with the Service Control Manager that runs independently of any user session and can be started, stopped, paused, or queried through the SCM. Distinct from a Process: a service has a registered name, a lifecycle managed by the SCM, and a defined set of control operations. A process is simply a running executable instance.
_Avoid_: daemon, background process
_See also_: Service Name, Service State, Service Control Manager (SCM)

---

### Service Name
**Disposition**: NEW — not present in GLOSSARY.md. DM-01 §5 proposes this term. DM-09 confirms all SCM API calls in this codebase use the internal name, never the display name. No conflict between proposals.

**Code confirmation**: `Includes/ServiceManager.au3` passes `$sName` (e.g., `wuauserv`, `FDResPub`) directly as the service identity in every SCM operation. `GLOSSARY.md` "Service Inventory" lists these names without explaining what kind of name they are.

**Entry**:

**Service Name**
: The internal, case-insensitive identifier of a service as registered in the SCM database (e.g., `wuauserv`, `FDResPub`). This is the string the script uses to identify a service in all SCM operations. Distinct from the Display Name, which is the human-readable label shown in the services management console.
_Avoid_: service key name, service identifier
_See also_: Display Name, Service Inventory

---

### Display Name
**Disposition**: NEW — not present in GLOSSARY.md. DM-01 §5 proposes this term. No conflict between proposals.

**Code confirmation**: No operation in `ServiceManager.au3` or `ServiceControl.au3` uses a display name. All operations use the Service Name. This term is included to close the conceptual gap so readers know display names exist but are not used here.

**Entry**:

**Display Name**
: The human-readable label for a service shown in the Windows services management console (e.g., "Windows Update" for `wuauserv`). Not used in any SCM operation in this codebase; all operations identify services by Service Name.
_Avoid_: friendly name, service label
_See also_: Service Name

---

### Service State
**Disposition**: REPLACE — entry exists in GLOSSARY.md but has two defects that all three proposals agree on.

**Defects in current entry**:
1. Names both `QueryServiceStatus` and `QueryServiceStatusEx` — DM-01 §1 says use only `QueryServiceStatus`; DM-09 §3 says remove all API function names from this definition; DM-10 §4b and §3b say remove numeric codes and API names.
2. Does not distinguish stable from transient states — DM-01 §2 identifies this as a core gap.

**Conflict resolved — numeric codes**: DM-01 retains the numeric values (1–7) on the grounds that they appear verbatim in Result Row fields `$iInitialState` and `$iFinalState`. DM-10 §3b and §4b argue they belong in research docs, not the glossary. Resolution: the integer values are authoritative domain data (they are the values stored and returned in Result Rows, confirmed in `ServiceManager.au3` lines 240, 335) and therefore belong in the glossary — but as parenthetical identifiers within the named-state list, not as the primary content of the definition. The API function names do not belong.

**Conflict resolved — `QueryServiceStatusEx`**: DM-01 is correct. The codebase uses `QueryServiceStatus` exclusively (confirmed in `ServiceManager.au3`). `QueryServiceStatusEx` does not appear anywhere in the source files.

**Entry**:

**Service State**
: The lifecycle position of a registered service as reported by the SCM, expressed as one of seven named values: `STOPPED` (1), `START_PENDING` (2), `STOP_PENDING` (3), `RUNNING` (4), `CONTINUE_PENDING` (5), `PAUSE_PENDING` (6), `PAUSED` (7). The integer encoding is preserved verbatim in the Initial State and Final State fields of a Result Row. See Stable State and Transient State for the two categories of these values.
_Avoid_: service status (overloaded — also the name of the Windows struct that carries the state field)
_See also_: Stable State, Transient State, Stop-Eligible State, Result Row

---

### Stable State
**Disposition**: NEW — not present in GLOSSARY.md. DM-01 §2 proposes this term under the name "Stable Service State". DM-09 does not name it explicitly but its Stop-Eligible State discussion assumes the concept. No conflict between proposals.

**Code confirmation**: `_SM_StateToAlreadyStopped` checks for `STOPPED`; `_SM_IsStopEligible` checks for `RUNNING`, `PAUSED`, `PAUSE_PENDING`, `CONTINUE_PENDING` (which includes both stable and transient eligible states); the Phase 2 polling loop terminates when `$iPollState = $SM_STATE_STOPPED`. The stable/transient distinction is structural to the entire batch-stop design.

**Naming decision**: DM-01 uses "Stable Service State". The task specification uses "Stable State". Per GLOSSARY-FORMAT.md, pick the best one. "Stable State" is preferred: shorter, unambiguous within this domain area (no other kind of state is discussed), and consistent with the task spec. List "stable service state" under `_Avoid_` to prevent drift.

**Entry**:

**Stable State**
: A Service State in which a service remains indefinitely until an explicit operation moves it out: `RUNNING`, `STOPPED`, or `PAUSED`. Contrast with Transient State.
_Avoid_: stable service state, steady state, final state, resting state
_See also_: Transient State, Service State

---

### Transient State
**Disposition**: NEW — not present in GLOSSARY.md. DM-01 §2 proposes this term under the name "Transient Service State". No conflict between proposals.

**Code confirmation**: `_SM_StateNeedsPolling` returns true for `STOP_PENDING` — a transient state requiring Phase 2 polling. The batch-stop design is built around the distinction: stable states are routed immediately; transient states are polled.

**Naming decision**: Same rationale as Stable State — shorten to "Transient State"; list "transient service state" under `_Avoid_`.

**Entry**:

**Transient State**
: A Service State the SCM passes through during an in-progress operation: `START_PENDING`, `STOP_PENDING`, `PAUSE_PENDING`, or `CONTINUE_PENDING`. A service in a transient state may or may not accept a stop control depending on which transition is in progress. Contrast with Stable State.
_Avoid_: transient service state, pending state, intermediate state, in-progress state
_See also_: Stable State, Stop-Eligible State, Pending Service, Service State

---

### Stop-Eligible State
**Disposition**: NEW — not present in GLOSSARY.md. DM-01 §3 and DM-09 Change 4 both propose this term with identical four-state sets. No conflict between proposals.

**Code confirmation**: `_SM_IsStopEligible` in `ServiceManager.au3` (lines 476–483) returns `True` for exactly `RUNNING` (4), `PAUSED` (7), `PAUSE_PENDING` (6), and `CONTINUE_PENDING` (5) and `False` for all others. The comment block at line 86–91 of the same file cross-references this glossary term explicitly.

**Note on `START_PENDING`**: DM-01 §ADR notes that the code treats `START_PENDING` as stop-ineligible and marks it `FAILED`. This is a deliberate conservative choice documented separately in an ADR. The glossary entry does not need to explain the rationale — only the fact.

**Entry**:

**Stop-Eligible State**
: Any Service State from which the SCM will accept a stop control without immediately rejecting it: `RUNNING`, `PAUSED`, `PAUSE_PENDING`, and `CONTINUE_PENDING`. Services in `STOPPED`, `STOP_PENDING`, or `START_PENDING` are not stop-eligible in this codebase and are routed to `ALREADY_STOPPED`, pending-poll, or `FAILED` respectively without a stop control being issued.
_Avoid_: stoppable, controllable, can-stop
_See also_: Stop Control, Service State, Transient State, Stable State

---

### Service Control Manager (SCM)
**Disposition**: REPLACE — entry exists in GLOSSARY.md but contains implementation details that all three proposals agree must be removed.

**Defects in current entry**: Names `advapi32.dll` (the DLL) and `OpenSCManagerW` (the API function). DM-09 Change 1 and DM-10 §4 both flag these as implementation details. The domain concept is what the SCM *is*, not how the code reaches it.

**Conflict resolved — wording**: DM-01 adds a note about batch-scoped connection; DM-09 Change 1 adds the same note ("acquires a session-scoped connection at the start of each Batch Stop cycle"). No conflict. The batch-scoped connection detail is domain-relevant (it explains why the SCM Handle exists as a distinct concept). Include it, without naming any API function.

**Entry**:

**Service Control Manager (SCM)**
: The Windows component (accessible via `services.msc`) that is the authority for the lifecycle of all registered services on the machine: starting, stopping, querying, and configuring them. The script acquires a connection to the SCM once at the start of each Batch Stop cycle and releases it when the cycle completes.
_Avoid_: services manager, service manager, Windows service host
_See also_: SCM Handle, Service Handle, Batch Stop

---

### SCM Handle
**Disposition**: NEW — not present in GLOSSARY.md. DM-01 §4 and DM-09 Change 5 and DM-10 §3a all propose this term. All three proposals agree a distinct term is needed. Minor conflict on wording resolved below.

**Conflict resolved — API names**: DM-01's proposed definition mentions `OpenSCManagerW`, `SC_MANAGER_CONNECT`, and `CloseServiceHandle` — all implementation details. DM-09 and DM-10 correctly reject API names in glossary definitions. Use the concept-only framing from DM-09 Option B, supplemented with the batch-lifetime detail from DM-01.

**Code confirmation**: `$hSCM` in `ServiceManager.au3` (line 184) is opened once per batch call and closed at line 376 after all per-service handles are closed. The comment block at lines 160–164 explicitly documents the distinction between `$hSCM` and `$hService`.

**Entry**:

**SCM Handle**
: An opaque value representing an open connection to the Service Control Manager, obtained once at the start of a Batch Stop cycle and held until all per-service operations in that cycle complete. Distinct from a Service Handle: one SCM Handle covers the entire batch, while each service gets its own Service Handle.
_Avoid_: SCM connection, manager handle, database handle
_See also_: Service Handle, Service Control Manager (SCM), Batch Stop

---

### Service Handle
**Disposition**: REPLACE — entry exists in GLOSSARY.md but names `OpenServiceW` and `CloseServiceHandle` (API names). DM-01 §4 narrows the definition to per-service handles. DM-09 Change 2 and DM-10 §4a both say remove the API names and access-right constants. No conflict between proposals on the substance; minor conflict on wording resolved below.

**Conflict resolved — API names**: DM-01's revised definition still mentions `OpenServiceW` and `CloseServiceHandle`. DM-09 and DM-10 say no API names in the glossary. Use concept-only framing. The domain concept is an acquired, per-service capability token with a defined lifetime and release obligation.

**Code confirmation**: `$hService` in `ServiceManager.au3` is opened individually per service (line 221), held through Phase 1 routing and Phase 2 polling for that service, then closed. The comment at lines 160–164 makes the per-service vs batch-scoped distinction explicit in the code.

**Entry**:

**Service Handle**
: An opaque per-service value that grants specific access rights to one registered service. Opened at the start of that service's processing within a Batch Stop cycle and released exactly once when the service reaches a final outcome or the batch deadline expires. Distinct from the SCM Handle, which is batch-scoped.
_Avoid_: service object handle, service access token
_See also_: SCM Handle, Batch Stop

---

### Control Code
**Disposition**: NEW — not present in GLOSSARY.md. DM-01 §6 proposes this term. DM-09 §1 (`ControlService` section) labels `ControlService` an implementation detail but does not explicitly address whether the concept of a control code belongs in the glossary. DM-10 does not address it.

**Code confirmation**: `ServiceManager.au3` defines `$SM_SERVICE_CONTROL_STOP = 0x00000001` (line 83) and uses only this code in `ControlService` calls. `ServiceControl.au3` additionally uses `SERVICE_CONTROL_INTERROGATE` in `_ServiceRunning`. The concept of a control code as a distinct domain object (the instruction sent to a service's control handler) is specific to this project's SCM interaction model.

**Conflict resolved — API names and hex constants**: DM-01's definition names `ControlService` as the function and lists hex values for four control codes. Per GLOSSARY-FORMAT.md and DM-09/DM-10 rules, the function name and hex values are implementation details. Name the four codes by their symbolic identifiers only; omit hex values.

**Entry**:

**Control Code**
: An instruction delivered to a service's control handler, directing it to perform a specific operation. This codebase uses `SERVICE_CONTROL_STOP` as its primary control code. Other defined codes include `SERVICE_CONTROL_PAUSE`, `SERVICE_CONTROL_CONTINUE`, and `SERVICE_CONTROL_INTERROGATE`.
_Avoid_: control command, service command, service instruction
_See also_: Stop Control, Service Handle

---

### Stop Control
**Disposition**: NEW — not present in GLOSSARY.md. DM-01 §7 proposes this term. No conflict between proposals.

**Code confirmation**: `ServiceManager.au3` Phase 1 explicitly separates the act of issuing the stop control (`ControlService` call, lines 279–298) from the service reaching `STOPPED` state (Phase 2, lines 314–361). The Phase 2 polling loop exists precisely because the stop control is asynchronous. DM-01's key insight — "issuing a stop control does not immediately stop the service" — is confirmed by the two-phase architecture.

**Conflict resolved — API names**: DM-01's definition names `ControlService` and `SERVICE_CONTROL_STOP`. Omit the function name; `SERVICE_CONTROL_STOP` as the name of the specific control code is acceptable since it is the domain-level name of the operation (not an implementation detail), but to stay clean, refer to it via the "Control Code" term.

**Entry**:

**Stop Control**
: The act of sending a stop control code to a service's control handler. Issuing a stop control does not immediately stop the service; it signals the service to begin its shutdown sequence, after which the service transitions to `STOP_PENDING` and eventually to `STOPPED`. The stop control is distinct from the service reaching the `STOPPED` state.
_Avoid_: stopping a service (too broad — conflates the control dispatch with the final state transition)
_See also_: Control Code, Pending Service, Stop Outcome, Stop-Eligible State

---

### Stop Outcome
**Disposition**: NEW — the five outcome string values exist in GLOSSARY.md under "Result Row" but the concept of Stop Outcome as a named type does not. DM-01 §8 proposes "Stop Outcome". DM-10 §1 proposes "Outcome Code" for the same concept.

**Conflict resolved — term name**: DM-01 uses "Stop Outcome"; DM-10 uses "Outcome Code". "Stop Outcome" is more precise: the values are specific to stop operations, and "outcome" already implies a result classification without needing "code" (the values are strings, not numeric codes). DM-10's `_Avoid_` list includes "result code" and "status code", aligning with the preference for "Stop Outcome". List "Outcome Code" under `_Avoid_`.

**Code confirmation**: `ServiceManager.au3` defines `$SM_OUTCOME_STOPPED`, `$SM_OUTCOME_ALREADY`, `$SM_OUTCOME_UNAVAILABLE`, `$SM_OUTCOME_FAILED`, `$SM_OUTCOME_TIMEDOUT` (lines 55–59). The five string values correspond exactly to the five cases in the existing "Result Row" glossary entry. The `_SM_Win32ErrToOutcome` function (lines 453–462) makes the classification logic explicit.

**Entry**:

**Stop Outcome**
: The result classification assigned to a single service after a Batch Stop attempt. One of five values: `STOPPED` (the service reached the stopped state within the deadline), `ALREADY_STOPPED` (the service was already stopped or not active before the control was sent), `UNAVAILABLE` (the service does not exist in the SCM database), `FAILED` (the stop control was rejected or access was denied), `TIMED_OUT` (the service remained in a pending state past the batch deadline).
_Avoid_: outcome code, result code, stop result, status code, outcome string
_See also_: Result Row, Batch Stop, Pending Service

---

### Pending Service
**Disposition**: NEW — not present in GLOSSARY.md. DM-01 §7 proposes "Pending Service" (the individual). DM-10 §1 proposes "Pending List" (the collection). These are complementary, not conflicting: "Pending Service" is the item; "Pending List" is the set of such items.

**Task scope**: The task asks for "Pending Service" only. "Pending List" belongs to this same domain area but is a separate term for a future entry (or the synthesis agent to add). A cross-reference is included.

**Code confirmation**: `ServiceManager.au3` maintains `$aPendingIdx` and `$aPendingHnd` (lines 188–189) as the backing store for pending services. A service is added to these arrays when it either (a) accepted a stop control and transitioned to `STOP_PENDING` (Phase 1 success path, lines 303–307) or (b) was already in `STOP_PENDING` at first query (lines 256–261). Both cases match DM-01's definition precisely.

**Entry**:

**Pending Service**
: A service that has either accepted a stop control or was already in a stop-transition state at first query, and has not yet reached the `STOPPED` state. Pending services are tracked across poll cycles within a Batch Stop until each either reaches `STOPPED` or the shared batch deadline expires.
_Avoid_: in-progress service, stopping service, polled service
_See also_: Stop Control, Stop Outcome, Batch Stop, Result Row

---

## Cross-audit conflict summary

| Conflict | Proposals in disagreement | Resolution |
|---|---|---|
| `Service State` — retain numeric codes? | DM-01: yes (domain-relevant in Result Rows). DM-10: no (implementation details). | Retained as parenthetical identifiers within the named-state list. Code confirms the integers appear in Result Row fields. |
| `Service State` — mention `QueryServiceStatusEx`? | DM-01: remove it. DM-09: remove all API names. | Removed. Only `QueryServiceStatus` is used in the codebase. |
| `SCM` entry — keep API names? | DM-09: remove. DM-10: remove. DM-01: also remove (adds batch-scoped note instead). | Removed. Batch-scoped connection note retained (domain-relevant). |
| `SCM Handle` — include `SC_MANAGER_CONNECT` and `OpenSCManagerW`? | DM-01: yes. DM-09/DM-10: no (API details). | Removed. GLOSSARY-FORMAT.md rule is clear: implementation details do not belong. |
| `Service Handle` — keep `OpenServiceW` and `CloseServiceHandle`? | DM-01 revised version: retains them. DM-09 Change 2/DM-10 §4a: remove. | Removed. Concept-only definition per DM-09/DM-10. |
| `Control Code` — include hex constants? | DM-01: yes. DM-09/DM-10 rules: no. | Removed. Symbolic names retained (`SERVICE_CONTROL_STOP` etc.) as domain-level names of the operations. |
| `Stop Outcome` vs `Outcome Code` — term name? | DM-01: "Stop Outcome". DM-10: "Outcome Code". | "Stop Outcome" selected. More precise; values are strings not codes; DM-10's own `_Avoid_` list disfavours "code" framing. |
| `Pending Service` vs `Pending List` — scope? | DM-01: individual service. DM-10: collection. | Both are valid; non-conflicting. This section defines the individual ("Pending Service"). "Pending List" deferred to synthesis agent as a companion term. |

---

## Terms confirmed correct in current GLOSSARY.md (not in scope for replacement)

- **Batch Stop** — requires rewrite per DM-10 §2c (remove function name and algorithm detail), but that is a separate domain entry outside the Service Lifecycle terms listed in this task.
- **Result Row** — structurally correct per DM-10 §5; the Stop Outcome entry above provides the named type for the `$sOutcome` field.
- **Service Inventory** — domain-specific list; correct per DM-10 §5.
