# Domain Modeling Proposals Index

This file tracks all ten domain modeling proposals produced for the
Win10-Stop-Services-Processes project. For each proposal it records what was found,
what was done with the findings, and what (if anything) is still pending.

Status values:
- **Incorporated** — all significant glossary terms and ADR candidates from this proposal
  have been acted on (terms appear in `GLOSSARY.md`; ADRs appear in `docs/adr/`).
- **Partially Incorporated** — some terms or ADRs from the proposal were acted on; others
  were not.
- **Proposed** — no action has been taken.

---

## DM-01: Service Lifecycle

**Focus:** Windows service lifecycle concepts — service states, state transitions, SCM
operations, control codes, and the gap between issuing a stop control and reaching
`STOPPED`.

**Status:** Incorporated

**Key findings:**
- `GLOSSARY.md` had no distinction between stable states (`RUNNING`, `STOPPED`, `PAUSED`)
  and transient states (`*_PENDING`), leaving the polling and eligibility logic without
  vocabulary.
- SCM Handle and Service Handle were conflated under a single entry; they are different
  domain objects with different lifetimes and access rights.
- Service Name and Display Name were absent, even though all SCM API calls use Service
  Names exclusively.
- The concept of Stop-Eligible State — the routing rule at the heart of Phase 1 — had
  no name.
- A semantic split existed between `ServiceControl.au3`'s INTERROGATE-based "running"
  check and `ServiceManager.au3`'s `QueryServiceStatus`-based state read.

**Recommendations acted on:**
- Added to `GLOSSARY.md`: SCM Handle, Service Handle (revised), Service Name, Display
  Name, Stable Service State, Transient Service State, Stop-Eligible State, Control Code,
  Stop Control, Pending Service, Stop Outcome, Batch Stop (revised), Result Row (revised).
- ADR `0002-start-pending-stop-ineligible.md` written: `START_PENDING` treated as
  stop-ineligible, outcome `FAILED` with Win32 error 1061.
- `Service State` definition cleaned of API names and rewritten around concept-first
  language.

**Still pending:**
- Clarifying note in `Service State` about `_ServiceRunning()` (INTERROGATE-based) being
  a legacy path not used by the batch-stop route — the glossary entry describes the
  canonical path but does not call out the legacy divergence.

