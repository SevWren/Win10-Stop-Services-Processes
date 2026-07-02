# CLAUDE.md — Win10-Stop-Services-Processes

## Project Overview

An AutoIt v3 script that runs as a persistent background process (system tray) on Windows 10/11. Its purpose is to suppress Windows Update and related telemetry activity by periodically terminating a hardcoded list of processes and stopping their backing services. Secondary features include process priority management and a priority watchdog. Requires administrator privileges (`#RequireAdmin`).

---

## Repository Layout

```
Stop Services Processes.au3   ← primary script (only file to edit)
Includes/
  ServiceControl.au3          ← custom DllCall service library (advapi32.dll)
  AutoItConstants.au3         ← bundled standard AutoIt include
  Date.au3                    ← bundled standard AutoIt include
  Misc.au3                    ← bundled standard AutoIt include
  MsgBoxConstants.au3         ← bundled standard AutoIt include
BackUp/                       ← historical version snapshots (do not edit)
release/
  Stop Services - Processes.Exe  ← compiled output (do not edit manually)
Log File/closure_log.txt      ← repo-tracked sample log
%HOMEDRIVE%/login/            ← runtime log location on user's machine
ff7.ico                       ← system tray icon
```

---

## Hardcoded Paths (Machine-Specific)

These paths inside `Stop Services Processes.au3` are specific to the author's machine and **must not be changed** without explicit instruction:

| Variable / Directive | Current Value |
|---|---|
| `#include` (ServiceControl) | `C:\github\my-github-info\Win10-Stop-Services-Processes\Includes\ServiceControl.au3` |
| `$iconfile` | `%HOMEDRIVE%\Users\mmuel\Documents\AutoIT\ff7.ico` |
| `$sLogFile` | `@HomeDrive & "\login\closure_log.txt"` |
| `#AutoIt3Wrapper_Outfile_x64` | `..\..\..\Users\mmuel\Desktop\Stop Services - Processes.Exe` |

---

## Architecture

### Execution Model
The script runs a passive main loop (`While 1 / Sleep(50) / WEnd`). All meaningful work is driven by hotkeys and `AdlibRegister` callbacks — never by modifying the main loop directly.

### Hotkeys
| Hotkey | Function | Behavior |
|---|---|---|
| `Shift + F1` | `ToggleScript()` | Starts/stops the active monitoring loop |
| `ScrollLock + PAUSE` | `_exit()` | Hard terminates the script |
| `Ctrl + Shift + 9` | `SetProcessPriority()` | One-shot: sets priority for all instances of a named process |
| `Ctrl + Alt + Shift + 9` | `LockProcessPriority()` | Locks a specific PID's priority; watchdog auto-restores on drift |

### Active Monitoring Loop (`ToggleScript`)
When started via Shift+F1, runs `While $bScriptRunning` and calls:
- `_CloseInstaller()` — kills processes in `$sProcesses[]` array every ~2 seconds
- `_stopservicescustom()` — stops services in `$aServiceNames[]` every ~2 seconds
- `_miscpopups()` — closes specific application registration dialogs

Timing uses `TimerInit()` / `TimerDiff()` via `CheckElapsedTime($iStartTime, $iIntervalSeconds)`.

### Priority Watchdog (`LockProcessPriority` + `_PriorityWatchdog`)
- `LockProcessPriority()`: collects PID + priority via `InputBox`, sets immediately, appends to three parallel global arrays, calls `AdlibRegister("_PriorityWatchdog", 10000)` only on first entry.
- `_PriorityWatchdog()`: fires every 10 seconds, iterates arrays backwards, removes dead PIDs, restores drifted priorities. Calls `AdlibUnRegister` when arrays empty.
- Multiple PIDs supported — one timer handles all of them.

---

## Coding Conventions

### Function Naming
- Hotkey-triggered (public): `PascalCase` — `ToggleScript`, `SetProcessPriority`, `LockProcessPriority`
- Internal/private: `_UnderscorePascalCase` — `_CloseInstaller`, `_LogMessage`, `_PriorityWatchdog`

### Logging
All events go through `_LogMessage($sMessage, $sType, $iLevel)`:
- `$iLevel` 0 = Error, 1 = Info, 2 = Verbose
- `$iLogLevel = 2` by default (Verbose)
- `$bLogToConsole = True` mirrors output to SciTE console
- Log type strings: `"System"`, `"Process"`, `"Service"`, `"ProcessPriority"`, `"PriorityWatchdog"`

### Region Structure
Code is organized into `#Region` / `#EndRegion` blocks:
1. `Includes/Options/Permissions/Hotkeys`
2. `Variables/Logging`
3. Functions follow (no region wrapper)

