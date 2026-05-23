import AuthenticationServices
import Foundation
import TodoShared

@MainActor
final class TodoStore: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var syncState: SyncState = .idle
    @Published private(set) var tasks: [TodoTask] = []
    @Published private(set) var drafts: [TodoDraft] = []
    @Published var errorMessage: String?

    private var apiClient: URLSessionTodoAPIClient?
    private var repository: LocalTodoRepository?
    private var syncEngine: TodoSyncEngine?
    private var session: AuthSession?
    private var serverVersion: Int64 = 0

    init() {
        WidgetDataStore.publish(tasks: tasks)
        Task {
            await configureSharedServices()
        }
    }

    func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>) async {
        do {
            let token = try identityToken(from: result)
            session = try await requiredAPIClient().authenticateWithApple(identityToken: token)
            isAuthenticated = true
            errorMessage = nil
            await sync()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func organize(sourceText: String) async {
        do {
            let trimmedText = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else {
                throw TodoStoreError.emptyInput
            }
            let taskDrafts = try await requiredAPIClient().organizeTasks(
                input: trimmedText,
                session: requiredSession()
            )
            drafts = taskDrafts.map { taskDraft in
                var normalizedDraft = taskDraft
                if normalizedDraft.sourceText == nil {
                    normalizedDraft.sourceText = trimmedText
                }
                return TodoDraft(taskDraft: normalizedDraft)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmDraft(_ draft: TodoDraft) async {
        do {
            var taskDraft = draft.taskDraft
            taskDraft.title = taskDraft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !taskDraft.title.isEmpty else {
                throw TodoStoreError.emptyInput
            }
            _ = try await requiredRepository().createTask(
                from: taskDraft,
                userID: requiredSession().userID
            )
            drafts.removeAll { $0.id == draft.id }
            await reloadLocalTasks()
            await sync()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelDraft(_ draft: TodoDraft) {
        drafts.removeAll { $0.id == draft.id }
    }

    func toggleCompletion(for task: TodoTask) async {
        guard !task.completed else {
            return
        }
        do {
            _ = try await requiredRepository().completeTask(id: task.id)
            await reloadLocalTasks()
            await refreshPendingSyncState()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ task: TodoTask) async {
        do {
            _ = try await requiredRepository().softDeleteTask(id: task.id)
            await reloadLocalTasks()
            await refreshPendingSyncState()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sync() async {
        guard isAuthenticated, session != nil else {
            return
        }

        syncState = .syncing
        do {
            let repository = try requiredRepository()
            let session = try requiredSession()
            let pendingOperations = await repository.pendingOperations()
            if !pendingOperations.isEmpty {
                _ = try await requiredSyncEngine().pushPendingChanges(session: session)
            }
            let changes = try await requiredSyncEngine().pullChanges(
                sinceVersion: serverVersion,
                session: session
            )
            serverVersion = changes.serverVersion
            await reloadLocalTasks()
            await refreshPendingSyncState()
            errorMessage = nil
        } catch {
            syncState = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    private func configureSharedServices() async {
        do {
            let baseURL = try Self.apiBaseURL()
            let repository = try await LocalTodoRepository(
                storage: FileTodoLocalStorage(fileURL: Self.localStoreURL())
            )
            let apiClient = URLSessionTodoAPIClient(baseURL: baseURL)
            self.repository = repository
            self.apiClient = apiClient
            self.syncEngine = TodoSyncEngine(repository: repository, apiClient: apiClient)
            await reloadLocalTasks()
            await refreshPendingSyncState()
            errorMessage = nil
        } catch {
            syncState = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    private func reloadLocalTasks() async {
        guard let repository else {
            return
        }
        tasks = await repository.allTasks().sorted(by: sortTasks)
        WidgetDataStore.publish(tasks: tasks)
    }

    private func refreshPendingSyncState() async {
        guard let repository else {
            return
        }
        let pendingCount = await repository.pendingOperations().count
        syncState = pendingCount == 0 ? .idle : .offlinePending(pendingCount)
    }

    private func requiredAPIClient() throws -> URLSessionTodoAPIClient {
        if let apiClient {
            return apiClient
        }
        throw TodoStoreError.notConfigured
    }

    private func requiredRepository() throws -> LocalTodoRepository {
        if let repository {
            return repository
        }
        throw TodoStoreError.notConfigured
    }

    private func requiredSyncEngine() throws -> TodoSyncEngine {
        if let syncEngine {
            return syncEngine
        }
        throw TodoStoreError.notConfigured
    }

    private func requiredSession() throws -> AuthSession {
        if let session {
            return session
        }
        throw TodoStoreError.missingAccessToken
    }

    private func identityToken(from result: Result<ASAuthorization, Error>) throws -> String {
        let authorization = try result.get()
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let token = credential.identityToken
        else {
            throw TodoStoreError.missingIdentityToken
        }
        guard let tokenString = String(data: token, encoding: .utf8) else {
            throw TodoStoreError.invalidIdentityToken
        }
        return tokenString
    }

    private static func apiBaseURL() throws -> URL {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "TodoAPIBaseURL") as? String else {
            throw TodoStoreError.missingAPIBaseURL
        }
        guard let url = URL(string: value), let scheme = url.scheme, let host = url.host, !scheme.isEmpty, !host.isEmpty else {
            throw TodoStoreError.invalidAPIBaseURL(value)
        }
        return url
    }

    private static func localStoreURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TodoList", isDirectory: true)
            .appendingPathComponent("local-store.json")
    }

    private func sortTasks(_ lhs: TodoTask, _ rhs: TodoTask) -> Bool {
        if lhs.completed != rhs.completed {
            return !lhs.completed
        }
        if lhs.importance.rawValue != rhs.importance.rawValue {
            return lhs.importance.rawValue > rhs.importance.rawValue
        }
        if lhs.urgency.rawValue != rhs.urgency.rawValue {
            return lhs.urgency.rawValue > rhs.urgency.rawValue
        }
        return lhs.updatedAt > rhs.updatedAt
    }
}

enum TodoStoreError: LocalizedError {
    case emptyInput
    case missingIdentityToken
    case invalidIdentityToken
    case missingAccessToken
    case missingAPIBaseURL
    case invalidAPIBaseURL(String)
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "请输入待整理内容"
        case .missingIdentityToken:
            return "Apple 登录未返回身份令牌"
        case .invalidIdentityToken:
            return "Apple 身份令牌格式无效"
        case .missingAccessToken:
            return "请先登录"
        case .missingAPIBaseURL:
            return "缺少 TodoAPIBaseURL 配置"
        case .invalidAPIBaseURL(let value):
            return "TodoAPIBaseURL 无效：\(value)"
        case .notConfigured:
            return "iOS shared 服务尚未完成初始化"
        }
    }
}
