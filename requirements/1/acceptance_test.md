# 需求 1 验收测试

本文档是需求 1 的验收权威清单，内容来自 `docs/zh/product_plan.md`。

## 状态表

| ID | 层级 | 验收项 | 验证方式 | 当前状态 | 证据 |
| --- | --- | --- | --- | --- | --- |
| A1 | L1 | 后端接口、安全和用户隔离 | `cd server && go test ./... && go vet ./...` | PASS | 当前环境已执行通过 |
| A2 | L1 | iOS/macOS 静态接入 shared 和真实 API client | 见下方静态命令 | PASS | 当前环境已执行通过 |
| A3 | L1 | shared Swift 自动化测试 | `cd shared/swift && swift test` | BLOCKED | 当前 Linux 环境无 `swift` |
| A4 | L2 | iOS App 和 Widget 构建 | `xcodebuild ... build` | BLOCKED | 当前 Linux 环境无 Xcode |
| A5 | L2 | macOS 菜单栏 App 构建 | `cd apps/macos && swift build` | BLOCKED | 当前 Linux 环境无 `swift` |
| A6 | L2 | 同账号跨端同步和 Widget 实机展示 | iPhone/macOS + 已部署后端手工验收 | BLOCKED | 需要真实 Apple Team、Bundle ID、App Group、后端 |
| A7 | L3 | 人工范围确认 | 人工按产品计划确认 | PENDING | 待 L2 环境具备后执行 |

## L1：当前环境可执行

### A1 后端接口、安全和用户隔离

```bash
cd server
go test ./...
go vet ./...
```

通过标准：

- 未登录用户不能调用 AI 或任务接口。
- 用户 A 不能读取或修改用户 B 的任务。
- Apple identity token verifier 覆盖有效 token、错误 audience、未知 kid、签名失败和过期 token。
- DeepSeek 返回非法 JSON 时后端返回错误，不保存任务。

### A2 客户端静态接入

```bash
! rg -n "PlaceholderTodoBackendService|PlaceholderTodoService|placeholder-ios|placeholder-apple" apps/ios apps/macos --glob '!**/README.md'
rg -n "import TodoShared|URLSessionTodoAPIClient|LocalTodoRepository|TodoSyncEngine" apps/ios apps/macos --glob '!**/README.md'
! rg -n "replace-with-real|example.invalid|group.com.example.todolist|todo-api.example.invalid|com.example.todolist" apps/ios apps/macos --glob '!**/README.md'
uv run --quiet python -c "import plistlib, pathlib; [plistlib.load(open(p, 'rb')) for p in pathlib.Path('apps/ios').rglob('*.plist')]; [plistlib.load(open(p, 'rb')) for p in pathlib.Path('apps/ios').rglob('*.entitlements')]"
```

通过标准：

- iOS/macOS 默认运行路径不使用占位服务。
- iOS/macOS 均引用 shared Swift 核心。
- 客户端没有 DeepSeek API key。
- 默认配置不包含示例后端地址、示例 Bundle ID 或示例 App Group。

### A3 shared Swift 自动化测试

```bash
cd shared/swift
swift test
```

通过标准：

- 本地队列生成、同步成功清理、同步失败保留、最后写入优先和 Widget 排序通过。
- AI 草稿优先级协议接受后端定义的 `1..5`。

## L2：需要 macOS/Xcode/真实配置

配置：

- `TODO_API_BASE_URL` 指向已部署后端。
- `APP_GROUP_IDENTIFIER`、`TODO_APP_BUNDLE_ID`、`TODO_WIDGET_BUNDLE_ID`、`APPLE_DEVELOPMENT_TEAM` 使用真实 Apple Developer 配置。
- 后端默认使用 SQLite，配置 `SQLITE_PATH`、`JWT_SECRET`、`APPLE_BUNDLE_IDS`、`DEEPSEEK_API_KEY`；切到 Postgres 时再配置 `DATABASE_DRIVER=postgres` 和 `DATABASE_URL`。

命令：

```bash
xcodebuild -project apps/ios/TodoList.xcodeproj -target TodoList -destination 'generic/platform=iOS Simulator' build
cd apps/macos
swift build
```

通过标准：

- 同一 Apple 账号可在 iPhone 和 macOS 登录。
- 用户可输入自然语言，并得到可编辑的 AI 任务草稿。
- AI 能识别日期、重要程度和紧急程度。
- 离线新增或修改任务后，恢复网络能同步到另一端。
- iPhone 小组件能展示当前最重要和最紧急的任务。

## L3：人工范围确认

- iPhone App、macOS App、iPhone Widget、后端和同步策略均符合第一版范围。
- 第一版非目标未被引入实现范围。
- 后端部署说明符合裸机 systemd 目标，长期持久服务配置归 env_tools 管理。
