import Foundation

public enum SyncOperationKind: String, Codable, Equatable, Sendable {
    case create
    case update
    case delete
}

public struct SyncOperation: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var kind: SyncOperationKind
    public var task: TodoTask
    public var createdAt: Date

    public init(id: String, kind: SyncOperationKind, task: TodoTask, createdAt: Date) {
        self.id = id
        self.kind = kind
        self.task = task
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case task
        case createdAt = "created_at"
    }
}
