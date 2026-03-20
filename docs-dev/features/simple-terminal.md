# Simple Terminal（libghostty-spm）

## 背景
在重置后的 `CanvasTerminalKit` 中恢复最小可用终端能力，依赖 `libghostty-spm`，提供可嵌入的终端视图与可运行 Demo。

## BDD 场景

### 场景 1：创建简单终端
- Given 使用方创建 `SimpleTerminal(options:)`
- When 提供工作目录和字体大小
- Then 终端配置应使用 `exec` 后端并应用工作目录与字体大小

### 场景 2：展示终端视图
- Given 已创建 `SimpleTerminal`
- When 在 SwiftUI 中使用 `SimpleTerminalView`
- Then 终端表面应可渲染并连接对应状态对象

## 验收标准
1. SPM 依赖中包含 `libghostty-spm`。
2. 提供 `SimpleTerminal` 与 `SimpleTerminalView` 公共 API。
3. 提供 `CanvasTerminalDemo` 可执行目标用于本地运行验证。
4. 关键行为由测试覆盖并通过。
