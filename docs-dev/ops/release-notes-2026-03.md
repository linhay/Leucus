# Release Notes - 2026-03

## 2026-03-21

- 修复：`Leucus` 在 Dock 重开窗口（`applicationShouldHandleReopen`）时崩溃；将 `main.swift` 从“整个 `app.run()` 包裹 `MainActor.assumeIsolated`”改为“仅初始化 `AppDelegate` 阶段使用 `assumeIsolated`，运行循环在外部执行”，避免主执行器假设在重入事件路径触发断言。
- 验证：`xcodebuild -project Example/Leucus.xcodeproj -scheme Leucus -configuration Debug -destination 'platform=macOS' build` 成功。
- 发布：`Leucus` 首个版本 `0.0.1`（Git tag: `v0.0.1`）。
- 构建：`xcodebuild -project Example/Leucus.xcodeproj -scheme Leucus -configuration Release -destination 'platform=macOS' build` 成功。
- 产物：生成 `Leucus-0.0.1.zip` 与 `appcast.xml` 并上传到 GitHub Release，供 Sparkle/GitHub Pages 同步分发。
- 修复：为 `Leucus` target 新增 Build Phase `Embed Sparkle XPC Services`，在构建时将 `Sparkle.framework/Versions/B/XPCServices/{Downloader,Installer}.xpc` 复制到 `Leucus.app/Contents/XPCServices`，修复“Unable to Check For Updates / The updater failed to start”。
- 版本：测试更新版本提升为 `0.0.2 (2)`（`MARKETING_VERSION=0.0.2`，`CURRENT_PROJECT_VERSION=2`）。
- 发布：创建 GitHub Release `v0.0.2`（`Leucus 0.0.2`），上传资产 `Leucus-0.0.2.zip` 与 `appcast.xml`。
- 同步：`release-assets-to-pages.yml`（release 事件）执行成功，`gh-pages` 分支 `appcast.xml` 已包含 `0.0.2` 条目（CDN 可能存在短暂缓存延迟）。
- 排查：通过 `log stream` 定位到 Sparkle 启动失败根因为 `SUPublicEDKey` 空值导致 `The provided EdDSA key could not be decoded`，并确认将 XPCServices 复制到 `Contents/XPCServices` 会触发 Sparkle Fatal（XPC 必须位于 `Sparkle.framework` 内）。
- 修复：移除错误的 `Embed Sparkle XPC Services` 构建阶段，恢复 Sparkle 默认 XPC 布局；同时从 `Info.plist` 删除 `SUPublicEDKey` 空占位，避免无效公钥导致 updater 启动失败。
- 版本：发布 `0.0.4 (4)`（Git tag: `v0.0.4`），用于验证升级链路修复。
- 验证：Release 构建下手动触发“检查更新…”不再出现 `Unable to Check For Updates`，弹窗为 `You’re up to date!`；`release-assets-to-pages.yml`（run `23376568961`）成功，`gh-pages` 的 `appcast.xml` 已更新为 `0.0.4` 顶项。
- 规范化：生成并接入 Sparkle EdDSA 密钥；`LEUCUS_SPARKLE_PUBLIC_KEY` 写入有效公钥，`SUPublicEDKey` 恢复为构建变量注入。
- 防护：新增公钥格式校验（Base64 且解码后 32 字节）；公钥无效时禁用 updater，避免 Sparkle 启动阶段 fatal。
- 自动化：新增脚本 `scripts/release_leucus_sparkle.sh` 与 `make release-leucus-sparkle VERSION=...`，串联构建、签名 appcast、上传 Release。
- CI：新增 `.github/workflows/release-signed-sparkle.yml`，支持 `workflow_dispatch` 输入版本号后在 GitHub Actions 内完成签名发布。
- 安全：仓库新增 Secret `SPARKLE_PRIVATE_KEY`，用于 CI 中 `generate_appcast --ed-key-file -` 签名，不再依赖本机私钥参与发布。
- 发布：创建 GitHub Release `v0.0.5`（`Leucus 0.0.5`），资产为 `Leucus-0.0.5.zip` + 签名 `appcast.xml`（包含 `sparkle:edSignature`）。
- 同步：`release-assets-to-pages.yml`（run `23376930242`）成功，`gh-pages` 顶项已更新为 `0.0.5`。

## 2026-03-20

- 修复：`Leucus` 的 `AppIcon` 全尺寸资源补齐为 macOS 标准槽位（`16/32/128/256/512` 的 `1x/2x`）。
- 修复：原始图标从非正方形源图统一裁切并输出为 `1024x1024`（对应 `512@2x`）。
- 验证：`xcodebuild -project Example/Leucus.xcodeproj -scheme Leucus -destination 'platform=macOS' build` 下，`actool` 不再出现 icon 尺寸告警。
- 新增：`Leucus` 接入 Sparkle 自动升级，应用菜单增加“检查更新…”入口，支持手动触发更新检查。
- 新增：`Leucus` 显式 `Info.plist`（包含 `SUFeedURL` / `SUPublicEDKey` / 自动检查相关键），并通过 `LEUCUS_APPCAST_URL` / `LEUCUS_SPARKLE_PUBLIC_KEY` 注入；未配置有效 feed 时自动禁用菜单动作。
- 新增：GitHub Pages 分发模板配置（`LEUCUS_GITHUB_OWNER` / `LEUCUS_GITHUB_REPO` -> `LEUCUS_APPCAST_URL`），为仓库改名后快速切换 appcast 地址做准备。
- 新增：GitHub Actions 工作流 `.github/workflows/release-assets-to-pages.yml`，在 release 发布后自动同步 `appcast.xml` 与 `.zip` 到 `gh-pages`。
- 验证：`xcodebuild -project Example/Leucus.xcodeproj -scheme Leucus -destination 'platform=macOS' build` 成功，产物 `Info.plist` 已包含 Sparkle 关键字段。
