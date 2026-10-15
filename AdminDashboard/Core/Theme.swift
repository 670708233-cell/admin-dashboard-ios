import SwiftUI

// MARK: - 科技感配色（与 Android 端一致）

enum Tech {
    static let cyan = Color(red: 0.0, green: 0.898, blue: 1.0)      // #00E5FF
    static let blue = Color(red: 0.227, green: 0.482, blue: 1.0)    // #3A7BFF
    static let purple = Color(red: 0.604, green: 0.400, blue: 0.941) // #9A66F0
    static let green = Color(red: 0.169, green: 0.831, blue: 0.478) // #2BD47A
    static let red = Color(red: 1.0, green: 0.357, blue: 0.431)     // #FF5B6E
    static let yellow = Color(red: 0.945, green: 0.769, blue: 0.059) // #F1C40F

    static let bgTop = Color(red: 0.016, green: 0.024, blue: 0.059)     // #04060F
    static let bgBottom = Color(red: 0.039, green: 0.071, blue: 0.157)  // #0A1228
    static let glass = Color(red: 0.055, green: 0.090, blue: 0.200)     // #0E1733
    static let track = Color(red: 0.102, green: 0.133, blue: 0.251)     // #1A2240

    static let accentGradient = LinearGradient(
        colors: [cyan, blue, purple],
        startPoint: .leading, endPoint: .trailing
    )

    /// 统计卡主题色（按索引循环）
    static let accents: [Color] = [
        Color(red: 0.180, green: 0.800, blue: 0.443), // #2ECC71
        Color(red: 0.251, green: 0.620, blue: 1.0),   // #409EFF
        Color(red: 0.945, green: 0.769, blue: 0.059), // #F1C40F
        Color(red: 0.204, green: 0.596, blue: 0.859), // #3498DB
        Color(red: 0.604, green: 0.400, blue: 0.941), // #9A66F0
        Color(red: 0.902, green: 0.447, blue: 0.137)  // #E67E22
    ]

    static func accent(_ i: Int) -> Color { accents[i % accents.count] }
}

/// 数值格式化（对齐 Android fmt）
func fmt(_ v: Any?) -> String {
    switch v {
    case nil: return "-"
    case let d as Double: return d == d.rounded() ? String(Int64(d)) : String(format: "%.2f", d)
    case let i as Int: return String(i)
    case let s as String: return s
    default: return "\(v ?? "-")"
    }
}
