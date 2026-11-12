# AutoIt integers (0–5) as the canonical internal representation for process priority

The Windows `GetPriorityClass` API returns hex priority class constants (e.g., `0x20` for
Normal) that bear no numeric relationship to the integers AutoIt's `ProcessSetPriority`
accepts (e.g., `2` for Normal). We store and compare priorities internally as AutoIt integers
(0–5) throughout all priority-bearing variables and the watchdog arrays, converting from
Windows API hex only at the read boundary via `_WinAPIPriorityClassToAutoItConst`.

## Considered options

**Option A (chosen):** AutoIt integers as the canonical internal form; convert Windows API hex
to AutoIt integer once, on read, inside `_GetProcessPriorityByPID`.
Every `ProcessSetPriority` call site and every watchdog array slot uses integers directly —
no conversion needed at write time. The single conversion function is the sole coupling point
between the two schemes.

**Option B:** Store Windows API hex constants (e.g., `$NORMAL_PRIORITY_CLASS = 0x20`)
internally throughout.
Rejected: `ProcessSetPriority` requires AutoIt integers, so every write site — including the
watchdog's restore path — would require a hex-to-integer conversion. The watchdog parallel
arrays (`$aPriorityWatchTargets[]`) would hold values that cannot be passed to
`ProcessSetPriority` without transformation, pushing conversion burden to the most
performance-sensitive paths.

## Consequences

- Every priority comparison and assignment in the codebase uses AutoIt integers (0–5).
  The named constants `$AUTOIT_PRIORITY_IDLE` through `$AUTOIT_PRIORITY_REALTIME` are the
  only values that may appear in priority-bearing variables and array slots.
- Any call to `GetPriorityClass` (directly or via `_GetProcessPriorityByPID`) MUST pass its
  return value through `_WinAPIPriorityClassToAutoItConst` before the result is stored,
  compared, or logged. Code that compares a raw `GetPriorityClass` return value against an
  AutoIt integer will compile silently and produce wrong results — `0x20 <> 2` even though
  both represent Normal priority.
- `_WinAPIPriorityClassToAutoItConst` is not optional plumbing; it is the mandatory boundary
  function. Any new code path that reads a Windows priority class must route through it.
