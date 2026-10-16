import SwiftUI

@main
struct AdminDashboardApp: App {
    @StateObject private var auth = AuthStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isLoggedIn {
                    MainView(onLogout: { auth.logout() })
                } else {
                    LoginView(onLoggedIn: { auth.loginSucceeded() })
                }
            }
            .environmentObject(auth)
            .preferredColorScheme(.dark)
            // 强制布局尺寸与物理屏幕一致：防止系统/测试版系统给出异常窗口尺寸
            .frame(width: UIScreen.main.bounds.width,
                   height: UIScreen.main.bounds.height)
            .clipped()
        }
    }
}
