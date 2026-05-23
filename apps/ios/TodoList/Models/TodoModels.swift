import Foundation
import TodoShared

typealias TodoTask = TodoShared.TodoTask
typealias TaskPriority = TodoShared.TaskPriority

struct TodoDraft: Identifiable, Equatable {
    let id: UUID
    var taskDraft: AITaskDraft

    init(id: UUID = UUID(), taskDraft: AITaskDraft) {
        self.id = id
        self.taskDraft = taskDraft
    }

    var title: String {
        get { taskDraft.title }
        set { taskDraft.title = newValue }
    }

    var importance: TaskPriority {
        get { taskDraft.importance }
        set { taskDraft.importance = newValue }
    }

    var urgency: TaskPriority {
        get { taskDraft.urgency }
        set { taskDraft.urgency = newValue }
    }

    var dueAt: Date? {
        get { taskDraft.dueAt }
        set { taskDraft.dueAt = newValue }
    }
}

extension TodoShared.TaskPriority {
    var title: String {
        switch self {
        case .none: return "无"
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }
}

extension TodoShared.TodoTask {
    var isDeleted: Bool {
        deletedAt != nil
    }
}

enum SyncState: Equatable {
    case idle
    case syncing
    case offlinePending(Int)
    case failed(String)

    var title: String {
        switch self {
        case .idle:
            return "已同步"
        case .syncing:
            return "同步中"
        case .offlinePending(let count):
            return "待同步 \(count)"
        case .failed:
            return "同步失败"
        }
    }
}
