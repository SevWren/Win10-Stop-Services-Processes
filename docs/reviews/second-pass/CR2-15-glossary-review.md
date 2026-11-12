# CR2-15 — GLOSSARY.md Second-Pass Review

**Date**: 2026-11-12
**Fixed point**: current file state (`GLOSSARY.md` as it stands today)
**Spec sources**: `.agents/skills/domain-modeling/GLOSSARY-FORMAT.md`, `.agents/skills/domain-modeling/SKILL.md`
**Review axes**: Standards (format + implementation-detail rule) | Spec (completeness + accuracy)

---

## Standards

### S1 — Format compliance

The GLOSSARY-FORMAT.md canonical structure for each entry is:

```
**Term**:
{definition}
_Avoid_: ...
_See also_: ... (optional)
```

Overall the file follows this structure well. Specific deviations found:

**S1-a — `Pending Service` has a `_See also_:` field; all other entries do not.**
Line 89: `_See also_: Pending List`. This is permitted by the format spec, but it is the only entry in the file that uses it. Not a violation — the spec marks `_See also_` as optional — but worth noting for consistency.

**S1-b — Colon placement on term headings is inconsistent in source but renders correctly.**
All bold terms are followed immediately by a newline and then the definition. The format example shows `**Term**:` with the colon on the same line. In the GLOSSARY.md file every entry uses `**Term**:` correctly on the heading line. No deviation here.

**S1-c — All 50 entries present in the file do follow the bold-term / definition / `_Avoid_:` structure.** No entry is missing its `_Avoid_:` field. Pass.

---

### S2 — Implementation details

The SKILL.md rule: *"GLOSSARY.md should be totally devoid of implementation details."* The GLOSSARY-FORMAT.md rule: *"Define what it IS, not what it does."*

**S2-a — `Test Case`: function name in definition.**
Line 277–278:
> "One named boolean check with an optional expected/actual pair. Each test case maps to a single observable property of the function under test."

The phrase "function under test" is acceptable domain vocabulary in a testing glossary. No implementation detail present. Pass.

**S2-b — `Test Function`: naming convention `_Test_` in definition.**
Lines 281–283:
> "An AutoIt function whose name begins with `_Test_` and whose body contains one or more related test cases against a single function under test."

The naming convention `_Test_` is an implementation detail — it is a specific code naming pattern, not a domain concept. The domain concept is simply: a named grouping of related test cases. The `_Test_` prefix belongs in CLAUDE.md (where function naming conventions live), not the glossary.

**Violation — cite SKILL.md: "totally devoid of implementation details."**

**S2-c — `Test Harness`: file path and exit code in definition.**
Lines 269–273:
> "The single AutoIt script that runs all tests for the ServiceManager module. It owns the test framework globals, the assertion helper, and the result printer. It is executed directly by the AutoIt runtime and exits with code 0 (all pass) or 1 (any failure)."

"exits with code 0 (all pass) or 1 (any failure)" is an implementation/operational detail of the harness, not part of the domain concept of what a test harness *is*. It belongs in the test harness file header or CLAUDE.md.

**Violation — cite SKILL.md: "totally devoid of implementation details."**

**S2-d — `Unit Test`: four specific function names in definition.**
Lines 304–308:
> "The harness labels four groups as pure-logic or pure-mapping helpers that fall into this category."

This sentence is acceptable (it references the concept), but the entry stops just short of naming the functions. No function names appear in the definition. Pass.

**S2-e — `Integration Test`: "empty input array" in definition.**
Lines 311–313:
> "The harness contains exactly one such test, which calls the function with an empty input array."

"calls the function with an empty input array" describes the specific implementation of the one integration test rather than what an integration test *is* as a domain concept. The domain concept is: a test that exercises a live system boundary. The specific test case's input is an implementation detail.

**Violation — cite SKILL.md: "totally devoid of implementation details."**

**S2-f — `Service Name`: example values in definition.**
Lines 36–38:
> "Examples: `wuauserv`, `TrustedInstaller`."

These are specific entries from the Service Inventory, not part of what a Service Name *is*. They are illustrative, but the GLOSSARY-FORMAT.md instructs: "Define what it IS". Borderline; the examples help distinguish Service Name from Display Name, but strictly they are implementation data.

**Judgement call** — borderline, not a hard violation given the disambiguation value.

**S2-g — `Service Inventory`: canonical entry list in definition.**
Lines 121–123:
> "Canonical entries include `FDResPub`, `fdPHost`, `TrustedInstaller`, `wuauserv`, `UsoSvc`, `DoSvc`, `WaaSMedicSvc`, `SSDPSRV`, and `sppsvc`."

A hardcoded list of service names from the codebase is implementation data. The domain concept of Service Inventory is the fixed set of targets; the specific contents of that set belong in the script's global variables, not the glossary.

**Violation — cite SKILL.md: "totally devoid of implementation details."**

**S2-h — `Log Type`: five specific string literals in definition.**
Lines 237–239:
> "The five defined values are `System`, `Process`, `Service`, `ProcessPriority`, and `PriorityWatchdog`. Appears bracketed in the on-disk format: `[Service]`."

