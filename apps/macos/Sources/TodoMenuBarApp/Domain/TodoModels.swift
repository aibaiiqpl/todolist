import Foundation

enum TodoPriorityLevel: String, CaseIterable, Identifiable {
    case low
    case normal
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low:
            "Low"
        case .normal:
            "Normal"
        case .high:
            "High"
        }
    }
}

struct TodoTask: Identifiable, Equatable {
    let id: UUID
    var title: String
    var completed: Bool
    var importance: TodoPriorityLevel
    var urgency: TodoPriorityLevel
    var dueAt: Date?
    var sourceText: String?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var version: Int

    var isDeleted: Bool {
        deletedAt != nil
    }
}

struct AuthSession: Equatable {
    var isAuthenticated: Bool
    var displayName: String?
    var userID: String?

    static let signedOut = AuthSession(
        isAuthenticated: false,
        displayName: nil,
        userID: nil
    )
}

enum SyncConnectionState: Equatable {
    case idle
    case syncing
    case offline
    case failed(String)

    var displayName: String {
        switch self {
        case .idle:
            "Synced"
        case .syncing:
            "Syncing"
        case .offline:
            "Offline"
        case .failed:
            "Sync failed"
        }
    }

    var systemImage: String {
        switch self {
        case .idle:
            "checkmark.icloud"
        case .syncing:
            "arrow.triangle.2.circlepath.icloud"
        case .offline:
            "wifi.slash"
        case .failed:
            "exclamationmark.icloud"
        }
    }
}

struct SyncSnapshot: Equatable {
    var state: SyncConnectionState
    var pendingChanges: Int
    var lastSyncedAt: Date?

    static let initial = SyncSnapshot(
        state: .offline,
        pendingChanges: 0,
        lastSyncedAt: nil
    )
}
