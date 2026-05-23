import Foundation
import TodoShared

@MainActor
protocol TodoServicing {
    func restoreSession() async throws -> AuthSession?
    func authenticateWithApple(identityToken: String) async throws -> AuthSession
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
    case invalidAppleIdentityToken
    case unsupportedIncompleteToggle

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            "Task title cannot be empty."
        case .taskNotFound:
            "Task was not found."
        case .authenticationRequired:
            "Sign in before syncing tasks."
        case .invalidAppleIdentityToken:
            "Apple sign-in did not return an identity token."
        case .unsupportedIncompleteToggle:
            "Marking tasks incomplete is not supported by the shared task repository yet."
        }
    }
}
