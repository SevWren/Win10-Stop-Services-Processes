# Analysis: test_process_close.au3

**File path:** `test_process_close.au3` (repo root)
**Date of analysis:** 2026-11-12

---

## 1. What it does

`test_process_close.au3` is a 13-line script that runs an infinite loop, polling every 2 seconds to check whether `TCPSVCS.EXE` is running. If the process is found it calls `ProcessClose("TCPSVCS.EXE")` to terminate it; either way it writes a one-line status message to the console. The script never exits on its own.

`TCPSVCS.EXE` is also entry 14 (0-indexed) in the production process target array `$sProcesses[]` inside `Stop Services Processes.au3`, so the script is exploring the same termination behaviour that the main script already performs as part of its regular `_KillProcessList` cycle.

---

## 2. Relationship to the main test suite

This file is not part of the official test harness. The project's test infrastructure lives under `Tests/` and is represented by `Tests/ServiceManager.Tests.au3`, which follows a documented design philosophy: a named `_TestAssert` framework, pass/fail counters, structured console output, and a CI-friendly non-zero exit on failure.

`test_process_close.au3` has none of those characteristics. It has no `#include` of a module under test, no assertions, no pass/fail reporting, and no defined scope or exit condition. It was not produced as part of a ticket or branch (the test harness carries a branch and ticket header; this file has neither).

---

## 3. Quality assessment

The file does not meet the project's testing standards on any dimension:

| Criterion | `Tests/ServiceManager.Tests.au3` | `test_process_close.au3` |
|---|---|---|
| Named test functions | Yes (`_Test_*` pattern) | No |
| Assertion framework | Yes (`_TestAssert`) | No |
| Pass/fail accounting | Yes | No |
| Structured console output | Yes | No |
| CI-compatible exit code | Yes (`Exit 0` / `Exit 1`) | No (never exits) |
| Ticket / branch header | Yes (T03, arch branch) | No |
| Defined scope | Yes (ServiceManager.au3 pure-logic + SCM integration) | No |
| Commented-out dead code | No | Yes (two `MsgBox` lines commented out with `;~`) |
| Stale inline comment | — | Yes ("Check if the Notepad process is running" on a check for `TCPSVCS.EXE`) |

The stale comment ("Notepad") is a direct signal that the file was adapted from an AutoIt boilerplate or earlier experiment without being cleaned up. The two commented-out `MsgBox` lines reinforce this: they are diagnostic scaffolding that was never removed.

---

## 4. Recommendation

**Delete the file.**

The rationale:

- **No test value.** The file does not test any module. It exercises `ProcessClose` directly on a live process, which is exactly what the production code already does. No assertion, no regression protection, and no coverage is added.
- **Duplicate of production behaviour.** The kill-and-poll loop duplicates `_KillProcessList` in `Stop Services Processes.au3`. If the intent was to verify that `ProcessClose` works against `TCPSVCS.EXE`, that verification is already implicit in the production path.
- **Not a candidate for `Tests/ServiceManager.Tests.au3`.** The test suite covers `ServiceManager.au3` (service stop semantics). Process kill behaviour via `ProcessClose` is a different domain and REQ-009 (no live stop controls in the harness) would prohibit a live-termination test anyway.
- **Not a candidate for standalone archival.** The file provides no documented context, no reproducible outcome, and no value as a reference. Keeping it creates noise when surveying repo contents.

If a future need arises to validate `ProcessClose` integration specifically, that work should be scoped as a new ticket, follow the `_Test_*` / `_TestAssert` conventions, and live under `Tests/`.
