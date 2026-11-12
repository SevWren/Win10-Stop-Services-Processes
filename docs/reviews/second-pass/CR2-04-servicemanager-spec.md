# CR2-04 — ServiceManager.au3 Second-Pass Review

**File reviewed**: `Includes/ServiceManager.au3`
**Fixed point**: `ab5b012..HEAD`
**Commits in range**:
- `1d8a5ea` feat: replace broken service-stop path with native SCM batch-stop module
- `2a62801` chore(cleanup)

**Spec sources**: `docs/ARCHITECTURE.md`, `docs/REQUIREMENTS.md` (REQ-001–REQ-009),
`.scratch/service-manager-migration/issues/03-build-servicemanager.md`

**Standards sources**: `CODING_STANDARDS.md`, `CLAUDE.md`

---

## Standards

### Documented-standard checks

**S-01 — Handle types: PASS**
All SC_HANDLE parameters use `"handle"` throughout. `OpenSCManagerW` return type,
`OpenServiceW` parameter and return type, and all `CloseServiceHandle` parameters are
typed `"handle"`. No `"long"` appears for any handle parameter.
(CLAUDE.md "AutoIt Version Compatibility Notes"; CODING_STANDARDS.md "WinAPI Patterns")

**S-02 — @error captured immediately after DllCall: PASS**
Every DllCall in the file is followed on the very next line by
`Local $i*DllErr = @error`. `CloseServiceHandle` calls intentionally omit @error
capture; this is documented in `docs/ARCHITECTURE.md` ("Close handles" note) as an
accepted pattern and is not flagged.
(CODING_STANDARDS.md "@error Capture"; REQ-006)

**S-03 — $SM_OUTCOME_* constant naming: MINOR**
The constant names do not fully mirror the string values they hold:

| Constant | Value |
|---|---|
| `$SM_OUTCOME_ALREADY` | `"ALREADY_STOPPED"` |
| `$SM_OUTCOME_TIMEDOUT` | `"TIMED_OUT"` |

`$SM_OUTCOME_TIMEDOUT` omits the underscore that is present in its value
`"TIMED_OUT"`. `$SM_OUTCOME_ALREADY` truncates `ALREADY_STOPPED` without a
distinguishing suffix. A reader scanning the constant name alone cannot infer the
exact string value. The other three constants (`$SM_OUTCOME_STOPPED`,
`$SM_OUTCOME_UNAVAILABLE`, `$SM_OUTCOME_FAILED`) are unambiguous.
This is a Mysterious Name judgement call, not a hard violation — both constants
function correctly and no code outside this file is broken. Renaming to
`$SM_OUTCOME_ALREADY_STOPPED` and `$SM_OUTCOME_TIMED_OUT` would remove the
ambiguity.

**S-04 — Function naming: PASS**
`CLAUDE.md` names `_SM_PascalCase` as the third naming tier for the service-manager
module and explicitly states it wins over `CODING_STANDARDS.md` on conflict. All
helpers (`_SM_StopServicesBatch`, `_SM_GetServiceState`, `_SM_Win32ErrToOutcome`,
etc.) follow `_SM_PascalCase`. No violation.

**S-05 — Logging routes through _LogMessage: PASS**
All log calls in the file go through `_LogMessage($sMsg, $sType, $iLevel)` using the
named constants `$LOG_TYPE_SERVICE`, `$LOG_LEVEL_ERROR`, `$LOG_LEVEL_VERBOSE`,
`$LOG_LEVEL_INFO`. No bare `ConsoleWrite` in production code.
(CODING_STANDARDS.md "Logging")

**S-06 — Handle ownership (every handle has exactly one cleanup path): PASS**
See Spec S-07 trace below. All paths close exactly once.

### Smell baseline (Fowler, Refactoring ch.3)

