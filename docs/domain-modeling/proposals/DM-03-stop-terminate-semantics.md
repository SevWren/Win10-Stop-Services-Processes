# DM-03 — Stop / Terminate / Kill / Close Semantics

**Status:** Proposal
**Author:** domain-modeling skill
**Relates to:** GLOSSARY.md, `Includes/ServiceManager.au3`, `Stop Services Processes.au3`

---

## 1. What prompted this analysis

The word "stop" appears in at least four distinct technical roles in this codebase:

- The Windows SCM concept of stopping a service (`ControlService` with `SERVICE_CONTROL_STOP`)
- An intermediate SCM state (`STOP_PENDING`)
- The script-level monitoring loop being paused (`ToggleScript`)
- The function name `_stopservicescustom` / `_RunServiceBatchStop`

The words "kill", "terminate", "close", and "graceful" also surface across source, comments, and log strings without a shared definition. This proposal resolves each term's precise meaning in this codebase and identifies which ones belong in GLOSSARY.md.

---

## 2. Term-by-term analysis

### 2.1 "Stop" (service context)

**What the code does:**
`_SM_StopServicesBatch` sends `SERVICE_CONTROL_STOP` (0x00000001) to the Windows SCM via `ControlService`. This is a *request* — the SCM forwards it to the service's control handler, which is then responsible for transitioning to `STOPPED`. The service may take time; the caller polls.

**Key distinction:** "Stop" in the service context is always *cooperative / graceful*. The SCM does not forcibly terminate the service's host process. If the service ignores or cannot accept the control, the outcome is `FAILED` or `TIMED_OUT`, not forced termination.

**Verdict:** "Stop" for services means *send SERVICE_CONTROL_STOP and wait for STOPPED state*. It is strictly graceful. There is no force-stop path in this codebase for services.

---

### 2.2 "Kill" / "Terminate" (process context)

**What the code does:**
`_CloseInstaller` calls AutoIt's `ProcessClose($sProcesses[$i])`. AutoIt's `ProcessClose` maps to `TerminateProcess` in kernel32.dll — a hard, unconditional kill. There is no SIGTERM equivalent; the process gets no chance to run cleanup code.

**Verdict:** In this codebase, "kill" and "terminate" are synonyms for the same operation (`ProcessClose` → `TerminateProcess`). There is no graceful process-stop path. The function name `_CloseInstaller` is a historical misnomer (see §2.3 below).

**Avoid:** "terminate process" and "kill process" should not be used interchangeably with "stop service" — they are entirely different mechanisms.

---

### 2.3 "Close" (process and window context)

The word "close" appears in two distinct roles:

**a) `_CloseInstaller` function name** — despite the name, this function kills processes via `ProcessClose`, not window close messages. The name is inherited from early script history and does not reflect the actual operation. No `WinClose` or `WM_CLOSE` message is sent to the processes listed in `$sProcesses[]`.

**b) `WinClose` calls in `_miscpopups`** — here "close" is genuine: `WinClose` sends a `WM_CLOSE` message to the target window, giving the application a chance to handle it. This is a *graceful window close*, distinct from process kill.

**Verdict:** "Close" is overloaded in this codebase:
- As a function name (`_CloseInstaller`): misleading synonym for "kill process".
- As a WinAPI operation (`WinClose`): a genuine cooperative window-close request.

The two should not be treated as synonyms. This is an existing naming inconsistency in the code, noted here for awareness but not proposed for immediate renaming (see §6).

---

### 2.4 "Graceful stop" vs "force stop"

