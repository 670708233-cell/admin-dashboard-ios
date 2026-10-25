import Foundation

// MARK: - 通用响应包装

/// { code, msg, data } 统一包装
struct ApiResp<T: Decodable>: Decodable {
    let code: Int
    let msg: String?
    let data: T?
}

/// 无 data 的响应（POST 操作用）
struct PlainResp: Decodable {
    let code: Int
    let msg: String?
}

/// 分页结构：兼容 list/items/users/cookies/logs/keys 与 total/count
struct PageData<T: Decodable>: Decodable {
    let list: [T]?
    let items: [T]?
    let users: [T]?
    let cookies: [T]?
    let logs: [T]?
    let keys: [T]?
    let total: Int?
    let count: Int?
    let page: Int?
    let pageSize: Int?

    var rows: [T] { list ?? items ?? users ?? cookies ?? logs ?? keys ?? [] }
    var totalCount: Int { total ?? count ?? 0 }
    var totalPages: Int { max(1, (totalCount + 19) / 20) }

    enum CodingKeys: String, CodingKey {
        case list, items, users, cookies, logs, keys, total, count, page
        case pageSize = "page_size"
    }
}

// MARK: - 认证

struct LoginReq: Encodable {
    let username: String
    let password: String
}

struct ChangePasswordReq: Encodable {
    let oldPassword: String
    let newPassword: String
    enum CodingKeys: String, CodingKey {
        case oldPassword = "old_password"
        case newPassword = "new_password"
    }
}

struct LoginData: Decodable {
    let token: String?
    let user: UserInfo?
    let userInfo: UserInfo?
}

struct UserInfo: Decodable {
    let id: Int?
    let username: String?
    let nickname: String?
    let role: String?
}

// MARK: - 仪表盘（后端返回驼峰键）

struct GrowthPoint: Decodable {
    let date: String?
    let count: Int?
}

struct RequestStat: Decodable {
    let total: Int?
    let success: Int?
    let failed: Int?
    let deleted: Int?
}

struct WebRequestStat: Decodable {
    let total: RequestStat?
    let query: RequestStat?
    let refresh: RequestStat?
    let weight: RequestStat?
    let publicQuery: RequestStat?
    let apiQuery: RequestStat?
    let unknown: RequestStat?
    enum CodingKeys: String, CodingKey {
        case total, query, refresh, weight, unknown
        case publicQuery = "public_query"
        case apiQuery = "api_query"
    }
}

struct MiniRequestStat: Decodable {
    let total: RequestStat?
    let video: RequestStat?
    let weight: RequestStat?
    let material: RequestStat?
    let unknown: RequestStat?
}

struct DashboardData: Decodable {
    let todayRegistrations: Int?
    let todayRecharge: Double?
    let totalUsers: Int?
    let totalRecharge: Double?
    let webTotalRequests: Int?
    let miniProgramTotalRequests: Int?
    let alipayTotalRequests: Int?
    let miniProgramTodayRegistrations: Int?
    let miniProgramTotalUsers: Int?
    let miniProgramTodayAdViews: Int?
    let miniProgramTodayAiAnalysis: Int?
    let miniProgramTodayAiWorkAnalysis: Int?
    let miniProgramTodayAiWeightAnalysis: Int?
    let miniProgramTodayRecharge: Double?
    let miniProgramTotalRecharge: Double?
    let alipayTodayRegistrations: Int?
    let alipayTotalUsers: Int?
    let alipayTodayAdViews: Int?
    let alipayTodayAiAnalysis: Int?
    let alipayTodayAiWorkAnalysis: Int?
    let alipayTodayAiWeightAnalysis: Int?
    let userGrowth: [GrowthPoint]?
    let miniProgramUserGrowth: [GrowthPoint]?
    let alipayUserGrowth: [GrowthPoint]?
    let todayRequests: RequestStat?
    let webRequests: WebRequestStat?
    let miniProgramRequests: MiniRequestStat?
    let alipayRequests: MiniRequestStat?
    let androidRequests: WebRequestStat?
    let iosRequests: WebRequestStat?
    let totalCookies: Int?
    let validCookies: Int?
    let invalidCookies: Int?
}

