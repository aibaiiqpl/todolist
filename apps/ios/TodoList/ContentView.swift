import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: TodoStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SyncStatusView()
                if store.isAuthenticated {
                    MainTodoView()
                } else {
                    LoginView()
                }
            }
            .navigationTitle("AI 待办")
        }
    }
}

private struct MainTodoView: View {
    @EnvironmentObject private var store: TodoStore
    @State private var inputText = ""

    var body: some View {
        List {
            Section("自然语言输入") {
                NaturalLanguageInputView(text: $inputText) {
                    Task {
                        await store.organize(sourceText: inputText)
                    }
                }
            }

            if !store.drafts.isEmpty {
                Section("AI 草稿") {
                    ForEach(store.drafts) { draft in
                        DraftPreviewView(draft: draft) { updatedDraft in
                            Task {
                                await store.confirmDraft(updatedDraft)
                                if store.drafts.isEmpty {
                                    inputText = ""
                                }
                            }
                        } onCancel: {
                            store.cancelDraft(draft)
                            if store.drafts.isEmpty {
                                inputText = ""
                            }
                        }
                    }
                }
            }

            Section("任务") {
                TaskListView()
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await store.sync()
        }
    }
}
