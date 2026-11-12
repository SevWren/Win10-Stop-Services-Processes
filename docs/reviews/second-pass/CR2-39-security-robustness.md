# CR2-39 — Security and Robustness Review
**Files:** `Includes/ServiceManager.au3`, `Stop Services Processes.au3`
**Date:** 2026-11-12
**Reviewer:** Second-pass automated analysis
**Scope:** Handle leaks, TOCTOU, integer overflow, array bounds, null-handle checks, privilege escalation

---

## 1. Handle Leaks — OpenSCManagerW / OpenServiceW

### 1.1 SCM Handle (`$hSCM`)

`OpenSCManagerW` is called once at line 170. The handle is assigned to `$hSCM` at line 184 (only reached if the call succeeds). There is exactly one `CloseServiceHandle($hSCM)` call, at line 376, executed unconditionally after Phase 1 and Phase 2 complete.

**Exit paths from `_SM_StopServicesBatch`:**

| Exit path | Line | $hSCM closed? |
|---|---|---|
| Empty input (`$iCount = 0`) | 144 | N/A — SCM was never opened |
| `OpenSCManagerW` failure | 182 | N/A — `$hSCM` never assigned; early return before line 184 |
| Normal completion | 378 | Yes — line 376 |

**Finding:** No SCM handle leak on any exit path. PASS.

### 1.2 Service Handles (`$hService`)

`OpenServiceW` is called once per iteration inside the Phase 1 loop (line 203). On failure the code uses `ContinueLoop` without calling `CloseServiceHandle` (line 219) — this is correct because no handle was successfully obtained when `$aSvcOpen[0]` is null/zero.

Each path that successfully opens `$hService` is traced below:

| Branch | Disposition | CloseServiceHandle call |
|---|---|---|
| `OpenServiceW` failure (null handle) | `ContinueLoop` with no close | Correct — handle not opened |
| `QueryServiceStatus` failure | `CloseServiceHandle($hService)` + `ContinueLoop` | Line 237 |
| State = ALREADY_STOPPED | `CloseServiceHandle($hService)` + `ContinueLoop` | Line 250 |
| State = STOP_PENDING (needs polling) | Handle stored in `$aPendingHnd[]`; closed in Phase 2 or timeout sweep | See §1.3 |
| State = START_PENDING (not stop-eligible) | `CloseServiceHandle($hService)` + `ContinueLoop` | Line 271 |
| `ControlService` failure | `CloseServiceHandle($hService)` + `ContinueLoop` | Line 297 |
| Stop control accepted (pending) | Handle stored in `$aPendingHnd[]`; closed in Phase 2 or timeout sweep | See §1.3 |

**Finding:** Every Phase 1 path that obtains a service handle either closes it immediately or transfers it to `$aPendingHnd[]` for deferred closure. No Phase 1 leak. PASS.

### 1.3 Pending Service Handles (`$aPendingHnd[]`)

Handles in `$aPendingHnd[]` are closed in two places:

- **Phase 2 poll loop** (line 343): when `QueryServiceStatus` reports `STOPPED`, the handle is closed and the entry removed from the pending arrays.
- **Timeout sweep** (line 371): after the Phase 2 `While` loop exits (timeout or empty list), any remaining entries in `$aPendingHnd[]` are iterated and each handle is closed.

**Gap identified — Phase 2 poll query failure path (lines 329–332):**
When `QueryServiceStatus` fails during polling (`$iPollDllErr Or Not $aPoll[0]`), the code logs and calls `ContinueLoop`, leaving the handle in `$aPendingHnd[]`. This is intentional — it defers to the next tick rather than abandoning the handle. The handle will eventually be closed either when polling succeeds and the service stops, or when the timeout sweep runs. The handle is never orphaned. PASS (by design — deferred retry is documented).

**Finding:** No pending handle leaks. PASS.

---

## 2. TOCTOU Vulnerabilities in `_PriorityWatchdog`

DM-02 flagged TOCTOU as a known concern. The implemented mitigations are:

