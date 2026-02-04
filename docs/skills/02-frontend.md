# RULESET: FRONTEND ENGINEERING (REACT)

## CORE ARCHITECTURE
- **Framework**: Vite + React + TypeScript + TailwindCSS.
- **State Management**: `zustand` (via `useWorkflows` hook).
- **Graph Engine**: `reactflow`.

## 🛡️ SCHEMA-DRIVEN UI (CRITICAL)
Tofi uses a strict "Schema-First" approach.
1. **Define Schema First**: Create/Edit `tofi-ui/src/schemas/<node_type>.schema.ts`.
2. **Zod Validation**: All form inputs MUST be validated via Zod.
3. **Auto-Generation**: The UI forms are often auto-generated from these schemas. DO NOT hardcode inputs inside components unless necessary.

## EDGE & CONNECTION ARCHITECTURE (CRITICAL)

Edges represent execution flow. There are two distinct systems:

### 1. Reference-Driven Edges (Normal Nodes)
- Normal nodes (ai, var, dict, shell, api, loop, hold, file) do **NOT** have manual `next`.
- Edges are **auto-computed from `{{}}` references**: if node B's fields contain `{{A}}`, edge A→B appears.
- Removing the `{{}}` reference removes the edge.
- `syncNodeRelations()` in `edgeSync.ts` auto-computes both `dependencies` (who I reference) and `next` (who references me).
- Dragging a connection on canvas inserts `{{sourceId}}` into target's primary input field (`PRIMARY_INPUT_FIELD` map).
- Deleting an edge removes `{{sourceId}}` from the target node.

### 2. Boolean Trigger Edges (Compare/Check Only)
- `BOOLEAN_NODE_TYPES = Set(['compare', 'check'])` — the only nodes that can actively trigger.
- Edges come from `on_true`/`on_false` fields (T/F branches).
- These use `sourceHandle: 'true'/'false'` and display as emerald/red handles on canvas.
- Canvas displays dual T/F output handles at 35%/65% vertical position.

### Key Files
- `edgeSync.ts`: `generateEdgesFromTriggerMap()` — generates all edges. `syncNodeRelations()` — syncs `dependencies` + `next`.
- `WorkflowCanvas.tsx`: `useEffect` regenerates edges on any node change. `onConnect`/`onEdgeDelete` handle reference insertion/removal.
- `serializer.ts`: Compare/Check auto-generate `_branch` backend nodes. Deserialization merges them back. Legacy `next` auto-migrated to `{{}}` references.

### MentionInput System
- Zero-width spaces (`\u200B`) around `@mention` tags for Slack-like UX (no visible gaps).
- `@` triggers popup at any cursor position (no space required before `@`).
- `findAdjacentTag` treats `ZWS + tag + ZWS` as atomic unit for arrow/delete.
- `htmlToValue` strips ZWS during serialization.

## COMPONENT RULES
- **Node Metadata**: Icons, colors, and categories define in `tofi-ui/src/config/nodeMetadata.ts`.
- **Custom Nodes**: Located in `tofi-ui/src/components/editor/nodes/`.