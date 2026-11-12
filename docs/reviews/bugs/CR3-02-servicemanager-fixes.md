# CR3-02 — Code Review: ServiceManager.au3 Bug Fixes

**Review type:** Two-axis (Standards + Spec)
**Fixed point:** `c113a6f`
**Commit reviewed:** `de1353e` (fix: bug investigation, AU3Check hardening, and remaining documented work)
**File scope:** `Includes/ServiceManager.au3` only
**Spec sources:** BUG-02, BUG-03, BUG-04, CODING_STANDARDS.md
**Date:** 2026-11-12

---

## Standards

### BUG-02 Fix — `Local $iPendLen` Declaration Position

**PASS.**

`Local $iPendLen` is now declared at line 192, before the Phase 1 `For` loop, alongside the
other pending-tracking array declarations (`$aPendingIdx`, `$aPendingHnd`). It is no longer
inside the loop body. The two assignment sites inside the loop (the STOP_PENDING branch at
line 255 and the stop-accepted branch at line 302) correctly use plain `$iPendLen = ...` with
no `Local` keyword. AU3Check `-w 3` will no longer emit a redeclaration-in-loop warning for
this variable.

The added comment block (lines 189–191) accurately explains the rationale. No violations.

---

### BUG-03 Fix — `_SM_GetServiceState` Removal

**PARTIAL PASS — residual documentation gap.**

The function definition (Func body + doc-comment block, formerly lines 382–410) has been
deleted from the file. The INTERNAL HELPERS list in the file header no longer contains
`_SM_GetServiceState` (confirmed: line 19 and surrounding lines). The deletion of the function
itself is correct and complete.

**Residual gap — not introduced by this diff, but not resolved by it either:**

`ARCHITECTURE.md` lines 22–23 still list `_SM_GetServiceState($hService)` under the
`ServiceManager.au3` internal-helper tree in the Module Map section. ARCHITECTURE.md is a
separate file outside the stated scope of this review (`Includes/ServiceManager.au3` only),
so this is recorded as an observation rather than a finding against the diff. However, the
file header (line 19 of `ServiceManager.au3`) now documents fewer functions than
`ARCHITECTURE.md` claims exist — a reader consulting both documents will find them
inconsistent. This should be addressed in a follow-on ARCHITECTURE.md update.

Similarly, `CLAUDE.md` §"Coding Conventions → Function Naming" still lists
`_SM_GetServiceState` as an example of the `_SM_PascalCase` tier. This is outside file scope
but is a documentation inconsistency introduced by the deletion.

---

### BUG-04 Fix — Outcome Constant Rename

**FAIL — MAJOR. `$SM_OUTCOME_ALREADY_STOPPED` constant is declared with a doubled suffix.**

The diff shows the following at line 55:

```autoit
-Global Const $SM_OUTCOME_ALREADY        = "ALREADY_STOPPED"
+Global Const $SM_OUTCOME_ALREADY_STOPPED_STOPPED = "ALREADY_STOPPED"
```

The declared identifier is `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` — the word `_STOPPED` appears
twice. BUG-04 specifies the new name must be `$SM_OUTCOME_ALREADY_STOPPED`.

**All four usage sites within `Includes/ServiceManager.au3` reference `$SM_OUTCOME_ALREADY_STOPPED`
(without the double suffix):**

| Line | Usage |
|------|-------|
| 246 | `$aResults[$i][3] = $SM_OUTCOME_ALREADY_STOPPED` |
| 291 | `If $sCtrlOutcome = $SM_OUTCOME_ALREADY_STOPPED Then` |
| 425 | `Return $SM_OUTCOME_ALREADY_STOPPED` |
| (Stop Services Processes.au3:247) | `Case $sOutcome = $SM_OUTCOME_ALREADY_STOPPED` |
| (Tests/ServiceManager.Tests.au3:190) | `= $SM_OUTCOME_ALREADY_STOPPED` |

Every read site uses the correctly-named identifier `$SM_OUTCOME_ALREADY_STOPPED`. The
declaration uses `$SM_OUTCOME_ALREADY_STOPPED_STOPPED`. These are two different identifiers in
AutoIt. The constant `$SM_OUTCOME_ALREADY_STOPPED` is therefore **undeclared** everywhere it is
read; `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` is **declared but never read**.

