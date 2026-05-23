import Foundation

public enum TaskPriority: Int, Codable, Comparable, Sendable, CaseIterable {
    case low = 1
    case mediumLow = 2
    case medium = 3
    case high = 4
    case critical = 5

    public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
