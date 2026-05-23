import Foundation
import WidgetKit

private let appGroupIdentifier = "group.com.example.todolist"
private let widgetSnapshotKey = "todo.widget.snapshot"

struct WidgetTaskSnapshot: Codable, Identifiable, Equatable {
    let id: UUID
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

enum WidgetDataStore {
    static func publish(tasks: [TodoTask]) {
        let visibleTasks = tasks.filter { !$0.completed && !$0.isDeleted }
        let mostImportant = visibleTasks
            .sorted { lhs, rhs in
                if lhs.importance.rawValue == rhs.importance.rawValue {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.importance.rawValue > rhs.importance.rawValue
            }
            .first
            .map(WidgetTaskSnapshot.init(task:))

        let mostUrgent = visibleTasks
            .sorted { lhs, rhs in
                if lhs.urgency.rawValue == rhs.urgency.rawValue {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.urgency.rawValue > rhs.urgency.rawValue
            }
            .first
            .map(WidgetTaskSnapshot.init(task:))

        let snapshot = TodoWidgetSnapshot(
            mostImportant: mostImportant,
            mostUrgent: mostUrgent,
            updatedAt: Date()
        )

        guard let data = try? JSONEncoder().encode(snapshot) else {
            return
        }

        UserDefaults(suiteName: appGroupIdentifier)?.set(data, forKey: widgetSnapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension WidgetTaskSnapshot {
    init(task: TodoTask) {
        self.init(
            id: task.id,
            title: task.title,
            importance: task.importance.rawValue,
            urgency: task.urgency.rawValue,
            dueAt: task.dueAt
        )
    }
}
