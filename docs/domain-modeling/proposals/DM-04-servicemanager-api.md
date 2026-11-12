# DM-04 — ServiceManager API: Domain-Model Analysis

**Date**: 2026-11-12
**Focus**: `Includes/ServiceManager.au3` public API — functions, return values, error types, and the contracts they represent.
**Status**: Proposal — do not modify GLOSSARY.md directly; apply after review.

---

## 1. What Was Examined

- `Includes/ServiceManager.au3` (the full file, 494 lines)
- `Includes/ServiceControl.au3` (the legacy module it partially supersedes)
- `GLOSSARY.md` (current state)
- `docs/ARCHITECTURE.md` (public contract specification)
- `docs/wiki/decisions.md` (D-001, D-002)
- `docs/reviews/REVIEW-ServiceManager.au3.md` (independent code review)

---

## 2. Public API Catalogue

### 2.1 The only public function

```
_SM_StopServicesBatch(ByRef $aServiceNames [, $iBatchTimeoutMs [, $iPollIntervalMs]])
```

**Parameters**

| Name | Type | Direction | Description |
|---|---|---|---|
| `$aServiceNames` | 1D array of strings | ByRef (read-only semantically) | Service names to stop |
| `$iBatchTimeoutMs` | integer | in | Shared deadline in ms (default 20000) |
| `$iPollIntervalMs` | integer | in | Sleep between polls in ms (default 500) |

**Return value**

A 2D array `[n][6]` — one row per input service. Columns:

| Index | Name | Type | Meaning |
|---|---|---|---|
| `[i][0]` | Service Name | string | Copy of the input service name |
| `[i][1]` | Initial State | integer 1–7 or -1 | State at first `QueryServiceStatus`; -1 = unavailable |
| `[i][2]` | Final State | integer 1–7 or -1 | State after polling; -1 = never queried |
| `[i][3]` | Outcome | string constant | One of: `STOPPED`, `ALREADY_STOPPED`, `UNAVAILABLE`, `FAILED`, `TIMED_OUT` |
| `[i][4]` | Win32 Error | integer | Win32 error code at last failure; 0 = no error |
| `[i][5]` | Note | string | Human-readable note; empty string if none |

**`@error` macro**

| Value | Meaning |
|---|---|
| 0 | Batch was processed; inspect per-row `Outcome` for individual results |
| 1 | SCM could not be opened (batch-level failure); returned array has zero rows |

**Empty-input contract**: if `$aServiceNames` has zero elements, returns a zero-row 2D array `[0][6]` with `@error = 0`. This is not an error.

### 2.2 Internal helpers (not called from the main script)

These are exposed for the test harness only. They are not part of the public API for production callers.

| Function | Purpose | Returns |
|---|---|---|
| `_SM_GetServiceState($hService)` | Queries a single open service handle's current state | Integer 1–7, or -1 on error; `@error 1` on failure |
| `_SM_ServiceStateToString($iState)` | Maps state integer to a human-readable string | String; `"UNKNOWN"` for unrecognised values |
| `_SM_Win32ErrToOutcome($iWin32Err)` | Maps a Win32 error to an Outcome string | `ALREADY_STOPPED` (1062), `UNAVAILABLE` (1060), or `FAILED` (all others) |
| `_SM_IsStopEligible($iState)` | True if the state can receive `SERVICE_CONTROL_STOP` | Boolean |
| `_SM_StateNeedsPolling($iState)` | True if already in `STOP_PENDING` | Boolean |
| `_SM_StateToAlreadyStopped($iState)` | True if already `STOPPED` | Boolean |
| `_SM_BuildResultRow(...)` | Constructs a single 6-element result row | 1D array `[6]` |

---

## 3. Domain-Modeling Questions and Findings

### 3.1 "ServiceHandle" vs "SCM Handle" — are these the same type?

**Finding: they are the same Win32 type (`SC_HANDLE`) but represent distinct domain objects with different lifecycles and access rights.**

Both `$hSCM` and `$hService` are `SC_HANDLE` values returned by `advapi32.dll`. However:

- The **SCM Handle** (`$hSCM`) is opened once per batch call against `OpenSCManagerW` with `SC_MANAGER_CONNECT`. Its scope is the entire batch operation. It is never passed to callers.
- A **Service Handle** (`$hService`) is opened per-service against `OpenServiceW` with `SERVICE_QUERY_STATUS | SERVICE_STOP`. Its scope is a single service within the batch. Some service handles are held open across Phase 1 and Phase 2 (the pending list); others are closed immediately after their Phase 1 routing decision.

The GLOSSARY.md currently defines "Service Handle" (the per-service variant) but does not define "SCM Handle" as a separate term. This gap is real: the two objects have different access rights, different lifetimes, and different failure modes. A caller reading the glossary cannot tell them apart.

**Proposal for GLOSSARY.md** (see Section 5 below):
- Retain "Service Handle" with a tightened definition.
- Add "SCM Handle" as a distinct term.

