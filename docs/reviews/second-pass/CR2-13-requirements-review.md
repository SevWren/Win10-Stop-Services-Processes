# CR2-13 — Requirements Register Second-Pass Review

**File reviewed**: `docs/REQUIREMENTS.md`
**Fixed point**: `ab5b012` (merge commit, pre-implementation)
**HEAD commit**: `1d8a5ea` (feat: replace broken service-stop path with native SCM batch-stop module)
**Spec source**: `Enterprise-Grad_Multi-Agent_Engineering_Implementation_Testing_Adversarial_Audit_AutoIt_prompt.md`
**Reviewer**: Claude Sonnet 4.6 (1M context) — Maton Agent
**Date**: 2026-11-12

---

## Standards Axis

Standards checks per the task brief, applied against the diff `ab5b012...HEAD` for `docs/REQUIREMENTS.md`.

### S-01 — STALE STATEMENT IN REQ-017 (FAIL)

**Severity**: MAJOR

REQ-017 (line 268) contains the statement:

> "No `docs/adr/` directory exists in this repository. This requirement row constitutes the required primary-source decision record per the enterprise prompt's alternative-API clause."

This statement is factually incorrect at HEAD. The directory `docs/adr/` exists and contains ten ADR files, including `docs/adr/0009-queryservicestatus-api-selection.md`, which is a fully authored ADR covering precisely the same API-selection decision that REQ-017 claims to record inline. The stale assertion was apparently accurate at the time the requirements register was first drafted (before `1d8a5ea` landed) but was not updated when the ADR directory was created.

**Impact**: The traceability claim in REQ-017's Evidence field references itself as the primary decision record, but the actual decision record now lives in `docs/adr/0009-queryservicestatus-api-selection.md`. Any reader using REQ-017 as the authoritative decision trace will not discover the richer ADR rationale. The Evidence field should cite `docs/adr/0009-queryservicestatus-api-selection.md` and the stale "No `docs/adr/`" sentence must be removed or corrected.

---

### S-02 — ALL 17 REQs PRESENT (PASS)

REQ-001 through REQ-017 are all present in sequence. No gap, no duplicate numbering detected.

---

### S-03 — ORIGINAL 14 REQ STATUSES ARE IMPLEMENTED (PASS)

The diff confirms that at `ab5b012` the file did not exist — `docs/REQUIREMENTS.md` was introduced entirely in `1d8a5ea`. The original content in the diff shows all statuses as "Implementation pending (T03)". At HEAD:

| REQ | Status at HEAD |
|-----|----------------|
| REQ-001 | IMPLEMENTED |
| REQ-002 | IMPLEMENTED |
| REQ-003 | IMPLEMENTED |
| REQ-004 | IMPLEMENTED |
| REQ-005 | IMPLEMENTED |
| REQ-006 | IMPLEMENTED |
| REQ-007 | IMPLEMENTED |
| REQ-008 | IMPLEMENTED |
| REQ-009 | IMPLEMENTED |
| REQ-010 | IMPLEMENTED |
| REQ-011 | IMPLEMENTED |
| REQ-012 | IMPLEMENTED |
| REQ-013 | IMPLEMENTED |
| REQ-014 | IMPLEMENTED |

No "pending" status remains for the original 14. REQ-015, REQ-016, and REQ-017 are also marked IMPLEMENTED (REQ-017 as "IMPLEMENTED (with recorded decision)").

---

### S-04 — REQ-015, REQ-016, REQ-017 CONTENT (PASS)

**REQ-015** (Intra-Batch Poll Interval is 500 ms): Content matches enterprise prompt ("The default poll interval is 500 ms"). Implementation reference correctly names `$SVC_BATCH_POLL_MS = 500` in `Stop Services Processes.au3` and the `Sleep($iPollIntervalMs)` call in Phase 2 of `_SM_StopServicesBatch`. Evidence cites concrete file/line references.

**REQ-016** (Batch Stop Deadline is 20 Seconds): Content matches enterprise prompt ("The default batch deadline is 20 seconds"). Implementation reference correctly names `$SVC_BATCH_TIMEOUT_MS = 20000` and the `While … TimerDiff($iTimer) < $iBatchTimeoutMs` guard. Evidence cites concrete file/line references.

**REQ-017** (QueryServiceStatus API Selection): Content correctly captures the rationale for choosing `QueryServiceStatus` over `QueryServiceStatusEx`, documenting all four justification points and the `ControlService` struct compatibility argument. The decision record content is substantively sound. The stale directory claim is a separate defect covered in S-01.

---

### S-05 — REQ-002 IMPLEMENTATION REFERENCE (PASS)

REQ-002 at HEAD correctly identifies `_SM_ServiceStateToString()` as the interpretation function. The Status field explicitly disambiguates: "`_SM_GetServiceState` is a separate DllCall helper and is not the interpretation function." The original diff shows the pre-implementation version named `_SM_GetServiceState()` — this was corrected. No residual incorrect reference remains.

---

### S-06 — GATE 5 EVIDENCE REFERENCES (PARTIAL PASS — NOTE)

All 17 REQs carry a Gate 5 evidence reference of the form "T05 review SPEC-NNN" or "T05 review STD-NN". REQ-005, REQ-006, REQ-007, REQ-008, and REQ-009 carry evidence citations without an inline "Gate 5 evidence:" label in the Evidence field (some rely solely on the Status field). This is a minor consistency issue — the references are present but their placement is not uniform across all rows. This does not break traceability but reduces scan-ability.

