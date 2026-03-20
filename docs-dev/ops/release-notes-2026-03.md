# Release Notes - 2026-03

## 2026-03-21

- 发布：`Leucus` 首个版本 `0.0.1`（Git tag: `v0.0.1`）。
- 构建：`xcodebuild -project Example/Leucus.xcodeproj -scheme Leucus -configuration Release -destination 'platform=macOS' build` 成功。
- 产物：生成 `Leucus-0.0.1.zip` 与 `appcast.xml` 并上传到 GitHub Release，供 Sparkle/GitHub Pages 同步分发。

## 2026-03-20

- 修复：`Leucus` 的 `AppIcon` 全尺寸资源补齐为 macOS 标准槽位（`16/32/128/256/512` 的 `1x/2x`）。
- 修复：原始图标从非正方形源图统一裁切并输出为 `1024x1024`（对应 `512@2x`）。
- 验证：`xcodebuild -project Example/Leucus.xcodeproj -scheme Leucus -destination 'platform=macOS' build` 下，`actool` 不再出现 icon 尺寸告警。
- 新增：`Leucus` 接入 Sparkle 自动升级，应用菜单增加“检查更新…”入口，支持手动触发更新检查。
- 新增：`Leucus` 显式 `Info.plist`（包含 `SUFeedURL` / `SUPublicEDKey` / 自动检查相关键），并通过 `LEUCUS_APPCAST_URL` / `LEUCUS_SPARKLE_PUBLIC_KEY` 注入；未配置有效 feed 时自动禁用菜单动作。
- 新增：GitHub Pages 分发模板配置（`LEUCUS_GITHUB_OWNER` / `LEUCUS_GITHUB_REPO` -> `LEUCUS_APPCAST_URL`），为仓库改名后快速切换 appcast 地址做准备。
- 新增：GitHub Actions 工作流 `.github/workflows/release-assets-to-pages.yml`，在 release 发布后自动同步 `appcast.xml` 与 `.zip` 到 `gh-pages`。
- 验证：`xcodebuild -project Example/Leucus.xcodeproj -scheme Leucus -destination 'platform=macOS' build` 成功，产物 `Info.plist` 已包含 Sparkle 关键字段。
