# Section 05 — Configuration and Testing

Authoritative glossary entries for the Configuration and Testing domain areas.
Produced by forensic cross-audit of GLOSSARY.md, DM-05, DM-06, DM-10, the
source files, and the test harness. Read-only on all source files.

**Audit note — Timing Constants correction:**
The current GLOSSARY.md "Timing Constants" entry contains two wrong variable
names and omits one constant. The correct names (verified against
`Stop Services Processes.au3`, `#Region ;Timing constants`) are:
- WRONG in GLOSSARY.md: `$PRIORITY_WATCHDOG_INTERVAL_MS` — name does not exist in source
- CORRECT: `$PRIORITY_WATCHDOG_MS`
- WRONG in GLOSSARY.md: `$SVC_POLL_MS` — name does not exist in source
- CORRECT: `$SVC_BATCH_POLL_MS`
- OMITTED in GLOSSARY.md: `$SVC_BATCH_TIMEOUT_MS` — present in source, most consequential timing value

The entries below carry the corrected names. When these entries are merged into
GLOSSARY.md, the existing "Timing Constants" entry must be replaced.

---

## Configuration

**Service Target List:**
The fixed set of Windows service names the script attempts to stop each
monitoring cycle, declared as a module-level global in the Configuration region.
_Avoid_: service inventory, service array, `$aNames`, `$aSvcTargetNames`

**Process Target List:**
The fixed set of process executable names the script attempts to terminate each
monitoring cycle, declared as a module-level global at startup.
_Avoid_: process inventory, process array, `$sProcesses`

**Timing Constants:**
The named configuration values declared with `Global Const` in the Configuration
Region, each representing a single interval or deadline used by the monitoring
loop, the batch-stop operation, or the priority watchdog. The six constants are:
`$PROC_POLL_INTERVAL_SEC`, `$SVC_POLL_INTERVAL_SEC`, `$MAIN_LOOP_SLEEP_MS`,
`$PRIORITY_WATCHDOG_MS`, `$SVC_BATCH_TIMEOUT_MS`, and `$SVC_BATCH_POLL_MS`.
_Avoid_: settings, options, magic numbers

**Configuration Region:**
The `#Region ;Timing constants` block in `Stop Services Processes.au3` where all
timing constants are declared together at a single definition point, ensuring a
maintainer edits one location to change any interval value across the entire script.
_Avoid_: constants block, timing block, config section

---

## Testing

**Test Harness:**
The single AutoIt script (`Tests/ServiceManager.Tests.au3`) that contains all
test functions, the assertion helper, the test framework globals, and the result
printer for `ServiceManager.au3`. It exits with code 0 when all tests pass and
code 1 when any test fails.
_Avoid_: test suite (overloaded), test runner (implies a separate tool, which
does not exist here)

**Deterministic Test:**
A test function that produces the same pass/fail result regardless of the state
of the Windows SCM, installed services, or any other live system resource,
because it exercises only pure-logic or data-mapping functions and constructs all
input arrays inline without opening a live SCM handle.
_Avoid_: unit test (see Integration Test for the boundary this project draws)

**Integration Test:**
A test function that opens a live SCM handle and exercises the full DllCall chain
through `advapi32.dll`. The harness contains two such tests: one that passes an
empty service list (verifying the batch returns cleanly with no results) and one
that passes deliberately non-existent service names (exercising the UNAVAILABLE
routing path in Phase 1 without issuing any stop controls). Both require
administrator privileges.
_Avoid_: calling either integration test a deterministic test — both open a real
SCM handle

**Stub:**
An AutoIt `Func` defined in the test harness that replaces a dependency with a
fixed, scripted return value so the function under test can be exercised without
live system calls. The current harness contains no active stubs; a stub helper
(`_BuildExpectedRow`) was present in an earlier revision but was removed as dead
code. The pattern is documented in the harness header as the intended test-double
approach for this project should stubs be reintroduced.
_Avoid_: mock (a mock additionally verifies call count and arguments — this
project does neither), fake (a fake has working internal logic — stubs here are
fixed-value-only)

**Assertion:**
The boolean expression passed as the second argument to `_TestAssert()` that
determines whether a single named test case passes or fails. Every test case in
the harness contains exactly one assertion; the result increments either the pass
count or the fail count in the test framework globals.
_Avoid_: expect, matcher (Jest/Jasmine terminology that does not apply here)
