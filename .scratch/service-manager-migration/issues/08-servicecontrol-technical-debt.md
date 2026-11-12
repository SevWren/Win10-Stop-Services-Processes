# 08: ServiceControl.au3 — Fix Three Pre-existing Technical Defects

**What to build:** Resolve three confirmed Win32 correctness bugs in `Includes/ServiceControl.au3` that were identified during the second-pass code review (CR2-07). The three defects are:

1. **`ControlService` third-argument type mismatch** — `_StopService` (line 187–190) and `_ServiceRunning` (line 276–279) both pass `"str", ""` as the third argument to `ControlService`. The Win32 API requires `LPSERVICE_STATUS` — a pointer to a 7-DWORD `SERVICE_STATUS` struct. The correct fix is to allocate the struct with `DllStructCreate("dword;dword;dword;dword;dword;dword;dword")` and pass `"ptr", DllStructGetPtr(...)`, matching the pattern already used in `ServiceManager.au3`. Without this fix, `_ServiceRunning` returns the integer success/failure code of `ControlService` rather than the actual service state, and both functions silently discard the returned `SERVICE_STATUS` data.

2. **All Win32 handles typed `"long"` instead of `"handle"`** — Every `DllCall` in the file uses `"long"` for `SC_HANDLE` and `HANDLE` return types and input parameters (confirmed at `OpenSCManager`, `OpenService`, `CloseServiceHandle`, `StartService`, `ControlService`, `DeleteService`, `CreateService` sites across all six functions). On 64-bit Windows, handles are 64-bit quantities; `"long"` truncates them to 32 bits. The fix is a mechanical substitution of `"long"` → `"handle"` at every handle-typed DllCall position. `ServiceManager.au3` already uses `"handle"` throughout and is not affected.

3. **`$STANDARD_RIGHTS_REQUIRED2` naming workaround** — Line 1 declares `Global $STANDARD_RIGHTS_REQUIRED2 = 0x000F0000` with a trailing `2` to avoid a name collision with a constant of the same base name elsewhere in the include chain. This violates the AU3Check compliance requirement (no shadowed or ambiguous names, `-w 1 -w 2 -w 3 -w 4`) and is documented in `servicecontrol-analysis.md §4` as a known source of confusion. The fix requires identifying the collision source, choosing a resolution (rename the constant in this file to a scoped form such as `$SC_STANDARD_RIGHTS_REQUIRED`, or remove the duplicate from the other source), and updating all references.

**Scope note:** ADR-0011 establishes that `_StopService` is deprecated for stop operations on the monitoring hot path; `ServiceManager.au3`'s `_SM_StopServicesBatch` owns that responsibility. However, defects 1 and 2 affect the five non-stop helper functions (`_ServiceExists`, `_ServiceRunning`, `_StartService`, `_CreateService`, `_DeleteService`) that remain on the active path and have no equivalent in `ServiceManager.au3`. Fixing these bugs therefore matters regardless of what happens to `_StopService`.

**Decision gate:** Before implementing, a maintainer must decide: **keep `ServiceControl.au3` and fix it, or deprecate all remaining functions and eventually delete the file.** That decision should be recorded as an ADR. This issue is blocked until that ADR exists and resolves in favour of fixing.

**Blocked by:** ADR decision — keep-and-fix vs. deprecate-and-delete `ServiceControl.au3` (no ADR exists yet)

**Status:** needs-triage

---

## Evidence

| Finding ID | Source | Description |
|---|---|---|
| S-3 | `docs/reviews/second-pass/CR2-07-servicecontrol-review.md §S-3` | `ControlService` third arg is `"str", ""` not `LPSERVICE_STATUS` struct pointer |
| S-2 | `docs/reviews/second-pass/CR2-07-servicecontrol-review.md §S-2` | All Win32 handles typed `"long"` throughout all six functions |
| S-4 | `docs/reviews/second-pass/CR2-07-servicecontrol-review.md §S-4` | `$STANDARD_RIGHTS_REQUIRED2` naming workaround still present at line 1 |

Supporting analysis:

- `docs/domain-modeling/servicecontrol-analysis.md §4` — documents all three issues as known pre-existing bugs
- `docs/adr/0011-servicecontrol-servicemanager-boundary-convention.md` — establishes that `_StopService` is deprecated; non-stop helpers remain active
- `docs/adr/0004-servicemanager-incompatible-with-servicecontrol-error-convention.md` — records the permanent incompatibility between the two files' error conventions; the scalar `1`/`0`/`@error` convention in `ServiceControl.au3` must be preserved by any fix

---

## Checklist (contingent on ADR decision to keep-and-fix)

- [ ] ADR recorded: keep `ServiceControl.au3` and fix three defects (this issue remains blocked until that ADR exists)
- [ ] Defect 1 — `ControlService` struct fix:
  - [ ] Allocate `SERVICE_STATUS` struct in `_StopService` (line ~187) using `DllStructCreate("dword;dword;dword;dword;dword;dword;dword")`
  - [ ] Replace `"str", ""` with `"ptr", DllStructGetPtr($tStatus)` in the `ControlService` DllCall
  - [ ] Repeat for `_ServiceRunning` (line ~276); update the running-state check to read `dwCurrentState` from field 2 of the struct rather than from `$arRet[0]`
- [ ] Defect 2 — `"long"` → `"handle"` substitution:
  - [ ] Replace `"long"` with `"handle"` at every handle-typed position in `_StartService`, `_StopService`, `_ServiceExists`, `_ServiceRunning`, `_CreateService`, `_DeleteService`
  - [ ] Confirm no `"long"` handle-typed positions remain after substitution
- [ ] Defect 3 — `$STANDARD_RIGHTS_REQUIRED2` naming collision:
  - [ ] Identify the source of the name collision (which other include defines the base-name constant)
  - [ ] Choose resolution: scoped rename in this file or removal of the duplicate elsewhere
  - [ ] Update all references to `$STANDARD_RIGHTS_REQUIRED2` in `ServiceControl.au3` and any callers
- [ ] AU3Check passes at `-q -d -w 1 -w 2 -w 3 -w 4` with no new warnings after all three fixes
- [ ] Existing scalar `1`/`0`/`@error` return convention (required by ADR-0004) is preserved across all fixed functions

---

## Comments

<!-- Append discussion below this line -->
