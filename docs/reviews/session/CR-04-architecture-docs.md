# CR-04 — Architecture Documentation Review

**Reviewed files**: `docs/ARCHITECTURE.md`, `docs/BASELINE-INVENTORY.md`
**Fixed point**: `ab5b012`
**Commits in range**:
- `09b99ba` Added claude skill sets
- `2a62801` chore(cleanup)
- `1d8a5ea` feat: replace broken service-stop path with native SCM batch-stop module
**Spec sources**: `Enterprise-Grad_Multi-Agent_Engineering_Implementation_Testing_Adversarial_Audit_AutoIt_prompt.md`, `docs/REQUIREMENTS.md`
**Standards sources**: `CODING_STANDARDS.md`, `CLAUDE.md`

---

## Standards

Standards evaluated against `CODING_STANDARDS.md` and `CLAUDE.md`. Documentation files are assessed for consistency with the stated conventions; the smell baseline is applied where applicable to the design choices the docs encode.

### S-01 — Path Portability violation in BASELINE-INVENTORY.md (HARD VIOLATION)

**Standard**: `CODING_STANDARDS.md` — "No hardcoded checkout roots, user-profile paths, or desktop paths in source or docs." `CLAUDE.md` — the machine-specific paths table is prefaced "must not be changed without explicit instruction", but the portability rule concerns *new* content.

**Finding**: `BASELINE-INVENTORY.md` documents the existing hardcoded paths accurately (they are baseline facts), and that is appropriate. However, the doc also records `$sLogFile = @HomeDrive & "\login\closure_log.txt"` as a path configuration value under "Path Configuration" with **migration status: acceptable**. The standards file states log path defaults to `@HomeDrive & "\login\"` which corroborates this — no violation here. On re-examination this row is consistent with the standard.

**Revised finding**: No hard violation on paths in the docs themselves. The docs reproduce existing machine-specific paths as inventoried facts, which is correct. PASS.

### S-02 — ARCHITECTURE.md records `QueryServiceStatus` where enterprise prompt mandates `QueryServiceStatusEx` (INFORMATIONAL / judgement call)

**Standard**: `CODING_STANDARDS.md` does not mandate a specific query API. However, the enterprise prompt (incorporated as the spec authority) explicitly mandates `QueryServiceStatusEx` (Task 2: "Use `OpenSCManagerW`, `OpenServiceW`, `QueryServiceStatusEx`, `ControlService`, and `CloseServiceHandle`..."). The ARCHITECTURE.md documents `QueryServiceStatus` (the non-Ex variant) throughout the DllCall patterns section, the batch-stop algorithm pseudocode, and the contract block header reference URLs.

This is a standards concern only insofar as CODING_STANDARDS.md references the spec as authority for behavior decisions. The doc encodes a design choice that conflicts with the specified API. Flagged here; also raised under Spec axis (SP-01).

**Severity**: INFORMATIONAL under Standards (the standard does not name the API); MAJOR under Spec.

### S-03 — `_SM_GetServiceState` inline DLL string — Mysterious Name smell (judgement call)

**Standard**: CODING_STANDARDS.md smell baseline — "Mysterious Name: a function, variable, or type whose name doesn't reveal what it does or holds."

**Finding**: The module map comment `; uses inline "advapi32.dll" string` on `_SM_GetServiceState` is an implementation note embedded in an architecture diagram, not a name issue. `_SM_GetServiceState` follows the `_SM_PascalCase` naming convention documented in CODING_STANDARDS.md. No smell.

**Verdict**: PASS.

### S-04 — Duplicate `advapi32.dll` string documented as "internal only" — Speculative Generality smell (judgement call)

**Standard**: CODING_STANDARDS.md smell baseline — "Speculative Generality: abstraction, parameters, or hooks added for needs the spec doesn't have."

**Finding**: The module map explicitly marks `_SM_GetServiceState`, `_SM_ServiceStateToString`, and `_SM_Win32ErrToOutcome` as "Internal only (not called from main script)". Documenting these as internal helpers that are nonetheless exported (they carry the `_SM_` prefix, implying module membership) could signal speculative generality — but the spec requires state interpretation (REQ-002) and outcome classification (REQ-001), so these helpers are needed. No smell.

