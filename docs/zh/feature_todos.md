# 功能代办清单

本文档是项目持久化代办清单。功能完成后直接勾选对应条目；需求变化时先修改本清单和产品计划，再进入实现。

## 文档与流程

- [x] 固化产品计划到 `docs/zh/product_plan.md`
- [x] 固化功能代办到 `docs/zh/feature_todos.md`
- [x] 固化并行 Agent 协作规则到 `docs/zh/agent_workflow.md`
- [ ] 创建 GitHub issue 后同步到 `requirements/<issue-id>/` 设计三件套

## Auth

- [ ] 实现 Apple 登录客户端流程
- [ ] 实现 `POST /auth/apple`
- [ ] 后端校验 Apple identity token
- [ ] 后端签发和校验应用 JWT
- [ ] 用户表按 Apple subject 建立唯一身份
- [ ] 所有业务 API 强制用户隔离
- [ ] 添加鉴权失败和跨用户访问反例测试

## AI

- [ ] 实现后端 DeepSeek API client
- [ ] 实现 `POST /ai/organize`
- [ ] DeepSeek API key 仅从后端环境变量读取
- [ ] 提示词要求返回 JSON 任务草稿
- [ ] 校验 AI 返回字段和类型
- [ ] 解析失败时返回错误，不保存任务
- [ ] 支持日期识别
- [ ] 支持重要程度判断
- [ ] 支持紧急程度判断
- [ ] 添加一句话多任务测试
- [ ] 添加无日期输入测试
- [ ] 添加 DeepSeek 非法 JSON 反例测试

## Tasks

- [ ] 设计并迁移 Postgres 任务表
- [ ] 实现任务本地模型
- [ ] 实现任务新增、编辑、完成和软删除
- [ ] 实现本地待同步操作队列
- [ ] 实现 `GET /tasks/changes`
- [ ] 实现 `POST /tasks/sync`
- [ ] 实现最后写入优先冲突策略
- [ ] 同步成功后清空对应本地队列项
- [ ] 同步失败时保留本地队列项等待重试
- [ ] 添加软删除同步测试
- [ ] 添加离线编辑恢复同步测试

## iOS

- [ ] 搭建 SwiftUI iPhone App
- [ ] 接入共享 Swift Package
- [ ] 实现 Apple 登录入口
- [ ] 实现自然语言输入框
- [ ] 支持系统键盘听写输入同一输入框
- [ ] 实现 AI 草稿预览和编辑确认
- [ ] 实现任务列表
- [ ] 实现任务完成和删除交互
- [ ] 实现同步状态展示
- [ ] 实现 iPhone 主屏 Widget
- [ ] Widget 展示最重要任务
- [ ] Widget 展示最紧急任务
- [ ] Widget 点击进入 App
- [ ] 添加 Widget 空状态验证

## macOS

- [ ] 搭建 macOS 菜单栏 App
- [ ] 接入共享 Swift Package
- [ ] 实现 Apple 登录入口
- [ ] 展示任务列表
- [ ] 支持快速新增任务
- [ ] 支持完成任务
- [ ] 展示同步状态
- [ ] 验证与 iPhone 端同账号同步

## Server

- [ ] 搭建 Go 服务结构
- [ ] 配置 Postgres 连接
- [ ] 编写数据库迁移
- [ ] 实现 REST JSON 错误格式
- [ ] 实现 JWT 中间件
- [ ] 实现用户隔离查询
- [ ] 实现 DeepSeek 调用超时和错误处理
- [ ] 编写 systemd 部署说明
- [ ] 添加 API 集成测试

## Testing

- [ ] 后端鉴权测试
- [ ] 后端用户隔离测试
- [ ] 后端任务同步测试
- [ ] 后端 AI key 缺失失败测试
- [ ] Swift shared 本地队列测试
- [ ] Swift shared 同步成功测试
- [ ] Swift shared 同步失败重试测试
- [ ] iOS AI 草稿确认验收
- [ ] macOS 菜单栏基础验收
- [ ] iPhone Widget 排序和空状态验收