### 3.2 "ServiceName" vs "DisplayName" — distinct types or the same thing?

**Finding: they are distinct types, but only `ServiceName` is used in this module. `DisplayName` does not appear.**

The Windows SCM distinguishes:
- **Service Name** (`lpServiceName`): the short internal identifier used in registry keys and by all SCM API calls (`OpenServiceW`, `QueryServiceStatus`, `ControlService`). Examples: `"wuauserv"`, `"TrustedInstaller"`.
- **Display Name** (`lpDisplayName`): the human-readable label shown in `services.msc`. Example: `"Windows Update"`.

`_SM_StopServicesBatch` takes and returns `ServiceName` values only. The `$aServiceNames` parameter, `Result Row[i][0]`, and all log messages use the internal service name. `DisplayName` is never involved.

`ServiceControl.au3`'s `_CreateService` accepts a `$sDisplayName` parameter, so the distinction matters across the two modules even though it is invisible within ServiceManager.

**Proposal for GLOSSARY.md** (see Section 5): Add `ServiceName` and `DisplayName` as explicit, distinct terms. The current glossary does not define either. `ServiceName` is used throughout the codebase; its absence is a real gap.

### 3.3 Is the error/success convention consistent across the module?

**Finding: yes, with one intentional asymmetry that is documented but not named.**

The module uses two levels of error reporting:

**Level 1 — Batch-level failure**: `SetError(1)` + return the (unpopulated) result array. Used only when `OpenSCManagerW` fails. The returned array has zero rows in this case.

**Level 2 — Per-service outcome**: encoded in `Result Row[i][3]` (the Outcome string). Used for all individual service results. `@error` is 0 (success at the batch level) even when individual services have `FAILED` or `TIMED_OUT` outcomes.

This two-level convention is internally consistent and is documented in the architecture spec. However:
- The asymmetry between "SCM failure = `@error 1`" and "per-service failure = outcome string in a row" is a deliberate design decision that is not obvious from the function signature alone.
- `_SM_GetServiceState` uses `@error` in a third style: `0 = ok`, `1 = DllCall/query failed`. This is consistent with standard AutoIt helper conventions but differs from `_SM_StopServicesBatch`'s batch-level @error.

**Proposed ADR**: see ADR-001 below.

### 3.4 Is "SCM Handle" vs "Service Handle" clearly defined in the glossary?

**Finding: no. The current GLOSSARY.md defines "Service Handle" but not "SCM Handle".**

The current definition of "Service Handle" is:
> An opaque value returned by `OpenServiceW` that grants the rights requested. Every acquired service handle must be released with exactly one `CloseServiceHandle` call.

This is correct but incomplete. The glossary does not mention that `OpenSCManagerW` returns a structurally identical `SC_HANDLE` for the SCM itself, that it also requires `CloseServiceHandle` for release, and that the two serve different roles. A reader of the code will encounter `$hSCM` and `$hService` as separate variables and wonder if they have different types — the glossary gives no guidance.

**Proposal**: Add "SCM Handle" as a distinct term.

### 3.5 Is "Batch Stop" a module-level concept?

**Finding: yes. The existing glossary definition is correct but undersells the two-phase nature.**

The GLOSSARY.md currently defines "Batch Stop" as:
> A single call to `_SM_StopServicesBatch()` that opens SCM once, issues stop controls to all eligible services without serial waiting, then polls all pending services against one shared deadline, and returns one result row per input service.

This is accurate. The key domain property — "opens SCM once" — is captured. However the definition does not make it clear that the shared-deadline polling (Phase 2) is what makes this "batch" rather than "serial": services are not stopped one-at-a-time with their own independent timeouts. The deadline is shared across all services.

The term is well-placed in the glossary. No new term is needed. A minor refinement of the definition is proposed below.

### 3.6 "Result Row" — adequately defined?

**Finding: the current definition is accurate but column index 5 (`$sNote`) is omitted.**

The current definition states:
> A six-element array `[$sName, $iInitialState, $iFinalState, $sOutcome, $iWin32Error, ""]`

The trailing `""` is the note field. Its meaning is not stated, nor is it named. The note field can carry substantive content in two cases: `START_PENDING` (a stop was not attempted) and `TIMED_OUT` (deadline exceeded message). These are not mere empty placeholders.

**Proposal**: Revise the "Result Row" definition to name column 5 explicitly.

### 3.7 ServiceControl.au3 error conventions — comparison with ServiceManager

**Finding: the two modules use incompatible error conventions. This is a real terminology risk.**

`ServiceControl.au3` functions (`_StopService`, `_StartService`, etc.) use the convention:
- Return `1` on success.
- Return `0` on failure, with `SetError($lError)` where `$lError` is the raw Win32 error code.

`ServiceManager.au3` uses:
- Return a 2D array; `@error 0` = batch processed, `@error 1` = SCM failure.
- Per-service outcomes encoded as strings in result rows, not in `@error`.

