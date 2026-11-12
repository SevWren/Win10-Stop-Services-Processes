# CR2-03 — ServiceManager.au3 Second-Pass Review

**File**: `Includes/ServiceManager.au3`
**Fixed point**: `ab5b012`
**Diff**: `git diff ab5b012...HEAD -- "Includes/ServiceManager.au3"`
**Commits since fixed point**: `1d8a5ea feat: replace broken service-stop path with native SCM batch-stop module`
**Review date**: 2026-11-12

---

## Standards

### Targeted checklist

**1. OpenSCManagerW failure now returning a zero-row array — PASS**

Lines 175–183 of HEAD:

```autoit
Local $aEmpty[0][6]
SetError(1)
Return $aEmpty
```

The CR-02 fix is present and correct. The old code returned the pre-allocated `$aResults` array (which had `$iCount` populated rows); the new code declares a fresh `$aEmpty[0][6]` and returns that. The comment on line 179 (`; Return a zero-row array — NOT the pre-allocated $aResults (CR-02 MAJOR fix)`) documents the intent.

**2. `$iPendLen2` gone — PASS**

`$iPendLen` is declared once per loop iteration at line 199 (`Local $iPendLen`) and then assigned (not re-declared with `Local`) in both pending-append branches (lines 256 and 303). The opaque second variable `$iPendLen2` is gone. A comment at line 302 acknowledges the two branches share the same variable.

**3. `$LOG_LEVEL_*` and `$LOG_TYPE_*` constants defined and used at all `_LogMessage` call sites — PASS**

Constants are defined at lines 100–109. All twelve `_LogMessage` call sites (lines 177, 213, 217, 236, 249, 270, 293, 295, 331, 342, 370, 405) use the named constants. No call site passes string or numeric literals for `$sType` or `$iLevel`.

**4. `$SM_STOP_ELIGIBLE_STATES` constant defined — PASS**

Defined at line 91. The constant exists and carries a cross-reference to `DM-01`, `DM-09 Change 4`, and `GLOSSARY.md`. Note: the constant itself is a documentation string (`"RUNNING,PAUSED,PAUSE_PENDING,CONTINUE_PENDING"`) not used at runtime by `_SM_IsStopEligible`, which implements the same set via a `Switch` statement. The constant is a documentation artefact rather than a runtime guard — this is a judgement call, not a hard violation, but the disconnect between the constant and the `Switch` could cause them to drift silently.

**5. SCM Handle documentation comment at `OpenSCManagerW` call — PASS**

Lines 160–166 contain a full block comment that distinguishes `$hSCM` (SCM Handle, opened once for the batch, closed after all per-service handles) from `$hService` (Service Handle, per-service, Phase 1 through Phase 2). The comment references `DM-09 Change 5` and `GLOSSARY.md`.

**6. `_SM_BuildResultRow` column-5 `$sNote` comment — PASS**

Lines 531–536 contain an inline comment on `$aRow[5] = $sNote` explaining: non-empty only for START_PENDING and TIMED_OUT outcomes; empty string for all others; callers must check `$sOutcome` ([i][3]) for outcome classification, not the note field. References `DM-04 §3.6`.

**7. Duplicated Code — residual smell (judgement call)**

The two ReDim append blocks are structurally identical:

```autoit
; Lines 256–260 (STOP_PENDING branch):
$iPendLen = UBound($aPendingIdx)
ReDim $aPendingIdx[$iPendLen + 1]
ReDim $aPendingHnd[$iPendLen + 1]
$aPendingIdx[$iPendLen] = $i
$aPendingHnd[$iPendLen] = $hService

; Lines 303–307 (stop-control-accepted branch):
$iPendLen = UBound($aPendingIdx)
ReDim $aPendingIdx[$iPendLen + 1]
ReDim $aPendingHnd[$iPendLen + 1]
$aPendingIdx[$iPendLen] = $i
$aPendingHnd[$iPendLen] = $hService
```

