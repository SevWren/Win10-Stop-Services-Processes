# 02: Define Contracts and Verify Windows SCM APIs

**What to build:** Research the DllCall contract for each Windows SCM API against
primary sources. Convert target behaviors into REQ-* rows. Define the ServiceManager
module interface, service timing constants, and batch-stop public contract.
Produce docs/REQUIREMENTS.md, docs/ARCHITECTURE.md, docs/research/windows-scm-api.md,
docs/research/autoit-dllcall.md.

**Blocked by:** 01 (Baseline Discovery must be complete first)

**Status:** ready-for-agent

- [ ] Research subagent A: AutoIt DllCall, DllStructCreate, DllOpen, DllClose
- [ ] Research subagent B: Windows SCM APIs (OpenSCManagerW, OpenServiceW, QueryServiceStatusEx, ControlService, CloseServiceHandle)
- [ ] Verify SERVICE_STATUS is 7 DWORDs; SERVICE_STATUS_PROCESS is 9 DWORDs
- [ ] Verify ControlService takes SERVICE_STATUS (7-DWORD), not SERVICE_STATUS_PROCESS
- [ ] Reconcile service inventory against baseline (FDResPub, fdPHost, TrustedInstaller, wuauserv, UsoSvc, DoSvc, WaaSMedicSvc, SSDPSRV, sppsvc)
- [ ] Confirm minimum access rights: SC_MANAGER_CONNECT | SERVICE_QUERY_STATUS | SERVICE_STOP
- [ ] Write REQ-* rows in docs/REQUIREMENTS.md
- [ ] Write public contract for _SM_StopServicesBatch in docs/ARCHITECTURE.md
- [ ] Update GLOSSARY.md with SCM terms

## Status: CLOSED

All contract definition and API verification work was completed.

**What was delivered:**
- `docs/REQUIREMENTS.md` — REQ-001 through REQ-014, each with source, implementation location, and verification method.
- `docs/ARCHITECTURE.md` — module interface, DllCall contracts (OpenSCManagerW, OpenServiceW, QueryServiceStatus, ControlService, CloseServiceHandle), `_SM_StopServicesBatch` public contract with 2D return array layout.
- `docs/research/windows-scm-api.md` — Windows SCM API research (access rights, SERVICE_STATUS 7-DWORD layout, ControlService vs QueryServiceStatusEx selection).
- `docs/research/autoit-dllcall.md` — AutoIt DllCall / DllStructCreate research.
- `GLOSSARY.md` — SCM terms, timing constants, result-row column definitions.
- Service inventory of 9 names (FDResPub, fdPHost, TrustedInstaller, wuauserv, UsoSvc, DoSvc, WaaSMedicSvc, SSDPSRV, sppsvc) reconciled against baseline.
- Minimum access rights confirmed: SC_MANAGER_CONNECT | SERVICE_QUERY_STATUS | SERVICE_STOP.
- SERVICE_STATUS confirmed as 7-DWORD struct; ControlService verified to take SERVICE_STATUS (not SERVICE_STATUS_PROCESS).

**One naming inconsistency noted (not a blocker):** CR-10 (S-01) found that two timing-constant names in `GLOSSARY.md` (`$PRIORITY_WATCHDOG_INTERVAL_MS`, `$SVC_POLL_MS`) diverge from their actual declared names in the implementation (`$PRIORITY_WATCHDOG_MS`, `$SVC_BATCH_POLL_MS`). This is a documentation drift defect; all requirements and contracts are correct.

**Artifacts as evidence:**
- `/home/vercel-sandbox/repo/docs/REQUIREMENTS.md`
- `/home/vercel-sandbox/repo/docs/ARCHITECTURE.md`
- `/home/vercel-sandbox/repo/docs/research/windows-scm-api.md`
- `/home/vercel-sandbox/repo/docs/research/autoit-dllcall.md`
- `/home/vercel-sandbox/repo/GLOSSARY.md`
