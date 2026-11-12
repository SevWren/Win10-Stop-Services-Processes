# 09: Move `$sProcesses[18]` to `#Region ;Configuration — Target lists`

**What to build:** Move the `$sProcesses[18]` declaration from `#Region ;Variables/Logging` (line 84 of `Stop Services Processes.au3`) into the existing `#Region ;Configuration — Target lists` block (lines 75–82), immediately after `$aSvcTargetNames[9]`. Add an "edit here" comment above the array matching the style already present for the service target list. This is a pure structural refactor — no variable rename, no caller changes, no logic changes.

**Blocked by:** None (pure structural refactor; no dependency on any open issue)

**Status:** ready-for-agent

---

## Background

CR2-38 (`docs/reviews/second-pass/CR2-38-config-region-audit.md`) identified two failures in Check 2 and Check 6:

- **Check 2 (FAIL):** `$sProcesses[18]` is declared at line 90 inside `#Region ;Variables/Logging`, a mixed-purpose region that also contains runtime state (`$bScriptRunning`, `$iLastStopServices`, `$iLastStopProcesses`), logging configuration, and the full log-file initialization block. The process target list is a user-editable configuration input, not runtime state.

- **Check 6 (PARTIAL PASS — process list FAIL):** The service target list at line 77 carries `; Edit here to add/remove service targets — do not modify _RunServiceBatchStop body.` The process target list has no equivalent directive; the comment at line 87 (`; Process inventory — processes closed every $PROC_POLL_INTERVAL_SEC seconds.`) is descriptive only. A user looking to add or remove process targets has no explicit signal that this is the correct edit point and that function bodies must not be touched.

The asymmetry is also documented as Candidate 1 in `docs/architecture-opportunities.md`:

> "The two inventory declarations are conceptually a single concern (what targets does the script suppress?) but they sit in different regions. Any future change to the Process Inventory — adding a process, removing one, or adjusting the duplicate `xgamehelper.exe` entry — requires navigating to the wrong region."

The fix concentrates configuration: after the move, `#Region ;Configuration — Target lists` is the single definition point for all suppression targets, and `#Region ;Variables/Logging` contains only runtime state.

---

## Acceptance Criteria

- [ ] `$sProcesses[18]` is declared inside `#Region ;Configuration — Target lists`, after `$aSvcTargetNames[9]` and before `#EndRegion`.
- [ ] All 18 entries are preserved exactly as-is, including the duplicate `"xgamehelper.exe"` at indices 15 and 16 (see BASELINE-INVENTORY.md — second close is a harmless no-op).
- [ ] An "edit here" comment appears directly above `$sProcesses[18]`, e.g.:
  ```autoit
  ; Edit here to add/remove process targets — do not modify _KillProcessList body.
  ```
- [ ] The existing descriptive comment (`; Process inventory — processes closed every $PROC_POLL_INTERVAL_SEC seconds.`) is preserved, either above or below the "edit here" comment.
- [ ] The duplicate-entry note (`; Note: "xgamehelper.exe" appears at index 15 and 16...`) is preserved alongside the declaration.
- [ ] `$sProcesses[18]` is removed from `#Region ;Variables/Logging` with no residual blank lines left in its place beyond normal spacing.
- [ ] `$sStringInstaller` and all remaining variables in `#Region ;Variables/Logging` are undisturbed.
- [ ] No caller changes are required — `$sProcesses` is already declared `Global` and all call sites reference it by name without regard to file position.
- [ ] AU3Check at `-q -d -w 1 -w 2 -w 3 -w 4` produces no new warnings (Windows-only gate; mark NOT RUN in environment where AutoIt is unavailable per blockers B-001/B-002/B-003).

---

## Tasks

- [ ] Read `Stop Services Processes.au3` lines 75–100 to confirm current state before editing.
- [ ] In `#Region ;Configuration — Target lists` (after the closing `]` of `$aSvcTargetNames[9]` and before `#EndRegion`), insert:
  - A blank separator line after `$aSvcTargetNames`.
  - The descriptive comment: `; Process Inventory: processes closed every $PROC_POLL_INTERVAL_SEC seconds.`
  - The "edit here" directive: `; Edit here to add/remove process targets — do not modify _KillProcessList body.`
  - The duplicate-entry note (preserve verbatim from current source).
  - The `Global $sProcesses[18] = [...]` declaration with all 18 entries preserved verbatim.
- [ ] Remove `$sProcesses[18]` and its associated comments from `#Region ;Variables/Logging`, leaving `$sStringInstaller` as the first declaration in that region.
- [ ] Verify by inspection that `$aSvcTargetNames[9]` and `$sProcesses[18]` are now adjacent peers inside the same `#Region ;Configuration — Target lists` block.
- [ ] Verify by inspection that no other region content was disturbed.
- [ ] Run AU3Check if on Windows; mark NOT RUN with environment note if in Linux sandbox.

---

## Source References

- Audit finding: `docs/reviews/second-pass/CR2-38-config-region-audit.md` §Check 2 and §Check 6
- Architecture analysis: `docs/architecture-opportunities.md` §Candidate 1
- Current declaration location: `Stop Services Processes.au3` line 90 (inside `#Region ;Variables/Logging`, line 84)
- Target region: `Stop Services Processes.au3` lines 75–82 (`#Region ;Configuration — Target lists`)
- Duplicate-entry rationale: `docs/BASELINE-INVENTORY.md` §Process Inventory

## Comments

*(none yet)*
