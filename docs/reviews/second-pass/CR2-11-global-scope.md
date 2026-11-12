# CR2-11 — Global Scope and Variable Lifecycle Audit

**Files audited:**
- `Stop Services Processes.au3` (primary script)
- `Includes/ServiceManager.au3`
- `Includes/ServiceControl.au3`
- `Tests/ServiceManager.Tests.au3`

**Standards sources:** `CODING_STANDARDS.md`, `CLAUDE.md`
**Date:** 2026-11-12
**Reviewer:** Agent (second-pass)
**Prior related review:** CR2-38 (`docs/reviews/second-pass/CR2-38-config-region-audit.md`)

---

## Check 1 — Global declarations at top of files in `#Region` blocks

### `Stop Services Processes.au3`

**Result: PASS with minor exceptions**

All `Global` and `Global Const` declarations appear before the main `While 1` loop and
before any `Func` definitions. The region structure is:

| Region | Lines | Content |
|---|---|---|
| `#Region ;**** Directives ****` | 2–11 | AutoIt3Wrapper compiler directives |
| `#Region ;Includes/Options/Permissions` | 14–30 | `#include` directives, `Opt()` calls |
| `#Region ;hotkeys` | 32–37 | `HotKeySet()` calls only |
| `#Region ;Timing constants` | 39–48 | `Global Const` timing values |
| `#Region ;Configuration — Log constants` | 50–65 | `Global Const` log level/type constants |
| `#Region ;Configuration — AutoIt process priority constants` | 67–78 | `Global Const` priority constants |
| `#Region ;Configuration — Target lists` | 80–87 | `Global $aSvcTargetNames[9]` |
| `#Region ;Variables/Logging` | 89–145 | Mixed runtime globals + log-init code block |

**Minor exceptions (carried forward from CR2-38):**

1. `$sProcesses[18]` is declared at line 96 inside `#Region ;Variables/Logging` rather than
   in a dedicated configuration region. As a user-editable target list it is structurally
   analogous to `$aSvcTargetNames` and should reside in the Configuration target-lists region.
   This is a pre-existing structural issue, not a regression.

2. `Dim $sLogDir`, `Dim $sDateTime`, and `Dim $sLogEntry` appear at lines 126, 132, and 133
   inside the log-initialization block within `#Region ;Variables/Logging` — which is in
   global scope (not inside a function). Using `Dim` in global scope is legal per AU3Check
   conventions, but it is weaker than `Local` (which is not valid at global scope) and
   creates no shadowing risk here. These three `Dim` variables are initialization
   temporaries and are not referenced again after the initialization block. They do not
   need to be in a config region.

### `Includes/ServiceManager.au3`

**Result: PASS**

All `Global Const` declarations are at the top of the file (lines 44–109), before any `Func`
definition. The file has no `#Region` blocks, which is expected for a module-level include
file. All declarations are properly at module scope with no code mixed in between them.

### `Includes/ServiceControl.au3`

**Result: PARTIAL FAIL — missing `Global Const`; no `#Region` blocks; no `#include-once`**

All 51 declarations are `Global` (mutable), never `Global Const`. They appear at the top of
the file before any `Func` definitions — correct placement — but the mutability issue is
flagged separately in Check 2. The file has no `#Region` structure and no `#include-once`
directive (see Check 2 notes).

### `Tests/ServiceManager.Tests.au3`

**Result: PASS (test-file exemption applies)**

All `Global Const` and `Global` declarations (lines 103–118) appear before the first `Func`
definition. No `#Region` structure is required for test files. The `#include` for
`ServiceManager.au3` is deferred to line 500 (after all `Func` definitions), which is an
intentional design to allow functions to be defined before the module under test is included.
This is a recognized AutoIt pattern and does not violate any standard.

---

## Check 2 — `Global Const` vs `Global` classification

### `Stop Services Processes.au3`

**Result: PASS with two observations**

All named constants (timing, log levels, log types, AutoIt priority values, `$PROCESS_IDLE`)
are declared as `Global Const`. All runtime mutable state variables (`$bScriptRunning`,
`$iLastStopServices`, `$iLastStopProcesses`, `$iconfile`, `$iLogMaxAgeDays`, `$sLogFile`,
`$iLogLevel`, `$bLogToConsole`, `$sStringInstaller`, `$taskcloseran`, `$sProcesses[18]`,
`$aSvcTargetNames[9]`, the three watchdog arrays) are declared as `Global`. The
`Global`/`Global Const` split is semantically correct for all of these.

**Observations:**

