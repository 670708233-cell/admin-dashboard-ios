import SwiftUI

// MARK: - 系统设置（对齐 Android SettingsScreen 六标签页）

struct SettingsView: View {
    @State private var tab = 0
    // 2026-11-06 对齐 Vue 端更新：新增「代理设置」（快代理动态IP/熔断直连/告警邮件）
    // 2026-11-12 对齐 Vue 端更新：新增「取数引擎」（Web引擎体系/手机端接口）
    private let tabs = ["基础设置", "微信小程序", "支付宝小程序", "Web端设置", "用户设置", "点数设置", "接口限流", "安卓更新", "iOS更新", "代理设置", "取数引擎"]
    @State private var settings: [String: Any?]?
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Group {
                if let error, settings == nil { ErrorBox(message: error) { load() } }
                else if settings == nil { LoadingBox() }
                else { tabContent }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .task { load() }
    }

    private func load() {
        Task {
            do { settings = try await APIClient.shared.settingsGet(); error = nil }
            catch { self.error = error.localizedDescription }
        }
    }

    // 可横滑标签条（对应 Android ScrollableTabRow）
    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<tabs.count, id: \.self) { i in
                    Button { withAnimation(.easeOut(duration: 0.15)) { tab = i } } label: {
                        Text(tabs[i])
                            .font(.system(size: 13, weight: tab == i ? .semibold : .regular))
                            .foregroundColor(tab == i ? .black : .white.opacity(0.75))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Capsule().fill(tab == i ? AnyShapeStyle(Tech.accentGradient) : AnyShapeStyle(Color.white.opacity(0.08))))
                            .overlay(Capsule().strokeBorder(tab == i ? Color.clear : Tech.cyan.opacity(0.25), lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        let map = settings ?? [:]
        switch tab {
        case 0: BasicSettingsTab(settings: map)
        case 1: KeyValueSection(load: { try await APIClient.shared.miniProgramSettings() },
                                save: { try await APIClient.shared.miniProgramUpdateSetting($0) },
                                delete: { try await APIClient.shared.miniProgramDeleteSetting($0) },
                                announcementEnabled: true)
        case 2: KeyValueSection(load: { try await APIClient.shared.alipaySettings() },
                                save: { try await APIClient.shared.alipayUpdateSetting($0) },
                                delete: { try await APIClient.shared.alipayDeleteSetting($0) },
                                announcementEnabled: true)
        case 3: KeyValueSection(load: { try await APIClient.shared.webSettings() },
                                save: { try await APIClient.shared.webUpdateSetting($0) },
                                delete: { try await APIClient.shared.webDeleteSetting($0) },
                                announcementEnabled: true,
                                flowCardAdEnabled: true)
        case 4: UserSettingsTab(settings: map)
        case 5: PointsSettingsTab(settings: map)
        case 6: RateLimitTab(settings: map)
        case 7: AppUpdateTab(settings: map, prefix: "app_update", title: "安卓端更新设置")
        case 8: AppUpdateTab(settings: map, prefix: "ios_app_update", title: "iOS端更新设置")
        case 9: ProxySettingsTab()                                             // 代理设置（独立接口加载，不依赖 settings map）
        case 10: DouyinDetailEngineTab()                                       // 取数引擎（独立接口加载）
        default: AppUpdateTab(settings: map, prefix: "ios_app_update", title: "iOS端更新设置")
        }
    }
}

// MARK: - settings/get Map 取值辅助（对齐 Android str/bool/int）

extension Dictionary where Key == String, Value == Any? {
    func settingStr(_ key: String) -> String {
        guard let v = self[key] ?? nil else { return "" }
        if let s = v as? String { return s }
        if let i = v as? Int { return String(i) }
        if let d = v as? Double { return d == d.rounded() ? String(Int(d)) : String(format: "%.2f", d) }
        if let b = v as? Bool { return b ? "1" : "0" }
        return "\(v)"
    }
    func settingBool(_ key: String, _ def: Bool = true) -> Bool {
        guard let v = self[key] ?? nil else { return def }
        if let b = v as? Bool { return b }
        if let i = v as? Int { return i == 1 }
        if let d = v as? Double { return d == 1.0 }
        let s = "\(v)"
        return s == "1" || s == "true"
    }
    func settingInt(_ key: String, _ def: Int) -> Int {
        guard let v = self[key] ?? nil else { return def }
        if let i = v as? Int { return i }
        if let d = v as? Double { return Int(d) }
        if let s = v as? String, let i = Int(s) { return i }
        return def
    }
}

extension String {
    func ifBlank(_ fallback: String) -> String { isEmpty ? fallback : self }
}

// MARK: - Toast 修饰器 + 开关行 + 带提示字段

extension View {
    func toastOverlay(_ message: String?) -> some View {
        overlay(alignment: .bottom) {
            if let message {
                Text(message)
                    .font(.system(size: 14)).foregroundColor(.white)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(Capsule().fill(Tech.glass.opacity(0.95)))
                    .overlay(Capsule().strokeBorder(Tech.cyan.opacity(0.5), lineWidth: 1))
                    .padding(.bottom, 30).allowsHitTesting(false).transition(.opacity)
            }
        }
    }
}

struct SwitchRow: View {
    let label: String
    @Binding var checked: Bool
    var body: some View {
        Toggle(isOn: $checked) {
            Text(label).font(.system(size: 14)).foregroundColor(.white.opacity(0.9))
        }
        .tint(Tech.cyan)
    }
}

private struct FieldWithHint: View {
    let label: String
    let hint: String?
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    init(label: String, hint: String? = nil, keyboard: UIKeyboardType = .default, text: Binding<String>) {
        self.label = label; self.hint = hint; self.keyboard = keyboard; _text = text
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledField(label: label, text: $text, keyboard: keyboard)
            if let hint {
                Text(hint).font(.system(size: 11)).foregroundColor(.white.opacity(0.4))
            }
        }
    }
}

// MARK: - Tab 1：基础设置 + 三平台站点状态

private struct BasicSettingsTab: View {
    let settings: [String: Any?]
    @State private var siteName = ""
    @State private var siteDesc = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var toast: String?

