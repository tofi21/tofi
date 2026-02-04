# RULESET: BACKEND ENGINE (GO)

## PROJECT STRUCTURE

```
tofi-core/
  internal/
    engine/
      engine.go          # Core: GetAction(), RunNode(), InferEdges(), Start()
      actions.go          # Action interface definition
      persistence.go      # SQLite state persistence (SaveState)
      recovery.go         # Zombie task recovery on restart
      reporter.go         # Execution report generation
      base/
        virtual.go        # Fallback handler for unknown node types
      data/
        var.go            # Variable node (also handles "const")
        dict.go           # Structured JSON builder
        secret.go         # Sensitive values with log masking
      logic/
        compare.go        # Dual-value comparison (14 operators)
        check.go          # Single-value validation (6 operators)
        branch.go         # Boolean flow router (on_true/on_false)
        loop.go           # Iterator (items/range/count modes)
      tasks/
        ai.go             # LLM inference (OpenAI-compatible, MCP agent mode)
        shell.go          # Bash script execution (60s timeout)
        hold.go           # Manual approval gate (polling)
        file.go           # File library loader
        handoff.go        # Sub-workflow handoff (max depth 10)
        api.go            # HTTP request (NOT registered in GetAction)
    models/
      models.go           # Node, Workflow, ExecutionContext structs
    server/
      server.go           # HTTP server, route registration
      handlers.go         # Workflow/execution API handlers
      auth.go             # JWT authentication middleware
      workerpool.go       # Concurrent execution pool
      recovery.go         # Server-level zombie recovery
      registry.go         # Execution registry (in-memory tracking)
      admin_handlers.go   # Admin API handlers
    storage/
      db.go               # SQLite database layer
```

## NODE REGISTRATION

All nodes are registered in `GetAction()` (engine.go):

```go
switch nodeType {
case "shell":    return &tasks.Shell{}
case "ai":       return &tasks.AI{}
case "hold":     return &tasks.Hold{}
case "file":     return &tasks.File{}
case "workflow":  return &tasks.Handoff{}
case "check":    return &logic.Check{}
case "compare":  return &logic.Compare{}
case "branch":   return &logic.Branch{}
case "loop":     return &logic.Loop{}
case "var", "const": return &data.Var{}
case "dict":     return &data.Dict{}
case "secret":   return &data.Secret{}
default:         return &base.Virtual{}   // returns "VIRTUAL_OK"
}
```

> `api.go` exists but is **not registered**. Do not reference it.

## ACTION INTERFACE

Every node implements:
```go
type Action interface {
    Validate(node *models.Node) error
    Execute(config map[string]interface{}, ctx *models.ExecutionContext) (string, error)
}
```
- `Validate` — called by `ValidateAll()` before execution starts
- `Execute` — receives **resolved** config (templates already expanded) and returns a string result

## NODE STRUCT (models.go)

```go
type Node struct {
    ID           string
    Type         string
    Value        interface{}            // Used by var/const nodes
    Config       map[string]interface{} // Static configuration
    Input        []Parameter            // Typed parameter definitions
    Env          map[string]string
    RunIf        string                 // Conditional execution expression
    Next         []string               // Downstream node IDs
    Dependencies []string               // Must-complete-before-me node IDs
    RetryCount   int
    OnFailure    []string               // Error handler node IDs
    Timeout      int                    // Seconds (0 = no limit)
}
```

## EXECUTION MODEL (RunNode)

`RunNode()` is the core execution function. Each node runs as a goroutine:

1. **Resume check** — if result exists from disk recovery, skip execution but still trigger `next`
2. **Dependency gate** — wait for all `Dependencies` to complete. Propagate SKIP/ERROR upstream (except `run_if` skips don't propagate)
3. **Concurrency lock** — `CheckAndSetStarted()` ensures only one goroutine executes a node
4. **`run_if` evaluation** — govaluate expression; false = SKIP with downstream propagation
5. **Config resolution** — two paths:
   - Var/Const: direct `ReplaceParamsAny` on config + value
   - Others: `ResolveLocalContext()` → `ResolveConfig()` (two-phase resolution)
   - Secret references (`ref:SECRET_NAME`) resolved via DB lookup
   - Dict's `fields` skipped during template resolution (handled internally)
6. **Execute with timeout** — goroutine + channel + `context.WithTimeout`
7. **Retry** — up to `RetryCount` attempts
8. **Result handling**:
   - Success → `SetResult(nodeID, output)` → trigger `Next`
   - Error → `SetResult(nodeID, "ERR_PROPAGATION: ...")` → trigger `Next` + `OnFailure`
   - Branch special: reads `on_true`/`on_false` from Config to determine routing

## VARIABLE RESOLUTION

Resolution order (see `ResolveLocalContext` + `ReplaceParams`):

1. **Node results** — `{{node_id}}` or `{{node_id.field}}` (gjson path)
2. **Workflow data** — `{{data.key}}`
3. **Secrets** — `{{secrets.key}}`
4. **Environment** — `{{env.VAR_NAME}}`

Secret reference format in config: `ref:SECRET_NAME` → resolved at runtime via encrypted DB lookup.

## EDGE INFERENCE (InferEdges)

`InferEdges()` runs before execution to ensure bidirectional consistency:
- For every `next` entry A→B, add A to B's `dependencies`
- For branch nodes: also process `on_true`/`on_false` from config
- For every `dependencies` entry B depends on A, add B to A's `next`

## API ROUTES

```
Public:
  GET  /health
  GET  /api/v1/stats
  POST /api/v1/auth/setup
  POST /api/v1/auth/login

Protected (JWT):
  GET    /api/v1/auth/me
  POST   /api/v1/run                              # Execute workflow
  GET    /api/v1/executions                        # List executions
  GET    /api/v1/executions/{id}                   # Get execution detail
  GET    /api/v1/executions/{id}/logs              # Stream logs
  GET    /api/v1/executions/{id}/artifacts         # List artifacts
  POST   /api/v1/executions/{id}/nodes/{nid}/approve  # Approve/reject hold
  POST   /api/v1/executions/{id}/cancel            # Cancel execution
  GET/POST/DELETE /api/v1/workflows                # CRUD workflows
  POST   /api/v1/workflows/validate                # Validate YAML
  POST/GET/DELETE /api/v1/secrets                   # Secret management

Admin:
  GET/POST/DELETE /api/v1/admin/users
  GET/DELETE      /api/v1/admin/executions
  GET             /api/v1/admin/stats
```

## CODING PATTERNS

- **Error handling**: explicit `if err != nil`. Wrap with context: `fmt.Errorf("node %s: %w", id, err)`
- **New node**: implement `Action` interface, register in `GetAction()`, add tests
- **State persistence**: `SaveState(ctx)` after every status change (RUNNING, SUCCESS, ERROR, SKIP)
- **Zombie recovery**: `recovery.go` restores in-flight executions from SQLite on server restart
- **Log masking**: secret values auto-masked via `ctx.MaskLog()`