**Related proposals:** [DM-03](#dm-03-stopterminatekillclose-semantics) (stop vs. kill
distinction), [DM-04](#dm-04-servicemanager-api) (handle lifecycle detail),
[DM-09](#dm-09-windows-scm-api-domain-mapping) (API name cleanup in glossary entries)

---

## DM-02: Process Management

**Focus:** Process vs. Service distinction, PID lifecycle, the two incompatible priority
numbering schemes, Priority Watchdog, and the absence of an "AutoClose" concept.

**Status:** Incorporated

**Key findings:**
- "Process" was used for both running executables (kernel32-managed) and services
  (SCM-managed); `TrustedInstaller` straddles both, and nothing in the glossary explained
  the difference.
- PID lifetime semantics (a PID is only valid while the process is alive; must re-validate
  before use) were undocumented.
- Priority Class split: Windows API returns hex constants; AutoIt `ProcessSetPriority`
  takes integers 0–5; the two schemes are incompatible and require an explicit conversion
  function.
- Priority Drift (the trigger condition for the watchdog) was used in log messages but
  undefined.
- "AutoClose" does not exist in the codebase; the correct term is Process Kill.

**Recommendations acted on:**
- Added to `GLOSSARY.md`: Process, PID (Process ID), Process Kill, Priority Class
  (revised), AutoIt Priority Constant (new), Priority Drift, Priority Watchdog (revised),
  Watchlist, Service (contrast term for Process), Process Inventory (sharpened with
  TrustedInstaller disambiguation note).
- ADR `0007-autoit-priority-constants-canonical.md` written: AutoIt integers (0–5) as
  the canonical internal form; convert-on-read from Windows API hex.

**Still pending:**
- None. All significant terms and the ADR candidate were acted on.

**Related proposals:** [DM-03](#dm-03-stopterminatekillclose-semantics) (kill vs. stop
semantics), [DM-06](#dm-06-configuration-and-list-management) (Process Target List /
Service Target List naming question)

---

## DM-03: Stop/Terminate/Kill/Close Semantics

**Focus:** Disambiguating the four overloaded words — "stop", "kill", "terminate",
"close" — and establishing which operations are graceful vs. unconditional.

**Status:** Incorporated

**Key findings:**
- "Stop" in the service context is always cooperative (SCM control sent; service
  handles shutdown asynchronously); there is no force-kill path for services.
- "Kill"/"terminate" for processes means `ProcessClose` → Windows `TerminateProcess`;
  unconditional, no cleanup opportunity.
- "Close" is overloaded: `_CloseInstaller` (misleading historical name; actually kills)
  vs. `WinClose` in `_miscpopups` (genuine `WM_CLOSE` cooperative close).
- `TIMED_OUT` is a terminal outcome, not a prelude to force-kill; the monitoring loop
  retries on the next cycle.

**Recommendations acted on:**
- Added to `GLOSSARY.md`: Stop Control (the cooperative dispatch act, distinct from
  reaching STOPPED), Process Kill (the unconditional termination), Batch Stop revised to
  include "All stop operations are cooperative (graceful); there is no force-kill
  fallback".
- ADR `0005-graceful-only-service-stop.md` written: graceful-only stop; no
  `TerminateProcess` fallback; TIMED_OUT services are retried next cycle.

**Still pending:**
- `_CloseInstaller` naming inconsistency noted but not proposed for rename (cosmetic
  refactor out of scope). No glossary action required.
- `WinClose` in `_miscpopups` deliberately not given a glossary term (too narrow and
  application-specific); remains undocumented at glossary level.

**Related proposals:** [DM-01](#dm-01-service-lifecycle) (stop control / stop outcome
vocabulary), [DM-02](#dm-02-process-management) (process kill term),
[DM-04](#dm-04-servicemanager-api) (graceful-only decision in context of API contract)

---

## DM-04: ServiceManager API

**Focus:** The public contract of `_SM_StopServicesBatch` — parameters, return shape,
`@error` convention, and how it differs from `ServiceControl.au3`'s scalar convention.

**Status:** Incorporated

**Key findings:**
- SCM Handle and Service Handle are both `SC_HANDLE` values but serve entirely different
  roles; glossary did not distinguish them.
- Two-level error reporting (`@error 1` for batch-level SCM failure; outcome strings in
  rows for per-service results) is non-obvious and leads callers to misread `@error 0` as
  "all stopped".
- `ServiceControl.au3` and `ServiceManager.au3` use incompatible error conventions; a
  developer familiar with one will misread the other.
- Result Row column 5 (`$sNote`) was unnamed; its content in `START_PENDING` and
  `TIMED_OUT` cases carries substantive information.
- Batch Stop definition in glossary did not make explicit that the deadline is shared
  across all services (not per-service).

**Recommendations acted on:**
- Added to `GLOSSARY.md`: SCM Handle (standalone term), Service Handle (tightened,
  explicitly contrasted with SCM Handle), Service Name, Display Name, Result Row (revised
  to name column 5 explicitly), Batch Stop (revised to call out shared deadline).
- ADR `0003-batch-stop-two-level-error-convention.md` written.
- ADR `0004-servicemanager-incompatible-with-servicecontrol-error-convention.md` written.

**Still pending:**
- None. All significant terms and both ADR candidates were acted on.

**Related proposals:** [DM-01](#dm-01-service-lifecycle) (handle types),
[DM-03](#dm-03-stopterminatekillclose-semantics) (graceful-only decision),
[DM-09](#dm-09-windows-scm-api-domain-mapping) (API name cleanup in handle definitions)

---

## DM-05: Test Vocabulary

**Focus:** Test harness structure, test classification (unit vs. integration vs.
deterministic), stub vs. mock vs. fake distinctions in an AutoIt hand-rolled framework.

**Status:** Incorporated

**Key findings:**
- The harness uses no third-party runner; vocabulary from Jest/Jasmine/pytest does not
  apply and must not be imported into the glossary.
- Stub is correct (fixed return value, no call verification); mock is explicitly not
  present; fake is explicitly not present.
- One test (`_Test_EmptyInput`) opens a live SCM handle — it is an integration test, not
  a unit test, even though the harness presents it without that label.
- Environment Gate captures the Windows-only constraint on the harness.

**Recommendations acted on:**
- Added to `GLOSSARY.md` (Testing section): Test Harness, Test Case, Test Function,
  Test Suite, Stub, Deterministic Test, Unit Test, Integration Test, Environment Gate.
- Open questions about "Stub vs. helper" and "Deterministic vs. unit test" naming
  preference were resolved in favour of "Stub" and "Deterministic Test" respectively,
  as reflected in the glossary entries.

**Still pending:**
- "Assertion" was proposed as a standalone glossary term in DM-05 but does not appear
  in `GLOSSARY.md` as an independent entry. It is referenced only in the _Avoid_ note
  for Test Case. If a future contributor asks what an assertion is, there is no entry.
- Exit Code Convention (harness exits 0/1) was noted as CI-relevant but was not added
  to the glossary (correctly excluded as an implementation detail).

**Related proposals:** [DM-04](#dm-04-servicemanager-api) (the module the tests cover),
[DM-10](#dm-10-glossary-audit) (overall glossary completeness)

---

## DM-06: Configuration and List Management

**Focus:** How service lists, process lists, and timing constants are structured and
whether they warrant distinct domain vocabulary ("Process Target List", "Service Target
List", "Target", "Configuration").

**Status:** Partially Incorporated

**Key findings:**
- Process list (`$sProcesses[]`) and service list (`$aNames[]`) have no canonical domain
  names; the glossary used "inventory" loosely.
- The two lists are structurally asymmetric: `$sProcesses` is a module-level global;
  `$aNames` is a local re-created on every call — a structural gap noted for the
  maintainer.
- "Whitelist" and "AutoClose" do not exist in the codebase and must not be coined.
- Timing constants are genuine configuration (single declared location, consumed
  globally); target lists are not (hardcoded inside function bodies).
- `$sProcesses2[]` referenced in the existing glossary does not exist in current code.

**Recommendations acted on:**
- `GLOSSARY.md` Process Inventory entry sharpened: removed the stale `$sProcesses2[]`
  reference; added the TrustedInstaller disambiguation note (see DM-02).
- Timing Constants entry corrected: variable names removed from definition text; concept
  described without enumerating specific identifiers.

**Still pending:**
- "Process Target List", "Service Target List", "Target", and "Configuration" as explicit
  glossary terms were proposed but not added. The current glossary retains "Process
  Inventory" and "Service Inventory" as the canonical terms.
- The structural asymmetry between `$sProcesses` (global) and `$aNames` (local) was
  noted for the maintainer but not resolved.
- Whether `$aNames` should be promoted to a module-level global is an open implementation
  question.

**Related proposals:** [DM-02](#dm-02-process-management) (Process Inventory sharpening),
[DM-10](#dm-10-glossary-audit) (Timing Constants correction, `$sProcesses2[]` removal)

---

## DM-07: Logging and Audit Trail

**Focus:** Log levels, log types, the distinction between diagnostic entries and audit
(suppression) events, log file structure, and the "closure log" naming tension.

**Status:** Incorporated

**Key findings:**
- Log level values (0/1/2) exist only as inline integer literals throughout the code;
  no named constants; the mapping lives only in `CLAUDE.md`.
- Log type strings (`"System"`, `"Process"`, etc.) are bare string literals with no
  `Global Const` declarations; a typo would silently produce an unrecognized tag.
- Not all log entries are equal: Info entries are semantically significant (a suppression
  action completed); Verbose entries are expected-negative noise.
- The filename `closure_log.txt` predates multi-subsystem use and understates scope;
  the domain term should be "Log File", not "closure log".
- The repo-tracked sample log uses a pre-refactor format; it is stale as a canonical
  reference.

**Recommendations acted on:**
- Added to `GLOSSARY.md` (Logging section): Log Level, Log Type, Log Entry, Log File,
  Log Rotation, Suppression Event.
- "Closure log" explicitly excluded from glossary; "Log File" is the canonical term.
- Named constants for log levels (`$LOG_LEVEL_ERROR`, `$LOG_LEVEL_INFO`,
  `$LOG_LEVEL_VERBOSE`) added to `Includes/ServiceManager.au3` (T1-07) and to
  `Stop Services Processes.au3` (T1-11).
- Named constants for log type strings (`$LOG_TYPE_SYSTEM`, `$LOG_TYPE_PROCESS`,
  `$LOG_TYPE_SERVICE`, `$LOG_TYPE_PROCESS_PRIORITY`, `$LOG_TYPE_PRIORITY_WATCHDOG`)
  added to `Includes/ServiceManager.au3` (T1-07) and to `Stop Services Processes.au3`
  (T1-11).

**Still pending:**
- Sample log at `Log File/closure_log.txt` remains stale (pre-refactor format); no
  update was made to that file.

**Related proposals:** [DM-10](#dm-10-glossary-audit) (overall completeness; Log Level
and Log Rotation appear in DM-10's missing-terms list as well)

---

## DM-08: Architecture Pattern Vocabulary

**Focus:** Precise architectural language for ServiceManager.au3 (deep module vs.
library vs. wrapper vs. adapter), where the seam is, what "migration" means, and whether
`#include` is an architectural term.

**Status:** Incorporated

**Key findings:**
- `ServiceManager.au3` is a deep module (large behaviour, single public entry point); it
  is not a library, wrapper, or adapter.
- `ServiceControl.au3` is a library (multiple independent, loosely related entry points;
  relatively shallow interface).
- The seam sits between the monitoring loop and `_SM_StopServicesBatch`; it did not move
  during the extraction — only the depth behind it increased.
- `#include` is an AutoIt preprocessor mechanism, not an architectural concept; must not
  be used as an architectural term.
- "Migration" understates what happened: it was a module extraction with interface
  redesign, not a mechanical lift-and-shift.

**Recommendations acted on:**
- Added to `GLOSSARY.md` (Architecture section): Deep Module, Seam, Module Extraction.
- ADR `0001-servicemanager-module-extraction.md` written: documents the extraction
  decision and why the interface was redesigned rather than preserved.

**Still pending:**
- The boundary between `ServiceControl.au3` (non-stop helpers) and `ServiceManager.au3`
  (stop operations) is "by convention" only — no interface enforces it. This was flagged
  as an open architectural tension. ADR `0011` documenting this boundary convention is
  now being written; once merged it will close this item.

**Related proposals:** [DM-04](#dm-04-servicemanager-api) (the API contract the deep
module exposes), [DM-09](#dm-09-windows-scm-api-domain-mapping) (the lower seam between
ServiceManager and advapi32.dll)

---

## DM-09: Windows SCM API Domain Mapping

**Focus:** Which Win32 API concepts (`OpenSCManagerW`, `OpenServiceW`, `QueryServiceStatus`,
`ControlService`, `DllCall`) are domain-level vocabulary vs. implementation details that
should not appear in `GLOSSARY.md`.

**Status:** Incorporated

**Key findings:**
- All four SCM API function names are implementation details; the domain concepts are
  already captured by existing glossary terms (SCM, Service Handle, Service State, Batch
  Stop). No new terms needed for the functions themselves.
- `DllCall` is a general AutoIt mechanism, not a project-specific concept; must not appear
  in the glossary.
- Three existing entries were contaminated with API names: SCM definition mentioned
  `advapi32.dll` and `OpenSCManagerW`; Service Handle mentioned `OpenServiceW` and
  `CloseServiceHandle`; Service State mentioned `QueryServiceStatus` / `QueryServiceStatusEx`.
- SCM Handle was absent as a distinct term; Service Handle and SCM Handle were treated
  as the same concept.
- Win32 error codes are platform constants; not glossary terms. The classification logic
  is fully expressed through Stop Outcome values.

**Recommendations acted on:**
- `GLOSSARY.md` Service Control Manager (SCM) entry cleaned: API names removed.
- `GLOSSARY.md` Service Handle entry cleaned: API names removed.
- `GLOSSARY.md` Service State entry cleaned: API function names removed; numeric codes
  retained only where they appear in Result Row fields.
- Added to `GLOSSARY.md`: SCM Handle (standalone entry), Stop-Eligible State.
- ADR `0006-batch-scoped-scm-handle.md` written: SCM handle opened once per batch, not
  once per service.
- ADR `0008-direct-dllcall-advapi32.md` written: direct DllCall to advapi32.dll instead
  of AutoIt WinAPI wrappers.
- ADR `0009-queryservicestatus-api-selection.md` written: `QueryServiceStatus` (7-DWORD)
  used instead of `QueryServiceStatusEx` (9-DWORD).

**Still pending:**
- None. All glossary cleanups, new terms, and ADR candidates from this proposal were
  acted on.

**Related proposals:** [DM-01](#dm-01-service-lifecycle) (the terms that replaced the
contaminated definitions), [DM-04](#dm-04-servicemanager-api) (handle lifecycle detail),
[DM-08](#dm-08-architecture-pattern-vocabulary) (the lower seam at advapi32.dll)

---

## DM-10: Glossary Audit

**Focus:** A full completeness and consistency audit of `GLOSSARY.md` against the
codebase — identifying missing terms, conflicting definitions, overloaded terms, and
implementation contamination.

**Status:** Incorporated

**Key findings:**
- 10 missing terms: Monitoring Loop, Toggle, Outcome Code (later named Stop Outcome),
  Pending List, Watchlist, Priority Drift, Log Level, Log Rotation, Tray Notification,
  Misc Popup.
- 3 conflicting terms: Process Inventory (referenced `$sProcesses2[]` which does not
  exist); Timing Constants (wrong variable names `$PRIORITY_WATCHDOG_INTERVAL_MS`,
  `$SVC_POLL_MS`); Batch Stop (read as a function spec; named `_SM_StopServicesBatch`
  directly).
- 2 overloaded terms: "Service Handle" conflated SCM Handle and per-service handle;
  "Service State" conflated concept with Windows integer lookup table.
- 5 implementation-contaminated entries: Service Handle (API names), Service State
  (numeric hex codes), Batch Stop (function name and algorithm), Priority Watchdog
  (AdlibRegister, array names, interval), Priority Class (hex constants, conversion
  function name).
- Recommended priority order: (1) purge contamination, (2) fix factual errors, (3)
  rewrite Batch Stop, (4) add SCM Handle, (5) add 10 missing terms, (6) rewrite Service
  State.

**Recommendations acted on:**
- All 10 missing terms added to `GLOSSARY.md` (some under slightly different names:
  "Stop Outcome" rather than "Outcome Code"; "Pending List" matches exactly).
- `$sProcesses2[]` reference removed from Process Inventory.
- Timing Constants entry rewritten without specific variable names.
- Batch Stop rewritten as a concept-first definition without `_SM_StopServicesBatch` name.
- SCM Handle added as a standalone term.
- Service Handle, Service State, Priority Watchdog, Priority Class all cleaned of
  implementation details.

**Still pending:**
- Service State numeric codes: the current `GLOSSARY.md` entry still retains numeric
  encodings for the state values (e.g. "`STOPPED`, `START_PENDING` ... The numeric
  encoding of each state is preserved verbatim in the Initial State and Final State
  fields"). DM-10 proposed removing the numeric codes entirely; this was partially
  honoured (function names removed, integer enumerations retained as a borderline
  acceptable reference since they appear verbatim in Result Rows).
- Priority Class hex values: the current entry describes "incompatible numbering schemes"
  without naming the hex values, but does not name the specific constants. This is in
  line with DM-10's contamination finding; no further action needed.

**Related proposals:** All nine other proposals feed into this audit.
[DM-01](#dm-01-service-lifecycle) through [DM-09](#dm-09-windows-scm-api-domain-mapping)
each address a subset of the gaps catalogued here.

---

## What's Been Acted On

### GLOSSARY.md additions and revisions

All six sections of the current `GLOSSARY.md` were either added or substantially revised
as a result of these proposals:

| Section | Key additions / revisions |
|---|---|
| Service Lifecycle | SCM Handle, Service, Service Handle (cleaned), Service Name, Display Name, Stable/Transient Service State, Stop-Eligible State, Control Code, Stop Control, Pending Service, Pending List, Batch Stop (concept-first), Stop Outcome, Result Row (column 5 named), Service Inventory (cleaned) |
| Process Management | Process, PID, Process Kill, Process Inventory (sharpened), Priority Class (cleaned), AutoIt Priority Constant (new), Priority Drift, Priority Watchdog (cleaned), Watchlist |
| Script Behaviour | Monitoring Loop, Toggle, Timing Constants (corrected), Tray Notification, Misc Popup |
| Logging | Log Level, Log Type, Log Entry, Log File, Log Rotation, Suppression Event |
| Testing | Test Harness, Test Case, Test Function, Test Suite, Stub, Deterministic Test, Unit Test, Integration Test, Environment Gate |
| Architecture | Deep Module, Seam, Module Extraction |

### ADRs written

Ten ADRs were written, mapping to these proposals:

| ADR | Source proposal(s) |
|---|---|
| `0001-servicemanager-module-extraction.md` | DM-08 |
| `0002-start-pending-stop-ineligible.md` | DM-01 |
| `0003-batch-stop-two-level-error-convention.md` | DM-04 |
| `0004-servicemanager-incompatible-with-servicecontrol-error-convention.md` | DM-04 |
| `0005-graceful-only-service-stop.md` | DM-03 |
| `0006-batch-scoped-scm-handle.md` | DM-09 |
| `0007-autoit-priority-constants-canonical.md` | DM-02 |
| `0008-direct-dllcall-advapi32.md` | DM-09 |
| `0009-queryservicestatus-api-selection.md` | DM-09 |
| `0010-main-loop-sleep-timing.md` | (post-proposal; arose from code review CR-09) |

---

## Still Pending

The following recommendations from proposals were not acted on and remain open:

| Item | Source | Notes |
|---|---|---|
| "Assertion" as a standalone glossary term | DM-05 | Currently only in _Avoid_ note for Test Case; a future reader has no definition entry |
| "Process Target List", "Service Target List", "Target", "Configuration" as explicit glossary terms | DM-06 | "Process Inventory" / "Service Inventory" retained; these proposed alternative names were not added |
| `$aNames` promoted to module-level global | DM-06 | Implementation question deferred to maintainer |
| Sample log at `Log File/closure_log.txt` updated to current format | DM-07 | Still shows pre-refactor format |
| ADR for ServiceControl / ServiceManager boundary-by-convention | DM-08 | ADR 0011 now being written; will document the convention once merged |
| Clarifying note in `Service State` about `_ServiceRunning()` as a legacy non-canonical path | DM-01 | The entry describes canonical behavior but does not call out the legacy divergence |
| Service State numeric codes fully removed | DM-10 | Proposal said remove all integers; partial: function names removed but integer encodings retained (borderline acceptable; they appear in Result Rows) |
