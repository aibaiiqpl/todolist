# Agent 协作说明

本文档定义多 Agent 并行开发边界。后续开发前先确认公共接口已写入产品计划或需求文档，再分配 Agent。

## 协作原则

- 每个 Agent 只修改自己负责的目录和文件。
- 公共接口、数据模型和错误语义先写入文档，再进入实现。
- 多 Agent 并行时，禁止重写或回滚其他 Agent 的改动。
- 开发 Agent 交付后必须说明修改文件、验证命令和未完成项。
- Review Agent 必须使用独立上下文，不继承开发 Agent 的假设。
- 发现需求变化时，先更新 `docs/zh/product_plan.md` 和 `docs/zh/feature_todos.md`，再继续实现。

## 推荐目录边界

- `server/`：Go 后端 API、DeepSeek 集成、Postgres 访问、鉴权和测试。
- `migrations/`：数据库 schema 迁移。
- `shared/swift/`：Swift 共享模型、API client、本地存储、同步队列。
- `apps/ios/`：iPhone SwiftUI App 和 WidgetKit 扩展。
- `apps/macos/`：macOS 菜单栏 App。
- `docs/zh/`：中文计划、代办、协作和验收文档。

## Agent A：后端

职责：

- 实现 Go REST API。
- 实现 Apple 登录校验和 JWT。
- 实现 Postgres schema、迁移和用户隔离。
- 实现 DeepSeek 后端代理和 AI 返回校验。
- 实现任务同步接口。

禁止：

- 修改 Swift 客户端 UI。
- 把 DeepSeek API key 写入客户端或仓库。
- 让 AI 解析失败静默降级为普通文本任务。

交付要求：

- 提供后端测试命令和结果。
- 覆盖鉴权失败、用户隔离、AI 非法 JSON 和同步冲突。

## Agent B：Swift 共享核心

职责：

- 定义 Swift 任务模型和同步模型。
- 实现 API client。
- 实现本地存储和待同步操作队列。
- 实现离线编辑和同步重试。

禁止：

- 直接实现平台专属 UI。
- 绕过后端协议自造客户端专用字段。

交付要求：

- 提供 Swift Package 测试命令和结果。
- 覆盖队列生成、同步成功清理、同步失败保留和最后写入优先。

## Agent C：iOS

职责：

- 实现 iPhone SwiftUI App。
- 接入 Apple 登录。
- 实现自然语言输入、系统听写输入承载、AI 草稿确认和任务列表。
- 实现 iPhone 主屏 Widget。

禁止：

- 在 iOS App 中保存 DeepSeek API key。
- 第一版实现 App 内麦克风录音识别。

交付要求：

- 提供 Xcode 或 xcodebuild 验证方式。
- 验证 Widget 展示最重要和最紧急任务。

## Agent D：macOS

职责：

- 实现 macOS 菜单栏 App。
- 接入共享 Swift Package。
- 实现登录、任务展示、快速新增、完成任务和同步状态。

禁止：

- 第一版实现 macOS 桌面 Widget。
- 修改后端 API 语义。

交付要求：

- 提供 macOS App 构建和基础验收方式。
- 验证与 iPhone 使用同一账号同步。

## Agent E：测试与验收

职责：

- 独立检查需求覆盖。
- 执行后端、Swift shared、iOS、macOS 和 Widget 验收。
- 对照 `docs/zh/feature_todos.md` 标记真实完成状态。

禁止：

- 继承开发 Agent 的未验证假设。
- 只做正例验证；必须包含反例。

交付要求：

- 只报告阻塞问题、缺失测试、实际验证命令和结果。
- 验证通过后更新代办勾选状态。

## 并行开发顺序

1. Agent A 和 Agent B 先并行实现后端协议与共享核心。
2. 公共接口稳定后，Agent C 和 Agent D 并行接入平台 UI。
3. Agent E 在每个阶段完成后独立 review。
4. 发现公共接口需要变更时，暂停相关实现，先更新文档和代办清单。
