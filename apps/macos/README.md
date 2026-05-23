# macOS 菜单栏 App

macOS 端是 SwiftUI `MenuBarExtra` 应用，默认接入 `../../shared/swift` 中的 `TodoShared` 包。任务本地存储使用 `FileTodoLocalStorage`，快速新增会通过 `LocalTodoRepository` 创建本地任务并写入同步队列，同步由 `TodoSyncEngine` 调用后端协议。

## 后端地址

运行前配置真实服务地址：

```bash
export TODO_API_BASE_URL="https://your-server.example.com"
```

未配置时应用启动即失败，避免把占位地址当成真实后端。配置真实服务器后，Apple 登录会把 `AuthenticationServices` 返回的 identity token 发送到 `/auth/apple`。

## 打开方式

在 macOS 上：

```bash
cd apps/macos
open Package.swift
```

然后在 Xcode 中选择 `TodoMenuBarApp` scheme 运行。菜单栏会出现 `AI Todos` 图标。

## 当前范围

- Apple 登录：使用 `SignInWithAppleButton` 获取 identity token，并调用真实 `/auth/apple`。
- 任务列表：展示 shared 本地仓库中的未删除任务。
- 快速新增：创建本地任务并入队等待同步。
- 完成任务：通过 shared 本地仓库更新任务并入队。
- 同步状态：调用 shared sync engine，失败时保留本地队列等待重试。

第一版只包含菜单栏应用。

## Linux 静态验证

Linux 环境无法编译 AppKit/SwiftUI。可执行的静态验证：

```bash
cd /home/agbox/workspace/todolist
rg -n "import TodoShared" apps/macos/Sources apps/macos/Package.swift
rg -n "PlaceholderTodoService|authenticateWithApplePlaceholder" apps/macos/Sources apps/macos/Package.swift || true
rg -n "TodoShared|../../shared/swift" apps/macos/Package.swift
rg -n "Widget|widget" apps/macos/Sources apps/macos/Package.swift || true
```
