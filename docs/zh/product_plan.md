# AI 待办 App 产品计划

## 目标

构建一个跨 iPhone 与 macOS 的 AI 待办应用。用户可以用自然语言输入零散想法，App 通过 DeepSeek 整理成结构化任务，并在 iPhone、macOS 和 iPhone 主屏小组件之间同步。

## 第一版范围

- iPhone App：SwiftUI 原生界面，支持 Apple 登录、自然语言输入、AI 整理、任务确认、任务列表、完成和删除。
- macOS App：菜单栏轻应用，支持 Apple 登录、查看任务、快速新增、完成任务和同步状态展示。
- iPhone 小组件：使用 WidgetKit 展示最重要和最紧急的任务；第一版只读，点击进入 App。
- 后端：自建 Go + Postgres REST JSON API，负责 Apple 登录校验、JWT、任务同步、DeepSeek 代理和用户数据隔离。
- 同步：客户端支持离线编辑，恢复网络后同步；删除使用软删除；冲突采用最后写入优先。
- 语音输入：第一版依赖系统键盘听写，不实现 App 内录音识别。

## 非目标

- 第一版不做 macOS 桌面 Widget。
- 第一版不做 App 内麦克风按钮或自研语音识别。
- 第一版不做团队协作、共享清单、标签体系、项目管理视图或复杂 GTD 流程。
- 第一版不把 DeepSeek API key 放到客户端。
- 第一版不做字段级冲突合并。

## 账号与安全

- 登录方式固定为 Apple 登录。
- 客户端拿到 Apple identity token 后调用后端 `POST /auth/apple`。
- 后端验证 Apple token，创建或匹配用户，然后签发应用自己的 JWT。
- 所有任务 API 必须校验 JWT，并按用户隔离数据。

## AI 整理

- 客户端将用户输入的自然语言发送到后端 `POST /ai/organize`。
- 后端调用 DeepSeek Chat Completions，并要求模型返回 JSON。
- AI 需要提取任务标题、重要程度、紧急程度、截止时间和原始输入来源。
- 后端必须校验 DeepSeek 返回结构；解析失败时直接返回错误，不静默保存错误任务。
- 客户端展示可编辑草稿，用户确认后才写入本地任务和同步队列。

## 任务模型

任务第一版包含：

- `id`
- `user_id`
- `title`
- `completed`
- `importance`
- `urgency`
- `due_at`
- `source_text`
- `created_at`
- `updated_at`
- `deleted_at`
- `version`

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

## 验收标准

- 同一 Apple 账号可在 iPhone 和 macOS 登录。
- 用户可输入一句自然语言，并得到可编辑的任务草稿。
- AI 能识别日期、重要程度和紧急程度。
- 未登录用户不能调用 AI 或任务接口。
- 用户 A 不能读取或修改用户 B 的任务。
- 离线新增或修改任务后，恢复网络能同步到另一端。
- iPhone 小组件能展示当前最重要和最紧急的任务。
