# Code Review CR-05 — Requirements and Implementation/Verification Docs

**Reviewer**: Standards sub-agent + Spec sub-agent (parallel)
**Fixed point**: `ab5b012`
**HEAD commits since fixed point**:
- `1d8a5ea` feat: replace broken service-stop path with native SCM batch-stop module
- `2a62801` chore(cleanup)
- `09b99ba` Added claude skill sets

**Files reviewed**:
- `docs/REQUIREMENTS.md` (new file, 234 lines)
- `docs/IMPLEMENTATION-AND-VERIFICATION.md` (new file, 241 lines)

**Spec source**: `Enterprise-Grad_Multi-Agent_Engineering_Implementation_Testing_Adversarial_Audit_AutoIt_prompt.md`
**Standards source**: `CODING_STANDARDS.md` + Fowler smell baseline

---

## Standards

### STD-S01 — Stale Status Fields Contradict Verification Document (MAJOR)

**Location**: `docs/REQUIREMENTS.md`, all 14 REQ entries (`REQ-001` through `REQ-014`)

Every requirement row carries a `**Status**` field reading either "Implementation pending (T03)" or "Implementation pending (T04)". `IMPLEMENTATION-AND-VERIFICATION.md` Gate 5 marks all 14 requirements as `IMPLEMENTED`. The two documents are factually contradictory on the implementation status of every requirement.

`CODING_STANDARDS.md` does not mandate a status field format, but the Speculative Generality heuristic is not applicable here; this is a correctness issue. Cross-document inconsistency undermines the traceability function these documents serve. All 14 `**Status**` fields must be updated to reflect final implementation evidence.

---

### STD-S02 — Function Name Mismatch Between REQ-002 and Gate 5 (MINOR)

**Location**: `docs/REQUIREMENTS.md` REQ-002 `**Implementation**` field vs. `docs/IMPLEMENTATION-AND-VERIFICATION.md` Gate 5 row for REQ-002

`REQUIREMENTS.md` REQ-002 cites `_SM_GetServiceState()` as the implementing function. Gate 5 of `IMPLEMENTATION-AND-VERIFICATION.md` cites `_SM_ServiceStateToString` as the evidence for REQ-002. These are different function names. Per `CODING_STANDARDS.md` §Function Naming, the `_SM_PascalCase` convention applies to service-manager module functions; both names are syntactically valid, but only one can be the actual implementation. If `_SM_ServiceStateToString` is the real function, REQ-002's `**Implementation**` field is wrong. If `_SM_GetServiceState` is real, the Gate 5 evidence row is wrong.

**Fix**: Align the function name in REQ-002 to match the actual function declared in `Includes/ServiceManager.au3`.

---

### STD-S03 — Predicted Outcomes Written to NOT RUN Gate (MAJOR)

**Location**: `docs/IMPLEMENTATION-AND-VERIFICATION.md` Gate 1 (AU3Check Static Analysis)

The spec states explicitly: "Keep commands, tool versions, exit codes, warnings, results, and limitations in `docs/IMPLEMENTATION-AND-VERIFICATION.md`. Do not write predicted outcomes there."

Gate 1 carries `**Status**: NOT RUN — Windows environment required` but then provides a table of resolved baseline issues and a bullet list asserting compliance ("All three files were written following CLAUDE.md and CODING_STANDARDS.md", "All variables declared with `Local`", etc.). These are author assertions, not tool output. The standard (§AU3Check Compliance) requires satisfaction of `AU3Check -q -d -w 1 -w 2 -w 3 -w 4`; that cannot be claimed as met when the tool was not run.

**Fix**: Gate 1 should contain only: the commands to run, the reason they were not run, and a pointer to the environmental blockers doc. Remove all compliance assertions from the NOT RUN section.

---

### STD-S04 — Acceptance Rationale Bypasses the Standard (MINOR)

**Location**: `docs/IMPLEMENTATION-AND-VERIFICATION.md` Accepted Minor/Informational Findings, row STD-001 (ServiceManager)

The rationale for accepting `$iPendLen`/`$iPendLen2` variable scoping reads: "Functional correctness unaffected; AU3Check will not flag this as an error." `CODING_STANDARDS.md` §AU3Check Compliance states variables must be declared with `Local` before use. The rationale that the tool will not flag it does not establish that the standard is met; it argues the enforcement mechanism will miss it. If the standard applies, the rationale needs to cite why the standard permits this pattern (e.g., the variable is declared, just inside a loop), not assert that the tool is blind to it.

**Fix**: Replace the rationale with a citation of the specific declaration location, confirming `Local` is used, so the standard is demonstrably satisfied.

---

### STD-S05 — REQ-010 Gate 5 Cross-Reference Typo (INFORMATIONAL)

**Location**: `docs/IMPLEMENTATION-AND-VERIFICATION.md` Gate 5, REQ-010 row, `Evidence` column

The evidence reads "T05 review SPEC-01" — the reference ID is truncated (should be "SPEC-011" or "SPEC-010"). All other rows use two-digit suffixes (SPEC-003, SPEC-004, etc.).

**Fix**: Correct the reference to the full two-digit form matching the review document.

---

## Spec

### SPEC-S01 — 500 ms Poll Interval and 20-Second Batch Deadline Not Captured as Requirements (MAJOR)

**Spec location**: §Service manager — "In one cycle… poll all pending services against one shared deadline. The default poll interval is 500 ms and the default batch deadline is 20 seconds."

