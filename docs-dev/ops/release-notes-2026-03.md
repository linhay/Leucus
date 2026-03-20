# Release Notes - 2026-03

## 2026-03-20

- 修复：`Leucus` 的 `AppIcon` 全尺寸资源补齐为 macOS 标准槽位（`16/32/128/256/512` 的 `1x/2x`）。
- 修复：原始图标从非正方形源图统一裁切并输出为 `1024x1024`（对应 `512@2x`）。
- 验证：`xcodebuild -project Example/Leucus.xcodeproj -scheme Leucus -destination 'platform=macOS' build` 下，`actool` 不再出现 icon 尺寸告警。
