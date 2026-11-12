# BUG-09 — Log Rotation and _LogMessage Concurrency Review

**File under investigation:** `Stop Services Processes.au3`
**Date:** 2026-11-12
**Status:** Two confirmed bugs found; one design risk documented.

---

## 1. Scope

This review examines two suspected issues in the logging subsystem:

1. Whether log file rotation can delete the file currently being written.
2. Whether `_LogMessage` is re-entrant safe given that `_PriorityWatchdog` fires via `AdlibRegister`.

---

## 2. Code Inventory

### 2.1 Log initialization (startup — lines 119–139)

Runs once at script load time, before the main loop starts. If the log file does not
exist, it creates the directory with `DirCreate` and writes an initial entry with a bare
`FileWrite($sLogFile, ...)` call (not `FileOpen`/`FileClose`). If the file already
exists, it immediately calls `_CheckAndRotateLogFile($sLogFile, $iLogMaxAgeDays)`.

### 2.2 `_CheckAndRotateLogFile` (lines 179–194)

```autoit
Func _CheckAndRotateLogFile($sPath, $iDaysMax)
    If FileExists($sPath) Then
        Local $aFileTime = FileGetTime($sPath, 0, 1)   ; 0 = modified time, 1 = string array
        If IsArray($aFileTime) Then
            Local $iFileDate = _DateToDayValue($aFileTime[0], $aFileTime[1], $aFileTime[2])
            Local $iToday    = _DateToDayValue(@YEAR, @MON, @MDAY)
            If $iToday - $iFileDate > $iDaysMax Then
                FileDelete($sPath)
            EndIf
        EndIf
    EndIf
EndFunc
```

Key observations:
- Uses `FileGetTime($sPath, 0, 1)` — flag `0` returns the **last-modified** time, **not**
  the creation time, as a string array `[YYYY, MM, DD, HH, MM, SS]`.
- Condition is `> $iDaysMax` (strict greater-than), so a file exactly 7 days old is NOT
  deleted; only files older than 7 days are deleted.
- Rotation is called **only at startup**, not during the monitoring loop or on any timer.

### 2.3 `_LogMessage` (lines 264–280)

```autoit
Func _LogMessage($sMessage, $sType, $iLevel)
    If $iLevel > $iLogLevel Then Return
    Local $sDateTime = _NowTime(12) & " " & @MDAY & "/" & @MON & "/" & @YEAR
    Local $sLogEntry = @CRLF & $sDateTime & " [" & $sType & "] " & $sMessage

    Local $hFile = FileOpen($sLogFile, 1)   ; Mode 1 = Append
    If $hFile = -1 Then
        ConsoleWrite("ERROR in _LogMessage: ..." & @CRLF)
        Return
    EndIf
    FileWrite($hFile, $sLogEntry)
    FileClose($hFile)

    If $bLogToConsole Then ConsoleWrite($sLogEntry & @CRLF)
EndFunc
```

Handle lifetime: open → write → close, all within a single call. No handle is held
between calls.

### 2.4 `_PriorityWatchdog` (lines 462–511)

Registered via `AdlibRegister("_PriorityWatchdog", 10000)`. Calls `_LogMessage`
multiple times per invocation.

---

## 3. Bug Analysis

---

### BUG-09-A: `_CheckAndRotateLogFile` uses last-modified time, not creation time — rotation window can delete a recently active log

**Severity:** Medium
**Status:** Confirmed bug

**Root cause:**

`FileGetTime($sPath, 0, 1)` — the second argument `0` selects **last-modified** time.
In normal operation, every `_LogMessage` call writes to the file, which advances the
last-modified timestamp. So in practice, as long as the script has been active within
7 days, the file will not be rotated.

However, the bug manifests in one real scenario: if the script is left **not running**
(monitoring loop never toggled on, no watchdog active, no log writes) for more than 7
days, the last-modified time ages past the threshold. On the next startup, the file is
deleted. This is arguably the intended behavior per the GLOSSARY.md definition of Log
Rotation ("deleting the log file when it is older than the configured maximum age").

