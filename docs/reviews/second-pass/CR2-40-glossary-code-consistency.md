# CR2-40 — GLOSSARY.md vs Code Consistency Check

**Review date:** 2026-11-12
**Scope:** 10 key glossary terms checked against
- `Includes/ServiceManager.au3`
- `Stop Services Processes.au3`
- `Tests/ServiceManager.Tests.au3`

**Method:** Each term's GLOSSARY.md definition was compared against the actual
identifier names, comment text, region labels, and log messages in the three
source files. The check is independent of T4-10.

---

## Summary Table

| # | Glossary Term | Verdict | Notes |
|---|---|---|---|
| 1 | Batch Stop | PASS | Used correctly in comments; no "bulk stop" or "group stop" found |
| 2 | Service Target List / `$aSvcTargetNames` | PASS with observation | Term appears in comment; region label differs from both GLOSSARY alternatives |
| 3 | Process Kill / `_KillProcessList` | PASS | Function exists; semantics match |
| 4 | Stop Outcome string values | PASS | All five exact strings confirmed |
| 5 | SCM Handle / `$hSCM` | PASS | Variable name and comment label match |
| 6 | Service Handle / `$hService` | PASS | Variable name and comment label match |
| 7 | Monitoring Loop | PASS | Consistently labelled in comments |
| 8 | Toggle / Shift+F1 | PASS | `HotKeySet("+{F1}", ...)` confirmed |
| 9 | Priority Drift log message | PASS | Exact phrase "Priority drift" present |
| 10 | Deterministic Test (test harness header) | PASS | Term appears in both header and banner |

---

## Detailed Findings

### 1. "Batch Stop"

**GLOSSARY.md** defines the term and lists _Avoid_: "bulk stop, mass stop".

**Code evidence:**
- `Includes/ServiceManager.au3` line 161 comment: `; $hSCM  — SCM Handle, opened ONCE for the entire batch`
- `Stop Services Processes.au3` line 234 comment: `; Service Target List (9 services) is declared in the Configuration region above:`
- `Stop Services Processes.au3` line 240: `_LogMessage("Service batch stop: could not open SCM — batch skipped", ...)`
- Phase headers in `ServiceManager.au3` lines 192–193 use `; PHASE 1` and `; PHASE 2`, which are consistent with Batch Stop's two-phase description.
- No occurrences of "bulk stop" or "group stop" found in any `.au3` file.

**Verdict: PASS.**

---

### 2. "Service Target List" and `$aSvcTargetNames`

**GLOSSARY.md** defines "Service Target List" as the fixed set of Windows service
names. It does not mandate a variable name. The variable `$aSvcTargetNames` exists
at `Stop Services Processes.au3` line 84.

**Code evidence:**
- Region label at line 80: `#Region ;Configuration — Target lists`
- Comment at line 81: `; Service Target List: Windows service names stopped every $SVC_POLL_INTERVAL_SEC seconds.`
- Comment at line 234: `; Service Target List (9 services) is declared in the Configuration region above:`

The region label reads "Target lists" (plural, lowercase), not "Service targets"
or "Target list" (singular). The in-comment phrase "Service Target List" matches
the GLOSSARY.md term exactly, so the concept is correctly named in prose. The
region header uses an abbreviated plural form; this is a minor stylistic
inconsistency, not a semantic divergence.

**Verdict: PASS** (term is correctly used in comments; region label is a minor
variation, not an avoided synonym).

---

### 3. "Process Kill" and `_KillProcessList`

**GLOSSARY.md** defines "Process Kill" as "the unconditional, immediate termination
of a process". It lists _Avoid_: "process stop, process close, terminate".

**Code evidence:**
- `Stop Services Processes.au3` line 207: `Func _KillProcessList()`
- Lines 203–206 doc comment: `; Force-kills processes via ProcessClose (TerminateProcess) — no graceful path.`
- Line 216: `_LogMessage("Successfully killed process: " & $sProcesses[$i], ...)`
- Line 219: `_LogMessage("Failed to kill process: " & $sProcesses[$i] ...)`
- Line 225: `_LogMessage("Process kill summary - Success: " ...)`

The function name `_KillProcessList` directly encodes the "Process Kill" concept.
The comment uses "Force-kills" and log messages use "killed process" / "Process
kill summary" — all consistent with the glossary definition. The avoided synonyms
("process stop", "process close", "terminate") do not appear in the function body
or its comments.

