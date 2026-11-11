---
updated: 2026-11-11
---

# Blockers

## B-001 — AU3Check Not Available in Linux Sandbox (2026-11-11)

**Status**: KNOWN, MITIGATED

AU3Check is a Windows binary. The Maton sandbox runs Linux. AU3Check static analysis
cannot be executed here. All `.au3` files are written to satisfy the `-q -d -w 1 -w 2 -w 3 -w 4`
flags by construction (following CLAUDE.md conventions strictly), but the gate is
marked `NOT RUN — Windows environment required` in IMPLEMENTATION-AND-VERIFICATION.md.

**Mitigation**: Code is written following CLAUDE.md conventions. The pre-commit hook is
installed so it fires when a Windows developer checks out the branch.

## B-002 — AutoIt Compiler Not Available in Linux Sandbox (2026-11-11)

**Status**: KNOWN, MITIGATED

AutoIt3Wrapper and the AutoIt compiler are Windows-only. x86 and x64 compilation of
`.exe` artifacts cannot be performed here. Compilation gates in TICKET-06 are marked
`NOT RUN — Windows environment required`.

**Mitigation**: Source `.au3` files are written per CLAUDE.md conventions. Compilation
is left to the Windows developer workflow.

## B-003 — Live Service Stop Tests Require Windows Runtime (2026-11-11)

**Status**: KNOWN, SCOPED

The deterministic test harness in `Tests/ServiceManager.Tests.au3` can be run on Windows
only. Linux static analysis confirms code structure; runtime behavior is NOT claimed.
