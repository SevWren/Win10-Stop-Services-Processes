# Section 07 — Windows SCM Abstraction and GUI Interaction

**Scope**: Authoritative glossary entries for the Windows SCM Abstraction and GUI Interaction
domain areas. Produced by cross-audit of `GLOSSARY.md`, `DM-09-windows-scm-mapping.md`,
`DM-10-glossary-audit.md`, `Stop Services Processes.au3`, `docs/research/windows-scm-api.md`,
and `GLOSSARY-FORMAT.md`.

**Status**: Ready to apply to `GLOSSARY.md`.

**Applies to**: `GLOSSARY.md` entries — Service Control Manager (SCM), SCM Handle (new),
Service Handle, Service State, Tray Notification (new), Misc Popup (new), Toggle (new).
Progress Indication: not applicable (see note at end of file).

---

## Windows SCM Abstraction

---

**Service Control Manager (SCM)**:
The Windows component (`services.msc`) that is the authority for the lifecycle of all registered
services on the machine: starting, stopping, querying, and configuring them. The script acquires
a session-scoped connection at the start of each Batch Stop cycle and closes it when the cycle
completes.
_Avoid_: service manager, Windows service controller, SCM database

**Audit note — replaces current entry**: The current `GLOSSARY.md` definition names
`advapi32.dll` and `OpenSCManagerW`. Both are implementation details that belong in
`docs/research/windows-scm-api.md` (where they are fully documented), not in the domain
glossary. This replacement wording describes what the SCM *is* without exposing how the
code reaches it. See DM-09 Change 1 and DM-10 Section 4a.

---

**SCM Handle**:
An opaque value representing an open connection to the Service Control Manager, distinct from
a Service Handle. One SCM Handle is opened at the start of each Batch Stop cycle and covers
all per-service operations within that cycle.
_Avoid_: SCM connection, manager handle, database handle

**Audit note — new entry**: The glossary defines Service Handle (per-service) but has no term
for the SCM-level connection handle. The two objects have different lifetimes, different access
rights, and different semantics: the SCM Handle spans the whole batch; a Service Handle spans
one service. Conflating them has caused bugs in legacy code. This distinction must be named.
See DM-09 Change 5 (Option B) and DM-10 Section 3a.

---

**Service Handle**:
An opaque value that grants specific access rights to one registered service. Each handle is
opened with the minimum rights required for the intended operation and must be released exactly
once when the operation completes or fails.
_Avoid_: service reference, service object, service pointer

**Audit note — replaces current entry**: The current `GLOSSARY.md` definition names
`OpenServiceW`, `CloseServiceHandle`, `SERVICE_STOP`, and `SERVICE_QUERY_STATUS`. These are
Win32 API function names and access-right constants — implementation details documented in
`docs/research/windows-scm-api.md`. The domain concept is simply: an acquired, rights-scoped
capability to interact with one service, with a mandatory release. See DM-09 Change 2 and
DM-10 Section 4a.

---

**Service State**:
The lifecycle position of a registered service as reported by the SCM: one of seven named
values — `STOPPED`, `START_PENDING`, `STOP_PENDING`, `RUNNING`, `CONTINUE_PENDING`,
`PAUSE_PENDING`, or `PAUSED`. The integer encoding of each value is preserved verbatim in
the Initial State and Final State fields of a Result Row. See also: Stop-Eligible State.
_Avoid_: service status, current state, service condition

**Audit note — replaces current entry**: The current `GLOSSARY.md` definition names
`QueryServiceStatus` and `QueryServiceStatusEx` — Win32 API function names that are
implementation details. The state names themselves (`STOPPED`, `RUNNING`, etc.) are domain
vocabulary; the numeric codes (`(1)`, `(2)`, ...) are Windows platform constants documented
in `docs/research/windows-scm-api.md` (SERVICE_STATUS struct, `dwCurrentState` field). The
numeric encodings have been removed from the domain definition; contributors who need them
must consult the research file. See DM-09 Change 3 and DM-10 Sections 3b, 4b.

