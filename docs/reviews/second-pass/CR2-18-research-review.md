# CR2-18 — Research Documents Second-Pass Review

**Reviewer**: Claude (automated)
**Date**: 2026-11-12
**Fixed point**: `ab5b012..HEAD`
**Commits in range**:
```
1d8a5ea feat: replace broken service-stop path with native SCM batch-stop module
2a62801 chore(cleanup)
09b99ba Added claude skill sets
```
**Files under review**:
- `docs/research/windows-scm-api.md`
- `docs/research/autoit-dllcall.md`

**Spec source**: `Includes/ServiceManager.au3` (actual implementation), enterprise prompt (9-service inventory), `Stop Services Processes.au3` configuration region.

---

## Standards

Both documents are research/reference notes, not production `.au3` code, so the CODING_STANDARDS.md function-naming, `@error` capture, handle-ownership, and AU3Check rules do not apply directly. The applicable standards for research documents in this repo are:

- Accuracy of citations and provenance disclosure
- Verification claims must be true
- Content must match what the production code actually does
- Smell baseline applies where relevant (Mysterious Name, Speculative Generality, etc.)

### autoit-dllcall.md

**[PASS] Source citation blockquote present.**
Lines 7–9 contain the required blockquote:

> NOTE: Primary source (autoitscript.com) was unavailable during research. Content verified against `Includes/ServiceManager.au3` implementation — all DllCall patterns documented here have been confirmed in the production code.

**[PASS] Verification claim is true.**
Cross-check against `ServiceManager.au3` confirms the claim:

| Documented pattern | Production usage in ServiceManager.au3 | Match |
|--------------------|----------------------------------------|-------|
| `"handle"` type for SC_HANDLE / HANDLE | `OpenSCManagerW`, `OpenServiceW`, `CloseServiceHandle`, `ControlService`, `QueryServiceStatus` — all use `"handle"` for handle params | Yes |
| `"wstr"` for LPCWSTR (W-suffixed APIs) | `OpenSCManagerW` passes `"wstr", "ServicesActive"`; `OpenServiceW` passes `"wstr", $sName` | Yes |
| `"ptr"` + `DllStructGetPtr($struct)` for output struct pointer | `QueryServiceStatus` and `ControlService` both pass `"ptr", DllStructGetPtr($t...)` | Yes |
| `"bool"` return type for BOOL-returning functions | `QueryServiceStatus`, `ControlService`, `CloseServiceHandle` all use `"bool"` as return type | Yes |
| `"dword"` for DWORD parameters | control code and access-right parameters throughout | Yes |
| Field 2 = `dwCurrentState` (1-based indexing) | `DllStructGetData($tQueryStatus, 2)` and `DllStructGetData($tPollStatus, 2)` | Yes |
| SERVICE_STATUS struct: 7 DWORD fields | `DllStructCreate("dword;dword;dword;dword;dword;dword;dword")` — 7 fields, used for both `QueryServiceStatus` and `ControlService` | Yes |

**[PASS] Handle type guidance is correct and consistent.**
The document states `"handle"` is the correct type for SC_HANDLE in AutoIt 3.3.14+ and that `"long"` truncates handles on 64-bit. Production code uses `"handle"` throughout — no `"long"` for handle types.

**[MINOR] `DllOpen` / `DllClose` section is documented but not used in production.**
The document covers `DllOpen`/`DllClose` for tight-loop DLL usage. `ServiceManager.au3` uses inline `"advapi32.dll"` string calls exclusively, not `DllOpen`. The document correctly notes that inline string calls are conventional for well-known system DLLs. This is accurate information and not speculative generality — it is a reasonable reference entry for a general DllCall research doc. No action required.

**[MINOR] No coverage of `@error` semantics after `DllStructCreate`.**
The `@error After DllStructCreate` table is present and correct. However, the production code does not check `@error` after `DllStructCreate` calls — it calls `DllStructCreate` and immediately uses the result. The document does not comment on whether checking is mandatory or optional in practice. This is a minor gap in guidance, not an inaccuracy.

### windows-scm-api.md

**[PASS] `QueryServiceStatusEx` section is present.**
Lines 102–160 document `QueryServiceStatusEx` in full, including signature, parameters, InfoLevel constant, return value, and error codes.

**[PASS] Rationale for using `QueryServiceStatus` instead of `QueryServiceStatusEx` is documented.**
Line 160 contains an explicit documented-choice note: the implementation uses `QueryServiceStatus` because it only needs `dwCurrentState` and not the PID; `QueryServiceStatusEx` was a research target because the original design anticipated needing the PID but the final implementation confirmed it was not required. This correctly describes what `ServiceManager.au3` does.

