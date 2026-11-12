# DM-08 — Architecture Pattern Vocabulary

Branch: arch/service-manager-migration
Date: 2026-11-12
Focus: Module structure, seams, adapters, and design decisions in the new architecture.

---

## Purpose

This proposal fixes imprecise language in how the codebase's architecture is described. The
existing `docs/ARCHITECTURE.md` and `CLAUDE.md` use "module", "library", "wrapper", "adapter",
and "migration" without consistent meaning. That matters because imprecise terms produce confused
design conversations — contributors disagree on where a seam is, what belongs inside it, and
what the extraction decision actually changed.

Vocabulary here follows the codebase-design skill's definitions exactly. Terms that conflict
with those definitions are flagged and a canonical replacement is proposed.

---

## 1. What is ServiceManager.au3?

### Current language in the codebase

`docs/ARCHITECTURE.md` calls it the "NEW: authoritative service-stop module". `CLAUDE.md` calls
`ServiceControl.au3` a "custom DllCall service library". Neither term is precise enough to
reason about seams or depth.

### Analysis

`ServiceManager.au3` has:

- A **single public function**: `_SM_StopServicesBatch(ByRef $aNames, $iBatchTimeoutMs, $iPollIntervalMs)`
- A **small interface**: three parameters, one return type (a 2D array), two @error codes.
- A **large implementation**: two-phase algorithm, parallel pending arrays, per-service state
  routing, Win32 error classification, handle lifecycle management, and logging — all hidden from
  the caller.

That is the definition of a **deep module**: a large amount of behaviour behind a small interface.

The internal helpers (`_SM_GetServiceState`, `_SM_IsStopEligible`, `_SM_StateNeedsPolling`,
`_SM_Win32ErrToOutcome`, etc.) are **internal seams** — private to the module's implementation,
not part of the external interface. They exist for the module's own testability and clarity,
not for callers.

`ServiceManager.au3` is not:

- A **library**: a library is a collection of loosely related utilities with many independent
  entry points. `ServiceManager.au3` has one public entry point.
- A **wrapper**: a wrapper is a shallow module whose interface closely mirrors the thing it
  wraps. `ServiceManager.au3` does not mirror the Win32 SCM API — it hides the entire
  two-phase batch algorithm and handle lifecycle behind a single call.
- An **adapter**: an adapter fills a slot at a seam. `ServiceManager.au3` *is* the
  implementation; there is no seam with an alternative adapter on the other side. It is the
  module that *owns* the seam. See §3 on where the seam actually is.

**Canonical term: deep module.**

---

## 2. What is ServiceControl.au3?

### Analysis

`ServiceControl.au3` is an older general-purpose SCM utility collection: `_ServiceExists`,
`_ServiceRunning`, `_StartService`, `_StopService`, `_CreateService`, `_DeleteService`. Each
function opens the SCM independently, issues one operation, and closes. There is no shared
handle lifecycle or batching.

This matches the definition of a **library**: multiple independent, loosely related operations
with no shared state across calls. It is also relatively **shallow** — its interface closely
mirrors the Win32 operations it wraps.

`_StopService` in `ServiceControl.au3` is specifically shallow: it opens SCM, sends one stop
control, closes, and returns a binary success/failure. It does not query state before issuing
the control, does not wait for the transition, and does not classify why it failed. The
`ServiceManager.au3` module replaced this path precisely because of that shallowness.

**Canonical term: library (shallow).**

---

## 3. Where is the seam in this architecture?

The **seam** is the boundary between the main script's monitoring loop (`ToggleScript`) and the
service-stop operation. The seam lives at the call to `_SM_StopServicesBatch` (via
`_RunServiceBatchStop`).

Before the migration, the seam was at `_stopservicescustom()` / `_StopService()` — but that
seam was architecturally weak: the caller could not distinguish STOPPED from FAILED from
TIMED_OUT. The seam existed, but the interface crossing it was too thin to be useful.

After the migration, the same seam location is preserved, but the interface is now rich:
`_RunServiceBatchStop` reads a 2D result array and routes each per-service outcome to the
appropriate log level. The seam location did not move; the depth behind it increased.

**Seam location:** between `ToggleScript`'s monitoring loop and the service-stop operation,
specifically at the `_RunServiceBatchStop()` call in the main script.

