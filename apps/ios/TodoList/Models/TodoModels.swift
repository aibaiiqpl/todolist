import Foundation

enum TaskImportance: Int, CaseIterable, Codable, Identifiable {
    case low = 1
    case medium = 2
    case high = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }
}

enum TaskUrgency: Int, CaseIterable, Codable, Identifiable {
    case low = 1
    case medium = 2
    case high = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }
}

struct TodoTask: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var completed: Bool
    var importance: TaskImportance
    var urgency: TaskUrgency
    var dueAt: Date?
    var sourceText: String
    let createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var version: Int

    var isDeleted: Bool {
        deletedAt != nil
    }

    enum CodingKeys: String, CodingKey {
        case id
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

struct TodoDraft: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var importance: TaskImportance
    var urgency: TaskUrgency
    var dueAt: Date?
    var sourceText: String

    init(
        id: UUID = UUID(),
        title: String,
        importance: TaskImportance,
        urgency: TaskUrgency,
        dueAt: Date?,
        sourceText: String
    ) {
        self.id = id
        self.title = title
        self.importance = importance
        self.urgency = urgency
        self.dueAt = dueAt
        self.sourceText = sourceText
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        importance = try container.decode(TaskImportance.self, forKey: .importance)
        urgency = try container.decode(TaskUrgency.self, forKey: .urgency)
        dueAt = try container.decodeIfPresent(Date.self, forKey: .dueAt)
        sourceText = try container.decodeIfPresent(String.self, forKey: .sourceText) ?? title
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case importance
        case urgency
        case dueAt = "due_at"
        case sourceText = "source_text"
    }
}

struct AppleAuthRequest: Codable, Equatable {
    var identityToken: String

    enum CodingKeys: String, CodingKey {
        case identityToken = "identity_token"
    }
}

struct AppleAuthResponse: Codable, Equatable {
    var userID: String
    var accessToken: String
    var expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case accessToken = "access_token"
        case expiresAt = "expires_at"
    }
}

struct OrganizeRequest: Codable, Equatable {
    var input: String
}

struct OrganizeResponse: Codable, Equatable {
    var drafts: [TodoDraft]
}

struct TaskChangesResponse: Codable, Equatable {
    var tasks: [TodoTask]
    var serverVersion: Int

    enum CodingKeys: String, CodingKey {
        case tasks
        case serverVersion = "server_version"
    }
}

enum TaskSyncOperationKind: String, Codable, Equatable {
    case create
    case update
    case delete
}

struct TaskSyncOperation: Identifiable, Codable, Equatable {
    var id: UUID
    var kind: TaskSyncOperationKind
    var task: TodoTask
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case task
        case createdAt = "created_at"
    }
}

struct TaskSyncRequest: Codable, Equatable {
    var operations: [TaskSyncOperation]
}

struct TaskSyncResponse: Codable, Equatable {
    var acknowledgedOperationIDs: [UUID]
    var tasks: [TodoTask]
    var serverVersion: Int

    enum CodingKeys: String, CodingKey {
        case acknowledgedOperationIDs = "acknowledged_operation_ids"
        case tasks
        case serverVersion = "server_version"
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
