# RULESET: BACKEND ENGINEERING (GO)

## CORE PRINCIPLES
- **Engine Logic**: Located in `tofi-core/internal/engine/`.
- **Concurrency**: The engine uses a DAG model. Worker pools handle task execution (`internal/server/workerpool.go`).
- **Error Handling**: Use explicit `if err != nil`. Wrap errors with context.

## 🔧 VARIABLE RESOLUTION (STRICT)
The engine resolves variables in this specific order (See `internal/engine/data/var.go`):
1. **Local Input**: Data passed directly to the node.
2. **Global Context**: Workflow-wide `data` defined at start.
3. **Secrets**: Encrypted keys (`internal/engine/data/secret.go`).

## CODING PATTERNS
- **Node Implementation**: New nodes must implement the `Node` interface.
- **Zombie Recovery**: When touching execution logic, ensure `recovery.go` can restore state from SQLite.
- **API Response**: Standardize JSON responses using `internal/server/handlers.go`.