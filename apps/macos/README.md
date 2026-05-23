# macOS 菜单栏 App

这是 AI 待办 App 第一版 macOS 端骨架，入口是 SwiftUI `MenuBarExtra`。当前仓库尚未提供 `shared/swift` 包，因此本目录先用 `TodoServicing` 协议和 `PlaceholderTodoService` 占位，后续共享包稳定后在 `apps/macos/Sources/TodoMenuBarApp/Infrastructure/` 内替换适配实现即可。

## 打开方式

在 macOS 上：

```bash
cd apps/macos
open Package.swift
```

然后在 Xcode 中选择 `TodoMenuBarApp` scheme 运行。菜单栏会出现 `AI Todos` 图标。

## 当前范围

- Apple 登录入口占位：使用 `SignInWithAppleButton`，成功回调后进入占位会话。
- 任务列表：展示本地占位任务。
- 快速新增：向占位数据源新增任务。
- 完成任务：切换任务完成状态。
- 同步状态：展示同步中、待同步数、最近同步时间和错误状态。

第一版不包含 macOS 桌面 Widget。

## Linux 验证

Linux 环境无法编译 AppKit/SwiftUI。可执行的静态验证：

```bash
cd apps/macos
swift package dump-package
find Sources/TodoMenuBarApp -type f | sort
```
