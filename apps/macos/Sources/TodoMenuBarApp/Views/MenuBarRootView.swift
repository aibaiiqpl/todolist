import SwiftUI

struct MenuBarRootView: View {
    @ObservedObject var viewModel: MenuBarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if viewModel.authSession?.isAuthenticated == true {
                signedInContent
            } else {
                SignInPanel(viewModel: viewModel)
            }
        }
        .padding(14)
    }

    private var signedInContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            SyncStatusView(
                snapshot: viewModel.syncSnapshot,
                isSyncing: viewModel.isSyncing,
                syncAction: {
                    Task {
                        await viewModel.syncNow()
                    }
                }
            )
            QuickAddView(viewModel: viewModel)
            TaskListView(viewModel: viewModel)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Todos")
                    .font(.headline)
                Text(viewModel.authSession?.displayName ?? "Signed in")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task {
                    await viewModel.signOut()
                }
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
            }
            .buttonStyle(.borderless)
            .help("Sign out")
        }
    }
}
