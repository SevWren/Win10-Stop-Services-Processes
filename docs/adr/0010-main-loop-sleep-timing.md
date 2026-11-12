# Main loop sleep timing: 50 ms passive loop, 500 ms active monitoring loop

The script contains two distinct loops with different sleep values, and CR-09 finding P-05 conflated them. The passive main loop (`While 1 / Sleep(50) / WEnd`) retains the CLAUDE.md baseline of 50 ms and is responsible for hotkey and tray responsiveness. The active monitoring loop inside `ToggleScript()` uses `Sleep($MAIN_LOOP_SLEEP_MS)` where `$MAIN_LOOP_SLEEP_MS = 500`. The 500 ms value is correct there because all real work in that loop is gated on `_CheckElapsedTime()` timers (`$PROC_POLL_INTERVAL_SEC = 2`, `$SVC_POLL_INTERVAL_SEC = 10`); the sleep merely yields CPU between timer checks, and 500 ms granularity is sufficient to wake well within those multi-second windows.

## Considered Options

- **50 ms for both loops**: retains maximum responsiveness everywhere but burns 10x more CPU in the active monitoring loop for no benefit — the timer gates already enforce the 2 s / 10 s intervals regardless of how fast the loop spins.
- **500 ms for the active monitoring loop, 50 ms for the passive main loop** *(chosen)*: passive loop stays at 50 ms so hotkeys and tray events remain snappy; active loop uses 500 ms because the coarsest timer it checks fires every 2 000 ms, making anything finer than ~500 ms needlessly tight.
- **500 ms for both loops**: would degrade hotkey and tray responsiveness, contradicting the CLAUDE.md requirement for a responsive main loop and the spec's "preserved behavior" gate.

## Consequences

- Hotkey (`Shift+F1`, `ScrollLock+Pause`, etc.) and tray responsiveness are unaffected — they are driven by the passive 50 ms loop, unchanged from the baseline.
- The active monitoring loop wakes at most 500 ms late relative to any timer expiry. Given the shortest poll interval is 2 000 ms, the worst-case latency is 500 ms (25% overshoot), which is acceptable for a background suppression tool.
- CPU load in the active monitoring loop is approximately 10x lower than it would be at 50 ms. This matters because the active loop also calls `_MiscPopups()` on every iteration, so a tighter sleep would increase that call rate proportionally.
- Future changes that add a sub-500 ms timer to the active monitoring loop would require lowering `$MAIN_LOOP_SLEEP_MS` to match; the constant provides a single definition point for that adjustment.
