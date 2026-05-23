import SwiftUI

struct QuickAddView: View {
    @ObservedObject var viewModel: MenuBarViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            TextField("Add a task", text: $viewModel.draftTitle)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit {
                    Task {
                        await viewModel.addDraftTask()
                        isFocused = true
                    }
                }

            Button {
                Task {
                    await viewModel.addDraftTask()
                    isFocused = true
                }
            } label: {
                if viewModel.isAdding {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "plus")
                }
            }
            .disabled(viewModel.isAdding)
            .buttonStyle(.borderedProminent)
            .help("Add task")
        }
    }
}
