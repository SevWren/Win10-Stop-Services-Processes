# Architecture Opportunities
Branch: arch/service-manager-migration
Date: 2026-11-12
Produced by: improve-codebase-architecture skill run, post-ServiceManager extraction session

---

## Context

This document was produced immediately after the ServiceManager module extraction
(branch `arch/service-manager-migration`). That session created `Includes/ServiceManager.au3` as
a deep module with a single public function (`_SM_StopServicesBatch`) behind which the full
two-phase batch algorithm, SCM handle lifecycle, and outcome classification are hidden.

The extraction surfaced several residual issues that were noted but not addressed. This survey
examines each of them and identifies the top candidates for the next round of deepening.

---

## Candidate 1 — `$sProcesses[18]` declared in the Variables/Logging region

**Strength: Strong**

**Files involved**
- `Stop Services Processes.au3` — lines 91-95 (Variables/Logging `#Region`)

**Problem**

The Process Inventory (`$sProcesses[18]`) is a configuration value — the fixed set of process
names the script attempts to kill each cycle — but it is declared in the `Variables/Logging`
region alongside runtime state (`$bScriptRunning`, `$iLastStopServices`, `$taskcloseran`). The
Service Inventory (`$aSvcTargetNames[9]`) correctly lives in a dedicated `Configuration — Target
lists` region. The asymmetry means that understanding the full configuration surface requires
reading two regions instead of one.

This is a shallow locality failure: the two inventory declarations are conceptually a single
concern (what targets does the script suppress?) but they sit in different regions. Any future
change to the Process Inventory — adding a process, removing one, or adjusting the duplicate
`xgamehelper.exe` entry — requires navigating to the wrong region.

**Applying the deletion test**: if `$sProcesses[18]` were moved into the Configuration region,
would complexity concentrate or just move? It concentrates: all target-list configuration would
be in one place, and the Variables/Logging region would contain only runtime state, which is its
correct responsibility.

**Solution**

Move `$sProcesses[18]` out of the `Variables/Logging` region and into the existing
`Configuration — Target lists` region, immediately after `$aSvcTargetNames`. The two inventory
arrays belong together; they are peers in the domain (Process Inventory and Service Inventory
are both defined in `GLOSSARY.md` under "Process Management" and "Service Lifecycle"
respectively).

No callers change — the variable name is unchanged. Only the region label and physical position
in the file move.

**Benefits**

- Locality: a contributor editing the target lists finds both inventories at the same location.
- The Variables/Logging region shrinks to pure runtime state, making its responsibility legible.
- The Configuration region becomes the single definition point for all suppression targets,
  matching the intent already expressed in its comment: "Edit here to add/remove service targets
  — do not modify `_RunServiceBatchStop` body."

---

## Candidate 2 — 51 `Global` declarations in `ServiceControl.au3` should be `Global Const`

**Strength: Strong**

**Files involved**
- `Includes/ServiceControl.au3` — the entire constant block (lines 2-82)

**Problem**

`ServiceControl.au3` declares every SCM access mask, service control code, service type, start
type, and error control value as `Global` (mutable). None of these values are ever reassigned;
they are pure Win32 API constants. The first line is representative:

```autoit
Global $STANDARD_RIGHTS_REQUIRED2 = 0x000F0000
```

Compare with `ServiceManager.au3`, which correctly uses `Global Const` throughout:

```autoit
Global Const $SM_STATE_STOPPED = 1
Global Const $SM_SC_MANAGER_CONNECT = 0x0001
```

Using `Global` instead of `Global Const` for these values means:
1. AU3Check under `-w 3`/`-w 4` will not catch accidental assignment to these names.
2. Any code in the compilation unit can silently overwrite a constant like `$SERVICE_STOP`
   before the DllCall that depends on it, producing a subtly wrong access mask with no
   compile-time warning.
3. The intent ("this is a fixed Win32 value") is not expressed in the code.

This is a seam hygiene issue: the convention-only boundary between `ServiceControl.au3` and
`ServiceManager.au3` (ADR-0011) already relies on discipline rather than enforcement; mutable
globals widen the gap between intent and what the compiler can check.

**Solution**

Change each `Global` declaration to `Global Const` in `ServiceControl.au3`. Also add
`#include-once` at the top of `ServiceControl.au3` (currently absent, noted in ADR-0011 as
causing duplicate-declaration warnings if the file is included twice).

**Benefits**

- AU3Check will now flag any accidental reassignment at `-w 3`/`-w 4`.
- The intent of each value as a fixed Win32 constant is expressed in the code, not just in
  comments.
- Consistency with `ServiceManager.au3` — both modules will use `Global Const` for all
  compile-time-fixed values.
