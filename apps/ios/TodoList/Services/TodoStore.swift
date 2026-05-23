import AuthenticationServices
import Foundation

@MainActor
final class TodoStore: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var syncState: SyncState = .idle
    @Published private(set) var tasks: [TodoTask] = []
    @Published private(set) var drafts: [TodoDraft] = []
    @Published var errorMessage: String?

    private let backend: TodoBackendServicing
    private var userID: String?
    private var accessToken: String?
    private var expiresAt: Date?
    private var serverVersion = 0
    private var pendingOperations: [TaskSyncOperation] = []

    init(backend: TodoBackendServicing = PlaceholderTodoBackendService()) {
        self.backend = backend
        WidgetDataStore.publish(tasks: tasks)
    }

    func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>) async {
        do {
            let token = try identityToken(from: result)
            let response = try await backend.authenticateWithApple(
                AppleAuthRequest(identityToken: token)
            )
            userID = response.userID
            accessToken = response.accessToken
            expiresAt = response.expiresAt
            isAuthenticated = true
            errorMessage = nil
            await sync()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func organize(sourceText: String) async {
        do {
            let response = try await backend.organize(
                OrganizeRequest(input: sourceText),
                accessToken: requiredAccessToken()
            )
            drafts = response.drafts
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmDraft(_ draft: TodoDraft) {
        let now = Date()
        let task = TodoTask(
            id: UUID(),
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            completed: false,
            importance: draft.importance,
            urgency: draft.urgency,
            dueAt: draft.dueAt,
            sourceText: draft.sourceText,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil,
            version: 0
        )
        tasks.insert(task, at: 0)
        drafts.removeAll { $0.id == draft.id }
        enqueue(kind: .create, task: task)
        WidgetDataStore.publish(tasks: tasks)
    }

    func cancelDraft(_ draft: TodoDraft) {
        drafts.removeAll { $0.id == draft.id }
    }

    func toggleCompletion(for task: TodoTask) {
        update(task) { item in
            item.completed.toggle()
            item.updatedAt = Date()
        }
    }

    func delete(_ task: TodoTask) {
        update(task) { item in
            item.deletedAt = Date()
            item.updatedAt = Date()
        }
    }

    func sync() async {
        guard isAuthenticated else {
            return
        }

        syncState = .syncing
        do {
            if pendingOperations.isEmpty {
                let response = try await backend.changes(
                    sinceVersion: serverVersion,
                    accessToken: requiredAccessToken()
                )
                merge(response.tasks)
                serverVersion = response.serverVersion
            } else {
                let response = try await backend.sync(
                    TaskSyncRequest(operations: pendingOperations),
                    accessToken: requiredAccessToken()
                )
                let acknowledgedIDs = Set(response.acknowledgedOperationIDs)
                pendingOperations.removeAll { acknowledgedIDs.contains($0.id) }
                merge(response.tasks)
                serverVersion = response.serverVersion
            }

            syncState = pendingOperations.isEmpty ? .idle : .offlinePending(pendingOperations.count)
            errorMessage = nil
            WidgetDataStore.publish(tasks: tasks)
        } catch {
            syncState = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    private func update(_ task: TodoTask, mutate: (inout TodoTask) -> Void) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else {
            return
        }
        mutate(&tasks[index])
        tasks.sort(by: sortTasks)
        enqueue(kind: tasks[index].isDeleted ? .delete : .update, task: tasks[index])
        WidgetDataStore.publish(tasks: tasks)
    }

    private func enqueue(kind: TaskSyncOperationKind, task: TodoTask) {
        pendingOperations.append(
            TaskSyncOperation(
                id: UUID(),
                kind: kind,
                task: task,
                createdAt: Date()
            )
        )
        syncState = .offlinePending(pendingOperations.count)
    }

    private func requiredAccessToken() throws -> String {
        if let accessToken {
            return accessToken
        }
        throw TodoBackendError.missingAccessToken
    }

    private func identityToken(from result: Result<ASAuthorization, Error>) throws -> String {
        let authorization = try result.get()
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let token = credential.identityToken
        else {
            throw TodoBackendError.missingIdentityToken
        }
        guard let tokenString = String(data: token, encoding: .utf8) else {
            throw TodoBackendError.invalidIdentityToken
        }
        return tokenString
    }

    private func merge(_ changedTasks: [TodoTask]) {
        for changedTask in changedTasks {
            if let index = tasks.firstIndex(where: { $0.id == changedTask.id }) {
                tasks[index] = changedTask
            } else {
                tasks.append(changedTask)
            }
        }
        tasks.sort(by: sortTasks)
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
