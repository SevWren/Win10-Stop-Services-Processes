# CR2-27 — Dead Code and Stale Content Audit
**Type**: Second-Pass Code Review
**Date**: 2026-11-12
**Reviewer**: Automated audit pass
**Scope**: Dead function references in `.au3` files; stale ADR-directory claims in docs; blocker resolution status; log format consistency; leftover test file

---

## Audit Items

---

### Item 1 — `_BuildExpectedRow` in `.au3` files

**Check**: grep all `.au3` files for any live reference to `_BuildExpectedRow`.

**Finding**: The name appears exactly once, in `Tests/ServiceManager.Tests.au3` line 50, inside a
comment block:

```
;   The term "stub" in older comments referred to _BuildExpectedRow, which has
;   been removed (dead code — never called).
```

No `Func _BuildExpectedRow` declaration exists. No call site exists. The comment accurately
describes its own history.

**Verdict**: RESOLVED — the function does not exist in any `.au3` file; the comment is
self-documenting.

---

### Item 2 — `_miscpopups` (bare lowercase) in `.au3` files

**Check**: grep all `.au3` files (case-insensitive) for `_miscpopups`.

**Finding**: Found as `_MiscPopups` (PascalCase with underscore prefix) in
`Stop Services Processes.au3` lines 176, 619, 623, 631 — declaration and one call site.
No bare lowercase `_miscpopups` identifier exists outside of the renamed form.

**Verdict**: RESOLVED — the old lowercase bare form is gone; the function has been renamed to
the convention-conforming `_MiscPopups`.

---

### Item 3 — `_CloseInstaller` in `.au3` files

**Check**: grep all `.au3` files for `_CloseInstaller`.

**Finding**: Zero matches across all `.au3` files in the repository.

**Note**: `CLAUDE.md` (the project README snapshot) documents `_CloseInstaller()` as a function
in the active monitoring loop, but it is not present in the current source. The function that
kills processes is now embedded in the monitoring loop or renamed. This discrepancy is between
`CLAUDE.md` and the live source; it is outside the scope of this audit item but noted for
awareness. The dead-code question asked specifically whether `_CloseInstaller` exists in `.au3`
files — it does not.

**Verdict**: RESOLVED — `_CloseInstaller` is absent from all `.au3` files.

---

### Item 4 — `_stopservicescustom` in `.au3` files

**Check**: grep all `.au3` files (case-insensitive) for `_stopservicescustom`.

**Finding**: Zero matches. The old function has been fully replaced by `_RunServiceBatchStop()`
wrapping `_SM_StopServicesBatch()`.

**Verdict**: RESOLVED — `_stopservicescustom` is absent from all `.au3` files.

---

### Item 5 — Bare `CheckElapsedTime` (without leading underscore) in `.au3` files

**Check**: grep all `.au3` files for `CheckElapsedTime` (without leading `_`).

**Finding**: Only `_CheckElapsedTime` (with underscore) exists:
- `Stop Services Processes.au3` line 167: `If _CheckElapsedTime($iLastStopProcesses, ...)`
- `Stop Services Processes.au3` line 171: `If _CheckElapsedTime($iLastStopServices, ...)`
- `Stop Services Processes.au3` line 291: `Func _CheckElapsedTime($iStartTime, $iInterval)`

No bare `CheckElapsedTime` without an underscore appears anywhere.

**Verdict**: RESOLVED — the function is correctly named `_CheckElapsedTime` throughout.

---

### Item 6 — `docs/ARCHITECTURE.md` stale "No `docs/adr/` directory exists" claim

**Check**: Does a `docs/adr/` directory exist? If it does not, the claim is accurate; if it
does, the claim is stale.

**Finding**: A glob of `docs/adr/**` returns no files. The `docs/adr/` directory does not
exist in the repository. The claim on `docs/ARCHITECTURE.md` line 123 reads:

> "No ADR directory exists in this repository."

This statement is factually accurate as of 2026-11-12.

