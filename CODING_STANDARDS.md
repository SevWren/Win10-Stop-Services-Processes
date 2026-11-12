# Coding Standards — Win10-Stop-Services-Processes

> This file is read by the code-review agent (Standards axis). It encodes reviewer-enforced
> standards derived from `CLAUDE.md`. Do not add implementation details here.

## Function Naming

> **Authority**: `CODING_STANDARDS.md` is the canonical source for naming conventions. `CLAUDE.md` §"Coding Conventions → Function Naming" is a summary kept in sync with this section. If the two files conflict, this file wins.

Three naming tiers are defined for this codebase:

| Tier | Convention | Examples |
|---|---|---|
| Hotkey-triggered (public) | `PascalCase` | `ToggleScript`, `SetProcessPriority`, `LockProcessPriority` |
| Internal/private | `_UnderscorePascalCase` | `_KillProcessList`, `_LogMessage`, `_PriorityWatchdog` |
| Service-manager module | `_SM_PascalCase` | `_SM_StopServicesBatch`, `_SM_IsStopEligible`, `_SM_GetServiceState` |

The `_SM_PascalCase` tier applies exclusively to functions defined inside `Includes/ServiceManager.au3`. All other private/internal helpers use `_UnderscorePascalCase`.

> **Reviewer check**: AU3Check does not enforce identifier naming conventions. The reviewer must grep for `^Func _[a-z]` across all production `.au3` files (excluding `Includes/Date.au3`, `Includes/Misc.au3`, `Includes/AutoItConstants.au3`, `Includes/MsgBoxConstants.au3`). Any match is a hard naming violation — the character immediately after `_` must be uppercase for all `_`-prefixed functions outside `ServiceManager.au3`.

## Logging

All runtime log messages MUST route through `_LogMessage($sMessage, $sType, $iLevel)`.
Direct `ConsoleWrite` calls outside of initialization/debug code are NOT permitted.
Log types in use: `"System"`, `"Process"`, `"Service"`, `"ProcessPriority"`, `"PriorityWatchdog"`.

**Exception (CR-03)**: Test harness files (`Tests/*.au3`, `Includes/*.Tests.au3`) may use `ConsoleWrite` directly for test runner output. This is intentional for CI-friendly, human-readable output from the test runner and is not subject to the `_LogMessage` routing requirement.

## @error Capture

After every `DllCall`, capture `@error` on the IMMEDIATELY following line:

```autoit
Local $aResult = DllCall(...)
Local $iDllError = @error   ; capture BEFORE any other call
```

When a Windows API may set `GetLastError`, call `_WinAPI_GetLastError()` on the line
after capturing `@error`, before any other API call (including `CloseHandle`).

## Handle Ownership

Every opened SCM handle or service handle has EXACTLY ONE cleanup path.
Every `DllOpen` has a matching `DllClose`. Every `OpenProcess` has a matching `CloseHandle`.
Failure returns MUST close any handles already acquired before returning.

## WinAPI Patterns

Use `PROCESS_QUERY_LIMITED_INFORMATION` (0x1000), not `PROCESS_QUERY_INFORMATION` (0x0400),
when querying process priority class. See `CLAUDE.md` section "WinAPI Priority Reading Pattern".

Never call `_WinAPI_GetPriorityClass` — use direct `DllCall("kernel32.dll", ...)`.

Never use `TrayTip` for watchdog notifications — use `_TrayNotify()` via `ToolTip()`.

## Path Portability

No hardcoded checkout roots, user-profile paths, or desktop paths in source or docs.
All project asset paths derive from `@ScriptDir`. Log path defaults to `@HomeDrive & "\login\"`.
Build output derives from the working directory.

## Duplicate Prevention

No `#include` directive may appear twice in the same file.
No `HotKeySet` call may register the same key combination twice.
No process name may appear in both `$sProcesses[]` and `$sProcesses2[]`.
No `Global Const` with the same identifier may be declared in more than one included file. Shared log-level and log-type constants (`$LOG_LEVEL_*`, `$LOG_TYPE_*`) are defined exclusively in `Stop Services Processes.au3` and must not be redeclared in `Includes/*.au3`. The duplicate declarations in `Includes/ServiceManager.au3` are a known temporary workaround for the test harness's standalone compilation context; the correct long-term fix is a shared `Includes/LogConstants.au3` include.