**In `LockProcessPriority` (the registration path):**
- Step 1 validates the PID with `ProcessExists($iPID)` at line 391.
- Step 3 (lines 437–442) performs an explicit TOCTOU re-check with a second `ProcessExists($iPID)` call immediately before `ProcessSetPriority`, with a comment reading "TOCTOU re-check then apply priority immediately". If the PID has exited between input and set, the function returns without registering the watchdog.

**In `_PriorityWatchdog` (the drift-correction path):**
- Line 474: `ProcessExists($iPID)` check at top of each loop iteration — removes dead PIDs.
- Lines 493–501: second explicit TOCTOU re-check (`ProcessExists($iPID)`) between drift detection (line 489) and the `ProcessSetPriority` restore call (line 503), with a comment "TOCTOU re-check before restore". If the PID exits in that window, the entry is removed and the restore is skipped.

**Remaining residual window (not a defect, documented):**
A race exists between the second `ProcessExists` call and `ProcessSetPriority` itself. If the PID exits in that sub-millisecond window, `ProcessSetPriority` will fail and the failure is caught at line 507 (the `Else` branch logs the error). This is the irreducible minimum TOCTOU window in a user-mode process manager — it cannot be closed without kernel-level atomic primitives. The failure path is handled gracefully. This matches the DM-02 characterisation of the concern as "known" and accepted.

**Finding:** DM-02 concern addressed. The TOCTOU window between detection and restore is explicitly mitigated with a re-check guard, and the remaining irreducible race is handled by the `ProcessSetPriority` failure path. PASS with known accepted residual.

---

## 3. Integer Overflow

### 3.1 `TimerDiff` return values

AutoIt's `TimerDiff` returns a double-precision floating-point value (milliseconds elapsed). The comparisons in question are:

- `ServiceManager.au3` line 316: `TimerDiff($iTimer) < $iBatchTimeoutMs`
  — `$iBatchTimeoutMs` default is 20000 (ms). Double comparison. No integer arithmetic performed.
- `Stop Services Processes.au3` line 292: `TimerDiff($iStartTime) >= ($iInterval * 1000)`
  — `$iInterval` is at most `$SVC_POLL_INTERVAL_SEC = 10`. `10 * 1000 = 10000`. Well within any integer range.

Both comparisons are between a double (TimerDiff result) and a small integer or constant. AutoIt performs implicit widening to double for the comparison. No overflow is possible in these expressions.

### 3.2 Service state integers

Service state values are Win32 `DWORD` values in the range 1–7, read via `DllStructGetData` into AutoIt variables. All comparisons are against named constants (e.g., `$SM_STATE_STOPPED = 1`). No arithmetic is performed on these values — they are used only in `Switch`/`Case` and equality comparisons.

### 3.3 Win32 error codes

Win32 error codes (e.g., `$SM_ERR_SVC_NOT_EXIST = 1060`, `$SM_ERR_CANNOT_ACCEPT = 1061`) are `DWORD` values compared by equality. No arithmetic is performed on them.

**Finding:** No integer overflow risk identified in any arithmetic expression in either file. PASS.

---

## 4. Array Bounds

### 4.1 `$aServiceNames` (input parameter)

`UBound($aServiceNames)` is called at line 139 to establish `$iCount`. The loop `For $i = 0 To $iCount - 1` is standard AutoIt idiom and cannot exceed bounds. The empty-input guard at line 142 (`If $iCount = 0`) returns early before any array access.

### 4.2 `$aResults` (result array)

Declared with `Local $aResults[$iCount][6]` at line 148. All accesses use the loop variable `$i` bounded by `$iCount - 1`, and column indices are literal values 0–5. No bounds risk.

### 4.3 `$aPendingIdx` / `$aPendingHnd` (parallel dynamic arrays)