The specific string values and the on-disk format string (`[Service]`) are implementation details. The domain concept is: a tag that identifies which subsystem produced a log entry. The enumeration of exact string values belongs in code or CLAUDE.md. The on-disk format `[Service]` is definitely implementation.

**Violation — cite SKILL.md: "totally devoid of implementation details."**

**S2-i — `Log Entry`: format string in definition.**
Lines 244–246:
> "in the format: `{time} {date} [{LogType}] {message}`."

The specific log line format is an implementation detail of the logging subsystem. The domain concept is: a single recorded event from one subsystem at one point in time.

**Violation — cite SKILL.md: "totally devoid of implementation details."**

**S2-j — `Service State`: seven state names with specific API string values in definition.**
Lines 47–51:
> "One of seven named values: `STOPPED`, `START_PENDING`, `STOP_PENDING`, `RUNNING`, `CONTINUE_PENDING`, `PAUSE_PENDING`, `PAUSED`. The numeric encoding of each state is preserved verbatim in the Initial State and Final State fields of a Result Row."

The seven named states are domain vocabulary — they are the lifecycle positions a service can be in. This is acceptable as it identifies the concept's extent. However, "The numeric encoding of each state is preserved verbatim in the Initial State and Final State fields of a Result Row" is an implementation detail describing how the data is stored. That sentence belongs in a code comment or architecture doc.

**Partial violation** on the final sentence only.

---

### S3 — Stale variable names

The task prompt specifically asks whether `$PRIORITY_WATCHDOG_INTERVAL_MS`, `$SVC_POLL_MS`, or `$sProcesses2[]` remain in the glossary. DM-10 identified all three as stale names from an earlier version.

**S3-a — `$PRIORITY_WATCHDOG_INTERVAL_MS`**: Not present anywhere in GLOSSARY.md. Cleared.

**S3-b — `$SVC_POLL_MS`**: Not present anywhere in GLOSSARY.md. Cleared.

**S3-c — `$sProcesses2[]`**: Not present anywhere in GLOSSARY.md. Cleared.

All three stale variable names have been removed. Pass on all three.

---

### Standards summary

| ID | Severity | Finding |
|----|----------|---------|
| S2-b | Hard | `Test Function` names the `_Test_` prefix — implementation convention, not domain concept |
| S2-c | Hard | `Test Harness` includes exit code behaviour — implementation detail |
| S2-e | Hard | `Integration Test` describes specific test input — implementation detail |
| S2-g | Hard | `Service Inventory` lists specific service name values — implementation data |
| S2-h | Hard | `Log Type` enumerates exact string literals and on-disk format — implementation detail |
| S2-i | Hard | `Log Entry` includes format string `{time} {date} [{LogType}] {message}` — implementation detail |
| S2-j | Partial | `Service State` final sentence on numeric encoding in Result Row — implementation detail |
| S2-f | Judgement call | `Service Name` examples `wuauserv`, `TrustedInstaller` — borderline |
| S1-a | Note | `Pending Service` is the only entry using `_See also_:` — not a violation, consistency note only |
| S3-a/b/c | Pass | All three stale variable names confirmed absent |

---

## Spec

### Term count

The task prompt states 46 terms are expected. A manual count of the current GLOSSARY.md yields **50 terms**:

| Section | Terms | Count |
|---------|-------|-------|
| Service Lifecycle | SCM, SCM Handle, Service, Service Handle, Service Name, Display Name, Service State, Stable Service State, Transient Service State, Stop-Eligible State, Control Code, Stop Control, Pending Service, Pending List, Batch Stop, Stop Outcome, Result Row, Service Inventory | 18 |
| Process Management | Process, PID, Process Kill, Process Inventory, Priority Class, AutoIt Priority Constant, Priority Drift, Priority Watchdog, Watchlist | 9 |
| Script Behaviour | Monitoring Loop, Toggle, Timing Constants, Tray Notification, Misc Popup | 5 |
| Logging | Log Level, Log Type, Log Entry, Log File, Log Rotation, Suppression Event | 6 |
| Testing | Test Harness, Test Case, Test Function, Test Suite, Stub, Deterministic Test, Unit Test, Integration Test, Environment Gate | 9 |
| Architecture | Deep Module, Seam, Module Extraction | 3 |
| **Total** | | **50** |

The file contains 50 terms, not 46. The 4-term surplus over the expected 46 is not itself a spec violation — the spec says "are all 46 terms present", not "are there exactly 46 terms". The question is whether the 46 expected terms are a subset of the 50 present. With no authoritative list of which 46 were expected, the finding is: the glossary is a superset; no terms appear missing by count.

---

### SP1 — "Assertion" term (DM-05 identified as missing)

DM-05 proposed **Assertion** as a term: *"The boolean expression passed as the second argument to `_TestAssert(...)`. An assertion evaluates to `True` or `False`..."*

DM-05 also noted that `Test Case` explicitly avoids the term "assertion" with the note: *"too granular — in this project one test case contains exactly one assertion"*.

**Current state**: The term **Assertion** is NOT present in GLOSSARY.md. The `_Avoid_` field on `Test Case` references assertions but no independent `Assertion` entry exists.

