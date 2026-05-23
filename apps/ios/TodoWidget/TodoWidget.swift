import SwiftUI
import WidgetKit

private let appGroupIdentifier = "group.com.example.todolist"
private let widgetSnapshotKey = "todo.widget.snapshot"

struct WidgetTaskSnapshot: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let importance: Int
    let urgency: Int
    let dueAt: Date?
}

struct TodoWidgetSnapshot: Codable, Equatable {
    let mostImportant: WidgetTaskSnapshot?
    let mostUrgent: WidgetTaskSnapshot?
    let updatedAt: Date
}

struct TodoWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: TodoWidgetSnapshot
}

struct TodoTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodoWidgetEntry {
        TodoWidgetEntry(
            date: Date(),
            snapshot: TodoWidgetSnapshot(
                mostImportant: WidgetTaskSnapshot(
                    id: UUID().uuidString,
                    title: "确认产品计划",
                    importance: 3,
                    urgency: 2,
                    dueAt: nil
                ),
                mostUrgent: WidgetTaskSnapshot(
                    id: UUID().uuidString,
                    title: "今天同步待办",
                    importance: 2,
                    urgency: 3,
                    dueAt: Date()
                ),
                updatedAt: Date()
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TodoWidgetEntry) -> Void) {
        completion(TodoWidgetEntry(date: Date(), snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoWidgetEntry>) -> Void) {
        let entry = TodoWidgetEntry(date: Date(), snapshot: loadSnapshot())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }

    private func loadSnapshot() -> TodoWidgetSnapshot {
        guard
            let data = UserDefaults(suiteName: appGroupIdentifier)?.data(forKey: widgetSnapshotKey),
            let snapshot = try? JSONDecoder().decode(TodoWidgetSnapshot.self, from: data)
        else {
            return TodoWidgetSnapshot(mostImportant: nil, mostUrgent: nil, updatedAt: Date())
        }
        return snapshot
    }
}

struct TodoWidgetView: View {
    let entry: TodoWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI 待办")
                .font(.headline)

            if entry.snapshot.mostImportant == nil && entry.snapshot.mostUrgent == nil {
                Text("暂无待办")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                if let task = entry.snapshot.mostImportant {
                    WidgetTaskRow(label: "最重要", task: task)
                }

                if let task = entry.snapshot.mostUrgent {
                    WidgetTaskRow(label: "最紧急", task: task)
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .containerBackgroundIfAvailable()
        .widgetURL(URL(string: "todolist://tasks"))
    }
}

private struct WidgetTaskRow: View {
    let label: String
    let task: WidgetTaskSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(task.title)
                .font(.caption)
                .lineLimit(2)
        }
    }
}

private extension View {
    @ViewBuilder
    func containerBackgroundIfAvailable() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(.background, for: .widget)
        } else {
            self
        }
    }
}

struct TodoWidget: Widget {
    let kind = "TodoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoTimelineProvider()) { entry in
            TodoWidgetView(entry: entry)
        }
        .configurationDisplayName("AI 待办")
        .description("展示最重要和最紧急的任务")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct TodoWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodoWidget()
    }
}