- Adding `#include-once` closes the duplicate-declaration risk noted in ADR-0011.

**ADR note**: ADR-0011 documented the missing `#include-once` as a known consequence of the
convention-only boundary. Fixing both items in one pass addresses the full hygiene gap identified
there.

---

## Candidate 3 — `_SM_GetServiceState` is dead code inside `ServiceManager.au3`

**Strength: Worth exploring**

**Files involved**
- `Includes/ServiceManager.au3` — `_SM_GetServiceState` (lines 397-410)
- `Tests/ServiceManager.Tests.au3` — no direct call to `_SM_GetServiceState` in the harness

**Problem**

`_SM_GetServiceState` is listed in the module's `INTERNAL HELPERS` block and is callable from
the test harness, but it is not called from `_SM_StopServicesBatch` (the module's only public
function), not called from the main script, and not called from the test harness. All
`QueryServiceStatus` calls inside `_SM_StopServicesBatch` are performed inline — the function
was apparently extracted as a helper but then not used.

This is a shallow-module symptom: the function's interface (takes `$hService`, returns a state
integer) is nearly as complex as its implementation (one `DllStructCreate`, one `DllCall`,
one `DllStructGetData`). It adds no meaningful leverage over the inlined pattern.

Applying the deletion test: if `_SM_GetServiceState` were deleted, would complexity concentrate
or just move? It would concentrate — the inlined `QueryServiceStatus` pattern would remain
where it is, and the dead function would disappear. There is no caller to update.

**Considerations**

The test harness has a note that the original `_BuildExpectedRow` was removed as dead code
(never called). `_SM_GetServiceState` is in the same position. The function exists in the module
header as a documented internal helper, so removing it requires updating the header comment as
well.

One reason to keep it: if a future feature needs to query a single service state without going
through the full batch path, `_SM_GetServiceState` provides a ready-made building block. But
YAGNI applies — there is no current caller and no roadmap item requiring it. Speculative
generality (CODING_STANDARDS.md smell baseline) argues for removal.

**Solution**

Delete `_SM_GetServiceState` from `ServiceManager.au3` and remove it from the module's
`INTERNAL HELPERS` comment block. Verify no callers exist first (the main script, the test
harness, and no other `.au3` file in the repo calls it).

If Phase 2 behavioral tests are introduced later and require a single-service query helper,
the function can be re-added at that point with a known caller.

---

## Candidate 4 — `$SM_OUTCOME_ALREADY` / `$SM_OUTCOME_TIMEDOUT` abbreviated constant names

**Strength: Worth exploring**

**Files involved**
- `Includes/ServiceManager.au3` — lines 56, 59 (constant declarations)
- `Includes/ServiceManager.au3` — multiple use sites throughout `_SM_StopServicesBatch`
- `Stop Services Processes.au3` — `_RunServiceBatchStop` function (lines 244-256)
- `Tests/ServiceManager.Tests.au3` — multiple assertion sites

**Problem**

The outcome constant names are inconsistent in their verbosity:

```autoit
Global Const $SM_OUTCOME_STOPPED      = "STOPPED"
Global Const $SM_OUTCOME_ALREADY      = "ALREADY_STOPPED"   ; abbreviated
Global Const $SM_OUTCOME_UNAVAILABLE  = "UNAVAILABLE"
Global Const $SM_OUTCOME_FAILED       = "FAILED"
Global Const $SM_OUTCOME_TIMEDOUT     = "TIMED_OUT"          ; abbreviated
```

`$SM_OUTCOME_ALREADY` resolves to the string `"ALREADY_STOPPED"`, not `"ALREADY"`.
`$SM_OUTCOME_TIMEDOUT` resolves to the string `"TIMED_OUT"`, not `"TIMEDOUT"`.

The mismatch between constant name and string value adds cognitive load: a reader of
`_RunServiceBatchStop` who sees `$SM_OUTCOME_ALREADY` must check the declaration to know the
actual string, whereas `$SM_OUTCOME_STOPPED` is self-evident. The domain term is "ALREADY_STOPPED"
(defined in `GLOSSARY.md` as a Stop Outcome); the constant should reflect that.

The consistent names would be `$SM_OUTCOME_ALREADY_STOPPED` and `$SM_OUTCOME_TIMED_OUT`,
matching the string values and the GLOSSARY.md Stop Outcome vocabulary exactly.

**Considerations**

This is a rename with mechanical blast radius: every use site in `ServiceManager.au3`, the main
script, and the test harness must be updated. AutoIt is case-insensitive for identifiers, so
the change is a simple find-and-replace with no runtime risk. The test harness's `_TestAssert`
calls will also need the rename applied.

