# DM-06: Configuration and List Management

Domain-modeling proposal for how service lists, process lists, and configuration
are structured, named, and conceptually distinguished in this codebase.

---

## 1. What exists in the code

### 1a. The process array

```autoit
Global $sProcesses[18] = [ _
    "taskhostw.exe", "TrustedInstaller.exe", "TiWorker.exe", ... ]
```

- Declared as a module-level global at startup.
- Consumed by `_CloseInstaller()` every `$PROC_POLL_INTERVAL_SEC` seconds.
- Fixed size (18 slots), hardcoded at the declaration site.
- Named `$sProcesses` — a generic plural noun with a Hungarian-style `s` prefix
  that conventionally means "string", not "set" or "list".

### 1b. The service array

```autoit
Local $aNames[9] = [ _
    "FDResPub", "fdPHost", "TrustedInstaller", "wuauserv", ... ]
```

- Declared as a **local** inside `_RunServiceBatchStop()`, re-created on every
  call.
- Passed immediately to `_SM_StopServicesBatch($aNames, ...)`.
- Named `$aNames` — a local scratch variable with no stable identity.

### 1c. The popup window matchers

```autoit
If WinExists("[CLASS:TPleaseRegisterForm]") Then ...
ElseIf WinExists("This is an unregistered copy", "") Then ...
```

- Two hardcoded window class/title strings inside `_miscpopups()`.
- No array, no name, no shared concept.

### 1d. The timing constants

```autoit
Global Const $PROC_POLL_INTERVAL_SEC   = 2
Global Const $SVC_POLL_INTERVAL_SEC    = 10
Global Const $MAIN_LOOP_SLEEP_MS       = 500
Global Const $PRIORITY_WATCHDOG_MS     = 10000
Global Const $SVC_BATCH_TIMEOUT_MS     = 20000
Global Const $SVC_BATCH_POLL_MS        = 500
```

- Already named and grouped (covered by the existing "Timing Constants" glossary
  entry). Referenced here only to contrast with the list variables above.

---

## 2. Terminology problems

### 2a. "Service list" vs "process list" — unnamed as concepts

The codebase operates on two structurally identical things: a set of Windows
service names to stop, and a set of process executable names to terminate. Both
are flat arrays of strings, both are iterated every cycle, both represent the
same relationship to the domain — "these are the targets the script acts on."

Neither has a canonical name in the glossary. The code uses `$sProcesses` and
`$aNames` — variable names that describe their AutoIt type, not their domain
role.

**Proposed terms:**

- **Process Target List**: the fixed set of process executable names
  (`$sProcesses[]`) that `_CloseInstaller()` attempts to terminate each cycle.
  _Avoid_: process inventory (already in GLOSSARY.md but describes the whole
  concept — see note in section 4), process array, `$sProcesses`.

- **Service Target List**: the fixed set of Windows service names
  (`$aNames[]`) that `_RunServiceBatchStop()` passes to `_SM_StopServicesBatch`
  each cycle.
  _Avoid_: service inventory (same note), service array, `$aNames`.

### 2b. "Targets" vs "exclusions" — only one side is present

The codebase has no exclusion or whitelist concept. Every name in both arrays is
unconditionally acted on. There is no filtering step, no "skip if matching X",
no suppression list.

The word "whitelist" does not appear in the code and would be a false concept if
introduced. The only relevant axis is: **what is on the target list**.

**Proposed term:**

- **Target**: any service name or process name that appears in the respective
  target list and is therefore acted on each cycle. Contrast with the implicit
  complement — processes/services not on the list — which the script ignores
  entirely and for which no domain term is needed.

### 2c. "Whitelist" — should not be introduced

There is no whitelisting mechanism. If the concept were added in the future (e.g.,
"never kill process X even if it appears"), that would warrant a new term.
For now, coining "whitelist" or "exclusion list" would describe something the
code does not do.

### 2d. "AutoClose" — does not exist by this name

