---
updated: 2026-11-12
---

# Agent Environment

## Codebase Files

The following `.au3` source files are active in this branch. Any agent writing or reviewing
code must account for all of them.

| File | Include requirement | Notes |
|---|---|---|
| `Stop Services Processes.au3` | — (entry point) | Main script; defines timing globals used by `ServiceManager.au3` |
| `Includes/ServiceManager.au3` | `#include "Includes\ServiceManager.au3"` | Must be included in the main script; provides `_SM_StopServicesBatch` |
| `Includes/ServiceControl.au3` | `#include "Includes\ServiceControl.au3"` | Retained; not used for stop operations |
| `Tests/ServiceManager.Tests.au3` | `#include "Includes\ServiceManager.au3"` (at top of test file) | Test harness only; never `#include`d by the main script |

Include paths are working-directory-relative. No hardcoded absolute paths in `#include`
directives. If `ServiceManager.au3` is not included, `_SM_StopServicesBatch` is undefined and
the main script will fail AU3Check with an undeclared-function error.

## Test Harness

The deterministic test harness for `ServiceManager.au3` lives at:

```
Tests/ServiceManager.Tests.au3
```

The harness does not make live Windows SCM calls. It exercises `_SM_StopServicesBatch` and the
internal helper functions using injected state, verifying outcome classification, result-row
structure, and edge cases (empty input, SCM failure, timeout, all five outcome codes).

### Linux sandbox limitation

AutoIt is a Windows-only runtime. In this Linux sandbox, `.au3` files cannot be executed
natively — `AutoIt3.exe` and `AutoIt3_x64.exe` are not available. Tests run in a constrained
mode: syntax can be validated with AU3Check (see below), but functional test execution requires
a Windows environment with AutoIt 3.3.16.x installed.

## AU3Check Availability

AU3Check is available in this sandbox for syntax validation:

```
au3check -q -d -w 1 -w 2 -w 3 -w 4 <file.au3>
```

Use it to catch undeclared variables, type mismatches, and warning-level issues before
committing. All `.au3` files in this repo configure these flags via
`#AutoIt3Wrapper_AU3Check_Parameters` so the same flags are enforced by AutoIt3Wrapper on
Windows. A pre-commit hook at `.git/hooks/pre-commit` also enforces AU3Check before every
commit.

AU3Check does not execute code — it performs static analysis only. It will not catch runtime
failures (e.g., a DllCall returning NULL because a service does not exist). Those are exercised
by the test harness on Windows.

## Pit-of-Success Improvements

### Coding Standards
`CODING_STANDARDS.md` at the repo root encodes the reviewer-enforced standards from `CLAUDE.md`.
The code-review subagent reads this during the Standards axis review.

### Research Gate
Any subagent writing `.au3` code must first produce a research note in `docs/research/` citing
the official AutoIt documentation (`https://www.autoitscript.com/autoit3/docs/`) for each
function used.

### Code-Review Gate
Every ticket that modifies `.au3` source must pass a dedicated, independent code-review agent
running both Standards and Spec axes before the ticket is closed.

## Data Sources

- Syntax validation: AU3Check (available in this sandbox)
- AutoIt official docs: https://www.autoitscript.com/autoit3/docs/
- Windows SCM API: https://learn.microsoft.com/en-us/windows/win32/services/service-functions

## No-Workarounds Rule

- No hardcoded checkout roots, user profiles, or desktop paths in source or docs
- No skipping AU3Check gate with `; au3check:ignore` or similar
- No duplicate service or process inventories across files
- `ServiceControl.au3` and `ServiceManager.au3` must not both be active service-stop paths;
  `ServiceManager.au3` is the sole authoritative stop path as of T04 integration
