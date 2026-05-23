import SwiftUI

struct NaturalLanguageInputView: View {
    @Binding var text: String
    let onOrganize: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: $text)
                .frame(minHeight: 96)
                .textInputAutocapitalization(.sentences)
                .overlay {
                    if text.isEmpty {
                        VStack {
                            HStack {
                                Text("例如：明天上午提醒我给客户发报价，重要")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                Spacer()
                            }
                            Spacer()
                        }
                    }
                }

            Button {
                onOrganize()
            } label: {
                Label("整理为任务", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}