**Verdict**: PASS.

### S-05 — BASELINE-INVENTORY.md `$iLastStopServices` timing note contains a factual inconsistency that could mislead (MINOR)

**Standard**: `CODING_STANDARDS.md` — docs are standards sources and must be accurate. The file at line "Service-stop check interval" states `CheckElapsedTime($iLastStopServices, 2) → 2000 ms` and labels it a conflict: "enterprise prompt targets 10s — this is a conflict to resolve." REQ-013 and the Architecture doc's timing-constants table both document the resolution as 10 s (`$SVC_POLL_INTERVAL_SEC = 10`). The BASELINE-INVENTORY.md correctly records the *baseline* value (2 s) and correctly flags it as a conflict. This is accurate inventory, not an error.

**Verdict**: PASS on accuracy; the conflict note is intentional.

### S-06 — ARCHITECTURE.md "Notes on ServiceControl.au3 Retention" section uses imprecise language about `_StopService` (MINOR)

**Standard**: `CLAUDE.md` — "`_stopservice(...)` (lowercase) — AutoIt function names are case-insensitive, so this correctly resolves to `_StopService` in ServiceControl.au3. Do not 'fix' this inconsistency." `CODING_STANDARDS.md` — docs must be accurate.

**Finding**: The Architecture doc states "_StopService function is NOT called from the main script after T04 integration." This is correct. It also states "_StopService function in ServiceControl.au3 is not deleted (it may be needed by callers not visible in this codebase)". This is consistent with the CLAUDE.md note about callers. The description is accurate.

**Verdict**: PASS.

### S-07 — Function naming convention compliance in documented interface (HARD VIOLATION — MINOR)

**Standard**: `CODING_STANDARDS.md` — "Service-manager module: `_SM_PascalCase` — `_SM_StopServicesBatch`, `_SM_GetServiceState`."

**Finding**: All documented function names (`_SM_StopServicesBatch`, `_SM_GetServiceState`, `_SM_ServiceStateToString`, `_SM_Win32ErrToOutcome`) comply with the `_SM_PascalCase` convention. The wrapper function `_RunServiceBatchStop` (documented in the integration point section) follows `_UnderscorePascalCase` as an internal main-script helper. PASS.

### S-08 — BASELINE-INVENTORY.md AU3Check table omits one documented concern (MINOR)

