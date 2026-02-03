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
