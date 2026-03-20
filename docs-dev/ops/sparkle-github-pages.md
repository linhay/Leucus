# Sparkle + GitHub Pages 发布流程（Leucus）

## 1. 先改 GitHub 仓库名
1. 在 GitHub 仓库 `Settings -> General -> Repository name` 修改仓库名（建议与 App 一致：`Leucus`）。
2. 本地同步远端地址：
   - `git remote set-url origin git@github.com:linhay/Leucus.git`
   - `git remote -v` 确认已更新。

## 2. 打开 GitHub Pages
1. 在仓库 `Settings -> Pages` 里开启 Pages。
2. 选择发布分支（建议 `gh-pages`）和根目录（`/`）。
3. 确认可访问地址：`https://linhay.github.io/Leucus/`。

## 3. Sparkle 配置
`Example/Leucus.xcodeproj` 里默认已配置：
1. `LEUCUS_GITHUB_OWNER = linhay`
2. `LEUCUS_GITHUB_REPO = Leucus`
3. `LEUCUS_APPCAST_URL = https://$(LEUCUS_GITHUB_OWNER).github.io/$(LEUCUS_GITHUB_REPO)/appcast.xml`
4. `LEUCUS_SPARKLE_PUBLIC_KEY = ""`（发布前必须填入公钥）

## 4. 发布产物到 Pages
1. 生成并签名发布包（`.zip`）。
2. 使用 Sparkle `generate_appcast` 生成 `appcast.xml`。
3. 将 `appcast.xml` 和发布包上传到 Pages 站点根目录（或同层可访问目录）。
4. 校验：
   - `appcast.xml` 可公网访问。
   - 下载链接可访问。
   - App 内“检查更新…”可拉到新版本。

## 5. 自动同步（已接入）
仓库已提供工作流：`.github/workflows/release-assets-to-pages.yml`

触发方式：
1. 发布 GitHub Release（`published`）自动触发。
2. 手动触发 `workflow_dispatch`，可指定 `release_tag`。

同步规则：
1. 从 Release 资产中下载 `appcast.xml` 与 `*.zip`。
2. 写入 `gh-pages`：
   - `appcast.xml` -> 站点根目录
   - `*.zip` -> `releases/`
3. 自动提交并推送到 `gh-pages` 分支。
