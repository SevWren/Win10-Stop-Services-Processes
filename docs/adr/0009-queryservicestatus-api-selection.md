# Use QueryServiceStatus (7-DWORD SERVICE_STATUS) instead of QueryServiceStatusEx

The enterprise prompt mandated `QueryServiceStatusEx` and `SERVICE_STATUS_PROCESS` (9 DWORDs).
The implementation in `Includes/ServiceManager.au3` uses `QueryServiceStatus` and the 7-DWORD
`SERVICE_STATUS` struct throughout. Three code reviews (CR-04 SP-01, CR-05 SPEC-S02, CR-06 SP-1)
flagged the absence of a recorded decision justifying this deviation. This ADR is that record.

**Status**: accepted

## Decision

`_SM_StopServicesBatch`, `_SM_GetServiceState`, and the Phase 2 poll loop all call
`QueryServiceStatus` via DllCall with a 7-DWORD struct
(`DllStructCreate("dword;dword;dword;dword;dword;dword;dword")`). `QueryServiceStatusEx` is
not called anywhere in the module.

## Rationale

`SERVICE_STATUS_PROCESS` adds two fields beyond `SERVICE_STATUS`:

| Field | Position | Value provided |
|---|---|---|
| `dwProcessId` | 8 | Host process PID |
| `dwServiceFlags` | 9 | Flags (e.g., runs in system process) |

Neither field is used by the batch-stop algorithm. The algorithm reads only `dwCurrentState`
(field 2) to route stop decisions in Phase 1 and to detect `SERVICE_STOPPED` in the Phase 2
poll. `ControlService` — also called in this module — accepts only `LPSERVICE_STATUS`
(7 DWORDs); there is no Ex variant that accepts `SERVICE_STATUS_PROCESS`, so both APIs already
share the same struct on the stop-control path.

`QueryServiceStatusEx` requires two additional DllCall parameters (`InfoLevel` =
`SC_STATUS_PROCESS_INFO` and `cbBufSize` = 36 bytes) that `QueryServiceStatus` does not.
Using the simpler API eliminates those parameters with no functional loss for this use case.

## Considered options

**`QueryServiceStatusEx` / `SERVICE_STATUS_PROCESS` (9 DWORDs)** — the API named in the
enterprise prompt. Rejected because the two extra fields (`dwProcessId`, `dwServiceFlags`) are
not needed for the batch-stop algorithm, and the additional DllCall parameters add complexity
without benefit.

**`QueryServiceStatus` / `SERVICE_STATUS` (7 DWORDs)** — chosen. Sufficient for reading
`dwCurrentState`. Struct is identical to the one `ControlService` already requires, so there
is no additional struct definition needed.

## Consequences

**Available fields** (`SERVICE_STATUS`, 7 DWORDs in order):
`dwServiceType` (1), `dwCurrentState` (2), `dwControlsAccepted` (3), `dwWin32ExitCode` (4),
`dwServiceSpecificExitCode` (5), `dwCheckPoint` (6), `dwWaitHint` (7).

**Not available**: `dwProcessId` and `dwServiceFlags`. PID-based detection (e.g., identifying
when two service names share a host process) is not possible with the current query API.
If a future requirement needs PID awareness — for example, to skip a stop attempt when a
protected svchost instance is detected — the query call sites must be migrated to
`QueryServiceStatusEx` with a 9-DWORD struct and the additional `InfoLevel`/`cbBufSize`
parameters. That migration is isolated to `Includes/ServiceManager.au3` and does not affect
the public interface of `_SM_StopServicesBatch`.

Both struct layouts are documented here for completeness, per the enterprise prompt requirement
to "Document `SERVICE_STATUS_PROCESS` as nine DWORD values and `SERVICE_STATUS` as seven DWORD
values":

| Struct | Fields | Used by |
|---|---|---|
| `SERVICE_STATUS` | 7 DWORDs | `QueryServiceStatus`, `ControlService` (this module) |
| `SERVICE_STATUS_PROCESS` | 9 DWORDs | `QueryServiceStatusEx` (not used in this module) |

Research source: `docs/research/windows-scm-api.md` §"QueryServiceStatus vs QueryServiceStatusEx".
