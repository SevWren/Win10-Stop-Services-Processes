---
updated: 2026-11-11
---

# Agent Environment

## Pit-of-Success Improvements

### AU3Check Pre-Commit Hook
AU3Check flags `-q -d -w 1 -w 2 -w 3 -w 4` are configured in every `.au3` file via
`#AutoIt3Wrapper_AU3Check_Parameters`. A pre-commit hook at `.git/hooks/pre-commit` enforces
this before every commit. See `.git/hooks/pre-commit`.

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

- Dev console output: AU3Check via pre-commit hook
- AutoIt official docs: https://www.autoitscript.com/autoit3/docs/
- Windows SCM API: https://learn.microsoft.com/en-us/windows/win32/services/service-functions

## No-Workarounds Rule

- No hardcoded checkout roots, user profiles, or desktop paths in source or docs
- No skipping AU3Check gate with `; au3check:ignore` or similar
- No duplicate service or process inventories across files
- ServiceControl.au3 and ServiceManager.au3 must not both be active service-stop paths
