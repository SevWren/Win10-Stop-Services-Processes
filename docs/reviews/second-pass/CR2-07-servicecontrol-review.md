# CR2-07 — ServiceControl.au3 Second-Pass Review

**File reviewed**: `Includes/ServiceControl.au3`
**Fixed point**: `ab5b012..HEAD` (file read directly; no diff computed — file unchanged since fixed point)
**Spec sources**:
- `docs/domain-modeling/servicecontrol-analysis.md`
- `docs/adr/0004-servicemanager-incompatible-with-servicecontrol-error-convention.md`
**Standards source**: `CODING_STANDARDS.md`, `CLAUDE.md`
**Review date**: 2026-11-12

---

## Standards

### S-1 (Hard violation) — Missing `#include-once`

The file has no `#include-once` directive. `CODING_STANDARDS.md` §AU3Check Compliance requires all `.au3` files to satisfy `AU3Check -q -d -w 1 -w 2 -w 3 -w 4`. Including `ServiceControl.au3` more than once in a compilation unit redefines every global constant, which triggers duplicate-declaration warnings under those flags. `ServiceManager.au3` correctly carries `#include-once`; this file does not. Flag as confirmed missing.

### S-2 (Hard violation) — All Win32 handles typed as `"long"` instead of `"handle"`

Confirmed throughout the file. Every `OpenSCManager`, `OpenService`, `CloseServiceHandle`, `StartService`, `ControlService`, `DeleteService`, and `CreateService` call uses `"long"` for the return type and for handle-typed input parameters. Examples:

- Line 109: `DllCall($hAdvapi32, "long", "OpenSCManager", ...)`
- Line 118: `DllCall($hAdvapi32, "long", "OpenService", "long", $hSC, ...)`
- Line 135: `DllCall($hAdvapi32, "int", "CloseServiceHandle", "long", $hService)`

The correct AutoIt DllCall type for a Win32 `SC_HANDLE` or `HANDLE` is `"handle"`. Using `"long"` truncates the value on 64-bit Windows where handles are 64-bit quantities. This is present in every function in the file (`_StartService`, `_StopService`, `_ServiceExists`, `_ServiceRunning`, `_CreateService`, `_DeleteService`). Affects every SCM or service handle in the file — not isolated to one function.

### S-3 (Hard violation) — `ControlService` third argument passes `"str", ""` where `LPSERVICE_STATUS` is required

Confirmed in two locations:

- `_StopService`, line 187–190:
  ```autoit
  $arRet = DllCall($hAdvapi32, "int", "ControlService", _
          "long", $hService, _
          "long", $SERVICE_CONTROL_STOP, _
          "str", "")
  ```
- `_ServiceRunning`, line 276–279:
  ```autoit
  $arRet = DllCall($hAdvapi32, "int", "ControlService", _
          "long", $hService, _
          "long", $SERVICE_CONTROL_INTERROGATE, _
          "str", "")
  ```

The Win32 `ControlService` third parameter is `LPSERVICE_STATUS` — a pointer to a 7-DWORD `SERVICE_STATUS` structure. Passing an empty string allocates a string buffer, not a struct. The returned service state is therefore inaccessible and effectively discarded. `_ServiceRunning` additionally uses the return value of `ControlService` directly as its running/not-running indicator (line 280: `$bRunning = $arRet[0]`), which is the integer success/failure code, not a state value — compounding the problem.

### S-4 (Hard violation) — `$STANDARD_RIGHTS_REQUIRED2` naming workaround still present

Line 1: `Global $STANDARD_RIGHTS_REQUIRED2 = 0x000F0000`

The trailing `2` is a collision-avoidance workaround because a constant with the same base name exists elsewhere. This violates the spirit of `CODING_STANDARDS.md` §AU3Check Compliance (no shadowed or ambiguous names) and is documented in `servicecontrol-analysis.md` §4 as a known source of confusion. The workaround is confirmed still present.

### S-5 (Judgement call — Duplicated Code smell)

All six functions open the SCM with `OpenSCManager`, perform their work, then close handles and call `DllClose`. The SCM-open/close scaffolding is copy-pasted verbatim across `_StartService`, `_StopService`, `_CreateService`, and `_DeleteService` (four functions share nearly identical setup/teardown blocks). `_ServiceExists` and `_ServiceRunning` omit the `kernel32` open but repeat the same SCM scaffolding. This is a Fowler **Duplicated Code** smell: the shared scaffolding pattern could be extracted into a helper. However, `servicecontrol-analysis.md` §2 explicitly documents the per-call SCM-open as a deliberate design choice ("shallow library") contrasted with `ServiceManager.au3`'s batched approach, so the duplication is architecturally intentional. Flag as a judgement call, not a hard violation.

