import Foundation
import Security

/// 登录态：token 存 Keychain，内存缓存同步给 APIClient
final class AuthStore: ObservableObject {
    @Published var isLoggedIn = false

    private static let tokenKey = "com.doushujun.admin.token"

    init() {
        if let t = Keychain.read(Self.tokenKey), !t.isEmpty {
            APIClient.shared.token = t
            isLoggedIn = true
        }
    }

    func loginSucceeded() {
        isLoggedIn = true
    }

    func saveToken(_ token: String) {
        Keychain.save(Self.tokenKey, token)
        APIClient.shared.token = token
    }

    func logout() {
        Task {
            _ = try? await APIClient.shared.logout()
        }
        Keychain.delete(Self.tokenKey)
        APIClient.shared.token = nil
        isLoggedIn = false
    }
}

/// 极简 Keychain 封装
enum Keychain {
    static func save(_ key: String, _ value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData as String] = data
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
