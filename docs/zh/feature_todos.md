# 功能代办清单

本文档是项目持久化代办清单。勾选表示该项已有当前环境可验证的证据；需要 Xcode、真实 Apple Developer 配置、实机或已部署后端的条目，在完成对应验收前保持未勾选。需求变化时先修改本清单和产品计划，再进入实现。

## 文档与流程

- [x] 固化产品计划到 `docs/zh/product_plan.md`
- [x] 固化功能代办到 `docs/zh/feature_todos.md`
- [x] 固化并行 Agent 协作规则到 `docs/zh/agent_workflow.md`
- [x] 创建需求 1 设计三件套到 `requirements/1/`
- [x] 创建验收清单入口到 `docs/zh/acceptance_checklist.md`

## Auth

- [ ] 实现 Apple 登录客户端流程（已实现，待 Xcode 与真实 Apple 配置验收）
- [x] 实现 `POST /auth/apple`
- [x] 后端校验 Apple identity token
- [x] 后端签发和校验应用 JWT
- [x] 用户表按 Apple subject 建立唯一身份
- [x] 所有业务 API 强制用户隔离
- [x] 添加鉴权失败和跨用户访问反例测试

## AI

- [x] 实现后端 DeepSeek API client
- [x] 实现 `POST /ai/organize`
- [x] DeepSeek API key 仅从后端环境变量读取
- [x] 提示词要求返回 JSON 任务草稿
- [x] 校验 AI 返回字段和类型
- [x] 解析失败时返回错误，不保存任务
- [x] 支持日期识别
- [x] 支持重要程度判断
- [x] 支持紧急程度判断
- [x] 添加一句话多任务测试
- [x] 添加无日期输入测试
- [x] 添加 DeepSeek 非法 JSON 反例测试

## Tasks

- [x] 设计并迁移 Postgres 任务表
- [ ] 实现任务本地模型（已实现，待 `swift test` 验收）
- [ ] 实现任务新增、编辑、完成和软删除（已实现，待 `swift test` 验收）
- [ ] 实现本地待同步操作队列（已实现，待 `swift test` 验收）
- [x] 实现 `GET /tasks/changes`
- [x] 实现 `POST /tasks/sync`
- [ ] 实现最后写入优先冲突策略（已实现，待 `swift test` 验收）
- [ ] 同步成功后清空对应本地队列项（已实现，待 `swift test` 验收）
- [ ] 同步失败时保留本地队列项等待重试（已实现，待 `swift test` 验收）
- [x] 添加软删除同步测试
- [ ] 添加离线编辑恢复同步测试（已写入 Swift 测试，待 `swift test` 验收）

## iOS

- [ ] 搭建 SwiftUI iPhone App（已实现，待 Xcode 构建验收）
- [ ] 接入共享 Swift Package（静态验收通过，待 Xcode 构建验收）
- [ ] 接入真实 Apple 登录流程（已实现，待真实 Apple 配置验收）
- [ ] 实现自然语言输入框（已实现，待 Xcode 构建验收）
- [ ] 支持系统键盘听写输入同一输入框（已实现，待实机验收）
- [ ] 接入真实 AI 草稿预览和编辑确认（已实现，待后端和 Xcode 验收）
- [ ] 接入真实任务列表（已实现，待 Xcode 构建验收）
- [ ] 接入真实任务完成和删除交互（已实现，待 Xcode 构建验收）
- [ ] 接入真实同步状态展示（已实现，待 Xcode 构建验收）
- [ ] 实现 iPhone 主屏 Widget（已实现，待 Xcode 构建验收）
- [ ] Widget 展示真实最重要任务（已实现，待 Widget 验收）
- [ ] Widget 展示真实最紧急任务（已实现，待 Widget 验收）
- [ ] Widget 点击进入 App（已实现，待实机验收）
- [ ] 添加 Widget 空状态验证（已写入 Swift 测试，待 `swift test` 验收）

## macOS

- [ ] 搭建 macOS 菜单栏 App（已实现，待 `swift build` 验收）
- [ ] 接入共享 Swift Package（静态验收通过，待 `swift build` 验收）
- [ ] 接入真实 Apple 登录流程（已实现，待真实 Apple 配置验收）
- [ ] 展示真实任务列表（已实现，待 `swift build` 验收）
- [ ] 接入真实快速新增任务（已实现，待 `swift build` 验收）
- [ ] 接入真实完成任务（已实现，待 `swift build` 验收）
- [ ] 展示真实同步状态（已实现，待 `swift build` 验收）
- [ ] 验证与 iPhone 端同账号同步

## Server

- [x] 搭建 Go 服务结构
- [x] 配置 Postgres 连接
- [x] 编写数据库迁移
- [x] 实现 REST JSON 错误格式
- [x] 实现 JWT 中间件
- [x] 实现用户隔离查询
- [x] 实现 DeepSeek 调用超时和错误处理
- [x] 编写 systemd 部署说明
- [x] 添加 API 集成测试

## Testing

- [x] 后端鉴权测试
- [x] 后端用户隔离测试
- [x] 后端任务同步测试
- [x] 后端 AI key 缺失失败测试
- [ ] Swift shared 本地队列测试（已写入，待 `swift test` 验收）
- [ ] Swift shared 同步成功测试（已写入，待 `swift test` 验收）
- [ ] Swift shared 同步失败重试测试（已写入，待 `swift test` 验收）
- [ ] iOS AI 草稿确认验收
- [ ] macOS 菜单栏基础验收
- [ ] iPhone Widget 排序和空状态验收