Neither `REQUIREMENTS.md` nor its conflicts-resolved section contains a requirement for the 500 ms intra-batch verification poll interval or the 20-second batch deadline. REQ-013 covers only the 10-second outer service-monitoring interval (the scheduling period between full batch invocations in `ToggleScript`). The two timing values that govern the behaviour *inside* `_SM_StopServicesBatch` itself — the 500 ms poll and 20-second deadline — are absent from the requirements register entirely.

The spec also requires (Task 2): "Convert each target behavior and preservation rule into a `REQ-*` row with one implementation location and one verification method." These two values satisfy that criterion and are missing.

**Fix**: Add `REQ-015` (500 ms intra-batch poll interval) and `REQ-016` (20-second batch deadline) with implementation locations in `ServiceManager.au3` and verification by code inspection of the named constants.

---

### SPEC-S02 — `QueryServiceStatusEx` Not Traced to Any Requirement (MAJOR)

**Spec location**: §Service manager — "Use `OpenSCManagerW`, `OpenServiceW`, `QueryServiceStatusEx`, `ControlService`, and `CloseServiceHandle`…"

No REQ row in `REQUIREMENTS.md` requires or verifies use of `QueryServiceStatusEx` specifically. REQ-008 documents the `SERVICE_STATUS` (7-DWORD) struct for `ControlService`, which is correct, but `QueryServiceStatusEx` returns `SERVICE_STATUS_PROCESS` (9 DWORDs), a distinct structure. The spec cites both API calls and both structures, with a specific instruction in Task 2 to "Document `SERVICE_STATUS_PROCESS` as nine DWORD values and `SERVICE_STATUS` as seven DWORD values." There is no REQ row for `SERVICE_STATUS_PROCESS` and no verification that `QueryServiceStatusEx` (rather than the simpler `QueryServiceStatus`) is the API in use.

**Fix**: Add a requirement row for `QueryServiceStatusEx` and `SERVICE_STATUS_PROCESS` (9 DWORDs), with a verification method (code inspection of the DllCall declaration).

---

### SPEC-S03 — Requirement Status Fields Not Updated From Execution Evidence (MAJOR)

**Spec location**: Task 6 — "Update every requirement row from execution evidence. Mark unavailable checks `NOT RUN` with the environmental reason; do not convert them to pass-by-inspection."

All 14 REQ rows still show "Implementation pending (T03/T04)". The spec's Task 6 deliverable explicitly requires updating these rows from execution evidence. Gate 5 of `IMPLEMENTATION-AND-VERIFICATION.md` provides the evidence (all 14 marked IMPLEMENTED), but it was not propagated back to `REQUIREMENTS.md`. This also overlaps with STD-S01 but is a spec compliance failure independent of the standards issue: Task 6 required a specific action that was not performed.

**Fix**: Update all 14 `**Status**` fields in `REQUIREMENTS.md` to `IMPLEMENTED` (or `NOT RUN` with reason for any that apply), citing the Gate 5 evidence row in each.

---

### SPEC-S04 — Undocumented Scope in Deliverable Record (MINOR)

**Spec location**: §File Map — exhaustive list of authorized files. §Global Constraints — "Do not create an additional `.au3` file until the requirements register identifies its responsibility…"

`IMPLEMENTATION-AND-VERIFICATION.md` "Changed / Created Files" table lists `.agents/skills/` (Matt Pocock skill set) as `Added`. This directory is entirely outside the spec's File Map. The spec does not authorize agent skill files and contains no requirement or architecture decision referencing them. Including them in the deliverable record without a decision entry in `docs/wiki/decisions.md` or a note in the conflicts section of `REQUIREMENTS.md` is undocumented scope expansion.

**Fix**: Either add a decision entry in `docs/wiki/decisions.md` explaining why the skill set was added and that it is out-of-scope for the migration, or remove the row from the deliverable table. The files themselves may remain; only the unacknowledged inclusion in the acceptance deliverable is the finding.

---

### SPEC-S05 — REQ-001 Outcome Codes Incomplete Relative to Spec (MINOR)

**Spec location**: Task 3 (§Public contract) — "Outcomes are `STOPPED`, `ALREADY_STOPPED`, `UNAVAILABLE`, `FAILED`, or `TIMED_OUT`."

REQ-001 `**Detail**` correctly lists the five outcome codes. However, the spec also states in §Service manager: "Classify each service independently as stopped, already stopped, unavailable, failed, or timed out." This matches. No gap in the codes themselves. However, REQ-001 does not specify the result-row column layout (`[n][6]` — service name, initial state, final state, outcome, Win32 error, plus index). The column layout is documented in `ARCHITECTURE.md` (not under review), but `REQUIREMENTS.md` REQ-001 is the traceability source for tests; without the column contract in the requirement, test column-layout assertions (e.g., `_Test_BuildResultRow` and `_Test_ResultArrayDimensions`) cannot be traced back to a requirement. This is a minor traceability gap.

**Fix**: Add a one-line `**Detail**` extension to REQ-001 noting the result row is `[n][5]` (0-indexed columns 0–5) per the spec's public contract, or cross-reference `docs/ARCHITECTURE.md` for the column layout.

---

## Summary

**Standards axis**: 5 findings (2 MAJOR, 2 MINOR, 1 INFORMATIONAL). Worst issue: STD-S03 — predicted compliance outcomes written into a NOT RUN gate, violating the spec's explicit prohibition on predicted results in the verification document.

**Spec axis**: 5 findings (3 MAJOR, 2 MINOR). Worst issue: SPEC-S01 — the 500 ms intra-batch poll interval and 20-second batch deadline, both explicitly stated in the spec's Target Behavior section, are absent from the requirements register entirely, leaving two core timing constraints without a traceable requirement or verification method.
