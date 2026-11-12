# DM-02 — Process Management Domain Model Proposal

Analysis of process management concepts in `Stop Services Processes.au3`. Covers five
term families: Process, PID, Priority Level, Watchdog, and AutoClose. Proposes precise
glossary entries, calls out gaps and ambiguities in the current GLOSSARY.md, and flags
one ADR candidate.

---

## 1. Findings from code analysis

### 1.1 "Process" is used in two senses and they are not distinguished

The codebase uses "process" to mean two different things:

1. **A running Windows executable** — an OS-level unit identified by a numeric PID,
   with a priority class, addressable via `ProcessExists`, `ProcessClose`,
   `ProcessSetPriority`. This is what `_CloseInstaller()` operates on.

2. **A service's host process** — `TrustedInstaller` appears in both `$sProcesses[]`
   (killed by `_CloseInstaller`) and in `$aServiceNames[]` (stopped via SCM by
   `_SM_StopServicesBatch`). The same name refers to fundamentally different OS objects
   depending on context.

The current glossary defines "Service Inventory" and "Process Inventory" as separate
lists, which implicitly acknowledges the distinction, but neither the glossary nor the
code comments define what a "Process" *is* in contrast to a "Service". This is the
single most important gap.

**A "Process" in this codebase is an OS executable instance managed via kernel32.dll /
AutoIt `ProcessXxx` functions. A "Service" is an OS object managed via the Service
Control Manager (advapi32.dll). They are entirely different Windows subsystems.
`TrustedInstaller` happens to be both: its service name is `TrustedInstaller`, and when
running it has a process named `TrustedInstaller.exe`.**

### 1.2 "PID" is used but not defined

PID (Process ID) appears throughout: in `LockProcessPriority`, `_PriorityWatchdog`,
`_GetProcessPriorityByPID`, and all three watchdog parallel arrays. It is a numeric
handle into the Windows process table. Its scope and lifetime matter: a PID is only
valid while the process is alive. The watchdog handles PID death explicitly (the
`ProcessExists` check before every operation). This lifecycle behavior is not captured
anywhere in the glossary.

### 1.3 Priority levels: two incompatible numbering schemes coexist

The code uses two entirely different sets of constants for the same six priority levels:

| Human name    | AutoIt const (`ProcessSetPriority`) | Windows API const (`GetPriorityClass`) |
|---------------|-------------------------------------|----------------------------------------|
| Idle          | `$PROCESS_IDLE` = 0                 | `$IDLE_PRIORITY_CLASS` = 0x40          |
| Below Normal  | `$PROCESS_BELOWNORMAL` = 1          | `$BELOW_NORMAL_PRIORITY_CLASS` = 0x4000|
| Normal        | `$PROCESS_NORMAL` = 2               | `$NORMAL_PRIORITY_CLASS` = 0x20        |
| Above Normal  | `$PROCESS_ABOVENORMAL` = 3          | `$ABOVE_NORMAL_PRIORITY_CLASS` = 0x8000|
| High          | `$PROCESS_HIGH` = 4                 | `$HIGH_PRIORITY_CLASS` = 0x80          |
| Real-time     | `$PROCESS_REALTIME` = 5             | `$REALTIME_PRIORITY_CLASS` = 0x100     |

The current glossary entry "Priority Class" describes both sets in a single paragraph,
which conflates two distinct concepts. The Windows API term is "Priority Class"; the
AutoIt term is "Priority Constant" (or in AutoIt's own docs, the integer argument to
`ProcessSetPriority`). These should be separate glossary entries, with a clear
cross-reference and the conversion function named.

`SetProcessPriority` (the hotkey function) only exposes levels 1–3 (Below Normal,
Normal, Above Normal) via its `InputBox`. `LockProcessPriority` exposes 0–5 (all six).
The asymmetry is intentional (Realtime is dangerous) but is a domain behavior, not a
term definition — it belongs in code comments, not the glossary.

### 1.4 "Watchdog" needs a precise definition

The term "watchdog" is used in `LockProcessPriority`, `_PriorityWatchdog`,
`$aPriorityWatchPIDs`, log type `"PriorityWatchdog"`, `$PRIORITY_WATCHDOG_MS`, and the
tray notification prefix `"[Priority Watchdog]"`. The current glossary entry "Priority
Watchdog" describes the implementation mechanism (AdlibRegister, 10 seconds, three
parallel arrays). What it lacks is a crisp definition of what a watchdog *is* as a
concept: an autonomous periodic check that detects and repairs unwanted state change.

