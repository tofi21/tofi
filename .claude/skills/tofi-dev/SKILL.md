---
name: tofi-dev
description: >
  Lead architect context for Project Tofi — a Kanban-driven AI agent platform with Go backend and React frontend.
  Use this skill for ANY coding task in the tofi project: backend Go changes (server, storage, skills, agents, engine),
  frontend React changes (pages, hooks, API, components), or full-stack features.
  Also trigger when the user mentions kanban, wishes, skills, agents, sandbox, or anything related to the tofi codebase.
user-invocable: false
---

# Tofi — Project Context

## What is Tofi

Tofi is a **Kanban-driven AI agent platform**. Users submit "wishes" (tasks) via a Kanban board, and LLM-powered agents execute them using tools, skills, and sandboxed commands.

**Core loop:** User creates wish → Backend creates Kanban card → Agent picks it up → Agent reasons and acts (tool calls, skill runs, sandbox commands) → Card completes with results → Frontend shows real-time progress via SSE.

## Project Structure

```
tofi/                          # Parent repo (submodules)
├── tofi-core/                 # Go backend
│   ├── cmd/tofi/              # CLI entrypoint
│   └── internal/
│       ├── server/            # HTTP handlers, routing, middleware, SSE, worker pool
│       ├── storage/           # SQLite DB layer (all tables, CRUD)
│       ├── skills/            # Skill installer (git clone, discover, two-phase install)
│       ├── mcp/               # MCP agent — LLM + tool calls ReAct loop
│       ├── executor/          # Sandbox — isolated command execution
│       ├── engine/            # Workflow engine (node-based execution)
│       ├── models/            # Shared data types
│       └── toolbox/           # Built-in action definitions
├── tofi-ui/                   # React frontend (Vite + Tailwind + React Query)
│   └── src/
│       ├── pages/             # Route-level page components
│       ├── hooks/             # React Query hooks (useKanban, useSkills, useAgents...)
│       ├── lib/api.ts         # Axios client + all API types and functions
│       ├── store/             # Zustand stores (auth, theme, ui)
│       ├── components/        # Layout + UI components
│       └── layouts/           # MainLayout (sidebar + island) and AuthLayout
└── .claude/
    ├── CLAUDE.md              # Points here
    └── skills/tofi-dev/       # This skill
```

**Dev:** Backend port 8080, frontend port 5173 (Vite proxy). Build: `cd tofi-core && go build -o tofi-server ./cmd/tofi`. Run: `./tofi-server server`.

## Architecture Overview

| Subsystem | What it does | Key files |
|-----------|-------------|-----------|
| **Kanban + Wish** | Task lifecycle (todo → working → hold → done/failed) | `wish_handlers.go`, `kanban_handlers.go`, `kanban.go` |
| **MCP Agent** | LLM reasoning loop with tool calls (max 30 steps) | `mcp/agent.go` |
| **Skills** | Reusable prompts, installable from Git/registry | `skills/installer.go`, `skill_handlers.go`, `storage/skills.go` |
| **Sandbox** | Isolated shell command execution for agents | `executor/sandbox.go` |
| **SSE** | Real-time Kanban card updates pushed to frontend | `server/sse.go`, `useCardStream.ts` |
| **Worker Pool** | Concurrent workflow execution (max 10) | `server/workerpool.go` |
| **Settings** | AI API key management (per-user and system-wide) | `storage/settings.go`, `SettingsPage.tsx` |

### Request Flow: Wish Execution

```
POST /api/v1/wish { title, description }
  → creates KanbanCard (status=todo)
  → async executeWish():
      1. Card → working
      2. Collect available skills from DB
      3. RunAgentLoop() with tools: sandbox_exec, run_skill__*, update_kanban, MCP tools
      4. Agent iterates: LLM → tool call → result → LLM (up to 30 steps)
      5. If skill install suggested → card → hold → user approves → agent resumes
      6. Card → done/failed with result
  → SSE pushes each step to frontend in real-time
```

## When to Read References

Before writing code, read the relevant reference file for patterns and conventions:

| Task involves | Read |
|--------------|------|
| Go backend (handlers, storage, models, API routes) | [`references/backend.md`](references/backend.md) |
| React frontend (pages, hooks, components, styling) | [`references/frontend.md`](references/frontend.md) |
| Both (full-stack feature) | Read both |

## Critical Rules

1. **Submodule workflow** — `tofi-core` and `tofi-ui` are git submodules. Commit inside each first, then update parent.

2. **Go patterns** — `r.PathValue("id")` for route params (Go 1.22+). Wrap errors: `fmt.Errorf("context: %w", err)`. Use `sync.Mutex` for shared state.

3. **React patterns** — All data fetching through React Query hooks in `src/hooks/`. API types and functions in `src/lib/api.ts`. Never fetch directly from components.

4. **Route ordering** — Specific routes before parameterized. `/skills/collection` before `/skills/{id}` in Go mux, and before `/skills/:id/edit` in React Router.

5. **Default AI model** — Skill run/test defaults to `gpt-4o` (OpenAI). Provider auto-detected from model name via `detectProviderFromModel()`.

6. **Auth** — All routes require JWT via `AuthMiddleware`. Admin routes need `AdminMiddleware`. Token from `useAuthStore`.

7. **Styling** — CSS variable design tokens: `bg-surface`, `text-foreground`, `border-border`, `bg-accent`. Dark/light via `useThemeStore`. Tailwind only.

8. **SSE for real-time** — Kanban updates use Server-Sent Events, not WebSocket. Frontend subscribes via `useCardStream` hook.

9. **Two-phase skill install** — Preview (clone + discover) → user selects → Confirm (install selected). Session cached with 10min TTL.

10. **Respond in Chinese** — The user prefers Chinese responses.
