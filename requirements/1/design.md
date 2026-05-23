# 需求 1 设计

## 架构

- iPhone App、macOS 菜单栏 App 和 iPhone Widget 通过共享 Swift 核心复用任务模型、API client、本地存储和同步队列。
- Go 后端提供 REST JSON API，默认连接 SQLite 方便本地开发，保留 Postgres 作为后续生产存储，代理 DeepSeek，并负责 Apple 登录校验、JWT 签发和用户数据隔离。
- DeepSeek API key 只保存在后端环境变量中，客户端不得持有。

## 账号与安全

- 登录方式固定为 Apple 登录。
- 客户端拿到 Apple identity token 后调用后端 `POST /auth/apple`。
- 后端验证 Apple token，创建或匹配用户，然后签发应用自己的 JWT。
- 所有任务 API 必须校验 JWT，并按用户隔离数据。

## AI 整理

- 客户端将自然语言输入发送到后端 `POST /ai/organize`。
- 后端调用 DeepSeek Chat Completions，并要求模型返回 JSON。
- AI 提取任务标题、重要程度、紧急程度、截止时间和原始输入来源。
- 后端校验 DeepSeek 返回结构；解析失败时直接返回错误，不静默保存错误任务。
- 客户端展示可编辑草稿，用户确认后才写入本地任务和同步队列。

## 任务模型

任务第一版包含：`id`、`user_id`、`title`、`completed`、`importance`、`urgency`、`due_at`、`source_text`、`created_at`、`updated_at`、`deleted_at`、`version`。

## 同步策略

- 客户端本地保存任务和待同步操作队列。
- 离线时允许新增、编辑、完成和删除任务。
- 联网后通过 `GET /tasks/changes` 拉取变更，通过 `POST /tasks/sync` 上传本地变更。
- 删除使用 `deleted_at` 软删除，确保删除状态能传播到其他设备。
- 冲突采用最后写入优先，比较服务端版本和更新时间后保留最终状态。

## 部署边界

- 后端部署目标是裸机 systemd。
- 本仓库保留应用配置、接口和部署说明。
- 长期运行服务的统一管理配置应放到 env_tools 项目，本仓库不维护持久服务编排。

## 配置

| 配置项 | 组件 | 推荐默认值 | 选择理由 |
| --- | --- | --- | --- |
| `ADDR` | 后端 | `:8080` | 本地和裸机部署都可直接启动，生产可由 systemd 环境文件覆盖。 |
| `DATABASE_DRIVER` | 后端 | `sqlite` | 第一版本地开发优先简单可运行；后续设为 `postgres` 可切回 Postgres。 |
| `SQLITE_PATH` | 后端 | `todolist.sqlite` | 本地无需安装数据库服务；文件路径可由部署环境覆盖。 |
| `DATABASE_URL` | 后端 | 空，仅 Postgres 必填 | SQLite 不需要该项；切到 Postgres 时必须显式配置，避免写入错误数据库。 |
| `JWT_SECRET` | 后端 | 空，启动失败 | JWT 签名密钥必须由部署环境提供，仓库不能提供可复用默认密钥。 |
| `APPLE_BUNDLE_IDS` | 后端 | 空，启动失败 | Apple identity token 的 audience 必须显式覆盖 iOS 与 macOS 客户端。 |
| `APPLE_BUNDLE_ID` | 后端 | 不设置 | 仅作为单客户端旧配置兼容入口；新部署必须使用 `APPLE_BUNDLE_IDS` 避免漏配 macOS audience。 |
| `DEEPSEEK_API_KEY` | 后端 | 空，启动失败 | 模型密钥只允许保存在后端部署环境，缺失时不能降级。 |
| `DEEPSEEK_MODEL` | 后端 | `deepseek-chat` | 使用 DeepSeek Chat Completions 的稳定默认模型，同时允许环境覆盖。 |
| `TODO_API_BASE_URL` | iOS/macOS | 空，客户端显示配置错误 | 客户端不能写死示例后端地址，真实地址必须来自构建配置。 |
| `APP_GROUP_IDENTIFIER` | iOS/Widget | 空，Widget 读写共享存储失败 | App Group 必须由 Apple Developer 配置决定，缺失时不能伪造共享数据。 |
| `TODO_APP_BUNDLE_ID` | iOS | 空，构建配置提供 | Bundle ID 必须与 Apple Developer 和后端 audience 一致。 |
| `TODO_WIDGET_BUNDLE_ID` | Widget | 空，构建配置提供 | Widget Bundle ID 必须与 App Group 和主 App 配置匹配。 |
| `APPLE_DEVELOPMENT_TEAM` | iOS/Widget | 空，构建配置提供 | 签名 Team 属于开发者账号信息，不能在仓库硬编码。 |
