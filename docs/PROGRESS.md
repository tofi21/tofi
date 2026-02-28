# Tofi Project Progress

## 2026-02-01 - Workflow & UI Improvements

### 1. Math Node Refactor ✅
**Status**: Completed
**Goal**: Simplify Math node UI and improve error reporting.
- [x] **Backend (`math.go`)**: Improved error messages to identify which operand (left/right) failed parsing.
- [x] **Frontend Schema**: Simplified fields to `Left`, `Op`, `Right`. Moved `output_bool` to 'More'.
- [x] **Frontend UI (`NodePropertiesPanel`)**: Implemented inline layout `[Left] [Op] [Right]`.
- [x] **Auto-Connection**: Implemented logic in `EditorInspector` to automatically create edges when a node is referenced via `@MentionInput`.
- [x] **Auto-Disconnection**: Implemented logic to automatically remove edges from "pure data nodes" (var, dict) when they are no longer referenced.
- [x] **Comprehensive Testing**: Created 6 test workflows covering all operators, input sources, edge cases, error handling, and real-world scenarios.
- [x] **Dependency Resolution**: Fixed workflow dependency issues by ensuring proper `next` and `dependencies` field usage.

### 2. Workflow Generation Reliability
**Status**: Completed
**Goal**: Ensure AI-generated workflows are valid and loadable in UI.
- [x] **Documentation**: Updated `NODE_REFERENCE.md` and `skills/03-workflow.md` to strictly define `var` (simple values) vs `dict` (structured data).
- [x] **Validation**: Created robust `demo_comprehensive.yaml` proving correct usage of `dict` for JSON data and `math` logic.
- [x] **Memory**: Updated agent memory with strict rules about `var` vs `dict` usage.

### 3. Documentation Cleanup
**Status**: Completed
- [x] **Consolidation**: Deleted `tofi-ui/PROGRESS.md` and consolidated tracking here.
- [x] **Accuracy**: Corrected `README.md` examples to match engine implementation.

---

## 2026-02-02 - Math Node Testing & Validation

### Math Node Comprehensive Test Suite ✅
**Status**: Completed
**Location**: `tofi-core/.tofi/jack/workflows/math_test_*.yaml`

**Test Coverage**:
1. **math_test_01_basic_operators.yaml**: All 6 operators (`>`, `<`, `==`, `>=`, `<=`, `!=`)
2. **math_test_02_input_sources.yaml**: Different input sources (var, dict, hardcoded, mixed)
3. **math_test_03_edge_cases.yaml**: Negative numbers, decimals, zero, large numbers
4. **math_test_04_output_bool.yaml**: `output_bool` mode behavior validation
5. **math_test_05_error_handling.yaml**: Invalid inputs, error messages, empty values
6. **math_test_06_complex_workflow.yaml**: Real-world multi-criteria validation scenario

**Key Findings**:
- Tofi engine requires **both** `next` and `dependencies` fields for proper execution
- `{{variable}}` references do NOT automatically create dependencies
- Dependencies must be explicitly declared to avoid race conditions
- All tests now run stably with 100% success rate

**Documentation**:
- Created `MATH_TEST_GUIDE.md` with detailed testing instructions
- Updated workflow best practices in skill documentation

### UI Dependencies Field Support ✅
**Status**: Completed
**Issue**: UI serializer did not support `dependencies` field, causing workflows to fail randomly after being edited in UI.

**Fix Applied**:
- Modified `tofi-ui/src/lib/serializer.ts` to support `dependencies` field
- Added field to TypeScript interface `NodeYAML`
- Implemented deserialization (loading YAML → UI)
- Implemented serialization (saving UI → YAML)
- Added `dependencies` to field blacklist to prevent it from being saved to `config`
- Rebuilt UI bundle

**Impact**: All workflows with `{{variable}}` references now work correctly in UI
**Documentation**: Created `docs/UI_DEPENDENCIES_FIX.md` with technical details

---

## 2026-02-04 - Boolean Node System & Legacy Cleanup

### Boolean Node System ✅
**Status**: Completed
**Goal**: Replace legacy logic nodes with a cleaner boolean-based system inspired by Apple Shortcuts.

**New Nodes**:
1. **Compare** (`compare.go`, `compare.schema.ts`)
   - Dual-input comparison node
   - Operators: `==`, `!=`, `>`, `<`, `>=`, `<=`, `between`, `contains`, `not_contains`, `starts_with`, `ends_with`, `matches`, `in`, `not_in`
   - Output: `"true"` or `"false"` (string)
   - Type-aware: numeric operators require numbers, string operators convert to string

