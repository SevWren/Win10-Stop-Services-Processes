# Code Review: CR2-12 — Architecture Document Second-Pass Review

**Reviewed file:** `docs/ARCHITECTURE.md`
**Fixed point:** `ab5b012..HEAD`
**Spec sources:** `Enterprise-Grad_Multi-Agent_Engineering_Implementation_Testing_Adversarial_Audit_AutoIt_prompt.md`, `docs/REQUIREMENTS.md`
**Reviewer:** CR2-12 (second-pass agent)
**Date:** 2026-11-12

---

## Standards

### S-01 — STALE: "No `docs/adr/` directory exists" statement is still present [MAJOR]

**Location:** `docs/ARCHITECTURE.md`, API Choice section, final paragraph (line 123 in the reviewed file):

> "No ADR directory exists in this repository. This note serves as the recorded primary-source decision in lieu of a formal ADR."

**Finding:** `docs/adr/` now exists and contains 10 ADR files (`0001` through `0010`, plus `README.md`). The claim that no ADR directory exists is factually false in the current repository state. T4-10 flagged this same statement. It has not been corrected.

This is not a cosmetic issue. The sentence asserts a structural fact ("no `docs/adr/` directory") to justify placing the API decision record in `ARCHITECTURE.md` rather than as a formal ADR. That justification is now invalid. `docs/adr/0009-queryservicestatus-api-selection.md` exists and presumably covers the same decision; the two records may duplicate or contradict each other.

**Required action:** Remove or update the "No ADR directory exists" sentence. Cross-reference `docs/adr/0009-queryservicestatus-api-selection.md` as the authoritative record if it covers the same decision. The in-line decision rationale in ARCHITECTURE.md may remain as a summary but must not misstate the repository structure.

---

### S-02 — Module Map documents only 3 of 7 internal helpers [MAJOR]

**Location:** `docs/ARCHITECTURE.md`, Module Map section.

**Finding:** The Module Map lists three internal-only helpers under `ServiceManager.au3`:

```
_SM_GetServiceState($hService)
_SM_ServiceStateToString($iState)
_SM_Win32ErrToOutcome($iWin32Err)
```

The code is known (per T4-10 and the task brief) to contain seven internal helpers. The four missing from the Module Map are:

| Helper | Role |
|---|---|
| `_SM_IsStopEligible` | Predicate: determines whether a state can accept a stop control |
| `_SM_StateNeedsPolling` | Predicate: determines whether a state should be added to pendingList |
| `_SM_StateToAlreadyStopped` | Predicate: determines whether a state maps to `ALREADY_STOPPED` |
| `_SM_BuildResultRow` | Builds a single result row for the return array |

Notably, the Pending-State Routing Reference table (further down in the same document) already names `_SM_IsStopEligible`, `_SM_StateNeedsPolling`, and `_SM_StateToAlreadyStopped` as "helper predicates" — they are described in the algorithm prose but absent from the Module Map. `_SM_BuildResultRow` is not mentioned anywhere in the document.

The enterprise prompt (Task 3) requires that every exported service-manager function be documented in `docs/ARCHITECTURE.md` with parameter types, return shape, `@error` and `@extended` meaning, ownership, and failure conditions. While the four missing helpers are internal (not exported), they are part of the module's documented interface contract since the routing table already refers to them. The Module Map is incomplete as a primary reference.

**Required action:** Add all seven internal helpers to the Module Map. Add at minimum a one-line description for `_SM_BuildResultRow` somewhere in the document, as it currently has no documentation at all.

---

### S-03 — QueryServiceStatus API selection section present [PASS]

The section "API Choice: QueryServiceStatus vs QueryServiceStatusEx" is present and well-formed. It documents both structs, states the rationale for the selection, and cross-references the research source. The enterprise prompt's alternative-API clause is satisfied by this section in conjunction with `REQ-017` and `docs/adr/0009-queryservicestatus-api-selection.md`.

---

### S-04 — Pending-state routing table present [PASS]

The "Pending-State Routing Reference" table is present and covers all seven `dwCurrentState` values (1–7). The table correctly maps each state to the predicate that fires, the Phase 1 action, and the expected outcome. The notes below the table address `SERVICE_START_PENDING` ineligibility and the error-1052 path for states 5–7.

---

### S-05 — Error 1052 in Outcome Classification Table [PASS]

Error 1052 (`ERROR_INVALID_SERVICE_CONTROL`) is present in the Outcome Classification Table:

> `ControlService` fails with 1052 (INVALID_SERVICE_CONTROL) | `FAILED` | 1052

The table also cross-references error 1052 in the notes beneath the routing table.

---

### S-06 — Smell baseline observations [INFORMATIONAL]

No Fowler smells are introduced by the diff to `ARCHITECTURE.md`. The document is new (all lines are additions from `ab5b012`). The two findings above (S-01, S-02) are documentation-accuracy issues, not design smells.