**Caveat**: `docs/wiki/blockers.md` B-005 references
`docs/adr/0009-queryservicestatus-api-selection.md` as if it exists and contains recorded
rationale. That file is absent, making B-005 internally inconsistent — but that inconsistency
is in `blockers.md`, not in `ARCHITECTURE.md`.

**Verdict**: RESOLVED — the claim in `docs/ARCHITECTURE.md` is accurate; no `docs/adr/`
directory exists.

---

### Item 7 — `docs/REQUIREMENTS.md` REQ-017 stale "No `docs/adr/` directory exists" claim

**Check**: Same `docs/adr/` existence check as Item 6, applied to REQ-017.

**Finding**: `docs/REQUIREMENTS.md` REQ-017 (line 268) states:

> "No `docs/adr/` directory exists in this repository. This requirement row constitutes
> the required primary-source decision record per the enterprise prompt's alternative-API
> clause."

As established above, `docs/adr/` does not exist. The statement is accurate.

**Verdict**: RESOLVED — the claim in `docs/REQUIREMENTS.md` REQ-017 is accurate.

---

### Item 8 — `docs/IMPLEMENTATION-AND-VERIFICATION.md` stale ADR directory claim

**Check**: Search `docs/IMPLEMENTATION-AND-VERIFICATION.md` for any reference to a
`docs/adr/` directory or ADR file paths.

**Finding**: The file does not mention `docs/adr/` or any ADR file path. The only ADR-adjacent
references are to `docs/wiki/blockers.md` blockers B-001, B-002, B-003 (line 241) —
none of which claim an ADR directory exists.

**Verdict**: RESOLVED — `docs/IMPLEMENTATION-AND-VERIFICATION.md` contains no stale ADR
directory claim.

---

### Item 9 — `docs/wiki/blockers.md` B-006 and B-007 resolution status

**Check**: Are B-006 (README not updated) and B-007 (GLOSSARY timing constant name drift)
marked RESOLVED? Per the task brief they should be — README fixed by T1-10, GLOSSARY fixed
by T2-11.

**Finding**: Both blockers are marked **OPEN** in the current file:

- B-006 (`docs/wiki/blockers.md` line 89): `**Status**: OPEN`
- B-007 (`docs/wiki/blockers.md` line 109): `**Status**: OPEN`

Neither has been updated to RESOLVED. If T1-10 fixed `README.md` and T2-11 fixed
`GLOSSARY.md`, the status fields in `blockers.md` were not updated after those tasks
completed.

**Verdict**: STILL OPEN — B-006 and B-007 remain marked OPEN. The status fields in
`docs/wiki/blockers.md` need to be updated to RESOLVED with brief resolution notes
referencing T1-10 and T2-11 respectively.

---

### Item 10 — `Log File/closure_log.txt` format vs `_LogMessage` output

**Check**: Does the sample log format match what `_LogMessage` currently produces?

**Sample log format** (from `Log File/closure_log.txt`):
```
12:34:29 PM 05/08/2024 - Service 'wuauserv' was closed.
```
Pattern: `HH:MM:SS AM/PM DD/MM/YYYY - Type 'name' was closed.`

**Current `_LogMessage` output** (from `Stop Services Processes.au3` lines 271–272):
```autoit
Local $sDateTime = _NowTime(12) & " " & @MDAY & "/" & @MON & "/" & @YEAR
Local $sLogEntry = @CRLF & $sDateTime & " [" & $sType & "] " & $sMessage
```
Pattern: `\r\nHH:MM:SS AM/PM D/M/YYYY [Type] message text`

**Differences**:

| Aspect | Sample log | `_LogMessage` output |
|---|---|---|
| Date separator | `DD/MM/YYYY` (zero-padded, e.g. `05/08/2024`) | `@MDAY/@MON/@YEAR` (no zero-pad; `5/8/2024`) |
| Type field | bare word after ` - ` (e.g. `Service`) | bracketed after space (e.g. `[Service]`) |
| Message body | `'wuauserv' was closed.` | structured text e.g. `Service stopped: wuauserv` |
| Leading whitespace | none | `@CRLF` prepended to each entry |

