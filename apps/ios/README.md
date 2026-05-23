# iOS MVP

打开方式：

1. 在 macOS 上打开 `apps/ios/TodoList.xcodeproj`。
2. 将 App 与 Widget target 的 Bundle Identifier、App Group `group.com.example.todolist` 替换成团队真实值。
3. 选择 `TodoList` scheme，使用 iPhone 模拟器运行。

当前骨架：

- SwiftUI iPhone App。
- Apple 登录入口占位。
- 自然语言 `TextEditor` 输入，系统键盘听写会进入同一输入框。
- AI 草稿预览、编辑和确认。
- 任务列表、完成和软删除交互。
- 同步状态展示。
- WidgetKit 只读 Widget，通过 App Group 快照展示最重要和最紧急任务，点击 `todolist://tasks` 回到 App。

`shared/swift` 稳定前，App 内使用 `TodoBackendServicing` 协议和 `PlaceholderTodoBackendService` 占位实现。协议语义对齐后端 canonical contract：

- `POST /auth/apple`：`{"identity_token"}` -> `{"user_id","access_token","expires_at"}`。
- `POST /ai/organize`：`{"input"}` -> `{"drafts":[...]}`。
- `GET /tasks/changes?since_version=N`：`{"tasks","server_version"}`。
- `POST /tasks/sync`：`{"operations":[{"id","kind","task","created_at"}]}` -> `{"acknowledged_operation_ids","tasks","server_version"}`。
