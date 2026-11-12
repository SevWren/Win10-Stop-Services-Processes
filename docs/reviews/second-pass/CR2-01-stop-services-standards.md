# CR2-01 — Stop Services Processes.au3 — Second-Pass Code Review

**File reviewed**: `Stop Services Processes.au3`
**Fixed point**: `HEAD` (committed diff reviewed via `git diff HEAD -- "Stop Services Processes.au3"`)
**Spec sources**: `docs/REQUIREMENTS.md` REQ-010 through REQ-014
**Standards sources**: `CODING_STANDARDS.md`, `CLAUDE.md`
**Standards axis focus**: Naming conventions, constant usage (`$LOG_LEVEL_*`, `$LOG_TYPE_*`, `$AUTOIT_PRIORITY_*`), config region structure, `#Region` labels
**Spec axis focus**: REQ-010 through REQ-014 compliance, service target list location, all 9 service names, 10-second poll interval

---

## Standards

### STD-01 — `#Region ;hotkeys` missing closing label (Hard violation)

**Standard**: `CLAUDE.md` "Region Structure" and general `#Region`/`#EndRegion` consistency. Every opening `#Region ;Label` should be closed by a matching `#EndRegion ;Label` for readability and reviewer traceability.

**Location**: Line 32–37

```autoit
#Region ;hotkeys
HotKeySet("{ScrollLock}{PAUSE}", "_exit")
...
#EndRegion
```

The `#EndRegion` on line 37 has no label. All other regions in the diff close with a matching label (e.g., `#EndRegion ;Includes/Options/Permissions`, `#EndRegion ;Variables/Logging`, `#EndRegion ;traytips`). This region is inconsistent and was not addressed by the diff.

**Fix**: Change to `#EndRegion ;hotkeys`.

---

### STD-02 — `#Region ;Timing constants` and `#Region ;Configuration — Log constants` / `#Region ;Configuration — AutoIt process priority constants` / `#Region ;Configuration — Target lists` missing closing labels (Hard violation)

**Standard**: Same region label symmetry requirement as STD-01.

**Location**: Lines 39–48, 50–65, 67–78, 80–87

All four newly introduced `#Region` blocks (added in this diff) close with bare `#EndRegion` without a matching label:

```autoit
#Region ;Timing constants
...
#EndRegion            ← no label

#Region ;Configuration — Log constants
...
#EndRegion            ← no label

#Region ;Configuration — AutoIt process priority constants
...
#EndRegion            ← no label

#Region ;Configuration — Target lists
...
#EndRegion            ← no label
```

The only correctly labelled close in the file is `#EndRegion ;Includes/Options/Permissions`, `#EndRegion ;Variables/Logging`, and `#EndRegion ;traytips`. The four new config regions are inconsistent with those.

**Fix**: Each `#EndRegion` should repeat the opening label, e.g., `#EndRegion ;Timing constants`.

---

### STD-03 — MsgBox timeout argument uses bare integer `1` (Judgement call)

**Standard**: `CODING_STANDARDS.md` "constant usage" focus — verify ALL call sites use named constants, no bare integer/string literals remain. `$LOG_LEVEL_*` and `$AUTOIT_PRIORITY_*` constants were introduced; no equivalent timeout constant was introduced for `MsgBox`.

**Location**: Lines 158, 162, 307, 327, 334, 369 (multiple `MsgBox(...)` calls throughout)

```autoit
MsgBox($MB_SYSTEMMODAL, "AutoIT Script", "Script paused!", 1)
MsgBox($MB_SYSTEMMODAL, "Process Priority", "Process name cannot be empty.", 1)
```

The first argument (`$MB_SYSTEMMODAL`) is properly a named constant. The fourth argument (`1`) is a bare integer representing a 1-second auto-dismiss timeout. No named constant (e.g., `$MSGBOX_TIMEOUT_SEC`) was defined for this. The diff did not change these call sites at all; they were pre-existing and remain bare. This is lower severity than the logging and priority literal replacements (which were the stated focus), but it is a remaining bare integer at a call site the focus list covers.