---

## Spec Axis

Checks against the enterprise prompt spec source.

### SP-01 — COVERAGE OF ENTERPRISE PROMPT REQUIREMENTS (PASS WITH NOTE)

The enterprise prompt's Target Behavior section defines the following mandatory items. Each is accounted for:

| Prompt requirement | REQ | Status |
|---|---|---|
| Per-service outcome classification (STOPPED/ALREADY_STOPPED/UNAVAILABLE/FAILED/TIMED_OUT) | REQ-001 | IMPLEMENTED |
| All 7 service states interpreted | REQ-002 | IMPLEMENTED |
| Issue stop controls without serial waiting; shared deadline | REQ-003 | IMPLEMENTED |
| Minimum access rights only (SC_MANAGER_CONNECT, SERVICE_QUERY_STATUS, SERVICE_STOP) | REQ-004 | IMPLEMENTED |
| One cleanup path per handle | REQ-005 | IMPLEMENTED |
| @error captured immediately after each DllCall | REQ-006 | IMPLEMENTED |
| "handle" type string for SC_HANDLE params | REQ-007 | IMPLEMENTED |
| ControlService receives valid SERVICE_STATUS struct (7 DWORDs) | REQ-008 | IMPLEMENTED |
| No live stop controls in test harness | REQ-009 | IMPLEMENTED |
| 9-service inventory matching enterprise prompt | REQ-010 | IMPLEMENTED |
| Undeclared $iLastStopProcesses fixed | REQ-011 | IMPLEMENTED |
| Duplicate #include and HotKeySet lines removed | REQ-012 | IMPLEMENTED |
| Service poll interval 10 seconds | REQ-013 | IMPLEMENTED |
| Include paths portable (working-directory relative) | REQ-014 | IMPLEMENTED |
| Default poll interval 500 ms | REQ-015 | IMPLEMENTED |
| Default batch deadline 20 seconds | REQ-016 | IMPLEMENTED |
| Primary-source decision for QueryServiceStatus vs QueryServiceStatusEx | REQ-017 | IMPLEMENTED |

No enterprise prompt requirement from the Target Behavior or Global Constraints sections appears to lack a corresponding REQ row.

---

### SP-02 — ITEMS IN ENTERPRISE PROMPT WITH NO CORRESPONDING REQ (NOTE — INFORMATIONAL)

The following enterprise prompt requirements are addressed in other documentation rather than as dedicated REQ rows. They are not missing from the implementation record, but their traceability passes through non-REQ documents:

- **Seven-day log rotation and portable log path** (Preserved Behavior section): Mentioned in REQ-014 only as a path portability item; the log-rotation behavior itself has no dedicated REQ. Traced instead through `docs/IMPLEMENTATION-AND-VERIFICATION.md`.
- **Duplicate process entry investigation** (Preserved Behavior: "Investigate duplicate process entries … retain intentional duplicate"): Recorded in the Conflicts Resolved table as T04, not as a REQ row. Acceptable given the conflict-resolution table is present, but a REQ or ADR would improve formal traceability.
- **Second-loop result-reporting defect investigation** (Preserved Behavior): Also recorded as T04, not a REQ. Same note applies.
- **`GetLastError()` capture before subsequent API call** (Global Constraints): Subsumed within REQ-006 (@error capture) and partially in REQ-005 (cleanup paths). No dedicated REQ for `GetLastError` sequencing. The implementation detail is covered in code review REVIEW-ServiceManager.au3.md rather than a REQ row.

None of these rise to BLOCKER or CRITICAL under the enterprise prompt's gate definition, but SP-02 flags them for the reviewer's awareness.

---

### SP-03 — TRACEABILITY: GATE 5 EVIDENCE REFERENCES PRESENT (PASS)

Every REQ row carries either an Evidence field with a Gate 5 reference or a Status field with a Gate 5 citation. The reference scheme (T05 review SPEC-NNN / STD-NN) is consistent with the evidence tracking format used in `docs/IMPLEMENTATION-AND-VERIFICATION.md`.

---

### SP-04 — SCOPE CREEP CHECK (PASS)

No REQ row documents behavior or structure that falls outside the enterprise prompt's scope. The Conflicts Resolved table at the end of the register handles decisions that extend beyond raw requirements (service inventory delta, duplicate entries, module authority boundary) — these are appropriate for a requirements register conflict log and do not represent unasked-for scope additions.

---

## Summary

| Axis | Findings | Worst issue |
|---|---|---|
| Standards | 1 fail, 1 partial pass note, 3 pass | S-01 (MAJOR): stale "No `docs/adr/` directory exists" in REQ-017 — factually wrong at HEAD; ADR exists at `docs/adr/0009-queryservicestatus-api-selection.md` |
| Spec | 1 informational note, 3 pass | SP-02 (INFORMATIONAL): log rotation, duplicate-process investigation, and GetLastError sequencing have no dedicated REQ rows; traced through other documents |

**Required fix**: Remove or correct the sentence "No `docs/adr/` directory exists in this repository" in REQ-017, and update the Evidence field to cite `docs/adr/0009-queryservicestatus-api-selection.md` as the primary decision record. All other findings are informational or pass.