**Runtime impact:** AU3Check `-d` (undeclared-variable checking) will flag every read site as
an undeclared variable. At runtime, `$SM_OUTCOME_ALREADY_STOPPED` resolves to an empty string
`""` (AutoIt default for undeclared variables). Any outcome comparison against it will silently
fail. The dead constant `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` will never be evaluated.

This is the highest-severity finding in this review. The fix is a one-character edit to the
declaration line:

```autoit
; Correct:
Global Const $SM_OUTCOME_ALREADY_STOPPED = "ALREADY_STOPPED"
```

**Authority:** CODING_STANDARDS.md §Constant Naming — constant names must mirror their string
values. BUG-04 §Fix Applied table explicitly specifies `$SM_OUTCOME_ALREADY_STOPPED` as the
new name.

---

### Old Name Residuals

**PASS for `$SM_OUTCOME_TIMEDOUT`:** No occurrences of the old name `$SM_OUTCOME_TIMEDOUT`
remain in any `.au3` file. The rename to `$SM_OUTCOME_TIMED_OUT` is complete across all three
files (`ServiceManager.au3`, `Stop Services Processes.au3`, `Tests/ServiceManager.Tests.au3`).

**PASS for `$SM_OUTCOME_ALREADY`:** No occurrences of the bare old name `$SM_OUTCOME_ALREADY`
(without any suffix) remain in any `.au3` file. The old identifier is fully gone.

---

### Smell Baseline Check (new issues introduced by the fixes)

**Speculative Generality — orphaned constant `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` (line 55).**
As detailed under BUG-04 above, the mis-typed declaration creates a constant that is defined
but never read. Per CODING_STANDARDS.md §Duplicate Prevention (reviewer note on orphaned
constants): "A `Global Const` that is defined but never read anywhere in the compilation unit
is a Speculative Generality smell." This is a direct consequence of the typo — it is not an
independent smell; it is the same BUG-04 finding viewed through the smell lens.

No other new smells were introduced. The BUG-02 scope change (moving `Local $iPendLen` before
the loop) is clean. The BUG-03 deletion removes dead code without leaving stubs or orphaned
references inside `ServiceManager.au3`.

**Pre-existing smell, not introduced by this diff (recorded for completeness):**
`$SM_STOP_ELIGIBLE_STATES` (line 90) is declared as a documentation-only string constant but
is never read by `_SM_IsStopEligible` or any other function. CODING_STANDARDS.md explicitly
acknowledges this instance and notes the comment claiming "Used by `_SM_IsStopEligible`" is
incorrect. This smell predates the diff and is unchanged by it.

---

## Spec

### BUG-02 — `$iPendLen` declared before the Phase 1 loop

**PASS.** BUG-02 §4 Fix specifies moving `Local $iPendLen` to before the Phase 1 For loop,
after the pending-tracking array declarations, and removing the `Local` keyword from inside
the loop body. The implementation matches exactly:

- `Local $iPendLen` now appears at line 192, after `Local $aPendingHnd[0]` and before the
  Phase 1 `For` loop at line 197.
- No `Local $iPendLen` exists inside the loop body.
- The two assignment sites inside the loop (lines 255 and 302) use plain assignment with no
  `Local` keyword, as required.

---

### BUG-03 — `_SM_GetServiceState` removed from function list AND INTERNAL HELPERS comment

**PASS for stated requirements. See documentation-gap note under Standards.**

BUG-03 §Fix Applied states: "The function definition (lines 382–410, including doc-comment
block) was deleted" and "The file header listing in the INTERNAL HELPERS comment block
(line 19) was also removed."

Both deletions are confirmed in the diff and in the current file state. The two inline
`QueryServiceStatus` DllCall patterns in Phase 1 (line 227) and Phase 2 (line 324) are
unchanged, consistent with BUG-03's explicit note: "The two inline `QueryServiceStatus`
DllCall patterns in `_SM_StopServicesBatch` (Phase 1 and Phase 2) are unchanged."

---

### BUG-04 — Outcome constant rename: definition + all usage sites

**FAIL — definition mismatch; usage sites partially correct.**

BUG-04 §Fix Applied specifies:

| Old name              | New name                    | Value (unchanged)   |
|-----------------------|-----------------------------|---------------------|
| `$SM_OUTCOME_ALREADY` | `$SM_OUTCOME_ALREADY_STOPPED` | `"ALREADY_STOPPED"` |
| `$SM_OUTCOME_TIMEDOUT`| `$SM_OUTCOME_TIMED_OUT`     | `"TIMED_OUT"`       |