**Services:** The codebase implements only graceful stop (via SCM control). There is no force-stop (i.e., no `TerminateProcess` on a service's host process) anywhere in the current code. If a service does not stop within `$SVC_BATCH_TIMEOUT_MS` (20,000 ms), the outcome is `TIMED_OUT` and the service is simply abandoned for that cycle — the monitoring loop will retry on the next `$SVC_POLL_INTERVAL_SEC` tick.

**Processes:** The codebase implements only force-kill (via `ProcessClose` → `TerminateProcess`). There is no graceful process-stop path.

**Summary table:**

| Subject  | Operation used          | Graceful? | Fallback if unresponsive |
|----------|-------------------------|-----------|--------------------------|
| Service  | `ControlService(STOP)`  | Yes       | `TIMED_OUT`; retry next cycle |
| Process  | `ProcessClose`          | No        | n/a — unconditional kill |
| Window   | `WinClose` (`WM_CLOSE`) | Yes       | n/a — no fallback in code |

---

### 2.5 "Timeout" in the stop process

**What the code does:**
`$SVC_BATCH_TIMEOUT_MS = 20000` is a *shared deadline* for all services in a single batch call. After `SERVICE_CONTROL_STOP` is sent, `_SM_StopServicesBatch` polls every `$SVC_BATCH_POLL_MS` (500 ms). If `TimerDiff($iTimer) >= $iBatchTimeoutMs` before all services reach `STOPPED`, those remaining are marked `TIMED_OUT`.

**Precise meaning:** "Timeout" in this codebase means *the shared polling deadline for a single batch-stop invocation was exceeded*. It does not mean the service crashed, was killed, or was retried with force. The service handle is closed and the service remains in whatever state it was in.

**Not to be confused with:** `$SVC_POLL_INTERVAL_SEC = 10` — this is the inter-cycle gap between batch-stop invocations, not a per-service timeout.

---

### 2.6 "Batch stop" — is it a first-class glossary term?

The existing GLOSSARY.md already carries a **Batch Stop** entry, defined as the single `_SM_StopServicesBatch()` call. This entry is correct and complete. No change is proposed to the existing definition.

The question is whether the entry should be sharpened to make explicit that it is *always graceful* (no force-kill fallback). The current definition focuses on the mechanical shape (one SCM open, fan-out, shared deadline, one result row per service) without mentioning graceful-vs-force. Given that GLOSSARY.md avoids implementation details, and "graceful" is a characteristic of the operation rather than a naming distinction, the current entry is adequate. The graceful-vs-force distinction belongs in an ADR (see §4).

---

## 3. Proposed GLOSSARY.md additions / amendments

The following are proposed changes to GLOSSARY.md. They must be applied by editing that file directly (not here).

### New term: Stop (service)

> A cooperative shutdown request sent to a Windows service via `ControlService(SERVICE_CONTROL_STOP)`. The service receives the control, handles it internally, and transitions toward `STOPPED`. The request may be pending (`STOP_PENDING`) or may time out.
> _Avoid_: "terminate service", "kill service", "close service"

### New term: Kill (process)

> An unconditional, immediate termination of a process via AutoIt `ProcessClose`, which maps to Windows `TerminateProcess`. The process gets no opportunity to run cleanup code.
> _Avoid_: "close process", "stop process", "terminate process" (all used interchangeably in comments and older function names, but all mean the same underlying operation here)

### New term: Stop Outcome

> The per-service result of a Batch Stop cycle. One of five values: `STOPPED` (service reached the STOPPED state within the deadline), `ALREADY_STOPPED` (service was not running when the batch started), `UNAVAILABLE` (service does not exist on this machine), `FAILED` (SCM or ControlService returned a non-recoverable error), `TIMED_OUT` (service did not reach STOPPED before the shared deadline).
> _Avoid_: "result", "status" (which is overloaded with Service State)

### Amendment to existing "Batch Stop" term

The existing definition is accurate. Consider appending one sentence: "All stop operations in a batch are cooperative (graceful); there is no force-kill fallback for services that do not respond."

### Term that does NOT belong in the glossary

**"Graceful stop"** — this is a general systems programming concept (cooperative shutdown vs. forced termination), not a term coined by this codebase. It belongs in documentation or an ADR, not the glossary.

**"Timeout"** — similarly general. `$SVC_BATCH_TIMEOUT_MS` is already captured under the existing **Timing Constants** glossary entry, which is the right place.

---

## 4. ADR warrant

**Question:** Is the decision to use graceful-only service stop (no force-kill fallback) ADR-worthy?

Applying the three-gate test:

1. **Hard to reverse?** Yes. Adding a force-kill fallback (e.g., `TerminateProcess` on the service host after timeout) is a meaningful architectural change that touches `ServiceManager.au3`, the monitoring loop, and the result-outcome model.

2. **Surprising without context?** Yes. A reader encountering `TIMED_OUT` as the terminal outcome for a non-responsive service will reasonably ask: "Why don't we just kill it?" The answer is non-obvious (services often run as SYSTEM, have dependent services, and may be protected by Windows; force-killing them can destabilize the system).

3. **Result of a real trade-off?** Yes. The alternative (force-kill on timeout) was implicitly available but not taken. The current code makes a deliberate choice.

**Verdict: an ADR is warranted.** See proposed ADR text in §5.

---

## 5. Proposed ADR

**Proposed path:** `docs/adr/0001-graceful-only-service-stop.md`

> # Graceful-only service stop; no force-kill fallback
>
> Windows services are stopped exclusively by sending `SERVICE_CONTROL_STOP` via the SCM and polling for the `STOPPED` state. If a service does not reach `STOPPED` within the shared batch deadline (`$SVC_BATCH_TIMEOUT_MS = 20 s`), it is marked `TIMED_OUT` and left running until the next monitoring cycle; no `TerminateProcess` call is made on the service host process.
>
> This choice reflects the nature of the target services (`wuauserv`, `TrustedInstaller`, `WaaSMedicSvc`, etc.): they may run as `NT AUTHORITY\SYSTEM`, they may have dependents, and forcibly killing their host process can leave the SCM database inconsistent. Graceful stop is safer and sufficient for the goal of temporarily suppressing update activity — the monitoring loop retries every 10 seconds anyway.
>
> **Considered alternative:** Call `TerminateProcess` on the service host PID when `TIMED_OUT`. Rejected because (a) resolving the host PID from a service name requires additional SCM/WMI calls not currently in scope, and (b) the safety risk outweighs the marginal gain given the 10-second retry cadence.

---

## 6. Out of scope / noted inconsistencies (not proposed for fix)

- **`_CloseInstaller` naming:** The function kills processes but is named "close". Renaming it (`_KillProcesses`, `_TerminateInventory`, etc.) would be a cosmetic refactor. No domain model entry is blocked on this.
- **`_stopservicescustom` (legacy):** Referenced in comments as the predecessor to `_RunServiceBatchStop`. No longer called; ServiceControl.au3's `_StopService` is similarly retired for stop operations. These are code-cleanliness issues, not domain model issues.
- **`WinClose` in `_miscpopups`:** This is a genuinely graceful close (WM_CLOSE to a dialog window), semantically different from both service-stop and process-kill. It is too narrow and application-specific to warrant a glossary entry.
