# Baseline Inventory
Branch: arch/service-manager-migration
Date: 2026-11-11
Ticket: T01 — Discover and Freeze the Baseline

---

## Repository Root

`/home/vercel-sandbox/repo` (cloned from https://github.com/SevWren/Win10-Stop-Services-Processes)

## Source Files

| File | Lines |
|---|---|
| `Stop Services Processes.au3` | 549 |
| `Includes/ServiceControl.au3` | 438 |
| `test_process_close.au3` | 14 |
| `CLAUDE.md` | ~230 |
| `README.md` | ~125 |

---

## Process Inventory — `$sProcesses[18]` (line 48)

Exactly 18 entries. **Note: index 15 and 16 are both `"xgamehelper.exe"` — deliberate duplicate or defect TBD.**

```
[0]  taskhostw.exe
[1]  TrustedInstaller.exe
[2]  TiWorker.exe
[3]  CompatTelRunner.exe
[4]  VSSVC.exe
[5]  msiexec.exe
[6]  msedge.exe
[7]  helppane.exe
[8]  net.exe
[9]  vmcompute.exe
[10] msedgewebview2.exe
[11] update.exe
[12] AggregatorHost.exe
[13] dllhost.exe
[14] TCPSVCS.EXE
[15] xgamehelper.exe     ← DUPLICATE
[16] xgamehelper.exe     ← DUPLICATE
[17] backgroundTaskHost.exe
```

**Version delta**: The zip-extracted version had 22 entries in `$sProcesses[22]` and an additional `$sProcesses2[2]` array with `["launcher-x64.exe", "PhoneExperienceHost.exe"]`. Those additions are NOT present in the cloned repo (HEAD of `main`).

---

## Service Inventory (line 165)

Declared locally inside `_stopservicescustom()` as `Local $aServiceNames`:

```
[0] TrustedInstaller
[1] wuauserv
[2] UsoSvc
[3] DoSvc
[4] WaaSMedicSvc
[5] sppsvc
```

`sppsvc` is additionally handled via `ProcessClose("sppsvc.exe")` at lines 183–193.

**Version delta**: The zip version and enterprise prompt also listed `FDResPub`, `fdPHost`, and `SSDPSRV`. These are absent in the cloned repo's service list.

---

## `#include` Directives (lines 20–30)

```
Line 20: #include "C:\github\my-github-info\Win10-Stop-Services-Processes\Includes\ServiceControl.au3"
Line 21: #include <MsgBoxConstants.au3>
Line 22: #include <AutoItConstants.au3>
Line 23: #include <Misc.au3>
Line 24: #include <Date.au3>
Line 25: #include <WinAPI.au3>
Line 26: #include <WinAPIProc.au3>
Line 27: #include <Array.au3>
Line 28: #include <WinAPI.au3>       ← DUPLICATE of line 25
Line 29: #include <WinAPIProc.au3>  ← DUPLICATE of line 26
Line 30: #include <Array.au3>       ← DUPLICATE of line 27
```

**Issues**:
- `ServiceControl.au3` include path is a hardcoded absolute machine-specific path.
- `<WinAPI.au3>`, `<WinAPIProc.au3>`, `<Array.au3>` are each included twice — AU3Check violations.

---

## `HotKeySet` Registrations (lines 36–41)

```
Line 36: HotKeySet("{ScrollLock}{PAUSE}", "_exit")
Line 37: HotKeySet("+{F1}", "ToggleScript")
Line 38: HotKeySet("+^9", "SetProcessPriority")   ; Ctrl+Shift+9
Line 39: HotKeySet("^!+9", "LockProcessPriority") ; Ctrl+Alt+Shift+9
Line 40: HotKeySet("+^9", "SetProcessPriority")   ← DUPLICATE of line 38
Line 41: HotKeySet("^!+9", "LockProcessPriority") ← DUPLICATE of line 39
```

**Issues**: `"+^9"` and `"^!+9"` registered twice each. Second registration overwrites the first (AutoIt behavior: last registration wins, but it wastes processing and may confuse AU3Check).

---

## `#AutoIt3Wrapper` Directives (lines 2–12)

```
#AutoIt3Wrapper_Icon=ff7.ico
#AutoIt3Wrapper_Outfile_x64=..\..\..\Users\mmuel\Desktop\Stop Services - Processes.Exe
#AutoIt3Wrapper_Compression=0
#AutoIt3Wrapper_Compile_Both=y
#AutoIt3Wrapper_UseX64=y
#AutoIt3Wrapper_Res_Description=Script monitors processes and services related to windows update and terminates if running.
#AutoIt3Wrapper_Res_Icon_Add=C:\github\my-github-info\Win10-Stop-Services-Processes\ff7.ico
#AutoIt3Wrapper_AU3Check_Parameters=-q -d -w 1 -w 2 -w 3 -w 4
#AutoIt3Wrapper_ShowProgress=Y
```

**Path issues**:
- `Outfile_x64`: relative path traverses up 3 levels to user desktop — machine-specific.
- `Res_Icon_Add`: absolute hardcoded path — machine-specific.

---

## Global Variable Declarations (lines 46–62)

```
Global $sStringInstaller = "In the _CloserInstaller function and just terminated"
Global $taskcloseran = 0
Global $sProcesses[18] = [...]
Global $bScriptRunning = False
Global $iLastStopServices = TimerInit()
Global $iconfile = @ScriptDir & "\ff7.ico"
Global $iLogMaxAgeDays = 7
Global $sLogFile = @HomeDrive & "\login\closure_log.txt"
Global $iLogLevel = 2
Global $bLogToConsole = True
Global Const $PROCESS_IDLE = 0
Global $aPriorityWatchPIDs[0]
Global $aPriorityWatchTargets[0]
Global $aPriorityWatchNames[0]
```

**Critical issue — undeclared variable `$iLastStopProcesses`**:
- Line 14: `;~ Global $iLastStopProcesses` — COMMENTED OUT
- Line 109: `If CheckElapsedTime($iLastStopProcesses, 2) Then` — USED but never declared
- Line 111: `$iLastStopProcesses = TimerInit()` — ASSIGNED but never declared
- **This will generate an AU3Check `-w 1` undeclared variable warning.**
- `TimerDiff` on an uninitialized variable returns a large elapsed time (wraps), so the
  process close loop fires immediately on first toggle — arguably the correct behavior,
  but the variable must be declared.

---

## Timing Values

| Usage | Value | Source |
|---|---|---|
| Main loop passive sleep | `Sleep(50)` ms | line 92 |
| Active loop sleep | `Sleep(500)` ms | line 118 |
| Process-kill check interval | `CheckElapsedTime($iLastStopProcesses, 2)` → 2000 ms | line 109 |
| Service-stop check interval | `CheckElapsedTime($iLastStopServices, 2)` → 2000 ms | line 114 |
| Priority watchdog AdlibRegister | `AdlibRegister("_PriorityWatchdog", 10000)` → 10000 ms | line 384 |
| TrayNotify auto-clear | `AdlibRegister("_ClearTrayNotify", 2000)` → 2000 ms | line 525 |
| Log max age | `$iLogMaxAgeDays = 7` → 7 days | line 54 |

**Note**: Both process and service intervals are `2` seconds (despite the comment at line 114 saying "10 seconds"). The enterprise prompt targets 10s for service polling — this is a conflict to resolve.

---

## Path Configuration

| Variable | Value |
|---|---|
| `$sLogFile` | `@HomeDrive & "\login\closure_log.txt"` |
| `$iconfile` | `@ScriptDir & "\ff7.ico"` |
| `#AutoIt3Wrapper_Outfile_x64` | `..\..\..\Users\mmuel\Desktop\Stop Services - Processes.Exe` |
| `#AutoIt3Wrapper_Res_Icon_Add` | `C:\github\my-github-info\Win10-Stop-Services-Processes\ff7.ico` |
| `#include ServiceControl.au3` | `C:\github\my-github-info\Win10-Stop-Services-Processes\Includes\ServiceControl.au3` |

**Migration status**: `$iconfile` already uses `@ScriptDir` (portable). `$sLogFile` uses `@HomeDrive` (acceptable). The `#include`, `Outfile_x64`, and `Res_Icon_Add` paths are still machine-specific.

---

## Known Broken Behaviors (from source)

No "Warning - Stop Services not working currently" comment in this version (that comment was in the zip version only). However, the broken behavior IS present:

1. `_ServiceRunning()` in `ServiceControl.au3` determines running state by sending `SERVICE_CONTROL_INTERROGATE` — this is unreliable. Protected services (e.g., `WaaSMedicSvc`) may refuse the control even when running. If `_ServiceRunning()` returns 0 for a running service, `_stopservice()` is never called.

2. `_StopService()` in `ServiceControl.au3` sends `ControlService(SERVICE_CONTROL_STOP)` and returns immediately — it does NOT wait for the service to reach `SERVICE_STOPPED` state. The return value of `_StopService()` indicates only whether the stop *control was accepted*, not whether the service stopped.

3. The `ControlService` call in `ServiceControl.au3` passes `"str", ""` as the third parameter (the `lpServiceStatus` output struct) — this is incorrect. `ControlService` requires a valid `SERVICE_STATUS` struct pointer. Passing an empty string results in undefined behavior. This is likely the root cause of unreliable service stopping.

---

## AU3Check Concerns

| Issue | Location | Severity |
|---|---|---|
| `$iLastStopProcesses` used but never declared | line 109, 111 | WARNING (-w 1 undeclared var) |
| `#include <WinAPI.au3>` duplicated | lines 25, 28 | WARNING |
| `#include <WinAPIProc.au3>` duplicated | lines 26, 29 | WARNING |
| `#include <Array.au3>` duplicated | lines 27, 30 | WARNING |
| `HotKeySet("+^9", ...)` duplicated | lines 38, 40 | WARNING |
| `HotKeySet("^!+9", ...)` duplicated | lines 39, 41 | WARNING |
| `xgamehelper.exe` duplicated in `$sProcesses` | index 15, 16 | INFORMATIONAL |
| `ControlService` receives `"str", ""` as SERVICE_STATUS | ServiceControl.au3 line 190 | FUNCTIONAL BUG |
| Handle type `"long"` used for SCM/service handles | ServiceControl.au3 | CORRECTNESS (64-bit) |

---

## ServiceControl.au3 Technical Findings

### Handle Type Issue
All SCM handles (`$hSC`, `$hService`) are declared with type `"long"` in DllCall parameters.
On 64-bit Windows, `SC_HANDLE` is 64 bits. Using `"long"` truncates to 32 bits and will
corrupt the handle value on 64-bit systems. Correct type string is `"handle"`.

### ControlService `lpServiceStatus` Parameter
```autoit
; INCORRECT (ServiceControl.au3 line 187-191):
$arRet = DllCall($hAdvapi32, "int", "ControlService", _
        "long", $hService, _
        "long", $SERVICE_CONTROL_STOP, _
        "str", "")       ; ← WRONG: must be a valid SERVICE_STATUS struct pointer
```

The `ControlService` Windows API requires a `LPSERVICE_STATUS` output parameter (pointer to a 7-DWORD structure). Passing `"str", ""` does not allocate the structure. This causes the DllCall to fail or write to an invalid address.

### `_ServiceRunning` Reliability
Uses `SERVICE_CONTROL_INTERROGATE` to test if a service is running. Protected services
(SFC, WaaS, etc.) reject `INTERROGATE` even when running. `QueryServiceStatus` is the
correct API for state inspection.

---

## Toolchain Availability

| Tool | Status |
|---|---|
| `git` | Available — v2.49.0 |
| `au3check` | NOT AVAILABLE (Windows binary) |
| AutoIt compiler | NOT AVAILABLE (Windows binary) |
| `curl` | Available — v8.17.0 |
| `python3` | Available — v3.9.25 |
| Linux kernel | 6.18.56 x86_64 |

**Implication**: AU3Check and compilation gates are marked `NOT RUN — Windows environment required`
throughout this effort. All `.au3` code must be written to satisfy `AU3Check -q -d -w 1 -w 2 -w 3 -w 4`
by construction, following `CLAUDE.md` and `CODING_STANDARDS.md`.

---

## Decisions Triggered by This Baseline

| Finding | Decision | Recorded In |
|---|---|---|
| `$iLastStopProcesses` undeclared | Declare as `Global $iLastStopProcesses` in globals section | T04 integration |
| Duplicate `#include` lines | Remove 3 duplicate pairs in T04 | T04 |
| Duplicate `HotKeySet` lines | Remove 2 duplicate pairs in T04 | T04 |
| `ControlService` wrong struct type | ServiceManager.au3 uses `DllStructCreate` for SERVICE_STATUS | T03 |
| Handle type `"long"` in ServiceControl.au3 | ServiceManager.au3 uses `"handle"` type strings | T03 |
| Service interval comment mismatch | Resolve: use 10s for service polling per enterprise prompt | T04 |
| Machine-specific include/build paths | Migrate to relative paths in T04 | T04 |
| `xgamehelper.exe` duplicate | Investigate before changing — retain unless confirmed defect | T04 |