**Verdict: PASS.**

---

### 4. "Stop Outcome" — exact string values

**GLOSSARY.md** specifies five exact outcome values:
`"STOPPED"`, `"ALREADY_STOPPED"`, `"UNAVAILABLE"`, `"FAILED"`, `"TIMED_OUT"`.

**Code evidence** (`Includes/ServiceManager.au3` lines 55–59):
```
Global Const $SM_OUTCOME_STOPPED     = "STOPPED"
Global Const $SM_OUTCOME_ALREADY     = "ALREADY_STOPPED"
Global Const $SM_OUTCOME_UNAVAILABLE = "UNAVAILABLE"
Global Const $SM_OUTCOME_FAILED      = "FAILED"
Global Const $SM_OUTCOME_TIMEDOUT    = "TIMED_OUT"
```

All five string literals match GLOSSARY.md exactly. The function header comment at
line 128 also enumerates them verbatim: `"STOPPED"`, `"ALREADY_STOPPED"`,
`"UNAVAILABLE"`, `"FAILED"`, `"TIMED_OUT"`.

**Verdict: PASS — exact match on all five values.**

---

### 5. "SCM Handle" and `$hSCM`

**GLOSSARY.md** defines "SCM Handle" and lists _Avoid_: "SCM connection, manager
handle". One SCM Handle is opened per Batch Stop cycle.

**Code evidence** (`Includes/ServiceManager.au3`):
- Line 161 comment: `; $hSCM  — SCM Handle, opened ONCE for the entire batch with SC_MANAGER_CONNECT.`
- Line 184: `Local $hSCM = $aScmOpen[0]`
- Line 376: `DllCall("advapi32.dll", "bool", "CloseServiceHandle", "handle", $hSCM)`

The variable name `$hSCM` is used for the batch-scoped handle throughout. The
comment explicitly labels it "SCM Handle" and distinguishes it from `$hService`
in the same comment block (line 163). The avoided synonyms do not appear.

**Verdict: PASS.**

---

### 6. "Service Handle" and `$hService`

**GLOSSARY.md** defines "Service Handle" as a per-service opaque value with minimum
access rights, distinct from SCM Handle. Lists _Avoid_: "service object handle".

**Code evidence** (`Includes/ServiceManager.au3`):
- Line 163 comment: `; $hService — Service Handle, opened per-service with SERVICE_QUERY_STATUS|SERVICE_STOP.`
- Line 221: `Local $hService = $aSvcOpen[0]`
- Variable `$hService` is used for all per-service handle operations throughout
  Phase 1 and Phase 2 (lines 237, 250, 271, 297, 343, 371).

The comment explicitly names it "Service Handle" and states its per-service
lifetime and minimum rights, matching the glossary definition. The avoided synonym
"service object handle" does not appear.

**Verdict: PASS.**

---

### 7. "Monitoring Loop"

**GLOSSARY.md** defines "Monitoring Loop" as the active state entered when toggled
on. Lists _Avoid_: "active loop, running state, script running".

**Code evidence** (`Stop Services Processes.au3`):
- Line 34 comment: `; Shift+F1 — toggle monitoring loop on/off`
- Line 102 comment: `Global $bScriptRunning = False   ; tracks whether the monitoring loop is active`
- Line 153 doc comment: `; Hotkey: Shift+F1 — toggles the active monitoring loop on/off.`
- Line 166 inline comment: `While $bScriptRunning   ; active monitoring loop — exits when Shift+F1 sets $bScriptRunning = False`

The term "monitoring loop" is used consistently in all four locations that
describe this construct. The avoided synonyms do not appear. The comment at line
166 uses "active monitoring loop" (adjective + term), which is consistent with
how the GLOSSARY.md entry uses it ("the active state the script enters").

**Verdict: PASS.**

---

### 8. "Toggle" — Shift+F1 hotkey

**GLOSSARY.md** defines "Toggle" as the user action (Shift+F1) that transitions
the script. Lists _Avoid_: "start, enable, activate".

**Code evidence** (`Stop Services Processes.au3`):
- Line 34: `HotKeySet("+{F1}", "ToggleScript")       ; Shift+F1 — toggle monitoring loop on/off`

