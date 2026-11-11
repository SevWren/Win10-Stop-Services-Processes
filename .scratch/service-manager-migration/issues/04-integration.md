# 04: Integrate ServiceManager into Main Script

**What to build:** Modify Stop Services Processes.au3 to wire _SM_StopServicesBatch()
at the service-monitoring boundary. Migrate touched paths to working-directory layout.
Add named timing constants. Preserve all 4 hotkeys, priority watchdog, popups,
logging, log rotation. Decide ServiceControl.au3 disposition.

**Blocked by:** 03 (ServiceManager.au3 must exist and be code-reviewed first)

**Status:** ready-for-agent

- [ ] Research subagent: verify HotKeySet, AdlibRegister, TimerInit, TimerDiff, _LogMessage patterns
- [ ] Add named timing constants (PROC_POLL_INTERVAL_SEC, SVC_POLL_INTERVAL_SEC, etc.)
- [ ] Replace _stopservicescustom() body with _SM_StopServicesBatch() call
- [ ] Migrate #include path for ServiceControl.au3 to relative "Includes\ServiceControl.au3"
- [ ] Migrate #include path for ServiceManager.au3 to relative "Includes\ServiceManager.au3"
- [ ] Migrate #AutoIt3Wrapper_Outfile_x64 to working-directory relative path
- [ ] Remove duplicate #include and HotKeySet entries
- [ ] Log each _SM result row outcome at appropriate log level
- [ ] AU3Check gate (NOT RUN — Windows only)
- [ ] Code-review subagent (independent): Standards + Spec axes
- [ ] Write docs/reviews/REVIEW-Stop-Services-Processes.au3.md
- [ ] Update README.md for changed paths and integration
