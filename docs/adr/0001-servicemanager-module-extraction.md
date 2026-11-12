# Extract service-stop behaviour into ServiceManager.au3 as a deep module

The existing `_StopService()` path in `ServiceControl.au3` sends a single stop control per
service with no state inspection, no wait, and binary success/failure reporting. On the
monitoring hot path this means the main script cannot distinguish a service that stopped
cleanly from one that timed out or was never running. The fix required more than moving code:
the entire algorithm needed to be rethought as a batch operation.

We extracted service-stop into a new module, `ServiceManager.au3`, built around a single
public function: `_SM_StopServicesBatch`. The function opens the Windows SCM once, issues stop
controls to all eligible services without serial waiting, then polls all pending services
against one shared deadline, and returns a structured result row for each input service. The
interface is small (three parameters, one return value, two @error codes); the behaviour behind
it is large.

`ServiceControl.au3` is retained for its non-stop helpers (`_ServiceExists`, `_ServiceRunning`,
`_StartService`, `_CreateService`, `_DeleteService`). Its `_StopService` function is no longer
called on the monitoring hot path but is not deleted, as there may be callers outside this
codebase.

## Considered options

**Option A (chosen):** New deep module with batch algorithm and structured outcomes.
Caller gets per-service outcome codes (`STOPPED`, `ALREADY_STOPPED`, `UNAVAILABLE`,
`FAILED`, `TIMED_OUT`) and Win32 error codes. SCM opened once per batch cycle.

**Option B:** Patch `_StopService` in `ServiceControl.au3` to add a wait loop.
Rejected: would still be one SCM open per service, serial waits, and would bloat a function
that is used elsewhere for one-off operations. The interface would stay binary, forcing
outcome logic into the caller.

**Option C:** Call AutoIt's built-in `ServiceStop()`.
Rejected: the built-in does not expose Win32 error codes, does not support batch
coordination, and has known gaps with protected services (e.g. `WaaSMedicSvc`) that require
direct `advapi32.dll` access.

## Consequences

- The main script's monitoring loop now reads a 2D result array and routes each outcome to
  the appropriate log level. The call site is more verbose than the old `_stopservicescustom()`
  call, but the behaviour is explicit and testable.
- `ServiceControl.au3` and `ServiceManager.au3` divide SCM operations by convention:
  non-stop operations live in `ServiceControl.au3`, stop operations in `ServiceManager.au3`.
  This boundary is not enforced by an interface — it is a naming and inclusion convention.
  Future contributors must not add stop operations back into `ServiceControl.au3`.
- `ServiceManager.au3` calls `_LogMessage` and `_WinAPI_GetLastError` directly, which means
  it is not fully self-contained: it depends on the main script's logging infrastructure and
  on `<WinAPI.au3>` being included before it.
