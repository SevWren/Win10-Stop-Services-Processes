# CR-02 — ServiceManager.au3 Code Review

**File reviewed:** `Includes/ServiceManager.au3`
**Fixed point:** `ab5b012`
**Diff command:** `git diff ab5b012...HEAD -- "Includes/ServiceManager.au3"`
**Ticket:** T03 — Build ServiceManager.au3 + Deterministic Test Harness
**Date:** 2026-11-12

---

## Standards

Standards sources: `CODING_STANDARDS.md`, `CLAUDE.md`, smell baseline (Fowler, _Refactoring_ ch.3).

### Documented-standard compliance

**Function Naming** — All functions follow the required `_SM_PascalCase` prefix pattern documented in CODING_STANDARDS.md. No violations.

**Logging** — Every runtime message routes through `_LogMessage($sMessage, $sType, $iLevel)` using the `"Service"` log type. Levels are correct: 0 for errors, 1 for successful-stop confirmations, 2 for verbose/already-stopped paths. No bare `ConsoleWrite` calls. No violations.

**@error Capture** — Every `DllCall` is immediately followed by `Local $i*DllErr = @error` on the next line, with `_WinAPI_GetLastError()` called on the line after that before any other API call. This is consistent across all six call sites (OpenSCManagerW, OpenServiceW, QueryServiceStatus x2, ControlService, polling QueryServiceStatus). Full compliance with CODING_STANDARDS.md "@error Capture" rule.

**Handle Ownership** — Every `OpenServiceW`-returned handle is closed on every branch before `ContinueLoop` or end-of-function. The SCM handle is closed after all service handles. On `OpenServiceW` failure the code correctly skips `CloseServiceHandle` (handle was never opened). No violations.

**AU3Check Compliance** — All variables are declared with `Local` before use. Loop index variables (`$i`, `$j`, `$k`, `$iTimeoutIdx`) are declared with `Local` at their respective `For` statements. The file uses `#include-once`. No shadowed globals, no use of `Dim` inside functions. No violations detected through static inspection (AU3Check gate noted as NOT RUN in the Linux sandbox per CLAUDE.md).

**Path Portability** — No hardcoded checkout roots, user-profile paths, or desktop paths. No violations.

**Duplicate Prevention** — `#include-once` present. No duplicate includes or HotKeySet calls (file introduces neither). No violations.

### Smell-baseline findings (all judgement calls)

**Duplicated Code (judgement call):** The four-line block that appends to `$aPendingIdx` / `$aPendingHnd` appears twice in Phase 1 — once for the STOP_PENDING branch and once for the ControlService-accepted branch. The only difference is the variable name used for the current pending-list length (`$iPendLen` vs `$iPendLen2`). The name divergence is itself forced by AutoIt's prohibition on redeclaration within the same scope, suggesting these two paths would benefit from extraction into a small helper (e.g., `_SM_AddToPending`). Low severity; does not affect correctness.

**Mysterious Name (judgement call):** `$iPendLen2` is a scope-collision workaround. The name communicates "a second pending-length variable" rather than its role. This is a symptom of the duplicated block above; fixing the duplication would eliminate this name.

**Speculative Generality (judgement call):** `_SM_BuildResultRow` is documented as a convenience helper "used by the test harness." It is never called within `ServiceManager.au3` itself. The test harness (`Tests/ServiceManager.Tests.au3`) is not in this diff. If that file does not exist or does not call `_SM_BuildResultRow`, this function is dead exported code. The issue checklist (T03) requires the test harness to be delivered together — its absence from the diff means the justification for this helper is unverifiable here.

**Middle Man (judgement call):** `_SM_StateNeedsPolling` and `_SM_StateToAlreadyStopped` are single-expression boolean wrappers (`Return ($iState = $SM_STATE_STOP_PENDING)`). They name intent clearly, which is valuable, but they add an extra call frame for a single comparison. The repo's coding standards do not prohibit this pattern; it is noted as a low-priority style observation only.

### Standards summary

No hard documented-standard violations found. Four smell-baseline observations, all judgement calls: one Duplicated Code instance (the pending-list append block), one Mysterious Name (`$iPendLen2`) arising from it, one Speculative Generality (`_SM_BuildResultRow` without its test harness), and two Middle Man wrappers of negligible severity.

---

## Spec

Spec sources: `.scratch/service-manager-migration/issues/03-build-servicemanager.md`, `docs/REQUIREMENTS.md`, `docs/ARCHITECTURE.md`.

### Requirements implemented correctly

**REQ-001 — Batch returns per-service outcomes with 5 outcome codes:**
All five outcome string constants (`STOPPED`, `ALREADY_STOPPED`, `UNAVAILABLE`, `FAILED`, `TIMED_OUT`) are defined and assigned on every code path. The 2D result array has 6 columns per row matching the contract exactly. Implemented correctly.