    init(settings: [String: Any?]) {
        self.settings = settings
        _siteName = State(initialValue: settings.settingStr("site_name"))
        _siteDesc = State(initialValue: settings.settingStr("site_description"))
        _phone = State(initialValue: settings.settingStr("contact_phone"))
        _email = State(initialValue: settings.settingStr("contact_email"))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                GlassCard(borderAlpha: 0.25, glowAlpha: 0.12) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("网站信息").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                        LabeledField(label: "网站名称", text: $siteName)
                        LabeledField(label: "网站描述", text: $siteDesc)
                        LabeledField(label: "客服电话", text: $phone)
                        LabeledField(label: "联系邮箱", text: $email)
                        Button("保存基础设置") {
                            Task {
                                do {
                                    try await APIClient.shared.settingsSave([
                                        "site_name": siteName, "site_description": siteDesc,
                                        "contact_phone": phone, "contact_email": email])
                                    toast = "基础设置保存成功"
                                } catch { toast = error.localizedDescription }
                            }
                        }
                        .buttonStyle(TechButtonStyle()).padding(.top, 4)
                    }
                }
                SiteStatusCard(title: "Web端站点状态", platform: "web",
                               isOpen: settings.settingBool("is_web_open"),
                               closeMessage: settings.settingStr("web_close_message").ifBlank("系统维护中，请稍后访问..."),
                               reopenTime: settings.settingStr("web_expected_reopen_time"))
                SiteStatusCard(title: "微信小程序端站点状态", platform: "mini_program",
                               isOpen: settings.settingBool("is_mini_program_open"),
                               closeMessage: settings.settingStr("mini_program_close_message").ifBlank("小程序维护中，请稍后访问..."),
                               reopenTime: settings.settingStr("mini_program_expected_reopen_time"))
                SiteStatusCard(title: "支付宝小程序端站点状态", platform: "alipay_mini",
                               isOpen: settings.settingBool("is_alipay_mini_open"),
                               closeMessage: settings.settingStr("alipay_mini_close_message").ifBlank("支付宝小程序维护中，请稍后访问..."),
                               reopenTime: settings.settingStr("alipay_mini_expected_reopen_time"))
            }
            .padding(16)
        }
        .toastOverlay(toast)
    }
}

// 三平台站点状态卡片（开关 + 关闭提示语 + 预计恢复时间）
private struct SiteStatusCard: View {
    let title: String
    let platform: String
    let isOpen: Bool
    let closeMessage: String
    let reopenTime: String
    @State private var open = true
    @State private var msg = ""
    @State private var reopen = ""
    @State private var toast: String?

    init(title: String, platform: String, isOpen: Bool, closeMessage: String, reopenTime: String) {
        self.title = title; self.platform = platform; self.isOpen = isOpen
        self.closeMessage = closeMessage; self.reopenTime = reopenTime
        _open = State(initialValue: isOpen)
        _msg = State(initialValue: closeMessage)
        _reopen = State(initialValue: reopenTime)
    }

    var body: some View {
        GlassCard(borderAlpha: 0.25, glowAlpha: 0.12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                    Toggle("", isOn: $open).labelsHidden().tint(Tech.cyan)
                    Text(open ? "开启" : "关闭").font(.system(size: 13)).foregroundColor(Tech.cyan)
                        .frame(width: 30, alignment: .leading)
                }
                if !open {
                    LabeledField(label: "关闭提示语", text: $msg)
                    LabeledField(label: "预计恢复时间", text: $reopen)
                }
                Button("保存") {
                    Task {
                        do {
                            try await APIClient.shared.siteStatus(SiteStatusReq(
                                platform: platform, isOpen: open ? 1 : 0,
                                closeMessage: msg,
                                expectedReopenTime: reopen.isEmpty ? nil : reopen))
                            toast = "\(title) 保存成功"
                        } catch { toast = error.localizedDescription }
                    }
                }
                .buttonStyle(TechButtonStyle(compact: true))
            }
        }
        .toastOverlay(toast)
    }
}

// MARK: - Tab 4：用户设置

private struct UserSettingsTab: View {
    let settings: [String: Any?]
    @State private var allowRegister = true
    @State private var allowRecharge = true
    @State private var singleDevice = false
    @State private var tokenDays = ""
    @State private var emailDomains = ""
    @State private var pwdLen = ""
    @State private var failLimit = ""
    @State private var toast: String?

    init(settings: [String: Any?]) {
        self.settings = settings
        _allowRegister = State(initialValue: settings.settingBool("allow_register"))
        _allowRecharge = State(initialValue: settings.settingBool("allow_point_recharge"))
        _singleDevice = State(initialValue: settings.settingBool("single_device_login", false))
        _tokenDays = State(initialValue: String(settings.settingInt("token_expire_days", 90)))
        _emailDomains = State(initialValue: settings.settingStr("allowed_email_domains"))
        _pwdLen = State(initialValue: String(settings.settingInt("password_min_length", 6)))
        _failLimit = State(initialValue: String(settings.settingInt("login_fail_limit", 5)))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SwitchRow(label: "允许用户注册", checked: $allowRegister)
                SwitchRow(label: "允许用户点数充值", checked: $allowRecharge)
                SwitchRow(label: "单设备登录（新设备登录会使旧设备掉线）", checked: $singleDevice)
                FieldWithHint(label: "Token有效期(天)", hint: "登录后Token的有效天数，超出后需重新登录，默认90天", keyboard: .numberPad, text: $tokenDays)
                FieldWithHint(label: "允许注册的邮箱后缀", hint: "多个后缀用英文逗号分隔（如 qq.com,163.com），不填则允许所有邮箱", text: $emailDomains)
                FieldWithHint(label: "密码最小长度", keyboard: .numberPad, text: $pwdLen)
                FieldWithHint(label: "登录失败次数限制（0表示无限制）", keyboard: .numberPad, text: $failLimit)
                Button("保存用户设置") {
                    Task {
                        do {
                            try await APIClient.shared.settingsSave([
                                "allow_register": allowRegister ? "1" : "0",
                                "allow_point_recharge": allowRecharge ? "1" : "0",
                                "single_device_login": singleDevice ? "1" : "0",
                                "token_expire_days": tokenDays,
                                "allowed_email_domains": emailDomains,
                                "password_min_length": pwdLen,
                                "login_fail_limit": failLimit])
                            toast = "用户设置保存成功"
                        } catch { toast = error.localizedDescription }
                    }
                }
                .buttonStyle(TechButtonStyle()).padding(.top, 6)
            }
            .padding(16)
        }
        .toastOverlay(toast)
    }
}

// MARK: - Tab 5：点数设置

private struct PointsSettingsTab: View {
    let settings: [String: Any?]
    @State private var bonus = ""
    @State private var signPoints = ""
    @State private var rate = ""
    @State private var inviteInviter = ""
    @State private var inviteNewuser = ""
    @State private var inviteLandingUrl = ""
    @State private var toast: String?

    init(settings: [String: Any?]) {
        self.settings = settings
        _bonus = State(initialValue: String(settings.settingInt("new_user_bonus", 30)))
        _signPoints = State(initialValue: String(settings.settingInt("daily_sign_points", 10)))
        _rate = State(initialValue: settings.settingStr("points_exchange_rate").ifBlank("100"))
        _inviteInviter = State(initialValue: String(settings.settingInt("invite_reward_inviter", 0)))
        _inviteNewuser = State(initialValue: String(settings.settingInt("invite_reward_newuser", 0)))
        _inviteLandingUrl = State(initialValue: settings.settingStr("invite_landing_url"))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                FieldWithHint(label: "新用户注册赠送点数", keyboard: .numberPad, text: $bonus)
                FieldWithHint(label: "每日签到奖励点数", keyboard: .numberPad, text: $signPoints)
                FieldWithHint(label: "点数兑换比例", hint: "1元等于多少点数", text: $rate)
                FieldWithHint(label: "邀请人奖励点数", hint: "每成功邀请一位新用户，邀请人获得的点数", keyboard: .numberPad, text: $inviteInviter)
                FieldWithHint(label: "新用户奖励点数", hint: "通过邀请链接注册的新用户额外获得的点数", keyboard: .numberPad, text: $inviteNewuser)
                FieldWithHint(label: "邀请落地页链接", hint: "邀请活动的落地页地址", keyboard: .URL, text: $inviteLandingUrl)
                Button("保存点数设置") {
                    Task {
                        do {
                            try await APIClient.shared.settingsSave([
                                "new_user_bonus": bonus,
                                "daily_sign_points": signPoints,
                                "points_exchange_rate": rate,
                                "invite_reward_inviter": inviteInviter,
                                "invite_reward_newuser": inviteNewuser,
                                "invite_landing_url": inviteLandingUrl])
                            toast = "点数设置保存成功"
                        } catch { toast = error.localizedDescription }
                    }
                }
                .buttonStyle(TechButtonStyle()).padding(.top, 6)
            }
            .padding(16)
        }
        .toastOverlay(toast)
    }
}

