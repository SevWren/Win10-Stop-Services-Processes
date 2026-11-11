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
