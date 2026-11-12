# AutoIt Service-Manager Migration Implementation Plan

> **For Codex CLI workers:** Execute the checked tasks in order. Use the repository, command output, and primary documentation as evidence. Do not substitute a narrative plan, assumed results, or simulated reviews for the work.

**Goal:** Replace the unverified service-stop path with a native, portable, and safely validated Windows SCM implementation while preserving the application's existing process, priority, hotkey, logging, and popup behavior.

**Architecture:** Keep the application entry point responsible for scheduling and user interaction. Put native Service Control Manager calls, service-state interpretation, batch stopping, and handle ownership in one focused include module. Exercise deterministic state and result logic through a non-destructive test harness before wiring the module into the monitoring loop.

**Tech Stack:** Windows 10, AutoIt 3.x, AutoIt3Wrapper, Au3Check, PowerShell, native Windows Service Control Manager APIs.

**Spec:** This document, the user request, and the repository instructions in `CLAUDE.md`. When they conflict, record the conflict in `docs/REQUIREMENTS.md` and obtain a decision before changing behavior with side effects.

## Codex CLI Operating Profile

- Target model: `gpt-5.6-terra`. Work autonomously from the concrete task, constraints, paths, and verification gates in this document.
- Begin discovery immediately; do not stop after restating this plan or wait for approval between safe, ordered tasks.
- Batch independent reads and research. Reserve sequential work for dependencies, shared-file integration, and evidence-gated decisions.
- Use separate Codex tasks only for independent research or review. The lead task alone changes shared integration files and reconciles conflicting findings.
- Send concise progress updates at completed gates or when an authority, environment, or safety decision blocks further execution.

## Global Constraints

- Work from the repository root. Start with `git status --short`; preserve every pre-existing change, untracked file, and binary artifact.
- Use `rg` or `rg --files` for repository discovery. Read the full relevant AutoIt source and its includes before changing an interface.
- Treat repository source and tested behavior as evidence. Record an uncertainty instead of inventing a requirement, API signature, test result, reviewer result, or compiler result.
- Use portable working-directory paths for project assets, build artifacts, and runtime data. Static checkout roots, user profiles, and desktop paths are migration debt and must not be introduced.
- Preserve `#RequireAdmin`, x86 and x64 support, and background/hotkey operation unless a documented technical decision changes one.
- Do not disable services, alter startup types, registry keys, service permissions, dependencies, scheduled tasks, Windows Update settings, Defender, firewall settings, or licensing configuration.
- Do not stop, terminate, disable, or modify a production Windows service during automated validation. A live stop test requires explicit authorization and a disposable test environment.
- Do not force-stop a service through `svchost.exe` or another host process. Report access and dependency failures as returned by Windows.
- Do not automatically stop dependent services. A dependency-related rejection is a per-service outcome, not permission to expand the target set.
- Use `apply_patch` for edits. Do not reset, restore, delete, or overwrite unrelated user work. Do not commit unless the user requests a commit.
- A compilation, test, review, or acceptance claim requires fresh command output or a cited report. If an environment prerequisite is unavailable, mark the corresponding gate `NOT RUN` and state why.

## Evidence and Review Gates

- Maintain requirement rows as `REQ-ID | source | implementation | test or inspection | evidence | status` in `docs/REQUIREMENTS.md`.
- Keep commands, tool versions, exit codes, warnings, results, and limitations in `docs/IMPLEMENTATION-AND-VERIFICATION.md`. Do not write predicted outcomes there.
- Each materially modified `.au3` file needs an independent whole-file review after its final edit. The reviewer checks the delivered file hash and writes `docs/reviews/REVIEW-<filename>.md`.
- When separate Codex agents are available, use a different agent for each material `.au3` review. Give reviewers the final file, relevant dependencies, requirements, and tests; they return findings, not approval by assertion.
- If separate agents are unavailable, record the independent-review gate as `NOT RUN`. A self-review may find defects but never counts as independent approval.
- Any edit after a review invalidates that file's approval. Correct findings, re-run affected checks, and repeat the file review.
- Only `BLOCKER`, `CRITICAL`, and `MAJOR` findings block acceptance. The final report lists accepted `MINOR` and `INFORMATIONAL` findings with rationale.

## Target Behavior

### Service manager

