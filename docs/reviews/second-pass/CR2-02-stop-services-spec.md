# CR2-02 — Stop Services Processes.au3 — Second-Pass Review

**File:** `Stop Services Processes.au3`
**Fixed point:** `ab5b012`
**Diff command:** `git diff ab5b012...HEAD -- "Stop Services Processes.au3"`
**Commits in range:**
```
1d8a5ea feat: replace broken service-stop path with native SCM batch-stop module
2a62801 chore(cleanup)
09b99ba Added claude skill sets
```
**Spec sources:** `docs/REQUIREMENTS.md`, `.scratch/service-manager-migration/issues/04-integration.md`
**Standards sources:** `CODING_STANDARDS.md`, `CLAUDE.md`

> Note: the diff covers all three commits. The first commit produced the intermediate state shown in
> the raw diff. The second commit ("chore(cleanup)") substantially reworked the file further —
> renaming functions, introducing named log-level and log-type constants, and extracting a
> configuration region. This review is against **HEAD**, which is the final state of all three commits.

---

## Standards

### STD-S1 — Old function names still present in HEAD (Mysterious Name + documented naming convention)

`CLAUDE.md` and `CODING_STANDARDS.md` both specify the naming convention for private helpers:
`_UnderscorePascalCase`. The ask in the focused review brief was whether the old names
`_miscpopups`, `_CloseInstaller`, and `CheckElapsedTime` (without underscore) remain.

In HEAD:

- `_miscpopups` is **gone** — renamed to `_MiscPopups` (line 623). **Pass.**
- `_CloseInstaller` is **gone** — renamed to `_KillProcessList` (line 207). **Pass.**
- `CheckElapsedTime` (bare, no underscore) is **gone** — renamed to `_CheckElapsedTime` (line 291). **Pass.**

No old names survive. The focused brief's name checks all clear.

### STD-S2 — Bare integer literals passed to `_LogMessage` (Primitive Obsession / Mysterious Name)

The focused brief asks whether any bare integer literals remain as the `$iLevel` argument to
`_LogMessage`. In HEAD, every `_LogMessage` call uses named constants (`$LOG_LEVEL_ERROR`,
`$LOG_LEVEL_INFO`, `$LOG_LEVEL_VERBOSE`). **No bare integers remain.** Pass.

One related bare integer survives elsewhere — `AdlibRegister("_ClearTrayNotify", 2000)` at
line 609. The 2000 ms tooltip display duration is not covered by any timing constant in the
configuration region. This is a judgement-call smell (Primitive Obsession): the value is
non-obvious and undocumented at the call site. No repo standard explicitly requires a named
constant for `AdlibRegister` intervals; this is a minor baseline finding only.

### STD-S3 — `_KillProcessList` kill-semantics comment

The focused brief asks whether `_KillProcessList` has the required kill-semantics comment.
Lines 202–206:

```autoit
; Func _KillProcessList
; Force-kills processes via ProcessClose (TerminateProcess) — no graceful path.
; Terminates every process named in $sProcesses[]. Called every $PROC_POLL_INTERVAL_SEC.
; Ref: docs/domain-modeling/proposals/DM-03-stop-terminate-semantics.md §2.2
```

The comment explicitly states "Force-kills ... TerminateProcess — no graceful path." **Pass.**

### STD-S4 — Shotgun Surgery

The focused brief identifies Shotgun Surgery as a targeted smell. The service-stop migration
required coordinated changes to `Stop Services Processes.au3` and `Includes/ServiceManager.au3`
(plus `Includes/ServiceControl.au3` disposition). That two-file spread is an inherent consequence
of integrating a new module; it is not evidence of a module-boundary problem. No shotgun surgery
finding.

### STD-S5 — Duplicated Code

The focused brief identifies Duplicated Code as a targeted smell. In HEAD the diff removed all
duplicate `#include` and `HotKeySet` pairs. No duplicated logic shapes appear in the new hunks
(the `_RunServiceBatchStop` Select block handles all five outcome codes once; `_KillProcessList`
loops once). **No finding.**

### STD-S6 — `$PROCESS_IDLE` declared alongside `$AUTOIT_PRIORITY_IDLE` (Duplicated Code / Primitive Obsession)