This is an omission relative to DM-05's proposal. DM-05 explicitly proposed Assertion as a distinct term, arguing it has a precise meaning in the harness context distinct from Test Case. Its absence means a reader encountering `_TestAssert(...)` in the code has no glossary anchor for what an assertion *is* versus what a test case *is*.

**Finding**: `Assertion` term is missing. DM-05 identified this; it has not been added.

---

### SP2 — Definition accuracy against code

**SP2-a — `Timing Constants` definition is accurate but overly abstract.**
The definition lists six named configuration values conceptually without naming any variables. This is correct per the implementation-detail rule (DM-10 Section 2b called for removal of specific variable names, which were removed). The definition accurately represents the domain concept. Pass on accuracy.

**SP2-b — `Service Inventory` lists `SSDPSRV` and `sppsvc` as canonical entries.**
Per the CLAUDE.md project overview, the service inventory is a hardcoded list. The specific names listed in the glossary entry (`FDResPub`, `fdPHost`, `TrustedInstaller`, `wuauserv`, `UsoSvc`, `DoSvc`, `WaaSMedicSvc`, `SSDPSRV`, `sppsvc`) should be verified against the actual `$aServiceNames[]` array in `Stop Services Processes.au3`. This review cannot confirm those names without reading the script directly, but the concern is flagged: if the script's array has changed since this entry was written, the glossary would contain stale data.

**SP2-c — `Batch Stop` definition is clean and concept-only.**
Lines 98–103: "A single operation that attempts to stop a group of services as a unit, issuing all stop controls without serial waiting (Phase 1) and measuring the outcome of each service against one shared deadline (Phase 2). All stop operations are cooperative (graceful); there is no force-kill fallback for services that do not respond in time."

The function name `_SM_StopServicesBatch()` that appeared in an earlier version (flagged in DM-10 Section 2c) is absent. The definition is now concept-only. Pass.

**SP2-d — `Process Inventory` no longer references `$sProcesses2[]`.**
DM-10 Section 2a identified `$sProcesses2[]` as a stale reference. The current definition at lines 149–154 makes no mention of `$sProcesses2[]` or any array variable name. It describes the concept correctly. Pass.

**SP2-e — `Test Case` definition diverges from DM-05 proposed wording.**
Current: "One named boolean check with an optional expected/actual pair."
DM-05 proposed: "One call to `_TestAssert(...)` — a named boolean check..."

The current definition omits the `_TestAssert(...)` reference, which is correct (function name is an implementation detail). However, the DM-05 proposal also specified that a test case "increments `$g_iTestCount`" — that implementation detail is correctly absent from the current entry. The current definition is cleaner than the DM-05 proposal in this respect. Pass on accuracy.

**SP2-f — `Stub` definition is accurate.**
The definition ("replaces a dependency with a fixed, scripted return value, so that the function under test can be exercised without issuing live Windows SCM calls") matches the harness description. The `_Avoid_: mock` contrast is correctly maintained. Pass.

**SP2-g — `Priority Watchdog` definition is accurate and clean.**
The earlier contaminated version named `AdlibRegister`, the 10-second interval, and three specific array names (flagged in DM-10 Section 4d). The current definition at lines 179–184 names none of these. It correctly describes the concept: an autonomous periodic mechanism that detects and corrects Priority Drift and evicts dead PIDs. Pass.

**SP2-h — `AutoIt Priority Constant` range `0–5` in definition.**
Lines 164–168: "The integer (0–5) that AutoIt's process-priority API accepts: 0 = Idle, 1 = Below Normal, 2 = Normal, 3 = Above Normal, 4 = High, 5 = Real-time."

This enumeration of the six values with their integer codes is borderline. The range `0–5` and the mapping to priority names are specific to AutoIt's API layer. Per the implementation-detail rule, this could be trimmed to just the concept ("an integer representing a priority tier on a six-level scale"). However, the distinction between AutoIt Priority Constants and Windows API hex values is itself a domain-level confusion this project must manage, so the mapping serves a disambiguation purpose beyond mere implementation fact. Flagged as a judgement call.

---

### Spec summary

| ID | Severity | Finding |
|----|----------|---------|
| SP1 | Missing term | `Assertion` absent — DM-05 identified this as a required addition; not yet added |
| SP2-b | Unverified | `Service Inventory` entry lists 9 specific service names; accuracy against current code not confirmed |
| SP2-h | Judgement call | `AutoIt Priority Constant` enumeration is borderline implementation detail vs. necessary disambiguation |
| All others | Pass | Stale names removed, Batch Stop cleaned, Priority Watchdog cleaned, Test Case accurate |

---

## Summary

**Standards axis**: 6 hard violations, 1 partial, 1 judgement call. Worst issue: `Log Type` and `Log Entry` both contain specific implementation strings (literal tag values and on-disk format) that the SKILL.md rule prohibits outright. `Service Inventory` similarly embeds the actual service name list, which is code data, not a domain concept definition.

**Spec axis**: 2 findings. Worst issue: `Assertion` term is absent despite DM-05 explicitly identifying it as a gap. The `Service Inventory` accuracy against current source code is unverified.
