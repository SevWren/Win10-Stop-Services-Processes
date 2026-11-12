# Issue 11 — Delete `Includes/ServiceControl.au3`

**Status:** ready-for-agent
**Blocked by:** ADR-0012 (decision already recorded — proceed immediately)

---

## Context

`Includes/ServiceControl.au3` is a hand-rolled Win32 DLL wrapper that exposes
`_StartService`, `_StopService`, `_ServiceExists`, `_ServiceRunning`,
`_CreateService`, and `_DeleteService`. ADR-0012 resolved to delete it because:

- The script's own `CLAUDE.md` documents that service-stopping is currently
  non-functional ("The source currently warns that service stopping is not
  working.").
- Line 14 of `Stop Services Processes.au3` already carries the in-source
  warning: `; Warning - Stop Services not working currently in this script.`
- None of the six functions are called anywhere in the active codebase.
- The active service-management path is being superseded by `ServiceManager.au3`
  (uses `$SM_*` constants in its own namespace — entirely independent).
- Keeping a dead include creates AU3Check noise and misleads future agents.

---

## Tasks

### 1. Delete `Includes/ServiceControl.au3`

Remove the file from the repository:

```
Includes/ServiceControl.au3
```

### 2. Remove the `#include` directive and its comment block from `Stop Services Processes.au3`

The block to remove is at lines 14 and 19-23 of `Stop Services Processes.au3`
(exact current text shown below — verify line numbers before editing):

```autoit
; Warning - Stop Services not working currently in this script.


...
#Region ;Includes/Options/Permissions
;This is the ServiceControlAu3 library included in the repo

;Autoit AU3 library Location `Program Files (x86)\AutoIt3\Include`
#include "C:\github\my-github-info\Win10-Stop-Services-Processes\Includes\ServiceControl.au3"
```

Specifically, delete:
- Line 14: `; Warning - Stop Services not working currently in this script.`
- The two blank lines that follow it (lines 15-16) — only if they become
  trailing whitespace after removing line 14; preserve any blank line that
  separates the `#AutoIt3Wrapper_ShowProgress` directive from the `#Region`
  block.
- Lines 20-23 inside the `#Region ;Includes/Options/Permissions` block:
  ```
  ;This is the ServiceControlAu3 library included in the repo

  ;Autoit AU3 library Location `Program Files (x86)\AutoIt3\Include`
  #include "C:\github\my-github-info\Win10-Stop-Services-Processes\Includes\ServiceControl.au3"
  ```
  Leave the `#Region` / `#EndRegion` markers and all other `#include` lines
  intact.

### 3. Verify no calls to the deleted functions remain anywhere

Search the entire working tree for each of the following identifiers. The search
must return zero matches (excluding the now-deleted `ServiceControl.au3` itself):

- `_ServiceRunning`
- `_ServiceExists`
- `_StartService`
- `_CreateService`
- `_DeleteService`
- `_StopService`

Suggested command (run from the project root):

```bash
grep -rn "_ServiceRunning\|_ServiceExists\|_StartService\|_CreateService\|_DeleteService\|_StopService" \
  --include="*.au3" .
```

Expected result: no output. If any match is found, stop and report it; do not
proceed with the remaining tasks until it is resolved.

### 4. Verify `$SM_*` constants in `ServiceManager.au3` are unaffected

`ServiceManager.au3` uses its own `$SM_*` constant namespace which has no
overlap with `ServiceControl.au3`. Confirm the file is present and that none
of its constants or functions reference `$SC_MANAGER_*`, `$SERVICE_CONTROL_*`,
or the six function names listed in task 3.

Suggested command:

```bash
grep -n "SC_MANAGER\|SERVICE_CONTROL\|_ServiceRunning\|_ServiceExists\|_StartService\|_CreateService\|_DeleteService\|_StopService" \
  ServiceManager.au3
```

Expected result: no output. If `ServiceManager.au3` does not exist yet, note
that in your report and skip this check.

### 5. Update `docs/adr/README.md` to note the ADR-0012 decision

Add a row for ADR-0012 in the ADR index table. The entry should record:

| ID     | Title                              | Status   |
|--------|------------------------------------|----------|
| 0012   | ServiceControl — keep or delete    | Accepted |

If `docs/adr/README.md` does not exist, create it with the table above plus a
brief header (one sentence explaining that ADRs record significant architectural
decisions for this project).

### 6. Update `CLAUDE.md` to remove the stale `_stopservice` reference

In `/home/vercel-sandbox/Win10-Stop-Services-Processes/CLAUDE.md`, the
**Runtime model** section contains:

> The source currently warns that service stopping is not working. Treat
> service-stop behavior as unverified: add or run targeted validation before
> reporting it works.

And the **Implementation guardrails** section contains:

> Do not claim the service-management path is functional without targeted
> runtime evidence.

After this issue is completed, service-stop via `ServiceControl.au3` no longer
exists at all, so both notes become misleading. Replace them with a single
accurate note in **Runtime model**:

> Service stopping via the former `ServiceControl.au3` wrapper has been removed
> (ADR-0012). Service management is now handled exclusively through
> `ServiceManager.au3`.

Remove the separate guardrail note in **Implementation guardrails** entirely.

### 7. Run AU3Check and confirm clean

Run AU3Check with the project-configured flags against the edited main script:

```bash
Au3Check -q -d -w 1 -w 2 -w 3 -w 4 "Stop Services Processes.au3"
```

Expected result: exit code 0, no warnings or errors printed.

If AU3Check is not available in the current environment, state that validation
was static only and describe what was verified manually.

---

## Acceptance criteria

- [ ] `Includes/ServiceControl.au3` is gone from the working tree.
- [ ] `Stop Services Processes.au3` has no reference to `ServiceControl.au3`
      (neither the `#include` line nor either associated comment line).
- [ ] Grep confirms zero remaining calls to the six deleted functions across all
      `.au3` files.
- [ ] `ServiceManager.au3` (if present) is confirmed unaffected.
- [ ] `docs/adr/README.md` lists ADR-0012 as Accepted.
- [ ] `CLAUDE.md` no longer references `_stopservice` or the broken
      service-stop warning; instead references ADR-0012 and `ServiceManager.au3`.
- [ ] AU3Check exits clean (or static-only validation is explicitly declared).

---

## Files touched

| File | Change |
|------|--------|
| `Includes/ServiceControl.au3` | Delete |
| `Stop Services Processes.au3` | Remove `#include` line and comment block (lines 14, 20-23) |
| `docs/adr/README.md` | Add ADR-0012 row (create file if absent) |
| `CLAUDE.md` | Replace stale service-stop warning with ADR-0012 reference |

---

## Notes for the agent

- The `#include` path in the source is an absolute machine-specific path
  (`C:\github\...`). The whole line must be deleted, not rewritten to a
  relative path, since the entire include is being removed.
- Do not touch any other `#include` lines or any other region of
  `Stop Services Processes.au3`.
- `$SM_*` constants (`$SM_SERVICE_RUNNING`, etc.) live in `ServiceManager.au3`
  and are entirely separate from the `$SC_MANAGER_*` / `$SERVICE_*` constants
  that lived in `ServiceControl.au3`. Do not conflate them.
- Compiled `.exe` artifacts are build artifacts per project convention; do not
  rebuild the `.exe` as part of this issue unless explicitly instructed.
