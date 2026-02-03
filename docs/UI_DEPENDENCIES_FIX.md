# UI Dependencies 字段支持修复

## 问题描述

在 2026-02-02 发现，tofi-ui 的序列化器（serializer.ts）不支持 `dependencies` 字段，导致：
1. 加载 YAML 工作流时，`dependencies` 字段被忽略
2. 保存工作流时，`dependencies` 字段丢失
3. 导致工作流在 UI 中编辑后出现竞态条件，随机失败

## 根本原因

### 加载时（deserializeYAML）
```typescript
// 旧代码（第 371-373 行）
if (nodeConfig.input) nodeData.input = nodeConfig.input;
if (nodeConfig.on_failure) nodeData.on_failure = nodeConfig.on_failure;
if (nodeConfig.timeout) nodeData.timeout = nodeConfig.timeout;
// ❌ 缺少 dependencies 处理
```

### 保存时（serializeToYAML）
```typescript
// 旧代码（第 277-283 行）
if (nodeData.on_failure) {
  yamlNode.on_failure = nodeData.on_failure;
}
if (nodeData.timeout) {
  yamlNode.timeout = nodeData.timeout;
}
// ❌ 缺少 dependencies 处理
```

## 修复方案

### 1. 更新 TypeScript 接口（第 19-28 行）

```typescript
export interface NodeYAML {
  type: string;
  label?: string;
  config?: Record<string, any>;
  input?: Array<{ from: string; as?: string }>;
  next?: string[];
  on_failure?: string;
  timeout?: number;
  dependencies?: string[];  // ✅ 新增
  value?: any;
}
```

### 2. 加载时支持（第 376 行）

```typescript
if (nodeConfig.input) nodeData.input = nodeConfig.input;
if (nodeConfig.on_failure) nodeData.on_failure = nodeConfig.on_failure;
if (nodeConfig.timeout) nodeData.timeout = nodeConfig.timeout;
if (nodeConfig.dependencies) nodeData.dependencies = nodeConfig.dependencies;  // ✅ 新增
```

### 3. 保存时支持（第 286-288 行）

```typescript
if (nodeData.timeout) {
  yamlNode.timeout = nodeData.timeout;
}

if (nodeData.dependencies && Array.isArray(nodeData.dependencies)) {  // ✅ 新增
  yamlNode.dependencies = nodeData.dependencies;
}
```

### 4. 黑名单更新（第 209 行）

```typescript
// 旧代码
if (!['type', 'label', 'next', 'on_failure', 'timeout', 'input'].includes(key)) {
  config[key] = nodeData[key];
}

// 新代码
if (!['type', 'label', 'next', 'on_failure', 'timeout', 'input', 'dependencies'].includes(key)) {
  config[key] = nodeData[key];
}
```

## 修改文件

- **文件**: `/Users/jackzhao/Developer/tofi/tofi-ui/src/lib/serializer.ts`
- **修改行数**: 4 处
- **影响范围**: 所有工作流的加载和保存

## 验证方法

### 1. CLI 测试（验证 YAML 文件正确性）

```bash
cd /Users/jackzhao/Developer/tofi/tofi-core
./tofi run -workflow .tofi/jack/workflows/math_test_01_basic_operators.yaml
```

**预期结果**：所有节点按正确顺序执行，无竞态条件错误。

### 2. UI 加载测试

1. 在 UI 中打开 `math_test_01_basic_operators.yaml`
2. 检查节点属性，确认 `dependencies` 字段已加载
3. 不做任何修改，直接保存
4. 用文本编辑器打开保存后的文件
5. 验证 `dependencies` 字段仍然存在

**预期结果**：
```yaml
test_gt:
  type: math
  label: 'Test: 100 > 50'
  dependencies:      # ✅ 应该保留
    - value_100
    - value_50
  config:
    left: '{{value_100}}'
    operator: '>'
    right: '{{value_50}}'
```

### 3. UI 编辑测试

1. 在 UI 中打开工作流
2. 修改某个节点（如改变 label）
3. 保存工作流
4. 验证 `dependencies` 字段未丢失

### 4. 稳定性测试

在 UI 中多次运行同一工作流，验证每次都成功，无随机失败。

## 影响范围

### 受益的节点类型

所有使用 `{{variable}}` 引用的节点都需要 `dependencies` 字段：
- `math` 节点（引用 var/dict 的值）
- `var` 节点（引用其他节点的输出）
- `ai` 节点（引用 prompt 模板变量）
- `api` 节点（引用 URL/body 模板变量）
- `shell` 节点（引用 script 模板变量）

### 工作流最佳实践

```yaml
# ✅ 正确模式
data_source:
  type: var
  value: '100'
  next: [consumer]       # 触发后续节点

consumer:
  type: math
  dependencies: [data_source]  # 声明依赖
  config:
    left: '{{data_source}}'
    operator: '>'
    right: '50'
```

## 相关文档

- [NODE_REFERENCE.md](../NODE_REFERENCE.md) - 节点字段完整参考
- [MATH_TEST_GUIDE.md](../tofi-core/.tofi/jack/workflows/MATH_TEST_GUIDE.md) - Math 节点测试指南
- [PROGRESS.md](./PROGRESS.md) - 项目进度跟踪

## 技术债务

### 未来改进

1. **自动依赖推导**：引擎可以分析 `{{variable}}` 引用，自动生成 `dependencies` 字段
2. **UI 依赖编辑器**：在节点属性面板中提供可视化的依赖关系编辑器
3. **依赖验证**：保存时验证 `dependencies` 中引用的节点是否存在
4. **循环依赖检测**：在 UI 中实时检测并警告循环依赖

## 提交信息

```
fix(ui): Add support for dependencies field in workflow serializer

- Added dependencies field to NodeYAML interface
- Implemented dependencies deserialization in deserializeYAML
- Implemented dependencies serialization in serializeToYAML
- Added dependencies to field blacklist in buildNodeConfig
- Rebuilt UI bundle

Fixes: Random workflow execution failures due to race conditions
Impact: All workflows using {{variable}} references
```