There is a second, shallower seam: between `ServiceManager.au3` and `advapi32.dll`. This is
where the DllCall adapter pattern lives — `advapi32.dll` is the external system being adapted
to. The `DllCall` lines are the adapters at this lower seam.

---

## 4. Is `#include` a canonical architectural term?

No. `#include` is an **AutoIt preprocessor directive** — a compile-time textual inclusion
mechanism. It is an implementation detail of how AutoIt composes source files, not a module
boundary or an architectural concept.

The fact that `ServiceManager.au3` is included via `#include` does not make the relationship
between the main script and `ServiceManager.au3` an "`#include` relationship" in any
architectural sense. The architectural relationship is **caller → module across a seam**. The
`#include` is the mechanism AutoIt uses to make the module's functions available to the caller;
it has no bearing on where the seam is or what the interface looks like.

**Do not use `#include` as an architectural term.** Use "module", "seam", "interface", and
"caller" instead.

---

## 5. What does "migration" mean in this context?

The branch is `arch/service-manager-migration`. The word "migration" is used in two senses in
this codebase, and they are different things.

### Sense 1: Module extraction (what actually happened)

The stop-services behaviour was extracted from `_stopservicescustom()` in the main script (and
from `_StopService()` in `ServiceControl.au3`) and **rewritten as a new deep module**
(`ServiceManager.au3`) with a richer interface.

This is a **module extraction with interface redesign**. The term "migration" understates it:
this was not a mechanical lift-and-shift of existing code into a new file. The batch algorithm,
the two-phase design, the per-service result rows, and the outcome classification were all new.

### Sense 2: Call-site migration (a consequence of sense 1)

The main script's monitoring loop was updated to call `_SM_StopServicesBatch` instead of
`_stopservicescustom`. That is a **call-site migration** — updating callers to cross the new
seam.

**Canonical terms:**
- The extraction decision: **module extraction** (with interface redesign).
- Updating the main script: **call-site migration**.
- Calling the whole thing "service manager migration": acceptable as a branch name shorthand,
  but imprecise as architectural language.

---

## 6. Proposals for GLOSSARY.md

The following terms are proposed for addition to `GLOSSARY.md`. They are
architecture-pattern terms specific to this project's design decisions, not general
programming concepts.

**Deep Module** (candidate term):
A module with a large amount of behaviour behind a small interface. `ServiceManager.au3`
is the canonical example in this codebase.
_Avoid_: library (unless describing a loose collection of utilities), wrapper, adapter
(unless the focus is on a seam with alternatives).

**Seam** (candidate term):
The location where a module's interface lives — where calling code crosses into module
internals. This codebase has two seams relevant to service stopping: one between the main
script's monitoring loop and `_SM_StopServicesBatch`, and one between `ServiceManager.au3`
and `advapi32.dll`.
_Avoid_: boundary (overloaded).

**Module Extraction** (candidate term):
The act of moving a coherent piece of behaviour out of a larger script or library into its
own module with a defined public interface. What happened when `ServiceManager.au3` was
created.
_Avoid_: migration (unless referring specifically to the call-site update).

Note: These are proposals only. Per the domain-modeling skill, GLOSSARY.md should not be
edited directly from a proposals document. Each term should be evaluated and added to
GLOSSARY.md during a live session when the term is resolved.

---

## 7. Tensions and open questions

**Tension: ServiceControl.au3 is now a split responsibility.**
After the migration, `ServiceControl.au3` owns non-stop helpers (`_ServiceExists`,
`_ServiceRunning`, `_StartService`, `_CreateService`, `_DeleteService`) but its `_StopService`
function is a dead path on the monitoring hot path. The seam between the two files is defined
by the decision documented in D-002 (not to use `_StopService` for stop operations). If
`_StopService` in `ServiceControl.au3` is ever called by a caller not visible in this
codebase, the two files are coupled by that undocumented dependency.

**Open question: Is there a real seam between ServiceControl.au3 and ServiceManager.au3?**
Currently there is not. Both are included in the same main script. There is no interface
through which one calls the other. If the design intent is that all *stop* operations go
through `ServiceManager.au3` and all *other* SCM operations go through `ServiceControl.au3`,
that is a **boundary by convention**, not a seam enforced by an interface. Worth noting in an
ADR (see ADR-0001 proposal).
