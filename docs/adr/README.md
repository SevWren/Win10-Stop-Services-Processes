# Architecture Decision Records

This directory is the authoritative record of significant architectural decisions made in the
Win10-Stop-Services-Processes project. Each file captures one decision: what was decided, why,
and what alternatives were rejected.

---

## Index

| # | Title | Status | Date | Summary |
|---|---|---|---|---|
| 0001 | ServiceManager Module Extraction | Accepted | — | Extract batch service-stop into a new deep module `ServiceManager.au3` with a single public function, structured per-service outcome rows, and one SCM open per batch cycle, replacing the serial `_StopService` path in `ServiceControl.au3`. |
| 0002 | START_PENDING Stop-Ineligible | Accepted | — | Services in `START_PENDING` are never sent a stop control; `_SM_IsStopEligible` returns `False` and the batch records outcome `FAILED` (Win32 1061), deferring the service to the next cycle. |
| 0003 | Batch Stop Two-Level Error Convention | Accepted | — | `_SM_StopServicesBatch` uses `@error 1` only for a batch-level SCM-open failure; individual service failures are expressed as outcome strings in per-row `[i][3]`, not in `@error`. |
| 0004 | ServiceManager Incompatible with ServiceControl Error Convention | Accepted | — | `ServiceManager.au3` deliberately returns a 2D result array rather than the scalar `1`/`0`/`@error` convention used by `ServiceControl.au3`; the two modules must never be used interchangeably for stop operations. |
| 0005 | Graceful-Only Service Stop | Accepted | — | Services are stopped exclusively via `SERVICE_CONTROL_STOP` with no `TerminateProcess` fallback; a service that does not reach `STOPPED` within the batch deadline is marked `TIMED_OUT` and retried on the next cycle. |
| 0006 | Batch-Scoped SCM Handle | Accepted | — | `_SM_StopServicesBatch` opens one SCM handle for the entire batch (not one per service), enabling a single fast-fail abort if the SCM is unavailable and eliminating per-service `OpenSCManagerW` round-trips. |
| 0007 | AutoIt Priority Constants Canonical | Accepted | — | Process priorities are stored and compared internally as AutoIt integers (0–5); Windows API hex priority class values are converted to AutoIt integers once at the read boundary via `_WinAPIPriorityClassToAutoItConst`. |
| 0008 | Direct DllCall to advapi32.dll | Accepted | — | `ServiceManager.au3` calls SCM APIs (`OpenSCManagerW`, `OpenServiceW`, `QueryServiceStatus`, `ControlService`, `CloseServiceHandle`) directly via `DllCall` rather than AutoIt built-ins or `_WinAPI_*` wrappers, to access the full `SERVICE_STATUS` struct and capture `@error` reliably. |
| 0009 | QueryServiceStatus API Selection | Accepted | — | `QueryServiceStatus` with the 7-DWORD `SERVICE_STATUS` struct is used throughout instead of `QueryServiceStatusEx` / `SERVICE_STATUS_PROCESS`, because the batch-stop algorithm only needs `dwCurrentState` and `ControlService` already requires the same 7-DWORD struct. |
| 0010 | *(see ADR file)* | Accepted | — | *(added after T3-08 validation — see `0010-*.md`)* |
| 0011 | ServiceControl/ServiceManager boundary convention | Accepted | 2026-11-12 | Convention-only separation: stop operations in ServiceManager.au3 only |

---

## Validation Notes

The ADRs were cross-checked against `Includes/ServiceManager.au3` and
`Stop Services Processes.au3` as of 2026-11-12. Findings per ADR:

**ADR-0001 — ServiceManager Module Extraction**
Code matches. `_SM_StopServicesBatch` is the sole public function, opens SCM once, issues
batch stop controls without serial waits, returns a `[n][6]` 2D array. `ServiceControl.au3`
is retained and `#include`d alongside `ServiceManager.au3` in the main script.
`_RunServiceBatchStop()` iterates the result array and routes each outcome to `_LogMessage`.
The dependency note in the ADR ("not fully self-contained: depends on `_LogMessage` and
`<WinAPI.au3>`") is confirmed: `ServiceManager.au3` calls `_LogMessage` and
`_WinAPI_GetLastError` directly without wrapping them.

**ADR-0002 — START_PENDING Stop-Ineligible**
Code matches. `_SM_IsStopEligible` returns `False` for any state not in
`{RUNNING, PAUSED, PAUSE_PENDING, CONTINUE_PENDING}`. In `_SM_StopServicesBatch` Phase 1,
a service that falls through the `_SM_StateToAlreadyStopped` and `_SM_StateNeedsPolling`
checks (covering `START_PENDING`) reaches the `Not _SM_IsStopEligible` branch, records
outcome `FAILED` with `$SM_ERR_CANNOT_ACCEPT` (1061), and closes the handle without sending
a stop control. `$SVC_POLL_INTERVAL_SEC = 10` confirmed in the main script.

**ADR-0003 — Batch Stop Two-Level Error Convention**
Code matches. `SetError(1)` is called only in the SCM-open failure path. All per-service
failures are written to `$aResults[$i][3]` as outcome strings. `@error` is `0` on the
normal `Return $aResults` path even when individual rows contain `FAILED` or `TIMED_OUT`.
`_RunServiceBatchStop` checks `@error` first, then iterates the array — the correct usage.

**ADR-0004 — ServiceManager Incompatible with ServiceControl Error Convention**
Code matches. `ServiceControl.au3` functions return `1`/`0` and encode Win32 errors in
`@error`. `_SM_StopServicesBatch` returns a 2D array and uses `@error` only for
batch-level SCM failure. Both modules are `#include`d in the main script without conflict.

**ADR-0005 — Graceful-Only Service Stop**
Code matches. `_SM_StopServicesBatch` sends `SERVICE_CONTROL_STOP` and polls for
`$SM_STATE_STOPPED`; no `TerminateProcess` or `ProcessClose` call exists in
`ServiceManager.au3`. Services remaining in `$aPendingIdx` after the Phase 2 loop exits
are marked `TIMED_OUT`. The batch timeout constant `$SVC_BATCH_TIMEOUT_MS = 20000` is
confirmed in the main script.

**ADR-0006 — Batch-Scoped SCM Handle**
Code matches. `OpenSCManagerW` is called once at the top of `_SM_StopServicesBatch`. On
failure, `SetError(1)` returns a zero-row array immediately with no per-service work. On
success, `$hSCM` is passed to every `OpenServiceW` in Phase 1 and `CloseServiceHandle` is
called on `$hSCM` once after the Phase 2 poll loop and timeout cleanup.

**ADR-0007 — AutoIt Priority Constants Canonical**
Code matches. `$aPriorityWatchTargets[]` stores AutoIt integers (0–5). `_GetProcessPriorityByPID`
calls `_WinAPIPriorityClassToAutoItConst` before returning. `ProcessSetPriority` call sites
use the AutoIt constants directly. The named constants `$AUTOIT_PRIORITY_IDLE` through
`$AUTOIT_PRIORITY_REALTIME` are defined in the main script's configuration region.

**ADR-0008 — Direct DllCall to advapi32.dll**
Code matches. All five SCM API calls in `ServiceManager.au3` use
`DllCall("advapi32.dll", ...)` directly. The capture-immediately pattern
(`Local $iDllErr = @error` on the line after `DllCall`, then
`Local $iWinErr = _WinAPI_GetLastError()` before any other call) is applied consistently
throughout Phase 1 and Phase 2 of `_SM_StopServicesBatch` and in `_SM_GetServiceState`.
No `_WinAPI_*` wrappers are used for advapi32.dll calls.

**ADR-0009 — QueryServiceStatus API Selection**
Code matches. `DllStructCreate("dword;dword;dword;dword;dword;dword;dword")` (7 DWORDs) is
used at every query site. `QueryServiceStatusEx` does not appear anywhere in
`ServiceManager.au3`. `dwCurrentState` is read as struct field 2 (`DllStructGetData($t, 2)`)
in both Phase 1 and the Phase 2 poll loop.

**Note:** ADR-0010 and ADR-0011 were added after the T3-08 validation pass (which covered
ADRs 0001–0009, all passing). These two ADRs have not yet been cross-checked against the
codebase.

---

## How to Read ADRs

### Structure of each file

ADRs in this project follow a lightweight format defined in
`CLAUDE/skills/domain-modeling/ADR-FORMAT.md`:

- **Title (H1)** — a short statement of the decision, written as a fact, not a question.
- **Context paragraph** — what situation made this decision necessary and what constraint or
  goal was driving it.
- **Considered Options** *(optional)* — alternatives that were evaluated and the specific
  reasons each was accepted or rejected. Present when the rejected paths are worth remembering
  so a future contributor does not re-propose them.
- **Consequences** *(optional)* — downstream effects that are non-obvious, including both
  positive outcomes and permanent constraints the decision imposes on future work.
- **Status** *(optional frontmatter)* — one of `proposed`, `accepted`, `deprecated`, or
  `superseded by ADR-NNNN`. When absent, treat the ADR as accepted.

An ADR can be a single paragraph. The goal is to record *that* a decision was made and *why*,
not to fill out a template.

### When to create a new ADR

Create a new ADR only when **all three** of the following are true
(from `CLAUDE/skills/domain-modeling/SKILL.md`):

1. **Hard to reverse** — changing the decision later would have meaningful cost (rework,
   breakage, or data migration).
2. **Surprising without context** — a future reader looking at the code would wonder "why on
   earth did they do it this way?" without the ADR.
3. **The result of a real trade-off** — there were genuine alternatives and you chose one for
   specific reasons.

If any criterion is missing, skip the ADR. Easy reversals do not need records. Obvious
decisions do not need explanation. If there was no real alternative, there is nothing to record
beyond "we did the obvious thing."

### Numbering

Scan `docs/adr/` for the highest existing number and increment by one. Use four-digit
zero-padded numbers: `0010-slug.md`, `0011-slug.md`, etc.

### Where to find related documentation

| Resource | Location |
|---|---|
| Domain glossary | `GLOSSARY.md` (repo root) |
| Architecture overview | `docs/ARCHITECTURE.md` |
| Coding standards (naming, logging, regions) | `CODING_STANDARDS.md` (repo root) |
| ADR format template | `CLAUDE/skills/domain-modeling/ADR-FORMAT.md` |
| Domain modeling skill (when to create ADRs) | `CLAUDE/skills/domain-modeling/SKILL.md` |
| Agent domain configuration | `docs/agents/domain.md` |