// MARK: - 网页端用户（snake_case + vip_info）

struct WebVipInfo: Decodable {
    let isVip: Bool?
    let isSuperVip: Int?
    let packageName: String?
    let startDate: String?
    let endDate: String?
    let dailyLimit: Int?
    enum CodingKeys: String, CodingKey {
        case isVip = "is_vip"
        case isSuperVip = "is_super_vip"
        case packageName = "package_name"
        case startDate = "start_date"
        case endDate = "end_date"
        case dailyLimit = "daily_limit"
    }
}

struct WebUser: Decodable, Identifiable {
    let id: Int?
    let username: String?
    let email: String?
    let balance: Double?
    let createdAt: String?
    let registerIp: String?
    let registerLocation: String?
    let isSuperVip: Int?
    let superVipDailyLimit: Int?
    let todayQueryCount: Int?
    let vipInfo: WebVipInfo?

    enum CodingKeys: String, CodingKey {
        case id, username, email, balance
        case createdAt = "created_at"
        case registerIp = "register_ip"
        case registerLocation = "register_location"
        case isSuperVip = "is_super_vip"
        case superVipDailyLimit = "super_vip_daily_limit"
        case todayQueryCount = "today_query_count"
        case vipInfo = "vip_info"
    }

    var vipLabel: String {
        if isSuperVip == 1 || vipInfo?.isSuperVip == 1 { return "超级VIP" }
        if vipInfo?.isVip == true { return "VIP至\(vipInfo?.endDate ?? "-")" }
        return "普通用户"
    }
}

/// 设置VIP：完整表单（对齐 Vue setSuperVipForm）
struct SetVipReq: Encodable {
    let userId: Int
    let isSuperVip: Int
    let vipType: String
    var dailyLimit: Int?
    var startDate: String?
    var endDate: String?
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case isSuperVip = "is_super_vip"
        case vipType = "vip_type"
        case dailyLimit = "daily_limit"
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

struct CloseVipReq: Encodable {
    let userId: Int
    let vipType: String
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case vipType = "vip_type"
    }
}

struct UpdateVipTimeReq: Encodable {
    let userId: Int
    let days: Int?
    let vipType: String
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case days, vipType = "vip_type"
    }
}

struct UpdateBalanceReq: Encodable {
    let userId: Int
    let balance: Double?
    let action: String
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case balance, action
    }
}

struct ChangeUserPasswordReq: Encodable {
    let userId: Int
    let newPassword: String
    let confirmPassword: String
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case newPassword = "new_password"
        case confirmPassword = "confirm_password"
    }
}

struct UserIdReq: Encodable {
    let userId: Int
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

// MARK: - 小程序用户（微信 / 支付宝）

struct MiniVipInfo: Decodable {
    let isVip: Bool?
    let packageId: Int?
    let startTime: String?
    let endTime: String?
    let dailyLimitVideo: Int?
    let dailyLimitWeight: Int?
    let usedTodayVideo: Int?
    let usedTodayWeight: Int?
    enum CodingKeys: String, CodingKey {
        case isVip = "is_vip"
        case packageId = "package_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case dailyLimitVideo = "daily_limit_video"
        case dailyLimitWeight = "daily_limit_weight"
        case usedTodayVideo = "used_today_video"
        case usedTodayWeight = "used_today_weight"
    }
}

struct MiniUser: Decodable, Identifiable {
    let id: Int?
    let openid: String?
    let userId: String?
    let nickname: String?
    let avatarUrl: String?
    let vipExpireTime: String?
    let createdAt: String?
    let lastLoginAt: String?
    let todayQueryCount: Int?
    let vipInfo: MiniVipInfo?

