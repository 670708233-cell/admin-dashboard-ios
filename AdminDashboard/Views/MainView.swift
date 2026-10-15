import SwiftUI

enum Screen: String, CaseIterable {
    case dashboard = "仪表盘"
    case web = "网页端用户"
    case mini = "微信小程序用户"
    case alipay = "支付宝小程序用户"
    case cookie = "Cookie 池"
    case settings = "系统设置"
    case logs = "操作日志"
    case aikey = "AI Key 管理"

    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.bottom.50"
        case .web: return "person.2"
        case .mini: return "message.fill"
        case .alipay: return "creditcard.fill"
        case .cookie: return "circle.hexagonpath.fill"
        case .settings: return "gearshape"
        case .logs: return "list.bullet.rectangle"
        case .aikey: return "key.fill"
        }
    }
}

/// 主框架：侧边抽屉导航（对齐 Android ModalNavigationDrawer）
struct MainView: View {
    var onLogout: () -> Void

    @EnvironmentObject private var auth: AuthStore
    @State private var screen: Screen = .dashboard
    @State private var drawerOpen = false
    @State private var showChangePwd = false
    @State private var toast: String?
    @State private var toastTask: Task<Void, Never>?

    private let drawerWidth: CGFloat = 280

    var body: some View {
        ZStack(alignment: .leading) {
            TechBackground()

            // 主内容
            VStack(spacing: 0) {
                header
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // 遮罩
            if drawerOpen {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.spring()) { drawerOpen = false } }
            }

            // 抽屉
            drawer
                .frame(width: drawerWidth)
                .offset(x: drawerOpen ? 0 : -drawerWidth)

            // Toast
            if let toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Tech.glass.opacity(0.95)).overlay(Capsule().strokeBorder(Tech.cyan.opacity(0.5), lineWidth: 1)))
                        .shadow(color: Tech.cyan.opacity(0.3), radius: 10)
                        .padding(.bottom, 40)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
            }
        }
        .animation(.spring(), value: drawerOpen)
        .sheet(isPresented: $showChangePwd) {
            ChangePasswordSheet()
        }
    }

    // MARK: 顶栏

    private var header: some View {
        HStack {
            Button { withAnimation(.spring()) { drawerOpen = true } } label: {
                Image(systemName: "line.3")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
            Text(screen.rawValue)
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            Button { showChangePwd = true } label: {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Tech.cyan)
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 8)
        .background(Color.black.opacity(0.25))
    }

    // MARK: 内容区

    @ViewBuilder
    private var content: some View {
        switch screen {
        case .dashboard: DashboardView()
        case .web: WebUsersView()
        case .mini: MiniUsersView()
        case .alipay: AlipayUsersView()
        case .cookie: CookieView()
        case .settings: SettingsView()
        case .logs: LogsView()
        case .aikey: AiKeysView()
        }
    }

    // MARK: 抽屉

    private var drawer: some View {
        ZStack(alignment: .leading) {
            TechBackground()
            VStack(alignment: .leading, spacing: 0) {
                Text("抖数君后台")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [.white, Tech.cyan], startPoint: .leading, endPoint: .trailing))
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 12)

                ScrollView {
                    ForEach(Screen.allCases, id: \.self) { item in
                        Button {
                            screen = item
                            withAnimation(.spring()) { drawerOpen = false }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 16))
                                    .frame(width: 24)
                                Text(item.rawValue)
                                    .font(.system(size: 15))
                                Spacer()
                            }
                            .foregroundColor(screen == item ? Tech.cyan : .white.opacity(0.8))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(screen == item ? Tech.cyan.opacity(0.15) : .clear)
                            )
                        }
                        .padding(.horizontal, 8)
                    }

                    Spacer(minLength: 24)

                    Button {
                        withAnimation(.spring()) { drawerOpen = false }
                        showChangePwd = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "key.fill").frame(width: 24)
                            Text("修改密码").font(.system(size: 15))
                            Spacer()
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .padding(.horizontal, 8)

                    Button {
                        withAnimation(.spring()) { drawerOpen = false }
                        auth.logout()
                        onLogout()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.portrait.and.arrow.right").frame(width: 24)
                            Text("退出登录").font(.system(size: 15))
                            Spacer()
                        }
                        .foregroundColor(Tech.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .padding(.horizontal, 8)
                }
            }
            .padding(.bottom, 24)
        }
        .shadow(color: .black.opacity(0.5), radius: 20)
    }

    // MARK: Toast

    func showToast(_ msg: String) {
        toastTask?.cancel()
        withAnimation(.spring()) { toast = msg }
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if !Task.isCancelled {
                withAnimation(.spring()) { toast = nil }
            }
        }
    }
}

/// 修改密码
struct ChangePasswordSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var oldPwd = ""
    @State private var newPwd = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                LabeledField(label: "旧密码", text: $oldPwd, secure: true)
                LabeledField(label: "新密码", text: $newPwd, secure: true)
                if let error {
                    Text(error).font(.system(size: 13)).foregroundColor(Tech.red)
                }
                Button("确定") {
                    Task {
                        do {
                            try await APIClient.shared.changePassword(ChangePasswordReq(oldPassword: oldPwd, newPassword: newPwd))
                            dismiss()
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                }
                .buttonStyle(TechButtonStyle(enabled: !oldPwd.isEmpty && !newPwd.isEmpty))
                .disabled(oldPwd.isEmpty || newPwd.isEmpty)
                Spacer()
            }
            .padding(20)
            .background(Tech.bgBottom.ignoresSafeArea())
            .navigationTitle("修改密码")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundColor(Tech.cyan)
                }
            }
        }
    }
}
