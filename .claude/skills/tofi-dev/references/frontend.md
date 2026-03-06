# Frontend Reference — tofi-ui (React)

## Tech Stack

- **React 19** + **React Router 7** + **Vite 7**
- **Tailwind CSS 4** (CSS variable design tokens, dark/light mode)
- **TanStack React Query 5** (all data fetching)
- **Zustand 5** (auth, theme, UI state)
- **Axios** (HTTP client with JWT interceptor)
- **Lucide React** (icons)
- **Framer Motion** (animations)

## Directory Map

```
src/
├── App.tsx                   # Route definitions
├── main.tsx                  # React mount + theme init
├── index.css                 # Tailwind + CSS variables (design tokens)
├── pages/
│   ├── KanbanPage.tsx        # Main dashboard — wish input, card board, SSE streaming
│   ├── SkillsPage.tsx        # Skill browse + install + run test panel
│   ├── CollectionPage.tsx    # View all skills in a collection
│   ├── SkillStudioPage.tsx   # Create/edit skill (fields, resources, inputs/outputs)
│   ├── AgentsPage.tsx        # Agent list + CRUD
│   ├── AgentEditorPage.tsx   # Agent edit form (model, prompt, skills)
│   ├── HistoryPage.tsx       # Execution history table
│   ├── SettingsPage.tsx      # AI API key management
│   ├── auth/LoginPage.tsx    # Login form
│   ├── auth/SetupPage.tsx    # First-time admin setup
│   └── admin/                # Admin dashboard, users, executions, workflows, secrets
├── hooks/
│   ├── useKanban.ts          # Kanban CRUD, wish, retry (React Query)
│   ├── useSkills.ts          # Skill CRUD, registry search, install, collection
│   ├── useAgents.ts          # Agent CRUD (localStorage for now)
│   └── useCardStream.ts     # SSE subscription for real-time card updates
├── lib/
│   ├── api.ts                # Axios instance + ALL API types and functions
│   ├── queryClient.ts        # React Query client config
│   └── utils.ts              # cn() helper (clsx + tailwind-merge)
├── store/
│   ├── auth.ts               # token, user, isAuthenticated, setAuth, logout
│   ├── theme.ts              # mode (auto/light/dark), resolved, setMode
│   └── ui.ts                 # isSidebarCollapsed
├── components/
│   ├── layout/Sidebar.tsx    # Nav sidebar (collapsible, animated)
│   ├── layout/Header.tsx     # Top bar (theme toggle, user menu)
│   └── ui/                   # Base components (card, button, input, label)
└── layouts/
    ├── MainLayout.tsx        # Sidebar + Header + Island content area
    └── AuthLayout.tsx        # Centered card for login/setup
```

## Routes

```typescript
// Public
/setup              → SetupPage
/login              → LoginPage

// Protected (require auth)
/                   → KanbanPage (main dashboard)
/agents             → AgentsPage
/agents/new         → AgentEditorPage
/agents/:id         → AgentEditorPage
/skills             → SkillsPage
/skills/new         → SkillStudioPage
/skills/collection  → CollectionPage (?source=xxx)   // BEFORE :id routes
/skills/:id/edit    → SkillStudioPage
/history            → HistoryPage
/settings           → SettingsPage

// Admin
/admin              → AdminDashboardPage
/admin/users        → AdminUsersPage
/admin/executions   → AdminExecutionsPage
/admin/workflows    → AdminWorkflowsPage
/admin/secrets      → AdminSecretsPage
```

## API Layer (lib/api.ts)

All API calls go through the Axios instance. Request interceptor adds JWT. Response interceptor handles 401 → auto logout.

### Key Types

```typescript
interface Skill {
  id: string; name: string; description: string;
  source: 'local' | string; source_url?: string;
  scope: string; version: string;
  instructions: string; manifest_json: string;
}

interface KanbanCard {
  id: string; title: string; description: string;
  status: 'todo' | 'working' | 'hold' | 'done' | 'failed';
  progress: number; result: string;
  steps: Array<{ name: string; status: string; detail?: string }>;
  actions: Array<{ type: string; status: string; payload: any }>;
  agent_id: string; execution_id: string;
  user_id: string; created_at: string; updated_at: string;
}

interface RegistrySkill {
  id: string; name: string; description: string;
  source: string; installs: number; stars: number;
}

interface InstallPreviewResponse {
  preview: boolean; session_id: string;
  source_url: string; total: number;
  skills: SkillPreview[];
}
```

### Key Functions

```typescript
// Kanban
listKanbanCards(), makeWish({ title, description, model? })
approveKanbanAction(cardId, actionIndex, decision)
continueKanbanCard(cardId), abortKanbanCard(cardId), retryKanbanCard(cardId)

// Skills
listSkills(query?), createSkill(data), updateSkill(id, data), deleteSkill(id)
runSkill({ id, prompt, useSystemKey }), searchRegistry(query)
installSkillPreview(source), installSkillConfirm({ sessionId, skillNames? })
getCollection(sourceUrl), deleteCollection(sourceUrl)

// Settings
listAIKeys(), setAIKey({ provider, value, scope }), deleteAIKey(provider, scope?)

// Execution
getExecution(id)
```

