import SwiftUI

struct DraftPreviewView: View {
    @State private var draft: TodoDraft
    @State private var hasDueDate: Bool
    let onConfirm: (TodoDraft) -> Void
    let onCancel: () -> Void

    init(
        draft: TodoDraft,
        onConfirm: @escaping (TodoDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: draft)
        _hasDueDate = State(initialValue: draft.dueAt != nil)
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("任务标题", text: $draft.title, axis: .vertical)

            Picker("重要程度", selection: $draft.importance) {
                ForEach(TaskImportance.allCases) { importance in
                    Text(importance.title).tag(importance)
                }
            }

            Picker("紧急程度", selection: $draft.urgency) {
                ForEach(TaskUrgency.allCases) { urgency in
                    Text(urgency.title).tag(urgency)
                }
            }

            Toggle("截止时间", isOn: $hasDueDate.animation())

            if hasDueDate {
                DatePicker(
                    "日期",
                    selection: Binding(
                        get: { draft.dueAt ?? Date() },
                        set: { draft.dueAt = $0 }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            HStack {
                Button("取消", role: .cancel) {
                    onCancel()
                }
                Spacer()
                Button {
                    if !hasDueDate {
                        draft.dueAt = nil
                    } else if draft.dueAt == nil {
                        draft.dueAt = Date()
                    }
                    onConfirm(draft)
                } label: {
                    Label("确认", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}
