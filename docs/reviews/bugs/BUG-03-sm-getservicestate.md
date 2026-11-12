# BUG-03: `_SM_GetServiceState` — Dead Code (Speculative Generality)

**Flagged by:** CR2-04
**Referenced in:** CR2-03 ("presumably reserved for the test harness from Ticket T03")
**File:** `Includes/ServiceManager.au3`
**Date:** 2026-11-12
**Status:** RESOLVED — function deleted

---

## Investigation Summary

### 1. Definition location

`_SM_GetServiceState($hService)` is defined at lines 397–410 of
`Includes/ServiceManager.au3`. It wraps a single `QueryServiceStatus` DllCall and
returns the integer `dwCurrentState` (1–7) or -1 on failure.

It is listed in the file header's INTERNAL HELPERS block (line 19) and in the
module map, giving the false impression it is a used internal helper.

### 2. Callers within `Includes/ServiceManager.au3`

**Zero.** A full-file grep for `_SM_GetServiceState` returns only:

- line 19 — header comment listing the function name
- line 383 — Func doc-comment block header
- line 397 — `Func _SM_GetServiceState(` definition
- line 405 — `_LogMessage` call inside the function's own error path
- line 410 — `EndFunc` marker

No call site exists anywhere inside the module. `_SM_StopServicesBatch` inlines the
identical `QueryServiceStatus` DllCall pattern directly at every query point
(Phase 1 initial query at line 228, Phase 2 poll at line 325).

### 3. `Tests/ServiceManager.Tests.au3` — does the test harness call it?

**No.** A complete read of `Tests/ServiceManager.Tests.au3` (525 lines) shows no
reference to `_SM_GetServiceState`. The test harness exercises:

- `_SM_ServiceStateToString` (pure mapping)
- `_SM_Win32ErrToOutcome` (pure mapping)
- `_SM_IsStopEligible` (pure logic)
- `_SM_StateNeedsPolling` (pure logic)
- `_SM_StateToAlreadyStopped` (pure logic)
- `_SM_BuildResultRow` (row construction)
- `_SM_StopServicesBatch` (integration)

CR2-03's claim that the function is "reserved for the test harness from Ticket T03"
is incorrect. Ticket T03's test harness was built without it; it was never needed.

### 4. `Stop Services Processes.au3` — any calls?

**No.** The main script includes `ServiceManager.au3` but calls only
`_SM_StopServicesBatch` (via `_RunServiceBatchStop` at line 233). No reference to
`_SM_GetServiceState` exists anywhere in the main script.

### 5. Is the function actually useful?

`_SM_GetServiceState` does exactly what `_SM_StopServicesBatch` already does inline
at two points (Phase 1 and Phase 2 poll). The inline DllCall pattern is intentional:
Phase 1 and Phase 2 each own their own `DllStructCreate` + `DllCall` +
immediate `@error` capture to satisfy the AutoIt volatile-`@error` constraint
(CLAUDE.md "AutoIt Version Compatibility Notes"). Extracting this into a helper
function would require passing `@error` capture state back across the call boundary,
which is awkward in AutoIt 3 and was explicitly avoided in the module design.

The function adds no value that the inlined pattern does not already provide.

### 6. Architecture decision: Keep or Delete?

**Delete.** The function is Speculative Generality (Martin Fowler: code that serves
no present caller, written in anticipation of a future need that never arrived).
Specific grounds:

- Not called from production code (`_SM_StopServicesBatch`)
- Not called from the test harness (`Tests/ServiceManager.Tests.au3`)
- Not called from the main script (`Stop Services Processes.au3`)
- Not referenced in any backup file
- The module already inlines the same DllCall pattern directly — there is no DRY
  violation being avoided
- Keeping it creates false documentation surface: the header listing it as an
  "INTERNAL HELPER" implies it is used

**If the team ever wanted a single-handle query helper**, the correct approach at
that point would be to introduce it with a concrete call site, not retain dead code
speculatively.

### 7. External caller audit

Grep across all `.au3` files in the repo finds zero external callers. Deletion is
safe. No coordination with BUG-02 agent is required (BUG-02 owns a separate function
in the same file; `_SM_GetServiceState` has no overlap with its scope).

---

## Fix Applied

The function definition (lines 382–410, including doc-comment block) was deleted
from `Includes/ServiceManager.au3`. The file header listing in the INTERNAL HELPERS
comment block (line 19) was also removed to keep the documented interface consistent
with the actual code.

The two inline `QueryServiceStatus` DllCall patterns in `_SM_StopServicesBatch`
(Phase 1 and Phase 2) are **unchanged** — they are correct and intentionally inlined.