- Manage this configured inventory unless a documented requirement decision changes it: `FDResPub`, `fdPHost`, `TrustedInstaller`, `wuauserv`, `UsoSvc`, `DoSvc`, `WaaSMedicSvc`, `SSDPSRV`, and `sppsvc`.
- Compare that inventory to the repository baseline before implementation. Record every difference; never silently add, remove, or rename a service target.
- Use `OpenSCManagerW`, `OpenServiceW`, `QueryServiceStatusEx`, `ControlService`, and `CloseServiceHandle`, or record a primary-source decision for a different API.
- Interpret all service states: stopped, start pending, stop pending, running, continue pending, pause pending, and paused. A stop request is not proof that the service stopped.
- In one cycle, open and inspect eligible services, issue stop controls without serial waiting, then poll all pending services against one shared deadline. The default poll interval is 500 ms and the default batch deadline is 20 seconds.
- Classify each service independently as stopped, already stopped, unavailable, failed, or timed out. Continue processing unrelated services when it remains safe.
- Request only `SC_MANAGER_CONNECT`, `SERVICE_QUERY_STATUS`, and `SERVICE_STOP` access unless primary documentation proves an additional access right is necessary.
- Capture AutoIt `@error` immediately after each `DllCall`. When a Windows API reports failure, capture `GetLastError()` before another API call. Every acquired SCM or service handle has one cleanup path and exactly one `CloseServiceHandle`.

### Preserved behavior

- Preserve the configured process inventories and process-closing summaries; compare them against the baseline rather than copying arrays into new modules.
- Investigate duplicate process entries and the second-loop result-reporting defect before changing either. Retain an intentional duplicate or correct a proven defect only with a requirement row and regression evidence.
- Preserve `SetProcessPriority()`, `LockProcessPriority()`, `_PriorityWatchdog()`, the AutoIt/Windows priority-class conversion boundary, and the rule that real-time priority is never automatic.
- Preserve `Shift+F1`, `ScrollLock+Pause`, `Ctrl+Shift+9`, and `Ctrl+Alt+Shift+9`. Detect and log a failed hotkey registration.
- Preserve the existing popup class/text match, tray behavior, pause/resume behavior, and logging levels. Keep logging failures isolated from service-handle cleanup.
- Keep process polling at 2 seconds, service polling at 10 seconds, and priority-watchdog polling at 10 seconds. Define each interval once as a named configuration value.
- Preserve seven-day log rotation while migrating the runtime log location into the portable working-directory layout.

### Primary research sources

- Microsoft Service Functions: `https://learn.microsoft.com/en-us/windows/win32/services/service-functions`
- `OpenSCManagerW`: `https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-openscmanagerw`
- `OpenServiceW`: `https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-openservicew`
- `QueryServiceStatusEx`: `https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-queryservicestatusex`
- `ControlService`: `https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-controlservice`
- `SERVICE_STATUS_PROCESS`: `https://learn.microsoft.com/en-us/windows/win32/api/winsvc/ns-winsvc-service_status_process`
- `CloseServiceHandle`: `https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-closeservicehandle`
- AutoIt `DllCall`, `DllStructCreate`, `HotKeySet`, and `AdlibRegister` documentation.

## File Map

| File | Action | Responsibility |
|---|---|---|
| `Stop Services Processes.au3` | Modify | Scheduling, configuration, interaction, and integration only. |
| `Includes/ServiceManager.au3` | Create or modify after manifest approval | Native SCM adapter, state interpretation, batch operation, and cleanup. |
| `Includes/ServiceControl.au3` | Inspect before retaining, adapting, or retiring | Current service-control behavior and compatibility boundary. |
| `Tests/ServiceManager.Tests.au3` | Create | Deterministic state, result, timeout, and cleanup tests; no live stop controls. |
| `docs/BASELINE-INVENTORY.md` | Create | Repository behavior, toolchain, build capability, and source inventory. |
| `docs/REQUIREMENTS.md` | Create | Requirements, source conflicts, decisions, and evidence status. |
| `docs/ARCHITECTURE.md` | Create | Module interfaces, scheduling, ownership, and side-effect boundary. |
| `docs/IMPLEMENTATION-AND-VERIFICATION.md` | Create | Commands, results, reviews, limitations, and acceptance. |
| `docs/reviews/REVIEW-<filename>.md` | Create per material `.au3` change | Independent whole-file review and delivered hash. |

Do not create an additional `.au3` file until the requirements register identifies its responsibility, public interface, test approach, and dedicated-review requirement.

---

## Task 1: Discover and Freeze the Baseline