A caller who calls `_SM_StopServicesBatch` with the same mental model as `_StopService` will misread `@error 0` on a batch that had multiple `FAILED` rows as "everything succeeded". This is the fundamental reason D-002 was needed: `_StopService`'s success/failure semantics cannot express per-service outcome. The difference in return conventions is not documented at the glossary level.

**Proposed ADR**: see ADR-002 below.

---

## 4. Proposed Glossary Changes

These are proposals only. Do not apply directly to GLOSSARY.md without review.

### 4.1 New term: SCM Handle

**SCM Handle**:
An opaque `SC_HANDLE` value returned by `OpenSCManagerW` that grants the caller the right to open individual services on the local machine. Within a batch stop, one SCM Handle is held for the duration of the entire batch and released by `CloseServiceHandle` before the function returns.
_Avoid_: SCM handle, manager handle, hSCM (code variable names do not belong in the glossary)

### 4.2 Revise: Service Handle

The existing definition is correct. Proposed addition to distinguish it from SCM Handle:

**Service Handle**:
An opaque `SC_HANDLE` value returned by `OpenServiceW` for a specific named service, granting the access rights requested (e.g., `SERVICE_STOP`, `SERVICE_QUERY_STATUS`). Every acquired Service Handle must be released with exactly one `CloseServiceHandle` call. A Service Handle is distinct from an SCM Handle: it refers to one service, not to the manager itself.
_Avoid_: service object handle, hService (code variable names do not belong in the glossary)

### 4.3 New term: Service Name

**Service Name**:
The short internal identifier for a Windows service — the string passed to `OpenServiceW` and stored in the registry under `HKLM\SYSTEM\CurrentControlSet\Services`. This is what `_SM_StopServicesBatch` accepts and what `Result Row[0]` contains. Examples: `"wuauserv"`, `"TrustedInstaller"`.
_Avoid_: service key, service identifier, service string

### 4.4 New term: Display Name

**Display Name**:
The human-readable label for a Windows service shown in `services.msc` and Task Manager. Distinct from Service Name. `ServiceManager.au3` does not use or return Display Names — all operations use Service Names exclusively.
_Avoid_: service label, friendly name

### 4.5 Revise: Result Row — add explicit column-5 definition

**Result Row**:
A six-element array `[$sName, $iInitialState, $iFinalState, $sOutcome, $iWin32Error, $sNote]` returned for each service in a Batch Stop. `$sOutcome` is one of: `STOPPED`, `ALREADY_STOPPED`, `UNAVAILABLE`, `FAILED`, `TIMED_OUT`. `$sNote` carries a human-readable explanation when the outcome requires one (e.g., `"Service in START_PENDING state; stop control not accepted"` or `"Deadline exceeded (20000ms)"`); empty string otherwise.

### 4.6 Revise: Batch Stop — clarify shared-deadline property

**Batch Stop**:
A single call to `_SM_StopServicesBatch()` that opens SCM once, issues stop controls to all eligible services without serial waiting (Phase 1), then polls all pending services against one **shared** deadline — not a per-service timeout — and returns one Result Row per input service (Phase 2). The shared deadline means a slow service and a fast service both count against the same clock.

---

## 5. ADR Proposals

Two decisions meet all three ADR criteria (hard to reverse, surprising without context, result of a real trade-off). Both are proposed as new ADRs in `docs/adr/`.

See companion files:
- `docs/adr/0003-batch-stop-two-level-error-convention.md`
- `docs/adr/0004-servicemanager-incompatible-with-servicecontrol-error-convention.md`

---

## 6. Issues Not Requiring Glossary or ADR Treatment

The following observations were made during the analysis but do not warrant GLOSSARY.md entries (they are implementation details, not domain vocabulary) or ADRs (they are either easily reversible or already documented elsewhere):

- **`_SM_GetServiceState` and `_SM_BuildResultRow` are "test-support exports"**: The review (REVIEW-ServiceManager.au3.md, STD-004, STD-005) already flags that these helpers have no internal call sites and exist only for the test harness. This is an implementation boundary decision, not a domain term. No ADR needed — the REVIEW document captures it.
- **`$hAdvapi32` parameter absent from `_SM_GetServiceState`**: REVIEW SPEC-001 (MAJOR) documents the divergence between ARCHITECTURE.md's two-parameter signature and the one-parameter implementation. The resolution belongs in a code fix and an architecture doc update, not in the domain model.
- **`_SM_Win32ErrToOutcome` dead branch for error 1060 from ControlService**: REVIEW SPEC-002 flags this. It is a comment-accuracy issue, not a domain concept.
- **`ByRef` on `$aServiceNames`**: This is a performance choice (avoid array copy on call). It does not affect the domain contract — the function treats the array as read-only. No ADR needed; the reason (AutoIt's pass-by-value-copies-arrays behaviour) is a language-level detail.
