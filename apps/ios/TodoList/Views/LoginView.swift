import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var store: TodoStore

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 8) {
                Text("使用 Apple 登录")
                    .font(.title2.weight(.semibold))
                Text("登录后可以整理任务并与其他端同步")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                Task {
                    await store.handleAppleAuthorization(result)
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(24)
    }
}
