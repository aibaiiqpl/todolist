import Foundation

public struct TodoTask: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var userID: String
    public var title: String
    public var completed: Bool
    public var importance: TaskPriority
    public var urgency: TaskPriority
    public var dueAt: Date?
    public var sourceText: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?
    public var version: Int

    public init(
        id: String,
        userID: String,
        title: String,
        completed: Bool = false,
        importance: TaskPriority = .medium,
        urgency: TaskPriority = .medium,
        dueAt: Date? = nil,
        sourceText: String? = nil,
        createdAt: Date,
        updatedAt: Date,
        deletedAt: Date? = nil,
        version: Int = 1
    ) {
        self.id = id
        self.userID = userID
        self.title = title
        self.completed = completed
        self.importance = importance
        self.urgency = urgency
        self.dueAt = dueAt
        self.sourceText = sourceText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.version = version
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case title
        case completed
        case importance
        case urgency
        case dueAt = "due_at"
        case sourceText = "source_text"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case version
    }
}
