# CR-06 — Research Docs Review

**Reviewed files**: `docs/research/autoit-dllcall.md`, `docs/research/windows-scm-api.md`
**Fixed point**: `ab5b012`
**Commits in scope**:
```
1d8a5ea feat: replace broken service-stop path with native SCM batch-stop module
2a62801 chore(cleanup)
09b99ba Added claude skill sets
```
**Spec source**: `.scratch/service-manager-migration/issues/02-contracts-and-api-verification.md`
**Standards sources**: `CODING_STANDARDS.md`, `.agents/skills/research/SKILL.md`

---

## Standards

### S-1 — Primary source not actually fetched (Hard violation)

**File**: `docs/research/autoit-dllcall.md`, lines 3–5

```
Note: autoitscript.com was unreachable from this sandbox. Content below is drawn from the
official AutoIt 3.3.14+ language reference (stable, well-established specification).
```

**Standard**: research/SKILL.md — "Investigate the question against **primary sources** (official docs, source code, specs, first-party APIs), not a secondary write-up of them. Follow every claim back to the source that owns it."

The official primary source (`autoitscript.com`) was not reached. Content was derived from training data rather than a live primary-source fetch. The file's own header acknowledges this. The standard is unambiguous: claims must be followed back to the source that owns them. All technical claims in this file — `@error` codes, `"handle"` type string behaviour, `"struct*"` availability from 3.3.6+, return array indexing — carry no verifiable citation to an actually-fetched page.

**Mitigation already present**: The claims were cross-verified against `Includes/ServiceManager.au3` patterns (see S-3 below) and are technically accurate. But accuracy does not substitute for sourcing compliance under the research skill standard.

---

### S-2 — windows-scm-api.md sourcing is compliant (No finding)

The header states "Primary sources: MSDN pages fetched directly" and every API section carries an individual `learn.microsoft.com` URL. `learn.microsoft.com` is the canonical Microsoft primary source for Win32 API documentation. No sourcing violation here.

---

### S-3 — DllCall pattern cross-check: autoit-dllcall.md vs ServiceManager.au3 (No finding)

All patterns documented in `autoit-dllcall.md` are consistent with actual usage in `Includes/ServiceManager.au3`:

| Claim in autoit-dllcall.md | Usage in ServiceManager.au3 | Match? |
|---|---|---|
| `"handle"` for `SC_HANDLE` / Windows HANDLE | `DllCall("advapi32.dll", "handle", "OpenSCManagerW", ...)` | Yes |
| `"ptr"` + `DllStructGetPtr` for `LPSERVICE_STATUS` | `"ptr", DllStructGetPtr($tQueryStatus)` | Yes |
| `"wstr"` for `LPCWSTR` service name | `"wstr", $sName` in `OpenServiceW` call | Yes |
| `DllStructCreate("dword;dword;dword;dword;dword;dword;dword")` for 7-field SERVICE_STATUS | Identical string used in all three struct allocations | Yes |
| Field 2 (1-based) = `dwCurrentState` | `DllStructGetData($tQueryStatus, 2)` | Yes |
| `@error` captured on the immediately following line | `Local $iScmDllErr = @error` on line after every DllCall | Yes |

One edge case worth noting: `OpenSCManagerW`'s `lpMachineName` (NULL) is passed as `"ptr", 0` in ServiceManager.au3, while `lpDatabaseName` is `"wstr", "ServicesActive"`. The `autoit-dllcall.md` type table documents `"ptr"` as "Raw pointer — pointer-sized" which is correct for passing NULL. No inconsistency.

---

### S-4 — Smell baseline scan (Judgement calls)

Both files are reference documentation (Markdown), not executable code. Classic Fowler code smells (Feature Envy, Message Chains, etc.) do not apply to Markdown prose. No smells flagged.

**Speculative Generality (judgement call, low severity)**: `autoit-dllcall.md` includes a full type string reference table covering `"float"`, `"double"`, `"byte"`, `"word"`, `"int_ptr"`, `"uint_ptr"` — none of which appear in the codebase or are needed by the spec. This is minor: a reference table being comprehensive is normal and arguably useful, but the spec asked for DllCall documentation sufficient for SCM operations, not a complete type catalogue.

---

## Spec

### SP-1 — QueryServiceStatusEx not documented (Partial miss)

