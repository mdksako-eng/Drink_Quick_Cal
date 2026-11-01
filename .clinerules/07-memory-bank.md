# Memory Bank — read this first (lean variant)

`memory-bank/` is this project's persistent memory. It exists so a new task does
not have to re-explore the repository, which is the most expensive thing an agent
does here (30,000 files, 1.3 GB of build output).

## At the start of EVERY task
1. Read `memory-bank/activeContext.md` and `memory-bank/progress.md`. They are
   deliberately short — keep them that way.
2. Read `systemPatterns.md` or `techContext.md` ONLY if the task touches
   architecture, data flow or setup.
3. `projectbrief.md` is stable background: read it only when scope is unclear.
   Do NOT read all five files "just in case".

## At the end of a task that changed something meaningful
- Update `activeContext.md`: what changed, what is next, open decisions.
- Append to `progress.md` when a milestone or phase lands (mirrors `ROADMAP.md`).
- Keep entries factual and short. A bloated Memory Bank is re-read on every task
  and costs more tokens than it saves.

## Hard limits
- Never store credentials, tokens, connection strings or customer data here.
- `ROADMAP.md` stays the human-facing feature log — do not duplicate its sections.