**Smell-01 — Speculative Generality (judgement call)**
`$SM_STOP_ELIGIBLE_STATES` (line 91) is declared as a comma-separated string constant
`"RUNNING,PAUSED,PAUSE_PENDING,CONTINUE_PENDING"` but is never referenced anywhere in
the file. The stop-eligibility logic lives entirely in `_SM_IsStopEligible` via a
`Switch` statement. The constant adds no callable behaviour and is not required by any
spec item. It is dead constant — an abstraction added for a need the spec does not
have.

**Smell-02 — Middle Man (judgement call)**
`_SM_StateToAlreadyStopped` and `_SM_StateNeedsPolling` are single-expression
predicates (`Return ($iState = $SM_STATE_STOPPED)` and
`Return ($iState = $SM_STATE_STOP_PENDING)` respectively). Both are called exactly
once. They wrap a single comparison behind a named function, adding a call layer
without contributing logic. However, the architecture document explicitly names them
as routing predicates in the Phase 1 table, so their existence is spec-driven. This
is a mild judgement call only.

---

## Spec

### REQ-001 — Batch returns per-service outcomes: PASS
`_SM_StopServicesBatch` returns a `[n][6]` 2D array. All five outcome codes —
`"STOPPED"`, `"ALREADY_STOPPED"`, `"UNAVAILABLE"`, `"FAILED"`, `"TIMED_OUT"` — are
reachable via the Phase 1 routing table and Phase 2 poll loop. Column layout
`[i][0..5]` matches the contract in `docs/ARCHITECTURE.md` and REQ-001.

### REQ-002 — All 7 service states interpreted: PASS
`_SM_ServiceStateToString` maps integers 1–7 to their canonical strings with a
`Switch` block; `Case Else` returns `"UNKNOWN"`. All seven `$SM_STATE_*` constants
are declared. REQ-002 satisfied.

### REQ-003 — No serial waiting: PASS
Phase 1 (lines 194–309) iterates all services and issues stop controls without any
`Sleep`. Phase 2 (lines 314–361) polls all pending services against one shared
`TimerInit()` deadline. The two phases are structurally separate. REQ-003 satisfied.

### REQ-004 — Minimum access rights only: PASS
`OpenSCManagerW` uses `$SM_SC_MANAGER_CONNECT = 0x0001`.
`OpenServiceW` uses `$SM_SERVICE_QUERY_AND_STOP = BitOR(0x0004, 0x0020) = 0x0024`.
No `SC_MANAGER_ALL_ACCESS` or `SERVICE_ALL_ACCESS` present. REQ-004 satisfied.

### REQ-005 — Every handle has exactly one cleanup path: PASS
Full trace:
- `$hSCM`: set only if `OpenSCManagerW` succeeds; closed unconditionally after Phase 2
  / timeout block (line 376). Early return on SCM-open failure returns before `$hSCM`
  is set, so no close needed.
- `$hService` (per-service): every branch that acquires the handle either closes it
  directly (`ContinueLoop` paths for QueryServiceStatus fail, ALREADY_STOPPED,
  START_PENDING, ControlService fail) or transfers ownership to `$aPendingHnd` for
  close in Phase 2 (STOP_PENDING branch, stop-accepted branch).
- Pending handles: closed on STOPPED detection (line 343) or in the timeout loop
  (line 371). REQ-005 satisfied.

### REQ-006 — @error captured immediately: PASS
(See Standards S-02 above.) REQ-006 satisfied.

### REQ-007 — "handle" type for SC_HANDLE params: PASS
(See Standards S-01 above.) REQ-007 satisfied.

### REQ-008 — ControlService receives valid SERVICE_STATUS struct: PASS
`DllStructCreate("dword;dword;dword;dword;dword;dword;dword")` (7 DWORDs) is used for
both `QueryServiceStatus` and `ControlService`; the struct pointer is passed as `"ptr"`.
No `"str", ""` pattern. REQ-008 satisfied.

### REQ-009 — Test harness, no live stops: N/A for this file
REQ-009 applies to `Tests/ServiceManager.Tests.au3`, not `Includes/ServiceManager.au3`.