---

## AutoIt Version Compatibility Notes (3.3.16.1)

These are confirmed bugs/gaps encountered in the author's AutoIt installation — do not revert these decisions:

| Issue | Fix Applied |
|---|---|
| `$PROCESS_IDLE` not defined in `AutoItConstants.au3` | Manually declared `Global Const $PROCESS_IDLE = 0` in globals |
| `_WinAPI_GetPriorityClass` wrapper propagates unreliable `@error` values | `_GetProcessPriorityByPID` uses direct `DllCall("kernel32.dll", ...)` instead |
| `PROCESS_QUERY_INFORMATION` (0x0400) denied on some processes | Use `PROCESS_QUERY_LIMITED_INFORMATION` (0x1000) — sufficient for `GetPriorityClass` |
| `TrayTip` renders as large Windows 10/11 toast notification | Use `ToolTip()` via `_TrayNotify()` helper — tiny, no Action Center, no sound |
| `@error` overwritten by `_WinAPI_CloseHandle` after `_WinAPI_GetPriorityClass` | Always save `Local $iErr = @error` on the line immediately after any WinAPI call |

---

## ServiceControl.au3

Custom library wrapping `advapi32.dll` via `DllCall` directly (not using AutoIt's built-in service functions). Provides:
- `_ServiceRunning($sComputerName, $sServiceName)` — checks if service responds to `SERVICE_CONTROL_INTERROGATE`
- `_StopService($sComputerName, $sServiceName)` — sends stop control
- `_StartService`, `_ServiceExists`, `_CreateService`, `_DeleteService`

> **Note**: The main script calls `_stopservice(...)` (lowercase) — AutoIt function names are case-insensitive, so this correctly resolves to `_StopService` in `ServiceControl.au3`. Do not "fix" this inconsistency.

---

## WinAPI Priority Reading Pattern

The correct pattern for reading a process priority class — do not use `_WinAPI_GetPriorityClass`:

```autoit
Local Const $PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
Local $aOpen = DllCall("kernel32.dll", "handle", "OpenProcess", "dword", $PROCESS_QUERY_LIMITED_INFORMATION, "bool", False, "dword", $iPID)
If @error Or Not $aOpen[0] Then Return -1
Local $aResult   = DllCall("kernel32.dll", "dword", "GetPriorityClass", "handle", $aOpen[0])
Local $iDllError = @error
Local $iWinError = _WinAPI_GetLastError()   ; must be before CloseHandle
DllCall("kernel32.dll", "bool", "CloseHandle", "handle", $aOpen[0])
If $iDllError Or Not $aResult[0] Then Return -1
```

---

## Priority Constant Mapping

`_WinAPI_GetPriorityClass` / `GetPriorityClass` returns Windows API constants. `ProcessSetPriority` takes AutoIt constants. These are **different numbering schemes** — always use `_WinAPIPriorityClassToAutoItConst()` to convert.

| AutoIt Const | Value | Windows API Const | Hex |
|---|---|---|---|
| `$PROCESS_IDLE` | 0 | `$IDLE_PRIORITY_CLASS` | 0x40 |
| `$PROCESS_BELOWNORMAL` | 1 | `$BELOW_NORMAL_PRIORITY_CLASS` | 0x4000 |
| `$PROCESS_NORMAL` | 2 | `$NORMAL_PRIORITY_CLASS` | 0x20 |
| `$PROCESS_ABOVENORMAL` | 3 | `$ABOVE_NORMAL_PRIORITY_CLASS` | 0x8000 |
| `$PROCESS_HIGH` | 4 | `$HIGH_PRIORITY_CLASS` | 0x80 |
| `$PROCESS_REALTIME` | 5 | `$REALTIME_PRIORITY_CLASS` | 0x100 |

---

## User Notifications

Never use `TrayTip` for watchdog events — it produces large toast notifications on Windows 10/11.
Always use `_TrayNotify($sMessage)` which calls `ToolTip()` positioned bottom-right and auto-clears after 3 seconds via `AdlibRegister("_ClearTrayNotify", 3000)`.

---

## AU3Check Compiler Flags

```
-q -d -w 1 -w 2 -w 3 -w 4
```
- `-q` quiet, `-d` check undeclared variables, `-w 1-4` enable warning levels 1–4
- All compiler warnings should be resolved before committing

---

## Git / Deployment

- **Repo**: `https://github.com/SevWren/Win10-Stop-Services-Processes`
- **Branch**: `main`
- Compiled `.exe` lives in `release/` — rebuild via AutoIt3Wrapper after script changes
- `BackUp/` folder contains historical versions — never delete, never edit
