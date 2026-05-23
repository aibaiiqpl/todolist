import AuthenticationServices
import Combine
import Foundation

@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published private(set) var authSession: AuthSession = .signedOut
    @Published private(set) var tasks: [TodoTask] = []
    @Published private(set) var syncSnapshot: SyncSnapshot = .initial
    @Published var draftTitle = ""
    @Published var errorMessage: String?
    @Published private(set) var isAdding = false
    @Published private(set) var isSyncing = false

    private let service: any TodoServicing
    private var didRestore = false

    init(service: any TodoServicing) {
        self.service = service
    }

    func restore() async {
        guard !didRestore else {
            return
        }
        didRestore = true
        authSession = await service.restoreSession()
        guard authSession.isAuthenticated else {
            return
        }
        await reloadTasks()
        await syncNow()
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success:
            do {
                authSession = try await service.authenticateWithApplePlaceholder()
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
        authSession = .signedOut
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

    func syncNow() async {
        guard authSession.isAuthenticated else {
            syncSnapshot = .initial
            return
        }

        isSyncing = true
        syncSnapshot.state = .syncing
        defer { isSyncing = false }

        do {
            syncSnapshot = try await service.sync()
            errorMessage = nil
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
}
