# 外置 Example 工程

## 背景
将 Demo 从 Swift Package 内部 executable target 迁移到仓库外置 Example 工程，参考 `libghostty-spm` 的 `Example/` 结构。

## 目标
1. 主包只保留 library target。
2. 示例通过独立 Xcode 工程运行。
3. 示例工程通过本地 package 引用 `CanvasTerminalKit`。

## 验收标准
1. `Package.swift` 不再包含 `CanvasTerminalDemo` executable。
2. 存在 `Example/Leucus.xcodeproj`。
3. `xcodebuild -project Example/Leucus.xcodeproj -scheme Leucus -destination 'platform=macOS' build` 可成功构建示例 App。
4. `make open-example` 可直接打开 Example 工程。
