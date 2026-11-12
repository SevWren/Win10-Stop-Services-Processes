# Section 09 — Implementation Contamination Cleanup

**Source proposal**: DM-10, Section 4 (Implementation Contamination) and Section 2a (Conflicting Terms — Process Inventory)
**Governing rules**: `.agents/skills/domain-modeling/SKILL.md` ("totally devoid of implementation details"), `.agents/skills/domain-modeling/GLOSSARY-FORMAT.md`
**Read-only references**: `GLOSSARY.md` (current), `DM-10-glossary-audit.md`, `DM-09-windows-scm-mapping.md`
**Status**: Ready to apply — no GLOSSARY.md changes made here; this document records the before/after for each contaminated entry.

---

## Entry 1 — Service Handle

### Contaminated text (current GLOSSARY.md, verbatim)

> An opaque value returned by `OpenServiceW` that grants the rights requested (e.g.,
> `SERVICE_STOP`, `SERVICE_QUERY_STATUS`). Every acquired service handle must be released
> with exactly one `CloseServiceHandle` call.

### Why it is contaminated

The entry names two Win32 API functions (`OpenServiceW`, `CloseServiceHandle`) and two
access-right constants (`SERVICE_STOP`, `SERVICE_QUERY_STATUS`). These are platform
implementation details. The domain concept — a temporary, rights-bound reference to a
specific service — is fully expressible without them.

### Clean replacement

**Service Handle**:
A reference to an open service, granting specific access rights to that service and valid
only for the duration of the operation that acquired it. Every service handle must be
released exactly once when the operation completes or fails.
_Avoid_: service reference, service object, handle

---

## Entry 2 — Service State

### Contaminated text (current GLOSSARY.md, verbatim)

> One of seven values returned by `QueryServiceStatus` / `QueryServiceStatusEx`:
> `STOPPED` (1), `START_PENDING` (2), `STOP_PENDING` (3), `RUNNING` (4),
> `CONTINUE_PENDING` (5), `PAUSE_PENDING` (6), `PAUSED` (7).

### Why it is contaminated

The entry names two Win32 API functions (`QueryServiceStatus`, `QueryServiceStatusEx`)
and annotates each state with its integer code (1–7). The API function names are
implementation details. The integer encodings are Windows platform constants; they are
already documented in `docs/research/windows-scm-api.md` and are not project-specific
domain vocabulary. The seven named states themselves are domain vocabulary.

### Clean replacement

**Service State**:
The current phase of a service's lifecycle as reported by the SCM. A service is always
in exactly one of seven states: `STOPPED`, `START_PENDING`, `STOP_PENDING`, `RUNNING`,
`CONTINUE_PENDING`, `PAUSE_PENDING`, or `PAUSED`.
_Avoid_: service status, service phase

---

## Entry 3 — Batch Stop

### Contaminated text (current GLOSSARY.md, verbatim)

> A single call to `_SM_StopServicesBatch()` that opens SCM once, issues stop controls
> to all eligible services without serial waiting, then polls all pending services against
> one shared deadline, and returns one result row per input service.

### Why it is contaminated

The entry names the internal function `_SM_StopServicesBatch()` directly and describes
its three algorithmic phases (open SCM, issue stops without serial waiting, poll pending
services). Function names and algorithm steps are implementation details. The domain
concept is a coordinated, deadline-bounded stop operation applied to a group of services
treated as a unit.

### Clean replacement

**Batch Stop**:
A coordinated stop operation applied to multiple services under a single shared deadline,
treating the group as a unit. Each service in the batch receives an independent outcome,
but all outcomes are measured against the same deadline.
_Avoid_: bulk stop, mass stop, group stop

---

## Entry 4 — Priority Watchdog

### Contaminated text (current GLOSSARY.md, verbatim)

> The `AdlibRegister`-driven mechanism (`_PriorityWatchdog`) that fires every 10 seconds,
> checks the current priority of each watched PID via `GetPriorityClass`, and restores it
> if drift is detected. Uses three parallel global arrays: `$aPriorityWatchPIDs`,
> `$aPriorityWatchTargets`, `$aPriorityWatchNames`.

### Why it is contaminated

The entry names the AutoIt timer registration function (`AdlibRegister`), the internal
callback function (`_PriorityWatchdog`), the Win32 API function (`GetPriorityClass`),
the polling interval (10 seconds), and three specific global array variables
(`$aPriorityWatchPIDs`, `$aPriorityWatchTargets`, `$aPriorityWatchNames`). All of these
are implementation mechanics. The domain concept is a background monitor that detects
unauthorized priority changes on watched processes and corrects them automatically.

