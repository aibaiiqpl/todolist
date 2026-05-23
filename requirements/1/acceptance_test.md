# 需求 1 验收测试

本文档是需求 1 的验收权威清单，内容来自 `docs/zh/product_plan.md`。

## 状态表

| 层级 | 状态 | 证据 |
| --- | --- | --- |
| L1 后端接口与安全 | PASS | `cd server && go test ./... && go vet ./...` |
| L1 客户端静态接入 | PASS | `rg` 检查 iOS/macOS 引用 `TodoShared` 且无占位服务默认路径 |
| L2 Apple 平台构建 | BLOCKED | 当前 Linux 环境无 `swift`、`xcodebuild` |
| L2 跨端实机同步 | BLOCKED | 需要 macOS/Xcode、真实 Bundle ID、App Group、Apple Developer Team 和已部署后端 |
| L3 人工体验验收 | PENDING | 待 L2 环境具备后执行 |

## L1：可在当前 Linux 环境执行

### 后端测试

命令：

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

### 客户端静态接入

命令：

```bash
rg -n "PlaceholderTodoBackendService|PlaceholderTodoService|placeholder-ios|placeholder-apple" apps/ios apps/macos
rg -n "import TodoShared|URLSessionTodoAPIClient|LocalTodoRepository|TodoSyncEngine" apps/ios apps/macos
rg -n "replace-with-real|example.invalid|group.com.example.todolist|todo-api.example.invalid" apps/ios apps/macos
uv run --quiet python -c "import plistlib, pathlib; [plistlib.load(open(p, 'rb')) for p in pathlib.Path('apps/ios').rglob('*.plist')]; [plistlib.load(open(p, 'rb')) for p in pathlib.Path('apps/ios').rglob('*.entitlements')]"
```

通过标准：

- iOS/macOS 默认运行路径不使用占位服务。
- iOS/macOS 均引用 shared Swift 核心。
- 客户端没有 DeepSeek API key。
- 默认配置不包含示例后端地址或示例 App Group。

## L2：需要 macOS/Xcode/真实配置

命令：

```bash
swift --version
cd shared/swift && swift test
xcodebuild -project apps/ios/TodoList.xcodeproj -target TodoList -destination 'generic/platform=iOS Simulator' build
cd apps/macos && swift build
```

手工配置：

- `TODO_API_BASE_URL` 指向已部署后端。
- `APP_GROUP_IDENTIFIER`、Bundle Identifier、Team 使用真实 Apple Developer 配置。
- 后端配置 `DATABASE_URL`、`JWT_SECRET`、`APPLE_BUNDLE_ID`、`DEEPSEEK_API_KEY`。

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
