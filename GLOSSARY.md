# Glossary — Win10-Stop-Services-Processes

> Domain vocabulary for this project. Contains terms only — no implementation details.
> Updated inline as terms are resolved during sessions.

## Service Lifecycle

**Service Control Manager (SCM)**:
The Windows component (`services.msc`) that is the authority for the lifecycle of all
registered services on the machine: starting, stopping, querying, and configuring them.
The script acquires a session-scoped connection at the start of each Batch Stop cycle
and closes it when the cycle completes.
_Avoid_: service manager, Windows service manager

**SCM Handle**:
An opaque value representing an open connection to the Service Control Manager, distinct
from a Service Handle. One SCM Handle is opened at the start of each Batch Stop cycle
and covers all per-service operations within that cycle.
_Avoid_: SCM connection, manager handle

**Service**:
A Windows OS component registered with the Service Control Manager, manageable via the
SCM. A service may or may not be backed by a running process at any given moment.
Stopping a service via the SCM is different from killing its host process.
_Avoid_: daemon, background process (which implies a process, not a service)

**Service Handle**:
An opaque value that grants specific access rights to one registered service. Each handle
is opened with the minimum rights required for the intended operation and must be released
exactly once when the operation completes or fails. Distinct from an SCM Handle, which
refers to the manager itself, not to any individual service.
_Avoid_: service object handle

**Service Name**:
The short internal identifier for a Windows service, stored in the registry and used by
all SCM API calls. This is what the script passes when requesting a service handle or
issuing a stop control. Examples: `wuauserv`, `TrustedInstaller`.
_Avoid_: service key, service identifier, service string

**Display Name**:
The human-readable label for a Windows service shown in `services.msc` and Task Manager.
Distinct from Service Name. All stop operations in this project use Service Names
exclusively; Display Names are never consulted.
_Avoid_: service label, friendly name

**Service State**:
The lifecycle position of a Windows service as reported by the SCM. One of seven named
values: `STOPPED`, `START_PENDING`, `STOP_PENDING`, `RUNNING`, `CONTINUE_PENDING`,
`PAUSE_PENDING`, `PAUSED`.
_Avoid_: service status (overloaded with the name of the underlying Windows struct)

**Stable Service State**:
A Service State in which a service remains until an operation explicitly moves it:
`RUNNING`, `STOPPED`, or `PAUSED`. Contrast with Transient Service State.
_Avoid_: steady state, final state

**Transient Service State**:
A Service State the SCM is passing through during an in-progress operation:
`START_PENDING`, `STOP_PENDING`, `PAUSE_PENDING`, or `CONTINUE_PENDING`. A service in a
transient state may or may not accept control codes, depending on which transition is in
progress.
_Avoid_: pending state, intermediate state

**Stop-Eligible State**:
A Service State from which a stop control can be accepted: `RUNNING`, `PAUSED`,
`PAUSE_PENDING`, or `CONTINUE_PENDING`. Services in `STOPPED`, `STOP_PENDING`, or
`START_PENDING` are not stop-eligible and are routed to `ALREADY_STOPPED`, pending-poll,
or `FAILED` respectively without a stop control being issued.
_Avoid_: stoppable, controllable

**Control Code**:
An integer constant sent to the SCM to instruct it to deliver a command to a service's
control handler. This project issues only the stop control code. Other defined codes
include pause, continue, and interrogate.
_Avoid_: control command, service command

**Stop Control**:
The act of sending a stop control code to a service via the SCM. Issuing a stop control
does not immediately stop the service; it transitions the service toward `STOP_PENDING`
while the service's main thread handles shutdown asynchronously. The stop control is
distinct from the service reaching the `STOPPED` state.
_Avoid_: stopping a service (too broad — conflates the control dispatch with the final state)

**Pending Service**:
A service that has accepted a stop control (or was already in `STOP_PENDING` at first
query) but has not yet reached the `STOPPED` state. Pending services are tracked across
poll cycles within a Batch Stop until the shared deadline expires.
_See also_: Pending List
_Avoid_: in-progress service, stopping service

**Pending List**:
The set of services within a single Batch Stop that have had a stop control issued (or
were already in `STOP_PENDING` state) and are waiting for their Service State to reach
`STOPPED` before the shared deadline expires.
_Avoid_: pending services, in-progress list

**Batch Stop**:
A single operation that attempts to stop a group of services as a unit, issuing all stop
controls without serial waiting (Phase 1) and measuring the outcome of each service
against one shared deadline (Phase 2). All stop operations are cooperative (graceful);
there is no force-kill fallback for services that do not respond in time.
_Avoid_: bulk stop, mass stop