    enum CodingKeys: String, CodingKey {
        case id, openid, nickname
        case userId = "user_id"
        case avatarUrl = "avatar_url"
        case vipExpireTime = "vip_expire_time"
        case createdAt = "created_at"
        case lastLoginAt = "last_login_at"
        case todayQueryCount = "today_query_count"
        case vipInfo = "vip_info"
    }

    var vipLabel: String {
        if vipInfo?.isVip == true { return "VIP至\(vipInfo?.endTime ?? vipExpireTime ?? "-")" }
        return "普通用户"
    }
}

// 后端 mini 表 user_id 是 BIGINT,JSON 里以 number 输出;安卓 Gson 宽松转换无感,
// Swift JSONDecoder 严格类型会 typeMismatch(表现为"数据解析失败(200)")——手动兼容 int/str 双形态。
// 放 extension 以免抑制 struct 的合成 memberwise init(MiniVipSheet 占位构造要用)。
extension MiniUser {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id)
        openid = try c.decodeIfPresent(String.self, forKey: .openid)
        if let s = try? c.decode(String.self, forKey: .userId) {
            userId = s
        } else if let i = try? c.decode(Int.self, forKey: .userId) {
            userId = String(i)
        } else {
            userId = nil
        }
        nickname = try c.decodeIfPresent(String.self, forKey: .nickname)
        avatarUrl = try c.decodeIfPresent(String.self, forKey: .avatarUrl)
        vipExpireTime = try c.decodeIfPresent(String.self, forKey: .vipExpireTime)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        lastLoginAt = try c.decodeIfPresent(String.self, forKey: .lastLoginAt)
        todayQueryCount = try c.decodeIfPresent(Int.self, forKey: .todayQueryCount)
        vipInfo = try c.decodeIfPresent(MiniVipInfo.self, forKey: .vipInfo)
    }
}

struct AlipayUser: Decodable, Identifiable {
    let id: Int?
    let alipayUserId: String?
    let userId: String?
    let nickname: String?
    let avatarUrl: String?
    let vipExpireTime: String?
    let createdAt: String?
    let lastLoginAt: String?
    let todayQueryCount: Int?
    let vipInfo: MiniVipInfo?

    enum CodingKeys: String, CodingKey {
        case id, nickname
        case alipayUserId = "alipay_user_id"
        case userId = "user_id"
        case avatarUrl = "avatar_url"
        case vipExpireTime = "vip_expire_time"
        case createdAt = "created_at"
        case lastLoginAt = "last_login_at"
        case todayQueryCount = "today_query_count"
        case vipInfo = "vip_info"
    }

    var vipLabel: String {
        if vipInfo?.isVip == true { return "VIP至\(vipInfo?.endTime ?? vipExpireTime ?? "-")" }
        return "普通用户"
    }
}

/// set-vip：user_id 传 user_id 列的值（不是行 id）
struct MiniSetVipReq: Encodable {
    let userId: String
    let isVip: Int
    let packageId: Int?
    let startDate: String?
    let endDate: String?
    var orderNo: String?
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case isVip = "is_vip"
        case packageId = "package_id"
        case startDate = "start_date"
        case endDate = "end_date"
        case orderNo = "order_no"
    }
}

// MARK: - 小程序 VIP 套餐

/// 公开套餐接口：{ status, data: [...] }
struct PackageListResp: Decodable {
    let status: String?
    let data: [VipPackage]?
}

struct VipPackage: Decodable, Identifiable {
    let id: Int?
    let name: String?
    let type: Int?
    let duration: Int?
    let price: String?
    let dailyLimit: Int?
    let status: Int?
    enum CodingKeys: String, CodingKey {
        case id, name, type, duration, price, status
        case dailyLimit = "daily_limit"
    }
}

/// get-package：{ code, msg, data: { vip_info, package_info, is_expired } }
struct MiniVipDetailResp: Decodable {
    let code: Int
    let msg: String?
    let data: MiniVipDetail?
}

