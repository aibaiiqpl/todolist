import Foundation

public struct SyncSummary: Equatable, Sendable {
    public var uploadedOperationCount: Int
    public var clearedOperationCount: Int
    public var appliedRemoteTaskCount: Int

    public init(uploadedOperationCount: Int, clearedOperationCount: Int, appliedRemoteTaskCount: Int) {
        self.uploadedOperationCount = uploadedOperationCount
        self.clearedOperationCount = clearedOperationCount
        self.appliedRemoteTaskCount = appliedRemoteTaskCount
    }
}

public struct TodoSyncEngine: Sendable {
    private let repository: LocalTodoRepository
    private let apiClient: any TodoAPIClient

    public init(repository: LocalTodoRepository, apiClient: any TodoAPIClient) {
        self.repository = repository
        self.apiClient = apiClient
    }

    public func pushPendingChanges(session: AuthSession) async throws -> SyncSummary {
        let operations = await repository.pendingOperations()
        guard !operations.isEmpty else {
            return SyncSummary(uploadedOperationCount: 0, clearedOperationCount: 0, appliedRemoteTaskCount: 0)
        }

        let result = try await apiClient.syncTasks(operations: operations, session: session)
        try await repository.applyRemoteTasks(result.tasks)
        try await repository.clearOperations(ids: result.acknowledgedOperationIDs)

        return SyncSummary(
            uploadedOperationCount: operations.count,
            clearedOperationCount: result.acknowledgedOperationIDs.count,
            appliedRemoteTaskCount: result.tasks.count
        )
    }

    public func pullChanges(sinceVersion: Int64, session: AuthSession) async throws -> TaskChanges {
        let changes = try await apiClient.fetchTaskChanges(sinceVersion: sinceVersion, session: session)
        try await repository.applyRemoteTasks(changes.tasks)
        return changes
    }
}