Line 113 declares `Global Const $PROCESS_IDLE = 0` as a compatibility shim ("not defined in this
AutoIt version's AutoItConstants.au3"). Lines 72–77 introduce a full set of
`$AUTOIT_PRIORITY_*` constants, including `$AUTOIT_PRIORITY_IDLE = 0`. The two constants carry
the same value and the same domain meaning (AutoIt idle priority). `$PROCESS_IDLE` is not
referenced anywhere in the diff-range code — `$AUTOIT_PRIORITY_IDLE` is used at lines 429 and
561. The shim is now a dead declaration that duplicates `$AUTOIT_PRIORITY_IDLE` (value = 0).
Judgement-call: low-risk dead code, but the duplication is real. The fix would be to delete line
113 and confirm AU3Check passes without it.

### STD-S7 — `_MiscPopups` name does not match `CLAUDE.md` active-monitoring-loop description

`CLAUDE.md` architectural description names the function `_miscpopups()`. The rename to
`_MiscPopups` is consistent with `_UnderscorePascalCase` naming and is therefore an improvement;
AutoIt is case-insensitive so there is no runtime break. This is not a violation — it is a
positive alignment with the stated convention. No finding.

### STD-S8 — `ConsoleWrite` calls outside `_LogMessage` in production code

`CODING_STANDARDS.md`: "Direct `ConsoleWrite` calls outside of initialization/debug code are NOT
permitted." The log-initialization block (lines 121–144) uses `ConsoleWrite` exclusively, which
the standard's own "initialization/debug code" exception covers. No new `ConsoleWrite` calls were
introduced in function bodies by the diff. **Pass.**

---

## Spec

### Integration issue-04 checklist

**SP-1 — `_RunServiceBatchStop` calls `_SM_StopServicesBatch` (not `_stopservicescustom`)**

Line 238: `Local $aResults = _SM_StopServicesBatch($aSvcTargetNames, $SVC_BATCH_TIMEOUT_MS, $SVC_BATCH_POLL_MS)`

`_stopservicescustom` is absent from HEAD entirely. **Pass.**

**SP-2 — Service target list is in the config region**

Issue-04 checklist item: "Replace `_stopservicescustom()` body with `_RunServiceBatchStop()` call." The spec implies the
service list should be accessible to maintainers. In HEAD, lines 80–87 define a dedicated
`#Region ;Configuration — Target lists` block:

```autoit
Global $aSvcTargetNames[9] = [ _
    "FDResPub", "fdPHost", "TrustedInstaller", "wuauserv", _
    "UsoSvc", "DoSvc", "WaaSMedicSvc", "SSDPSRV", "sppsvc"]
```

The function body comment at line 234 explicitly says "edit there to add/remove targets."
**Pass.**

**SP-3 — Correct 9-service inventory (REQ-010)**

`docs/REQUIREMENTS.md` REQ-010 canonical list: `FDResPub`, `fdPHost`, `TrustedInstaller`,
`wuauserv`, `UsoSvc`, `DoSvc`, `WaaSMedicSvc`, `SSDPSRV`, `sppsvc`. HEAD `$aSvcTargetNames`
matches exactly. **Pass.**

**SP-4 — All 4 hotkeys preserved**

Issue-04: "Preserve all 4 hotkeys." Lines 33–36:

```autoit
HotKeySet("{ScrollLock}{PAUSE}", "_exit")
HotKeySet("+{F1}", "ToggleScript")
HotKeySet("+^9", "SetProcessPriority")
HotKeySet("^!+9", "LockProcessPriority")
```

All four present, no duplicates. **Pass.**

**SP-5 — Named timing constants added**

Issue-04 checklist: "Add named timing constants (PROC_POLL_INTERVAL_SEC, SVC_POLL_INTERVAL_SEC, etc.)."
Lines 42–47 declare `$PROC_POLL_INTERVAL_SEC`, `$SVC_POLL_INTERVAL_SEC`, `$MAIN_LOOP_SLEEP_MS`,
`$PRIORITY_WATCHDOG_MS`, `$SVC_BATCH_TIMEOUT_MS`, `$SVC_BATCH_POLL_MS`. **Pass.**

**SP-6 — Service polling interval at 10 s (REQ-013)**

`$SVC_POLL_INTERVAL_SEC = 10` at line 43; used at line 171. **Pass.**

**SP-7 — Relative include paths (REQ-014)**

Lines 18–20: `#include "Includes\ServiceControl.au3"` and `#include "Includes\ServiceManager.au3"`.
Line 4: `#AutoIt3Wrapper_Outfile_x64=.\release\Stop Services - Processes.exe`. **Pass.**

**SP-8 — Duplicate `#include` and `HotKeySet` entries removed (REQ-012)**

No duplicates present in HEAD. **Pass.**

**SP-9 — `Global $iLastStopProcesses = 0` declared (REQ-011)**

Line 104: `Global $iLastStopProcesses = 0`. **Pass.**

**SP-10 — Per-service outcome logging (issue-04 checklist)**

Issue-04: "Log each `_SM` result row outcome at appropriate log level." Lines 248–261 in
`_RunServiceBatchStop` log all five `$SM_OUTCOME_*` cases plus an Else guard. **Pass.**

**SP-11 — Intra-batch poll and deadline constants (REQ-015, REQ-016)**

`$SVC_BATCH_POLL_MS = 500` (line 47) and `$SVC_BATCH_TIMEOUT_MS = 20000` (line 46) are declared
and passed through to `_SM_StopServicesBatch` at line 238. **Pass.**

**SP-12 — README.md not updated (open item from issue-04)**

Issue-04 status block explicitly records: "README.md was not updated despite being a checklist
requirement." This was flagged as open in issue-04 and confirmed by CR-10 (SP-05, MINOR). No
change to README.md is visible in the diff. This remains unresolved per the issue checklist.
**Fail (pre-existing open item, not introduced by this diff).**

---

## Summary

**Standards:** 2 findings.
- STD-S2 (bare integer in `AdlibRegister("_ClearTrayNotify", 2000)`) — judgement call, Primitive Obsession, minor.
- STD-S6 (`$PROCESS_IDLE` dead declaration duplicates `$AUTOIT_PRIORITY_IDLE`) — judgement call, Duplicated Code / dead code, minor. Worst Standards issue.

All focused-brief checks pass: no bare integers in `_LogMessage`, no old function names (`_miscpopups`, `_CloseInstaller`, `CheckElapsedTime`), and `_KillProcessList` has the required kill-semantics comment.

**Spec:** 1 finding.
- SP-12 (README.md not updated) — pre-existing open item carried from issue-04/CR-10; not introduced by this diff. All 11 integration checklist items otherwise satisfied. Worst Spec issue.
