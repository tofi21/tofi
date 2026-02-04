# RULESET: FRONTEND ENGINEERING (REACT)

## PROJECT STRUCTURE

```
tofi-ui/src/
  App.tsx                         # Root component
  main.tsx                        # Entry point
  pages/
    EditorPage.tsx                # Workflow canvas editor
    WorkflowsPage.tsx             # Workflow listing
    DashboardPage.tsx             # Dashboard
    ExecutionDetailPage.tsx        # Execution viewer
    SecretsPage.tsx               # Secret management
    ArtifactsPage.tsx             # Artifacts viewer
    NodeSchemaTestPage.tsx         # Schema test page
    admin/                        # Admin pages
    auth/                         # Auth pages
  store/
    ui.ts                         # UI state (zustand) — workflow, canvas, execution
    auth.ts                       # Auth state (zustand) — token, user
  lib/
    edgeSync.ts                   # Edge sync, reference extraction, node relations
    serializer.ts                 # YAML ↔ React Flow serialization (25KB)
    schema-generator.ts           # Schema → form field generation
    api.ts                        # API client
    queryClient.ts                # React Query client
    utils.ts                      # General utilities
  schemas/
    index.ts                      # Schema registry (registerSchema, getSchemaByType)
    ai.schema.ts                  # + 11 more schema files (one per node type)
  config/
    nodeMetadata.ts               # Node icons, colors, categories
  components/editor/
    WorkflowCanvas.tsx            # Main canvas — edge regeneration, onConnect, onEdgeDelete
    EditorInspector.tsx           # Inspector panel — config tabs, upstream trigger banner
    NodePropertiesPanel.tsx       # Schema-driven property forms
    NodeLibrary.tsx               # Node palette / library
    DataSourcePanel.tsx           # Data source management
    HoldNodeInspector.tsx         # Hold node special inspector
    SecretSelector.tsx            # Secret picker
    YamlEditor.tsx                # YAML editor view
    nodes/
      BaseNode.tsx                # Base node component (handles, labels)
      TaskNode.tsx                # Generic task node renderer
    edges/                        # Edge components
    fields/                       # Form field components
    MentionInput/
      MentionInput.tsx            # @mention reference input (main)
      MentionTextarea.tsx         # Textarea variant
      MentionText.tsx             # Read-only display
      MentionPopover.tsx          # Suggestion dropdown
      DictMentionInput.tsx        # Dict-specific mention input
      mentionUtils.ts             # ZWS helpers, tag detection
      useDataSources.ts           # Available data sources hook
      types.ts                    # Type definitions
  hooks/
    useWorkflows.ts               # Workflow CRUD hook
  types/
    schema.ts                     # NodeSchema, SchemaField, FieldType definitions
```

## SCHEMA-DRIVEN UI

Tofi uses a **schema-first** approach for node property forms:

1. **Define schema** in `src/schemas/<type>.schema.ts`
2. **Register** in `src/schemas/index.ts` via `registerSchema()`
3. **Forms auto-generate** from schema fields via `NodePropertiesPanel`

**Field types**: `text`, `textarea`, `number`, `password`, `select`, `checkbox`, `boolean`, `list`, `secret`, `model_select`, `key-value-list`, `node-multi-select`

**Conditional visibility**: Use `showWhen` to show/hide fields based on other field values.

## EDGE & CONNECTION ARCHITECTURE

Two distinct systems for edges:

### 1. Reference-Driven Edges (Normal Nodes)

Normal nodes (ai, var, dict, shell, hold, file, workflow, loop) do **NOT** use manual `next`. Edges are **auto-computed from `{{}}` references**:

- If node B's config contains `{{A}}` → edge A→B auto-appears
- Removing `{{A}}` from B → edge disappears
- `syncNodeRelations()` auto-computes both `dependencies` and `next`
- Dragging a connection on canvas inserts `{{sourceId}}` into target's primary input field
- Deleting an edge removes `{{sourceId}}` from target

**Key constants** in `edgeSync.ts`:
```typescript
BOOLEAN_NODE_TYPES = new Set(['compare', 'check'])
FIELDS_TO_SCAN = ['prompt', 'command', 'url', 'expression', 'value',
                  'body', 'headers', 'input', 'left', 'right',
                  'text', 'pattern', 'list']
PRIMARY_INPUT_FIELD = { ai: 'prompt', shell: 'command', ... }
```

### 2. Boolean Trigger Edges (Compare/Check Only)

