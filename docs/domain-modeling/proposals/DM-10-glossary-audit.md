# DM-10 — GLOSSARY.md Completeness and Consistency Audit

**Date**: 2026-11-12
**Scope**: Full audit of `GLOSSARY.md` against `Stop Services Processes.au3`,
`Includes/ServiceManager.au3`, `Includes/ServiceControl.au3`,
`docs/ARCHITECTURE.md`, and `docs/REQUIREMENTS.md`.
**Output type**: Proposal only — do NOT modify `GLOSSARY.md` directly until this proposal is accepted.

---

## Summary

The current `GLOSSARY.md` has 8 entries. The audit identified:

- **10 missing terms** found in code and docs that belong in the glossary
- **3 conflicting terms** where the glossary definition diverges from actual code behavior
- **2 overloaded terms** where one word carries two distinct meanings
- **5 implementation-contaminated entries** that contain details belonging in code comments or architecture docs, not a glossary

---

## 1. Missing Terms

These are domain concepts that appear consistently across source files and docs but have no glossary entry. Each proposed definition follows the GLOSSARY-FORMAT.md rules: one or two sentences defining what the concept *is*, not how it is implemented.

---

**Monitoring Loop**
The active state the script enters when toggled on, during which it repeatedly checks the process inventory and service inventory on their respective intervals.
_Avoid_: active loop, running state, script running

---

**Toggle**
The user action (Shift+F1) that transitions the script between its idle state and its Monitoring Loop state.
_Avoid_: start, enable, activate

---

**Outcome Code**
One of five string values (`STOPPED`, `ALREADY_STOPPED`, `UNAVAILABLE`, `FAILED`, `TIMED_OUT`) that classifies the result of a single service-stop attempt within a Batch Stop.
_Avoid_: result code, status code, outcome string

---

**Pending List**
The set of services within a single Batch Stop that have had a stop control issued (or were already in STOP_PENDING state) and are waiting for their Service State to reach STOPPED before the shared deadline expires.
_Avoid_: pending services, in-progress list

---

**Watchlist**
The set of PIDs that the Priority Watchdog is currently monitoring for priority drift. A PID is added to the watchlist via the Lock Priority hotkey and removed when the process exits or the watchlist becomes empty.
_Avoid_: watchdog list, PID list, monitored processes

---

**Priority Drift**
The condition where a watched PID's current Windows priority class no longer matches the target priority class set when the PID was added to the Watchlist. When drift is detected, the Priority Watchdog restores the target priority.
_Avoid_: priority change, priority mismatch

---

**Log Level**
A numeric threshold (0 = Error, 1 = Info, 2 = Verbose) that controls which log messages are written. A message is written only when its level is less than or equal to the current log level setting.
_Avoid_: verbosity, log severity

---

**Log Rotation**
The act of deleting the log file when it is older than the configured maximum age, which causes a fresh file to be created on the next log write.
_Avoid_: log cleanup, log pruning

---

**Tray Notification**
A small tooltip displayed at the bottom-right of the desktop to report watchdog events to the user. Distinct from a Windows toast notification, which the script deliberately avoids.
_Avoid_: tray tip, tray alert, toast notification

---

**Misc Popup**
An application registration dialog from a third-party program (e.g., AdvancedRenamer, Sublime Text) that the script closes automatically during the Monitoring Loop.
_Avoid_: popup, dialog, window

---

## 2. Conflicting Terms

These are terms already in `GLOSSARY.md` whose definitions diverge from how they are actually used in the current code.

---

### 2a. Process Inventory

**Glossary says:**
> "The array(s) of process executable names (`$sProcesses[]`, `$sProcesses2[]`) that `_CloseInstaller()` terminates every ~2 seconds when the monitoring loop is active."

**Code says:**
`$sProcesses2[]` does not exist in the current codebase. It was present in a historical zip version documented in `docs/BASELINE-INVENTORY.md` but is absent from the current `main` branch. The current script declares only `$sProcesses[18]`. Referencing `$sProcesses2[]` in the glossary defines a concept that no longer exists in the code.

**Proposed resolution:** Remove the reference to `$sProcesses2[]`. The definition should refer only to the single array of process names.

---

### 2b. Timing Constants

**Glossary says (last two entries):**
> `$PRIORITY_WATCHDOG_INTERVAL_MS = 10000` and `$SVC_POLL_MS = 500`

**Code says:**
In `Stop Services Processes.au3`, the actual constant names are `$PRIORITY_WATCHDOG_MS` and `$SVC_BATCH_POLL_MS`. The glossary uses different identifiers: `$PRIORITY_WATCHDOG_INTERVAL_MS` and `$SVC_POLL_MS`. Neither of those names appears anywhere in the current source.

Additionally, the glossary omits `$SVC_BATCH_TIMEOUT_MS` (20000 ms) entirely, which is the most consequential timing value in the new batch-stop design.

**Proposed resolution:** Correct the constant names to match the code. Remove the specific variable names from the glossary entirely — they are implementation details. The glossary entry should define what the *concept* of a timing constant is in this project, not enumerate the variable names and values.

---

### 2c. Batch Stop

**Glossary says:**
> "A single call to `_SM_StopServicesBatch()` that opens SCM once, issues stop controls to all eligible services without serial waiting, then polls all pending services against one shared deadline, and returns one result row per input service."

**Code says:**
This is mechanically accurate for `ServiceManager.au3`. However, the entry reads as a function spec rather than a domain concept definition. The core domain meaning — that a batch treats a group of services as a unit under one shared deadline — is buried under procedural detail.