Additionally, "drift" is used in log messages (`"Priority drift on PID …"`) but not
defined. Drift is the concept that a process's priority has been changed by an external
agent (the OS scheduler, another tool, the process itself) away from the locked target.
This is the trigger condition for the watchdog's restore action.

### 1.5 "AutoClose" is not a term in this codebase

The task brief mentions "AutoClose" as a term needing precision. After searching the
code, `AutoClose` does not appear as a function, variable, or comment. The concept of
closing/terminating processes is handled by `_CloseInstaller()` via `ProcessClose()`.
There is no "AutoClose" term to define. The correct canonical term for this operation
is **Process Kill** (the act of `_CloseInstaller` calling `ProcessClose` on a targeted
executable name).

---

## 2. Proposed glossary additions / changes

The following entries are proposed for addition to `GLOSSARY.md`. Entries marked
**CHANGE** replace or sharpen an existing entry; entries marked **NEW** are absent.

---

### NEW — Process

A running Windows executable instance, addressable by PID and managed via `kernel32.dll`
(`OpenProcess`, `GetPriorityClass`) and AutoIt's `ProcessXxx` functions. Distinct from
a Service: a process has no SCM entry and cannot be started/stopped via `advapi32.dll`.
_Avoid_: task, program, executable (use "process" unless referring specifically to the
`.exe` file on disk)

---

### NEW — PID (Process ID)

The numeric identifier Windows assigns to a running process. Valid only for the
lifetime of the process; once the process exits the PID may be reassigned. Any code
holding a PID must re-validate it with `ProcessExists` before use.
_Avoid_: process handle (a handle is a different Windows object returned by `OpenProcess`)

---

### CHANGE — Priority Class (replace current single entry with two entries)

**Priority Class** (Windows API term):
One of six values returned by `GetPriorityClass` (`kernel32.dll`): `IDLE_PRIORITY_CLASS`
(0x40), `BELOW_NORMAL_PRIORITY_CLASS` (0x4000), `NORMAL_PRIORITY_CLASS` (0x20),
`ABOVE_NORMAL_PRIORITY_CLASS` (0x8000), `HIGH_PRIORITY_CLASS` (0x80),
`REALTIME_PRIORITY_CLASS` (0x100). These are Windows API hex constants.
_Avoid_: priority constant, priority level (when the Windows API layer is meant)

**AutoIt Priority Constant** (AutoIt layer term):
The integer (0–5) passed to `ProcessSetPriority` and stored in
`$aPriorityWatchTargets[]`: 0=Idle, 1=BelowNormal, 2=Normal, 3=AboveNormal, 4=High,
5=Real-time. These are AutoIt-specific and do not match Windows API hex values.
Conversion between the two schemes is performed by `_WinAPIPriorityClassToAutoItConst()`.
_Avoid_: priority class (when the AutoIt integer layer is meant)

---

### NEW — Priority Drift

The condition in which a watched process's current Priority Class differs from its
locked AutoIt Priority Constant. Drift is caused by an external agent (OS scheduler,
another tool, the process itself) changing the process's priority after it was locked.
Detection and correction of drift is the sole responsibility of the Priority Watchdog.
_Avoid_: priority change, priority mismatch

---

### CHANGE — Priority Watchdog (replace current entry)

An autonomous periodic mechanism that detects and corrects Priority Drift for every PID
in the watchlist. It is registered once via `AdlibRegister` when the first PID is
added, fires every `$PRIORITY_WATCHDOG_MS` (10 seconds), and unregisters itself
(`AdlibUnRegister`) when the watchlist is empty. Per tick it also evicts dead PIDs
(those where `ProcessExists` returns false). Implemented in `_PriorityWatchdog()` with
state held in three parallel global arrays: `$aPriorityWatchPIDs`,
`$aPriorityWatchTargets`, `$aPriorityWatchNames`.
_Avoid_: priority monitor, priority keeper

---

### NEW — Watchlist

The set of PIDs currently under Priority Watchdog supervision. Maintained as three
parallel global arrays keyed by array index. A PID may appear at most once. Entries are
added by `LockProcessPriority` and removed by `_PriorityWatchdog` on death or
(implicitly) only by process exit — there is no user-initiated remove path in the
current implementation.
_Avoid_: watch array, priority array

---

### NEW — Process Kill

The act of `_CloseInstaller()` calling AutoIt's `ProcessClose()` on a process named in
the Process Inventory. A process kill targets all running instances of the given
executable name without knowledge of PID. It runs every `$PROC_POLL_INTERVAL_SEC`
(2 seconds) while the monitoring loop is active.
_Avoid_: process stop, process close (ProcessClose is the AutoIt function name, not the
domain term), terminate

---

