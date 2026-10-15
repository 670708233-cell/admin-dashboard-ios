import Foundation

/// 仪表盘自动刷新间隔（秒）持久化：0 = 关闭
enum RefreshIntervalStore {
    private static let key = "dashboard.refresh.sec"

    static func get() -> Int {
        UserDefaults.standard.integer(forKey: key)
    }

    static func save(_ seconds: Int) {
        UserDefaults.standard.set(seconds, forKey: key)
    }

    static let options: [(Int, String)] = [
        (0, "关闭"), (15, "每 15 秒"), (30, "每 30 秒"), (60, "每 1 分钟"), (300, "每 5 分钟")
    ]

    static func label(_ sec: Int) -> String {
        options.first { $0.0 == sec }?.1.replacingOccurrences(of: "每 ", with: "") ?? "\(sec)秒"
    }
}
