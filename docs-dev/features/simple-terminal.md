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

### 场景 3：方向键与删除键输入稳定
- Given 用户已将焦点置于终端内容区
- When 按下方向键或删除键
- Then 应向终端注入完整 ANSI 序列（例如 `ESC [ C`），不出现裸文本 `[C/[D`
- And `.exec` 后端优先走物理按键事件路径，不依赖 `doCommand` 文本回退

### 场景 4：终端 Surface 与 Prowl 保持同源
- Given 终端卡片在 macOS AppKit 下渲染
- When 创建终端 surface
- Then 使用同 Prowl 的 Ghostty C API surface/view 输入管线（包含 `performKeyEquivalent`、`translationState`、`ghostty_surface_key` 路径）

## 验收标准
1. SPM 依赖中包含 `libghostty-spm`。
2. 提供 `SimpleTerminal` 与 `SimpleTerminalView` 公共 API。
3. 提供 `CanvasTerminalDemo` 可执行目标用于本地运行验证。
4. AppKit 下方向键/删除键序列映射有测试覆盖并通过。
5. AppKit 终端 surface 代码与 Prowl 主实现同源（允许最小编译兼容补丁）。
6. 关键行为由测试覆盖并通过。
