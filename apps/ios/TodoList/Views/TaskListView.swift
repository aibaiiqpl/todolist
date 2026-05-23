import SwiftUI

struct TaskListView: View {
    @EnvironmentObject private var store: TodoStore
    @State private var editingTask: TodoTask?
    @State private var editingTitle = ""

    private var visibleTasks: [TodoTask] {
        store.tasks.filter { !$0.isDeleted }
    }

    var body: some View {
        Group {
            if visibleTasks.isEmpty {
                ContentUnavailableView("暂无任务", systemImage: "checklist")
            } else {
                ForEach(visibleTasks) { task in
                    TaskRow(task: task) {
                        Task {
                            await store.toggleCompletion(for: task)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            editingTask = task
                            editingTitle = task.title
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                        .tint(.blue)

                        Button(role: .destructive) {
                            Task {
                                await store.delete(task)
                            }
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .alert("编辑任务", isPresented: editBinding) {
            TextField("任务标题", text: $editingTitle)
            Button("保存") {
                guard let editingTask else {
                    return
                }
                Task {
                    await store.updateTitle(for: editingTask, title: editingTitle)
                    self.editingTask = nil
                    editingTitle = ""
                }
            }
            Button("取消", role: .cancel) {
                editingTask = nil
                editingTitle = ""
            }
        }
    }

    private var editBinding: Binding<Bool> {
        Binding(
            get: { editingTask != nil },
            set: { isPresented in
                if !isPresented {
                    editingTask = nil
                    editingTitle = ""
                }
            }
        )
    }
}

private struct TaskRow: View {
    let task: TodoTask
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                onToggle()
            } label: {
                Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.completed ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .strikethrough(task.completed)
                    .foregroundStyle(task.completed ? .secondary : .primary)

                HStack(spacing: 8) {
                    Badge(text: "重要 \(task.importance.title)")
                    Badge(text: "紧急 \(task.urgency.title)")

                    if let dueAt = task.dueAt {
                        Badge(text: dueAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct Badge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.thinMaterial, in: Capsule())
    }
}
