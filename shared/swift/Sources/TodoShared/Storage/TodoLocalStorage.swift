import Foundation

public protocol TodoLocalStorage: Sendable {
    func load() async throws -> LocalStoreState
    func save(_ state: LocalStoreState) async throws
}

public actor InMemoryTodoLocalStorage: TodoLocalStorage {
    private var state: LocalStoreState

    public init(state: LocalStoreState = LocalStoreState()) {
        self.state = state
    }

    public func load() async throws -> LocalStoreState {
        state
    }

    public func save(_ state: LocalStoreState) async throws {
        self.state = state
    }
}

public actor FileTodoLocalStorage: TodoLocalStorage {
    private let fileURL: URL
    private let encoder = JSONEncoder.todoSharedEncoder()
    private let decoder = JSONDecoder.todoSharedDecoder()

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() async throws -> LocalStoreState {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return LocalStoreState()
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(LocalStoreState.self, from: data)
    }

    public func save(_ state: LocalStoreState) async throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: [.atomic])
    }
}