`BOOLEAN_NODE_TYPES` = `compare` and `check` — the **only** nodes that can actively trigger downstream:

- Edges from `on_true`/`on_false` fields (T/F branches)
- Canvas displays dual output handles: emerald (true, 35% Y) / red (false, 65% Y)
- `sourceHandle: 'true'` or `'false'`
- `NodeMultiSelect` component for picking target nodes

### Key Functions

| Function | File | Purpose |
|----------|------|---------|
| `generateEdgesFromTriggerMap()` | edgeSync.ts | Generate all edges from `{{}}` refs + `on_true`/`on_false` |
| `syncNodeRelations()` | edgeSync.ts | Sync `dependencies` + `next` from references |
| `extractNodeReferences()` | edgeSync.ts | Extract all `{{nodeId}}` refs from node data |
| `addReferenceToNode()` | edgeSync.ts | Insert `{{nodeId}}` into node's primary input |
| `removeReferenceFromNode()` | edgeSync.ts | Remove `{{nodeId}}` from node |

### Canvas Lifecycle (WorkflowCanvas.tsx)

- **useEffect**: regenerates edges on any node data change via `generateEdgesFromTriggerMap()`, calls `syncNodeRelations()`
- **onConnect**: Boolean T/F → update `on_true`/`on_false`. Normal → `addReferenceToNode()` on target
- **onEdgeDelete**: Boolean T/F → remove from `on_true`/`on_false`. Normal → `removeReferenceFromNode()` on target

## SERIALIZER (serializer.ts)

### YAML → React Flow (`deserializeFromYAML`)
- Parse YAML, create React Flow nodes with position auto-layout
- **Compare/Check merge**: `{id}_branch` suffix nodes merged back into parent
- **Legacy migration**: Normal nodes with `next` but missing `{{}}` refs → auto-add refs, then clear `next`
- Supports `dependencies` field round-trip

### React Flow → YAML (`serializeToYAML`)
- **Compare/Check split**: Auto-generate `_branch` suffix backend node with `condition`, `on_true`, `on_false`
- **nextMap**: Only collects edges with `sourceHandle === 'out'` (excludes T/F edges)
- **Var nodes**: `value` written as top-level field (not inside `config`)
- **Secret references**: `{{secrets.KEY}}` → `ref:KEY` format in YAML

## MENTIONINPUT SYSTEM

`@mention` enables inline node references in text fields:

- **Zero-width spaces** (`\u200B`) around tags for Slack-like UX (no visible gaps)
- **`@` triggers popup** at any cursor position (no space-before-@ required)
- **`findAdjacentTag`** treats `ZWS + tag + ZWS` as atomic unit for arrow/delete
- **`htmlToValue`** strips ZWS during serialization to YAML
- **DictMentionInput**: Specialized variant for dict field values

## NODE METADATA

```typescript
NODE_CATEGORIES = [
  { title: 'Intelligence', items: ['ai'] },
  { title: 'Data',         items: ['var', 'dict'] },
  { title: 'Flow Control', items: ['compare', 'check', 'loop', 'hold'] },
  { title: 'Experimental', items: ['workflow', 'file', 'shell'] },
  // secret: category '_hidden' — not shown in palette
]
```

**Icons**: Lucide icons per node type (defined in `nodeMetadata.ts`)
**Colors**: Each node has a distinct `text-*-400` color class

## STATE MANAGEMENT

### UIState (`store/ui.ts`) — Zustand
- Sidebar / inspector toggle
- Selected node, active workflow
- Canvas API reference
- Workflow save/run status
- Execution monitoring (executionId, status, nodeResults)
- Key methods: `saveWorkflow()`, `runWorkflow()`, `testRunToNode()`, `stopWorkflow()`, `monitorExecution()`

### AuthState (`store/auth.ts`) — Zustand + persist
- `token`, `user`, `isAuthenticated`
- Persisted to localStorage as `tofi-auth-storage`

## UPSTREAM TRIGGER BANNER

`EditorInspector.tsx` shows an amber warning banner when a node is triggered by multiple upstream sources AND at least one is a Compare/Check T/F branch. This warns users about potentially conflicting trigger paths.

## TECH STACK
- **Framework**: Vite + React + TypeScript + TailwindCSS
- **Graph**: `@xyflow/react` (React Flow)
- **State**: Zustand
- **Data fetching**: React Query
- **Icons**: Lucide React
