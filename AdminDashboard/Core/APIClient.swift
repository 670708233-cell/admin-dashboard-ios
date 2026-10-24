import Foundation

enum APIError: LocalizedError {
    case http(code: Int, msg: String)
    case transport(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .http(_, let msg): return msg.isEmpty ? "请求失败" : msg
        case .transport(let m): return m
        case .empty: return "返回数据为空"
        }
    }
}

/// 与 Android RetrofitClient 对应的接口客户端
final class APIClient {
    static let shared = APIClient()

    var token: String?

    private let base = "http://113.44.37.234:8000/api/"
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 50
        cfg.waitsForConnectivity = true
        session = URLSession(configuration: cfg)
    }

    // MARK: - 基础请求

    private func makeURL(_ path: String, _ query: [URLQueryItem]?) -> URL {
        var comps = URLComponents(string: base + path)!
        if let query, !query.isEmpty {
            comps.queryItems = query.filter { $0.value != nil && !($0.value!.isEmpty) }
        }
        return comps.url!
    }

    private func perform<T: Decodable>(
        _ path: String,
        method: String = "GET",
        query: [URLQueryItem]? = nil,
        body: (any Encodable)? = nil
    ) async throws -> T {
        var req = URLRequest(url: makeURL(path, query))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token, !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body { req.httpBody = try encoder.encode(body) }

        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
        guard let http = resp as? HTTPURLResponse else { throw APIError.transport("无效响应") }

        // 统一包装的 {code,msg,data}：code != 200 时抛出后端 msg
        if let plain = try? decoder.decode(PlainResp.self, from: data), plain.code != 200 {
            throw APIError.http(code: plain.code, msg: plain.msg ?? "")
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.transport("数据解析失败(\(http.statusCode))")
        }
    }

    /// 展开 ApiResp，data 为空时抛 empty
    private func unwrap<T: Decodable>(_ path: String, method: String = "GET", query: [URLQueryItem]? = nil, body: (any Encodable)? = nil) async throws -> T {
        let resp: ApiResp<T> = try await perform(path, method: method, query: query, body: body)
        guard resp.code == 200 else { throw APIError.http(code: resp.code, msg: resp.msg ?? "") }
        guard let data = resp.data else { throw APIError.empty }
        return data
    }

    // MARK: - 认证

    func login(_ req: LoginReq) async throws -> LoginData {
        try await unwrap("admin/login", method: "POST", body: req)
    }

    func logout() async throws {
        let _: PlainResp = try await perform("admin/logout", method: "GET")
    }

    func changePassword(_ req: ChangePasswordReq) async throws {
        let _: PlainResp = try await perform("admin/changePassword", method: "POST", body: req)
    }

    // MARK: - 仪表盘

    func dashboard() async throws -> DashboardData {
        try await unwrap("admin/dashboard")
    }

    // MARK: - 网页端用户

    func webUsers(page: Int = 1, pageSize: Int = 20, keyword: String? = nil, vipType: String? = nil, hasQueryToday: Bool? = nil) async throws -> PageData<WebUser> {
        try await unwrap("admin/users/list", query: [
            .init(name: "page", value: "\(page)"),
            .init(name: "page_size", value: "\(pageSize)"),
            .init(name: "search", value: keyword),
            .init(name: "vip_type", value: vipType),
            .init(name: "has_query_today", value: hasQueryToday == true ? "1" : nil)
        ])
    }

    func setSuperVip(_ req: SetVipReq) async throws { let _: PlainResp = try await perform("admin/users/set_super_vip", method: "POST", body: req) }
    func closeVip(_ req: CloseVipReq) async throws { let _: PlainResp = try await perform("admin/users/close_vip", method: "POST", body: req) }
    func updateVipTime(_ req: UpdateVipTimeReq) async throws { let _: PlainResp = try await perform("admin/users/update_vip_time", method: "POST", body: req) }
    func updateBalance(_ req: UpdateBalanceReq) async throws { let _: PlainResp = try await perform("admin/users/updateBalance", method: "POST", body: req) }
    func changeUserPassword(_ req: ChangeUserPasswordReq) async throws { let _: PlainResp = try await perform("admin/users/changeUserPassword", method: "POST", body: req) }
    func deleteUser(_ req: UserIdReq) async throws { let _: PlainResp = try await perform("admin/users/delete", method: "POST", body: req) }

    // MARK: - 微信小程序用户

    func miniUsers(page: Int = 1, pageSize: Int = 20, keyword: String? = nil, vipType: String? = nil) async throws -> PageData<MiniUser> {
        try await unwrap("admin/mini/user/list", query: [
            .init(name: "page", value: "\(page)"),
            .init(name: "page_size", value: "\(pageSize)"),
            .init(name: "search", value: keyword),
            .init(name: "vip_type", value: vipType)
        ])
    }

    func miniSetVip(_ req: MiniSetVipReq) async throws { let _: PlainResp = try await perform("admin/mini/user/set-vip", method: "POST", body: req) }
    func miniUserVipDetail(userId: String) async throws -> MiniVipDetailResp {
        try await perform("admin/mini/user/get-package", query: [.init(name: "user_id", value: userId)])
    }
    func miniPackages() async throws -> PackageListResp {
        try await perform("mini_program/vip_official/packages")
    }

    // MARK: - 支付宝小程序用户

    func alipayUsers(page: Int = 1, pageSize: Int = 20, keyword: String? = nil, vipType: String? = nil) async throws -> PageData<AlipayUser> {
        try await unwrap("admin/alipay/user/list", query: [
            .init(name: "page", value: "\(page)"),
            .init(name: "page_size", value: "\(pageSize)"),
            .init(name: "search", value: keyword),
            .init(name: "vip_type", value: vipType)
        ])
    }

    func alipaySetVip(_ req: MiniSetVipReq) async throws { let _: PlainResp = try await perform("admin/alipay/user/set-vip", method: "POST", body: req) }
    func alipayPackages() async throws -> PackageListResp {
        try await perform("alipay_mini/vip/packages")
    }

    // MARK: - Cookie 池

    func cookieList(page: Int = 1, pageSize: Int = 20, keyword: String? = nil) async throws -> PageData<CookieItem> {
        try await unwrap("admin/cookie/list", query: [
            .init(name: "page", value: "\(page)"),
            .init(name: "page_size", value: "\(pageSize)"),
            .init(name: "search", value: keyword)
        ])
    }

    func cookieStats() async throws -> CookieStats {
        try await unwrap("admin/cookie/stats")
    }

    func cookieAdd(_ req: CookieAddReq) async throws { let _: PlainResp = try await perform("admin/cookie/add", method: "POST", body: req) }
    func cookieBatchAdd(_ req: CookieBatchAddReq) async throws { let _: PlainResp = try await perform("admin/cookie/batch-add", method: "POST", body: req) }
    func cookieUpdateStatus(_ req: CookieUpdateStatusReq) async throws { let _: PlainResp = try await perform("admin/cookie/update-status", method: "POST", body: req) }
    func cookieDelete(_ req: IdReq) async throws { let _: PlainResp = try await perform("admin/cookie/delete", method: "POST", body: req) }
    func cookieBatchDelete(_ req: CookieBatchDeleteReq) async throws { let _: PlainResp = try await perform("admin/cookie/batch-delete", method: "POST", body: req) }

    // MARK: - 系统设置

    func settingsGet() async throws -> [String: Any?] {
        struct Resp: Decodable { let code: Int; let data: [String: AnyCodable]? }
        let r: Resp = try await perform("admin/settings/get")
        guard r.code == 200, let d = r.data else { throw APIError.empty }
        return d.mapValues { $0.value }
    }

    func settingsSave(_ map: [String: String]) async throws {
        let _: PlainResp = try await perform("admin/settings/save", method: "POST", body: map)
    }

    func siteStatus(_ req: SiteStatusReq) async throws { let _: PlainResp = try await perform("admin/settings/site_status", method: "POST", body: req) }

    func miniProgramSettings() async throws -> [KeyValueSetting] {
        try await unwrap("admin/mini_program/getSettings")
    }
    func miniProgramUpdateSetting(_ req: SettingUpdateReq) async throws { let _: PlainResp = try await perform("admin/mini_program/updateSetting", method: "POST", body: req) }
    func miniProgramDeleteSetting(_ req: SettingDeleteReq) async throws { let _: PlainResp = try await perform("admin/mini_program/deleteSetting", method: "POST", body: req) }

    func alipaySettings() async throws -> [KeyValueSetting] {
        try await unwrap("admin/alipay_settings/getSettings")
    }
    func alipayUpdateSetting(_ req: SettingUpdateReq) async throws { let _: PlainResp = try await perform("admin/alipay_settings/updateSetting", method: "POST", body: req) }
    func alipayDeleteSetting(_ req: SettingDeleteReq) async throws { let _: PlainResp = try await perform("admin/alipay_settings/deleteSetting", method: "POST", body: req) }

    // MARK: - Web 端设置（公告/流量卡广告等 web 专属 KV）

    func webSettings() async throws -> [KeyValueSetting] {
        try await unwrap("admin/web_settings/getSettings")
    }
    func webUpdateSetting(_ req: SettingUpdateReq) async throws { let _: PlainResp = try await perform("admin/web_settings/updateSetting", method: "POST", body: req) }
    func webDeleteSetting(_ req: SettingDeleteReq) async throws { let _: PlainResp = try await perform("admin/web_settings/deleteSetting", method: "POST", body: req) }

    // MARK: - 操作日志

    func logsList(page: Int = 1, pageSize: Int = 20, keyword: String? = nil, action: String? = nil) async throws -> PageData<OpLog> {
        try await unwrap("admin/logs/list", query: [
            .init(name: "page", value: "\(page)"),
            .init(name: "page_size", value: "\(pageSize)"),
            .init(name: "search", value: keyword),
            .init(name: "action_type", value: action)
        ])
    }

    func logDetail(id: Int) async throws -> OpLog {
        try await unwrap("admin/logs/detail", query: [.init(name: "id", value: "\(id)")])
    }

    // MARK: - AI Key 管理

    func aiKeys(page: Int = 1, pageSize: Int = 100, keyword: String? = nil) async throws -> PageData<AiKey> {
        try await unwrap("admin/ai_keys/list", query: [
            .init(name: "page", value: "\(page)"),
            .init(name: "page_size", value: "\(pageSize)"),
            .init(name: "search", value: keyword)
        ])
    }

    func aiKeyStats() async throws -> AiKeyStats { try await unwrap("admin/ai_keys/stats") }
    func aiKeyConfig() async throws -> AiKeyConfig { try await unwrap("admin/ai_keys/config") }
    func aiKeyAdd(_ req: AiKeyAddReq) async throws { let _: PlainResp = try await perform("admin/ai_keys/add", method: "POST", body: req) }
    func aiKeyUpdate(_ req: AiKeyUpdateReq) async throws { let _: PlainResp = try await perform("admin/ai_keys/update", method: "POST", body: req) }
    func aiKeyToggle(_ req: AiKeyToggleReq) async throws { let _: PlainResp = try await perform("admin/ai_keys/toggle", method: "POST", body: req) }
    func aiKeyResetCooldown(_ req: AiKeyCooldownReq) async throws { let _: PlainResp = try await perform("admin/ai_keys/reset_cooldown", method: "POST", body: req) }
    func aiKeySaveConfig(_ req: AiKeySaveConfigReq) async throws { let _: PlainResp = try await perform("admin/ai_keys/save_config", method: "POST", body: req) }
    func aiKeyDelete(_ req: AiKeyDeleteReq) async throws { let _: PlainResp = try await perform("admin/ai_keys/delete", method: "POST", body: req) }
    func aiKeyTest(_ req: AiKeyTestReq) async throws { let _: PlainResp = try await perform("admin/ai_keys/test", method: "POST", body: req) }
}

/// settingsGet 的任意值容器
struct AnyCodable: Decodable {
    let value: Any?
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { value = nil }
        else if let i = try? c.decode(Int.self) { value = i }
        else if let d = try? c.decode(Double.self) { value = d }
        else if let b = try? c.decode(Bool.self) { value = b }
        else if let s = try? c.decode(String.self) { value = s }
        else { value = nil }
    }
}
