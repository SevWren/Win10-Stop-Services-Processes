# CR3-04 — ServiceControl.au3 Fixes Review

**File reviewed**: `Includes/ServiceControl.au3`
**Fixed point**: `c113a6f`
**HEAD commit**: `de1353e` — "fix: bug investigation, AU3Check hardening, and remaining documented work"
**Review date**: 2026-11-12
**Spec sources**: `docs/architecture-opportunities.md` (Candidate 2), `docs/reviews/bugs/BUG-07-servicecontrol-bugs.md`
**Standards source**: `CODING_STANDARDS.md`

---

## Standards

### S-1 — Global → Global Const conversions: PASS

All 51 declarations in the constant block (lines 2–87) are `Global Const`. The grep confirms
exactly 51 `^Global Const` lines and zero bare `^Global $NAME = value` lines remain. No
mutable global constant survives the change.

### S-2 — BitOR-computed aggregates typed as Global Const: PASS

All five BitOR-computed aggregates are correctly typed `Global Const`:

- `$SC_MANAGER_ALL_ACCESS` (line 12) — `Global Const ... = BitOR(...)`
- `$SERVICE_ALL_ACCESS` (line 31) — `Global Const ... = BitOR(...)`
- `$SERVICE_DRIVER` (line 63) — `Global Const ... = BitOR(...)`
- `$SERVICE_WIN32` (line 68) — `Global Const ... = BitOR(...)`
- `$SERVICE_TYPE_ALL` (line 71) — `Global Const ... = BitOR(...)`

AutoIt evaluates BitOR at declaration time when all operands are already-defined `Global Const`
values; the keyword is therefore valid and correct here, consistent with how `ServiceManager.au3`
handles its own aggregates.

### S-3 — #include-once at line 1: PASS

`#include-once` is present at line 1, unchanged from the fixed point. The spec (Candidate 2)
required this; it was already present before the change and has not been disturbed.

### S-4 — _StopService deprecation notice: PASS

The deprecation block is present at lines 157–159 of the current file, inserted between the
existing "Note:" line and the closing `===` fence:

```autoit
; DEPRECATED: Use _SM_StopServicesBatch() from Includes/ServiceManager.au3 instead.
; This function returns binary 1/0 with no state inspection or structured outcomes.
; See ADR-0004: incompatible error conventions with ServiceManager.au3.
```

All three required elements are present:
- The deprecation notice itself — present.
- Reference to `_SM_StopServicesBatch()` — present, with the correct module path
  (`Includes/ServiceManager.au3`).
- Reference to ADR-0004 — present (`See ADR-0004: incompatible error conventions with
  ServiceManager.au3`).

### S-5 — Function bodies unchanged: PASS

Diffing HEAD against the fixed point shows no changes to any function body. The diff is
confined entirely to:
1. The 51 `Global` → `Global Const` substitutions in the constant block (lines 2–87).
2. The three-line deprecation comment insertion in the `_StopService` header (lines 157–159).

All six function bodies (`_StartService`, `_StopService`, `_ServiceExists`, `_ServiceRunning`,
`_CreateService`, `_DeleteService`) are byte-for-byte identical to the fixed point.

### S-6 — Smell baseline (CODING_STANDARDS.md §Smell Baseline): no new smells introduced

The diff introduces no new logic, no new abstractions, and no new duplicated code. The
Duplicated Code smell pre-existing in the function bodies (all six functions repeat the same
DllOpen / OpenSCManager / OpenService / close pattern) was present before the fixed point and
is not touched by this change. No new smell is introduced.

---

## Spec

Spec source: `docs/architecture-opportunities.md` Candidate 2 and
`docs/reviews/bugs/BUG-07-servicecontrol-bugs.md` §8 Notes on Architecture Changes.

### SP-1 — 51 Global → Global Const conversions: PASS

Candidate 2 states: "Change each `Global` declaration to `Global Const` in `ServiceControl.au3`."
The fixed point had 51 bare `Global` declarations in lines 2–87. HEAD has 51 `Global Const`
declarations across the same range. Count is correct; no declaration is missing or duplicated.

