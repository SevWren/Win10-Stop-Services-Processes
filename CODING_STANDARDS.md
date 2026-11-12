# Coding Standards — Win10-Stop-Services-Processes

> This file is read by the code-review agent (Standards axis). It encodes reviewer-enforced
> standards derived from `CLAUDE.md`. Do not add implementation details here.

## Function Naming

> **Authority**: `CLAUDE.md` is the canonical source for naming conventions. This section must remain in sync with the "Coding Conventions → Function Naming" section of `CLAUDE.md`.

- Hotkey-triggered (public): `PascalCase` — `ToggleScript`, `SetProcessPriority`
- Internal/private: `_UnderscorePascalCase` — `_CloseInstaller`, `_LogMessage`
- Service-manager module: `_SM_PascalCase` — `_SM_StopServicesBatch`, `_SM_IsStopEligible`, `_SM_GetServiceState`

> **Note (CR-09)**: `_SM_PascalCase` is a valid third naming tier used by service-manager module helpers. `CLAUDE.md` ("Coding Conventions → Function Naming") is the canonical source for all naming tiers. If this section and `CLAUDE.md` ever conflict, `CLAUDE.md` wins.

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

## AU3Check Compliance

All `.au3` files must satisfy `AU3Check -q -d -w 1 -w 2 -w 3 -w 4`:
- Declare all variables with `Local` or `Global` before use
- Use `Dim` only for variables in the global scope outside a function
- Avoid shadowed variable names between Global and Local scopes

## Test File Conventions

- Test files live under `Tests/` (e.g., `Tests/ServiceControl.Tests.au3`) or use the `*.Tests.au3` naming suffix (e.g., `Includes/ServiceControl.Tests.au3`).
- The `g_` prefix for global variables in test harnesses is an accepted convention within test files and does not violate the standard variable naming rules applied to production code.
- Test harness files may use `ConsoleWrite` directly (see Logging → CR-03 exception above).
- Test files are excluded from the `_SM_PascalCase` removal note; they follow the same two-tier function naming as production code (`PascalCase` / `_UnderscorePascalCase`).

## Smell Baseline (Fowler, Refactoring ch.3)

The code-review Standards axis also applies these heuristics:
- **Mysterious Name**: rename if the name does not reveal what the variable/function does
- **Duplicated Code**: extract shared logic; do not copy-paste between functions
- **Speculative Generality**: remove parameters, hooks, or abstractions not needed by the spec
- **Shotgun Surgery**: a logical change that forces edits across many files signals a module boundary issue