**[PASS] Service inventory reconciliation section is present.**
Lines 484–524 contain the "Service Inventory Reconciliation" section with baseline vs. enterprise-prompt comparison table.

**[PASS] All 9 services are present in the reconciliation table.**
The table lists: `FDResPub`, `fdPHost`, `TrustedInstaller`, `wuauserv`, `UsoSvc`, `DoSvc`, `WaaSMedicSvc`, `SSDPSRV`, `sppsvc` — 9 services, matching the enterprise prompt.

**[PASS] Per-service reference section is accurate.**
The per-service notes (lines 514–524) are consistent with the services' known behaviors and special constraints (WaaSMedicSvc protected service, sppsvc may resist stop, fdPHost/FDResPub dependency ordering).

---

## Spec

The spec for these research documents is two-part: (1) the enterprise prompt specified the 9-service inventory, and (2) `ServiceManager.au3` is the authoritative implementation against which documentation accuracy is verified.

### Does windows-scm-api.md cover all Win32 functions used in ServiceManager.au3?

ServiceManager.au3 makes DllCall to these functions:

| Function called in ServiceManager.au3 | Documented in windows-scm-api.md |
|----------------------------------------|----------------------------------|
| `OpenSCManagerW` | Yes — full section (lines 8–54) |
| `OpenServiceW` | Yes — full section (lines 57–100) |
| `QueryServiceStatus` | Yes — full section (lines 164–204) |
| `ControlService` | Yes — full section (lines 207–272) |
| `CloseServiceHandle` | Yes — full section (lines 275–310) |

**[PASS]** All five Win32 functions called by `ServiceManager.au3` are covered.

`QueryServiceStatusEx` is documented as a research target (per spec requirement) even though the final implementation does not call it. The rationale is documented inline. This is correct per the enterprise prompt which named it as a required research topic.

### Is the struct documentation accurate against production code?

**[PASS] SERVICE_STATUS struct (7 DWORD fields) matches production usage.**
`windows-scm-api.md` documents SERVICE_STATUS as 7 DWORDs (lines 320–344). `ServiceManager.au3` creates `DllStructCreate("dword;dword;dword;dword;dword;dword;dword")` — 7 anonymous DWORD fields — for both `QueryServiceStatus` and `ControlService` calls. Field 2 = `dwCurrentState` is consistent between the document's field table and the production `DllStructGetData($t, 2)` calls.

**[PASS] ControlService struct type correctly stated.**
Lines 222–223 explicitly note: "The 3rd parameter is `LPSERVICE_STATUS` (pointer to `SERVICE_STATUS`, 7 fields), NOT `LPSERVICE_STATUS_PROCESS`." Production code passes a 7-field struct to `ControlService`. Consistent.

### Is the service inventory section accurate against Stop Services Processes.au3?

The service target list in `Stop Services Processes.au3` (lines 84–86) is:

```autoit
Global $aSvcTargetNames[9] = [ _
    "FDResPub", "fdPHost", "TrustedInstaller", "wuauserv", _
    "UsoSvc", "DoSvc", "WaaSMedicSvc", "SSDPSRV", "sppsvc"]
```

**[PASS] All 9 services match exactly.**
The reconciliation table in `windows-scm-api.md` lists the same 9 service names in the same set (order differs, which is immaterial — service names are identical). No service is missing, no extra service is documented.

**[PASS] Baseline delta is correctly documented.**
The document states the baseline contained 6 services and 3 were added (`FDResPub`, `fdPHost`, `SSDPSRV`). This matches the BASELINE-INVENTORY.md reference cited inline.

**[MINOR — INFORMATIONAL] Access rights value used by production code not cross-referenced in the spec document.**
`ServiceManager.au3` opens each service with `$SM_SERVICE_QUERY_AND_STOP = BitOR(0x0004, 0x0020) = 0x0024`. The "Minimum Rights Per Operation" table in `windows-scm-api.md` (line 439) lists `0x0024` for Query + Stop. The constant value is correct, but `windows-scm-api.md` does not explicitly cross-reference `$SM_SERVICE_QUERY_AND_STOP` by name. This is not a defect — the document correctly defines the right values; the constant name is a code-layer concern.

---

## Summary

| Axis | Findings | Worst issue |
|------|----------|-------------|
| Standards | 2 minor notes, 0 hard violations | Neither rises to actionable: `DllOpen` coverage is correct reference material; missing `DllStructCreate @error` guidance in production code is a code gap, not a doc inaccuracy |
| Spec | 1 informational note, 0 missing requirements, 0 scope creep | None; all required sections present, service inventory verified accurate against both production arrays |

Both documents pass their mandatory checklist items. No blocking findings.