**Assessment**: Judgement call — the timeout integer is not in the same domain as `$LOG_LEVEL_*` or `$AUTOIT_PRIORITY_*`, but the stated review brief asks to verify no bare integer/string literals remain in call sites using the named-constant families. The `MsgBox` timeout is a separate parameter slot and a separate domain; a constant here would be speculative generality unless other code reuses the same timeout value. Flag for awareness but not a hard violation.

---

### STD-04 — All `$LOG_LEVEL_*` and `$LOG_TYPE_*` call sites converted (Pass)

Every `_LogMessage` call in the diff replaced bare string type literals (e.g., `"System"`, `"Process"`, `"PriorityWatchdog"`) and bare integer level literals (`0`, `1`, `2`) with the corresponding named constants (`$LOG_TYPE_SYSTEM`, `$LOG_LEVEL_INFO`, etc.). Exhaustive scan of the diff confirms no bare string or integer remains in any `_LogMessage` argument position. Full pass.

---

### STD-05 — All `$AUTOIT_PRIORITY_*` call sites converted (Pass)

Every reference to `$PROCESS_BELOWNORMAL`, `$PROCESS_NORMAL`, `$PROCESS_ABOVENORMAL`, `$PROCESS_HIGH`, `$PROCESS_REALTIME`, `$PROCESS_IDLE` was replaced with the corresponding `$AUTOIT_PRIORITY_*` constant. Covers `SetProcessPriority`, `LockProcessPriority`, `_WinAPIPriorityClassToAutoItConst`, and `_PriorityConstantToName`. Full pass.

---

### STD-06 — `CheckElapsedTime` renamed to `_CheckElapsedTime` (Pass)

Bare `CheckElapsedTime` (public naming where private is required) was renamed to `_CheckElapsedTime` matching the `_UnderscorePascalCase` convention for internal/private functions. Both call sites in `ToggleScript` were updated. Full pass.

---

### STD-07 — `_miscpopups` renamed to `_MiscPopups` (Pass)

`_miscpopups` (lowercase, violating `_UnderscorePascalCase`) was renamed to `_MiscPopups`. Definition, call site in `ToggleScript`, and footer comment all updated consistently. Full pass.

---

### STD-08 — `_CloseInstaller` renamed to `_KillProcessList` (Pass)

Previous name `_CloseInstaller` was misleading (Mysterious Name smell — it did not close an installer, it killed a list of processes). Renamed to `_KillProcessList`, which clearly describes the behaviour. The `$sStringInstaller` message string was updated to reference `_KillProcessList` to stay in sync. Full pass.

---

### STD-09 — Service target list moved to config region (Pass)

The diff removes the local `$aNames[9]` array declared inside `_RunServiceBatchStop()` and replaces it with a reference to the new global `$aSvcTargetNames` declared in `#Region ;Configuration — Target lists`. This is consistent with the stated config region structure requirement. Full pass.

---

### Smell baseline (Fowler ch.3)

- **Mysterious Name**: `_CloseInstaller` → `_KillProcessList` addressed this. No new mysterious names introduced. `$sStringInstaller` on line 90 retains a name that no longer reflects its updated content ("In the _KillProcessList function..."), but this is a minor residue; `$taskcloseran` on line 91 is similarly opaque and pre-existing — both were not touched by the focused diff and are out of scope for this review pass.
- **Duplicated Code**: The TOCTOU process-exists re-check + ArrayDelete triple appears twice in `_PriorityWatchdog` (dead-process detection and drift-restore dead-process guard). This is pre-existing and not introduced by this diff.
- **Speculative Generality**: No new speculative abstraction introduced.
- **Shotgun Surgery**: The constant migration touched every `_LogMessage` call site and every priority reference across the whole file — this is intentional global substitution, not a design smell.

---

