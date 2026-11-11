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