### S-6 (Standards — `@error` capture after `DllCall` not done)

`CODING_STANDARDS.md` §@error Capture requires `@error` to be captured on the immediately following line after every `DllCall`. None of the `DllCall` sites in `ServiceControl.au3` capture `@error` at all; instead, the functions inspect `$arRet[0]` for a zero/nonzero result and call `GetLastError` explicitly when it is zero. The file predates the `@error`-capture standard and uses a different (older) error-detection idiom. This is a standards violation across all six functions, though it is a systematic legacy pattern rather than a one-off omission.

---

## Spec

### Spec source resolution

The fixed point is `ab5b012..HEAD`. The file is confirmed unchanged since that point (read directly). Two spec documents were supplied:

- `docs/domain-modeling/servicecontrol-analysis.md` — contributor analysis documenting the file's current state, known issues, and expected structure.
- `docs/adr/0004-servicemanager-incompatible-with-servicecontrol-error-convention.md` — ADR recording the decision to retain both modules with incompatible error conventions.

Both documents describe what the file *should* look like; findings below test the file against those descriptions.

### SP-1 (Pass) — `_StopService` is still present

Spec requirement (`servicecontrol-analysis.md` §3): "`_StopService` is **retained in the file** and not deleted, because there may be callers outside this codebase."

Confirmed: `_StopService` is present at lines 157–206. It is not removed.

### SP-2 (Pass) — All 5 non-stop helper functions are intact

The analysis doc §1 lists six public functions; five are non-stop helpers. All five are confirmed present:

| Function | Lines |
|---|---|
| `_StartService` | 97–146 |
| `_ServiceExists` | 216–242 |
| `_ServiceRunning` | 255–287 |
| `_CreateService` | 314–381 |
| `_DeleteService` | 391–438 |

No function has been removed or renamed.

### SP-3 (Partial fail) — Deprecation notice for `_StopService` not present in the file

The spec (`servicecontrol-analysis.md` §3 and §5) states that `_StopService` must not be called on the monitoring hot path and that its supersession by `_SM_StopServicesBatch` / `ServiceManager.au3` is the documented outcome. The ADR (§0004) records the permanent incompatibility and the decision to retain both modules with their native conventions.

The existing comment block above `_StopService` (lines 148–156) says only:

```
; Note: This function does not check to see if the service has stopped successfully
```

There is no deprecation notice, no reference to `ServiceManager.au3`, and no "superseded by `_SM_StopServicesBatch`" callout. The analysis doc and ADR both establish that callers must choose the right module; the file itself provides no in-source guidance to steer them. This is a partial spec miss: the function is retained (correct) but it carries no deprecation marker directing callers to the replacement.

### SP-4 (Pass) — Constants block is intact and complete

The spec describes a full set of `$SC_MANAGER_*`, `$SERVICE_*`, `$SERVICE_CONTROL_*`, service-type, start-type, and error-control constants as global. All constant groups are present (lines 1–87), consistent with the analysis doc §1.

### SP-5 (Pass) — Error convention is scalar (`1`/`0`/`@error`)

ADR-0004 requires `ServiceControl.au3` functions to follow the scalar return convention (return `1` on success, `0` on failure, `@error` = Win32 error code). All six functions do so: they return `1` at the success path and `Return 0` after `SetError($lError)` on the failure path. The convention is intact and consistent with the ADR.

---

## Summary

**Standards axis — 6 findings** (4 hard violations, 1 judgement call, 1 standards violation):
Worst issue: S-2 and S-3 together — `"long"` handle types truncate handles on 64-bit Windows, and the `ControlService` struct-pointer bug makes the status output from both `_StopService` and `_ServiceRunning` inaccessible. These are pre-existing bugs, not regressions introduced at this commit, but they remain unresolved.

**Spec axis — 4 findings** (3 passes, 1 partial fail):
Worst issue: SP-3 — `_StopService` carries no in-source deprecation notice pointing callers to `ServiceManager.au3`, despite the analysis doc and ADR both establishing that this redirection is required documentation.
