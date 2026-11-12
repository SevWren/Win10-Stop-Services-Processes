# Two-level error reporting in `_SM_StopServicesBatch`

`_SM_StopServicesBatch` reports failures at two distinct levels: `@error 1` for a batch-level SCM failure (the manager could not be opened at all), and outcome strings encoded in per-row `Result Row[i][3]` for every individual service result. `@error` is `0` even when some services have `FAILED` or `TIMED_OUT` outcomes — a "successful batch" means "we talked to the SCM and got a result for every service", not "every service stopped".

This was chosen over a single `@error` / return-code convention because the function operates on multiple services simultaneously. A scalar error code cannot express "three stopped, one timed out, one not found" — the caller needs structured per-service data. The batch-level `@error 1` exists as a fast-fail path only for the degenerate case where the SCM itself cannot be opened, which makes the per-row array meaningless.

**Consequence**: callers must not check `@error` alone to determine whether services actually stopped. After checking `@error`, callers must iterate the returned array and inspect each row's outcome string. Code that treats `@error = 0` as "all stopped" is silently incorrect.

## Considered Options

- **Single `@error` with a summary code**: rejected — loses per-service granularity needed for logging and retry logic.
- **Return `False` / `0` on any per-service failure**: rejected — same information loss; also inconsistent with AutoIt array-return functions.
- **Two-level as implemented**: chosen — batch-level `@error` for the unrecoverable case; structured rows for the recoverable per-service cases.