> **Reviewer note — orphaned constants**: A `Global Const` that is defined but never read anywhere in the compilation unit is a Speculative Generality smell. Grep for the constant name across all included files; if no read site exists outside the declaration line, flag it for removal or correction. Known instance: `$SM_STOP_ELIGIBLE_STATES` in `Includes/ServiceManager.au3` is defined but never read by `_SM_IsStopEligible` (which uses a `Switch` over integer state constants instead). The comment claiming "Used by `_SM_IsStopEligible`" is incorrect and should be removed or corrected to "documentation-only".

## AU3Check Compliance

All `.au3` files must satisfy `AU3Check -q -d -w 1 -w 2 -w 3 -w 4`:
- Declare all variables with `Local` or `Global` before use
- Use `Dim` only for variables in the global scope outside a function
- Avoid shadowed variable names between Global and Local scopes

## Test File Conventions

- Test files live under `Tests/` (e.g., `Tests/ServiceControl.Tests.au3`) or use the `*.Tests.au3` naming suffix (e.g., `Includes/ServiceControl.Tests.au3`).
- The `g_` prefix for global variables in test harnesses is an accepted convention within test files and does not violate the standard variable naming rules applied to production code.
- Test harness files may use `ConsoleWrite` directly (see Logging → CR-03 exception above).
- Test helper functions follow the same two-tier naming as production code (`PascalCase` / `_UnderscorePascalCase`). The `_SM_PascalCase` tier is not used in test files — only in `Includes/ServiceManager.au3` itself.

## Constant Naming

All `Global Const` declarations must use a `$PREFIX_Name` pattern. The prefix identifies the owning module or category:

| Prefix | Scope | Defined in | Examples |
|---|---|---|---|
| `$LOG_LEVEL_` | Shared logging | `Stop Services Processes.au3` | `$LOG_LEVEL_ERROR`, `$LOG_LEVEL_INFO`, `$LOG_LEVEL_VERBOSE` |
| `$LOG_TYPE_` | Shared logging | `Stop Services Processes.au3` | `$LOG_TYPE_SYSTEM`, `$LOG_TYPE_SERVICE` |
| `$AUTOIT_PRIORITY_` | Process priority mapping | `Stop Services Processes.au3` | `$AUTOIT_PRIORITY_IDLE`, `$AUTOIT_PRIORITY_HIGH` |
| `$SM_STATE_` | ServiceManager module | `Includes/ServiceManager.au3` | `$SM_STATE_STOPPED`, `$SM_STATE_RUNNING` |
| `$SM_OUTCOME_` | ServiceManager module | `Includes/ServiceManager.au3` | `$SM_OUTCOME_STOPPED`, `$SM_OUTCOME_FAILED` |
| `$SM_ERR_` | ServiceManager module | `Includes/ServiceManager.au3` | `$SM_ERR_ACCESS_DENIED`, `$SM_ERR_SVC_NOT_EXIST` |
| `$SM_SC_MANAGER_` / `$SM_SERVICE_` | ServiceManager SCM access rights | `Includes/ServiceManager.au3` | `$SM_SC_MANAGER_CONNECT`, `$SM_SERVICE_QUERY_AND_STOP` |

New constants in `Includes/ServiceManager.au3` must use the `$SM_` prefix. New constants in the main script that do not belong to any module use a category prefix (`$LOG_`, `$AUTOIT_`, etc.). Do not introduce a new prefix without updating this table.

---

## Region Structure

All `#Region` / `#EndRegion` blocks must carry a matching label on both the opening and closing tag:

```autoit
#Region ;Configuration — Log constants
...
#EndRegion ;Configuration — Log constants
```

The three canonical top-level regions in `Stop Services Processes.au3` are:
1. `Includes/Options/Permissions/Hotkeys`
2. `Variables/Logging`
3. (Functions follow with no outer region wrapper)

Configuration-data regions within the script use the `Configuration —` prefix followed by the data category (e.g., `Configuration — Log constants`, `Configuration — AutoIt process priority constants`, `Configuration — Target lists`). Do not use a bare name without the `Configuration —` prefix for configuration-data regions.

---

## Smell Baseline (Fowler, Refactoring ch.3)

The code-review Standards axis also applies these heuristics:
- **Mysterious Name**: rename if the name does not reveal what the variable/function does
- **Duplicated Code**: extract shared logic; do not copy-paste between functions
- **Speculative Generality**: remove parameters, hooks, or abstractions not needed by the spec
- **Shotgun Surgery**: a logical change that forces edits across many files signals a module boundary issue