**Spec line**: `- [ ] Research subagent B: Windows SCM APIs (OpenSCManagerW, OpenServiceW, **QueryServiceStatusEx**, ControlService, CloseServiceHandle)`

`windows-scm-api.md` documents `QueryServiceStatus` (the 7-field variant) rather than `QueryServiceStatusEx` (the 9-field variant). The document does include a `SERVICE_STATUS_PROCESS` struct section and a comparison table that mentions `QueryServiceStatusEx`, but there is no dedicated API section for `QueryServiceStatusEx` covering its full signature, parameters (`SC_STATUS_PROCESS_INFO` info level, buffer/byte-count parameters), and error codes.

This matters because `QueryServiceStatusEx` is the modern function (it returns the PID via `dwProcessId`), and the spec explicitly named it. The implementation in `ServiceManager.au3` uses `QueryServiceStatus`, which is correct for its purpose, but the spec called for the research to cover `QueryServiceStatusEx`.

**Severity**: Medium. The documented alternative (`QueryServiceStatus`) is what the implementation actually uses, so the gap is in research completeness rather than in implementation guidance.

---

### SP-2 — Service inventory reconciliation absent (Missing deliverable)

**Spec line**: `- [ ] Reconcile service inventory against baseline (FDResPub, fdPHost, TrustedInstaller, wuauserv, UsoSvc, DoSvc, WaaSMedicSvc, SSDPSRV, sppsvc)`

Neither `autoit-dllcall.md` nor `windows-scm-api.md` contains any service inventory reconciliation. The named services (FDResPub, fdPHost, TrustedInstaller, wuauserv, UsoSvc, DoSvc, WaaSMedicSvc, SSDPSRV, sppsvc) do not appear in either file.

This item may have been intended for `docs/REQUIREMENTS.md` rather than the research files, but the spec assigns it to issue 02's work product without specifying a separate output artifact. It remains unaddressed in the session's research output.

**Severity**: Medium. The service list is a named input from the spec; its absence means the research docs do not confirm or deny which services in the baseline are stoppable via the new SCM path.

---

### SP-3 — All confirmed spec items satisfied (No finding)

The following spec checklist items are fully addressed in the research docs:

| Spec item | Addressed in |
|---|---|
| Research subagent A: DllCall, DllStructCreate, DllOpen, DllClose | `autoit-dllcall.md` — all four covered |
| Verify SERVICE_STATUS is 7 DWORDs | `windows-scm-api.md` — "Total fields: 7. ALL fields are DWORD. Confirmed from MSDN." |
| Verify SERVICE_STATUS_PROCESS is 9 DWORDs | `windows-scm-api.md` — "Total fields: 9. ALL fields are DWORD. Confirmed from MSDN." |
| Verify ControlService takes SERVICE_STATUS (7-DWORD), not SERVICE_STATUS_PROCESS | `windows-scm-api.md` — "Critical note" explicitly states this; summary table confirms |
| Confirm minimum access rights: SC_MANAGER_CONNECT \| SERVICE_QUERY_STATUS \| SERVICE_STOP | `windows-scm-api.md` — values 0x0001, 0x0004, 0x0020 documented and confirmed |

---

### SP-4 — Out-of-scope spec items (Not findings against research docs)

The following spec items from issue 02 are not addressed in the research docs but are not expected to be — they are separate output artifacts:

- REQ-* rows in `docs/REQUIREMENTS.md`
- Public contract for `_SM_StopServicesBatch` in `docs/ARCHITECTURE.md`
- GLOSSARY.md update with SCM terms

These remain open in issue 02 but are out of scope for this review of the research files.

---

## Summary

**Standards axis**: 1 hard violation (S-1: autoit-dllcall.md primary source not fetched), 1 low-severity judgement call (S-4: speculative completeness in type table). Worst issue: S-1 — claims in autoit-dllcall.md are uncited against a live primary source, violating the research skill standard.

**Spec axis**: 2 findings — SP-1 (QueryServiceStatusEx not documented, medium), SP-2 (service inventory reconciliation absent, medium). Worst issue: SP-2 — named service list reconciliation (FDResPub, fdPHost, TrustedInstaller, wuauserv, UsoSvc, DoSvc, WaaSMedicSvc, SSDPSRV, sppsvc) is wholly absent from the research output.
