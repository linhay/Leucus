# Leucus 自动升级（Sparkle）

## 背景
为 `Example/Leucus` 接入 macOS 非商店分发常用的自动升级能力，支持手动检查更新与后台自动检查。

## 范围
1. 在 `Leucus` 示例工程集成 Sparkle。
2. 应用菜单提供“检查更新…”入口。
3. 默认启用自动检查更新（可下载由 Sparkle 自身策略控制）。
4. 通过 `Info.plist` 注入升级配置（`SUFeedURL`、`SUPublicEDKey`）。

## BDD 场景
1. Given 应用已配置 `SUFeedURL`
   When 应用启动
   Then Sparkle Updater 应启动并进入自动检查流程

2. Given 用户点击 App 菜单中的“检查更新…”
   When Sparkle 可用
   Then 应触发手动检查更新

3. Given 应用未配置 `SUFeedURL`
   When 应用启动并显示菜单
   Then “检查更新…”菜单项应置灰，避免触发无效检查

4. Given `SUFeedURL` 包含空格或无效格式
   When 解析升级配置
   Then 仅接受可解析为 `http/https` 的 URL，其余视为未配置

5. Given 已发布 GitHub Release（包含 `appcast.xml` 与 `.zip`）
   When `Sync Release Assets To Pages` 工作流触发
   Then 资产应自动同步到 `gh-pages`（`/appcast.xml` 与 `/releases/*.zip`）

## 验收标准
1. `Leucus` target 已链接 Sparkle。
2. App 启动后存在“检查更新…”菜单项。
3. 有效 `SUFeedURL` 时菜单可点击并触发 `checkForUpdates`。
4. `SUFeedURL` 无效或缺失时菜单不可点击。
5. URL 解析逻辑有自动化测试覆盖。
6. GitHub Release 发布后可自动同步 Sparkle 资产到 GitHub Pages。

## 配置说明
1. `LEUCUS_GITHUB_OWNER`：GitHub 用户或组织名（默认 `linhay`）。
2. `LEUCUS_GITHUB_REPO`：用于 GitHub Pages 分发的仓库名（默认 `Leucus`）。
3. `LEUCUS_APPCAST_URL`：默认由 `owner/repo` 组合为 `https://$(LEUCUS_GITHUB_OWNER).github.io/$(LEUCUS_GITHUB_REPO)/appcast.xml`，也可手动覆盖。
4. `LEUCUS_SPARKLE_PUBLIC_KEY`：Sparkle EdDSA 公钥（用于更新包签名验证）。