// MARK: - Tab 6：接口限流设置

// key 带 rate_limit_ 前缀（对齐 Vue/后端，2026-10-22 起旧无前缀 key 不再生效）
private let rateLimitDefaults: [(String, Int)] = [
    ("rate_limit_refresh_max", 80), ("rate_limit_refresh_window", 60),
    ("rate_limit_batch_refresh_max", 3000), ("rate_limit_batch_refresh_window", 86400),
    ("rate_limit_query_max", 1000), ("rate_limit_query_window", 86400),
    ("rate_limit_weight_query_max", 100), ("rate_limit_weight_query_window", 86400),
    ("rate_limit_public_query_max", 80), ("rate_limit_public_query_window", 60),
    ("rate_limit_api_query_max", 3000), ("rate_limit_api_query_window", 86400)
]

private struct RateLimitTab: View {
    let settings: [String: Any?]
    @State private var values: [String: String] = [:]
    @State private var toast: String?

    private let groups: [(String, [(String, String)])] = [
        ("单次数据刷新 refresh", [("rate_limit_refresh_max", "最大请求数（默认80）"), ("rate_limit_refresh_window", "时间窗口秒（默认60）")]),
        ("批量数据刷新 batch_refresh", [("rate_limit_batch_refresh_max", "最大请求数（默认3000）"), ("rate_limit_batch_refresh_window", "时间窗口秒（默认86400）")]),
        ("批量查询 query", [("rate_limit_query_max", "最大请求数（默认1000）"), ("rate_limit_query_window", "时间窗口秒（默认86400）")]),
        ("权重查询 weight_query（仅非VIP）", [("rate_limit_weight_query_max", "最大请求数（默认100）"), ("rate_limit_weight_query_window", "时间窗口秒（默认86400）")]),
        ("公开查询/API public_query", [("rate_limit_public_query_max", "最大请求数（默认80）"), ("rate_limit_public_query_window", "时间窗口秒（默认60）")]),
        ("统计查询/API对接 api_query", [("rate_limit_api_query_max", "最大请求数（默认3000）"), ("rate_limit_api_query_window", "时间窗口秒（默认86400）")])
    ]

    init(settings: [String: Any?]) {
        self.settings = settings
        var initial: [String: String] = [:]
        for (k, def) in rateLimitDefaults { initial[k] = String(settings.settingInt(k, def)) }
        _values = State(initialValue: initial)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("配置各接口的请求频率限制，修改后立即生效。所有时间窗口单位为秒。")
                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.45))
                ForEach(groups, id: \.0) { group in
                    GlassCard(borderAlpha: 0.25, glowAlpha: 0.12) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(group.0).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                            ForEach(group.1, id: \.0) { field in
                                LabeledField(label: field.1, text: binding(field.0), keyboard: .numberPad)
                            }
                        }
                    }
                }
                HStack(spacing: 12) {
                    Button("保存限流设置") {
                        Task {
                            do {
                                var map: [String: String] = [:]
                                for (k, def) in rateLimitDefaults {
                                    let v = (values[k] ?? "").trimmingCharacters(in: .whitespaces)
                                    map[k] = v.isEmpty ? String(def) : v
                                }
                                try await APIClient.shared.settingsSave(map)
                                toast = "接口限流设置保存成功"
                            } catch { toast = error.localizedDescription }
                        }
                    }
                    .buttonStyle(TechButtonStyle())
                    Button("恢复默认") {
                        for (k, def) in rateLimitDefaults { values[k] = String(def) }
                        toast = "已恢复默认值，请点击保存生效"
                    }
                    .buttonStyle(TechButtonStyle(compact: true))
                }
                .padding(.top, 4)
            }
            .padding(16)
        }
        .toastOverlay(toast)
    }

    private func binding(_ key: String) -> Binding<String> {
        Binding(get: { values[key] ?? "" }, set: { values[key] = $0 })
    }
}

// MARK: - Tab 2/3：小程序 KV 设置（微信 / 支付宝，对齐 Android 新增/编辑/删除）

struct KeyValueSection: View {
    let load: () async throws -> [KeyValueSetting]
    let save: (SettingUpdateReq) async throws -> Void
    let delete: (SettingDeleteReq) async throws -> Void
    var announcementEnabled = false   // 公告配置（工作/休班时段+文案 JSON）特殊编辑
    var flowCardAdEnabled = false     // 流量卡广告（status 开关 + title/image/link）特殊编辑

    @State private var items: [KeyValueSetting] = []
    @State private var loading = false
    @State private var loadedOnce = false
    @State private var adding = false
    @State private var newKey = ""
    @State private var newValue = ""
    @State private var toast: String?

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button("新增配置") { newKey = ""; newValue = ""; adding = true }
                    .buttonStyle(TechButtonStyle(compact: true))
                Text("点击「编辑」修改值后保存").font(.system(size: 11)).foregroundColor(.white.opacity(0.4))
                Spacer()
            }
            .padding(.horizontal, 16)

            if loading, !loadedOnce { LoadingBox() }
            else if items.isEmpty {
                Text("暂无配置").font(.system(size: 13)).foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity).padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(items) { s in
                            if announcementEnabled, s.settingKey == "announcement" {
                                AnnouncementCard(item: s,
                                                 onSave: { json in run { try await save(SettingUpdateReq(id: s.id, settingKey: s.settingKey, settingValue: json, description: s.description)) } },
                                                 onDelete: { run { try await delete(SettingDeleteReq(id: s.id, settingKey: s.settingKey)) } })
                            } else if flowCardAdEnabled, s.settingKey == "flow_card_ad" {
                                FlowCardAdCard(item: s,
                                               onSave: { value, status in run { try await save(SettingUpdateReq(id: s.id, settingKey: s.settingKey, settingValue: value, description: s.description, status: status)) } },
                                               onDelete: { run { try await delete(SettingDeleteReq(id: s.id, settingKey: s.settingKey)) } })
                            } else {
                                KeyValueRow(item: s,
                                            onSave: { v in run { try await save(SettingUpdateReq(id: s.id, settingKey: s.settingKey, settingValue: v, description: s.description)) } },
                                            onDelete: { run { try await delete(SettingDeleteReq(id: s.id, settingKey: s.settingKey)) } })
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 20)
                }
            }
        }
        .task { await reload() }
        .sheet(isPresented: $adding) { addSheet }
        .toastOverlay(toast)
    }

    private func run(_ cmd: @escaping () async throws -> Void) {
        Task {
            do { try await cmd(); await reload() }
            catch { toast = error.localizedDescription }
        }
    }

    private func reload() async {
        loading = true
        do { items = try await load() }
        catch { toast = error.localizedDescription }
        loading = false
        loadedOnce = true
    }

    private var addSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                LabeledField(label: "键(key)", text: $newKey)
                LabeledField(label: "值(value)", text: $newValue)
                Spacer()
            }
            .padding(20)
            .background(Tech.bgBottom.ignoresSafeArea())
            .navigationTitle("新增配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { adding = false }.foregroundColor(Tech.cyan)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        let k = newKey.trimmingCharacters(in: .whitespaces)
                        guard !k.isEmpty else { toast = "请输入设置键"; return }
                        run { try await save(SettingUpdateReq(id: nil, settingKey: k, settingValue: newValue, description: nil)) }
                        adding = false
                    }
                    .foregroundColor(Tech.cyan)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 键值行

