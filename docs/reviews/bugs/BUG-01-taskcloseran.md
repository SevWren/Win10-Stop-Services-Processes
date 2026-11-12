# BUG-01 — Dead Global `$taskcloseran`

**Source finding:** CR2-29 / CR2-11-global-scope.md Finding 11
**File under investigation:** `Stop Services Processes.au3`
**Variable:** `$taskcloseran`
**Declaration line:** 86 (current file; noted as line 91 in CR2-29 due to drift as lines were added above it)
**Status:** CONFIRMED dead code — safe to remove

---

## 1. Declaration

```autoit
Global $taskcloseran       = 0
```

Located in `#Region ;Variables/Logging`, line 86 of the current file.

- **Type:** Integer (implicitly — initialized to numeric literal `0`)
- **Scope modifier:** `Global` (mutable)
- **Initial value:** `0`

---

## 2. Is it ever READ anywhere in the file?

No.

A full-text search of `Stop Services Processes.au3` for `$taskcloseran` returns exactly one hit: the declaration line itself. No function body, conditional, expression, or log call references the variable as a source value.

---

## 3. Is it ever WRITTEN (beyond initialization)?

No.

The search returns no assignment sites (`$taskcloseran = ...`, `$taskcloseran += ...`, etc.) other than the initializer. It is never incremented, toggled, or reset anywhere in the file.

---

## 4. Historical analysis across all BackUp versions

Every backup snapshot in `BackUp/` (19 files spanning V0.02 through the most recent `.backup.au3`) declares `Global $taskcloseran = 0`. In every single version, that declaration is the **only occurrence**. The variable was never read or written in any version of this script.

One backup (`V0.03.au3`) contains a comment:

```autoit
; - $taskcloseran: Counter or flag (consider renaming for clarity, e.g., $iTaskCloseCount).
```

This comment was placed by an earlier review pass and confirms that even at that point the variable's intent was already unclear and no active use was found.

---

## 5. What was it likely for?

The name decodes as "task close ran" — a **boolean flag** (or possibly an integer counter) intended to record whether a "task close" operation had executed. This maps to the original design of the script, which predates the current `_KillProcessList()` / `ToggleScript()` architecture.

In early versions the script likely had a simpler structure: a single linear task-close block that ran once, and `$taskcloseran` was meant to guard against re-entry or to log that the block had fired. As the script evolved into a hotkey-driven, loop-based architecture (the current `While $bScriptRunning` model with timer-gated calls), the guard variable became redundant — the control flow was replaced by `$bScriptRunning`, `_CheckElapsedTime()`, and the loop structure itself.

The variable was never cleaned up during refactoring.

---

## 6. Is the CR2-29 finding correct?

Yes. CR2-29 is fully correct. The variable is:

- Declared but never read.
- Never written after initialization.
- Carrying no side effects (a `Global` integer declaration with value `0` has no I/O, no DllCall, no AutoIt state change).
- Present in every historical version without ever gaining a use site.

The CR2-29 label "Mysterious Name, unused variable" is accurate on both counts.

---

## 7. Is deleting it safe? Any side effects?

**Yes, deletion is safe. No side effects.**

Checklist:

| Risk | Assessment |
|---|---|
| Read-after-delete | No read site exists anywhere in the file. |
| Write-after-delete | No write site exists anywhere in the file. |
| Passed to any function | Never appears in a function call argument. |
| AU3Check `-d` flag | The `-d` flag checks for *undeclared* variables. Removing a declared-but-unused global eliminates one superfluous declaration; AU3Check will not error. |
| Cross-file usage | Searched all files in repo root and `Includes/`; zero hits outside the declaration line. |
| Companion `$sStringInstaller` | Also dead (confirmed by CR2-11); the two lines are adjacent. This report covers only `$taskcloseran`; `$sStringInstaller` is a separate finding. |

No conditional logic, no logging, no service or process operation depends on this variable. Removing the line is a pure dead-code deletion.

---

## 8. Fix

Remove line 86:

```autoit
Global $taskcloseran       = 0
```

The blank line between `$sStringInstaller` and the comment `; Process inventory` is preserved to maintain readability of the Variables/Logging region.

**Applied:** see diff below (fix was applied to `Stop Services Processes.au3` as part of this investigation).
