# RULESET: WORKFLOW YAML SYNTAX

## CANONICAL REFERENCE
- Node types and configs: `tofi-core/docs/NODE_REFERENCE.md`
- Detailed per-node docs: `tofi-core/docs/nodes/*.md`
- Example workflows: `tofi-core/workflows/`

## WORKFLOW STRUCTURE

```yaml
id: "unique_workflow_id"           # Optional, for UI stability
name: "Display Name"
description: "Short summary"
data:
  key: "default_value"             # Global inputs (accessible via {{data.key}})
secrets:
  api_key: env.ENV_VAR_NAME        # Secret mapping
nodes:
  node_id:
    type: "ai"                     # See NODE_REFERENCE.md for all types
    label: "Step 1"                # Optional display label
    config:
      prompt: "..."                # Node-specific config
    next: ["next_node_id"]         # Downstream execution
    dependencies: ["dep_node_id"]  # Must complete before me
    on_failure: ["error_handler"]  # Error handler nodes
    run_if: "expression"           # Conditional execution (govaluate)
    timeout: 30                    # Seconds (0 = no limit)
    retry_count: 2                 # Retry on failure
```

## DATA REFERENCE SYNTAX

| Syntax | Resolves To |
|--------|-------------|
| `{{node_id}}` | Full output of another node |
| `{{node_id.field}}` | Specific field (gjson path) |
| `{{data.key}}` | Workflow-level data input |
| `{{secrets.key}}` | Secret value |
| `{{env.VAR}}` | Environment variable |

## CRITICAL RULES

### 1. VAR vs DICT
- **VAR**: single, simple values (string, number, boolean)
  - `value: "hello"` or `value: "95"`
  - **NEVER** put objects/arrays in var value — it will crash the frontend
- **DICT**: structured JSON objects
  - Uses `fields` array with key-value pairs
  - Or `input` with `{{}}` reference to extract from upstream JSON

### 2. QUOTING
- Always quote numeric values: `value: "90"` not `value: 90`
- Ensures consistent type handling across Go and JS

### 3. SECRETS
- Define in top-level `secrets:` block first
- Reference via `{{secrets.key_name}}` in node configs
- Never hardcode API keys in node config
- Frontend serializer converts `{{secrets.KEY}}` to `ref:KEY` format

### 4. BOOLEAN LOGIC (Compare/Check/Branch)

**Compare** — dual-value comparison:
```yaml
check_score:
  type: compare
  config:
    left: "{{ai_result.score}}"
    operator: ">"
    right: "90"
    on_true: ["high_score_handler"]
    on_false: ["low_score_handler"]
```

**Check** — single-value validation:
```yaml
validate_input:
  type: check
  config:
    value: "{{user_input}}"
    operator: "not_empty"
    on_true: ["process"]
    on_false: ["ask_again"]
```

> The frontend auto-generates a `_branch` suffix node for each Compare/Check that has `on_true`/`on_false`.

**Available Compare operators**: `==`, `!=`, `>`, `<`, `>=`, `<=`, `between`, `contains`, `not_contains`, `starts_with`, `ends_with`, `matches`, `in`, `not_in`

**Available Check operators**: `is_empty`, `not_empty`, `is_true`, `is_false`, `is_number`, `is_json`

### 5. EDGE MODEL (Frontend-Backend Alignment)

**Frontend**: Normal node edges are auto-computed from `{{}}` references. Only Compare/Check use `on_true`/`on_false` for active triggering.

**Backend**: The engine uses `next` + `dependencies` for execution ordering. `InferEdges()` ensures bidirectional consistency before execution.

**Implication**: When writing YAML for the backend directly, you still use `next`/`dependencies`. The frontend manages this translation automatically.

## CORRECT EXAMPLES

### Variable
```yaml
min_score:
  type: var
  label: "Minimum Score"
  value: "90"
```

### Dict (Structured Data)
```yaml
user_context:
  type: dict
  label: "User Context"
  config:
    fields:
      - key: "name"
        value: "Alice"
      - key: "role"
        value: "Admin"
```

### AI with Secret
```yaml
analyze:
  type: ai
  config:
    model: "gpt-4o"
    api_key: "{{secrets.openai_key}}"
    prompt: "Analyze: {{user_context}}"
  next: ["check_score"]
  dependencies: ["user_context"]
```

### Conditional Flow
```yaml
check_score:
  type: compare
  config:
    left: "{{analyze.score}}"
    operator: ">="
    right: "{{min_score}}"
    on_true: ["send_notification"]
    on_false: ["log_failure"]
  dependencies: ["analyze", "min_score"]

# Frontend auto-generates this _branch node:
check_score_branch:
  type: branch
  config:
    condition: "{{check_score}}"
    on_true: ["send_notification"]
    on_false: ["log_failure"]
  dependencies: ["check_score"]
```

### Shell with Environment
```yaml
deploy:
  type: shell
  config:
    script: |
      echo "Deploying to $TARGET"
      echo "Artifacts: $TOFI_ARTIFACTS_DIR"
    env:
      TARGET: "production"
      API_KEY: "{{secrets.deploy_key}}"
```

## REMOVED NODES (DO NOT USE)
- ~~`math`~~ → use `compare` with numeric operators
- ~~`text`~~ → use `compare` with string operators (`contains`, `starts_with`, etc.)
- ~~`list`~~ → use `compare` with `in`/`not_in`
- ~~`if`~~ → use `compare` + `branch` combination