2. **Check** (`check.go`, `check.schema.ts`)
   - Single-input validation node
   - Operators: `is_empty`, `not_empty`, `is_true`, `is_false`, `is_number`, `is_json`
   - Output: `"true"` or `"false"` (string)

3. **Branch** (`branch.go`)
   - Flow router based on boolean condition
   - Config: `condition`, `on_true`, `on_false`
   - Frontend auto-generates branch node when Compare has `on_true`/`on_false` configured

**Frontend Integration**:
- Compare UI node auto-generates `compare` + `branch` backend nodes via serializer
- Deserializer merges them back into single frontend node
- Updated `nodeMetadata.ts` with new node entries

### Legacy Node Cleanup ✅
**Status**: Completed
**Removed Nodes**:
- `math.go`, `math.schema.ts` - Superseded by `compare` with numeric operators
- `text.go`, `text.schema.ts` - Superseded by `compare` with string operators
- `list.go` - Superseded by `compare` with `in`/`not_in` operators
- `if.go`, `if.schema.ts` - Superseded by `compare` + `branch` combination

**Updated Files**:
- `engine.go` - Removed legacy node registrations
- `serializer.ts` - Removed legacy node handlers
- `NodePropertiesPanel.tsx` - Removed legacy schema imports
- `NodeSchemaTestPage.tsx` - Updated test page
- `NODE_REFERENCE.md` - Removed legacy documentation

### Node Panel Reorganization ✅
**Status**: Completed
**New Categories**:
1. **Intelligence** - AI
2. **Data** - Variable, Dict
3. **Flow Control** - Compare, Check, Loop, Hold
4. **Experimental** (Work in progress) - Workflow, File, Shell

**Hidden Nodes**:
- `secret` - Temporarily hidden (category: `_hidden`), pending design review for sub-workflow integration

### Architecture Decision: Config-based Special Fields
**Decision**: `on_true`/`on_false` stored in `config` (方案C)
**Rationale**: Keeps Node struct clean, special routing logic handled by engine via config lookup

### Boolean Node Canvas Integration ✅
**Status**: Completed
- Compare/Check nodes display dual T/F output handles on canvas (emerald=true, red=false)
- Added `NodeMultiSelect` component for selecting target nodes in `on_true`/`on_false`
- Handle backgrounds use opaque dark fills to avoid border bleed-through

### MentionInput Zero-Width Space & Unrestricted @ Trigger ✅
**Status**: Completed
- Replaced visible spaces around `@mention` tags with zero-width spaces (`\u200B`) for Slack-like experience
- Tags no longer produce visual gaps in text
- `findAdjacentTag` treats `ZWS + tag + ZWS` as atomic unit for arrow/delete navigation
- Removed restriction requiring space before `@` to trigger popup — `@` now works at any position

### Reference-Driven Edge Architecture ✅
**Status**: Completed
**Goal**: Separate data references from trigger relationships. Edges should follow `{{}}` references, not manual `next`.

**Key Architectural Change**:
- **Old model**: All edges driven by `next` field. `{{}}` references only affect `dependencies`.
- **New model**: Normal node edges are computed from `{{}}` references. Only Compare/Check retain active trigger via `on_true`/`on_false`.

| Node Type | Edge Source | Behavior |
| :--- | :--- | :--- |
| Normal (ai, var, dict, etc.) | `{{}}` references | B has `{{A}}` → edge A→B auto-appears; remove reference → edge disappears |
| Compare/Check | `on_true`/`on_false` | T/F branches, the only nodes that can actively "trigger" |

**Core Changes**:
- `edgeSync.ts`: `generateEdgesFromTriggerMap()` now derives edges from `{{}}` refs (reverse lookup) + `on_true`/`on_false`. New `syncNodeRelations()` auto-computes both `dependencies` and `next` for normal nodes.
- `WorkflowCanvas.tsx`: `onConnect` inserts `{{sourceId}}` into target's primary input field. `onEdgeDelete` removes `{{sourceId}}` from target.
- `serializer.ts`: `nextMap` only collects `sourceHandle='out'` edges. Deserialization migrates legacy `next` by auto-adding `{{}}` references.
- `EditorInspector.tsx`: Added upstream trigger banner when a node is triggered by both `{{}}` references and Compare/Check T/F branches.

**Constants**: `BOOLEAN_NODE_TYPES = Set(['compare', 'check'])` — single source of truth for which nodes have T/F branching capability.

---

## 2026-02-28 - File Container System, Save Node & Artifact Improvements

### Save Node ✅
**Status**: Completed
**Goal**: Add a dedicated node for saving content to the artifacts directory.