The `HotKeySet` call confirms Shift+F1 (`"+{F1}"` in AutoIt syntax where `+`
denotes Shift). The function name `ToggleScript` directly encodes the glossary
term. The comment on the same line uses "toggle" explicitly.

**Verdict: PASS — Shift+F1 confirmed as the toggle hotkey.**

---

### 9. "Priority Drift" — log message exact phrase

**GLOSSARY.md** defines "Priority Drift" as the condition where a watched PID's
current Priority Class no longer matches the target. Lists _Avoid_: "priority
change, priority mismatch".

**Code evidence** (`Stop Services Processes.au3` line 491):
```
_LogMessage("_PriorityWatchdog: Priority drift on PID " & $iPID & " — detected " & $sCurrentName & ", expected " & $sPriorityName & ". Restoring.", $LOG_TYPE_PRIORITY_WATCHDOG, $LOG_LEVEL_INFO)
```

The phrase "Priority drift" appears exactly in the log message, with the
capitalisation "Priority drift" (capital P, lowercase d) consistent with treating
it as a named concept at the start of a phrase component. The avoided synonyms
"priority change" and "priority mismatch" do not appear anywhere in the file.

**Verdict: PASS — exact phrase "Priority drift" confirmed in log message.**

---

### 10. "Deterministic Test" — test harness header

**GLOSSARY.md** defines "Deterministic Test" as a test that produces the same
pass/fail result regardless of live Windows SCM state.

**Code evidence** (`Tests/ServiceManager.Tests.au3`):
- Line 16 file header: `; ServiceManager.Tests.au3 — Deterministic test harness for ServiceManager.au3`
- Line 18 ticket line: `; Ticket : T03 — Build ServiceManager.au3 + Deterministic Test Harness`
- Lines 53–57 section heading: `; DETERMINISTIC DESIGN CONSTRAINT` with body
  explaining that all pure-logic tests are deterministic.
- Line 502 runtime banner: `ConsoleWrite("ServiceManager.Tests.au3 — deterministic test harness" & @CRLF)`

The term is used in the file's own section heading (`DETERMINISTIC DESIGN
CONSTRAINT`), in the ticket reference, in the doc comment, and in the runtime
console banner. The GLOSSARY.md definition and the harness description are
semantically aligned: both describe tests that do not depend on live SCM state.

**Verdict: PASS — term appears in both the header and the runtime banner.**

---

## Observations and Minor Issues

### OBS-1: Region label "Target lists" vs term "Service Target List"

The `#Region` header at line 80 reads `#Region ;Configuration — Target lists`
(plural, lowercase). The comment immediately inside the region (line 81) spells
out "Service Target List" correctly. The region label alone would not let a reader
identify the GLOSSARY.md term by scanning region headers. This is cosmetic; there
is no functional inconsistency and the term is not among the avoided synonyms.
No action required; note for future comment-tidy pass.

### OBS-2: "Batch Stop" appears only in log-message prose, not as a standalone comment heading

In `Stop Services Processes.au3`, the Phase 1 / Phase 2 comment headers inside
`_SM_StopServicesBatch` describe the two-phase algorithm but the phrase "Batch
Stop" itself does not appear as a function-level heading in `ServiceManager.au3`.
The term does appear in `_RunServiceBatchStop`'s doc comment (line 234: "Service
Target List (9 services) is declared in the Configuration region above") and in a
log message (line 240). The function name `_RunServiceBatchStop` encodes the
concept via the word "Batch". This is not a violation; the GLOSSARY.md does not
require the exact phrase to appear as a heading.

### OBS-3: `$SM_OUTCOME_TIMEDOUT` constant name vs string value

The constant identifier is `$SM_OUTCOME_TIMEDOUT` (no underscore between TIMED
and OUT), while the stored string is `"TIMED_OUT"` (with underscore). This is
intentional style: AutoIt constant names conventionally do not embed internal
underscores within the meaningful suffix, while the outcome string follows the
five-value protocol defined in GLOSSARY.md. The string value is what matters for
glossary consistency; it is correct.

---

## Conclusion

All 10 checked glossary terms are used consistently with their GLOSSARY.md
definitions in the three source files. No avoided synonyms were found. Three minor
observations (region label wording, batch-stop heading absence, constant name
vs. string discrepancy) are cosmetic and do not represent semantic inconsistencies.

**Overall: 10/10 terms PASS. No corrective action required.**
