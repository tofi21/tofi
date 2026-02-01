# RULESET: WORKFLOW GENERATION (YAML)

## THE GOLDEN STANDARD
Refer to `tofi-core/workflows/demo_basic.yaml` and `tofi-core/docs/NODE_REFERENCE.md` as the canonical example.

## 🏗️ WORKFLOW STRUCTURE
Every generated YAML must strictly follow this schema:

```yaml
name: "unique_workflow_name"
description: "Short summary"
data: 
  key: "default_value"  # Global inputs
secrets:
  api_key: true         # Required secrets
nodes:
  node_id_1:
    type: "Task" | "LLM" | "Shell" | ... (See NODE_REFERENCE.md)
    input:
      prompt: "Hello {{data.key}}"
    next: ["node_id_2"]