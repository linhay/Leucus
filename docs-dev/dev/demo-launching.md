# Demo 启动策略（macOS）

## 结论
`CanvasTerminalDemo` 在本地调试时，使用 `swift run` 的裸二进制启动会出现窗口与输入不稳定问题。

## 统一方案
使用 `.app bundle` 启动：
1. 构建可执行文件。
2. 组装 `CanvasTerminalDemo.app`（包含 `Info.plist` 和 `CFBundleIdentifier`）。
3. 通过 `open -n` 启动。

## 命令
- `make run-demo-app`
- 实现脚本：`scripts/run_demo_app.sh`

## 验证指标
- `System Events` 可观察到 `CanvasTerminalDemo` 进程窗口数 `>= 1`。