### CHANGE — Process Inventory (note to sharpen)

Current entry is accurate. Recommend adding one clarifying sentence: "Entries are
executable base names (e.g., `TrustedInstaller.exe`), not service names — the same
string `TrustedInstaller` in the Service Inventory refers to the SCM service, a distinct
object."

---

## 3. Process vs. Service — the core distinction

The glossary currently has no entry that states, clearly and in one place, what
distinguishes a process from a service. This is the highest-value gap to close, because
`TrustedInstaller` straddles both worlds and will confuse any future reader.

Recommended addition (brief, as the glossary format requires):

**Service** (if not already present, and it is not):
A Windows OS component registered with the Service Control Manager, manageable via
`advapi32.dll`. A service may or may not be backed by a running process at any given
moment. Stopping a service via SCM is different from killing its host process.
_Avoid_: daemon, background process (which implies a process, not a service)

This would sit alongside the existing "Service Control Manager (SCM)" entry and give
readers a contrast term for "Process".

---

## 4. ADR candidate

### ADR candidate: Two-layer priority representation with mandatory conversion

**Warrants an ADR.** All three criteria are met:

1. **Hard to reverse**: the dual-constant scheme is baked into `_GetProcessPriorityByPID`
   (reads Windows API hex), `ProcessSetPriority` (writes AutoIt integer), all three
   watchdog arrays (store AutoIt integers), and `_WinAPIPriorityClassToAutoItConst`
   (the conversion bridge). Collapsing to a single scheme would require touching every
   site that reads or writes priority.

2. **Surprising without context**: a reader seeing `$iPriorityConst = 2` stored in
   `$aPriorityWatchTargets[]` and then passed directly to `ProcessSetPriority` has no
   reason to know that `GetPriorityClass` would return `0x20` for the same "Normal"
   level. Without the conversion function and its comment, the mismatch is invisible
   and the bug would be silent (wrong priority silently accepted).

3. **Result of a real trade-off**: the alternative — storing Windows API hex constants
   throughout — would require converting at every `ProcessSetPriority` call site and
   would make the watchdog arrays harder to read. The alternative of storing human
   strings would add a second conversion layer. The chosen approach (AutoIt integers as
   the internal canonical form, convert-on-read from the Windows API) is the least-bad
   option but is not obvious.

Proposed ADR file: `docs/adr/0001-autoit-priority-constants-as-canonical-form.md`

Proposed content:

```
# AutoIt priority integers as the internal canonical form for process priority

The Windows GetPriorityClass API returns hex values (e.g., 0x20 for Normal) that have
no relationship to the integers AutoIt's ProcessSetPriority accepts (e.g., 2 for Normal).
We chose to store AutoIt integers (0–5) as the single canonical form throughout the
watchdog arrays and all priority-bearing variables, converting from Windows API hex only
at the read boundary (_WinAPIPriorityClassToAutoItConst). The alternative of storing
Windows API hex constants was rejected because every ProcessSetPriority call site would
then require a conversion, and the watchdog arrays would hold values that are not
directly usable without transformation. The conversion function is the single point of
coupling between the two schemes.
```

---

## 5. Terms that do NOT need glossary entries

- `AdlibRegister` / `AdlibUnRegister` — AutoIt built-in functions; general AutoIt
  programming concepts, not domain terms.
- `ProcessClose`, `ProcessSetPriority`, `ProcessExists` — AutoIt API surface; same.
- `OpenProcess`, `GetPriorityClass`, `CloseHandle` — Windows API; same.
- `TOCTOU` (time-of-check/time-of-use) — general concurrency concept; not domain-specific.
- Log level integers (0, 1, 2) — these are configuration, not domain vocabulary.

---

## 6. Summary of proposed GLOSSARY.md changes

| Action | Term | Reason |
|--------|------|--------|
| NEW | Process | Core concept; missing entirely |
| NEW | PID | Used throughout; lifetime semantics undocumented |
| NEW | Priority Drift | Trigger condition for watchdog; used in log messages but undefined |
| NEW | Watchlist | The data structure behind the watchdog; needs a name |
| NEW | Process Kill | The domain action of `_CloseInstaller`; "close" is ambiguous |
| NEW | Service | Contrast term for Process; absence creates confusion around TrustedInstaller |
| CHANGE | Priority Class | Split into "Priority Class" (Windows API) and "AutoIt Priority Constant" (AutoIt layer) |
| CHANGE | Priority Watchdog | Add the concept of "what a watchdog is" before describing the implementation |
| SHARPEN | Process Inventory | Add one sentence distinguishing from Service Inventory for `TrustedInstaller` case |
