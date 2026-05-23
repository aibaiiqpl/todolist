import Foundation

public struct LocalStoreState: Codable, Equatable, Sendable {
    public var tasks: [String: TodoTask]
    public var queue: [SyncOperation]

    public init(tasks: [String: TodoTask] = [:], queue: [SyncOperation] = []) {
        self.tasks = tasks
        self.queue = queue
    }
}
