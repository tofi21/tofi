# RULESET: WORKFLOW GENERATION (YAML)

## THE GOLDEN STANDARD
Refer to `tofi-core/workflows/demo_basic.yaml` and `tofi-core/docs/NODE_REFERENCE.md` as the canonical examples.

## 🏗️ WORKFLOW STRUCTURE
Every generated YAML must strictly follow this schema:

```yaml
id: "unique_workflow_id"    # Optional but recommended for UI stability
name: "Display Name"
description: "Short summary"
data: 
  key: "default_value"      # Global inputs
secrets:
  api_key: env.ENV_VAR_NAME # Required secrets mapping
nodes:
  node_id_1:
    type: "ai" | "shell" | ... (See NODE_REFERENCE.md)
    # ... config ...
    next: ["node_id_2"]
```

## 🚨 CRITICAL RULES (STABILITY CHECKLIST)

### 1. VAR vs DICT (The Data Rule)
*   **VAR Node**: strictly for **SINGLE, SIMPLE VALUES** (String, Number, Boolean).
    *   ✅ `value: "95"`
    *   ✅ `value: "some string"`
    *   ❌ `value: { key: "val" }` (FORBIDDEN: Will crash frontend)
*   **DICT Node**: MUST be used for **STRUCTURED DATA / JSON OBJECTS**.
    *   ✅ `config: fields: [{key: "topic", value: "AI"}]`

### 2. QUOTING (The Type Rule)
*   Always quote numeric values in `value` fields to ensure consistent String type handling across Backend (Go) and Frontend (JS/React).
    *   ✅ `value: "90"`
    *   ⚠️ `value: 90` (Avoid if possible)

### 3. SECRETS (The Security Rule)
*   Secrets MUST be defined in the top-level `secrets` block first.
*   Nodes reference them via `{{secrets.key}}`.
*   Never hardcode API keys in node config.

### 4. LABELS (The UI Rule)
*   Frontend nodes support a `label` field. While optional in backend, adding it improves UI readability.
    *   `label: "Step 1: Setup"`

## ✅ CORRECT EXAMPLES

### Correct Variable
```yaml
min_score:
  type: var
  label: "Minimum Score"
  value: "90"  # Quoted!
```

### Correct Structured Data
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

### Correct Math
```yaml
check_score:
  type: math
  config:
    left: "{{user_context.score}}"
    operator: ">"
    right: "{{min_score}}"
```
