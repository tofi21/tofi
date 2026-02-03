# UI 自动连线功能修复

## 问题描述

Math 节点和其他逻辑节点在 UI 中无法自动建立连线，即使在输入框中输入了 `{{node_id}}` 引用。

## 根本原因

在 `/Users/jackzhao/Developer/tofi/tofi-ui/src/lib/edgeSync.ts` 中：

### 问题 1: 字段扫描列表不完整（第 6 行）

```typescript
// ❌ 旧代码 - 缺少 Math 节点的字段
const FIELDS_TO_SCAN = ['prompt', 'command', 'url', 'expression', 'value', 'body', 'headers', 'input'];
```

**缺失的字段**：
- `left`, `right` - Math 节点使用的字段
- `text`, `pattern` - Text 节点使用的字段
- `list` - List 节点使用的字段

### 问题 2: 主输入字段配置错误（第 17-19 行）

```typescript
// ❌ 旧代码
math: 'expression',  // Math 节点实际使用 left, operator, right！
text: 'expression',  // Text 节点实际使用 text, pattern！
```

## 修复方案

### 1. 扩展字段扫描列表

```typescript
// ✅ 新代码 - 添加所有逻辑节点的字段
const FIELDS_TO_SCAN = [
  'prompt',     // AI 节点
  'command',    // Shell 节点
  'url',        // API 节点
  'expression', // Loop, If 节点
  'value',      // Var 节点
  'body',       // API 节点
  'headers',    // API 节点
  'input',      // Dict, Hold 节点
  'left',       // Math 节点左操作数
  'right',      // Math 节点右操作数
  'text',       // Text 节点文本
  'pattern',    // Text 节点模式
  'list'        // List 节点列表
];
```

### 2. 修正主输入字段映射

```typescript
// ✅ 新代码
const PRIMARY_INPUT_FIELD: Record<string, string> = {
  ai: 'prompt',
  shell: 'command',
  file: 'path',
  api: 'url',
  dict: 'input',
  var: 'value',
  loop: 'expression',
  math: 'left',      // ✅ 修正：使用 left 字段
  if: 'expression',
  text: 'text',      // ✅ 修正：使用 text 字段
  hold: 'input',
};
```

## 影响范围

### 受益的节点类型

修复后，以下节点类型的自动连线功能将正常工作：

1. **Math 节点** (`type: math`)
   - `left: '{{node_id}}'` → 自动创建边
   - `right: '{{node_id}}'` → 自动创建边

2. **Text 节点** (`type: text`)
   - `text: '{{node_id}}'` → 自动创建边
   - `pattern: '{{node_id}}'` → 自动创建边

3. **List 节点** (`type: list`)
   - `list: '{{node_id}}'` → 自动创建边

4. **所有其他节点** - 保持原有功能

## 自动连线的工作原理

### 触发时机

自动连线由 `generateEdgesFromReferences` 函数（第 167-197 行）在以下情况下触发：

1. **节点加载时** - 从 YAML 加载工作流
2. **节点编辑时** - 用户修改节点属性
3. **拖拽节点时** - 画布上移动节点

### 工作流程

```
用户输入 {{value_100}}
         ↓
扫描 FIELDS_TO_SCAN 列表中的所有字段
         ↓
使用正则 /\{\{([^}]+)\}\}/g 提取引用
         ↓
排除系统引用 (data., secrets., ctx.)
         ↓
解析节点 ID (处理 dict.key 格式)
         ↓
创建边: source=value_100, target=current_node
         ↓
自动显示连线
```

### 引用格式支持

- ✅ `{{node_id}}` - 简单引用
- ✅ `{{dict_node.field}}` - Dict 字段引用
- ✅ 多个引用：`{{a}} and {{b}}`
- ❌ `{{data.key}}` - 全局数据（不创建边）
- ❌ `{{secrets.key}}` - 密钥引用（不创建边）
- ❌ `{{ctx.execution_id}}` - 上下文（不创建边）

## 测试验证

### 1. Math 节点测试

```yaml
# 在 UI 中创建
value_100:
  type: var
  value: '100'

test_math:
  type: math
  config:
    left: '{{value_100}}'   # ← 输入这个
    operator: '>'
    right: '50'
```

**预期行为**：
- 输入 `{{value_100}}` 后，自动创建从 `value_100` 到 `test_math` 的边
- 画布上显示连线
- 保存后 YAML 包含正确的引用

### 2. Text 节点测试

```yaml
message:
  type: var
  value: 'error occurred'

check_text:
  type: text
  config:
    text: '{{message}}'     # ← 自动创建边
    mode: 'contains'
    pattern: 'error'
```

### 3. 多重引用测试

```yaml
test_math:
  type: math
  config:
    left: '{{value_a}}'     # ← 创建边 value_a → test_math
    operator: '>'
    right: '{{value_b}}'    # ← 创建边 value_b → test_math
```

**预期行为**：
- 两条边都应该自动创建
- 删除引用文本时，对应的边应该自动删除

## 与 Dependencies 字段的关系

**重要区别**：

| 特性 | 自动连线（Edges） | Dependencies 字段 |
|------|------------------|------------------|
| 作用 | UI 可视化，显示数据流 | 引擎执行顺序控制 |
| 生成方式 | UI 自动扫描 `{{}}` 引用 | 必须在 YAML 中显式声明 |
| 保存位置 | 转换为 `next` 字段 | 保存为 `dependencies` 字段 |
| 影响范围 | 仅 UI 显示 | 影响实际执行 |

**最佳实践**：
```yaml
value_100:
  type: var
  value: '100'
  next: [test_math]        # ← 从 UI 边生成

test_math:
  type: math
  dependencies: [value_100] # ← 必须手动添加（或 UI 支持后自动）
  config:
    left: '{{value_100}}'   # ← UI 扫描这个生成边
```

**未来改进**：UI 可以在保存时自动生成 `dependencies` 字段，基于检测到的 `{{}}` 引用。

## 相关文件

- **edgeSync.ts** - 自动连线核心逻辑
- **serializer.ts** - YAML 序列化/反序列化
- **EditorInspector.tsx** - 节点编辑器
- **CanvasEditor.tsx** - 画布编辑器

## 提交信息

```
fix(ui): Add auto-connection support for Math, Text, and List nodes

- Added 'left', 'right', 'text', 'pattern', 'list' to FIELDS_TO_SCAN
- Corrected PRIMARY_INPUT_FIELD for math node (expression → left)
- Corrected PRIMARY_INPUT_FIELD for text node (expression → text)

Fixes: Math and Text nodes not auto-connecting when {{}} references are used
Impact: All logic nodes (math, text, list, check) now support auto-connection
```

## 已知限制

1. **主输入字段限制**：`addReferenceToNode` 函数只能向**单个主字段**添加引用。对于 Math 节点，只会向 `left` 字段添加，不会自动填充 `right`。
2. **边删除逻辑**：删除节点时，相关的边会被删除，但 `dependencies` 字段不会自动更新（需要额外逻辑）。
3. **循环引用检测**：目前没有防止循环引用的机制（A → B → A）。

## 未来改进建议

1. **自动生成 Dependencies**：保存时根据 `{{}}` 引用自动添加 `dependencies` 字段
2. **多字段引用支持**：允许向多个字段添加引用（如 Math 的 left 和 right）
3. **引用辅助输入**：提供下拉菜单选择可用节点，而不是手动输入 `{{}}`
4. **循环依赖检测**：实时检测并警告循环依赖
5. **依赖可视化**：在画布上区分 `next` 边和 `dependencies` 边