---

## Spec

### SP-01 — Enterprise prompt Task 2 deliverables: largely met, one gap [MINOR]

Task 2 requires ARCHITECTURE.md to freeze: "file map, public module contract, result categories, ownership rules, service timing constants, and non-destructive validation strategy."

| Deliverable | Present? | Notes |
|---|---|---|
| File map | Yes | Module Map section covers all files |
| Public module contract | Yes | `_SM_StopServicesBatch` contract fully specified |
| Result categories | Yes | Outcome Classification Table covers all five outcomes |
| Ownership rules | Yes | SCM/service handle ownership documented per-phase |
| Service timing constants | Yes | Timing Constants section with all six named constants |
| Non-destructive validation strategy | Partial | Integration Point section shows `_RunServiceBatchStop` wrapper; no explicit statement of non-destructive validation strategy (test harness approach) is recorded here |

The validation strategy is covered in `docs/REQUIREMENTS.md` (REQ-009) and in the enterprise prompt's Task 3 gate, but `ARCHITECTURE.md` itself does not contain a "Validation Strategy" or "Testing Approach" section. The enterprise prompt's Task 2 checklist item "freeze … non-destructive validation strategy in `docs/ARCHITECTURE.md`" is not explicitly satisfied by the document as written. This is a minor gap since the information exists in requirements, but the architecture document is not self-contained on this point.

---

### SP-02 — Task 3 documentation requirement: internal helper functions not fully covered [MAJOR — mirrors S-02]

Task 3 requires: "Document every exported service-manager function with parameter types, return shape, `@error` and `@extended` meaning, ownership, and failure conditions in `docs/ARCHITECTURE.md`."

The public function `_SM_StopServicesBatch` is fully documented. The four undocumented internal helpers (`_SM_IsStopEligible`, `_SM_StateNeedsPolling`, `_SM_StateToAlreadyStopped`, `_SM_BuildResultRow`) are not exported, so the strict reading of "exported" may exclude them. However:

- The routing table references three of them by name as the mechanism that determines Phase 1 routing, making them part of the documented contract.
- `_SM_BuildResultRow` has zero documentation anywhere in the architecture document, leaving a gap in understanding how result rows are constructed.

The spec line: "Document every exported service-manager function … in `docs/ARCHITECTURE.md`" — the internal helpers that are named in the routing table should, at minimum, have a one-line signature documented to match what the table implies.

---

### SP-03 — Task 6 final-state update requirement [INFORMATIONAL]

Task 6 requires updating `docs/ARCHITECTURE.md` as part of the final acceptance report. The document header dates to 2026-11-11 (T02 ticket). If any architectural decisions were revised during Tasks 3–6 (e.g., the QueryServiceStatus decision documented in ADR-0009 may postdate this document), the document should reflect the final state. This cannot be fully verified from the diff alone but is flagged for the Task 6 author to confirm.

---

### SP-04 — `SERVICE_STATUS_PROCESS` documentation present [PASS]

Task 2 requires: "Document `SERVICE_STATUS_PROCESS` as nine DWORD values and `SERVICE_STATUS` as seven DWORD values. Confirm that `ControlService` receives the latter structure, not the former."

Both structures are documented in the struct reference table. The document explicitly confirms `ControlService` uses `LPSERVICE_STATUS` (7 DWORDs) and not `SERVICE_STATUS_PROCESS`.

---

### SP-05 — DllCall contracts with primary sources [PASS]

Task 2 requires capturing verified DllCall contracts for each SCM API. The DllCall Patterns section documents `OpenSCManagerW`, `OpenServiceW`, `QueryServiceStatus`, `ControlService`, and `CloseServiceHandle` with DLL name, return type, parameter types, structure layout, immediate `@error` capture, and MSDN references. This satisfies the enterprise prompt requirement.

---

### SP-06 — Integration point coverage [PASS]

Task 4 integration requirements (logging per result category, non-blocking main loop) are reflected in the Integration Point section, which shows all five outcome cases handled with `_LogMessage` calls and no blocking wait in the outer loop.

---

## Summary

| Axis | Findings | Worst issue |
|---|---|---|
| Standards | 2 findings (1 MAJOR, 1 MAJOR), 1 INFORMATIONAL | S-01: stale "No `docs/adr/` directory exists" assertion contradicts current repo structure |
| Spec | 2 findings (1 MAJOR, 1 MINOR, 1 INFORMATIONAL) | SP-02: four internal helpers named in routing table have no Module Map entry or parameter documentation |

**Standards worst:** S-01 — a factually false structural claim that invalidates the stated rationale for the in-document decision record.
**Spec worst:** SP-02 — four functions referenced in the architecture's own routing table are absent from the Module Map, leaving the document internally inconsistent.

Both MAJOR findings require correction before this document can be considered a reliable primary reference.