The fix removed `$iPendLen2` (the Mysterious Name) and unified the variable, which is correct. However the four-line append body itself was not extracted into a helper. The comment at line 302 acknowledges this. In AutoIt there is no pass-by-reference array append pattern that is concise enough to make extraction unambiguously cleaner; the smell is acknowledged and the naming confusion is resolved. Flag as a residual **Duplicated Code** smell — judgement call, not a hard violation.

---

### Naming convention violation — HARD VIOLATION

**Standard**: `CODING_STANDARDS.md` lines 10–13:

> A third tier `_SM_PascalCase` appeared in a previous revision of this file but is not defined in `CLAUDE.md`. It has been removed. Any module-prefixed helpers (e.g., service-manager functions) must follow the standard `_UnderscorePascalCase` convention unless `CLAUDE.md` is explicitly updated to introduce a new tier.

`CLAUDE.md` "Function Naming" does list `_SM_PascalCase` as the service-manager tier, but the same section states: "If this section and `CODING_STANDARDS.md` ever conflict, `CODING_STANDARDS.md` wins."

`CODING_STANDARDS.md` explicitly removed `_SM_` as a recognised tier. Every function in this module uses the `_SM_` prefix: `_SM_StopServicesBatch`, `_SM_GetServiceState`, `_SM_ServiceStateToString`, `_SM_Win32ErrToOutcome`, `_SM_IsStopEligible`, `_SM_StateNeedsPolling`, `_SM_StateToAlreadyStopped`, `_SM_BuildResultRow`. All eight names violate the documented standard as written.

This is a standards conflict between `CLAUDE.md` and `CODING_STANDARDS.md` that the standards docs themselves address (CODING_STANDARDS.md wins). The correct resolution per `CODING_STANDARDS.md` is to rename to `_UnderscorePascalCase` (e.g., `_StopServicesBatch`, `_GetServiceState`, etc.), OR to update `CLAUDE.md` first and then update `CODING_STANDARDS.md` to match. As written, this is a hard violation.

---

### Additional smell — Speculative Generality (judgement call)

`_SM_GetServiceState` (lines 397–410) is listed in the file's public-interface comment and in `ARCHITECTURE.md`'s internal-helpers list, but it is never called anywhere within `_SM_StopServicesBatch`. All state queries in the batch function are done inline via `QueryServiceStatus` DllCall patterns. The helper exists for the test harness or future callers, but nothing in the current diff invokes it from production code. This is a possible **Speculative Generality** smell — flag as a judgement call.

---

### No violations found

- `@error` capture: every DllCall is followed immediately by `Local $iXxxDllErr = @error`. Pattern is consistent throughout.
- Handle ownership: every opened service handle has exactly one close path (either in an early-exit ContinueLoop branch, in the Phase 2 stopped-removal block, or in the timeout cleanup loop). The SCM handle is closed once after the timeout loop.
- `_WinAPI_GetLastError()` is called on the line immediately after `@error` capture where Windows error codes are needed.
- `#include-once` is present.
- No `ConsoleWrite` calls outside the allowed test-harness exception.

---

## Spec

**Spec source**: `docs/ARCHITECTURE.md` — Phase 1 / Phase 2 algorithm description and `_SM_StopServicesBatch` public contract.

### Requirements present and correctly implemented

**Phase 1 algorithm — PASS**

The implementation matches the architecture's pseudocode exactly:

- SCM opened once with `SC_MANAGER_CONNECT`.
- Per-service loop opens each handle with `SERVICE_QUERY_STATUS | SERVICE_STOP`.
- `OpenServiceW` failure with error 1060 → `UNAVAILABLE`, handle never opened so no close.
- `OpenServiceW` failure with other error → `FAILED`, handle never opened.
- `QueryServiceStatus` failure → `FAILED`, close handle, continue.
- `dwCurrentState == SERVICE_STOPPED` (1) → `ALREADY_STOPPED`, close handle, continue.
- `dwCurrentState == SERVICE_STOP_PENDING` (3) → add to pending list, no ControlService call.
- `_SM_IsStopEligible` = False (START_PENDING) → `FAILED` with Win32 1061, close handle, continue.
- `ControlService` success → add to pending list.
- `ControlService` failure with 1062 → `ALREADY_STOPPED`; other failures → `FAILED`.

