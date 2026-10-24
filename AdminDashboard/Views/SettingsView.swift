import SwiftUI

// MARK: - 系统设置（对齐 Android SettingsScreen 六标签页）

struct SettingsView: View {
    @State private var tab = 0
    private let tabs = ["基础设置", "微信小程序", "支付宝小程序", "Web端设置", "用户设置", "点数设置", "接口限流", "安卓更新", "iOS更新"]
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

private struct SwitchRow: View {
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
                FieldWithHint(label: "邀请落地页链接", hint: "邀请活动的落地页地址", text: $inviteLandingUrl, keyboard: .URL)
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
                FieldWithHint(label: "下载链接", hint: "安装包/APK 下载地址", text: $downloadUrl, keyboard: .URL)
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