struct MiniVipDetail: Decodable {
    let vipInfo: MiniVipRecord?
    let packageInfo: VipPackage?
    let isExpired: Bool?
    enum CodingKeys: String, CodingKey {
        case vipInfo = "vip_info"
        case packageInfo = "package_info"
        case isExpired = "is_expired"
    }
}

struct MiniVipRecord: Decodable {
    let packageId: Int?
    let orderNo: String?
    let startTime: String?
    let endTime: String?
    let dailyLimit: Int?
    let dailyLimitVideo: Int?
    let dailyLimitWeight: Int?
    let usedTodayVideo: Int?
    let usedTodayWeight: Int?
    let status: Int?
    enum CodingKeys: String, CodingKey {
        case packageId = "package_id"
        case orderNo = "order_no"
        case startTime = "start_time"
        case endTime = "end_time"
        case dailyLimit = "daily_limit"
        case dailyLimitVideo = "daily_limit_video"
        case dailyLimitWeight = "daily_limit_weight"
        case usedTodayVideo = "used_today_video"
        case usedTodayWeight = "used_today_weight"
        case status
    }
}

// MARK: - Cookie 池

struct CookieItem: Decodable, Identifiable {
    let id: Int?
    let cookie: String?
    let isActive: Int?
    let isValid: Int?
    let useCount: Int?
    let lastUsedAt: String?
    let createdAt: String?
    enum CodingKeys: String, CodingKey {
        case id
        case cookie = "cookie_value"
        case isActive = "is_active"
        case isValid = "is_valid"
        case useCount = "use_count"
        case lastUsedAt = "last_used_at"
        case createdAt = "created_at"
    }
}

struct CookieStats: Decodable {
    let total: Int?
    let valid: Int?
    let invalid: Int?
    enum CodingKeys: String, CodingKey {
        case total = "total_cookies"
        case valid = "valid_cookies"
        case invalid = "invalid_cookies"
    }
}

struct CookieAddReq: Encodable {
    let cookieValue: String
    let platform: String?
    let remark: String?
    enum CodingKeys: String, CodingKey {
        case cookieValue = "cookie_value"
        case platform, remark
    }
}

struct CookieBatchAddReq: Encodable {
    let cookies: String
}

struct CookieUpdateStatusReq: Encodable {
    let id: Int
    let isActive: Int
    enum CodingKeys: String, CodingKey {
        case id
        case isActive = "is_active"
    }
}

struct IdReq: Encodable {
    let id: Int
}

struct CookieBatchDeleteReq: Encodable {
    let ids: [Int]
}

// MARK: - 系统设置

/// 站点状态（对齐 Android SiteStatusReq，Gson snake_case 线格式）
struct SiteStatusReq: Encodable {
    let platform: String      // web / mini_program / alipay_mini
    let isOpen: Int           // 1 开启 0 关闭
    let closeMessage: String?
    let expectedReopenTime: String?
    enum CodingKeys: String, CodingKey {
        case platform
        case isOpen = "is_open"
        case closeMessage = "close_message"
        case expectedReopenTime = "expected_reopen_time"
    }
}

/// {id, setting_key, setting_value, description, status, updated_at}
struct KeyValueSetting: Decodable, Identifiable {
    let id: Int?
    let settingKey: String?
    let settingValue: String?
    let description: String?
    let status: Int?
    let updatedAt: String?
    enum CodingKeys: String, CodingKey {
        case id, description, status
        case settingKey = "setting_key"
        case settingValue = "setting_value"
        case updatedAt = "updated_at"
    }
}

struct SettingUpdateReq: Encodable {
    let id: Int?
    let settingKey: String?
    let settingValue: String?
    let description: String?
    var status: Int?      // web 端 flow_card_ad 用（总开关）
    enum CodingKeys: String, CodingKey {
        case id, description, status
        case settingKey = "setting_key"
        case settingValue = "setting_value"
    }
}

