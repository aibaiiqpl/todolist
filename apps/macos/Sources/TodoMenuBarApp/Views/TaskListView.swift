import SwiftUI
import TodoShared

struct TaskListView: View {
    @ObservedObject var viewModel: MenuBarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.tasks.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.tasks) { task in
                    taskRow(task)
                    if task.id != viewModel.tasks.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        HStack(spacing: 8) {
            Image(systemName: "tray")
                .foregroundStyle(.secondary)
            Text("No tasks yet")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 64)
    }

    private func taskRow(_ task: TodoTask) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                Task {
                    await viewModel.toggleCompletion(for: task)
                }
            } label: {
                Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.completed ? .green : .secondary)
            }
            .disabled(task.completed)
            .buttonStyle(.plain)
            .help(task.completed ? "Completed" : "Complete task")

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .strikethrough(task.completed)
                    .foregroundStyle(task.completed ? .secondary : .primary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    priorityBadge("Important", task.importance)
                    priorityBadge("Urgent", task.urgency)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func priorityBadge(_ label: String, _ level: TaskPriority) -> some View {
        Text("\(label): \(level.displayName)")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.quaternary, in: Capsule())
    }
}