Both arrays are grown with `ReDim` before writing to `$iPendLen` (the previously-computed `UBound`). Reads in Phase 2 use `$j = UBound($aPendingIdx) - 1 To 0 Step -1`, which is safe even at zero length (AutoIt's `For … Step -1` does not execute when upper bound < lower bound). Removal uses a backward-iteration shrink pattern that correctly adjusts array size before the next iteration accesses it.

The timeout sweep at line 365 uses `For $iTimeoutIdx = 0 To UBound($aPendingIdx) - 1`, which is safe; if `$aPendingIdx` is empty `UBound` returns 0 and `0 To -1` does not execute.

### 4.4 `$aPriorityWatchPIDs` / `$aPriorityWatchTargets` / `$aPriorityWatchNames`

The watchdog loop at line 469 iterates `UBound($aPriorityWatchPIDs) - 1 To 0 Step -1`. `_ArrayDelete` is called on the same array being iterated — the backwards iteration is the correct pattern to handle shrinking during iteration without skipping elements or accessing out-of-bounds indices.

### 4.5 `$sProcesses` in `_KillProcessList`

`$sProcesses[18]` is declared at line 96. The loop at line 210 uses `UBound($sProcesses) - 1` as the upper bound. No manual index arithmetic. PASS.

**Finding:** No array bounds violations identified. PASS.

---

## 5. Null / Invalid Handle Checks

### 5.1 `OpenSCManagerW`

Lines 174–183: `@error` is captured immediately after the DllCall. The condition `$iScmDllErr Or Not $aScmOpen[0]` checks both the DllCall transport error and the returned handle being null/zero. On failure the function returns a zero-row array with `@error=1`. `$hSCM` is only assigned at line 184, which is unreachable if the check fails. PASS.

### 5.2 `OpenServiceW`

Lines 207–220: `@error` captured immediately. Condition `$iSvcDllErr Or Not $aSvcOpen[0]` checks both failure modes. `$hService` is only assigned at line 221, which is unreachable on the failure path. PASS.

### 5.3 `OpenProcess` in `_GetProcessPriorityByPID`

Lines 533–538: `@error Or Not $aOpen[0]` guard. On failure, returns -1 without attempting `GetPriorityClass`. The process handle is closed via `CloseHandle` at line 543 immediately after `GetPriorityClass`, before any further logic that could use it. PASS.

### 5.4 `QueryServiceStatus` calls

Both the Phase 1 query (lines 231–239) and Phase 2 poll (lines 328–333) check `$iQryDllErr Or Not $aQuery[0]` / `$iPollDllErr Or Not $aPoll[0]` before reading the status struct. `DllStructGetData` is not called on a failed struct pointer. PASS.

**Finding:** All handle validity checks are present and correctly positioned. PASS.

---

## 6. Privilege Escalation

### 6.1 `#RequireAdmin` in the test harness

`Tests/ServiceManager.Tests.au3` carries `#RequireAdmin` at line 1. Lines 3–12 of that file contain a scope note explaining that the directive applies to the entire test process, and that tests which do not open a live SCM handle could in principle be separated into a no-admin harness. This is a known and documented judgement call (previously flagged as finding S-05 in CR-03), not an unexamined risk.

The test harness is a development-time artifact. It is not compiled into the production release (`release/Stop Services - Processes.exe`). `#RequireAdmin` in the test harness does not affect the production binary in any way.

### 6.2 `#RequireAdmin` in the production script

`Stop Services Processes.au3` line 1 carries `#RequireAdmin`. This directive causes the AutoIt runtime to request UAC elevation when the compiled executable is launched. This is functionally required: `OpenSCManagerW` with `SC_MANAGER_CONNECT` and `OpenServiceW` with `SERVICE_STOP` both require the calling process to hold `SeServiceLogonRight` or be a member of the Administrators group. The script cannot function without elevation.

**Privilege minimisation analysis:** `ServiceManager.au3` requests only `SC_MANAGER_CONNECT` (0x0001) on the SCM handle and only `SERVICE_QUERY_STATUS | SERVICE_STOP` (0x0024) on each service handle. These are the documented minimum rights. The comment at lines 72–73 reads: "Minimum rights per operation — do not expand these without documented justification." No overly-broad rights (e.g., `SC_MANAGER_ALL_ACCESS`, `SERVICE_ALL_ACCESS`) are used. PASS.

### 6.3 Scope isolation

`ServiceManager.au3` uses `#include-once` (line 38) to prevent duplicate inclusion. It does not contain `#RequireAdmin` itself — that directive lives only in the top-level scripts (`Stop Services Processes.au3` and `Tests/ServiceManager.Tests.au3`). There is no mechanism by which including `ServiceManager.au3` could independently elevate a consumer that does not carry `#RequireAdmin`.

**Finding:** Privilege requirements are functionally necessary, correctly scoped, and use minimum-access constants. The test harness `#RequireAdmin` is documented and isolated from production. No privilege escalation risk. PASS.

---

## Summary Table

| Check | File(s) | Verdict | Notes |
|---|---|---|---|
| H-01: SCM handle closed on all exit paths | ServiceManager.au3 | PASS | Early returns are pre-assignment; normal path closes at line 376 |
| H-02: Service handle closed on all Phase 1 paths | ServiceManager.au3 | PASS | Each branch closes immediately or defers to Phase 2 / timeout sweep |
| H-03: Pending handles closed on Phase 2 success | ServiceManager.au3 | PASS | Line 343 |
| H-04: Pending handles closed on timeout | ServiceManager.au3 | PASS | Lines 365–372 |
| H-05: Poll-failure path does not orphan handles | ServiceManager.au3 | PASS | Deferred retry; timeout sweep is the backstop |
| T-01: TOCTOU re-check in LockProcessPriority | Stop Services Processes.au3 | PASS | Lines 437–442 |
| T-02: TOCTOU re-check in _PriorityWatchdog drift path | Stop Services Processes.au3 | PASS | Lines 493–501 |
| T-03: Residual TOCTOU window between re-check and set | Stop Services Processes.au3 | ACCEPTED | Irreducible user-mode race; failure path handled at line 507 |
| I-01: TimerDiff arithmetic overflow | Both | PASS | Double return type; operands small |
| I-02: Service state integer overflow | ServiceManager.au3 | PASS | Range 1–7; comparison only, no arithmetic |
| I-03: Win32 error code overflow | ServiceManager.au3 | PASS | Equality comparison only |
| A-01: Input array bounds | ServiceManager.au3 | PASS | UBound-driven loop with empty-input guard |
| A-02: Result array bounds | ServiceManager.au3 | PASS | Same index variable as input loop; literal column indices 0–5 |
| A-03: Dynamic pending arrays bounds | ServiceManager.au3 | PASS | ReDim before write; backwards iteration; UBound-driven reads |
| A-04: Watchdog parallel arrays bounds | Stop Services Processes.au3 | PASS | Backwards iteration with _ArrayDelete |
| A-05: Process list array bounds | Stop Services Processes.au3 | PASS | UBound-driven loop |
| N-01: OpenSCManagerW null check | ServiceManager.au3 | PASS | Lines 174–183 |
| N-02: OpenServiceW null check | ServiceManager.au3 | PASS | Lines 207–220 |
| N-03: OpenProcess null check | Stop Services Processes.au3 | PASS | Lines 533–538 |
| N-04: QueryServiceStatus null check | ServiceManager.au3 | PASS | Lines 231–239, 328–333 |
| P-01: #RequireAdmin test harness scope | Tests/ServiceManager.Tests.au3 | PASS | Development artifact; documented; isolated from production |
| P-02: #RequireAdmin production necessity | Stop Services Processes.au3 | PASS | Functionally required by SCM API |
| P-03: Minimum access rights | ServiceManager.au3 | PASS | SC_MANAGER_CONNECT + SERVICE_QUERY_STATUS\|SERVICE_STOP only |
| P-04: ServiceManager.au3 isolation | ServiceManager.au3 | PASS | #include-once; no #RequireAdmin |

**Overall verdict:** No defects found. All handle lifecycles are correct on every exit path. TOCTOU is mitigated to the irreducible user-mode minimum. No integer overflow risk. No array bounds violations. All handle validity checks are present. Privilege use is minimal and correctly scoped.
