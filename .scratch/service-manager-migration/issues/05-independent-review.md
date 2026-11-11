# 05: Independent Code Review — All Modified .au3 Files

**What to build:** Three independent review agents (fresh context) inspect the final
state of each modified .au3 file. Cross-file audit for globals, constants, arrays,
includes, duplicate inventories, DllCall contracts, timing constants, and
documentation references. diagnosing-bugs for any BLOCKER/CRITICAL/MAJOR finding.

**Blocked by:** 04 (Integration must be complete and T04 code-review passed first)

**Status:** ready-for-agent

- [ ] Review agent 1: Stop Services Processes.au3 final hash
- [ ] Review agent 2: Includes/ServiceManager.au3 final hash
- [ ] Review agent 3: Tests/ServiceManager.Tests.au3 final hash
- [ ] Cross-file audit: globals, constants, arrays, includes, duplicate inventories,
      DllCall contracts, timing constants, documentation references
- [ ] Escalate BLOCKER/CRITICAL/MAJOR findings to diagnosing-bugs
- [ ] All findings resolved before T06