struct KeyValueRow: View {
    let item: KeyValueSetting
    var onSave: (String) -> Void
    var onDelete: () -> Void
    @State private var value = ""
    @State private var editing = false

    var body: some View {
        GlassCard(accent: Tech.cyan, borderAlpha: 0.2, glowAlpha: 0.1) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.settingKey ?? "-").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                        if let desc = item.description, !desc.isEmpty {
                            Text(desc).font(.system(size: 11)).foregroundColor(.white.opacity(0.4))
                        }
                    }
                    Spacer()
                    Button(editing ? "收起" : "编辑") { editing.toggle() }
                        .font(.system(size: 13)).foregroundColor(Tech.cyan)
                    Button("保存") { onSave(value) }
                        .font(.system(size: 13)).foregroundColor(Tech.cyan)
                    Button("删除") { onDelete() }
                        .font(.system(size: 13)).foregroundColor(Tech.red)
                }
                if editing {
                    LabeledField(label: "值(value)", text: $value)
                } else {
                    Text(item.settingValue ?? "-")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(2)
                }
            }
        }
        .onAppear { value = item.settingValue ?? "" }
    }
}

// MARK: - 公告配置（工作/休班时段+文案 → announcement JSON，对齐 Vue serializeAnnouncementJson）

private struct AnnouncementCard: View {
    let item: KeyValueSetting
    var onSave: (String) -> Void
    var onDelete: () -> Void

    @State private var workMorningStart = "08:00"
    @State private var workMorningEnd = "12:00"
    @State private var workAfternoonStart = "14:00"
    @State private var workAfternoonEnd = "18:00"
    @State private var workText = ""
    @State private var offText = ""
    @State private var expanded = false

    var body: some View {
        GlassCard(accent: Tech.cyan, borderAlpha: 0.2, glowAlpha: 0.1) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("announcement（公告配置）").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                        Text("按工作/休班时段自动切换前端公告").font(.system(size: 11)).foregroundColor(.white.opacity(0.4))
                    }
                    Spacer()
                    Button(expanded ? "收起" : "编辑") { expanded.toggle() }
                        .font(.system(size: 13)).foregroundColor(Tech.cyan)
                    Button("保存") { saveJson() }
                        .font(.system(size: 13)).foregroundColor(Tech.cyan)
                    Button("删除") { onDelete() }
                        .font(.system(size: 13)).foregroundColor(Tech.red)
                }
                if expanded {
                    Text("工作时段（24小时制 HH:mm）").font(.system(size: 12)).foregroundColor(.white.opacity(0.5))
                    HStack(spacing: 8) {
                        LabeledField(label: "上午开始", text: $workMorningStart)
                        LabeledField(label: "上午结束", text: $workMorningEnd)
                    }
                    HStack(spacing: 8) {
                        LabeledField(label: "下午开始", text: $workAfternoonStart)
                        LabeledField(label: "下午结束", text: $workAfternoonEnd)
                    }
                    LabeledField(label: "工作时段公告", text: $workText)
                    LabeledField(label: "休班时段公告", text: $offText)
                } else {
                    Text(item.settingValue ?? "-")
                        .font(.system(size: 12)).foregroundColor(.white.opacity(0.55)).lineLimit(2)
                }
            }
        }
        .onAppear { parseJson() }
    }

    private func parseJson() {
        guard let data = (item.settingValue ?? "").data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        workMorningStart = obj["workMorningStart"] as? String ?? "08:00"
        workMorningEnd = obj["workMorningEnd"] as? String ?? "12:00"
        workAfternoonStart = obj["workAfternoonStart"] as? String ?? "14:00"
        workAfternoonEnd = obj["workAfternoonEnd"] as? String ?? "18:00"
        workText = obj["workAnnouncement"] as? String ?? ""
        offText = obj["offWorkAnnouncement"] as? String ?? ""
    }

    private func saveJson() {
        let obj: [String: String] = [
            "workMorningStart": workMorningStart, "workMorningEnd": workMorningEnd,
            "workAfternoonStart": workAfternoonStart, "workAfternoonEnd": workAfternoonEnd,
            "workAnnouncement": workText, "offWorkAnnouncement": offText]
        guard let data = try? JSONSerialization.data(withJSONObject: obj, options: []),
              let json = String(data: data, encoding: .utf8) else { return }
        onSave(json)
    }
}

// MARK: - 流量卡广告（web 端 flow_card_ad：status 总开关 + value JSON{title,image,link}）

private struct FlowCardAdCard: View {
    let item: KeyValueSetting
    var onSave: (String, Int) -> Void
    var onDelete: () -> Void

    @State private var enabled = false
    @State private var title = ""
    @State private var image = ""
    @State private var link = ""

    var body: some View {
        GlassCard(accent: Tech.cyan, borderAlpha: 0.2, glowAlpha: 0.1) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("flow_card_ad（流量卡广告）").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                        Text("Web 端流量卡推广位配置").font(.system(size: 11)).foregroundColor(.white.opacity(0.4))
                    }
                    Spacer()
                    Toggle("", isOn: $enabled).labelsHidden().tint(Tech.cyan).frame(width: 44)
                    Button("保存") { saveJson() }
                        .font(.system(size: 13)).foregroundColor(Tech.cyan)
                    Button("删除") { onDelete() }
                        .font(.system(size: 13)).foregroundColor(Tech.red)
                }
                LabeledField(label: "广告标题", text: $title)
                LabeledField(label: "广告图片URL", text: $image)
                LabeledField(label: "跳转链接", text: $link)
            }
        }
        .onAppear { parseJson() }
    }

    private func parseJson() {
        enabled = item.status == 1
        guard let data = (item.settingValue ?? "").data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        title = obj["title"] as? String ?? ""
        image = obj["image"] as? String ?? ""
        link = obj["link"] as? String ?? ""
    }

    private func saveJson() {
        let obj: [String: String] = ["title": title, "image": image, "link": link]
        guard let data = try? JSONSerialization.data(withJSONObject: obj, options: []),
              let json = String(data: data, encoding: .utf8) else { return }
        onSave(json, enabled ? 1 : 0)
    }
}

// MARK: - 安卓/iOS 端更新设置（app_update_* / ios_app_update_*，走统一 settings/save）

