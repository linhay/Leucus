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
4. `LEUCUS_SPARKLE_PUBLIC_KEY`：必须为有效 EdDSA 公钥（Base64，可解码为 32 字节）

密钥生成/导出（本机一次性）：
1. `generate_keys --account linhay.Leucus`
2. `generate_keys --account linhay.Leucus -x ~/.config/leucus/sparkle_private_key.txt`
3. `chmod 600 ~/.config/leucus/sparkle_private_key.txt`

## 4. 发布产物到 Pages
1. 生成并签名发布包（`.zip`）。
2. 使用 Sparkle `generate_appcast --ed-key-file <private_key_file>` 生成带 `sparkle:edSignature` 的 `appcast.xml`。
3. 将 `appcast.xml` 和发布包上传到 Pages 站点根目录（或同层可访问目录）。
4. 校验：
   - `appcast.xml` 可公网访问。
   - 下载链接可访问。
   - 新条目包含 `sparkle:edSignature`。
   - App 内“检查更新…”可拉到新版本。

推荐发布命令（仓库已内置）：
1. `make release-leucus-sparkle VERSION=0.0.x`
2. 私钥路径默认读取 `~/.config/leucus/sparkle_private_key.txt`，也可通过环境变量覆盖：
   - `SPARKLE_PRIVATE_KEY_FILE=/path/to/private_key.txt make release-leucus-sparkle VERSION=0.0.x`

## 6. CI 签名发布（GitHub Actions）
新增工作流：`.github/workflows/release-signed-sparkle.yml`
1. 先配置仓库 Secret：
   - `SPARKLE_PRIVATE_KEY`（内容为导出的私钥文本）
2. 在 GitHub Actions 手动运行 `Release Signed Sparkle Build`，输入 `version`（如 `0.0.6`）。
3. 工作流会自动：
   - 构建 Release `.app`
   - 打包 `Leucus-<version>.zip`
   - 使用 `SPARKLE_PRIVATE_KEY` 签名生成 `appcast.xml`
   - 创建/更新 GitHub Release（附带 zip + appcast）
4. Release 发布后，`release-assets-to-pages.yml` 会自动将资产同步到 `gh-pages`。

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
