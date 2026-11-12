# CR2-36 — Baseline & Research Cross-Check
Review date: 2026-11-12
Reviewer: second-pass agent
Sources verified against:
- `docs/BASELINE-INVENTORY.md`
- `docs/research/windows-scm-api.md`
- `docs/research/autoit-dllcall.md`
- `Stop Services Processes.au3` (HEAD, lines 79–87)
- `Includes/ServiceControl.au3` (HEAD)

---

## Part 1 — BASELINE-INVENTORY.md AU3Check Summary Table

### 1.1 Does the table include the `"long"` handle-type row for `ServiceControl.au3`?

YES. The AU3Check Concerns table (lines 203–213 of `BASELINE-INVENTORY.md`) contains the
following row as its last entry:

```
| Handle type `"long"` used for SCM/service handles | ServiceControl.au3 | CORRECTNESS (64-bit) |
```

The row is present and correctly characterises the issue. It maps to the detailed write-up in
the "ServiceControl.au3 Technical Findings / Handle Type Issue" section immediately below the
table. No gap found.

### 1.2 Column count consistency across all tables

All tables in `BASELINE-INVENTORY.md` were checked:

| Table | Expected columns | Actual columns | Consistent? |
|-------|-----------------|----------------|-------------|
| Source Files | 2 | 2 | Yes |
| Timing Values | 3 | 3 | Yes |
| Path Configuration | 2 | 2 | Yes |
| AU3Check Concerns | 3 | 3 | Yes |
| Toolchain Availability | 2 | 2 | Yes |
| Decisions Triggered | 3 | 3 | Yes |

No broken or ragged rows detected. Column counts are consistent throughout. The separator
rows use `|---|---|---|` patterns that correctly match their header counts.

### 1.3 Does the inventory accurately reflect the pre-migration state?

MOSTLY YES, with one clarification item noted below.

The inventory correctly records:
- 6 services in `_stopservicescustom()` / `Local $aServiceNames` (the pre-migration baseline).
  The 3 absent services (`FDResPub`, `fdPHost`, `SSDPSRV`) are noted as a version delta.
- The `ControlService "str", ""` bug at `ServiceControl.au3` line 190.
- The `"long"` handle-type correctness issue.
- All duplicate `#include`, `HotKeySet`, and process-array entries.
- The undeclared `$iLastStopProcesses` variable.

**Clarification item — variable naming delta**: `BASELINE-INVENTORY.md` refers to the service
array in the pre-migration source as `Local $aServiceNames` (line 55). In the migrated HEAD
the array has been renamed to `Global $aSvcTargetNames` and moved to the Configuration region
(line 84 of `Stop Services Processes.au3`). The inventory was written against the pre-migration
state, so this is not an error in the inventory — it is an expected post-migration delta. The
inventory is accurate for the state it documents.

---

## Part 2 — windows-scm-api.md Service Inventory Cross-Check

### 2.1 Claim in `windows-scm-api.md`

The Service Inventory Reconciliation section (lines 486–510) claims the following 9-service
target list is in effect:

```
FDResPub, fdPHost, TrustedInstaller, wuauserv, UsoSvc, DoSvc, WaaSMedicSvc, SSDPSRV, sppsvc
```

### 2.2 Actual config region in `Stop Services Processes.au3`

Lines 84–86:
```autoit
Global $aSvcTargetNames[9] = [ _
    "FDResPub", "fdPHost", "TrustedInstaller", "wuauserv", _
    "UsoSvc", "DoSvc", "WaaSMedicSvc", "SSDPSRV", "sppsvc"]
```

### 2.3 Verdict

EXACT MATCH. All 9 names, spellings, and case are identical between `windows-scm-api.md` and
the actual config region. Array size `[9]` confirms the count. No discrepancies found.

---

## Part 3 — autoit-dllcall.md DllCall Pattern Verification

### 3.1 `OpenSCManagerW` — signature and return type

**What `autoit-dllcall.md` states**:
The Type String Reference table (line 171) documents `"handle"` as the correct type for
`SC_HANDLE` / Windows HANDLE types, and specifies that `"long"` truncates handles to 32 bits
on 64-bit Windows. The research document does not provide a named `OpenSCManagerW` DllCall
pattern, but the Type String Reference and "handle vs long" note fully define the expected
pattern: return type `"handle"`, parameter types `"wstr"` (or `"str"`) and `"dword"`.

**What `ServiceControl.au3` actually does** (lines 109–112, repeated at 169–172, 224–227,
264–267, 335–338, 403–406):
```autoit
$arRet = DllCall($hAdvapi32, "long", "OpenSCManager", _
        "str", $sComputerName, _
        "str", "ServicesActive", _
        "long", $SC_MANAGER_CONNECT)
```

**Findings**:
- Return type is `"long"` — should be `"handle"` per `autoit-dllcall.md`.
- The function called is `"OpenSCManager"` (ANSI alias), not `"OpenSCManagerW"` (Unicode). The
  `windows-scm-api.md` documents `OpenSCManagerW`. On Windows the ANSI wrapper calls the W
  variant internally, so this is a style inconsistency rather than a functional failure, but it
  diverges from the documented API surface.