### Clean replacement

**Priority Watchdog**:
A background monitor that periodically checks whether each watched process's current
priority class still matches the target priority class set when it was added to the
Watchlist, and restores the target if drift is detected.
_Avoid_: priority monitor, priority keeper, priority restorer

---

## Entry 5 — Priority Class (split into two entries)

### Contaminated text (current GLOSSARY.md, verbatim)

> A Windows API constant returned by `GetPriorityClass` (kernel32.dll): `IDLE_PRIORITY_CLASS`
> (0x40), `BELOW_NORMAL_PRIORITY_CLASS` (0x4000), `NORMAL_PRIORITY_CLASS` (0x20),
> `ABOVE_NORMAL_PRIORITY_CLASS` (0x8000), `HIGH_PRIORITY_CLASS` (0x80),
> `REALTIME_PRIORITY_CLASS` (0x100). These differ from AutoIt's `ProcessSetPriority`
> constants (0–5) — always convert via `_WinAPIPriorityClassToAutoItConst()`.

### Why it is contaminated

The entry lists all six hex constants (0x40, 0x4000, 0x20, 0x8000, 0x80, 0x100),
names the Win32 API function (`GetPriorityClass`), names the DLL (`kernel32.dll`),
names the AutoIt built-in function (`ProcessSetPriority`), and names the project
conversion function (`_WinAPIPriorityClassToAutoItConst()`). All of these are
implementation details already documented in `CLAUDE.md` and `docs/ARCHITECTURE.md`.

Additionally, the single entry conflates two distinct concepts: the Windows OS scheduling
tier (a platform concept) and the AutoIt integer constant used to set priority (an
AutoIt-layer concept). These must be separated.

### Clean replacement — two entries

**Priority Class**:
The scheduling tier assigned to a process by the Windows operating system, expressed on a
six-level scale from Idle (lowest) to Realtime (highest). The operating system uses this
tier to allocate CPU time relative to other processes.
_Avoid_: priority level, process priority, priority value

**AutoIt Priority Constant**:
An integer from 0 to 5 used by AutoIt's process-priority functions to identify a priority
tier, where 0 is the lowest (Idle) and 5 is the highest (Realtime). Distinct from a
Priority Class value and not interchangeable with it without conversion.
_Avoid_: AutoIt priority, priority integer, priority number

---

## Entry 6 — Process Inventory (stale variable reference)

### Conflicting text (current GLOSSARY.md, verbatim)

> The array(s) of process executable names (`$sProcesses[]`, `$sProcesses2[]`) that
> `_CloseInstaller()` terminates every ~2 seconds when the monitoring loop is active.

### Why it is incorrect

`$sProcesses2[]` does not exist in the current codebase. Per DM-10 Section 2a, it was
present in a historical version documented in `docs/BASELINE-INVENTORY.md` but is absent
from the current `main` branch. The current script declares only `$sProcesses[18]`.
Referencing a non-existent variable presents a false picture of the domain.

Additionally, naming the internal function `_CloseInstaller()` is an implementation
detail. The domain concept is the set of process names the script targets for termination
during active monitoring.

### Corrected replacement

**Process Inventory**:
The list of process executable names that the script terminates on each process-kill
cycle while the Monitoring Loop is active. Currently declared as a single array
(`$sProcesses[18]`).
_Avoid_: process list, kill list, process array

---

## Summary of changes

| Entry | Action | Key detail removed |
|---|---|---|
| Service Handle | Rewritten | `OpenServiceW`, `CloseServiceHandle`, `SERVICE_STOP`, `SERVICE_QUERY_STATUS` |
| Service State | Rewritten | `QueryServiceStatus`, `QueryServiceStatusEx`, numeric codes 1–7 |
| Batch Stop | Rewritten | `_SM_StopServicesBatch()`, three-phase algorithm description |
| Priority Watchdog | Rewritten | `AdlibRegister`, `_PriorityWatchdog`, `GetPriorityClass`, 10-second interval, three global arrays |
| Priority Class | Split into two entries | Hex constants, `GetPriorityClass`, `kernel32.dll`, `ProcessSetPriority`, `_WinAPIPriorityClassToAutoItConst()` |
| Process Inventory | Corrected | Removed `$sProcesses2[]` (non-existent); removed `_CloseInstaller()` function name |