private struct AppUpdateTab: View {
    let settings: [String: Any?]
    let prefix: String
    let title: String
    @State private var enabled = false
    @State private var versionCode = ""
    @State private var versionName = ""
    @State private var downloadUrl = ""
    @State private var updateLog = ""
    @State private var force = false
    @State private var toast: String?

    init(settings: [String: Any?], prefix: String, title: String) {
        self.settings = settings
        self.prefix = prefix
        self.title = title
        _enabled = State(initialValue: settings.settingBool("\(prefix)_enabled", false))
        _versionCode = State(initialValue: settings.settingStr("\(prefix)_version_code"))
        _versionName = State(initialValue: settings.settingStr("\(prefix)_version_name"))
        _downloadUrl = State(initialValue: settings.settingStr("\(prefix)_download_url"))
        _updateLog = State(initialValue: settings.settingStr("\(prefix)_update_log"))
        _force = State(initialValue: settings.settingBool("\(prefix)_force", false))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SwitchRow(label: "启用更新检查", checked: $enabled)
                FieldWithHint(label: "版本号(version code)", hint: "整数，客户端版本号大于此值时提示更新", keyboard: .numberPad, text: $versionCode)
                FieldWithHint(label: "版本名称(version name)", hint: "展示用版本名，如 1.2.0", text: $versionName)
                FieldWithHint(label: "下载链接", hint: "安装包/APK 下载地址", keyboard: .URL, text: $downloadUrl)
                FieldWithHint(label: "更新日志", hint: "本次更新内容说明", text: $updateLog)
                SwitchRow(label: "强制更新（不更新不可用）", checked: $force)
                Button("保存\(title)") {
                    Task {
                        do {
                            try await APIClient.shared.settingsSave([
                                "\(prefix)_enabled": enabled ? "1" : "0",
                                "\(prefix)_version_code": versionCode,
                                "\(prefix)_version_name": versionName,
                                "\(prefix)_download_url": downloadUrl,
                                "\(prefix)_update_log": updateLog,
                                "\(prefix)_force": force ? "1" : "0"])
                            toast = "\(title)保存成功"
                        } catch { toast = error.localizedDescription }
                    }
                }
                .buttonStyle(TechButtonStyle()).padding(.top, 6)
            }
            .padding(16)
        }
        .toastOverlay(toast)
    }
}

// MARK: - Tab 10：代理设置（2026-11-06 快代理动态IP/熔断直连/告警邮件，对齐 Vue 端 SystemSettings.vue）
// 对齐后端 admin/DouyinProxySettings.php（读/存/测/重置），独立接口加载不依赖 settings map

private struct ProxySettingsTab: View {
    // ── 加载态 ──
    @State private var loading = true                    // 首次加载中
    @State private var loadError: String?                // 加载失败文案（可重试）
    // ── 表单字段（与后端 douyin_proxy_* 9键一一对应） ──
    @State private var mode = "api"                      // 代理模式：off=直连 api=快代理API动态 static=静态代理
    @State private var apiUrl = ""                       // 快代理提取IP的API链接（返回 纯IP 或 IP:端口）
    @State private var user = ""                         // 代理认证账号
    @State private var pass = ""                         // 代理认证密码
    @State private var port = ""                         // 代理端口（API返回 IP:端口 时以API为准，此端口仅兜底）
    @State private var staticProxy = ""                  // 静态代理地址（user:pass@ip:port）
    @State private var ttl = "300"                       // IP缓存秒数（到期自动拉新IP）
    @State private var alertEmail = ""                   // 故障告警收件邮箱
    @State private var alertOn = true                    // 告警邮件开关
    // ── 运行状态与操作态 ──
    @State private var status: DouyinProxyStatus?        // 运行状态快照（后端 DouyinProxy::getStatus）
    @State private var saving = false                    // 保存请求进行中
    @State private var testing = false                   // 链路测试进行中
    @State private var resetting = false                 // 重置熔断进行中
    @State private var testResult: DouyinProxyTestResult? // 最近一次链路测试结果
    @State private var toast: String?                    // 底部轻提示文案

