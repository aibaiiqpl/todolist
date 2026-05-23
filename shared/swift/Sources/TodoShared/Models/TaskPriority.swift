import Foundation

public enum TaskPriority: Int, Codable, Comparable, Sendable, CaseIterable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3

    public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
