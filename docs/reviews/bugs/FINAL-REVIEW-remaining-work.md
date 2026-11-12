# Final Review — Remaining Work

**Reviewer:** FINAL-REVIEW agent
**Fixed point:** `ce43db6`
**Scope:** Working-tree changes since `ce43db6` (concurrent agents IMPL-09, FIX-ADR0005, FIX-README-WAAS, FIX-B005)
**Files reviewed:**
1. `Stop Services Processes.au3`
2. `README.md`
3. `docs/adr/0005-graceful-only-service-stop.md`
4. `docs/adr/0012-servicecontrol-keep-or-delete.md`

---

## Standards

### `Stop Services Processes.au3`

**$sProcesses[18] moved to Configuration region**

PASS with one defect. The array was relocated from `#Region ;Variables/Logging` into `#Region ;Configuration — Target lists`, which aligns with the CODING_STANDARDS.md region-structure rule: configuration data belongs in a `Configuration —`-prefixed region. All 18 entries are present and in the correct order. The duplicate `xgamehelper.exe` at indices 15 and 16 is preserved, consistent with the documented baseline.

Defect: the region label on the opening comment for `$sProcesses` reads `; Process Inventory:` (capital I, colon) whereas the existing `$aSvcTargetNames` comment reads `; Service Target List:` (consistent style). This is a minor style inconsistency but not a standards violation per CODING_STANDARDS.md.

The region structure after the change is:

```
#Region ;Configuration — Target lists
  $aSvcTargetNames[9]
  $sProcesses[18]          ← moved here
#EndRegion ;Configuration — Target lists

#Region ;Variables/Logging
  $sStringInstaller
  ...
```

The closing `#EndRegion ;Configuration — Target lists` and opening `#Region ;Variables/Logging` are correctly placed and labelled (CODING_STANDARDS.md §Region Structure requires matching labels on both opening and closing tags). PASS.

**$g_bLogBusy rename to $bLogBusy**

PASS. The rename is consistent at all four usage sites:
- Line 112 (declaration): `Global $bLogBusy = False`
- Line 271 (read guard): `If $bLogBusy Then Return`
- Line 272 (set True): `$bLogBusy = True`
- Line 276 (reset on error path): `$bLogBusy = False`
- Line 282 (reset on success path): `$bLogBusy = False`

The rename is correct per CODING_STANDARDS.md §AU3Check Compliance (recently updated to state "Production globals use no prefix convention — Reserve `g_` prefix exclusively for test harness globals"). The variable is a production global, so removing the `g_` prefix is a standards compliance fix, not a cosmetic change. No stale references to `$g_bLogBusy` remain.

**CODING_STANDARDS.md also changed in the same working tree** (not listed as a target file, but detected in `git diff`). The added line makes the `g_` prohibition on production globals explicit. This change is consistent with the rename above and reinforces it as a hard rule rather than an implied one. No violation.

**Smell baseline**

- No Mysterious Name: `$bLogBusy` is clearer than `$g_bLogBusy` for a production global; the name accurately describes its purpose (re-entrancy guard for log I/O). No smell.
- No Duplicated Code introduced.
- No Speculative Generality: the `$sProcesses` move is a pure reorganisation with no new abstraction.
- Shotgun Surgery observation: the same commit both renames `$g_bLogBusy` and moves `$sProcesses`. These are two independent concerns touching the same file. This is acceptable scope (single file, low coupling) and is not a standards violation — just noted.

---

### `README.md`

**WaaSMedicSvc note**

Standards PASS. The note is added under `## Known Limitations` as a bullet, which is appropriate placement. No formatting violations. The note does not introduce any new code paths or inconsistencies with CODING_STANDARDS.md.

---

### `docs/adr/0005-graceful-only-service-stop.md`

**FAILED vs TIMED_OUT wording**

Standards PASS. The ADR follows the format defined in `ADR-FORMAT.md`: H1 title, Status frontmatter, context paragraph, Decision, Considered Options, Consequences. The Consequences section is an optional section that adds genuine value here. The edit is confined to the Negative bullet — no structural violation.