1. `$sStringInstaller` (line 90) and `$taskcloseran` (line 91) are both declared `Global`
   but neither is referenced anywhere in the script. `$sStringInstaller` is a dead string
   literal; `$taskcloseran` is an unused counter. Both are mutable `Global` declarations
   with no mutation site. These are dead globals, not misclassified as mutable; they should
   be removed rather than changed to `Global Const`. This is a Speculative Generality
   / dead-code smell (Fowler ch.3), not a scope classification error.

2. `$sProcesses[18]` (line 96) is a configuration array that is never reassigned after
   initialization. It could be `Global Const` only if it were a scalar — arrays cannot be
   declared `Global Const` in AutoIt (the `Const` modifier is not valid for array
   initializers in AU3). `Global` is the only legal declaration form here, so the current
   declaration is correct.

### `Includes/ServiceManager.au3`

**Result: PASS**

All 27 module-level declarations use `Global Const`. None are mutable state. Classification
is correct throughout.

### `Includes/ServiceControl.au3`

**Result: FAIL — all 51 declarations use `Global` instead of `Global Const`**

Every constant in `ServiceControl.au3` — service access rights, service control codes,
service types, start types, error levels — is a fixed numeric value that is never modified
at runtime. All 51 should be `Global Const`. Using bare `Global` means:

- AU3Check `-w 3` / `-w 4` will not detect accidental writes.
- The intent "these are read-only constants" is not expressed in code.
- The values can be overwritten by any code that mistakenly assigns to them.

This is a pre-existing issue in `ServiceControl.au3` (the file is an imported legacy
library). It does not cause functional failures at current usage, because no code in the
project writes to these names, but it is a standards violation.

**Recommendation:** Change all `Global $NAME = ...` declarations to
`Global Const $NAME = ...` in `ServiceControl.au3`. Note: `$STANDARD_RIGHTS_REQUIRED2` and
computed aggregates (`$SC_MANAGER_ALL_ACCESS`, `$SERVICE_ALL_ACCESS`, `$SERVICE_DRIVER`,
`$SERVICE_WIN32`, `$SERVICE_TYPE_ALL`) may need care if the AU3Check version rejects
`Global Const` with `BitOR(...)` on the right-hand side — verify before batch-applying.

---

## Check 3 — `$aSvcTargetNames`: Global in config region, NOT Local inside `_RunServiceBatchStop` (DM-06 fix)

**Result: PASS — DM-06 fix is fully implemented**

`$aSvcTargetNames` is declared at line 84 as:
```autoit
Global $aSvcTargetNames[9] = [ _
    "FDResPub", "fdPHost", "TrustedInstaller", "wuauserv", _
    "UsoSvc", "DoSvc", "WaaSMedicSvc", "SSDPSRV", "sppsvc"]
```

This is inside `#Region ;Configuration — Target lists` (lines 80–87), at module scope,
before any function definition.

`_RunServiceBatchStop()` (lines 237–263) contains no `Local $aSvcTargetNames` declaration.
The function body reads the global at line 238:
```autoit
Local $aResults = _SM_StopServicesBatch($aSvcTargetNames, $SVC_BATCH_TIMEOUT_MS, $SVC_BATCH_POLL_MS)
```

`$aResults` is a Local working variable receiving the return value; `$aSvcTargetNames` is
the Global being passed by reference. No `Local` shadow of `$aSvcTargetNames` exists
anywhere in the file. DM-06 is correctly implemented.

---

## Check 4 — `$sProcesses`: declaration location

**Result: PARTIAL FAIL — declared Global but in wrong region**

`$sProcesses[18]` is declared at line 96 as `Global $sProcesses[18] = [...]`.

Positive findings:
- It is `Global` (not `Local`), so it is correctly accessible from `_KillProcessList()`.
- It is declared at module scope, before any function definition.
- The scope lifecycle is correct: declared once at startup, read-only thereafter.

Issue (pre-existing, carried from CR2-38):
- It lives in `#Region ;Variables/Logging` (lines 89–145) alongside runtime state variables
  such as `$bScriptRunning`, log-file path, and the log-initialization code block.
- As a user-editable configuration list it belongs in a configuration region, mirroring the
  structure established for `$aSvcTargetNames` in `#Region ;Configuration — Target lists`.

No `Local $sProcesses` declaration exists anywhere in the codebase. There is no shadowing
risk and no DM-06-equivalent defect for this variable. The only issue is region placement.

---

## Check 5 — Priority watchdog parallel arrays: properly declared as Globals

**Result: PASS**

The three arrays are declared at lines 116–118, inside `#Region ;Variables/Logging`:

```autoit
Global $aPriorityWatchPIDs[0]      ; PIDs under watchdog
Global $aPriorityWatchTargets[0]   ; corresponding target AutoIt priority constants (0–5)
Global $aPriorityWatchNames[0]     ; corresponding human-readable priority names
```

