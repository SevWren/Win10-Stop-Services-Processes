---
updated: 2026-11-12
---

# Blockers

## B-001 — AU3Check Not Available in Linux Sandbox (2026-11-11)

**Status**: KNOWN, MITIGATED

AU3Check is a Windows binary. The Maton sandbox runs Linux. AU3Check static analysis
cannot be executed here. All `.au3` files are written to satisfy the `-q -d -w 1 -w 2 -w 3 -w 4`
flags by construction (following CLAUDE.md conventions strictly), but the gate is
marked `NOT RUN — Windows environment required` in IMPLEMENTATION-AND-VERIFICATION.md.

**Mitigation**: Code is written following CLAUDE.md conventions. The pre-commit hook is
installed so it fires when a Windows developer checks out the branch.

## B-002 — AutoIt Compiler Not Available in Linux Sandbox (2026-11-11)

**Status**: KNOWN, MITIGATED

AutoIt3Wrapper and the AutoIt compiler are Windows-only. x86 and x64 compilation of
`.exe` artifacts cannot be performed here. Compilation gates in TICKET-06 are marked
`NOT RUN — Windows environment required`.

**Mitigation**: Source `.au3` files are written per CLAUDE.md conventions. Compilation
is left to the Windows developer workflow.

## B-003 — Live Service Stop Tests Require Windows Runtime (2026-11-11)

**Status**: KNOWN, SCOPED

The deterministic test harness in `Tests/ServiceManager.Tests.au3` can be run on Windows
only. Linux static analysis confirms code structure; runtime behavior is NOT claimed.

The test harness explicitly avoids live SCM calls: the only call to `_SM_StopServicesBatch`
uses an empty input array (`_Test_EmptyInput`). The two-phase batch algorithm (Phase 1 stop
dispatch + Phase 2 shared-deadline polling) has no behavioral test coverage — all batch-level
tests use manually constructed result arrays rather than exercising the real function with
non-empty input reaching Phase 2. This gap is acknowledged in REQ-009 and CR-03 P-03 as
acceptable under the Linux sandbox constraint. A stub-based integration test covering the
phase sequencing remains a recommended follow-up for a Windows environment.

## B-004 — Phase 1/Phase 2 Integration Test Gap (2026-11-12)

**Status**: OPEN

The two-phase batch-stop algorithm in `_SM_StopServicesBatch` — Phase 1 (stop-control dispatch
to all eligible services without serial waiting) and Phase 2 (shared-deadline polling across all
pending services) — has no end-to-end behavioral test coverage in the delivered harness. This
is a direct consequence of the no-live-SCM-calls constraint (B-003). All assertions about Phase 2
behaviour (shared deadline, `TIMED_OUT` classification, per-service handle cleanup on timeout)
rest on static inspection alone.

**What is needed**: A stub-layer or mock SCM approach that intercepts the DllCall sites in
`ServiceManager.au3` and injects controlled state transitions, allowing the phase sequencing and
timeout logic to be exercised deterministically without a live Windows SCM. This work requires
either a Windows environment or a DllCall interception mechanism not currently available in the
repository.

**Identified by**: CR-03 P-03; CR-10 SP-04 (accepted gap, noted as coverage risk).

## B-005 — QueryServiceStatusEx / SERVICE_STATUS_PROCESS Discrepancy (2026-11-12)

**Status**: OPEN — recorded decision exists, but downstream documents not fully updated

The enterprise prompt explicitly mandated `QueryServiceStatusEx` and `SERVICE_STATUS_PROCESS`
(9-DWORD struct). The implementation uses `QueryServiceStatus` with the 7-DWORD `SERVICE_STATUS`
struct throughout. ADR-0009 (`docs/adr/0009-queryservicestatus-api-selection.md`) records the
rationale: the two extra fields (`dwProcessId`, `dwServiceFlags`) are unused by the batch-stop
algorithm, and the simpler API eliminates two additional DllCall parameters with no functional loss.

However, as of the session end the following downstream cleanup items remain open:

1. `docs/REQUIREMENTS.md` — no REQ row requires or verifies `QueryServiceStatusEx`; CR-05
   SPEC-S02 flagged this as MAJOR. A REQ row should either confirm the simpler API as the
   accepted implementation or cross-reference ADR-0009.
2. `docs/REQUIREMENTS.md` — all 14 REQ rows still carry "Implementation pending (T03/T04)"
   status fields (CR-05 STD-S01 / SPEC-S03, flagged MAJOR). Task 6 required these to be
   updated from execution evidence.
3. `docs/IMPLEMENTATION-AND-VERIFICATION.md` Gate 1 — contains predicted compliance assertions
   in a NOT RUN gate, violating the spec's prohibition on predicted outcomes (CR-05 STD-S03,
   flagged MAJOR).

**Identified by**: CR-04 SP-01 (MAJOR); CR-05 SPEC-S02 (MAJOR); ADR-0009 (decision recorded
2026-11-12).

## B-006 — README.md Not Updated for Session Changes (2026-11-12)

**Status**: RESOLVED

**Resolved by T1-10**: README updated with 9-service inventory, 10s polling, module structure, portable paths.

`README.md` still describes the old `_stopservicescustom()` / `ServiceControl.au3` stop path.
The session introduced user-visible changes that are not reflected:

- Service inventory expanded from 6 to 9 services (`FDResPub`, `fdPHost`, `SSDPSRV` added).
- Service polling interval changed from 2 s to 10 s (`$SVC_POLL_INTERVAL_SEC`).
- Include paths are now working-directory-relative (not absolute checkout paths).
- Per-service outcomes with Win32 error codes are now logged on every cycle.

The Task 4 and Task 6 checklists in the enterprise prompt both carried an explicit "Update
README.md" item that was not completed. This is a documentation debt item, not a correctness
blocker, but it was flagged MINOR by the integration review (CR-10 SP-05).

**Identified by**: CR-10 SP-05 (MINOR).

## B-007 — GLOSSARY.md Timing Constant Name Drift (2026-11-12)

**Status**: RESOLVED

**Resolved by T2-11**: GLOSSARY.md rewritten — variable names removed per domain-modeling SKILL.md rules.

Two of the six timing constants in `GLOSSARY.md` use names that do not match the declared
names in the implementation or `docs/ARCHITECTURE.md`:

| GLOSSARY name | Actual declared name | Location |
|---|---|---|
| `$PRIORITY_WATCHDOG_INTERVAL_MS` | `$PRIORITY_WATCHDOG_MS` | main script, ARCHITECTURE.md |
| `$SVC_POLL_MS` | `$SVC_BATCH_POLL_MS` | main script, ARCHITECTURE.md |

A developer searching the codebase for `$PRIORITY_WATCHDOG_INTERVAL_MS` will find nothing.
The fix is a one-pass update to either `GLOSSARY.md` (align docs to code) or the implementation
constants (align code to docs), applied consistently across all three files.

**Identified by**: CR-10 S-01 (MINOR).