- Access flag parameter uses `"long"` — should be `"dword"` per the type table.

The research document is internally accurate. It correctly identifies the `"long"` vs `"handle"`
problem. The discrepancy is between `ServiceControl.au3` and what the research document
specifies as correct — this is the pre-migration defect the research is documenting, not an
error in the research document itself.

### 3.2 `QueryServiceStatus` — 7-DWORD struct access pattern

**What `autoit-dllcall.md` states**:
- `SERVICE_STATUS` has exactly 7 DWORD fields (confirmed at line 332 of `windows-scm-api.md`).
- `dwCurrentState` is field 2 (1-based).
- Correct DllStructCreate definition uses `"dword field1; dword field2 ..."` with semicolons.
- Access by field number uses `DllStructGetData($tStatus, 2)` for `dwCurrentState`.
- The correct parameter type for passing the struct pointer is `"ptr"` with `DllStructGetPtr()`.

**What `ServiceControl.au3` actually does**:
`QueryServiceStatus` does not appear in `ServiceControl.au3` at all — the file has no call to
`QueryServiceStatus`. The `_ServiceRunning` function instead calls `ControlService` with
`SERVICE_CONTROL_INTERROGATE` to infer running state (confirmed at lines 276–279). There is no
`DllStructCreate` for a SERVICE_STATUS struct anywhere in `ServiceControl.au3`.

**Verdict on the research document**:
The 7-DWORD struct access pattern described in `autoit-dllcall.md` is internally accurate and
consistent with the MSDN struct definition in `windows-scm-api.md`. The field count (7),
field order, 1-based indexing convention, and `"ptr"` type usage are all correctly documented.
The absence of `QueryServiceStatus` from `ServiceControl.au3` is a deficiency in the legacy
code, not an error in the research document.

### 3.3 `ControlService` — third parameter handling

**What `autoit-dllcall.md` states**:
- `"str"` type is for ANSI string pointers (line 178).
- `"ptr"` should be used for output struct pointers; passing `DllStructGetPtr($tStruct)` is
  the standard approach for SERVICE_STATUS output parameters (lines 42–46).
- `"long"` is 32-bit signed and must not be used for handles.

**What `windows-scm-api.md` states**:
- `ControlService` third parameter is `LPSERVICE_STATUS` — pointer to a 7-DWORD SERVICE_STATUS
  struct (lines 215–223). It is an output parameter that receives the latest service status.
  Passing an empty string is incorrect.

**What `ServiceControl.au3` actually does** (lines 187–190, also 276–279):
```autoit
$arRet = DllCall($hAdvapi32, "int", "ControlService", _
        "long", $hService, _
        "long", $SERVICE_CONTROL_STOP, _
        "str", "")
```

**Findings**:
- Third parameter is `"str", ""` — an empty ANSI string pointer. This is incorrect.
  The API requires a valid `LPSERVICE_STATUS` pointer to a 28-byte (7 × 4) struct.
- `autoit-dllcall.md` correctly documents that `"str"` is for string data, not output struct
  pointers, and that `"ptr"` with `DllStructGetPtr()` is the correct approach.
- `windows-scm-api.md` correctly documents that the third parameter is `LPSERVICE_STATUS` (not
  a string), and states that passing an empty string "results in undefined behavior" and is
  "likely the root cause of unreliable service stopping" (consistent with BASELINE-INVENTORY.md
  line 197).
- Both research documents are internally consistent and mutually consistent on this point.
- The defect is in `ServiceControl.au3`, not in the research documents.
- Additionally, `$hService` is passed as `"long"` — per `autoit-dllcall.md` this should be
  `"handle"` for correct 64-bit operation.

---

## Summary of Findings

### BASELINE-INVENTORY.md

| Check | Result |
|-------|--------|
| `"long"` handle-type row present in AU3Check table | PASS — row present, correctly described |
| All table column counts consistent (3 columns throughout) | PASS — all tables have correct consistent column counts |
| Inventory accurately reflects pre-migration state | PASS — accurate for the state documented; post-migration variable rename is expected delta, not an error |

### Research Document Cross-Checks

| Check | Result | Notes |
|-------|--------|-------|
| `windows-scm-api.md` 9 service names match config region | PASS — exact match on all 9 names, spellings, and case |
| `OpenSCManagerW` signature and return type in `autoit-dllcall.md` | PASS (research accurate) — `ServiceControl.au3` uses `"long"` return type and ANSI function name, both deviating from what the research correctly documents as correct |
| `QueryServiceStatus` 7-DWORD struct access pattern | PASS (research accurate) — field count, 1-based indexing, and `"ptr"` type documented correctly; `ServiceControl.au3` does not call `QueryServiceStatus` at all |
| `ControlService` third parameter handling | PASS (research accurate) — both research documents correctly identify `"str", ""` as the defect; correct approach (`"ptr"` + `DllStructGetPtr`) is accurately described |

### No Errors Found in Research Documents

All three DllCall patterns described in `autoit-dllcall.md` and cross-referenced against
`windows-scm-api.md` are internally and mutually consistent, and accurately describe both
the correct patterns and the defects present in `ServiceControl.au3`. The defects are
confined to `ServiceControl.au3`; the research documents are reliable references for the
migration.
