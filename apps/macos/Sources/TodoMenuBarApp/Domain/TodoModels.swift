import Foundation
import TodoShared

extension TaskPriority {
    var displayName: String {
        switch self {
        case .low:
            "Low"
        case .mediumLow:
            "Medium Low"
        case .medium:
            "Medium"
        case .high:
            "High"
        case .critical:
            "Critical"
        }
    }
}

extension TodoTask {
    var isDeleted: Bool {
        deletedAt != nil
    }
}

extension AuthSession {
    var isAuthenticated: Bool {
        expiresAt > Date()
    }

    var displayName: String {
        userID
    }
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
