import Foundation

@MainActor
final class PlaceholderTodoService: TodoServicing {
    private var session = AuthSession.signedOut
    private var tasks: [TodoTask] = [
        TodoTask(
            id: UUID(),
            title: "Review today's AI-organized tasks",
            completed: false,
            importance: .high,
            urgency: .normal,
            dueAt: nil,
            sourceText: "Review tasks today",
            createdAt: .now,
            updatedAt: .now,
            deletedAt: nil,
            version: 1
        ),
        TodoTask(
            id: UUID(),
            title: "Confirm shared sync contract",
            completed: false,
            importance: .normal,
            urgency: .high,
            dueAt: nil,
            sourceText: nil,
            createdAt: .now,
            updatedAt: .now,
            deletedAt: nil,
            version: 1
        )
    ]
    private var pendingChanges = 0
    private var lastSyncedAt: Date?

    func restoreSession() async -> AuthSession {
        session
    }

    func authenticateWithApplePlaceholder() async throws -> AuthSession {
        session = AuthSession(
            isAuthenticated: true,
            displayName: "Apple User",
            userID: "placeholder-apple-user"
        )
        return session
    }

    func signOut() async {
        session = .signedOut
    }

    func fetchTasks() async throws -> [TodoTask] {
        try requireAuthentication()
        return visibleTasks()
    }

    func addTask(title: String) async throws -> TodoTask {
        try requireAuthentication()
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw TodoServiceError.emptyTitle
        }

        let task = TodoTask(
            id: UUID(),
            title: trimmedTitle,
            completed: false,
            importance: .normal,
            urgency: .normal,
            dueAt: nil,
            sourceText: trimmedTitle,
            createdAt: .now,
            updatedAt: .now,
            deletedAt: nil,
            version: 1
        )
        tasks.insert(task, at: 0)
        pendingChanges += 1
        return task
    }

    func setTaskCompleted(id: TodoTask.ID, completed: Bool) async throws -> TodoTask {
        try requireAuthentication()
        guard let index = tasks.firstIndex(where: { $0.id == id && !$0.isDeleted }) else {
            throw TodoServiceError.taskNotFound
        }

        tasks[index].completed = completed
        tasks[index].updatedAt = .now
        tasks[index].version += 1
        pendingChanges += 1
        return tasks[index]
    }

    func sync() async throws -> SyncSnapshot {
        try requireAuthentication()
        lastSyncedAt = .now
        pendingChanges = 0
        return SyncSnapshot(
            state: .idle,
            pendingChanges: pendingChanges,
            lastSyncedAt: lastSyncedAt
        )
    }

    private func visibleTasks() -> [TodoTask] {
        tasks
            .filter { !$0.isDeleted }
            .sorted { lhs, rhs in
                if lhs.completed != rhs.completed {
                    return !lhs.completed
                }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    private func requireAuthentication() throws {
        guard session.isAuthenticated else {
            throw TodoServiceError.authenticationRequired
        }
    }
}
