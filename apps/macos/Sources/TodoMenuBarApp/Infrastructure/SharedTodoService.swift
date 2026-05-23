import Foundation
import TodoShared

@MainActor
final class SharedTodoService: TodoServicing {
    private let apiClient: any TodoAPIClient
    private let sessionStore: AuthSessionStoring

    private var session: AuthSession?
    private var repository: LocalTodoRepository?
    private var syncEngine: TodoSyncEngine?
    private var repositoryUserID: String?
    private var lastSyncedAt: Date?
    private var serverVersion: Int64 {
        get {
            guard let number = UserDefaults.standard.object(forKey: serverVersionKey) as? NSNumber else {
                return 0
            }
            return number.int64Value
        }
        set {
            UserDefaults.standard.set(newValue, forKey: serverVersionKey)
        }
    }

    private var serverVersionKey: String {
        guard let userID = session?.userID else {
            return "serverVersion"
        }
        return "serverVersion.\(userID)"
    }

    init(
        apiClient: any TodoAPIClient = URLSessionTodoAPIClient(baseURL: TodoAppConfiguration.apiBaseURL),
        sessionStore: AuthSessionStoring = UserDefaultsAuthSessionStore()
    ) {
        self.apiClient = apiClient
        self.sessionStore = sessionStore
    }

    func restoreSession() async throws -> AuthSession? {
        guard let restoredSession = try sessionStore.load(), restoredSession.isAuthenticated else {
            sessionStore.clear()
            session = nil
            return nil
        }
        session = restoredSession
        return restoredSession
    }

    func authenticateWithApple(identityToken: String) async throws -> AuthSession {
        let authenticatedSession = try await apiClient.authenticateWithApple(identityToken: identityToken)
        try sessionStore.save(authenticatedSession)
        session = authenticatedSession
        repository = nil
        syncEngine = nil
        repositoryUserID = nil
        return authenticatedSession
    }

    func signOut() async {
        sessionStore.clear()
        session = nil
        repository = nil
        syncEngine = nil
        repositoryUserID = nil
        lastSyncedAt = nil
    }

    func fetchTasks() async throws -> [TodoTask] {
        let repository = try await requireRepository()
        let tasks = await repository.allTasks()
        return tasks
            .filter { !$0.isDeleted }
            .sorted { lhs, rhs in
                if lhs.completed != rhs.completed {
                    return !lhs.completed
                }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    func addTask(title: String) async throws -> TodoTask {
        let session = try requireSession()
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw TodoServiceError.emptyTitle
        }

        let repository = try await repository(for: session)
        let draft = AITaskDraft(
            title: trimmedTitle,
            importance: .medium,
            urgency: .medium,
            sourceText: trimmedTitle
        )
        return try await repository.createTask(from: draft, userID: session.userID)
    }

    func setTaskCompleted(id: TodoTask.ID, completed: Bool) async throws -> TodoTask {
        guard completed else {
            throw TodoServiceError.unsupportedIncompleteToggle
        }

        let repository = try await requireRepository()
        do {
            return try await repository.completeTask(id: id)
        } catch let error as LocalTodoRepositoryError {
            switch error {
            case .taskNotFound:
                throw TodoServiceError.taskNotFound
            }
        }
    }

    func sync() async throws -> SyncSnapshot {
        let session = try requireSession()
        let repository = try await repository(for: session)
        let syncEngine = try await syncEngine(for: session)

        _ = try await syncEngine.pushPendingChanges(session: session)
        let changes = try await syncEngine.pullChanges(sinceVersion: serverVersion, session: session)
        serverVersion = changes.serverVersion

        let pendingOperations = await repository.pendingOperations()
        lastSyncedAt = Date()
        return SyncSnapshot(
            state: .idle,
            pendingChanges: pendingOperations.count,
            lastSyncedAt: lastSyncedAt
        )
    }

    private func requireSession() throws -> AuthSession {
        guard let session, session.isAuthenticated else {
            throw TodoServiceError.authenticationRequired
        }
        return session
    }

    private func requireRepository() async throws -> LocalTodoRepository {
        let session = try requireSession()
        return try await repository(for: session)
    }

    private func repository(for session: AuthSession) async throws -> LocalTodoRepository {
        if let repository, repositoryUserID == session.userID {
            return repository
        }

        let storage = FileTodoLocalStorage(fileURL: try TodoAppConfiguration.localStoreURL(userID: session.userID))
        let repository = try await LocalTodoRepository(storage: storage)
        self.repository = repository
        self.syncEngine = TodoSyncEngine(repository: repository, apiClient: apiClient)
        self.repositoryUserID = session.userID
        return repository
    }

    private func syncEngine(for session: AuthSession) async throws -> TodoSyncEngine {
        if let syncEngine, repositoryUserID == session.userID {
            return syncEngine
        }

        _ = try await repository(for: session)
        guard let syncEngine else {
            throw TodoServiceError.authenticationRequired
        }
        return syncEngine
    }
}
