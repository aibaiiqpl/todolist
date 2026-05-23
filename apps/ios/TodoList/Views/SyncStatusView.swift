import SwiftUI

struct SyncStatusView: View {
    @EnvironmentObject private var store: TodoStore

    var body: some View {
        HStack(spacing: 8) {
            statusImage
            Text(store.syncState.title)
                .font(.caption.weight(.medium))
            Spacer()
            if case .failed(let message) = store.syncState {
                Text(message)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    @ViewBuilder
    private var statusImage: some View {
        switch store.syncState {
        case .idle:
            Image(systemName: "checkmark.icloud")
                .foregroundStyle(.green)
        case .syncing:
            ProgressView()
                .controlSize(.small)
        case .offlinePending:
            Image(systemName: "icloud.and.arrow.up")
                .foregroundStyle(.orange)
        case .failed:
            Image(systemName: "exclamationmark.icloud")
                .foregroundStyle(.red)
        }
    }
}