- [x] **Backend (`save.go`)**: Saves content to `{artifacts_dir}/{filename}`, supports base64 binary
- [x] **Engine registration**: Added `save` case in `GetAction()` (`engine.go`)
- [x] **Frontend Schema (`save.schema.ts`)**: Fields: `content` (textarea, allows data refs), `filename` (text)
- [x] **Schema registry**: Registered in `schemas/index.ts`

### File Node Container Refactor ✅
**Status**: Completed
**Goal**: Transform the File node from a simple file-library loader into a versatile file container that supports both upstream data input and user uploads.

**Backend (`file.go`, 40→300+ lines)**:
- [x] **Dual input mode**: `_input` (upstream data) vs `file_id`/`file_path` (user upload)
- [x] **File ID system**: Database lookup via `file_id` (new) alongside legacy `file_path` symlink approach
- [x] **save_to_disk option**: When receiving upstream data, optionally persist to artifacts directory
- [x] **Structured JSON output**: `{"path", "filename", "mime_type", "size", "file_id"}` (replaces raw path string)
- [x] **On-demand content resolution**: `{{file_node.content}}` reads file from disk or UpstreamContent map
- [x] **MIME detection**: Auto-detect content type from file headers
- [x] **Base64 binary support**: `base64:` prefix for binary upstream data

**Engine (`engine.go`)**:
- [x] File node special handling: injects first dependency's output as `_input` into config

**Models (`models.go`)**:
- [x] `UserFileRecord`: new fields `WorkflowID`, `NodeID`, `Source` ("library"|"workflow")
- [x] `ArtifactRecord`: new fields `RelativePath`, `MimeType`
- [x] `ExecutionContext.UpstreamContent`: map for non-disk file content
- [x] `resolveFileContent()`: on-demand `.content` field resolution
- [x] Artifacts path changed: `{workflow}/{execution_id}/` (isolated per execution)

**Storage (`sqlite.go`)**:
- [x] Migration: `user_files` table gets `workflow_id`, `node_id`, `source` columns
- [x] Migration: `execution_artifacts` table gets `mime_type`, `relative_path` columns
- [x] New methods: `SaveWorkflowFile()`, `ListWorkflowFiles()`

### Workflow File Links API ✅
**Status**: Completed
**New API Endpoints**:
- [x] `POST /api/v1/workflows/{id}/files` — Create file link (symlink)
- [x] `POST /api/v1/workflows/{id}/files/upload` — Upload file to workflow
- [x] `DELETE /api/v1/workflows/{id}/files/{filename}` — Delete file link

### File Preview & Artifacts Enhancements ✅
**Status**: Completed
- [x] **File preview API**: `GET /api/v1/files/{id}/preview` — inline thumbnail display
- [x] **Artifact download**: Supports `?mode=preview` for inline display (vs attachment download)
- [x] **Artifacts API**: Now returns structured `ArtifactRecord` objects (with `mime_type`, `relative_path`) instead of plain filename strings
- [x] **Artifact path fallback**: Tries new `{workflow}/{exec_id}/` path, falls back to legacy `{workflow}/` path

### Frontend: File Node UI ✅
**Status**: Completed
- [x] **FileNode component simplified**: From complex upload UI to clean container display (`FileNode.tsx`)
- [x] **File moved to Data category**: `nodeMetadata.ts` — "Experimental" → "Data", color zinc → emerald
- [x] **File schema expanded** (`file.schema.ts`): Added `file_path`, `filename`, `mime_type`, `save_to_disk` fields (all managed by FileInspector, hidden from generic panel)
- [x] **EdgeSync container support** (`edgeSync.ts`): File node uses `dependencies` instead of `{{}}` refs for connections. Removed `file` from `PRIMARY_INPUT_FIELD`. Added `'content'` to `FIELDS_TO_SCAN`.

### Frontend: MentionInput File Submenu ✅
**Status**: Completed
- [x] **Three-level submenu** for File nodes in MentionInput:
  - Level 1: File node entry (click to expand)
  - Level 2: Common keys (`content`, `filename`) + "Advanced" button
  - Level 3: Advanced keys (`path`, `mime_type`, `size`, `file_id`)
- [x] **DataSource type extended** (`types.ts`): Added `fileKeys`, `advancedKeys`, `requiresSubmenu`
- [x] **useDataSources hook**: Auto-populates File node keys
- [x] **Keyboard navigation**: Full arrow/enter/escape support across all 3 levels

### Frontend: ArtifactsPage Enhancements ✅
**Status**: Completed
- [x] MIME-type-based file icons (image/code/text/generic)
- [x] Inline preview support for text and image artifacts
- [x] Structured artifact records with metadata display