More importantly, the glossary entry directly names `_SM_StopServicesBatch()`, a specific function identifier. Per SKILL.md and GLOSSARY-FORMAT.md, function names and implementation mechanics do not belong in the glossary.

**Proposed resolution:** Rewrite to define the concept, not the implementation. Example:
> "A single operation that attempts to stop a group of services as a unit, issuing all stop controls without serial waiting and measuring the outcome of each service against one shared deadline."

---

## 3. Overloaded Terms

These are cases where a single word is used in the codebase to mean two distinct things, which will cause confusion if the glossary does not distinguish them.

---

### 3a. "Service Handle" vs "SCM Handle"

The glossary defines **Service Handle** as the opaque value returned by `OpenServiceW`. However, `OpenSCManagerW` also returns a handle — the SCM handle (`$hSCM`) — which is a different kind of object with different access rights, a different lifetime, and different close semantics. Both appear throughout `ServiceManager.au3` and `ServiceControl.au3`.

The glossary entry for "Service Handle" implicitly covers only `OpenServiceW` handles, but a reader encountering `$hSCM` in the code has no glossary term to anchor it.

**Proposed resolution:** Add a distinct **SCM Handle** term for the handle returned by `OpenSCManagerW`, and tighten the Service Handle definition to make clear it refers specifically to the per-service handle from `OpenServiceW`.

---

### 3b. "Service State" (the concept) vs "Service State" (the integer value)

The glossary entry for **Service State** is written as a list of integer constants with their Windows API names and numeric values. In the codebase, "service state" is used both as a concept (the lifecycle stage a service is in) and as a raw integer field read from a `SERVICE_STATUS` struct.

This conflation makes the glossary entry read like a lookup table from `advapi32.dll` documentation rather than a definition of a domain concept. The seven enumerated values are Windows platform facts, not project-specific domain knowledge.

**Proposed resolution:** Define Service State as the lifecycle position of a Windows service, and name the seven values without enumerating their numeric codes. The numeric codes belong in code comments and research docs (they are already in `docs/research/windows-scm-api.md`), not the glossary.

---

## 4. Implementation Contamination

These entries contain implementation details — specific variable names, API names, numeric values, function call syntax — that belong in code comments, architecture docs, or the CLAUDE.md spec, not in a domain glossary.

---

### 4a. Service Handle — DLL API name

The entry mentions `OpenServiceW` and `CloseServiceHandle` by name and uses Windows API terminology (`dwDesiredAccess`). These are implementation facts. The domain concept is simply: an acquired capability to interact with a specific service, which must be released when no longer needed.

---

### 4b. Service State — numeric codes

The entry lists all seven states with their integer values: `STOPPED (1)`, `START_PENDING (2)`, etc. The numeric values are Windows API constants, not domain vocabulary. The named states themselves (STOPPED, RUNNING, PAUSED, etc.) are domain vocabulary; their integers are not.

---

### 4c. Batch Stop — function name and algorithm

As noted in Section 2c, the entry names `_SM_StopServicesBatch()` and describes its internal phases. Function names and algorithm steps are implementation details.

---

### 4d. Priority Watchdog — implementation mechanics

The entry names `AdlibRegister`, the specific interval (`10 seconds`), the three parallel global arrays (`$aPriorityWatchPIDs`, `$aPriorityWatchTargets`, `$aPriorityWatchNames`), and the callback function name (`_PriorityWatchdog`). All of these are implementation details. The domain concept — a background checker that detects and corrects unauthorized priority changes on watched processes — can be stated without any of them.

---

### 4e. Priority Class — numeric hex constants and AutoIt conversion note

The entry lists Windows API hex values (`0x40`, `0x4000`, etc.) and references `ProcessSetPriority` and `_WinAPIPriorityClassToAutoItConst()`. These are implementation details of the priority-reading and -setting mechanism. They are well-documented in CLAUDE.md and `docs/ARCHITECTURE.md`. The domain concept is simply: the scheduling tier assigned to a process by the operating system, expressed on a six-level scale.

The note "These differ from AutoIt's `ProcessSetPriority` constants (0–5) — always convert via `_WinAPIPriorityClassToAutoItConst()`" is valuable knowledge, but it belongs in CLAUDE.md (where it already lives), not the glossary.

---

## 5. Terms Correctly in the Glossary

The following entries are well-formed and do not require changes (beyond the targeted fixes identified above):

- **Service Control Manager (SCM)** — correctly names the Windows concept without over-specifying implementation. The API name (`OpenSCManagerW`, `advapi32.dll`) could be pruned but is borderline acceptable as it identifies the specific platform component.
- **Result Row** — correctly defines the data structure concept and its shape. The specific array syntax is borderline but acceptable since it is the precise shape the entire project uses.
- **Service Inventory** — the canonical list of service names is domain knowledge specific to this project's purpose.

---

## 6. Recommended Priority Order for GLOSSARY.md Updates

If these proposals are accepted, apply changes in this order to minimise churn:

1. **Purge implementation details** from the five contaminated entries (Section 4). This is non-breaking — no term is removed, just cleaned.
2. **Correct the two factual errors** in Process Inventory and Timing Constants (Sections 2a, 2b).
3. **Rewrite Batch Stop** to be concept-only (Section 2c).
4. **Add the SCM Handle term** to resolve the handle overloading (Section 3a).
5. **Add the 10 missing terms** (Section 1) in alphabetical order within the glossary.
6. **Rewrite Service State** to remove numeric codes (Section 3b and 4b).
