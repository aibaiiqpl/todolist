import SwiftUI

struct TaskListView: View {
    @EnvironmentObject private var store: TodoStore

    private var visibleTasks: [TodoTask] {
        store.tasks.filter { !$0.isDeleted }
    }

    var body: some View {
        if visibleTasks.isEmpty {
            ContentUnavailableView("暂无任务", systemImage: "checklist")
        } else {
            ForEach(visibleTasks) { task in
                TaskRow(task: task) {
                    store.toggleCompletion(for: task)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        store.delete(task)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
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
