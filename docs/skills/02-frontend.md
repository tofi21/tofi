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

## COMPONENT RULES
- **Node Metadata**: Icons, colors, and categories define in `tofi-ui/src/config/nodeMetadata.ts`.
- **Custom Nodes**: Located in `tofi-ui/src/components/editor/nodes/`.