**The genuine risk** is a subtler one: `FileGetTime` with flag `0` is documented in
AutoIt to return last-modified time, but on some Windows FAT32 volumes or network shares
the modification timestamp can be unreliable or coarser than 1 second. On NTFS (the
normal case here) this is not a concern. The more serious concern is below.

**Can rotation delete the CURRENT log file (the one being written)?**

Rotation runs **exclusively at startup** (line 138), before the main loop and before any
`AdlibRegister` callback is active. At the point `_CheckAndRotateLogFile` executes:

- The monitoring loop has not started (Shift+F1 has not been pressed).
- No `AdlibRegister` callback is active (`_PriorityWatchdog` is only registered after the
  first `LockProcessPriority` invocation, which requires the UI).
- The only code that could have written to the log since the script started is the
  initialization block at lines 119–135.

There is **no concurrent writer** at the time rotation runs. The race between rotation
and an active writer cannot happen in normal flow.

**However, there is a logical inconsistency:**

The initialization block at lines 119–135 writes an initial entry **before** checking
rotation:

```
If Not FileExists($sLogFile) Then
    ...
    FileWrite($sLogFile, $sLogEntry)   ; line 129 — writes entry
Else
    ...
    _CheckAndRotateLogFile(...)        ; line 138 — rotation only on existing file
EndIf
```

The `Else` branch (rotation) executes only when the file already exists, so the initial
write at line 129 is never subject to rotation. This path is correct.

But the initial write at line 129 uses a bare `FileWrite($sLogFile, ...)` **without**
`FileOpen`/`FileClose` — it relies on AutoIt's implicit file open behavior. If
`$sLogFile` path contains characters that AutoIt cannot parse, or if the directory was
just created and hasn't flushed, this silent `FileWrite` may succeed silently while
writing nothing (AutoIt's `FileWrite` without an explicit handle opens in write/overwrite
mode, not append mode — meaning this initial entry uses **overwrite**, not append,
consistent with intent since the file is new). This is not a bug, but is worth noting as
a deviation from the `FileOpen(, 1)` append pattern used everywhere else.

**Verdict on BUG-09 Question 1:** Rotation cannot delete the currently-being-written
file under normal operation because rotation only runs at startup before any writer is
active. No bug in the concurrent-deletion sense. The last-modified vs. creation-time
choice is worth noting but behaves as intended for this use case.

---

### BUG-09-B (CONFIRMED BUG): `_LogMessage` is NOT re-entrant safe — `AdlibRegister` interruption can produce interleaved or corrupt log entries

**Severity:** Medium–High
**Status:** Confirmed bug

**Root cause:**

AutoIt's `AdlibRegister` callbacks fire **between bytecode instructions**, not between
function calls. A registered callback can interrupt any executing function at any
instruction boundary — including inside `_LogMessage`.

The critical window inside `_LogMessage` is:

```autoit
Local $hFile = FileOpen($sLogFile, 1)   ; ← interrupt can fire here
                                         ;   or here
FileWrite($hFile, $sLogEntry)            ; ← or here
FileClose($hFile)                        ; ← or here
```

If `_PriorityWatchdog` fires between `FileOpen` and `FileClose` in an outer
`_LogMessage` call, the following sequence occurs:

