# BUG-05 — Dead Compatibility Shim: `$PROCESS_IDLE`

**Review ID:** CR2-02
**File:** `Stop Services Processes.au3`
**Former line:** 108
**Status:** Fixed

---

## Summary

`Global Const $PROCESS_IDLE = 0` was a compatibility shim added because `$PROCESS_IDLE`
was absent from the bundled `AutoItConstants.au3` on the author's AutoIt 3.3.16.1
installation. The constant was superseded by `$AUTOIT_PRIORITY_IDLE = 0` (defined at
line 67 in the `$AUTOIT_PRIORITY_*` region). After that region was introduced, `$PROCESS_IDLE`
was never referenced again anywhere in the codebase — making it dead code.

---

## Investigation

### Step 1 — Located the declaration

```
Stop Services Processes.au3:108:
Global Const $PROCESS_IDLE = 0  ; not defined in this AutoIt version's AutoItConstants.au3
```

### Step 2 — Searched all .au3 files for any reference to `$PROCESS_IDLE`

Scope: all `.au3` files in the repo (excluding `BackUp/` only because those are
historical snapshots and not compiled into the script, but they were searched too).

Result: the identifier appears **only on the declaration line** in
`Stop Services Processes.au3`. No call site, no comparison, no assignment references it.

| File | Matches |
|------|---------|
| `Stop Services Processes.au3` | 1 (declaration only) |
| `Includes/ServiceControl.au3` | 0 |
| `Includes/ServiceManager.au3` | 0 |
| `Includes/AutoItConstants.au3` | 0 |
| `Tests/ServiceManager.Tests.au3` | 0 |
| All `BackUp/*.au3` | 0 |

Verdict: **truly dead — zero call sites.**

### Step 3 — Checked for other dead compatibility shims

Searched for any other `Global Const` declarations in the main script that duplicate
constants already provided by the `$AUTOIT_PRIORITY_*` family or by `AutoItConstants.au3`.

Findings:

**`$PROCESS_IDLE` (removed):**
Duplicated `$AUTOIT_PRIORITY_IDLE` (value 0). No usages anywhere.

**`$PROCESS_LOW`, `$PROCESS_BELOWNORMAL`, `$PROCESS_NORMAL`, `$PROCESS_ABOVENORMAL`,
`$PROCESS_HIGH`, `$PROCESS_REALTIME` — defined in `Includes/AutoItConstants.au3` lines 291–296:**
These are the original `ProcessSetPriority` constants shipped with AutoIt. The main script
does not use any of them — all priority-constant references in `Stop Services Processes.au3`
use the `$AUTOIT_PRIORITY_*` family exclusively. However, these constants live in the
**bundled include file** (`Includes/AutoItConstants.au3`), which is not owned by this
project, so they are **not removed** here. They are dead from the perspective of this
script but are part of the standard AutoIt distribution.

No other compatibility shims were found in the main script.

---

## Root Cause

The shim was introduced before the `$AUTOIT_PRIORITY_*` region was added. Once that
region landed, all code that previously would have used `$PROCESS_IDLE` was written to
use `$AUTOIT_PRIORITY_IDLE` instead. The old declaration was never cleaned up.

---

## Fix Applied

Deleted the dead declaration from `Stop Services Processes.au3` (was line 108):

```diff
-Global Const $PROCESS_IDLE = 0  ; not defined in this AutoIt version's AutoItConstants.au3
-
 ; Priority watchdog parallel arrays
```

The blank line separating it from the `; Priority watchdog parallel arrays` comment was
removed with it, keeping the spacing consistent with the surrounding block.

---

## Verification

After the fix:

- `$PROCESS_IDLE` does not appear anywhere in `Stop Services Processes.au3`.
- All priority-constant usages continue to resolve through `$AUTOIT_PRIORITY_IDLE` (value 0),
  which is defined in the `Configuration — AutoIt process priority constants` region at line 67.
- No AU3Check warnings are introduced: the removed constant was declared but never used,
  so removing it eliminates a potential "declared but never used" lint warning rather than
  creating one.

---

## Related

- `CLAUDE.md` — AutoIt Version Compatibility Notes table (the original justification for
  the shim is recorded there; that row remains accurate as historical context).
- `docs/ARCHITECTURE.md` — Priority Constant Mapping table documents `$AUTOIT_PRIORITY_IDLE`
  as the canonical constant for the Idle tier.
