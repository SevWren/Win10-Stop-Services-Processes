# CR2-38 — Configuration Region Structure Audit

**File audited:** `Stop Services Processes.au3`
**Standards sources:** `CODING_STANDARDS.md`, `CLAUDE.md`, `docs/ARCHITECTURE.md` (not present in repo)
**Date:** 2026-11-12
**Reviewer:** Agent (second-pass)

---

## Audit Checklist

### Check 1 — `$aSvcTargetNames[9]` declared as `Global` in a config `#Region`

**Result: PASS**

`$aSvcTargetNames[9]` is declared at line 84 as `Global $aSvcTargetNames[9] = [...]` inside
`#Region ;Configuration — Target lists` (lines 80–87). The region is properly closed with a
labeled `#EndRegion` at line 87. This satisfies the T1-11 requirement that the array be a
module-level global rather than a function-local variable.

---

### Check 2 — `$sProcesses[18]` in a config region

**Result: FAIL**

`$sProcesses[18]` is declared at line 96 inside `#Region ;Variables/Logging` (lines 89–145).
This is a mixed-purpose region that also contains runtime state variables (`$bScriptRunning`,
`$iLastStopServices`, `$iLastStopProcesses`, `$iconfile`, `$iLogMaxAgeDays`, `$sLogFile`,
`$iLogLevel`, `$bLogToConsole`, `$PROCESS_IDLE`, the priority watchdog parallel arrays) and
the entire log-file initialization block (lines 124–144).

The process target list is a user-editable configuration input, comparable to
`$aSvcTargetNames`. Placing it in a generic `Variables/Logging` region:

- Buries it alongside runtime state that users should never edit.
- Breaks the symmetry with `$aSvcTargetNames`, which has its own dedicated
  `Configuration — Target lists` region.
- Makes it harder to locate at a glance when adding or removing process targets.

**Recommendation:** Extract `$sProcesses[18]` into a dedicated
`#Region ;Configuration — Target lists` section (or extend the existing one to cover both
target arrays), mirroring the structure of the service target list.

---

### Check 3 — Timing constants in a config region

**Result: PASS**

All four required timing constants are present and are the only declarations inside
`#Region ;Timing constants` (lines 39–48):

| Constant | Line | Value |
|---|---|---|
| `$MAIN_LOOP_SLEEP_MS` | 44 | 500 ms |
| `$PRIORITY_WATCHDOG_MS` | 45 | 10000 ms |
| `$SVC_BATCH_TIMEOUT_MS` | 46 | 20000 ms |
| `$SVC_BATCH_POLL_MS` | 47 | 500 ms |

Additional timing constants `$PROC_POLL_INTERVAL_SEC` (line 42) and `$SVC_POLL_INTERVAL_SEC`
(line 43) are also present, which is correct. The region is single-purpose and well-focused.

Minor issue: the `#EndRegion` at line 48 has no label (see Check 7).

---

### Check 4 — Log level/type constants in a config region

**Result: PASS**

All required log level and log type constants are present inside
`#Region ;Configuration — Log constants` (lines 50–65):

**Log level constants:**

| Constant | Line | Value |
|---|---|---|
| `$LOG_LEVEL_ERROR` | 54 | 0 |
| `$LOG_LEVEL_INFO` | 55 | 1 |
| `$LOG_LEVEL_VERBOSE` | 56 | 2 |

**Log type constants:**

| Constant | Line |
|---|---|
| `$LOG_TYPE_SYSTEM` | 60 |
| `$LOG_TYPE_PROCESS` | 61 |
| `$LOG_TYPE_SERVICE` | 62 |
| `$LOG_TYPE_PROCESS_PRIORITY` | 63 |
| `$LOG_TYPE_PRIORITY_WATCHDOG` | 64 |

Region is properly labeled and closed at line 65.

---

### Check 5 — AutoIt priority constants in a config region

**Result: PASS**

All six AutoIt priority constants are present inside
`#Region ;Configuration — AutoIt process priority constants` (lines 67–78):

