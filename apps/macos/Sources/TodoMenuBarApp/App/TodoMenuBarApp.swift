import SwiftUI

@main
struct TodoMenuBarApp: App {
    @StateObject private var viewModel = MenuBarViewModel(service: PlaceholderTodoService())

    var body: some Scene {
        MenuBarExtra {
            MenuBarRootView(viewModel: viewModel)
                .frame(width: 380)
                .task {
                    await viewModel.restore()
                }
        } label: {
            Label("AI Todos", systemImage: "checklist")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}

struct SettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI Todos")
                .font(.headline)
            Text("Menu bar task capture for the MVP.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 320)
    }
}
