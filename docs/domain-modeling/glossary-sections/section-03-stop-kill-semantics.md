# Glossary Section 03 — Stop / Kill Semantics

This section defines the vocabulary for how this project stops services and kills
processes. The two operations are mechanically distinct and must not be conflated:
services are stopped cooperatively through the Windows Service Control Manager;
processes are killed unconditionally through the operating system. Using the wrong
word obscures which mechanism is in play.

> **Source authority**: `Includes/ServiceManager.au3`, `Stop Services Processes.au3`
> **Proposals consulted**: DM-03, DM-10
> **Read-only cross-references**: see section-01 for Stop Outcome full definition

---

## Language

**Stop (service)**:
A cooperative shutdown request delivered to a Windows service through the Service
Control Manager. The SCM forwards the request to the service's own control handler;
the service is responsible for transitioning itself to the STOPPED state. The request
may be accepted and pending (`STOP_PENDING`), may be refused, or may never complete
within the allowed time — but no process is forcibly terminated as part of a stop.
_Avoid_: terminate service, kill service, close service

---

**Kill (process)**:
An unconditional, immediate termination of a process by the operating system. The
process receives no notification and has no opportunity to run cleanup code. This is
the only process-termination mechanism used in this codebase.
_Avoid_: close process, stop process, terminate process

> **Naming note — `_CloseInstaller` misnomer**: Earlier versions of this codebase
> included a function named `_CloseInstaller` that killed processes despite its name.
> "Close" in that context was a historical misnomer: no close message was sent to any
> window; the operation was always an unconditional Kill. The function has since been
> renamed. Any occurrence of "close" in relation to processes in comments or older
> log strings should be read as Kill, not as a graceful window-close operation
> (which is a separate, unrelated mechanism used only in `_miscpopups`).

---

**Graceful Stop**:
A Stop (service) operation in which the service receives the SCM control request and
transitions to STOPPED under its own control, without any force-kill fallback. All
service-stop operations in this codebase are graceful; there is no path that falls
back to killing a service's host process if the service does not respond in time.
_Avoid_: soft stop, cooperative stop, clean stop

---

**Force Kill**:
A Kill (process) operation that terminates a process immediately and
unconditionally, regardless of the process's state or willingness to exit. Every
process termination in this codebase is a Force Kill; there is no graceful
process-stop path.
_Avoid_: hard kill, forced termination, forced close

---

**Batch Stop**:
A single operation that attempts to stop a group of services as a unit: all stop
controls are issued without serial waiting, and the outcome of each service is
measured against one shared deadline. A Batch Stop either succeeds for a given
service (it reaches the STOPPED state) or concludes with one of the terminal Stop
Outcomes — it never retries within the same batch.
_Avoid_: bulk stop, multi-service stop, service sweep

---

**Batch Deadline**:
The single shared time limit that governs an entire Batch Stop. It begins when the
first stop controls are issued and expires once for the whole group — it is not
reset or restarted for individual services. A service that has not reached the
STOPPED state when the Batch Deadline expires receives the `TIMED_OUT` outcome and
is left in whatever state it was in; no force-kill is attempted.
_Avoid_: per-service timeout, service timeout, stop deadline

> **Relationship to retry cadence**: The Batch Deadline is distinct from the
> inter-cycle gap (`$SVC_POLL_INTERVAL_SEC`) between successive Batch Stop
> invocations. The deadline controls how long one batch waits; the interval controls
> how often a new batch is started by the Monitoring Loop.

---

**Stop Outcome**:
The per-service result produced by a Batch Stop for each service in the input list.
Exactly one of five values:

| Value | Meaning |
|---|---|
| `STOPPED` | Service reached the STOPPED state within the Batch Deadline. |
| `ALREADY_STOPPED` | Service was not running when the batch was issued; no stop control was needed. |
| `UNAVAILABLE` | Service does not exist on this machine; it cannot be stopped. |
| `FAILED` | The SCM returned a non-recoverable error when the stop control was issued. |
| `TIMED_OUT` | The service did not reach STOPPED before the Batch Deadline expired. |

_Avoid_: result code, status code, outcome string, service result

> The full authoritative definition of this enum, including its relationship to the
> Result Row data structure, lives in section-01. This entry defines the five values
> for reference within the Stop/Kill Semantics domain.

---

**Monitoring Loop**:
The active state the script enters when toggled on, during which it repeatedly
invokes the process-kill cycle and the service-stop cycle on their respective
intervals, then sleeps briefly before repeating. The loop runs until the user
toggles it off.
_Avoid_: AutoClose, active loop, running state, script running

> **"AutoClose" is a misnomer**: Earlier documentation and comments in this codebase
> referred to this loop as "AutoClose". That name is inaccurate: the loop does not
> close anything — it kills processes (Force Kill) and stops services (Graceful
> Stop). "Monitoring Loop" is the canonical term.
