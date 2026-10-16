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
        }
    }
}