## React Query Hooks (src/hooks/)

Every hook wraps an API call with React Query. Pattern:

```typescript
// Query (fetching)
export function useSkills(query?: string) {
  return useQuery({
    queryKey: ['skills', query],
    queryFn: () => listSkills(query),
  });
}

// Mutation (create/update/delete)
export function useDeleteSkill() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => deleteSkill(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['skills'] }),
  });
}
```

## Adding a New Page — Pattern

1. Create `src/pages/MyPage.tsx`
2. Add route in `App.tsx` inside the `<Route element={<MainLayout />}>` group
3. Add nav item in `components/layout/Sidebar.tsx`
4. If it needs API: add types + functions in `lib/api.ts`, then hooks in `hooks/useMyThing.ts`

## Component Patterns

### Card

```tsx
<div className="bg-surface border border-border rounded-xl p-4 group hover:border-primary transition-colors cursor-pointer">
  <div className="flex items-start justify-between">
    {/* Left: icon + content */}
    {/* Right: action buttons (opacity-0 group-hover:opacity-100) */}
  </div>
  <p className="text-xs text-foreground-secondary mt-2.5 line-clamp-2">{description}</p>
</div>
```

### Modal / Dialog

```tsx
<div className="fixed inset-0 z-50 flex items-center justify-center bg-overlay backdrop-blur-sm" onClick={onClose}>
  <div className="bg-island border border-border rounded-2xl w-full max-w-md mx-4 shadow-2xl" onClick={e => e.stopPropagation()}>
    {/* Header with border-b, Content, Footer with border-t */}
  </div>
</div>
```

### Status Badge

```tsx
<span className={cn("inline-flex items-center gap-1 text-[10px] font-medium px-2 py-0.5 rounded-full", colorClass)}>
  <Icon className="size-3" />
  {label}
</span>
```

### Section Header

```tsx
<div className="flex items-center gap-2 mb-3">
  <Icon className={cn("size-4", color)} />
  <h3 className={cn("text-sm font-semibold", color)}>{label}</h3>
  <span className="text-[10px] text-foreground-faint bg-soft rounded-full px-2 py-0.5">{count}</span>
</div>
```

## Design Token CSS Variables

The theme uses CSS variables defined in `index.css`. Two palettes (light/dark) swap via `html.dark` class.

### Backgrounds
- `bg-shell` — outermost background
- `bg-island` — content island (main area)
- `bg-surface` — cards and inputs
- `bg-soft` — subtle highlight (tags, badges)

### Text
- `text-foreground` — primary text
- `text-foreground-secondary` — secondary
- `text-muted-text` — muted labels
- `text-foreground-faint` — barely visible

### Semantic Colors
- `bg-accent` / `text-accent-foreground` — primary action buttons
- `text-info` / `bg-info` — blue (installed, info)
- `text-success` / `bg-success` — green (public skills)
- `text-danger` / `bg-danger` — red (delete, errors)
- `text-warning` / `bg-warning` — amber (discover)

### Border & Overlay
- `border-border` — default border color
- `bg-overlay` — modal backdrop

## SSE Real-Time Updates (useCardStream)

```typescript
const { streamingContent, isStreaming } = useCardStream(cardId, isActive);
// Subscribes to GET /api/v1/kanban/{id}/stream?token={jwt}
// Events: step_added, step_updated, card_updated, card_done, result_chunk
// Auto-updates React Query cache on events
```

## Layout Architecture

```
┌──────────────────────────────────────────┐
│              Header (theme, user)         │
├────────┬─────────────────────────────────┤
│        │                                 │
│Sidebar │     Island (main content)       │
│ (nav)  │   bg-island, rounded, shadow    │
│        │   overflow-y-auto scrollable    │
│        │                                 │
└────────┴─────────────────────────────────┘
```

- Sidebar width: 240px expanded, 76px collapsed (animated)
- Content area uses `overflow-y-auto custom-scrollbar`
- Island has `rounded-3xl shadow-island` for floating effect

## Key Gotchas

1. **Scrolling** — Main content scrolls inside the island div (`overflow-y-auto`), not the window. Use `document.querySelector('.overflow-y-auto')` to find scroll container.

2. **Agent storage** — `useAgents.ts` currently uses localStorage, not backend API. Will be replaced later.

3. **Skill categorization** — `categorizeSkills()` in SkillsPage groups by `source_url`: single → singleInstalled, multiple → collections, `source === 'local'` → mySkills.

4. **Run panel polling** — SkillRunPanel submits run, then polls `getExecution(execId)` every 1.5s until status !== 'RUNNING'. Shows elapsed time and Stop button.

5. **Font sizes** — Heavy use of `text-[10px]` for metadata, `text-xs` for descriptions, `text-sm` for titles.
