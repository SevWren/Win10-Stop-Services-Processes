# Glossary Section — Process Management

Domain vocabulary for the process management area of Win10-Stop-Services-Processes. Covers
the nine core terms governing how the script identifies, terminates, and monitors Windows
processes. Cross-audited against `GLOSSARY.md` (current), `DM-02-process-management.md`,
`DM-10-glossary-audit.md`, and `Stop Services Processes.au3`.

---

## Audit notes before definitions

### Split applied: "Priority Class" entry in current GLOSSARY.md

The current `GLOSSARY.md` entry for **Priority Class** conflates two incompatible numbering
schemes in a single paragraph: the Windows API hex constants returned by `GetPriorityClass`
(`kernel32.dll`) and the AutoIt integer constants (0–5) passed to `ProcessSetPriority`. These
are entirely separate layers with no numeric correspondence (e.g., "Normal" is `0x20` in one
scheme and `2` in the other). The current entry warns about the difference and names the
conversion function, but keeping them in one entry preserves the conflation.

**This section splits them into two entries: "Priority Class" (Windows API) and "AutoIt
Priority Constant" (AutoIt layer).** The conversion bridge function
`_WinAPIPriorityClassToAutoItConst()` is named under both entries.

The current `GLOSSARY.md` entry should be replaced by these two entries when this section is
promoted.

### Implementation contamination in current GLOSSARY.md entries

Per `GLOSSARY-FORMAT.md` rules, function names, variable names, interval values, and DLL
names are implementation details and do not belong in a glossary. The current entries for
**Priority Watchdog** and **Process Inventory** contain such details. The definitions below
are concept-only; implementation details have been moved to code comments and
`docs/ARCHITECTURE.md` where they already live.

### Factual correction: Process Inventory

The current `GLOSSARY.md` entry for Process Inventory references `$sProcesses2[]`. That
array does not exist in the current codebase (`main` branch). The current script declares
only `$sProcesses[18]`. The definition below corrects this.

---

## Language

**Process**:
A running Windows executable instance, identified by a numeric PID and managed via
`kernel32.dll` and AutoIt's `ProcessXxx` functions. Distinct from a Service: a process has
no entry in the Service Control Manager and cannot be started or stopped through SCM. The
name `TrustedInstaller` illustrates the distinction — when running, it is both a process
(terminated by the Process Kill cycle) and a service (stopped by the Service batch-stop
cycle); they are different OS objects managed by different subsystems.
_Avoid_: task, program, executable (use "process" unless referring specifically to the `.exe`
file on disk)

---

**PID (Process ID)**:
The numeric identifier Windows assigns to a running process instance. A PID is valid only
for the lifetime of the process; once the process exits the PID may be reassigned to an
unrelated process. Any code that holds a PID across a time boundary must re-validate it with
`ProcessExists` before acting on it — failure to do so is a TOCTOU hazard. The Priority
Watchdog handles this explicitly by rechecking `ProcessExists` before every priority read and
before every restore attempt.
_Avoid_: process handle (a handle is a distinct Windows kernel object returned by
`OpenProcess`, not the numeric ID itself)

---

**Priority Class**:
The scheduling tier assigned to a process by the Windows kernel, expressed as one of six
named levels: Idle, Below Normal, Normal, Above Normal, High, Real-time. When read via the
Windows API (`GetPriorityClass`, `kernel32.dll`), each level is represented by a hex
constant: `IDLE_PRIORITY_CLASS` (0x40), `BELOW_NORMAL_PRIORITY_CLASS` (0x4000),
`NORMAL_PRIORITY_CLASS` (0x20), `ABOVE_NORMAL_PRIORITY_CLASS` (0x8000),
`HIGH_PRIORITY_CLASS` (0x80), `REALTIME_PRIORITY_CLASS` (0x100). These hex values have no
numeric relationship to AutoIt Priority Constants — always convert via
`_WinAPIPriorityClassToAutoItConst()`.
_Avoid_: priority level, priority constant (when the Windows API hex layer is meant); do not
use the hex values directly as inputs to AutoIt functions

---

**AutoIt Priority Constant**:
The integer (0–5) that AutoIt's `ProcessSetPriority` accepts as its priority argument, and
the canonical internal form in which target priorities are stored throughout this codebase.
The six values are: 0 = Idle, 1 = Below Normal, 2 = Normal, 3 = Above Normal, 4 = High,
5 = Real-time. These integers have no numeric correspondence to Windows API Priority Class
hex values — conversion from Windows API hex to AutoIt integer is performed by
`_WinAPIPriorityClassToAutoItConst()`, which is the single point of coupling between the two
schemes.
_Avoid_: priority class (when the AutoIt integer layer is meant), priority level (ambiguous
between the two schemes)

---

**Priority Drift**:
The condition in which a watched process's current Priority Class no longer matches the
AutoIt Priority Constant that was locked for it. Drift is caused by an external agent — the
OS scheduler, another tool, or the process itself — changing the process's priority after it
was locked. Priority Drift is the sole trigger condition for the Priority Watchdog's restore
action; the watchdog takes no action when no drift is detected.
_Avoid_: priority change, priority mismatch (both are vague; "drift" specifically means
external deviation from a locked target)

---

**Priority Watchdog**:
An autonomous periodic mechanism that detects Priority Drift for every PID in the Watchlist
and restores the locked priority when drift is found. It is activated when the first PID is
added to the Watchlist and deactivates itself when the Watchlist becomes empty. On each tick
it also evicts any PID whose process has exited. The Watchdog fires on a fixed interval
regardless of how many PIDs are in the Watchlist — a single timer covers all watched PIDs.
_Avoid_: priority monitor, priority keeper, priority checker

---

**Watchlist**:
The set of PIDs currently under Priority Watchdog supervision. A PID is added to the
Watchlist when a user locks a priority via the Lock Priority hotkey. A PID is removed from
the Watchlist automatically when the Priority Watchdog detects that the process has exited;
there is no user-initiated removal path in the current implementation. Each PID may appear
in the Watchlist at most once — duplicate entries are rejected at lock time.
_Avoid_: watchdog list, PID list, monitored processes, watch array

---

**Process Kill**:
The act of force-terminating every running instance of a named executable, performed without
knowledge of PID and with no graceful shutdown path. This is the domain term for the
periodic action that targets processes in the Process Inventory. AutoIt's `ProcessClose`
(which calls `TerminateProcess` internally) is the mechanism; "Process Kill" is the domain
concept.
_Avoid_: process stop (implies graceful shutdown, which does not occur here), process close
(`ProcessClose` is the function name, not the domain term), terminate

---

**Process Inventory**:
The fixed set of executable names targeted for Process Kill on each process-kill cycle. All
entries are executable base names (e.g., `TrustedInstaller.exe`). The same string
`TrustedInstaller` also appears in the Service Inventory, but there it refers to the SCM
service name — a distinct OS object managed by a different subsystem. The Process Inventory
contains only a single array of names; a previously referenced second array (`$sProcesses2`)
does not exist in the current codebase.
_Avoid_: process list, kill list, target list

---

## Cross-reference: terms defined elsewhere that relate to this section

- **Service** — the complementary OS concept to Process; defined (or proposed for
  definition) in the Service Management section. The contrast between Process and Service is
  essential context for understanding `TrustedInstaller`'s dual presence.
- **Service Inventory** — the counterpart set for service-stop operations; defined in the
  current `GLOSSARY.md`.
- **Timing Constants** — the intervals that govern how often the Process Kill cycle and the
  Priority Watchdog fire; defined in the current `GLOSSARY.md` (subject to the name
  corrections identified in `DM-10-glossary-audit.md` §2b).
