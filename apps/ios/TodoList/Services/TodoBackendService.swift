import Foundation

protocol TodoBackendServicing {
    func authenticateWithApple(_ request: AppleAuthRequest) async throws -> AppleAuthResponse
    func organize(_ request: OrganizeRequest, accessToken: String) async throws -> OrganizeResponse
    func changes(sinceVersion: Int, accessToken: String) async throws -> TaskChangesResponse
    func sync(_ request: TaskSyncRequest, accessToken: String) async throws -> TaskSyncResponse
}

enum TodoBackendError: LocalizedError {
    case emptyInput
    case missingIdentityToken
    case invalidIdentityToken
    case missingAccessToken

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
        }
    }
}

struct PlaceholderTodoBackendService: TodoBackendServicing {
    func authenticateWithApple(_ request: AppleAuthRequest) async throws -> AppleAuthResponse {
        guard !request.identityToken.isEmpty else {
            throw TodoBackendError.missingIdentityToken
        }
        return AppleAuthResponse(
            userID: "placeholder-ios-user",
            accessToken: "placeholder-ios-access-token",
            expiresAt: Date().addingTimeInterval(60 * 60)
        )
    }

    func organize(_ request: OrganizeRequest, accessToken: String) async throws -> OrganizeResponse {
        let trimmedText = request.input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw TodoBackendError.emptyInput
        }

        let drafts = splitDraftInputs(trimmedText).map { title in
            TodoDraft(
                title: title,
                importance: inferredImportance(from: title),
                urgency: inferredUrgency(from: title),
                dueAt: inferredDueDate(from: title),
                sourceText: trimmedText
            )
        }

        return OrganizeResponse(drafts: drafts)
    }

    func changes(sinceVersion: Int, accessToken: String) async throws -> TaskChangesResponse {
        TaskChangesResponse(tasks: [], serverVersion: sinceVersion)
    }

    func sync(_ request: TaskSyncRequest, accessToken: String) async throws -> TaskSyncResponse {
        let tasks = request.operations.map { operation in
            var syncedTask = operation.task
            syncedTask.version += 1
            return syncedTask
        }

        return TaskSyncResponse(
            acknowledgedOperationIDs: request.operations.map(\.id),
            tasks: tasks,
            serverVersion: tasks.map(\.version).max() ?? 0
        )
    }

    private func splitDraftInputs(_ text: String) -> [String] {
        let candidates = text
            .components(separatedBy: CharacterSet(charactersIn: "\n;；"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return candidates.isEmpty ? [text] : candidates
    }

    private func inferredImportance(from text: String) -> TaskImportance {
        if text.contains("重要") || text.localizedCaseInsensitiveContains("critical") {
            return .high
        }
        return .medium
    }

    private func inferredUrgency(from text: String) -> TaskUrgency {
        if text.contains("今天") || text.contains("马上") || text.localizedCaseInsensitiveContains("urgent") {
            return .high
        }
        return .medium
    }

    private func inferredDueDate(from text: String) -> Date? {
        let calendar = Calendar.current
        if text.contains("今天") {
            return calendar.startOfDay(for: Date())
        }
        if text.contains("明天") {
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))
        }
        return nil
    }
}
