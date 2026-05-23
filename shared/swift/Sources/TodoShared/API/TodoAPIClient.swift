import Foundation

public struct TaskChanges: Codable, Equatable, Sendable {
    public var tasks: [TodoTask]
    public var cursor: String?

    public init(tasks: [TodoTask], cursor: String? = nil) {
        self.tasks = tasks
        self.cursor = cursor
    }
}

public struct SyncResult: Codable, Equatable, Sendable {
    public var acknowledgedOperationIDs: [String]
    public var tasks: [TodoTask]

    public init(acknowledgedOperationIDs: [String], tasks: [TodoTask] = []) {
        self.acknowledgedOperationIDs = acknowledgedOperationIDs
        self.tasks = tasks
    }

    enum CodingKeys: String, CodingKey {
        case acknowledgedOperationIDs = "acknowledged_operation_ids"
        case tasks
    }
}

public protocol TodoAPIClient: Sendable {
    func authenticateWithApple(identityToken: String) async throws -> AuthSession
    func organizeTasks(input: String, session: AuthSession) async throws -> [AITaskDraft]
    func fetchTaskChanges(since: Date?, session: AuthSession) async throws -> TaskChanges
    func syncTasks(operations: [SyncOperation], session: AuthSession) async throws -> SyncResult
}