**Files:**
- Create: `docs/BASELINE-INVENTORY.md`
- Read: `CLAUDE.md`, `README.md`, `Stop Services Processes.au3`, every included project `.au3` file, and existing tests.

- [ ] Run `git status --short`, `git rev-parse --show-toplevel`, and `rg --files`; record the root, branch, user changes, source files, includes, tests, binaries, documentation, and resources.
- [ ] Read the complete entry point and `Includes/ServiceControl.au3`. Trace every service, process, logging, timer, priority, popup, and hotkey call site.
- [ ] Record current service and process inventories, timing values, output directives, runtime paths, compilation directives, known warnings, and every source comment that identifies broken behavior.
- [ ] Discover installed AutoIt, Au3Check, and compiler executables. Record version, architecture availability, exact command syntax, and unavailable tooling.
- [ ] Write only observed facts to `docs/BASELINE-INVENTORY.md`; list unresolved differences between the baseline and this plan separately.

**Gate:** The baseline names every planned code/test/document file and identifies whether x86, x64, static analysis, unit tests, and read-only integration checks can run.

## Task 2: Define Contracts and Verify APIs

**Files:**
- Create: `docs/REQUIREMENTS.md`, `docs/ARCHITECTURE.md`
- Read: primary Microsoft and AutoIt references listed above.

- [ ] Convert each target behavior and preservation rule into a `REQ-*` row with one implementation location and one verification method.
- [ ] Reconcile source-plan conflicts, including service inventory, 2-second versus 10-second service polling, log-path migration, existing `ServiceControl.au3`, and expected output paths. A behavior-changing conflict needs an explicit decision before code changes.
- [ ] Capture the verified DllCall contract for each SCM API: DLL/export, return value, parameter order/types, output structures, access rights, failure behavior, and immediate error-capture rule.
- [ ] Document `SERVICE_STATUS_PROCESS` as nine DWORD values and `SERVICE_STATUS` as seven DWORD values. Confirm that `ControlService` receives the latter structure, not the former.
- [ ] Treat any earlier proposed service-manager code as unverified reference material. Compare it to the primary-source contract before reusing a declaration, structure, timeout rule, or cleanup path.
- [ ] Freeze the file map, public module contract, result categories, ownership rules, service timing constants, and non-destructive validation strategy in `docs/ARCHITECTURE.md`.

**Gate:** Every planned API and result outcome has a primary source, and every requirement has an implementation and verification destination.

## Task 3: Build a Safe, Testable Service Boundary

**Files:**
- Create: `Includes/ServiceManager.au3`, `Tests/ServiceManager.Tests.au3`

**Public contract:**
- `_SM_StopServicesBatch(ByRef $aServiceNames, $iBatchTimeoutMs, $iPollIntervalMs)` owns all SCM and service handles opened for one batch and returns one result row per requested service.
- Each result row contains service name, initial state, final state, outcome, and captured Win32 error. Outcomes are `STOPPED`, `ALREADY_STOPPED`, `UNAVAILABLE`, `FAILED`, or `TIMED_OUT`.
- Batch-level `@error` represents a failure that prevents processing the batch; a per-service failure is represented in that service's result row.

- [ ] Write deterministic tests for all seven states, stop eligibility, invalid control acceptance, missing service, access denied, a single-service failure in a batch, shared timeout, state transitions, and per-service result accounting.
- [ ] Run the test harness before implementation and record the failing cases that define the missing contract.
- [ ] Implement pure state/action and result-aggregation helpers first. Keep them independent of live SCM calls so tests do not stop a service.
- [ ] Implement the SCM adapter using the verified Unicode APIs and minimally necessary access rights. Use one cleanup path for every acquired handle.
- [ ] Implement batch inspection, stop requests, shared-deadline polling, and final result rows. A failure for one service must not skip safe work for another.
- [ ] Document every exported service-manager function with parameter types, return shape, `@error` and `@extended` meaning, ownership, and failure conditions in `docs/ARCHITECTURE.md`.
- [ ] Re-run the deterministic tests. Add a read-only status query only if it cannot send a control request.

**Gate:** The test harness passes without sending a stop control to a production service, and the module returns complete rows for every configured input service.

## Task 4: Integrate Without Regressions

**Files:**
- Modify: `Stop Services Processes.au3`
- Inspect: `Includes/ServiceControl.au3`, `README.md`