They are:
- `Global` (not `Local`) — correct; they must persist across `AdlibRegister` callbacks.
- Declared as zero-length arrays, grown with `_ArrayAdd` and shrunk with `_ArrayDelete`
  inside `LockProcessPriority()` and `_PriorityWatchdog()`.
- Never shadowed by a `Local` declaration anywhere in the file.
- Used consistently by reference (via direct array subscripts and `_ArrayAdd`/
  `_ArrayDelete` calls that mutate them in place).

The `AdlibRegister("_PriorityWatchdog", ...)` guard (`$bWasEmpty`) correctly ensures the
adlib is only registered once, while the same three globals serve all registered PIDs.
Lifecycle is correct.

**Minor placement note:** These are runtime state (not configuration), so their placement in
`#Region ;Variables/Logging` is semantically appropriate. They could optionally be in a
dedicated `#Region ;Watchdog state` block for clarity, but this is a cosmetic matter.

---

## Check 6 — Local variables in function scope that should be in config region

**Result: PASS — no such cases found**

A thorough scan of all `Local` declarations in function bodies across all three production
files found no cases where a function-scoped `Local` is used as a configuration input that
belongs at module scope.

Specific cases reviewed:
- `_RunServiceBatchStop()` — `Local $aResults`, `Local $sSvcName`, `Local $sOutcome`,
  `Local $iWin32` are all working variables for iteration/logging, not configuration.
- `_KillProcessList()` — `Local $iSuccess`, `Local $iFailure`, `Local $bActionTaken`,
  `Local $iResult` are counters and working variables.
- `LockProcessPriority()` — All `Local` declarations are input validation temporaries or
  working variables within the function. `$aPriorityWatchPIDs` etc. are accessed as globals
  without redeclaration.
- `_PriorityWatchdog()` — `Local $iPID`, `Local $iPriorityConst`, `Local $sPriorityName`
  at lines 470–472 are loop-iteration copies read from the Global arrays. These are correct
  as `Local` working copies.
- `_SM_StopServicesBatch()` in `ServiceManager.au3` — All `Local` declarations are properly
  function-scoped working variables (result arrays, loop indices, DLL call result holders,
  pending tracking arrays). No configuration data is buried in function scope.

---

## Check 7 — Variable shadowing: Local declarations that shadow a Global with the same name

**Result: PASS for all production files, with one cross-file issue flagged**

### Within `Stop Services Processes.au3`

Automated scan of all `Local` declarations against all `Global` declarations in the same
file found **no shadowing**. No `Local $varname` exists for any `$varname` that is also
declared `Global` in the main script.

### Within `Includes/ServiceManager.au3`

Same scan found **no shadowing** within `ServiceManager.au3` itself.

### Within `Tests/ServiceManager.Tests.au3`

The test file uses `$g_`-prefixed globals (`$g_iTestCount`, `$g_iPassCount`, etc.) and local
variables with distinct names. No shadowing detected. The `g_` prefix convention for test
globals is explicitly permitted by `CODING_STANDARDS.md`.

### Cross-file: `Global Const` redefinition between `ServiceManager.au3` and `Stop Services Processes.au3`

**Result: DEFECT — five Global Const names declared in both files with identical values**

The following constants are declared as `Global Const` in **both** `ServiceManager.au3`
(included at line 20) and `Stop Services Processes.au3` (lines 54–64):

| Constant | ServiceManager.au3 line | Main script line | Values match? |
|---|---|---|---|
| `$LOG_LEVEL_ERROR` | 100 | 54 | Yes (both = 0) |
| `$LOG_LEVEL_INFO` | 101 | 55 | Yes (both = 1) |
| `$LOG_LEVEL_VERBOSE` | 102 | 56 | Yes (both = 2) |
| `$LOG_TYPE_SYSTEM` | 108 | 60 | Yes (both = "System") |
| `$LOG_TYPE_SERVICE` | 109 | 62 | Yes (both = "Service") |

Because `ServiceManager.au3` is included at line 20 (before the main script's own
`Global Const` declarations at lines 54–64), AutoIt processes `ServiceManager.au3`'s
declarations first. When the main script then reaches its own `Global Const $LOG_LEVEL_ERROR = 0`
declaration, it encounters a **Global Const redefinition**. Under AU3Check `-w 3` / `-w 4`
this may be flagged as warning `0237 — $NAME already declared as a constant`.

