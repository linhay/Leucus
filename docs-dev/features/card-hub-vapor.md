# Card Hub Vapor（卡片中枢控制服务）

## 背景
- 当前卡片交互主要发生在本地 UI 内，缺少统一中枢来承载“卡片控制命令”。
- 需要引入 Vapor 服务作为中枢，使卡片可通过统一命令通道互相控制。
- 为支持多空间，路由采用“空间 + 卡片”资源模型。

## 路由设计（主流 REST）
- 采用版本化前缀：`/api/v1`
- 采用资源分层：`spaces -> cards -> commands/actions`

Canonical 路由：
- `GET /api/v1/health`：健康检查
- `POST /api/v1/spaces/:spaceID/commands`：向指定空间投递命令（请求体包含 targetCardID）
- `GET /api/v1/spaces/:spaceID/cards/:cardID/commands`：拉取并消费该空间内某卡片命令
- `GET /api/v1/spaces/:spaceID/cards/:cardID/routes`：拉取该卡片动作路由描述
- `POST /api/v1/spaces/:spaceID/cards/:cardID/actions/select`
- `POST /api/v1/spaces/:spaceID/cards/:cardID/actions/close`
- `POST /api/v1/spaces/:spaceID/cards/:cardID/actions/title`
- `POST /api/v1/spaces/:spaceID/cards/:cardID/actions/url`
- `POST /api/v1/spaces/:spaceID/cards/:cardID/actions/directory`

说明：不再保留旧版兼容路由（`/api/...`、`/api/v1/canvases/...`）。

## 领域模型
- `CardControlCommand` 使用 `spaceID`
- 命令队列键为 `(spaceID, cardID)`，确保多空间隔离

## BDD 验收场景
1. Given 中枢服务已启动
   When 客户端调用 `POST /api/v1/spaces/:spaceID/commands` 投递命令
   Then 服务应返回接受状态，并将命令写入对应 `(spaceID, targetCardID)` 队列

2. Given 某空间某卡片队列中已有待处理命令
   When 客户端调用 `GET /api/v1/spaces/:spaceID/cards/:cardID/commands`
   Then 应返回该队列命令列表，并从队列中消费

3. Given 两个空间使用同一个 `cardID`
   When 分别向两个空间投递命令
   Then 拉取命令时应严格按 `spaceID` 隔离，不得串线

4. Given 客户端按卡片动作路由发起控制请求
   When 调用 `POST /api/v1/spaces/:spaceID/cards/:cardID/actions/<action>`
   Then 中枢应将请求映射为统一控制命令并写入该卡片队列

5. Given 客户端调用旧路由
   When 请求进入服务
   Then 服务应返回 404（路由不存在）

## 验收标准
1. `CardHubService` 仅暴露版本化 `spaces` canonical 路由。
2. API 路由具备最小输入校验（`spaceID/cardID` 合法、`action/value` 非空）。
3. 至少覆盖“投递-拉取-消费”链路、多空间隔离、动作映射与旧路由不可用测试。
4. `CanvasWorkspaceView` 现有命令轮询链路保持兼容（调用者使用新路由即可）。

## 路由发现
- `GET /api/v1/spaces/:spaceID/cards/:cardID/routes`
- 返回字段：`spaceID`、`cardID`、`routes[]`
- `routes[]` 项包含：`action`、`method`、`pathTemplate`、`mappedCommandAction`、`requiresValue`、`scope`