    var body: some View {
        ScrollView {                                     // 整页可滚动
            VStack(alignment: .leading, spacing: 12) {   // 纵向卡片流
                if loading {                             // 首次加载态
                    LoadingBox()
                } else if let loadError {                // 加载失败态（点重试）
                    ErrorBox(message: loadError) { load() }
                } else {
                    // ── 代理模式卡 ──
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("代理模式")                                  // 卡片标题
                                .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                            Text("快代理API动态=默认走代理，故障自动熔断直连并发告警邮件；静态代理=固定地址；直连=不走代理")   // 模式说明
                                .font(.system(size: 11)).foregroundColor(.white.opacity(0.5))
                            HStack(spacing: 8) {                             // 模式三选一
                                modeChip("直连", "off")                      // off
                                modeChip("快代理API动态", "api")             // api
                                modeChip("静态代理", "static")               // static
                            }
                        }
                    }
                    // ── 配置卡（直连模式无配置项） ──
                    if mode != "off" {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                if mode == "api" {                           // 快代理 API 动态专属字段
                                    FieldWithHint(label: "API链接（提取IP）", hint: "返回 纯IP 或 IP:端口，带端口时以API为准", keyboard: .URL, text: $apiUrl)
                                    LabeledField(label: "代理账号", text: $user)                        // 账号输入
                                    LabeledField(label: "代理密码", text: $pass, secure: true)          // 密码掩码输入
                                    FieldWithHint(label: "代理端口", hint: "API带端口时优先用API的，此端口仅兜底", keyboard: .numberPad, text: $port)
                                    FieldWithHint(label: "IP缓存秒数", hint: "到期自动调API拉新IP，默认300", keyboard: .numberPad, text: $ttl)
                                } else {                                     // 静态代理专属字段
                                    FieldWithHint(label: "静态代理地址", hint: "格式 user:pass@ip:port 或 ip:port", text: $staticProxy)
                                }
                                FieldWithHint(label: "故障告警收件邮箱", hint: "熔断/恢复时自动发邮件提醒", keyboard: .emailAddress, text: $alertEmail)   // 告警邮箱
                                SwitchRow(label: "故障/恢复自动发邮件提醒", checked: $alertOn)           // 告警开关行
                            }
                        }
                    }
                    // ── 操作按钮行：保存 / 测试链路 / 重置熔断 ──
                    HStack(spacing: 10) {
                        Button { save() } label: { Text(saving ? "保存中…" : "保存配置") }                        // 主操作
                            .buttonStyle(TechButtonStyle(enabled: !saving))
                        Button { test() } label: { Text(testing ? "测试中…" : "测试链路") }                      // 直连模式禁用
                            .buttonStyle(TechButtonStyle(enabled: !testing && mode != "off"))
                        Button { reset() } label: { Text(resetting ? "重置中…" : "重置熔断") }                   // 恢复用
                            .buttonStyle(TechButtonStyle(enabled: !resetting))
                    }
                    // ── 测试结果卡（点过测试才显示） ──
                    if let r = testResult {
                        GlassCard(accent: r.ok == true ? Tech.green : Tech.red) {   // 边框随结果变色
                            VStack(alignment: .leading, spacing: 4) {
                                Text(r.ok == true ? "链路正常：代理出口IP \(r.echoIp ?? "-")" : "链路异常：\(r.msg ?? "未知错误")")   // 结论行
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(r.ok == true ? Tech.green : Tech.red)          // 绿=通 红=异常
                                if mode == "api", let ip = r.ip, !ip.isEmpty {  // API 模式附带显示提取到的 IP
                                    Text("快代理API返回：\(ip)")
                                        .font(.system(size: 12)).foregroundColor(.white.opacity(0.6))
                                }
                            }
                        }
                    }
                    // ── 运行状态卡（对齐 Vue 端运行状态网格） ──
                    if let s = status {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("运行状态")                                 // 卡片标题
                                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                                statusRow("当前缓存IP", s.cachedIp ?? "")        // TTL 内生效的代理地址
                                statusRow("备份IP（24h兜底）", s.lastIp ?? "")   // API 拉取失败时的兜底
                                statusRow("连续失败计数", "\(s.failCnt ?? 0) / 3") // 满 3 触发熔断
                                statusRow("熔断状态", s.breaking == true ? "熔断直连中（剩 \(s.breakLeft ?? 0) 秒）" : "正常")   // 熔断器状态
                                statusRow("故障告警中", s.alerting == true ? "是（恢复后将发邮件）" : "否")   // 是否处于告警周期
                                statusRow("上次告警时间", alertTimeText(s.lastAlertTime))    // 秒级时间戳转可读
                                statusRow("最近请求链路", s.lastUsed ?? "")      // 排查业务实际走直连还是代理
                            }
                        }
                    }
                }
            }
            .padding(16)                                         // 页边距
        }
        .toastOverlay(toast)                                     // 底部轻提示悬浮层
        .task { if loading { load() } }                          // 进入 Tab 自动加载一次
    }

    // 模式胶囊按钮（选中高亮渐变，对齐顶部标签条风格）
    private func modeChip(_ title: String, _ value: String) -> some View {
        Button { mode = value } label: {                         // 点击切换模式
            Text(title)
                .font(.system(size: 12, weight: mode == value ? .semibold : .regular))   // 选中加粗
                .foregroundColor(mode == value ? .black : .white.opacity(0.75))          // 选中黑字（渐变底上）
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(mode == value ? AnyShapeStyle(Tech.accentGradient) : AnyShapeStyle(Color.white.opacity(0.08))))   // 选中渐变底
                .overlay(Capsule().strokeBorder(mode == value ? Color.clear : Tech.cyan.opacity(0.25), lineWidth: 1))                        // 未选中描边
        }
    }

    // 状态行辅助：左灰右亮两端对齐
    private func statusRow(_ key: String, _ value: String) -> some View {
        HStack {                                                 // 水平排布
            Text(key).font(.system(size: 12)).foregroundColor(.white.opacity(0.55))   // 左侧键名（弱化）
            Spacer()                                             // 弹性空隙
            Text(value.isEmpty ? "-" : value).font(.system(size: 12)).foregroundColor(.white.opacity(0.9))   // 右侧值（空显示 -）
        }
    }

    // 秒级时间戳 → yyyy-MM-dd HH:mm:ss
    private func alertTimeText(_ ts: Int?) -> String {
        guard let ts, ts > 0 else { return "-" }                 // 无告警记录显示 -
        let f = DateFormatter()                                  // 格式化器
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"                     // 目标格式
        return f.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))   // 秒 → Date → 字符串
    }

    // 加载配置与运行状态
    private func load() {
        Task {
            do {
                let d = try await APIClient.shared.douyinProxyGet()   // GET 配置+状态
                let c = d.config ?? [:]                               // 配置键值对（可能为空）
                let m = c["douyin_proxy_mode"] ?? "api"               // 回填模式（默认 api）
                mode = m.isEmpty ? "api" : m                          // 空值兜底为 api
                apiUrl = c["douyin_proxy_api_url"] ?? ""              // 回填 API 链接
                user = c["douyin_proxy_user"] ?? ""                   // 回填账号
                pass = c["douyin_proxy_pass"] ?? ""                   // 回填密码
                port = c["douyin_proxy_port"] ?? ""                   // 回填端口
                staticProxy = c["douyin_proxy_static"] ?? ""          // 回填静态代理
                let t = c["douyin_proxy_ttl"] ?? "300"                // 回填 TTL（默认 300）
                ttl = t.isEmpty ? "300" : t                           // 空值兜底
                alertEmail = c["douyin_proxy_alert_email"] ?? ""      // 回填告警邮箱
                alertOn = (c["douyin_proxy_alert_on"] ?? "1") != "0"  // 回填写告警开关（"1"为开）
                status = d.status                                     // 记录运行状态快照
                loadError = nil                                       // 清除错误
            } catch { loadError = error.localizedDescription }        // 失败记录错误（展示重试态）
            loading = false                                          // 关闭加载态
        }
    }

    // 保存配置：组装 9 键扁平 map（后端 saveConfig 白名单校验后 upsert 进 system_settings）
    private func save() {
        saving = true                                               // 打开保存中态
        Task {
            do {
                try await APIClient.shared.douyinProxySave([
                    "douyin_proxy_mode": mode,                       // 模式
                    "douyin_proxy_api_url": apiUrl.trimmingCharacters(in: .whitespaces),        // API 链接
                    "douyin_proxy_user": user.trimmingCharacters(in: .whitespaces),             // 账号
                    "douyin_proxy_pass": pass,                       // 密码（不 trim，防误删字符）
                    "douyin_proxy_port": port.trimmingCharacters(in: .whitespaces),             // 端口
                    "douyin_proxy_static": staticProxy.trimmingCharacters(in: .whitespaces),    // 静态代理
                    "douyin_proxy_ttl": ttl.trimmingCharacters(in: .whitespaces).isEmpty ? "300" : ttl.trimmingCharacters(in: .whitespaces),   // TTL（空则后端默认 300）
                    "douyin_proxy_alert_email": alertEmail.trimmingCharacters(in: .whitespaces),// 告警邮箱
                    "douyin_proxy_alert_on": alertOn ? "1" : "0"     // 告警开关（"1"开）
                ])
                toast = "代理配置保存成功"                             // 成功提示
                load()                                              // 重载最新配置+状态
            } catch { toast = error.localizedDescription }           // 失败提示
            saving = false                                          // 关闭保存中态
        }
    }

    // 测试链路：拉IP → 经代理访问回显接口 → 显示出口IP
    private func test() {
        testing = true                                              // 打开测试中态
        testResult = nil                                            // 清掉上次结果
        Task {
            do { testResult = try await APIClient.shared.douyinProxyTest() }   // 记录结果供 UI 展示
            catch { toast = error.localizedDescription }            // 失败提示
            testing = false                                         // 关闭测试中态
        }
    }

    // 重置熔断：清失败计数/熔断标记/IP缓存（改完配置后点一下，立刻生效）
    private func reset() {
        resetting = true                                            // 打开重置中态
        Task {
            do {
                try await APIClient.shared.douyinProxyReset()       // POST 重置
                toast = "已重置熔断与缓存"                            // 成功提示
                load()                                              // 重载状态
            } catch { toast = error.localizedDescription }           // 失败提示
            resetting = false                                       // 关闭重置中态
        }
    }
}