**Stop Outcome**:
The result classification for a single service after a Batch Stop attempt. One of five
values: `STOPPED` (service reached the `STOPPED` state within the deadline),
`ALREADY_STOPPED` (service was not running when the batch started), `UNAVAILABLE`
(service does not exist on this machine), `FAILED` (stop control rejected or access
denied), `TIMED_OUT` (service did not reach `STOPPED` before the shared deadline).
_Avoid_: result code, stop result, status (overloaded with Service State)

**Result Row**:
A six-element record returned for each service in a Batch Stop: service name, initial
state, final state, Stop Outcome, Win32 error code at last failure (zero if none), and a
human-readable note when the outcome requires one (empty string otherwise).
_Avoid_: result record, result entry

**Service Inventory**:
The set of Windows services targeted for batch stop operations during each Monitoring Loop cycle.
_Avoid_: service list, service array

---

## Process Management

**Process**:
A running Windows executable instance, addressable by PID. Distinct from a Service: a
process has no SCM entry and is not managed via the Service Control Manager. The name
`TrustedInstaller` is both a Service Name (SCM-managed) and a process executable name
(process-managed) — they are different OS objects.
_Avoid_: task, program, executable (use "process" unless referring specifically to the file on disk)

**PID (Process ID)**:
The numeric identifier Windows assigns to a running process. Valid only for the lifetime
of that process; once the process exits the PID may be reassigned to another process. Any
code holding a PID must re-validate it before use.
_Avoid_: process handle (a handle is a different Windows object obtained by opening the process)

**Process Kill**:
The unconditional, immediate termination of a process. The process receives no
opportunity to run cleanup code. This is the operation performed each cycle on every
process named in the Process Inventory.
_Avoid_: process stop, process close, terminate (all used interchangeably in older comments,
but all mean the same underlying unconditional operation in this codebase)

**Process Inventory**:
The fixed set of process executable names the script attempts to kill each monitoring
cycle. Entries are executable base names (e.g., `TrustedInstaller.exe`), not service
names — the same string `TrustedInstaller` in the Service Inventory refers to the SCM
service, a distinct object.
_Avoid_: process list, process array

**Priority Class**:
The scheduling tier assigned to a process by the operating system, expressed on a
six-level scale: Idle, Below Normal, Normal, Above Normal, High, and Real-time. The
Windows layer and the AutoIt layer represent these six levels using incompatible numbering
schemes; conversion between the two is always required when reading and then setting a
priority.
_Avoid_: priority level, priority constant (when the Windows API layer is meant)

**AutoIt Priority Constant**:
The integer (0–5) that AutoIt's process-priority API accepts: 0 = Idle, 1 = Below Normal,
2 = Normal, 3 = Above Normal, 4 = High, 5 = Real-time. These integers are unrelated to
the Windows API hex values for the same levels. The Watchlist stores AutoIt Priority
Constants as the canonical target priority for each watched PID.
_Avoid_: priority class (when the AutoIt integer layer is meant)

**Priority Drift**:
The condition in which a watched PID's current Priority Class no longer matches the
target priority that was set when the PID was added to the Watchlist. Drift is caused by
an external agent (the OS scheduler, another tool, or the process itself) changing the
priority after it was locked. Detection and correction of drift is the sole responsibility
of the Priority Watchdog.
_Avoid_: priority change, priority mismatch

**Priority Watchdog**:
An autonomous periodic mechanism that detects and corrects Priority Drift for every PID
in the Watchlist. It fires on a fixed interval, checks each watched PID's current
priority, restores any that have drifted, and evicts dead PIDs. It unregisters itself
when the Watchlist becomes empty.
_Avoid_: priority monitor, priority keeper

**Watchlist**:
The set of PIDs currently under Priority Watchdog supervision. A PID is added when the
user invokes the Lock Priority hotkey and removed when the process exits. A PID may
appear at most once.
_Avoid_: watchdog list, PID list, watch array

---

## Script Behaviour

**Monitoring Loop**:
The active state the script enters when toggled on, during which it repeatedly checks
the Process Inventory and Service Inventory on their respective intervals and closes any
Misc Popups it finds.
_Avoid_: active loop, running state, script running

**Toggle**:
The user action (Shift+F1) that transitions the script between its idle state and its
Monitoring Loop state.
_Avoid_: start, enable, activate

**Timing Constants**:
The named configuration values with a single declared location that govern all interval
and deadline behaviour: the process-kill cycle interval, the service-stop cycle interval,
the main loop sleep, the priority watchdog interval, the batch-stop shared deadline, and
the batch-stop poll interval.
_Avoid_: settings, options, timing values

**Tray Notification**:
A small tooltip displayed at the bottom-right of the desktop to report watchdog events
to the user. Distinct from a Windows toast notification, which the script deliberately
avoids because it produces intrusive Action Center entries with sound.
_Avoid_: tray tip, tray alert, toast notification

