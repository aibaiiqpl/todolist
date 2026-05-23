import Foundation
import TodoShared
import WidgetKit

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

enum WidgetDataStore {
    static func publish(tasks: [TodoTask]) {
        let selection = WidgetTaskSelector.select(from: tasks)

        let snapshot = TodoWidgetSnapshot(
            mostImportant: selection.mostImportant.map(WidgetTaskSnapshot.init(task:)),
            mostUrgent: selection.mostUrgent.map(WidgetTaskSnapshot.init(task:)),
            updatedAt: Date()
        )

        guard let data = try? JSONEncoder().encode(snapshot) else {
            return
        }

        guard let appGroupIdentifier = Bundle.main.todoAppGroupIdentifier else {
            return
        }
        UserDefaults(suiteName: appGroupIdentifier)?.set(data, forKey: widgetSnapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension Bundle {
    var todoAppGroupIdentifier: String? {
        guard
            let value = object(forInfoDictionaryKey: "TodoAppGroupIdentifier") as? String,
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !value.contains("$(")
        else {
            return nil
        }
        return value
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