### SP-2 — Constant values unchanged: PASS

A line-by-line comparison of the constant block between the fixed point and HEAD shows no
numeric value was altered. Every hex literal, every BitOR operand list, and every constant
name is identical between the two states. Representative spot checks:

| Constant | Fixed point value | HEAD value | Match |
|---|---|---|---|
| `$STANDARD_RIGHTS_REQUIRED2` | `0x000F0000` | `0x000F0000` | Yes |
| `$SC_MANAGER_ALL_ACCESS` | `BitOR($STANDARD_RIGHTS_REQUIRED2, $SC_MANAGER_CONNECT, ...)` | unchanged | Yes |
| `$SERVICE_ALL_ACCESS` | `BitOR($STANDARD_RIGHTS_REQUIRED2, $SERVICE_QUERY_CONFIG, ...)` | unchanged | Yes |
| `$SERVICE_CONTROL_STOP` | `0x00000001` | `0x00000001` | Yes |
| `$SERVICE_DRIVER` | `BitOR($SERVICE_KERNEL_DRIVER, $SERVICE_FILE_SYSTEM_DRIVER, $SERVICE_RECOGNIZER_DRIVER)` | unchanged | Yes |
| `$SERVICE_TYPE_ALL` | `BitOR($SERVICE_WIN32, $SERVICE_ADAPTER, $SERVICE_DRIVER, $SERVICE_INTERACTIVE_PROCESS)` | unchanged | Yes |
| `$SERVICE_ERROR_CRITICAL` | `0x00000003` | `0x00000003` | Yes |

### SP-3 — Five non-stop helper functions intact and unchanged: PASS

The five functions that BUG-07 §7 identifies as the non-stop helpers — `_ServiceRunning`,
`_ServiceExists`, `_StartService`, `_CreateService`, `_DeleteService` — are present in HEAD
with bodies identical to the fixed point. No parameter, no DllCall argument, no return path,
and no local variable declaration was altered in any of these five functions.

BUG-07 §8 also called for a deprecation comment on `_StopService` pointing to
`_SM_StopServicesBatch()` and ADR-0004. That requirement is met (see S-4 above).

### SP-4 — #include-once addition (Candidate 2 secondary requirement): PASS

Candidate 2 states: "Also add `#include-once` at the top of `ServiceControl.au3` (currently
absent, noted in ADR-0011 as causing duplicate-declaration warnings if the file is included
twice)."

The spec says "currently absent" because the spec document was written against a state before
the fixed point. The fixed point (`c113a6f`) already had `#include-once` at line 1. HEAD
preserves it. The requirement is satisfied — whether it was present before the fixed point or
added in an earlier commit is immaterial; the current state is correct.

### SP-5 — Out-of-scope items (not addressed by this change, not expected to be): NOTE

BUG-07 §8 identifies two additional fix items that Candidate 2 did not ask for in this change:

- Bug A fix (`"str", ""` → proper `SERVICE_STATUS` struct in `ControlService` calls in
  `_StopService` and `_ServiceRunning`).
- Bug B fix (`"long"` → `"handle"` for all handle-typed DllCall parameters across all six
  functions).

Neither of these is addressed in this diff, and neither was required by Candidate 2 or by
the task spec for this change. BUG-07 §8 notes that both bugs together "warrant an ADR before
implementation." Their absence here is correct scope behaviour, not a missing requirement.

---

## Summary

**Standards axis**: 0 violations. All 51 conversions are correct; BitOR aggregates are
correctly typed; `#include-once` is at line 1; deprecation notice is complete with both
`_SM_StopServicesBatch()` and ADR-0004 references; function bodies are untouched.

**Spec axis**: 0 findings. All five non-stop helper functions are intact and unchanged; all
51 constant values are identical to the fixed point; the `_StopService` deprecation notice
meets the BUG-07 requirement.

No issues found on either axis. The change is a clean, mechanical execution of Candidate 2
with no scope creep and no unintended side effects.