The values are identical in both files, so there is no runtime behavioral impact — the
second declaration is effectively a no-op. However:
- It is a standards violation (AU3Check `-w 3`).
- It creates ambiguity about where these constants are authoritative.
- `ServiceManager.au3` declares only a subset of the main script's log constants
  (`$LOG_TYPE_PROCESS`, `$LOG_TYPE_PROCESS_PRIORITY`, `$LOG_TYPE_PRIORITY_WATCHDOG` are
  not in `ServiceManager.au3`), which makes the overlap partial and inconsistent.

**Recommendation:** Remove the duplicate log-level and log-type `Global Const` declarations
from `ServiceManager.au3`. The authoritative definitions live in the main script's
`#Region ;Configuration — Log constants`. `ServiceManager.au3` should rely on the
declarations provided by the including script, as it already does for `_LogMessage` itself
(which it calls but does not define). This follows the dependency direction established
by the architecture: `ServiceManager.au3` is a module that calls back into the main
script's logging infrastructure; it should not re-declare the main script's constants.

**Note:** This is distinct from variable shadowing (a `Local` overriding a `Global`). This
is a `Global Const` redefinition conflict at module scope. AU3Check treats it as a warning
rather than an error, but it is a code-quality defect under the project's AU3Check
compliance standard (`-w 3` enabled).

---

## Summary Table

| # | Check | File(s) | Result |
|---|---|---|---|
| 1a | Global declarations at top in `#Region` blocks — main script | `Stop Services Processes.au3` | PASS (minor: `$sProcesses` in wrong region; `Dim` temporaries in init block) |
| 1b | Global declarations at top in `#Region` blocks — ServiceManager | `Includes/ServiceManager.au3` | PASS |
| 1c | Global declarations at top — ServiceControl | `Includes/ServiceControl.au3` | PASS (placement OK; no regions — expected for legacy file) |
| 1d | Global declarations at top — Tests | `Tests/ServiceManager.Tests.au3` | PASS |
| 2a | `Global Const` vs `Global` — main script | `Stop Services Processes.au3` | PASS (2 dead globals noted; `$sProcesses` array cannot be `Const`) |
| 2b | `Global Const` vs `Global` — ServiceManager | `Includes/ServiceManager.au3` | PASS |
| 2c | `Global Const` vs `Global` — ServiceControl | `Includes/ServiceControl.au3` | **FAIL** — 51 `Global` declarations should be `Global Const` |
| 3 | `$aSvcTargetNames` is Global in config region, not Local in function | `Stop Services Processes.au3` | PASS — DM-06 fix confirmed |
| 4 | `$sProcesses` declared in config region | `Stop Services Processes.au3` | PARTIAL FAIL — Global correct, but in `Variables/Logging` not a config region |
| 5 | Watchdog arrays properly declared as Globals | `Stop Services Processes.au3` | PASS |
| 6 | No Local vars in functions that belong in config region | All files | PASS |
| 7a | No Local shadows a Global — within each file | All files | PASS |
| 7b | No cross-file Global Const redefinition | `ServiceManager.au3` + main | **DEFECT** — 5 `$LOG_*` constants redeclared in both files |

---

## Actionable Items

### High priority

**CR2-11-H1:** `Global Const` redefinition conflict — `$LOG_LEVEL_ERROR`, `$LOG_LEVEL_INFO`,
`$LOG_LEVEL_VERBOSE`, `$LOG_TYPE_SYSTEM`, `$LOG_TYPE_SERVICE` are declared in both
`Includes/ServiceManager.au3` (lines 100–109) and `Stop Services Processes.au3` (lines 54–64
of the `#Region ;Configuration — Log constants` block).

Remove the five duplicate `Global Const` declarations from `ServiceManager.au3`. The
authoritative definitions are in the main script. `ServiceManager.au3` already depends on
the main script providing `_LogMessage`; it should equally rely on the main script providing
the log constants.

### Medium priority

**CR2-11-M1:** `ServiceControl.au3` — all 51 `Global` declarations should be `Global Const`.
These are fixed numeric and string constants that are never reassigned. Converting them to
`Global Const` enforces read-only intent and enables AU3Check warning detection for
accidental writes. Verify that AU3Check accepts `Global Const NAME = BitOR(...)` before
applying to compound declarations.

**CR2-11-M2:** `$sProcesses[18]` region placement (carried from CR2-38). Move the declaration
out of `#Region ;Variables/Logging` into the `#Region ;Configuration — Target lists` block,
alongside `$aSvcTargetNames`. Add an "Edit here" comment matching the service target list
guidance.

### Low priority

**CR2-11-L1:** `$sStringInstaller` (line 90) and `$taskcloseran` (line 91) are declared
`Global` but never read or written after declaration. These are dead globals. Remove them
to eliminate speculative generality noise from the global scope.