BUG-04 also states: "`Includes/ServiceManager.au3` — 5 occurrences updated (definition + 4 usages)."

**`$SM_OUTCOME_TIMED_OUT`:** Definition at line 58 is correct. Usage at line 366 is correct.
Full rename complete. PASS.

**`$SM_OUTCOME_ALREADY_STOPPED`:** The 4 usage sites within `ServiceManager.au3` (lines 246,
291, 425) and in the companion files (`Stop Services Processes.au3` line 247,
`Tests/ServiceManager.Tests.au3` line 190) all correctly use `$SM_OUTCOME_ALREADY_STOPPED`.
However, the definition at line 55 reads `$SM_OUTCOME_ALREADY_STOPPED_STOPPED`. The spec
requires the declaration to be `$SM_OUTCOME_ALREADY_STOPPED`. FAIL on the definition.

BUG-04 post-fix verification states: "A regex search for `SM_OUTCOME_ALREADY[^_]` ... returned
no matches — the old names are fully removed." That check passes (the old name `$SM_OUTCOME_ALREADY`
without any suffix is gone). However, the check did not catch the doubled-suffix typo
`$SM_OUTCOME_ALREADY_STOPPED_STOPPED`, which is a different erroneous identifier. The
verification step was insufficient.

---

### ARCHITECTURE.md — 5 outcome codes, Phase 1 / Phase 2 logic

**PASS.** The five outcome codes required by ARCHITECTURE.md §Outcome Classification Table
are all correctly implemented:

| Outcome | Constant in code | String value | Implementation |
|---------|-----------------|--------------|----------------|
| `STOPPED` | `$SM_OUTCOME_STOPPED` (line 54) | `"STOPPED"` | Phase 2 poll, line 339 |
| `ALREADY_STOPPED` | `$SM_OUTCOME_ALREADY_STOPPED` (line 246, 291, 425) | `"ALREADY_STOPPED"` | Phase 1 state-routing + ControlService 1062 path |
| `UNAVAILABLE` | `$SM_OUTCOME_UNAVAILABLE` (line 54, 210) | `"UNAVAILABLE"` | Phase 1 OpenService 1060 path |
| `FAILED` | `$SM_OUTCOME_FAILED` (lines 214, 234, 266) | `"FAILED"` | Phase 1 error paths |
| `TIMED_OUT` | `$SM_OUTCOME_TIMED_OUT` (line 366) | `"TIMED_OUT"` | Post-Phase-2 timeout sweep |

Note: `ALREADY_STOPPED` read sites reference the undeclared identifier `$SM_OUTCOME_ALREADY_STOPPED`
due to the typo in the declaration. The string value `"ALREADY_STOPPED"` will never be assigned
at runtime; services that were already stopped will receive an empty string `""` as their outcome.
The spec is correctly stated in the usage sites but broken at runtime due to the declaration bug.

**Phase 1 routing:** The five routing branches (STOPPED → ALREADY_STOPPED, STOP_PENDING →
pending list, non-stop-eligible → FAILED, stop-eligible → ControlService + pending list,
ControlService failure → classify by Win32 error) are intact and match ARCHITECTURE.md
§Batch-Stop Algorithm exactly.

**Phase 2 polling:** The shared-deadline While loop, backwards iteration for safe removal,
per-service CloseServiceHandle on STOPPED, and the post-loop timeout sweep are all intact and
match the architecture spec.

---

## Summary

| Axis | Findings | Worst issue |
|------|----------|-------------|
| Standards | 1 FAIL (MAJOR), 1 PASS, 2 PASS, 1 doc-gap note, 1 pre-existing smell note | BUG-04 declaration typo: `$SM_OUTCOME_ALREADY_STOPPED_STOPPED` declared; `$SM_OUTCOME_ALREADY_STOPPED` used — identifier mismatch causes undeclared-variable warnings and silent empty-string assignment at runtime |
| Spec | 1 FAIL (definition), 2 PASS, 5-outcome coverage confirmed | Same BUG-04 declaration typo — the spec-required name `$SM_OUTCOME_ALREADY_STOPPED` is used at all call sites but the declaration does not match, breaking the runtime contract |

**Action required:** Rename the declaration on line 55 of `Includes/ServiceManager.au3` from
`$SM_OUTCOME_ALREADY_STOPPED_STOPPED` to `$SM_OUTCOME_ALREADY_STOPPED`. No other code changes
are needed; all usage sites already use the correct name.
