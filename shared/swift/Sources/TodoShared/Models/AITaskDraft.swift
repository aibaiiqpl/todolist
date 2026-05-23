import Foundation

public struct AITaskDraft: Codable, Equatable, Sendable {
    public var title: String
    public var importance: TaskPriority
    public var urgency: TaskPriority
    public var dueAt: Date?
    public var sourceText: String?

    public init(
        title: String,
        importance: TaskPriority = .none,
        urgency: TaskPriority = .none,
        dueAt: Date? = nil,
        sourceText: String? = nil
    ) {
        self.title = title
        self.importance = importance
        self.urgency = urgency
        self.dueAt = dueAt
        self.sourceText = sourceText
    }

    enum CodingKeys: String, CodingKey {
        case title
        case importance
        case urgency
        case dueAt = "due_at"
        case sourceText = "source_text"
    }
}