**Standards summary**: 2 hard violations (STD-01, STD-02 — `#EndRegion` labels missing on 5 regions including all 4 new config regions and the pre-existing `#Region ;hotkeys`); 1 judgement call (STD-03 — bare `1` timeout in `MsgBox` calls). All stated focus items (naming, constant usage) are otherwise fully addressed.

---

## Spec

### SPEC-01 — REQ-010: All 9 service names present (Pass)

REQ-010 canonical list: `FDResPub`, `fdPHost`, `TrustedInstaller`, `wuauserv`, `UsoSvc`, `DoSvc`, `WaaSMedicSvc`, `SSDPSRV`, `sppsvc`.

Current file, lines 84–86:
```autoit
Global $aSvcTargetNames[9] = [ _
    "FDResPub", "fdPHost", "TrustedInstaller", "wuauserv", _
    "UsoSvc", "DoSvc", "WaaSMedicSvc", "SSDPSRV", "sppsvc"]
```

All 9 names present, array size declared as `[9]`. Full pass.

---

### SPEC-02 — REQ-010: Service target list location diverges from REQ-010 "Detail" text (Observation)

REQ-010 Detail states: "9 service names present in `$aServiceNames` local array in `_RunServiceBatchStop()`". The implementation moved the list to a global `$aSvcTargetNames` in the config region, which is architecturally superior (single edit point) and explicitly intended by the diff's comment: "Edit here to add/remove service targets — do not modify _RunServiceBatchStop body."

The REQ-010 Status line says "IMPLEMENTED" and the detail text is an artefact of the original plan before the config-region refactor was adopted. This is not a spec failure — the requirement intent (9 names, correct names, accessible to `_RunServiceBatchStop`) is satisfied. However, the requirements register's Detail text is now stale. This should be noted as a documentation cleanup item, not a code defect.

---

### SPEC-03 — REQ-011: `$iLastStopProcesses` declared (Pass)

`Global $iLastStopProcesses = 0` present on line 104. Full pass.

---

### SPEC-04 — REQ-012: Duplicate `#include` and `HotKeySet` lines removed (Pass)

Working-tree file contains each of `WinAPI.au3`, `WinAPIProc.au3`, `Array.au3` exactly once. Each hotkey combination registered exactly once. Full pass.

---

### SPEC-05 — REQ-013: Service poll interval is 10 seconds (Pass)

`Global Const $SVC_POLL_INTERVAL_SEC = 10` on line 43. Used as the interval argument to `_CheckElapsedTime($iLastStopServices, $SVC_POLL_INTERVAL_SEC)` in `ToggleScript` (line 171). Full pass.

---

### SPEC-06 — REQ-014: Include paths portable (Pass)

`#include "Includes\ServiceControl.au3"` and `#include "Includes\ServiceManager.au3"` are relative. `#AutoIt3Wrapper_Outfile_x64=.\release\Stop Services - Processes.exe` is relative. No hardcoded user-profile or checkout-root paths present. Full pass.

---

### SPEC-07 — REQ-013: `_CheckElapsedTime` used at service poll site (not bare `CheckElapsedTime`) (Pass)

Both poll sites in `ToggleScript` call `_CheckElapsedTime(...)` (the renamed, correctly namespaced function). The bare `CheckElapsedTime` reference is gone. Full pass.

---

**Spec summary**: 0 missing requirements; 0 scope creep; 0 wrong implementations across REQ-010 through REQ-014. One documentation staleness observation (SPEC-02): REQ-010 Detail text in `docs/REQUIREMENTS.md` refers to a local array that no longer exists; the requirements register should be updated to reflect the global config-region placement.

---

## Summary

| Axis | Finding count | Worst finding |
|---|---|---|
| Standards | 3 (2 hard, 1 judgement call) | STD-01/STD-02: `#EndRegion` labels absent on 5 regions (hotkeys + all 4 new config regions) |
| Spec | 1 observation (not a failure) | SPEC-02: REQ-010 Detail text stale — references local array that was superseded by global config-region placement |