| Constant | Line | Value |
|---|---|---|
| `$AUTOIT_PRIORITY_IDLE` | 72 | 0 |
| `$AUTOIT_PRIORITY_BELOW_NORMAL` | 73 | 1 |
| `$AUTOIT_PRIORITY_NORMAL` | 74 | 2 |
| `$AUTOIT_PRIORITY_ABOVE_NORMAL` | 75 | 3 |
| `$AUTOIT_PRIORITY_HIGH` | 76 | 4 |
| `$AUTOIT_PRIORITY_REALTIME` | 77 | 5 |

Region is properly labeled and closed at line 78. The inline comments cross-referencing the
DM-02 proposal are present and correct.

---

### Check 6 — "Edit here" comment in service/process target list regions

**Result: PARTIAL PASS — service list PASS, process list FAIL**

**Service target list (line 82):**
> `; Edit here to add/remove service targets — do not modify _RunServiceBatchStop body.`

This is present and effective. It directs the user to the correct edit point and explicitly
warns against editing the downstream function body. PASS.

**Process target list (`$sProcesses[18]`, lines 93–100):**
The comment at line 93 reads:
> `; Process inventory — processes closed every $PROC_POLL_INTERVAL_SEC seconds.`

This is a description, not an "edit here" directive. There is no instruction equivalent to
the service list's `; Edit here to add/remove...` guidance. A user looking to modify the
process kill list has no explicit signal that this is the correct edit point and that
function bodies should not be touched. FAIL.

**Recommendation:** Add an "edit here" comment directly above `$sProcesses[18]`, e.g.:
```autoit
; Edit here to add/remove process targets — do not modify _KillProcessList body.
```

---

### Check 7 — All config regions properly labeled with `#EndRegion`

**Result: PARTIAL FAIL — one unlabeled `#EndRegion`**

| Region label (`#Region`) | Line | `#EndRegion` | Line | Labeled? |
|---|---|---|---|---|
| `;**** Directives created by AutoIt3Wrapper_GUI ****` | 2 | `#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****` | 11 | Yes |
| `;Includes/Options/Permissions` | 14 | `#EndRegion ;Includes/Options/Permissions` | 30 | Yes |
| `;hotkeys` | 32 | `#EndRegion` | 37 | **No** |
| `;Timing constants` | 39 | `#EndRegion` | 48 | **No** |
| `;Configuration — Log constants` | 50 | `#EndRegion` | 65 | **No** |
| `;Configuration — AutoIt process priority constants` | 67 | `#EndRegion` | 78 | **No** |
| `;Configuration — Target lists` | 80 | `#EndRegion` | 87 | **No** |
| `;Variables/Logging` | 89 | `#EndRegion ;Variables/Logging` | 145 | Yes |
| `;traytips` | 600 | `#EndRegion ;traytips` | 616 | Yes |

Five of nine `#EndRegion` markers are bare (unlabeled). This is not a functional defect —
AutoIt does not require labels — but it reduces readability in the SciTE code-folding view
and makes it harder to match opening and closing markers in a plain-text diff.

The bare markers at lines 37, 48, 65, 78, and 87 all correspond to config or structural
regions. Adding matching labels (e.g., `#EndRegion ;Timing constants`) would bring these
into alignment with the labeled style used for the two longest regions (`Variables/Logging`
and `traytips`).

---

## Summary

| # | Check | Result |
|---|---|---|
| 1 | `$aSvcTargetNames[9]` declared Global in config region | PASS |
| 2 | `$sProcesses[18]` in a config region | **FAIL** |
| 3 | Timing constants in config region | PASS |
| 4 | Log level/type constants in config region | PASS |
| 5 | AutoIt priority constants in config region | PASS |
| 6 | "Edit here" comment in target list regions | PARTIAL PASS (service: yes; process: no) |
| 7 | All config regions labeled with `#EndRegion` | PARTIAL FAIL (5 of 9 unlabeled) |

**Actionable items in priority order:**

1. **(High)** Move `$sProcesses[18]` out of `#Region ;Variables/Logging` into a dedicated
   configuration region, either by extending the existing
   `#Region ;Configuration — Target lists` block or creating a sibling block. This is the
   structural mirror of the work done for `$aSvcTargetNames` in T1-11.

2. **(Medium)** Add an `; Edit here to add/remove process targets...` comment above
   `$sProcesses[18]`, matching the guidance style of the service target list.

3. **(Low)** Label the five bare `#EndRegion` markers at lines 37, 48, 65, 78, and 87 to
   match the style of the labeled regions.
