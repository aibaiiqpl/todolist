# iOS MVP

打开方式：

1. 在 macOS 上打开 `apps/ios/TodoList.xcodeproj`。
2. 将 App 与 Widget target 的 Bundle Identifier、App Group `group.com.example.todolist` 替换成团队真实值。
3. 选择 `TodoList` scheme，使用 iPhone 模拟器运行。

当前界面骨架：

- SwiftUI iPhone App。
- Apple 登录入口使用 `SignInWithAppleButton` 获取 identity token，并通过 shared Swift Package 调用真实 `POST /auth/apple`。
- 自然语言 `TextEditor` 输入，系统键盘听写会进入同一输入框。
- AI 草稿预览、编辑和确认，整理请求通过真实 `POST /ai/organize` 返回多个草稿。
- 任务列表、完成和软删除交互，确认后的任务写入 shared 本地文件仓储并进入离线队列。
- 同步状态展示，刷新时通过 shared sync engine 推送队列并拉取服务端变更；失败时队列保留在本地文件中。
- WidgetKit 只读 Widget，通过 App Group 快照展示最重要和最紧急任务，点击 `todolist://tasks` 回到 App。

真实后端地址通过 `TodoList/Info.plist` 的 `TodoAPIBaseURL` 配置。当前值是占位地址，接入环境时必须替换为真实服务器地址；不要在 iOS 工程中写入任何 AI provider key。

App target 已接入本地 Swift Package `../../shared/swift`，并链接 `TodoShared` product。当前协议由 shared `URLSessionTodoAPIClient` 承载：

- `POST /auth/apple`：`{"identity_token"}` -> `{"user_id","access_token","expires_at"}`。
- `POST /ai/organize`：`{"input"}` -> `{"drafts":[...]}`。
- `GET /tasks/changes?since_version=N`：`{"tasks","server_version"}`。
- `POST /tasks/sync`：`{"operations":[{"id","kind","task","created_at"}]}` -> `{"acknowledged_operation_ids","tasks","server_version"}`。
