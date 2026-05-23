import Foundation

public struct WidgetTaskSelection: Equatable, Sendable {
    public var mostImportant: TodoTask?
    public var mostUrgent: TodoTask?

    public init(mostImportant: TodoTask?, mostUrgent: TodoTask?) {
        self.mostImportant = mostImportant
        self.mostUrgent = mostUrgent
    }
}

public enum WidgetTaskSelector {
    public static func select(from tasks: [TodoTask]) -> WidgetTaskSelection {
        let candidates = tasks.filter { !$0.completed && $0.deletedAt == nil }
        return WidgetTaskSelection(
            mostImportant: candidates.sorted(by: moreImportantFirst).first,
            mostUrgent: candidates.sorted(by: moreUrgentFirst).first
        )
    }

    private static func moreImportantFirst(lhs: TodoTask, rhs: TodoTask) -> Bool {
        if lhs.importance != rhs.importance {
            return lhs.importance > rhs.importance
        }
        if lhs.urgency != rhs.urgency {
            return lhs.urgency > rhs.urgency
        }
        return tieBreak(lhs: lhs, rhs: rhs)
    }

    private static func moreUrgentFirst(lhs: TodoTask, rhs: TodoTask) -> Bool {
        if lhs.urgency != rhs.urgency {
            return lhs.urgency > rhs.urgency
        }
        if lhs.dueAt != rhs.dueAt {
            return earlierDueDateFirst(lhs: lhs.dueAt, rhs: rhs.dueAt)
        }
        if lhs.importance != rhs.importance {
            return lhs.importance > rhs.importance
        }
        return tieBreak(lhs: lhs, rhs: rhs)
    }

    private static func earlierDueDateFirst(lhs: Date?, rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case (.some(let lhsDate), .some(let rhsDate)):
            return lhsDate < rhsDate
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            return false
        }
    }

    private static func tieBreak(lhs: TodoTask, rhs: TodoTask) -> Bool {
        if lhs.dueAt != rhs.dueAt {
            return earlierDueDateFirst(lhs: lhs.dueAt, rhs: rhs.dueAt)
        }
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }
        return lhs.id < rhs.id
    }
}