The word "AutoClose" does not appear in the codebase as a variable, constant,
function name, or concept. The behavior it might describe — periodically closing
processes — is what `_CloseInstaller()` does, governed by `$PROC_POLL_INTERVAL_SEC`.
If the user community uses "AutoClose" informally, the canonical term for the
mechanism is the **monitoring loop** (the `While $bScriptRunning` block inside
`ToggleScript`).

---

## 3. Is "configuration" a first-class concept?

No. Configuration in this codebase is split across two very different forms:

**Form 1 — Named constants (genuine configuration):**
The timing constants (`$PROC_POLL_INTERVAL_SEC`, etc.) are declared with
`Global Const` in a dedicated `#Region ;Timing constants` block with a comment
calling them "Single definition point for all interval values." They behave as
configuration: one place to change, effect felt everywhere.

**Form 2 — Hardcoded lists (not configuration):**
Both target lists are hardcoded directly in the body of their consuming
functions. `$sProcesses` is a global with inline initialization; `$aNames` is a
local that is re-declared on every call. Neither is in the timing constants
region; neither is documented as a "single definition point."

This is a meaningful structural asymmetry. The timing constants are treated as
configuration; the target lists are treated as code. A future maintainer wanting
to add or remove a target must edit a function body, not a configuration block.

**Proposed term:**

- **Configuration**: the set of named constants (currently the timing constants
  plus `$iLogLevel`, `$bLogToConsole`, `$iLogMaxAgeDays`) that have a single
  declared location and are consumed by the rest of the script without
  redeclaration. The target lists are not configuration under this definition
  — they are hardcoded data.

---

## 4. Relationship to existing GLOSSARY.md entries

Two glossary entries already use the word "inventory":

- **Process Inventory**: "The array(s) of process executable names (`$sProcesses[]`,
  `$sProcesses2[]`) that `_CloseInstaller()` terminates every ~2 seconds..."
- **Service Inventory**: "The list of Windows service names that
  `_SM_StopServicesBatch()` attempts to stop each cycle..."

These entries are accurate but carry implementation detail (`$sProcesses[]`,
`$sProcesses2[]`, the specific service names). The proposed "Process Target List"
and "Service Target List" terms are intended as the precise canonical domain names
for the same concepts, with the following relationship:

- "Target List" is the domain term (what it IS: the declared set of targets).
- "Inventory" in the current glossary reads more like a description of the
  implementation artifact.

A future GLOSSARY.md update should consider whether "Process Inventory" and
"Service Inventory" should be renamed to "Process Target List" and "Service
Target List", or whether the existing terms should be kept and the new terms
introduced as aliases. That choice is out of scope for this proposal.

---

## 5. Summary of proposed terms

| Proposed Term | Definition | Avoid |
|---|---|---|
| Process Target List | The fixed set of process executable names the script attempts to terminate each monitoring cycle. | process inventory, process array, `$sProcesses` |
| Service Target List | The fixed set of Windows service names the script attempts to stop each monitoring cycle. | service inventory, service array, `$aNames` |
| Target | Any process name or service name that appears in the respective target list and is therefore acted on unconditionally each cycle. | target entry, whitelist candidate |
| Configuration | Named constants with a single declared location consumed by the rest of the script. The target lists are not configuration. | settings, options |

Terms deliberately not introduced: "whitelist", "exclusion list", "AutoClose"
(no corresponding concept in the code).

---

## 6. Open questions for the maintainer

1. Should `$aNames` (the service target list) be promoted to a module-level
   global alongside `$sProcesses`, so both target lists live in the same region
   and are edited in the same place? This is an implementation question, not a
   domain question, but the domain observation is what surfaces it.

2. Should the target lists be moved into the `#Region ;Timing constants` block
   (or a new `#Region ;Configuration` block) to make them first-class
   configuration alongside the timing constants?

3. `$sProcesses2[]` is referenced in the current GLOSSARY.md "Process Inventory"
   entry but does not appear in the current `Stop Services Processes.au3`. Is it
   present in a backup version only, or is it a planned future addition?
