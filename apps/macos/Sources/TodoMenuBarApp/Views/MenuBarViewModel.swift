import AuthenticationServices
import Combine
import Foundation
import Network
import TodoShared

@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published private(set) var authSession: AuthSession?
    @Published private(set) var tasks: [TodoTask] = []
    @Published private(set) var syncSnapshot: SyncSnapshot = .initial
    @Published var draftTitle = ""
    @Published var errorMessage: String?
    @Published private(set) var isAdding = false
    @Published private(set) var isSyncing = false

    private let service: any TodoServicing
    private var didRestore = false
    private let pathMonitor = NWPathMonitor()
    private let pathMonitorQueue = DispatchQueue(label: "TodoMenuBar.NetworkPath")

    init(service: any TodoServicing) {
        self.service = service
        startNetworkRecoverySync()
    }

    func restore() async {
        guard !didRestore else {
            return
        }
        didRestore = true
        do {
            authSession = try await service.restoreSession()
            guard authSession?.isAuthenticated == true else {
                return
            }
            await reloadTasks()
            await syncNow()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            do {
                let identityToken = try identityToken(from: authorization)
                authSession = try await service.authenticateWithApple(identityToken: identityToken)
                errorMessage = nil
                await reloadTasks()
                await syncNow()
            } catch {
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        await service.signOut()
        authSession = nil
        tasks = []
        syncSnapshot = .initial
        draftTitle = ""
        errorMessage = nil
    }

    func addDraftTask() async {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            errorMessage = TodoServiceError.emptyTitle.localizedDescription
            return
        }

        isAdding = true
        defer { isAdding = false }

        do {
            _ = try await service.addTask(title: title)
            draftTitle = ""
            errorMessage = nil
            await reloadTasks()
            syncSnapshot.pendingChanges += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleCompletion(for task: TodoTask) async {
        do {
            _ = try await service.setTaskCompleted(id: task.id, completed: !task.completed)
            errorMessage = nil
            await reloadTasks()
            syncSnapshot.pendingChanges += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateTitle(for task: TodoTask, title: String) async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = TodoServiceError.emptyTitle.localizedDescription
            return
        }
        do {
            _ = try await service.updateTaskTitle(id: task.id, title: trimmedTitle)
            errorMessage = nil
            await reloadTasks()
            syncSnapshot.pendingChanges += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func syncNow() async {
        guard authSession?.isAuthenticated == true else {
            syncSnapshot = .initial
            return
        }

        isSyncing = true
        syncSnapshot.state = .syncing
        defer { isSyncing = false }

        do {
            syncSnapshot = try await service.sync()
            errorMessage = nil
            await reloadTasks()
        } catch {
            syncSnapshot.state = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    private func reloadTasks() async {
        do {
            tasks = try await service.fetchTasks()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startNetworkRecoverySync() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else {
                return
            }
            Task { @MainActor [weak self] in
                await self?.syncNow()
            }
        }
        pathMonitor.start(queue: pathMonitorQueue)
    }

    private func identityToken(from authorization: ASAuthorization) throws -> String {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let token = String(data: tokenData, encoding: .utf8),
            !token.isEmpty
        else {
            throw TodoServiceError.invalidAppleIdentityToken
        }

        return token
    }
}
