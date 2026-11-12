# 10: Optional — Populate $sNote for Win32 error 5 (WaaSMedicSvc log noise)

**What to build:** In `_SM_Win32ErrToOutcome` (or its immediate call site in `_SM_StopServicesBatch`), populate the `$sNote` field (column 5 of the result row, `$aResults[$i][5]`) with the string `"ACCESS_DENIED — OS-protected service"` when `ControlService` returns Win32 error 5 (`ERROR_ACCESS_DENIED`). All other FAILED outcomes must leave `$sNote` empty. This is a 1-line change in `Includes/ServiceManager.au3`. It does not alter outcome routing (FAILED remains FAILED per ADR-0005); it only adds a human-readable explanation to the note column so that the repeated FAILED log entries for `WaaSMedicSvc` are less confusing to users.

**Why optional:** The current FAILED routing is correct per ADR-0005 (`docs/adr/0005-graceful-only-service-stop.md`). `WaaSMedicSvc` is protected on Windows 10 1803+ by a kernel-level mechanism; `ControlService` with `SERVICE_CONTROL_STOP` reliably returns `ERROR_ACCESS_DENIED` (5) on modern builds and there is nothing the script can do about it. This ticket is a pure UX improvement — reducing log confusion — not a correctness or bug fix. See `docs/reviews/bugs/BUG-11-protected-service.md` §Recommendations ("Optional: Improve the log message note field for Win32=5") for the full rationale.

**Blocked by:** None — straightforward 1-line change, no dependency on open issues.

**Status:** ready-for-agent

---

## Tasks

- [ ] In `Includes/ServiceManager.au3`, locate `_SM_Win32ErrToOutcome` and the FAILED branch of `_SM_StopServicesBatch` where `$aResults[$i][4]` (Win32 error) is set.
- [ ] After the FAILED outcome is assigned, add a conditional: if `$iCtrlWinErr = 5` then set `$aResults[$i][5] = "ACCESS_DENIED — OS-protected service"`. All other error codes must leave `$aResults[$i][5]` unchanged (empty string).
- [ ] Verify that `_RunServiceBatchStop` in `Stop Services Processes.au3` already reads column 5 (`$sNote`) for FAILED outcomes, or update it to append the note to the log line when non-empty (e.g., `"Service stop failed: WaaSMedicSvc (Win32: 5) — ACCESS_DENIED — OS-protected service"`).
- [ ] Confirm no other FAILED outcome (e.g., Win32 error 1061 `ERROR_SERVICE_CANNOT_ACCEPT_CTRL`) gains a note — regression check.
- [ ] Run AU3Check (`-q -d -w 1 -w 2 -w 3 -w 4`) with no new warnings.

---

## Acceptance Criteria

- `_SM_Win32ErrToOutcome` (or its call site) populates `$sNote` with `"ACCESS_DENIED — OS-protected service"` specifically for Win32 error 5.
- All other FAILED outcomes continue to have an empty `$sNote` (no regression).
- Log output for `WaaSMedicSvc` includes the note text, making it clear the failure is an OS protection mechanism and not a script misconfiguration.
- No new AU3Check warnings introduced.

---

## Context and Reference

- **Source finding:** `docs/reviews/bugs/BUG-11-protected-service.md` — §Recommendations, "Optional: Improve the log message note field for Win32=5"
- **ADR constraint:** ADR-0005 (`docs/adr/0005-graceful-only-service-stop.md`) — FAILED routing must not change; no force-kill fallback; no new outcome string.
- **Do not** add a service-name-specific branch (`If $sSvcName = "WaaSMedicSvc"`) inside `ServiceManager.au3` — the note must be keyed on the Win32 error code (5), not the service name. This keeps the module generic per BUG-11 §Recommendations.
- **File to edit:** `Includes/ServiceManager.au3` (1-line change). Possibly a 1-line change in `Stop Services Processes.au3` if `_RunServiceBatchStop` does not already surface column 5 in the FAILED log line.
- **Priority:** Low — optional quality-of-life improvement only.