The sample log was produced by an older version of the script (pre-migration, 2024 entries).
The current `_LogMessage` implementation generates a structurally different format: bracket-
delimited type field, no zero-padded date components, `@CRLF` leading each entry, and
structured outcome messages rather than the old `'name' was closed.` phrasing.

**Verdict**: STILL OPEN — the sample log in `Log File/closure_log.txt` does not match the
format produced by the current `_LogMessage` implementation. The file is a historical artifact
from the pre-migration script. If `closure_log.txt` is intended as a format reference or
documentation sample, it needs to be updated to reflect the current log format. If it is
retained purely as historical evidence, a note to that effect should be added to the file or
to `docs/BASELINE-INVENTORY.md`.

---

### Item 11 — `test_process_close.au3` presence (recommended for deletion)

**Check**: Is `test_process_close.au3` still present in the repository?

**Finding**: `test_process_close.au3` exists at `/home/vercel-sandbox/repo/test_process_close.au3`.
The file contains a bare `#RequireAdmin` stub that loops checking for `TCPSVCS.EXE`. It is not
referenced by any other file, not included in `#include` statements, and not part of the
`Tests/` harness.

**Verdict**: STILL OPEN — `test_process_close.au3` is still present. The recommendation to
delete it has not been acted upon.

---

## Summary Table

| # | Item | Verdict |
|---|---|---|
| 1 | `_BuildExpectedRow` in `.au3` files | RESOLVED |
| 2 | `_miscpopups` bare lowercase in `.au3` files | RESOLVED |
| 3 | `_CloseInstaller` in `.au3` files | RESOLVED |
| 4 | `_stopservicescustom` in `.au3` files | RESOLVED |
| 5 | Bare `CheckElapsedTime` (no underscore) in `.au3` files | RESOLVED |
| 6 | `docs/ARCHITECTURE.md` "No `docs/adr/`" claim | RESOLVED (claim is accurate) |
| 7 | `docs/REQUIREMENTS.md` REQ-017 "No `docs/adr/`" claim | RESOLVED (claim is accurate) |
| 8 | `docs/IMPLEMENTATION-AND-VERIFICATION.md` ADR directory claim | RESOLVED (no such claim present) |
| 9 | `docs/wiki/blockers.md` B-006 and B-007 marked RESOLVED | STILL OPEN |
| 10 | `Log File/closure_log.txt` format vs `_LogMessage` | STILL OPEN |
| 11 | `test_process_close.au3` still present | STILL OPEN |

**RESOLVED**: 8 of 11
**STILL OPEN**: 3 of 11

---

## Action Items for STILL OPEN Findings

### AO-1 (Item 9) — Update `docs/wiki/blockers.md` B-006 and B-007 status
- Change B-006 `**Status**: OPEN` to `**Status**: RESOLVED — README.md updated by T1-10`
- Change B-007 `**Status**: OPEN` to `**Status**: RESOLVED — GLOSSARY.md updated by T2-11`
- File: `/home/vercel-sandbox/repo/docs/wiki/blockers.md`

### AO-2 (Item 10) — Reconcile `Log File/closure_log.txt` with current log format
- Either update `closure_log.txt` to show a representative entry in the current format
  (e.g. `12:34:29 PM 8/5/2024 [Service] Service stopped: wuauserv`) with a header comment
  noting it is a format sample, not live output; or add a note in `docs/BASELINE-INVENTORY.md`
  that the file is a pre-migration historical artifact and does not reflect the current format.
- File: `/home/vercel-sandbox/repo/Log File/closure_log.txt`

### AO-3 (Item 11) — Delete `test_process_close.au3`
- The file is dead code with no callers, no harness membership, and a prior deletion
  recommendation. Delete it.
- File: `/home/vercel-sandbox/repo/test_process_close.au3`