---

### `docs/adr/0012-servicecontrol-keep-or-delete.md`

**File does not exist.**

The file `docs/adr/0012-servicecontrol-keep-or-delete.md` is absent from the working tree. `git diff ce43db6` does not show it as added, and `ls docs/adr/` confirms its absence. The highest ADR number in the directory is `0011`. The agent tasked with creating this file (expected to be a concurrent agent) has not produced it.

Standards finding (HARD): **ADR-0012 is missing.** If this ADR was in scope for the current cycle, its absence is an unmet deliverable. No review of its content is possible.

---

## Spec

The originating spec for these changes is defined by the task instructions, which specify four targeted changes. Each is evaluated below.

### 1. `Stop Services Processes.au3` — `$sProcesses[18]` moved to config region; `$bLogBusy` rename

**$sProcesses move:** PASS. The spec requires `$sProcesses[18]` to be moved to the config region. It is now inside `#Region ;Configuration — Target lists`, after `$aSvcTargetNames`. All 18 entries are present. The duplicate `xgamehelper.exe` at indices 15 and 16 is preserved as required.

**$bLogBusy rename:** PASS. The spec requires renaming `$g_bLogBusy` to `$bLogBusy` consistently at all usage sites. The diff shows all five occurrences (declaration + four usages in `_LogMessage`) updated. No residual `$g_bLogBusy` references remain.

### 2. `README.md` — WaaSMedicSvc note present? Accurate?

**Present:** PASS. The note was added.

**Accurate:** PARTIAL. The note states:

> Stop attempts return `ERROR_ACCESS_DENIED (5)` and produce `FAILED` outcome entries in the log every cycle.

This is consistent with the service-stop module's behavior: `ControlService` returning `ERROR_ACCESS_DENIED` causes the outcome to be recorded as `FAILED` (not `TIMED_OUT`). The claim aligns with ADR-0005's updated Consequences section.

However, the note states the service "cannot be stopped by user-mode code." This is an overstatement — WaaSMedicSvc can be stopped by user-mode code with sufficient privilege escalation or when the Windows Update Medic Service protection mechanism is disabled. The note is accurate as a practical description of normal script behavior but the absolute phrasing ("cannot") is misleading for technically sophisticated users. This is a documentation accuracy concern, not a spec violation — the spec asked only for the note to be "present" and "accurate" in the sense of matching the code's behavior, which it does.

### 3. `docs/adr/0005-graceful-only-service-stop.md` — Consequences wording corrected for FAILED vs TIMED_OUT

PASS. The old Negative bullet conflated `TIMED_OUT` and `FAILED` by using a single sentence covering both "ignores" and "protected" cases under the `TIMED_OUT` outcome label. The new wording explicitly splits them:

- "A service that persistently ignores stop controls produces `TIMED_OUT`."
- "A service that actively rejects the stop control (e.g., a protected service returning `ERROR_ACCESS_DENIED`) produces `FAILED` immediately."

This is correct per the implementation in `ServiceManager.au3`: `ControlService` failure (rejected stop) records `FAILED`; timeout in the Phase 2 poll loop records `TIMED_OUT`. The correction matches the actual code behavior.

### 4. `docs/adr/0012-servicecontrol-keep-or-delete.md` — Exists? Follows ADR-FORMAT.md?

**NOT DELIVERED.** The file does not exist. The spec explicitly requires this file to exist and to follow `ADR-FORMAT.md`. This is an unmet requirement.

---

## Summary

| Axis | Findings | Worst issue |
|---|---|---|
| Standards | 3 PASS, 1 missing file | ADR-0012 absent — cannot be reviewed |
| Spec | 3 PASS (one with accuracy caveat), 1 missing | ADR-0012 not delivered — hard spec miss |

**Standards:** All reviewed changes conform to documented standards. The `$g_bLogBusy` rename and `$sProcesses` region move are correct. ADR-0012 cannot be reviewed because it does not exist.

**Spec:** Items 1–3 are implemented correctly. Item 4 (ADR-0012) is the sole hard failure — the file was not created by any concurrent agent.