// MARK: - Tab 11：取数引擎（2026-11-12 对齐 Vue 端 douyinDetail 标签页）

private struct DouyinDetailEngineTab: View {
    // ── 加载态 ──
    @State private var loading = true                    // 首次加载中
    @State private var loadError: String?                // 加载失败文案（可重试）
    // ── 表单字段（与后端 dy_* 7键一一对应） ──
    @State private var channel = "web"                   // 获取端：web=Web端引擎体系 mobile=手机端接口
    @State private var mobileFallback = true             // 手机端失败自动降级 Web 端体系：1/0
    @State private var signMode = "nosign"               // 手机端签名模式：nosign=无签放行 pure=纯算六头
    @State private var engine = "local"                  // 引擎模式：local=本地纯算 cdp_sign=CDP仅取签 cdp_proxy=CDP全代理
    @State private var cdpBase = ""                      // CDP API 地址（DouyinDetailService.exe 监听地址）
    @State private var cdpTimeout = "60"                 // CDP API 超时秒（建议 30~60）
    @State private var cdpFallback = true                // CDP 失败自动降级本地纯算：1/0
    // ── 实际生效（后端计算，CDP 地址缺失时自动回落 local，与所选可能不同） ──
    @State private var effectiveEngine = "local"
    @State private var effectiveChannel = "web"
    // ── 操作态 ──
    @State private var saving = false                    // 保存请求进行中
    @State private var testing = false                   // 测试请求进行中
    @State private var testResult: (ok: Bool, title: String, detail: String)?   // 测试结果（对齐 Vue {ok,title,detail}）
    @State private var toast: String?                    // 底部轻提示文案

    // 选项表（文案与 Vue dyChannelOptions/dySignModeOptions/dyEngineOptions 逐字一致）
    private let channelOptions: [(value: String, label: String, desc: String)] = [
        ("web", "Web端引擎体系（默认）", "douyin.com web 接口，走下方引擎模式（本地纯算 / CDP 取签 / CDP 全代理）"),
        ("mobile", "手机端接口", "出口由「代理设置」控制，失败可降级 Web 端"),
    ]
    private let signOptions: [(value: String, label: String, desc: String)] = [
        ("nosign", "无签模式（默认）", "不带任何签名头直取 aggr6 接口（服务端无签放行），最省资源"),
        ("pure", "纯算签名", "gorgon/helios/medusa 真算 + ladon/argus 伪头（纯算六头）"),
    ]
    private let engineOptions: [(value: String, label: String, desc: String)] = [
        ("local", "本地纯算（默认）", "Node 算 a_bogus + PHP 算 secsdk，代理可控，无需额外服务"),
        ("cdp_sign", "CDP 仅取签（推荐）", "浏览器原生算签（抗风控最强），PHP 自己发请求保留代理/重试控制权，批量仍可 curl_multi 并行"),
        ("cdp_proxy", "CDP 全代理", "浏览器签好并请求完直接拿最终响应，单条约 1.2 秒串行，数据最鲜活"),
    ]

