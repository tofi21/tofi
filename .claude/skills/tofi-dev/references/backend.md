# Backend Reference — tofi-core (Go)

## Directory Map

```
internal/
├── server/
│   ├── server.go              # Server struct, routes, Start(), middleware
│   ├── handlers.go            # Workflow/execution/file/secret handlers
│   ├── wish_handlers.go       # POST /wish → async agent execution
│   ├── kanban_handlers.go     # Kanban CRUD, approve, continue, abort
│   ├── skill_handlers.go      # Skill CRUD, install, run, test, collection, registry
│   ├── auth.go                # JWT generation, AuthMiddleware, AdminMiddleware
│   ├── sse.go                 # SSEHub — real-time event push
│   ├── workerpool.go          # Concurrent job execution (10 workers)
│   ├── scheduler.go           # Cron triggers (robfig/cron)
│   ├── registry.go            # In-memory execution context tracking
│   ├── recovery.go            # Zombie task recovery on restart
│   ├── webhook.go             # Public webhook trigger handlers
│   └── admin_handlers.go      # Admin-only handlers
├── storage/
│   ├── sqlite.go              # DB init, table creation, migrations
│   ├── skills.go              # Skill CRUD, ListSkillsBySourceURL, DeleteSkillsBySourceURL
│   ├── kanban.go              # KanbanCard CRUD, status transitions
│   └── settings.go            # AI key storage (ResolveAIKey)
├── skills/
│   ├── installer.go           # SkillInstaller: Install, PreviewInstall, InstallOne
│   ├── source.go              # ParseSource (git URL, local path, owner/repo@skill)
│   ├── registry.go            # skills.sh registry client
│   └── store.go               # LocalStore (filesystem skill management)
├── mcp/
│   └── agent.go               # RunAgentLoop, MCP client, tool conversion, ReAct loop
├── executor/
│   ├── executor.go            # Executor interface (CreateSandbox, Execute, Cleanup)
│   ├── sandbox.go             # DirectExecutor — real implementation
│   └── docker.go              # DockerExecutor — container-based (optional)
├── engine/
│   ├── engine.go              # Start(), RunNode(), node scheduling
│   └── tasks/
│       ├── ai.go              # LLM inference, resolveAPIKey, detectProviderFromModel
│       ├── skill.go           # Skill execution task, resolveSkillAPIKey
│       └── shell.go           # Shell command execution
├── models/
│   ├── models.go              # Workflow, Node, ExecutionContext, ExecutionResult
│   └── skill.go               # SkillFile, SkillManifest, SkillInput/Output
└── parser/
    └── parser.go              # YAML workflow parser
```

## Server Struct

```go
type Server struct {
    config          Config
    registry        *ExecutionRegistry          // active execution tracking
    db              *storage.DB                 // SQLite
    workerPool      *WorkerPool                 // 10 concurrent jobs
    scheduler       *Scheduler                  // cron triggers
    executor        executor.Executor           // sandbox
    sseHub          *SSEHub                     // real-time push
    holdMu          sync.Mutex
    holdChannels    map[string]chan HoldSignal   // agent pause/resume
    previewMu       sync.Mutex
    previewSessions map[string]*PreviewSession  // skill install cache (10min TTL)
}
```

## API Routes

### Auth (public)
```
GET  /health
POST /api/v1/auth/setup           # first-time admin creation
GET  /api/v1/auth/setup_status    # { initialized: bool }
POST /api/v1/auth/login           # → { token, user }
```

### Kanban
```
GET    /api/v1/kanban                    # list all cards
POST   /api/v1/kanban                    # create card
GET    /api/v1/kanban/{id}               # get card
PUT    /api/v1/kanban/{id}               # update card
DELETE /api/v1/kanban/{id}               # delete card
POST   /api/v1/kanban/{id}/approve       # approve hold action
POST   /api/v1/kanban/{id}/continue      # resume agent after hold
POST   /api/v1/kanban/{id}/abort         # abort running card
POST   /api/v1/kanban/{id}/retry         # retry failed card
GET    /api/v1/kanban/{id}/stream        # SSE event stream
```

