# Domain Documentation

## Layout

This repo uses a **single-context** layout:

- `GLOSSARY.md` at the repo root — domain vocabulary
- `docs/adr/` — Architecture Decision Records (use ADR-FORMAT.md)

## Consumer Rules

1. Read `GLOSSARY.md` before writing any agent-facing document, ticket, or spec.
   Use the terms it defines exactly — do not substitute synonyms.
2. When a new domain term is agreed during a session, update `GLOSSARY.md` immediately.
3. When a decision is hard-to-reverse, surprising, and was a real trade-off, create
   an ADR in `docs/adr/` following the format in `.agents/skills/domain-modeling/ADR-FORMAT.md`.
4. `GLOSSARY.md` contains domain vocabulary only — no implementation details, no specs,
   no scratch notes.