The benefit is small but real: constant names should read as domain vocabulary, not as
abbreviations of it.

---

## Candidate 5 — Phase 2 behavioral test gap (Windows-only Environment Gate blocker)

**Strength: Worth exploring**

**Files involved**
- `Tests/ServiceManager.Tests.au3` — test design comments (lines 36-47)
- `Includes/ServiceManager.au3` — Phase 2 poll loop (lines 316-361)

**Problem**

The test harness (`Tests/ServiceManager.Tests.au3`) covers Phase 1 routing thoroughly through
deterministic unit tests and the UNAVAILABLE integration path. Phase 2 — the poll loop that
drives pending services to `STOPPED` or `TIMED_OUT` — is not covered by any test. The test
harness explicitly documents this gap:

> "Because live Windows services that match the production service names... are not present in
> this Linux sandbox environment, the only testable integration path is the UNAVAILABLE outcome
> produced when OpenServiceW returns Win32 error 1060."

This means two of the five Stop Outcomes — `STOPPED` (the success path) and `TIMED_OUT` (the
deadline-exceeded path) — are never exercised by any test. The Phase 2 `while` loop, the
backwards-iteration removal pattern, and the timeout cleanup path have zero test coverage.

The Environment Gate (AutoIt runs only on Windows) is the structural blocker. There is no
in-process stand-in for the Windows SCM.

**Applying the DEEPENING.md dependency classification**: the SCM is a "true external" dependency
(a Windows OS component, not owned by this project). The correct testing shape is a port at the
seam between `_SM_StopServicesBatch` and the SCM calls, with a stub adapter for tests and the
real `DllCall` adapter for production. However, AutoIt has no native injection or interface
mechanism; this would require restructuring `_SM_StopServicesBatch` to accept a function-pointer
or a dispatch table for its SCM calls, which AutoIt supports via `Call()` but which would
meaningfully complicate the module's interface.

**One adapter = hypothetical seam rule applies here**: a stub adapter for tests would be the
only non-production adapter. Under DEEPENING.md seam discipline, a single-adapter seam is
indirection, not a real seam. This keeps the Phase 2 gap in "worth exploring" rather than
"strong" territory — the architectural fix is real, but the AutoIt constraints make it costly.

**Practical path forward**

The most pragmatic resolution is a Windows-only integration test that uses a real, benign
service known to exist on every Windows installation (e.g., `W32Time`, `Spooler`) and that
verifies Phase 2 reaches `STOPPED`. This requires careful test hygiene (stop a service, verify
it stops, then restart it — with a cleanup path that always restores the service state). The
test would be gated with a Windows environment check and would require `#RequireAdmin`.

This is a genuine behavioral test gap, not merely a coverage metric concern: Phase 2 contains
the most operationally significant logic in the module (the shared-deadline poll loop is the
heart of the Batch Stop algorithm), and it has never been verified to work end-to-end.

---

## Summary and Recommended Priority

| # | Candidate | Strength | Effort | ADR impact |
|---|---|---|---|---|
| 1 | Move `$sProcesses[18]` to Configuration region | Strong | Minimal — one-line move | None |
| 2 | `Global` → `Global Const` + `#include-once` in `ServiceControl.au3` | Strong | Low — mechanical substitution across 51 declarations | Closes gap documented in ADR-0011 |
| 3 | Delete dead `_SM_GetServiceState` | Worth exploring | Minimal — delete + update header | None |
| 4 | Rename `$SM_OUTCOME_ALREADY` / `$SM_OUTCOME_TIMEDOUT` | Worth exploring | Low — mechanical rename across 3 files | None |
| 5 | Phase 2 behavioral test coverage | Worth exploring | High — requires Windows, careful service lifecycle management | Potentially warrants a new ADR if a port/adapter seam is introduced |

**Top recommendation: Candidate 2** (`Global Const` + `#include-once` in `ServiceControl.au3`).

It is the highest-leverage change with the lowest risk. It directly addresses a correctness
gap (mutable Win32 constants), expresses intent that is currently implicit, adds compile-time
enforcement that AU3Check can apply, and closes a known gap from ADR-0011 — all without
touching any logic or changing any public interface. The blast radius is confined to
`ServiceControl.au3`.

**Second recommendation: Candidate 1** (move `$sProcesses[18]` to Configuration region).

It is a one-line move with zero runtime risk that improves the locality of all suppression
configuration into a single region. The change is self-contained and immediately legible to
any future contributor.

Candidates 3 and 4 are correct but low-urgency housekeeping items. Candidate 5 is architecturally
significant but blocked by the Windows-only Environment Gate and should wait until a Windows CI
environment is available or a seam injection pattern for AutoIt is prototyped.
