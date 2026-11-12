# 01: Discover and Freeze the Baseline

**What to build:** Read and record the complete current state of the repository:
all source files, includes, process and service inventories, timing values, output
directives, runtime paths, compilation directives, known broken behaviors, and
toolchain availability. Produce `docs/BASELINE-INVENTORY.md`.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] Run git status --short, record root and branch
- [ ] Read Stop Services Processes.au3 completely — trace every call site
- [ ] Read Includes/ServiceControl.au3 completely
- [ ] Read test_process_close.au3
- [ ] Record all process names (both arrays), service names, timing values
- [ ] Record all #AutoIt3Wrapper directives and output paths
- [ ] Record all #include directives and note duplicates
- [ ] Record all HotKeySet registrations and note duplicates
- [ ] Discover AutoIt / Au3Check / compiler availability in environment
- [ ] Write docs/BASELINE-INVENTORY.md with observed facts only

## Status: CLOSED

All baseline discovery work was completed and recorded.

**What was delivered:**
- `docs/BASELINE-INVENTORY.md` exists and records the full pre-migration state: all source files, process and service inventories, timing values, output directives, hardcoded machine-specific paths, duplicate `#include` pairs, duplicate `HotKeySet` entries, and the undeclared `$iLastStopProcesses` variable.
- Toolchain availability (AU3Check, AutoIt3, AutoIt3Wrapper — all Windows-only, unavailable in Linux sandbox) was recorded and cross-referenced to `docs/wiki/blockers.md` (B-001, B-002, B-003).

**Artifacts as evidence:**
- `/home/vercel-sandbox/repo/docs/BASELINE-INVENTORY.md`