**Standard**: Docs must be complete and accurate per their stated scope (BASELINE-INVENTORY.md's own preamble: "Write only observed facts").

**Finding**: The AU3Check table lists `ControlService receives "str", ""` as a functional bug in `ServiceControl.au3`. The table does not include the handle-type `"long"` issue as a separate row despite it being identified in the "ServiceControl.au3 Technical Findings" section two paragraphs later (it is listed in that subsection but not the summary table). The severity is noted in the sub-section. This is a minor documentation completeness gap; the information is present in the file, just not surfaced in the AU3Check summary table.

**Severity**: MINOR — information is present elsewhere in same document.

---

**Standards summary**: 1 minor finding (S-08 — AU3Check table omits handle-type concern from summary row). No hard violations identified in the documentation content itself. The most significant cross-axis concern (QueryServiceStatus vs QueryServiceStatusEx) is primarily a Spec issue.

---

## Spec

Spec evaluated against the enterprise prompt (`Enterprise-Grad_Multi-Agent_Engineering_Implementation_Testing_Adversarial_Audit_AutoIt_prompt.md`) Task 1 and Task 2 requirements, and `docs/REQUIREMENTS.md`.

### SP-01 — ARCHITECTURE.md documents `QueryServiceStatus` where the spec mandates `QueryServiceStatusEx` (MAJOR)

**Spec**: Enterprise prompt Task 2: "Use `OpenSCManagerW`, `OpenServiceW`, `QueryServiceStatusEx`, `ControlService`, and `CloseServiceHandle`, or record a primary-source decision for a different API."

**Also**: Enterprise prompt Task 2: "Document `SERVICE_STATUS_PROCESS` as nine DWORD values and `SERVICE_STATUS` as seven DWORD values."

**Finding**: `ARCHITECTURE.md` documents `QueryServiceStatus` throughout:
- DllCall pattern section heading: "### Query service state" uses `QueryServiceStatus`.
- Reference URL provided: `.../nf-winsvc-queryservicestatus` (the non-Ex variant).
- The batch-stop algorithm pseudocode uses `QueryServiceStatus($hService, $tStatus)`.
- The contract block comment references `QueryServiceStatus`.
- The SERVICE_STATUS struct is documented as 7 DWORDs — which matches `QueryServiceStatus` / `SERVICE_STATUS`, not `QueryServiceStatusEx` / `SERVICE_STATUS_PROCESS` (9 DWORDs).

The spec explicitly mandates `QueryServiceStatusEx` and `SERVICE_STATUS_PROCESS`. The spec also mandates that both struct sizes be documented. `ARCHITECTURE.md` documents only `SERVICE_STATUS` (7 DWORDs) and not `SERVICE_STATUS_PROCESS` (9 DWORDs). There is no recorded "primary-source decision for a different API" in REQUIREMENTS.md, ARCHITECTURE.md, or the wiki that explains the downgrade to the non-Ex variant.

This means either the implementation will use the wrong API, or the architecture doc does not reflect the actual implementation. Either way, the documentation fails to satisfy the spec requirement.

**Spec line**: "Use `OpenSCManagerW`, `OpenServiceW`, `QueryServiceStatusEx`, `ControlService`, and `CloseServiceHandle`, or record a primary-source decision for a different API."
**Spec line**: "Document `SERVICE_STATUS_PROCESS` as nine DWORD values and `SERVICE_STATUS` as seven DWORD values."

**Severity**: MAJOR.

### SP-02 — ARCHITECTURE.md does not document the `SERVICE_STOP_PENDING` (state 3) handling gap (MINOR)

**Spec**: Enterprise prompt Task 2: "Interpret all service states: stopped, start pending, stop pending, running, continue pending, pause pending, and paused."

**Finding**: The batch-stop algorithm pseudocode correctly handles `SERVICE_STOPPED` (1) and `SERVICE_STOP_PENDING` (3) explicitly, and implicitly handles `SERVICE_RUNNING` (4) by issuing a stop. However, states `SERVICE_START_PENDING` (2), `SERVICE_CONTINUE_PENDING` (5), `SERVICE_PAUSE_PENDING` (6), and `SERVICE_PAUSED` (7) are not addressed in the algorithm pseudocode. The algorithm issues a stop control for any service not in state 1 or 3, without noting that the stop control may be rejected (error 1052 — INVALID_CONTROL) for a service in a pending state.

The Outcome Classification Table at the bottom does not include a row for "stop control rejected with 1052 (INVALID_CONTROL)" as a distinct case, only "ControlService fails with other error → FAILED". The enterprise prompt Task 6 explicitly lists error 1052 as a test case: "invalid control (1052)".

The REQ-002 requirement exists in REQUIREMENTS.md but ARCHITECTURE.md does not map these edge states to their expected outcomes in the pseudocode or table.

**Spec line**: "Interpret all service states: stopped, start pending, stop pending, running, continue pending, pause pending, and paused."
**Spec line (Task 6)**: "Run the full deterministic service-manager harness, including... invalid control (1052)..."

**Severity**: MINOR — the information gap is in documentation completeness; REQ-002 captures the requirement separately.

### SP-03 — BASELINE-INVENTORY.md correctly records the version delta for service and process inventories (PASS)

**Spec**: Enterprise prompt Task 1: "Compare that inventory to the repository baseline before implementation. Record every difference; never silently add, remove, or rename a service target."

**Finding**: `BASELINE-INVENTORY.md` explicitly calls out the version delta between the zip-extracted version (22 process entries, `$sProcesses2[2]`) and the cloned repo (18 entries, no second array). It also documents the service inventory delta (6 services in baseline vs 9 in enterprise prompt), naming the three additions (`FDResPub`, `fdPHost`, `SSDPSRV`) explicitly. The "Decisions Triggered by This Baseline" table maps each finding to a task. This fully satisfies the Task 1 spec requirement.

**Verdict**: PASS.

### SP-04 — BASELINE-INVENTORY.md satisfies Task 1 gate requirements (PASS)

**Spec**: Task 1 gate: "The baseline names every planned code/test/document file and identifies whether x86, x64, static analysis, unit tests, and read-only integration checks can run."

**Finding**: The Toolchain Availability table records availability of `git`, `au3check` (NOT AVAILABLE), AutoIt compiler (NOT AVAILABLE), `curl`, `python3`, and kernel version. The implication note correctly states that AU3Check and compilation gates are marked NOT RUN. The file map in the enterprise prompt lists 8 file categories; the BASELINE-INVENTORY.md identifies all source files and their line counts. The "Decisions Triggered by This Baseline" table references T03 and T04 for downstream tasks. Gate is satisfied.

**Verdict**: PASS.

### SP-05 — ARCHITECTURE.md satisfies Task 2 gate for module contract, result categories, and timing constants (PASS with caveat)

**Spec**: Task 2 gate: "Every planned API and result outcome has a primary source, and every requirement has an implementation and verification destination."

**Finding**: The Architecture doc documents the public contract in full (parameters, return shape, `@error` semantics, side effects, refs to MSDN). All five outcome codes (`STOPPED`, `ALREADY_STOPPED`, `UNAVAILABLE`, `FAILED`, `TIMED_OUT`) are defined with scenario mappings. Timing constants are defined in a single-definition-point table. MSDN URLs are cited for every DllCall pattern.

**Caveat**: The API choice (`QueryServiceStatus` vs `QueryServiceStatusEx`) creates a gap against the spec (SP-01). With that exception, the gate requirements are otherwise met.

**Verdict**: CONDITIONAL PASS — pending resolution of SP-01.

### SP-06 — ARCHITECTURE.md documents `_RunServiceBatchStop` wrapper in integration section (PASS)

**Spec**: Enterprise prompt Task 4: "Integrate `_SM_StopServicesBatch()` at the service-monitoring boundary. Log each result category."

**Finding**: The "Integration Point" section shows the before/after code pattern including the full `_RunServiceBatchStop()` wrapper with Select/Case logging for all five outcome codes. All log calls use `_LogMessage` with appropriate type `"Service"` and level arguments. This satisfies the documentation requirement for the integration point.

**Verdict**: PASS.

### SP-07 — BASELINE-INVENTORY.md `$iLastStopProcesses` finding — decision alignment (PASS)

**Spec**: REQ-011 — "Add `Global $iLastStopProcesses = 0` to globals section."

**Finding**: BASELINE-INVENTORY.md identifies the undeclared variable as a critical issue, notes the AU3Check `-w 1` implication, and maps it to "T04 integration" in the Decisions table. REQ-011 is recorded. No gap.

**Verdict**: PASS.

---

**Spec summary**: 1 major finding (SP-01 — `QueryServiceStatusEx` mandated by spec but `QueryServiceStatus` documented throughout ARCHITECTURE.md, with no recorded decision for the deviation; `SERVICE_STATUS_PROCESS` 9-DWORD struct not documented), 1 minor finding (SP-02 — pending-state handling and error 1052 not surfaced in algorithm pseudocode or outcome table).

---

## Summary

**Standards axis**: 1 finding total. Worst issue: S-08 (MINOR) — AU3Check summary table in BASELINE-INVENTORY.md omits the `"long"` handle-type concern from its rows, though the information appears in the sub-section below.

**Spec axis**: 2 findings total. Worst issue: SP-01 (MAJOR) — ARCHITECTURE.md documents `QueryServiceStatus` and the 7-DWORD `SERVICE_STATUS` struct throughout, where the enterprise prompt explicitly mandates `QueryServiceStatusEx` and requires documentation of both `SERVICE_STATUS` (7 DWORDs) and `SERVICE_STATUS_PROCESS` (9 DWORDs), with no recorded primary-source decision justifying the downgrade.