**REQ-002 — All 7 service states interpreted:**
Constants `$SM_STATE_STOPPED` through `$SM_STATE_PAUSED` (1–7) are defined. `_SM_ServiceStateToString` maps all seven states plus an `"UNKNOWN"` fallback. The routing logic in `_SM_StopServicesBatch` handles STOPPED (already-stopped), STOP_PENDING (needs polling), START_PENDING (ineligible), and all remaining states (eligible for stop control). Implemented correctly.

**REQ-003 — No serial waiting; two-phase design:**
Phase 1 opens handles, queries state, and issues stop controls to all eligible services without sleeping between them. Phase 2 polls all pending services against a single `TimerInit()` / `TimerDiff()` deadline. The architecture's pseudocode is faithfully reproduced. Implemented correctly.

**REQ-004 — Minimum access rights only:**
`OpenSCManagerW` uses `$SM_SC_MANAGER_CONNECT` (0x0001). `OpenServiceW` uses `$SM_SERVICE_QUERY_AND_STOP` = `BitOR($SM_SERVICE_QUERY_STATUS, $SM_SERVICE_STOP)` = 0x0024. No use of `SC_MANAGER_ALL_ACCESS` or `SERVICE_ALL_ACCESS`. Per REQUIREMENTS.md REQ-004: "OpenSCManagerW → SC_MANAGER_CONNECT (0x0001); OpenServiceW for stop → SERVICE_QUERY_STATUS | SERVICE_STOP (0x0024)." Implemented correctly.

**REQ-005 — Every handle exactly one cleanup path:**
Traced all DllCall return values: every `OpenServiceW` handle is closed exactly once on every branch. The SCM handle is closed once at the end. Polling handles are closed inside the Phase 2 loop on success and in the timeout cleanup loop. Implemented correctly.

**REQ-006 — @error captured immediately after DllCall:**
Confirmed at every DllCall site. Implemented correctly.

**REQ-007 — "handle" type string for SC_HANDLE params:**
Every parameter typed as `SC_HANDLE` in the Win32 API uses the AutoIt `"handle"` type string. No `"long"` type appears for handle parameters. Implemented correctly.

**REQ-008 — ControlService receives valid SERVICE_STATUS struct:**
`DllStructCreate("dword;dword;dword;dword;dword;dword;dword")` is used and its pointer passed as `"ptr"`. Matches the architecture's verified pattern exactly. Implemented correctly.

### Missing requirements

**REQ-009 — Deterministic test harness not in this diff (missing):**
The issue checklist (03-build-servicemanager.md) requires: "Write Tests/ServiceManager.Tests.au3 (TDD: red first) — test all 7 service states, stop eligibility, missing service, access denied, single-service failure in a batch, shared timeout, per-row result rows." This file is absent from the diff. The T03 ticket treats the test harness and the module as a single deliverable ("Build ServiceManager.au3 + Deterministic Test Harness"). REQ-009 is unmet by this diff.

### Implementation deviations

**SCM-failure return value deviates from architecture contract (wrong):**
The architecture contract states: `@error=1` means "batch-level failure; returned array has 0 rows." The batch-stop algorithm pseudocode shows: "On failure: SetError(1), return empty array."

The implementation allocates `$aResults[$iCount][6]` before attempting to open the SCM. When `OpenSCManagerW` fails, it sets `@error=1` and returns `$aResults` — a pre-sized array with `$iCount` rows, each pre-populated with `-1` states and empty strings. This is not an empty array; it has `$iCount` rows with partially-initialised default values.

A caller that checks `@error` first (as intended) will never read these rows, so the runtime impact is benign. However, the returned value does not match the contract, which complicates testing and future callers that may inspect `UBound($aResults)` before or alongside `@error`. The fix is a simple early-return before allocation: move the `$aResults` declaration after the successful SCM open.

**Additional internal helpers beyond architecture spec (scope expansion, low severity):**
The architecture's internal helper list specifies three functions: `_SM_GetServiceState`, `_SM_ServiceStateToString`, `_SM_Win32ErrToOutcome`. The implementation adds four more: `_SM_IsStopEligible`, `_SM_StateNeedsPolling`, `_SM_StateToAlreadyStopped`, `_SM_BuildResultRow`. All four are used internally within `_SM_StopServicesBatch` (except `_SM_BuildResultRow`, which is not called from anywhere in this file). The extra helpers do not change the public interface and their intent is clear. This is minor scope expansion beyond the architecture spec; it does not break any requirement.

### Spec summary

8 of 9 in-scope requirements implemented correctly. 1 requirement missing (REQ-009 — test harness). 1 implementation deviation from the architecture contract (SCM-failure returns a pre-sized array instead of an empty array).

---

**Summary:** Standards axis — 0 hard violations, 4 judgement-call smells; worst issue is the Duplicated Code (pending-list append block appears twice, forcing the opaque `$iPendLen2` name). Spec axis — 3 findings: 1 missing deliverable (test harness, REQ-009), 1 implementation wrong against contract (SCM-failure return value), 1 minor scope expansion (extra internal helpers); worst issue is the missing test harness, which is a required co-deliverable of T03.