### Wish
```
POST   /api/v1/wish                      # { title, description, model? }
```

### Skills
```
GET    /api/v1/skills                    # list (?q=search)
POST   /api/v1/skills                    # create
GET    /api/v1/skills/collection         # ?source=xxx
DELETE /api/v1/skills/collection         # ?source=xxx
GET    /api/v1/skills/{id}              # get
PUT    /api/v1/skills/{id}              # update
DELETE /api/v1/skills/{id}              # delete
POST   /api/v1/skills/{id}/run          # run (async → execution_id)
POST   /api/v1/skills/{id}/test         # test (same as run)
POST   /api/v1/skills/{id}/export       # export as SKILL.md
POST   /api/v1/skills/install           # mode: preview/confirm/default
GET    /api/v1/skills/{id}/resources
PUT    /api/v1/skills/{id}/resources/{type}/{name}
DELETE /api/v1/skills/{id}/resources/{type}/{name}
```

### Settings
```
GET    /api/v1/settings/ai-keys
POST   /api/v1/settings/ai-keys          # { provider, value, scope }
DELETE /api/v1/settings/ai-keys/{provider}
```

### Registry
```
GET    /api/v1/registry/search           # ?q=xxx → skills.sh
```

### Executions
```
GET    /api/v1/executions/{id}           # status + outputs
GET    /api/v1/executions/{id}/logs
```

## Database Tables (SQLite)

| Table | Key columns | Purpose |
|-------|------------|---------|
| `users` | id, username, password_hash, role | Accounts |
| `kanban_cards` | id, title, status, progress, steps(JSON), actions(JSON), user_id | Tasks |
| `skills` | id, name, version, scope, source, source_url, manifest_json, instructions | Skills |
| `settings` | user, provider, encrypted_value | AI keys |
| `executions` | id, workflow_id, user, status, result_json | History |
| `execution_logs` | execution_id, node_id, log_type, content | Logs |
| `secrets` | id, user, name, encrypted_value | Secrets |

## Adding a Handler — Pattern

```go
// 1. In appropriate *_handlers.go:
func (s *Server) handleMyThing(w http.ResponseWriter, r *http.Request) {
    userID := r.Context().Value(UserContextKey).(string)
    id := r.PathValue("id")

    var req struct {
        Field string `json:"field"`
    }
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "invalid request body", http.StatusBadRequest)
        return
    }

    result, err := s.db.DoSomething(id, userID)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(result)
}

// 2. Register in server.go setupRoutes():
mux.HandleFunc("GET /api/v1/my-thing/{id}", s.AuthMiddleware(s.handleMyThing))
```

## Adding a Storage Method — Pattern

```go
func (db *DB) GetThing(id, userID string) (*ThingRecord, error) {
    row := db.QueryRow(`SELECT id, name, user_id FROM things WHERE id = ? AND user_id = ?`, id, userID)
    var rec ThingRecord
    if err := row.Scan(&rec.ID, &rec.Name, &rec.UserID); err != nil {
        return nil, err
    }
    return &rec, nil
}
```

## Kanban Card States

```
todo → working → done
                → failed (retryable)
                → hold (waiting for user, 10min timeout)
                    → working (continue) / failed (abort/timeout)
```

## Skill Install Flow

```
Normal: POST /skills/install { source } → clone → discover → install all → DB

Two-phase:
  POST /skills/install { source, mode: "preview" } → clone → discover → cache session → return list
  POST /skills/install { mode: "confirm", session_id, skill_names } → install selected → DB → cleanup
```

## MCP Agent Loop

ReAct loop in `mcp/agent.go`:
1. System prompt + available skills
2. Tools: MCP tools + sandbox_exec + run_skill__* + update_kanban
3. Call LLM → if tool_calls → execute → append results → loop (max 30 iterations)
4. Return final text

## Key Go Dependencies

- `modernc.org/sqlite` — pure Go SQLite (no CGo)
- `github.com/mark3labs/mcp-go` — MCP client
- `github.com/golang-jwt/jwt/v5` — JWT
- `github.com/google/uuid` — UUIDs
- `github.com/robfig/cron/v3` — cron scheduling
