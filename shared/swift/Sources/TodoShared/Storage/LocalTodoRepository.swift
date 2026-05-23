import Foundation

public actor LocalTodoRepository {
    private let storage: any TodoLocalStorage
    private var state: LocalStoreState

    public init(storage: any TodoLocalStorage) async throws {
        self.storage = storage
        self.state = try await storage.load()
    }

    public func allTasks(includeDeleted: Bool = false) -> [TodoTask] {
        state.tasks.values
            .filter { includeDeleted || $0.deletedAt == nil }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.id < rhs.id
            }
    }

    public func task(id: String) -> TodoTask? {
        state.tasks[id]
    }

    public func pendingOperations() -> [SyncOperation] {
        state.queue
    }

    @discardableResult
    public func createTask(
        from draft: AITaskDraft,
        userID: String,
        now: Date = Date(),
        id: String = UUID().uuidString
    ) async throws -> TodoTask {
        let task = TodoTask(
            id: id,
            userID: userID,
            title: draft.title,
            importance: draft.importance,
            urgency: draft.urgency,
            dueAt: draft.dueAt,
            sourceText: draft.sourceText,
            createdAt: now,
            updatedAt: now
        )
        state.tasks[task.id] = task
        enqueue(kind: .create, task: task, now: now)
        try await persist()
        return task
    }

    @discardableResult
    public func updateTask(
        id: String,
        title: String? = nil,
        importance: TaskPriority? = nil,
        urgency: TaskPriority? = nil,
        dueAt: Date? = nil,
        sourceText: String? = nil,
        now: Date = Date()
    ) async throws -> TodoTask {
        var task = try existingTask(id: id)
        if let title {
            task.title = title
        }
        if let importance {
            task.importance = importance
        }
        if let urgency {
            task.urgency = urgency
        }
        if let dueAt {
            task.dueAt = dueAt
        }
        if let sourceText {
            task.sourceText = sourceText
        }
        task.updatedAt = now
        task.version += 1
        state.tasks[id] = task
        enqueue(kind: .update, task: task, now: now)
        try await persist()
        return task
    }

    @discardableResult
    public func completeTask(id: String, now: Date = Date()) async throws -> TodoTask {
        var task = try existingTask(id: id)
        task.completed = true
        task.updatedAt = now
        task.version += 1
        state.tasks[id] = task
        enqueue(kind: .update, task: task, now: now)
        try await persist()
        return task
    }

    @discardableResult
    public func softDeleteTask(id: String, now: Date = Date()) async throws -> TodoTask {
        var task = try existingTask(id: id)
        task.deletedAt = now
        task.updatedAt = now
        task.version += 1
        state.tasks[id] = task
        enqueue(kind: .delete, task: task, now: now)
        try await persist()
        return task
    }

    public func applyRemoteTasks(_ tasks: [TodoTask]) async throws {
        for remoteTask in tasks {
            state.tasks[remoteTask.id] = LastWriteWinsMerger.merge(
                local: state.tasks[remoteTask.id],
                remote: remoteTask
            )
        }
        try await persist()
    }

    public func clearOperations(ids: [String]) async throws {
        let ids = Set(ids)
        state.queue.removeAll { ids.contains($0.id) }
        try await persist()
    }

    private func existingTask(id: String) throws -> TodoTask {
        guard let task = state.tasks[id] else {
            throw LocalTodoRepositoryError.taskNotFound(id)
        }
        return task
    }

    private func enqueue(kind: SyncOperationKind, task: TodoTask, now: Date) {
        state.queue.append(SyncOperation(
            id: UUID().uuidString,
            kind: kind,
            task: task,
            createdAt: now
        ))
    }

    private func persist() async throws {
        try await storage.save(state)
    }
}

public enum LocalTodoRepositoryError: Error, Equatable, Sendable {
    case taskNotFound(String)
}
