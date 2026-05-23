# 需求 1 设计

## 架构

- iPhone App、macOS 菜单栏 App 和 iPhone Widget 通过共享 Swift 核心复用任务模型、API client、本地存储和同步队列。
- Go 后端提供 REST JSON API，连接 Postgres，代理 DeepSeek，并负责 Apple 登录校验、JWT 签发和用户数据隔离。
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