All eight routing cases from the architecture's "Pending-State Routing Reference" table are covered.

**Phase 2 algorithm — PASS**

- `TimerInit()` before the While loop.
- While condition: `UBound($aPendingIdx) > 0 And TimerDiff($iTimer) < $iBatchTimeoutMs`.
- `Sleep($iPollIntervalMs)` before the inner poll loop.
- Backwards iteration for safe in-loop removal.
- Poll failure → defer (leave in pending list).
- `dwCurrentState == SERVICE_STOPPED` → `STOPPED`, close handle, remove from pending list.
- Timeout cleanup loop → `TIMED_OUT`, close handle.
- SCM handle closed after timeout cleanup.

**@error contract — PASS**

`@error=1` is set before `Return $aEmpty` (zero-row array) on the SCM-failure path. All other returns leave `@error=0`.

**Result row columns — PASS**

`[i][0]` through `[i][5]` match the architecture contract exactly: name, init state, final state, outcome string, Win32 error, note.

**Outcome codes — PASS**

All five outcome strings from the contract (`STOPPED`, `ALREADY_STOPPED`, `UNAVAILABLE`, `FAILED`, `TIMED_OUT`) are used at the correct call sites. Named constants (`$SM_OUTCOME_*`) are used throughout.

**Side effects contract — minor gap**

The architecture states: "Calls `_LogMessage` for each service outcome (level 1 for success, 0 for failure)". The implementation uses level 2 (verbose) for `ALREADY_STOPPED` and service-not-found (`UNAVAILABLE`) cases, which the contract's side-effects line does not mention. The implementation is functionally correct — verbose-level logging for expected-negative observations is consistent with the logging policy in `CLAUDE.md` and `CODING_STANDARDS.md`. The gap is in the architecture's side-effects description, which under-specifies the verbose path. This is a documentation gap in `ARCHITECTURE.md`, not an implementation error.

**`_SM_GetServiceState` unused by the main function — gap**

The architecture lists `_SM_GetServiceState` as an internal helper for `ServiceManager.au3`. It is present and correctly implemented, but no call site within `_SM_StopServicesBatch` or any other function in this file actually invokes it. All state queries are done by inline DllCall patterns. The function exists for the test harness (Ticket T03 mentions a "Deterministic Test Harness") but no test file appears in this diff. The spec says "Internal only (not called from main script)" — which is satisfied — but the helper itself is called from nowhere in the module. This is not a spec violation but is worth noting: if the test harness is the intended consumer, it should appear in a subsequent commit.

**QueryServiceStatus decision — documented and implemented consistently — PASS**

`ARCHITECTURE.md` documents the deliberate choice to use `QueryServiceStatus` over `QueryServiceStatusEx`, with rationale. The implementation is consistent with this documented decision throughout Phase 1, Phase 2, and `_SM_GetServiceState`.

---

## Summary

| Axis | Findings | Worst issue |
|---|---|---|
| Standards | 1 hard violation, 2 judgement-call smells | Naming: all 8 `_SM_*` function names violate `CODING_STANDARDS.md` CR-09 (requires `_UnderscorePascalCase` or a matching update to both standards files) |
| Spec | 1 documentation gap (not an implementation error), 1 observation (unused helper) | Side-effects line in `ARCHITECTURE.md` under-specifies the verbose-level logging path; not a code defect |

All targeted fix-verification checks pass. The single hard Standards violation is the `_SM_` prefix conflict between `CLAUDE.md` and `CODING_STANDARDS.md`.