/// 删除设置：mini/alipay 传 setting_key；web 传 id + setting_key
struct SettingDeleteReq: Encodable {
    var id: Int?
    var settingKey: String?
    enum CodingKeys: String, CodingKey {
        case id
        case settingKey = "setting_key"
    }
}

// MARK: - 操作日志（对齐后端 admin.Log 真实字段）

struct OpLog: Decodable, Identifiable {
    let id: Int?
    let username: String?
    let actionType: String?
    let description: String?
    let ipAddress: String?
    let userAgent: String?
    let createdAt: String?
    enum CodingKeys: String, CodingKey {
        case id, username, description
        case actionType = "action_type"
        case ipAddress = "ip_address"
        case userAgent = "user_agent"
        case createdAt = "created_at"
    }
}

// MARK: - AI Key 管理

struct AiKey: Decodable, Identifiable {
    let id: Int?
    let name: String?
    let provider: String?
    let apiKey: String?
    let baseUrl: String?
    let model: String?
    let priority: Int?
    let isActive: Int?
    let isAvailable: Int?
    let inCooldown: Bool?
    let cooldownRemain: Int?
    let todayCalls: Int?
    let totalCalls: Int?
    let failedCount: Int?
    let lastError: String?
    let lastCheckAt: String?
    let note: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, provider, model, priority, note
        case apiKey = "api_key"
        case baseUrl = "base_url"
        case isActive = "is_active"
        case isAvailable = "is_available"
        case inCooldown = "in_cooldown"
        case cooldownRemain = "cooldown_remain"
        case todayCalls = "today_calls"
        case totalCalls = "total_calls"
        case failedCount = "failed_count"
        case lastError = "last_error"
        case lastCheckAt = "last_check_at"
        case createdAt = "created_at"
    }
}

struct AiKeyStats: Decodable {
    let totalKeys: Int?
    let activeKeys: Int?
    let availableKeys: Int?
    let coolingKeys: Int?
    let todayCalls: Int?
    let failedTotal: Int?
    enum CodingKeys: String, CodingKey {
        case totalKeys = "total_keys"
        case activeKeys = "active_keys"
        case availableKeys = "available_keys"
        case coolingKeys = "cooling_keys"
        case todayCalls = "today_calls"
        case failedTotal = "failed_total"
    }
}

struct AiKeyConfig: Decodable {
    let cooldownSeconds: Int?
    enum CodingKeys: String, CodingKey {
        case cooldownSeconds = "cooldown_seconds"
    }
}

struct AiKeyAddReq: Encodable {
    let name: String
    let provider: String
    let apiKey: String
    let baseUrl: String
    let model: String
    let priority: Int?
    let note: String?
    enum CodingKeys: String, CodingKey {
        case name, provider, model, priority, note
        case apiKey = "api_key"
        case baseUrl = "base_url"
    }
}

struct AiKeyUpdateReq: Encodable {
    let id: Int
    let name: String?
    let apiKey: String?
    let baseUrl: String?
    let model: String?
    let priority: Int?
    let note: String?
    enum CodingKeys: String, CodingKey {
        case id, name, model, priority, note
        case apiKey = "api_key"
        case baseUrl = "base_url"
    }
}

struct AiKeyToggleReq: Encodable {
    let id: Int
    let isActive: Int
    enum CodingKeys: String, CodingKey {
        case id
        case isActive = "is_active"
    }
}

struct AiKeyCooldownReq: Encodable {
    let id: Int
}

struct AiKeySaveConfigReq: Encodable {
    let cooldownSeconds: Int
    enum CodingKeys: String, CodingKey {
        case cooldownSeconds = "cooldown_seconds"
    }
}

struct AiKeyDeleteReq: Encodable {
    let id: Int
}

struct AiKeyTestReq: Encodable {
    let id: Int
}