---

**Stop-Eligible State**:
A Service State from which a stop control can be accepted: `RUNNING`, `PAUSED`,
`PAUSE_PENDING`, or `CONTINUE_PENDING`. Services in `STOPPED`, `STOP_PENDING`, or
`START_PENDING` are not stop-eligible and are routed to `ALREADY_STOPPED`, pending-poll, or
`FAILED` respectively without a stop control being issued.
_Avoid_: stoppable, controllable, eligible service

**Audit note — new entry**: This classification is a deliberate project decision encoded in
the service-stop logic. It drives Phase 1 of Batch Stop and is referenced in log messages.
The concept was not previously named in the glossary. See DM-09 Change 4.

---

## GUI Interaction

---

**Tray Notification**:
A small tooltip displayed near the bottom-right corner of the desktop to report watchdog events
to the user. It auto-clears after 2 seconds and produces no sound and no Action Center entry.
Distinct from a Windows toast notification, which the script deliberately avoids.
_Avoid_: tray tip, tray alert, toast notification, system notification

**Code evidence** (`Stop Services Processes.au3`, lines 606-614, `#Region ;traytips`):
`_TrayNotify` calls `ToolTip()` positioned at `@DesktopWidth - 260, @DesktopHeight - 80`
and schedules `_ClearTrayNotify` via `AdlibRegister` with a 2000 ms delay. The choice of
`ToolTip()` over `TrayTip()` is intentional and documented in `CLAUDE.md` (User Notifications
section): `TrayTip` produces large toast notifications with Action Center entries on Windows
10/11; `ToolTip` does not. See DM-10 Section 1 (Tray Notification).

---

**Misc Popup**:
An application registration dialog from a third-party program that the script closes
automatically during the Monitoring Loop. The two known instances are the AdvancedRenamer
registration form (`TPleaseRegisterForm` window class) and the Sublime Text unregistered-copy
dialog.
_Avoid_: popup, dialog, window, registration dialog

**Code evidence** (`Stop Services Processes.au3`, lines 622-630, `_miscpopups`):
The function tests for two window identities — `[CLASS:TPleaseRegisterForm]` and the title
`"This is an unregistered copy"` — and calls `WinClose` on whichever is found. It is called
on every iteration of the active monitoring loop (line 176). The script comment notes it is
specific to the author's system. See DM-10 Section 1 (Misc Popup).

---

**Toggle**:
The user action (Shift+F1) that transitions the script between its idle state and its active
Monitoring Loop state. Each activation starts the loop; each subsequent press stops it.
_Avoid_: start, enable, activate, pause

**Code evidence** (`Stop Services Processes.au3`, lines 155-178, `ToggleScript`):
`$bScriptRunning` is flipped on each call; a `MsgBox` with a 1-second auto-dismiss confirms
the new state to the user. The monitoring `While` loop runs synchronously inside `ToggleScript`
while `$bScriptRunning` is `True`. See DM-10 Section 1 (Toggle).

---

## Progress Indication — Not Applicable

**Finding**: No progress indication mechanism exists in the current codebase.

The script has no progress bar, no percentage counter, no step indicator, and no staged UI
feedback during long operations. The closest candidates were evaluated and ruled out:

- The `MsgBox` calls in `ToggleScript` (lines 158, 162) confirm state transitions but are
  instantaneous and auto-dismiss after 1 second; they do not indicate progress through a
  multi-step operation.
- The `_TrayNotify` calls in `_PriorityWatchdog` report discrete events (priority restored,
  PID exited) after the fact; they are event notifications, not progress indicators.
- The Batch Stop operation (`_RunServiceBatchStop`) runs silently and logs results only after
  completion; there is no per-service UI feedback during the polling phase.

No glossary entry for Progress Indication is warranted. If a future implementation adds
progress feedback (e.g., a tray tooltip showing "Stopping 3 of 9 services..."), a new term
should be defined at that time.