### Phase 1 routing table vs ARCHITECTURE.md: PASS
Every state in the ARCHITECTURE.md Phase 1 routing table maps correctly to the code:

| State | ARCHITECTURE.md action | Code |
|---|---|---|
| STOPPED (1) | `_SM_StateToAlreadyStopped` → ALREADY_STOPPED | Line 244 ✓ |
| START_PENDING (2) | `_SM_IsStopEligible` = False → FAILED / Win32 1061 | Lines 264–273 ✓ |
| STOP_PENDING (3) | `_SM_StateNeedsPolling` → add to pending | Lines 254–262 ✓ |
| RUNNING/PAUSED/PAUSE_PENDING/CONTINUE_PENDING (4–7) | `_SM_IsStopEligible` → ControlService → pending | Lines 275–307 ✓ |

### Phase 2 timer arithmetic: PASS
`While UBound($aPendingIdx) > 0 And TimerDiff($iTimer) < $iBatchTimeoutMs`
`TimerDiff` returns elapsed milliseconds since `TimerInit()`. The condition continues
while elapsed < timeout and exits when elapsed >= timeout. Direction is correct — the
loop drains when the deadline is reached.

### Timer start before Phase 1: PASS (matches architecture)
`$iTimer = TimerInit()` is called at line 314, after Phase 1 completes. This means
Phase 1 execution time is not charged against the Phase 2 deadline.
`docs/ARCHITECTURE.md` ("Batch-Stop Algorithm") places `$iTimer = TimerInit()` at
the top of Phase 2, not before Phase 1. The implementation matches the architecture
exactly. No violation.

### All 5 outcome string values: PASS
| Constant | String value | Required |
|---|---|---|
| `$SM_OUTCOME_STOPPED` | `"STOPPED"` | ✓ |
| `$SM_OUTCOME_ALREADY` | `"ALREADY_STOPPED"` | ✓ |
| `$SM_OUTCOME_UNAVAILABLE` | `"UNAVAILABLE"` | ✓ |
| `$SM_OUTCOME_FAILED` | `"FAILED"` | ✓ |
| `$SM_OUTCOME_TIMEDOUT` | `"TIMED_OUT"` | ✓ |

All five string values are correct. (Note: the constant names are abbreviated vs their
values — flagged as Standards S-03 Mysterious Name, not a spec failure.)

### Scope creep: MINOR
`$SM_STOP_ELIGIBLE_STATES` (line 91) is not required by any REQ-001–REQ-009 item and
is never consumed. It duplicates the eligibility logic already in `_SM_IsStopEligible`
in unused string form. Also flagged under Standards Smell-01.

`_SM_GetServiceState` is declared as an internal helper (file header, line 19) and is
present in the architecture module map, but it is never called from within
`_SM_StopServicesBatch` or any other function in the file. The main function uses
inline `DllCall` + `DllStructGetData` patterns rather than delegating to this helper.
The function is not scope creep (it is listed in the architecture), but it is dead
code as written — a spec item described in the module map that the implementation
chose not to exercise internally.

---

## Summary

**Standards axis**: 2 findings — 1 minor documented-standard issue (S-03: abbreviated
constant names `$SM_OUTCOME_ALREADY` / `$SM_OUTCOME_TIMEDOUT` create Mysterious Name
ambiguity), 2 smell judgement calls (Smell-01: unused `$SM_STOP_ELIGIBLE_STATES`
constant; Smell-02: single-expression Middle Man predicates). No hard violations.
Worst issue: S-03 (minor naming inconsistency).

**Spec axis**: 2 minor findings — `$SM_STOP_ELIGIBLE_STATES` declared but unused
(minor scope creep); `_SM_GetServiceState` is listed in the architecture module map
but never called internally (dead code, not a behavioural gap). REQ-001 through
REQ-009 all pass. All 5 outcome strings are correct. Timer arithmetic is correct.
Phase 1 routing matches the architecture table exactly.
Worst issue: unused `_SM_GetServiceState` helper (dead code vs architecture map).
