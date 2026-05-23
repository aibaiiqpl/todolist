# TodoList Agent 规则

## 项目文档

- 产品计划：`docs/zh/product_plan.md`
- 功能代办：`docs/zh/feature_todos.md`
- Agent 协作：`docs/zh/agent_workflow.md`

## 文档归属

- 中文文档统一放在 `docs/zh/`。
- `requirements/<issue-id>/` 只归档对应需求的需求、设计和验收材料。
- 完成项必须真实验收通过后才允许在 `docs/zh/feature_todos.md` 勾选；占位实现、骨架界面或未接入真实 shared/API 的客户端能力不得标记完成。

## 协作边界

- 并行开发时只修改自己负责的目录和文件。
- 禁止重写或回滚其他 Agent 的改动。
- 需求变化先更新产品计划和功能代办，再进入实现。