    private var isCdp: Bool { engine == "cdp_sign" || engine == "cdp_proxy" }   // CDP 引擎（决定专属表单项显隐）
    private var isMobile: Bool { channel == "mobile" }                          // 手机端获取通道

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if loading {                             // 首次加载态
                    LoadingBox()
                } else if let loadError {                // 加载失败态（点重试）
                    ErrorBox(message: loadError) { load() }
                } else {
                    // ── 获取端卡 ──
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("获取端")
                                .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                            Text(desc(channelOptions, channel))
                                .font(.system(size: 11)).foregroundColor(.white.opacity(0.5))
                            VStack(spacing: 6) {                         // 两行选项（文案较长，竖排）
                                ForEach(channelOptions, id: \.value) { opt in
                                    optionRow(opt, selected: channel) { channel = $0 }
                                }
                            }
                        }
                    }
                    // ── 手机端专属卡（失败降级 + 签名模式） ──
                    if isMobile {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                SwitchRow(label: "失败降级Web端", checked: $mobileFallback)   // 降级开关
                                Text("手机端取数失败时自动回退 Web 端引擎体系（业务不中断）")
                                    .font(.system(size: 11)).foregroundColor(.white.opacity(0.5))
                                Text("签名模式")
                                    .font(.system(size: 14, weight: .semibold)).foregroundColor(.white.opacity(0.9))
                                Text(desc(signOptions, signMode))
                                    .font(.system(size: 11)).foregroundColor(.white.opacity(0.5))
                                VStack(spacing: 6) {
                                    ForEach(signOptions, id: \.value) { opt in
                                        optionRow(opt, selected: signMode) { signMode = $0 }
                                    }
                                }
                            }
                        }
                    }
                    // ── 引擎模式卡（Web 端引擎体系；手机端直取不走引擎，但 Vue 端恒显示，保持一致） ──
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("引擎模式")
                                .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                            Text(desc(engineOptions, engine))
                                .font(.system(size: 11)).foregroundColor(.white.opacity(0.5))
                                .fixedSize(horizontal: false, vertical: true)
                            VStack(spacing: 6) {
                                ForEach(engineOptions, id: \.value) { opt in
                                    optionRow(opt, selected: engine) { engine = $0 }
                                }
                            }
                            if isCdp {                                   // CDP 引擎专属配置
                                FieldWithHint(label: "CDP API 地址", hint: "DouyinDetailService.exe 的监听地址（含端口，不带末尾斜杠）", keyboard: .URL, text: $cdpBase)
                                FieldWithHint(label: "API 超时(秒)", hint: "建议 30~60：Chrome 冷启动首次调用需 6 秒以上", keyboard: .numberPad, text: $cdpTimeout)
                                SwitchRow(label: "失败降级本地", checked: $cdpFallback)      // CDP 挂掉自动回退本地纯算
                                Text("CDP 取数失败时自动回退本地纯算（exe 挂掉不影响业务）")
                                    .font(.system(size: 11)).foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                    // ── 操作按钮行：保存 / 测试连接（CDP）/ 测试手机端通道（mobile） ──
                    HStack(spacing: 10) {
                        Button { save() } label: { Text(saving ? "保存中…" : "保存引擎设置") }
                            .buttonStyle(TechButtonStyle(enabled: !saving))
                        if isCdp {                                       // 仅 CDP 引擎显示
                            Button { test(.cdp) } label: { Text(testing ? "测试中…" : "测试连接") }
                                .buttonStyle(TechButtonStyle(enabled: !testing))
                        }
                        if isMobile {                                    // 仅手机端通道显示
                            Button { test(.mobile) } label: { Text(testing ? "测试中…" : "测试手机端通道") }
                                .buttonStyle(TechButtonStyle(enabled: !testing))
                        }
                    }
                    // ── 测试结果卡（点过测试才显示） ──
                    if let r = testResult {
                        GlassCard(accent: r.ok ? Tech.green : Tech.red) {   // 边框随结果变色
                            VStack(alignment: .leading, spacing: 4) {
                                Text(r.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(r.ok ? Tech.green : Tech.red)
                                    .fixedSize(horizontal: false, vertical: true)
                                if !r.detail.isEmpty {                   // 附带统计/链路详情
                                    Text(r.detail)
                                        .font(.system(size: 12)).foregroundColor(.white.opacity(0.6))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    // ── 实际生效卡（后端实时计算：配置未保存/CDP 地址缺失时会与所选不同） ──
                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("当前实际生效")
                                .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                            statusRow("获取端", effectiveChannel == "mobile" ? "手机端接口" : "Web端引擎体系")
                            statusRow("引擎", engineLabel(effectiveEngine))
                        }
                    }
                }
            }
            .padding(16)                                         // 页边距
        }
        .toastOverlay(toast)                                     // 底部轻提示悬浮层
        .task { if loading { load() } }                          // 进入 Tab 自动加载一次
    }

    // 选项行：单选卡（选中青色描边+圆点，下方灰色描述，对齐 Vue radio+form-tip）
    private func optionRow(_ opt: (value: String, label: String, desc: String),
                           selected: String, onChange: @escaping (String) -> Void) -> some View {
        let on = selected == opt.value                           // 是否选中
        return Button { onChange(opt.value) } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: on ? "checkmark.circle.fill" : "circle")     // 选中实心圆点
                        .font(.system(size: 13))
                        .foregroundColor(on ? Tech.cyan : .white.opacity(0.35))
                    Text(opt.label)
                        .font(.system(size: 13, weight: on ? .semibold : .regular))
                        .foregroundColor(on ? .white : .white.opacity(0.7))
                }
                Text(opt.desc)
                    .font(.system(size: 10.5)).foregroundColor(.white.opacity(0.4))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(on ? Tech.cyan.opacity(0.12) : Color.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(on ? Tech.cyan.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // 状态行辅助：左灰右亮两端对齐（与 ProxySettingsTab 一致）
    private func statusRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).font(.system(size: 12)).foregroundColor(.white.opacity(0.55))
            Spacer()
            Text(value.isEmpty ? "-" : value).font(.system(size: 12)).foregroundColor(.white.opacity(0.9))
        }
    }

    // 选项描述查找：当前选中项的 desc（找不到回退空串）
    private func desc(_ opts: [(value: String, label: String, desc: String)], _ value: String) -> String {
        opts.first { $0.value == value }?.desc ?? ""
    }

    // 引擎 value → 展示文案（实际生效行用，未知值原样显示）
    private func engineLabel(_ value: String) -> String {
        engineOptions.first { $0.value == value }?.label ?? value
    }

    // 加载配置与实际生效引擎
    private func load() {
        Task {
            do {
                let d = try await APIClient.shared.douyinDetailGet()   // GET 配置+实际生效
                let c = d.config ?? [:]                                // 配置键值对（可能为空）
                let e = c["dy_detail_engine"] ?? "local"               // 回填引擎（默认 local）
                engine = e.isEmpty ? "local" : e
                cdpBase = c["dy_cdp_api_base"] ?? ""                   // 回填 CDP 地址
                let t = c["dy_cdp_api_timeout"] ?? "60"                // 回填超时（默认 60）
                cdpTimeout = t.isEmpty ? "60" : t
                cdpFallback = (c["dy_cdp_fallback_local"] ?? "1") != "0"   // 回填降级开关（"1"为开）
                let ch = c["dy_detail_channel"] ?? "web"               // 回填获取端（默认 web）
                channel = ch.isEmpty ? "web" : ch
                mobileFallback = (c["dy_mobile_fallback_web"] ?? "1") != "0"
                let sm = c["dy_mobile_sign_mode"] ?? "nosign"          // 回填签名模式（默认 nosign）
                signMode = sm.isEmpty ? "nosign" : sm
                effectiveEngine = d.effectiveEngine ?? "local"         // 记录实际生效引擎
                effectiveChannel = d.effectiveChannel ?? "web"         // 记录实际生效获取端
                loadError = nil                                        // 清除错误
            } catch { loadError = error.localizedDescription }         // 失败记录错误（展示重试态）
            loading = false                                          // 关闭加载态
        }
    }

    // 测试目标（区分两个接口的展示逻辑，对齐 Vue testDouyinDetail/testMobileChannel）
    private enum TestTarget { case cdp, mobile }

    // 保存配置：组装 dy_* 7键扁平 map（后端白名单校验后 upsert 进 system_settings）
    private func save() {
        saving = true                                               // 打开保存中态
        Task {
            do {
                let timeout = min(max(Int(cdpTimeout.trimmingCharacters(in: .whitespaces)) ?? 60, 5), 300)   // 钳制 5~300 秒
                try await APIClient.shared.douyinDetailSave([
                    "dy_detail_channel": channel,                    // 获取端
                    "dy_mobile_fallback_web": mobileFallback ? "1" : "0",   // 手机端降级开关
                    "dy_mobile_sign_mode": signMode,                 // 手机端签名模式
                    "dy_detail_engine": engine,                      // 引擎模式
                    "dy_cdp_api_base": cdpBase.trimmingCharacters(in: .whitespaces),   // CDP 地址
                    "dy_cdp_api_timeout": String(timeout),           // CDP 超时秒
                    "dy_cdp_fallback_local": cdpFallback ? "1" : "0" // CDP 降级本地开关
                ])
                toast = "引擎设置保存成功"                             // 成功提示
                load()                                              // 重载最新配置+实际生效
            } catch { toast = error.localizedDescription }           // 失败提示
            saving = false                                          // 关闭保存中态
        }
    }

    // 测试：CDP 连接（/health 透传）或手机端通道（真实拉一条视频）
    private func test(_ target: TestTarget) {
        testing = true                                              // 打开测试中态
        testResult = nil                                            // 清掉上次结果
        Task {
            do {
                let r = try await target == .cdp
                    ? APIClient.shared.douyinDetailTest()
                    : APIClient.shared.douyinDetailTestMobile()     // 按目标调对应接口
                if target == .cdp {                                 // CDP：结论+Chrome 就绪+请求统计
                    let statText = (r.stats ?? [:]).isEmpty
                        ? ""
                        : (r.stats ?? [:]).map { "\($0.key)=\($0.value.value ?? "-")" }.joined(separator: "，")
                    testResult = (
                        true,
                        "CDP 连接正常" + (r.chromeReady == false ? "（首次调用会自动拉起 Chrome，稍等 6 秒左右）" : ""),
                        statText.isEmpty ? "" : "请求统计：\(statText)"
                    )
                } else {                                            // 手机端：结论+视频/赞/耗时/链路
                    var parts: [String] = []
                    if let id = r.awemeId, !id.isEmpty { parts.append("测试视频=\(id)") }
                    if let dg = r.diggCount { parts.append("赞=\(dg)") }
                    if let ms = r.costMs { parts.append("耗时=\(ms)ms") }
                    if let lu = r.lastUsed, !lu.isEmpty { parts.append("链路=\(lu)") }
                    testResult = (true, "手机端通道正常", parts.joined(separator: "，"))
                }
            } catch {                                               // 接口报错：红字展示原因
                testResult = (false, "测试失败：\(error.localizedDescription)", "")
            }
            testing = false                                         // 关闭测试中态
        }
    }
}