**Misc Popup**:
An application registration dialog from a third-party program (e.g., AdvancedRenamer,
Sublime Text) that the script closes automatically during the Monitoring Loop.
_Avoid_: popup, dialog, window

---

## Logging

**Log Level**:
One of three integer values controlling whether a log message is written: 0 = Error
(failure events), 1 = Info (completed-action events), 2 = Verbose (expected-negative
observations such as a service already being stopped). Messages with a level above the
current log level ceiling are silently dropped.
_Avoid_: severity, priority (overloaded with process priority in this codebase), verbosity

**Log Type**:
A category label attached to each Log Entry identifying which subsystem generated it.
_Avoid_: category, channel, logger name

**Log Entry**:
A single line written to the Log File recording one event, including its timestamp, Log Type, and a human-readable description.
_Avoid_: log line, log record, event (too ambiguous in this context)

**Log File**:
The single append-only plaintext file that persists all log entries across script
sessions. Initialized on first run; deleted and recreated (rotated) when it exceeds the
configured maximum age. The only durable record of suppression actions.
_Avoid_: audit log, closure log (the filename predates multi-subsystem use)

**Log Rotation**:
The act of deleting the log file when it is older than the configured maximum age, which
causes a fresh file to be created on the next log write.
_Avoid_: log cleanup, log pruning

**Suppression Event**:
A log entry at Info level that records a completed suppression action: a process kill or
a service stop that reached the `STOPPED` state. These are the semantically significant
entries — they assert that the script's core purpose was carried out for a specific target.
_Avoid_: audit event, action log entry

---

## Testing

**Test Harness**:
The hand-rolled AutoIt testing infrastructure that runs the test suite and reports pass/fail results.
_Avoid_: test suite (overloaded; see below), test runner (implies a separate tool, which does not exist here)

**Assertion**:
A single pass/fail check in the test harness: a predicate applied to actual output that must hold for the test to pass.
_Avoid_: test, check, expectation (in the technical test-harness sense)
_See also_: Test Harness, Deterministic Test

**Test Case**:
One named boolean check with an optional expected/actual pair. Each test case maps to a
single observable property of the function under test.
_Avoid_: assertion (too granular — in this project one test case contains exactly one assertion), test (ambiguous)

**Test Function**:
An individual executable test within the Test Harness, covering one behavior or property of the module under test.
_Avoid_: test suite, spec, describe block (terminology from frameworks that do not exist here)

**Test Suite**:
The complete set of test functions in the harness, taken together. In this project the
suite is flat: all test functions are peers with no nesting or grouping beyond function
boundaries.
_Avoid_: spec file, test module

**Stub**:
An AutoIt function defined in the test harness that replaces a dependency with a fixed,
scripted return value, so that the function under test can be exercised without issuing
live Windows SCM calls.
_Avoid_: mock (a mock additionally verifies call count and arguments; nothing in this harness does that), fake (a fake has working internal logic; stubs here are fixed-value-only)

**Deterministic Test**:
A test that produces the same pass/fail result regardless of the state of the Windows
SCM, running services, or any other live system resource. All tests in this harness
except one are deterministic by design.
_Avoid_: unit test (see below for the distinction this project uses)

**Unit Test**:
A test case exercising a pure-logic or pure-mapping function — one that takes inputs and
returns outputs with no live system calls and no global state mutation. The harness
labels four groups as pure-logic or pure-mapping helpers that fall into this category.
_Avoid_: "unit" for tests that call the batch-stop function against a live SCM — those are integration tests

**Integration Test**:
A test that exercises the module against a live SCM connection, verifying behavior under real operating-system conditions.
_Avoid_: calling the empty-input test a unit test — it exercises live Windows APIs

**Environment Gate**:
The constraint that the test harness requires the Windows AutoIt runtime and therefore
cannot run in a Linux sandbox. Static analysis via the AutoIt compiler checker is also
Windows-only.
_Avoid_: platform constraint, OS requirement

---

## Architecture

**Deep Module**:
A module with a large amount of behaviour behind a small interface. The ServiceManager
module is the canonical example in this codebase: its public surface is a single function
with three parameters, behind which the entire two-phase batch algorithm, handle
lifecycle management, and outcome classification are hidden from callers.
_Avoid_: library (unless describing a loose collection of utilities), wrapper, adapter

**Seam**:
The location where a module's interface lives — the boundary that calling code crosses
into module internals. This codebase has two seams relevant to service stopping: one
between the main script's monitoring loop and the batch-stop operation, and one between
the ServiceManager module and the Windows service control API.
_Avoid_: boundary (overloaded)

**Module Extraction**:
The act of moving a coherent piece of behaviour out of a larger script or library into
its own module with a defined public interface. The ServiceManager module was created by
extracting and redesigning the service-stop behaviour that previously lived inline in
the main script.
_Avoid_: migration (unless referring specifically to updating the call sites after extraction)