- [ ] Add named process, service, verification, and watchdog timing constants. Use the 2-second process, 10-second service, 500-ms verification, 20-second batch, and 10-second watchdog defaults only after Task 2 resolves baseline conflicts.
- [ ] Integrate `_SM_StopServicesBatch()` at the service-monitoring boundary. Log each result category and preserve a responsive main loop; do not add a service-specific blocking wait to the process loop.
- [ ] Preserve process closing, priority setting, watchdog behavior, popups, tray notifications, all four hotkeys, pause/resume, exit, and log rotation. Correct a discovered defect only with a requirement, regression test, and recorded evidence.
- [ ] Migrate touched source, build, icon, include, and log paths to the working-directory policy. Do not add static checkout, profile, or desktop paths.
- [ ] Decide whether `Includes/ServiceControl.au3` is retained as a compatibility layer or superseded by `Includes/ServiceManager.au3`. Leave one authoritative service implementation and update callers accordingly.
- [ ] Update `README.md` when visible behavior, configuration, hotkeys, output paths, or validation requirements change.

**Gate:** The integration has a traceable requirement map, no duplicate service-control path, and targeted regression evidence for each preserved feature.

## Task 5: Review, Correct, and Re-review

**Files:**
- Create: `docs/reviews/REVIEW-Stop-Services-Processes.au3.md`
- Create: `docs/reviews/REVIEW-ServiceManager.au3.md`
- Create: `docs/reviews/REVIEW-ServiceManager.Tests.au3.md`

- [ ] Dispatch independent reviewers for each materially modified `.au3` file when the environment supports them. Reviewers inspect the complete final file and its direct dependencies, rather than an author-provided summary.
- [ ] Require reviewers to check AutoIt syntax/scopes, include paths, timers and reentrancy, DllCall signatures, pointer/handle widths, structure layouts, immediate error capture, every early-return cleanup path, result accounting, unexpected side effects, and regression coverage.
- [ ] Record file path, SHA-256 hash, reviewer identity, reviewed dependencies, findings with severity/location/evidence, decision, and approval status in each report.
- [ ] Resolve every `BLOCKER`, `CRITICAL`, and `MAJOR` finding. Re-run the affected test or inspection and have the independent reviewer inspect the new hash.
- [ ] Run a cross-file audit for function declarations/callers, globals, constants, arrays, includes, DllCalls, duplicate service inventories, result contracts, timing constants, and documentation references.

**Gate:** Each modified `.au3` file either has an independent approval for its final hash or is explicitly marked as blocked from independent review. No unaddressed blocking finding remains.

## Task 6: Validate and Deliver

**Files:**
- Update: `docs/IMPLEMENTATION-AND-VERIFICATION.md`, `docs/ARCHITECTURE.md`, `docs/REQUIREMENTS.md`, `README.md`

- [ ] Run Au3Check with the repository's configured flags and record the exact command, warnings, errors, and exit code.
- [ ] Compile x86 and x64 separately when both compilers are available. Record compiler path/version, command, exit code, warnings, output artifact, and path-portability result for each architecture.
- [ ] Run the full deterministic service-manager harness, including access denied (5), dependent-service rejection (1051), invalid control (1052), missing service (1060), unavailable control (1061), not-started (1062), dependency failure (1068), and deletion-pending (1072) classification where test doubles can represent them.
- [ ] Run process/priority/watchdog regression checks, logging/rotation checks, hotkey registration checks, popup checks, and safe read-only service-status integration checks that are actually available.
- [ ] Verify the portable path contract by using a second checkout or moved working directory. Confirm that required assets, log creation, and affected build output resolve without source edits.
- [ ] Update every requirement row from execution evidence. Mark unavailable checks `NOT RUN` with the environmental reason; do not convert them to pass-by-inspection.
- [ ] Write the final report: changed/created files, architecture, source/API decisions, review findings, compile/test evidence, accepted limitations, and exactly one outcome: `ACCEPTED`, `CONDITIONALLY ACCEPTED`, or `REJECTED`.

**Gate:** `ACCEPTED` requires all mandatory checks to have passed, all material files to have final-hash independent approvals, and no unresolved blocking finding. `CONDITIONALLY ACCEPTED` requires no unresolved blocking finding and explicitly lists each non-blocking `NOT RUN` item. Otherwise the outcome is `REJECTED`.

## Execution Directive

Begin Task 1 now. Move to the next task only after its gate has evidence. Use separate Codex tasks only for bounded, independent research or review work; do not let parallel agents edit the same file. The lead task owns integration, evidence reconciliation, and the final report.
