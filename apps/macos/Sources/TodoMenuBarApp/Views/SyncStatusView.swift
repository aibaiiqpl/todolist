import SwiftUI

struct SyncStatusView: View {
    let snapshot: SyncSnapshot
    let isSyncing: Bool
    let syncAction: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: snapshot.state.systemImage)
                .foregroundStyle(statusColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusText)
                    .font(.caption)
                Text(detailText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                syncAction()
            } label: {
                if isSyncing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .disabled(isSyncing)
            .buttonStyle(.borderless)
            .help("Sync now")
        }
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var statusText: String {
        if case .failed(let message) = snapshot.state {
            return message
        }
        return snapshot.state.displayName
    }

    private var detailText: String {
        let pendingText = snapshot.pendingChanges == 1
            ? "1 pending change"
            : "\(snapshot.pendingChanges) pending changes"

        guard let lastSyncedAt = snapshot.lastSyncedAt else {
            return pendingText
        }

        return "\(pendingText) · Last sync \(lastSyncedAt.formatted(date: .omitted, time: .shortened))"
    }

    private var statusColor: Color {
        switch snapshot.state {
        case .idle:
            .green
        case .syncing:
            .blue
        case .offline:
            .secondary
        case .failed:
            .red
        }
    }
}