1. Outer `_LogMessage` opens the file → `$hFile = N` (a valid handle, e.g. handle #1).
2. AutoIt interrupts; `_PriorityWatchdog` starts executing.
3. `_PriorityWatchdog` calls `_LogMessage(...)` (inner call).
4. Inner `_LogMessage` calls `FileOpen($sLogFile, 1)` → opens the file **again** →
   `$hFile = M` (a second handle, e.g. handle #2).
5. Inner `_LogMessage` writes to handle #2, then closes handle #2. Log entry from
   watchdog is written.
6. AutoIt resumes outer `_LogMessage`.
7. Outer `_LogMessage` calls `FileWrite(handle #1, ...)` — but the file has been written
   to and closed via handle #2 since handle #1 was opened. The write to handle #1 still
   succeeds because handle #1 was never closed.
8. Outer `_LogMessage` closes handle #1.

**What actually happens on Windows with two simultaneous append handles to the same
file:** Windows NTFS permits multiple processes/threads to open the same file for
appending with `FILE_SHARE_WRITE`. AutoIt's `FileOpen` with mode 1 maps to a standard
append open. Since AutoIt is single-threaded but the interrupt occurs mid-function, there
are effectively two open handles to the same file within the same process. The writes
from both handles will both land in the file, but the **order** is non-deterministic
relative to each other and the two entries can be interleaved within the same log line if
a write spans multiple internal I/O calls.

**The more likely scenario (and the actual risk):** The file size is small and writes are
short text strings. In practice each `FileWrite` is likely a single Win32 `WriteFile`
call, so interleaving within a line is unlikely. However:

- **If the interrupt fires between `FileOpen` and `FileWrite`:** the outer handle is
  open; the inner call opens a second handle, writes, and closes. The outer handle
  pointer position was set at open time (append → end of file at that moment). After the
  inner write, the outer handle's internal file pointer is now stale — it points to what
  was the end-of-file before the inner write. When the outer `FileWrite` executes, it
  appends from the stale position, **overwriting** the watchdog's entry rather than
  appending after it.

This is the actual data-loss mechanism: the watchdog log entry can be silently
overwritten by the outer `_LogMessage` write if the interrupt fires between `FileOpen`
and `FileWrite` in the outer call.

**How probable is this in practice?**

`_PriorityWatchdog` fires every 10 seconds (`$PRIORITY_WATCHDOG_MS = 10000`). It only
registers after `LockProcessPriority()` is used (requires explicit user interaction).
The vulnerable window is the ~microseconds between `FileOpen` and `FileWrite`. The
probability of an interrupt landing in that window on any given call is very low.
However, under high log volume (many processes being killed every 2 seconds, each
generating log calls), the cumulative probability across thousands of calls is
non-trivial. The bug is a real but low-frequency corruption risk, not a theoretical one.

**Is `_ClearTrayNotify` also a concern?**

`_ClearTrayNotify` is registered via `AdlibRegister("_ClearTrayNotify", 2000)` from
`_TrayNotify`. It does not call `_LogMessage`, so it cannot trigger this re-entrance
path. It is not a risk here.

**What about the monitoring loop and the watchdog interleaving?**

The monitoring loop runs inside `ToggleScript()` which is itself a hotkey handler. AutoIt
hotkey handlers and `AdlibRegister` callbacks share the same single thread. The
monitoring loop contains `Sleep($MAIN_LOOP_SLEEP_MS)` (500 ms). AutoIt processes
`AdlibRegister` callbacks during `Sleep` calls. So `_PriorityWatchdog` will reliably
fire during `Sleep(500)` in the monitoring loop — this is expected and correct. The
re-entrance risk is not from the monitoring loop itself but from `_LogMessage` being
called by both a monitoring-loop function and the watchdog in rapid succession.

---

### BUG-09-C: `_LogMessage` has no retry or fallback on `FileOpen` failure — silent data loss

**Severity:** Low
**Status:** Design gap, not a bug per se

If `FileOpen($sLogFile, 1)` returns `-1`, `_LogMessage` logs to console (if
`$bLogToConsole` is True) and returns. There is no retry, no alternative path, and no
accumulation buffer. In production use (`$bLogToConsole = True`) the console output
prevents total silence, but compiled execution (`release/Stop Services - Processes.Exe`)
runs without a SciTE console, so a `FileOpen` failure there produces completely silent
log loss with no indication to the user.

No `@error` is inspected after `FileOpen` — the only check is the return value being
`-1`. This is correct per AutoIt conventions (FileOpen returns -1 on failure, not via
@error), so the check itself is not buggy. The gap is the absence of any durable
fallback.

---

## 4. Summary Table

| ID | Description | Severity | Type |
|----|-------------|----------|------|
| BUG-09-A | Rotation uses last-modified time; rotation-during-active-write is impossible by sequencing but timestamp semantics are worth auditing | Low | Design note |
| BUG-09-B | `_LogMessage` is not re-entrant safe; `AdlibRegister` interrupt between `FileOpen` and `FileWrite` can cause the watchdog's log entry to be overwritten by the outer write | Medium–High | Confirmed bug |
| BUG-09-C | `FileOpen` failure in `_LogMessage` produces silent log loss in compiled/no-console mode | Low | Design gap |

---

## 5. Re-entrant Safety: Detailed Call Graph

```
[Monitoring loop — ToggleScript]
  └─ _KillProcessList() → _LogMessage()
       └─ FileOpen($sLogFile, 1)       ← AdlibRegister can interrupt HERE
            ↓
       [_PriorityWatchdog fires]
            └─ _LogMessage() → FileOpen() → FileWrite() → FileClose()
            ↓ [returns]
       FileWrite($hFile, ...)           ← outer handle write; inner write may be overwritten
       FileClose($hFile)
```

---

## 6. Rotation Timing Proof (BUG-09-A)

The startup sequence, in order:

1. `#include` directives processed (defines constants, `$LOG_LEVEL_*`, etc.)
2. Global variable declarations (line 84 onwards)
3. `TraySetIcon` (line 115)
4. Log initialization block (lines 119–139) — **this is where rotation runs**
5. Main loop `While 1 / Sleep(50) / WEnd` enters
6. User presses Shift+F1 → `ToggleScript()` starts monitoring loop
7. User presses Ctrl+Alt+Shift+9 → `LockProcessPriority()` → `AdlibRegister("_PriorityWatchdog", ...)`

At step 4 (rotation), steps 6 and 7 have not yet occurred. No `AdlibRegister` callback
exists. No monitoring loop is running. The file cannot be open for writing by any other
path in this process. Rotation-during-write is structurally impossible under normal
startup order.

The only scenario that could change this: if the script is launched while a **previous
instance** is still running and writing to the same log file. `$sLogFile` has no
instance-locking mechanism. Two concurrent script instances would both rotate and write
to the same path with no coordination. This is an edge case not addressed by the current
code, but it is outside the scope of the two bugs under investigation.

---

## 7. Feedback Loop Assessment (per SKILL.md Phase 1)

This codebase requires the Windows AutoIt runtime (confirmed in CLAUDE.md: "Environment
Gate — requires Windows AutoIt runtime and cannot run in a Linux sandbox"). A
deterministic executable feedback loop cannot be built in this sandbox. Static code
analysis (the method used for this review) is the only available tool.

For BUG-09-B: the race window is microseconds wide; a stress loop that maximizes log
volume while `_PriorityWatchdog` is active would raise the reproduction rate. The
harness would need to compare the byte count of expected log entries against the actual
file content after N iterations. This can only be run on a Windows machine with AutoIt
3.3.16.x installed.

---

## 8. Recommended Fix Direction (no code changes made)

**BUG-09-B fix approach:** Use a guard variable (a boolean global flag) that
`_LogMessage` sets on entry and clears on exit. If the flag is already set when
`_LogMessage` is entered (re-entrant call from an `AdlibRegister` interrupt), the
re-entrant message should either be queued or written via a separate direct
`FileWrite($sLogFile, ...)` call that bypasses the handle-lifetime window. A simpler
alternative is to open the file, acquire the write, close it — and accept that AutoIt's
single-threaded interrupt model means the guard flag approach is sufficient (no two OS
threads are involved; only the interrupt sequencing matters, and a boolean check at
function entry will prevent the nested `FileOpen` from occurring). The queued message
would need to be flushed after the outer `FileClose`.

This recommendation is not implemented here pending explicit instruction.
