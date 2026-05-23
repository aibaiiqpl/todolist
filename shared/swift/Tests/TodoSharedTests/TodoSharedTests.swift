import XCTest
@testable import TodoShared

final class TodoSharedTests: XCTestCase {
    func testLocalQueueGenerationForCreateUpdateAndDelete() async throws {
        let repository = try await LocalTodoRepository(storage: InMemoryTodoLocalStorage())
        let created = try await repository.createTask(
            from: AITaskDraft(title: "Pay rent", importance: .high, urgency: .medium),
            userID: "user-1",
            now: date(0),
            id: "task-1"
        )

        _ = try await repository.completeTask(id: created.id, now: date(10))
        _ = try await repository.softDeleteTask(id: created.id, now: date(20))

        let operations = await repository.pendingOperations()
        XCTAssertEqual(operations.map(\.kind), [.create, .update, .delete])
        XCTAssertEqual(operations.map(\.task.id), ["task-1", "task-1", "task-1"])
    }

    func testSyncSuccessClearsAcknowledgedOperations() async throws {
        let repository = try await LocalTodoRepository(storage: InMemoryTodoLocalStorage())
        _ = try await repository.createTask(
            from: AITaskDraft(title: "Buy milk"),
            userID: "user-1",
            now: date(0),
            id: "task-1"
        )
        let api = FakeTodoAPIClient()
        let engine = TodoSyncEngine(repository: repository, apiClient: api)

        let summary = try await engine.pushPendingChanges(session: session())

        XCTAssertEqual(summary.uploadedOperationCount, 1)
        XCTAssertEqual(summary.clearedOperationCount, 1)
        let remainingOperations = await repository.pendingOperations()
        XCTAssertTrue(remainingOperations.isEmpty)
    }

    func testSyncFailureKeepsPendingOperationsForRetry() async throws {
        let repository = try await LocalTodoRepository(storage: InMemoryTodoLocalStorage())
        _ = try await repository.createTask(
            from: AITaskDraft(title: "Book flights"),
            userID: "user-1",
            now: date(0),
            id: "task-1"
        )
        let api = FakeTodoAPIClient(syncError: TestError.expected)
        let engine = TodoSyncEngine(repository: repository, apiClient: api)

        do {
            _ = try await engine.pushPendingChanges(session: session())
            XCTFail("Sync should fail")
        } catch TestError.expected {
            let operations = await repository.pendingOperations()
            XCTAssertEqual(operations.count, 1)
            XCTAssertEqual(operations.first?.kind, .create)
        }
    }

    func testLastWriteWinsUsesUpdatedAtThenVersion() {
        let older = task(id: "task-1", title: "Older", updatedAt: date(10), version: 10)
        let newer = task(id: "task-1", title: "Newer", updatedAt: date(20), version: 1)

        XCTAssertEqual(LastWriteWinsMerger.winner(local: older, remote: newer).title, "Newer")

        let lowerVersion = task(id: "task-1", title: "Lower", updatedAt: date(20), version: 1)
        let higherVersion = task(id: "task-1", title: "Higher", updatedAt: date(20), version: 2)

        XCTAssertEqual(LastWriteWinsMerger.winner(local: lowerVersion, remote: higherVersion).title, "Higher")
    }

    func testWidgetSelectsMostImportantAndMostUrgentTasks() {
        let low = task(id: "low", title: "Low", importance: .low, urgency: .low, dueAt: date(100))
        let important = task(id: "important", title: "Important", importance: .high, urgency: .medium, dueAt: date(200))
        let urgent = task(id: "urgent", title: "Urgent", importance: .medium, urgency: .high, dueAt: date(50))
        var completed = task(id: "completed", title: "Completed", importance: .high, urgency: .high, dueAt: date(1))
        completed.completed = true

        let selection = WidgetTaskSelector.select(from: [low, important, urgent, completed])

        XCTAssertEqual(selection.mostImportant?.id, "important")
        XCTAssertEqual(selection.mostUrgent?.id, "urgent")
    }

    func testSyncContractsUseServerVersionSnakeCase() throws {
        let decoder = JSONDecoder.todoSharedDecoder()
        let changes = try decoder.decode(TaskChanges.self, from: Data("""
        {"tasks":[],"server_version":42}
        """.utf8))
        XCTAssertEqual(changes.serverVersion, 42)

        let result = try decoder.decode(SyncResult.self, from: Data("""
        {"acknowledged_operation_ids":["op-1"],"tasks":[],"server_version":43}
        """.utf8))
        XCTAssertEqual(result.acknowledgedOperationIDs, ["op-1"])
        XCTAssertEqual(result.serverVersion, 43)
    }
}

private final class FakeTodoAPIClient: TodoAPIClient, @unchecked Sendable {
    private let syncError: Error?

    init(syncError: Error? = nil) {
        self.syncError = syncError
    }

    func authenticateWithApple(identityToken: String) async throws -> AuthSession {
        session()
    }

    func organizeTasks(input: String, session: AuthSession) async throws -> [AITaskDraft] {
        []
    }

    func fetchTaskChanges(sinceVersion: Int64, session: AuthSession) async throws -> TaskChanges {
        TaskChanges(tasks: [], serverVersion: sinceVersion)
    }

    func syncTasks(operations: [SyncOperation], session: AuthSession) async throws -> SyncResult {
        if let syncError {
            throw syncError
        }
        return SyncResult(acknowledgedOperationIDs: operations.map(\.id), serverVersion: 1)
    }
}

private enum TestError: Error {
    case expected
}

private func task(
    id: String,
    title: String,
    importance: TaskPriority = .none,
    urgency: TaskPriority = .none,
    dueAt: Date? = nil,
    updatedAt: Date = date(0),
    version: Int = 1
) -> TodoTask {
    TodoTask(
        id: id,
        userID: "user-1",
        title: title,
        completed: false,
        importance: importance,
        urgency: urgency,
        dueAt: dueAt,
        sourceText: nil,
        createdAt: date(0),
        updatedAt: updatedAt,
        version: version
    )
}

private func session() -> AuthSession {
    AuthSession(userID: "user-1", accessToken: "token", expiresAt: date(1000))
}

private func date(_ seconds: TimeInterval) -> Date {
    Date(timeIntervalSince1970: seconds)
}
