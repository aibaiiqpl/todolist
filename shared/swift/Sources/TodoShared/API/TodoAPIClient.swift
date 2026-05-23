import Foundation

public struct TaskChanges: Codable, Equatable, Sendable {
    public var tasks: [TodoTask]
    public var serverVersion: Int64

    public init(tasks: [TodoTask], serverVersion: Int64) {
        self.tasks = tasks
        self.serverVersion = serverVersion
    }

    enum CodingKeys: String, CodingKey {
        case tasks
        case serverVersion = "server_version"
    }
}

public struct SyncResult: Codable, Equatable, Sendable {
    public var acknowledgedOperationIDs: [String]
    public var tasks: [TodoTask]
    public var serverVersion: Int64

    public init(acknowledgedOperationIDs: [String], tasks: [TodoTask] = [], serverVersion: Int64) {
        self.acknowledgedOperationIDs = acknowledgedOperationIDs
        self.tasks = tasks
        self.serverVersion = serverVersion
    }

    enum CodingKeys: String, CodingKey {
        case acknowledgedOperationIDs = "acknowledged_operation_ids"
        case tasks
        case serverVersion = "server_version"
    }
}

public protocol TodoAPIClient: Sendable {
    func authenticateWithApple(identityToken: String) async throws -> AuthSession
    func organizeTasks(input: String, session: AuthSession) async throws -> [AITaskDraft]
    func fetchTaskChanges(sinceVersion: Int64, session: AuthSession) async throws -> TaskChanges
    func syncTasks(operations: [SyncOperation], session: AuthSession) async throws -> SyncResult
}
