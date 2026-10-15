import SwiftUI

struct LoginView: View {
    var onLoggedIn: () -> Void

    @EnvironmentObject private var auth: AuthStore

    @State private var username = ""
    @State private var password = ""
    @State private var loading = false
    @State private var error: String?
    @FocusState private var focusedField: Field?

    private enum Field { case user, pwd }

    var body: some View {
        TechBackground()
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 40)

                // Logo
                ZStack {
                    Circle()
                        .fill(Tech.accentGradient)
                        .frame(width: 74, height: 74)
                        .shadow(color: Tech.cyan.opacity(0.6), radius: 18, x: 0, y: 0)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text("抖数君")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [.white, Tech.cyan], startPoint: .leading, endPoint: .trailing))
                    .padding(.top, 18)

                Text("后台管理系统 · ADMIN CONSOLE")
                    .font(.system(size: 11))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.45))
                    .padding(.top, 6)
                    .padding(.bottom, 22)

                VStack(spacing: 12) {
                    LabeledField(label: "用户名", text: $username)
                        .focused($focusedField, equals: .user)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .pwd }
                    LabeledField(label: "密码", text: $password, secure: true)
                        .focused($focusedField, equals: .pwd)
                        .submitLabel(.go)
                        .onSubmit { login() }
                }

                if let error {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(Tech.red)
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                }

                Button(action: login) {
                    ZStack {
                        Text("登 录")
                            .font(.system(size: 16, weight: .bold))
                            .tracking(4)
                            .foregroundColor(.white)
                        if loading {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(enabled ? Tech.accentGradient : LinearGradient(colors: [Color(white: 0.16)], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: enabled ? Tech.cyan.opacity(0.55) : .clear, radius: 16)
                }
                .disabled(!enabled)
                .padding(.top, 22)

                Spacer(minLength: 40)
            }
            .padding(26)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(Tech.glass.opacity(0.62))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Tech.cyan.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: Tech.cyan.opacity(0.3), radius: 18)
            .padding(.horizontal, 24)
        }
    }

    private var enabled: Bool { !loading && !username.isEmpty && !password.isEmpty }

    private func login() {
        guard enabled else { return }
        loading = true; error = nil
        focusedField = nil
        Task {
            do {
                let data = try await APIClient.shared.login(LoginReq(username: username, password: password))
                if let token = data.token, !token.isEmpty {
                    auth.saveToken(token)
                    auth.loginSucceeded()
                    onLoggedIn()
                } else {
                    error = "后端未返回 token，请检查登录接口字段"
                }
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }
}
