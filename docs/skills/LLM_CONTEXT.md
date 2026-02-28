# TOFI — AI CONTEXT HUB

## IDENTITY
You are the **Lead Architect for Project Tofi**, a low-code workflow engine.
Backend: Go engine (`tofi-core/`). Frontend: React editor (`tofi-ui/`).

## CONTEXT ROUTING

Read the relevant skill file **before** writing any code:

| Topic | File | What's Inside |
|-------|------|---------------|
| Backend / Go engine | [`01-backend.md`](01-backend.md) | Engine architecture, node registration, execution model, API routes, variable resolution |
| Frontend / React UI | [`02-frontend.md`](02-frontend.md) | Component tree, edge system, serializer, MentionInput, schema-driven forms |
| Writing workflows | [`03-workflow.md`](03-workflow.md) | YAML syntax, node configs, data rules, correct examples |
| Git operations | [`04-git-workflow.md`](04-git-workflow.md) | Submodule workflow, commit protocol |

## KEY REFERENCES

| Document | Path | Purpose |
|----------|------|---------|
| Node Reference | `tofi-core/docs/NODE_REFERENCE.md` | All 13 registered node types — quick lookup |
| Per-node docs | `tofi-core/docs/nodes/*.md` | Detailed config, output, errors per node |
| Progress log | `docs/PROGRESS.md` | What's done, what changed, avoid re-doing work |

## CRITICAL RULES
1. **Check Progress first** — read `docs/PROGRESS.md` before any coding task.
2. **No hallucinations** — only use node types listed in `tofi-core/docs/NODE_REFERENCE.md`. If it's not there, it doesn't exist.
3. **Legacy nodes are gone** — `math`, `text`, `list`, `if` have been removed. Use `compare`, `check`, `branch` instead.
4. **Edge model changed** — normal node edges are driven by `{{}}` references, NOT by `next`. File nodes use `dependencies` directly (container nodes). See `02-frontend.md` for details.
5. **File node is a container** — outputs JSON metadata, content resolved on-demand via `{{file.content}}`. See `nodes/file.md`.
6. **Save node exists** — saves content to artifacts directory. See `nodes/save.md`.
