# SCM handle opened once per Batch Stop cycle, not once per service

`_SM_StopServicesBatch` opens the Windows Service Control Manager handle (`$hSCM`) once at the
start of the function and holds it for the entire batch — covering Phase 1 (state inspection and
stop-control dispatch for all services) and Phase 2 (shared-deadline polling). It is closed once,
after all per-service handles are released. `ServiceControl.au3` does the opposite: every function
(`_StopService`, `_StartService`, `_ServiceExists`, `_ServiceRunning`, `_DeleteService`) opens and
closes its own SCM handle independently. These are intentionally incompatible approaches, chosen to
match the access pattern each layer is designed for.

## Considered options

**Per-call SCM open (the `ServiceControl.au3` pattern) — rejected.**
Opening a fresh SCM handle on every function call makes each call self-contained and independent,
which is appropriate for the one-off, mixed-purpose helpers in `ServiceControl.au3`. For a batch
operation it has two costs: it adds one `OpenSCManagerW` / `CloseServiceHandle` round-trip per
service (not per batch), and it prevents a clean batch-level abort. If the SCM cannot be opened,
there is no single point to detect that before iterating over the service list — the failure would
surface per-service rather than stopping the whole batch immediately. The batch-scoped approach
makes `@error=1` from `_SM_StopServicesBatch` mean exactly "the SCM could not be opened; no
per-service work was attempted", which is a cleaner contract for the caller.

**Batch-scoped SCM open (chosen).**
One `OpenSCManagerW` call at the top of `_SM_StopServicesBatch`. If it fails, the function returns
`@error=1` with a zero-row array and no per-service work is done. If it succeeds, `$hSCM` is
passed to every `OpenServiceW` call in Phase 1 and is closed only after all per-service handles and
the Phase 2 poll loop are complete. This matches the structure of the algorithm: the SCM connection
is a resource needed for the whole batch, not for individual services.

## Consequences

**Positive:**
- One `OpenSCManagerW` / `CloseServiceHandle` system call pair per batch regardless of how many
  services are in the list. For a ten-service batch this is nine fewer SCM open/close round-trips
  compared to the per-call pattern.
- A single conditional at the top of `_SM_StopServicesBatch` handles SCM failure for the entire
  batch. The caller receives `@error=1` and a zero-row array; it does not need to inspect per-row
  outcome codes to determine whether the SCM was available.

**Negative:**
- If the OS revokes SCM access mid-batch (e.g. the process loses elevation between Phase 1 and
  Phase 2), the existing `$hSCM` handle may become stale. In practice this does not happen: the
  script runs with `#RequireAdmin` and elevation cannot be dropped mid-execution on Windows 10/11.
  It is noted here because a reader familiar with the per-call pattern might expect a fresh
  privilege check on every service operation.

**Non-obvious — convention-only boundary:**
Both `ServiceControl.au3` and `ServiceManager.au3` can be `#include`d in the same script without
conflict; AutoIt does not enforce any interface boundary between them. The separation between
per-call SCM handles (`ServiceControl.au3`) and the batch-scoped handle (`ServiceManager.au3`) is a
naming and inclusion convention, not a language-level constraint. Future contributors must not add
stop operations to `ServiceControl.au3` or replicate the per-call pattern inside
`ServiceManager.au3` — doing so would silently undermine the batch-level abort guarantee without
any compiler or runtime error.
