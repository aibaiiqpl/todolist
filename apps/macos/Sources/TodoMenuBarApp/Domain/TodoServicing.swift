import Foundation

@MainActor
protocol TodoServicing {
    func restoreSession() async -> AuthSession
    func authenticateWithApplePlaceholder() async throws -> AuthSession
    func signOut() async
    func fetchTasks() async throws -> [TodoTask]
    func addTask(title: String) async throws -> TodoTask
    func setTaskCompleted(id: TodoTask.ID, completed: Bool) async throws -> TodoTask
    func sync() async throws -> SyncSnapshot
}

enum TodoServiceError: LocalizedError {
    case emptyTitle
    case taskNotFound
    case authenticationRequired

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            "Task title cannot be empty."
        case .taskNotFound:
            "Task was not found."
        case .authenticationRequired:
            "Sign in before syncing tasks."
        }
    }
}
