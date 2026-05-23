# 需求 1：AI 待办 App 第一版

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
