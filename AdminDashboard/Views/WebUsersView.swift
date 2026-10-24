import SwiftUI

enum WebUserAction: String, Identifiable {
    case superVip, vipTime, balance, pwd, close, delete
    var id: String { rawValue }

    var inputLabel: String {
        switch self {
        case .vipTime: return "延长天数（正数延长，负数缩短）"
        case .balance: return "新余额"
        case .pwd: return "新密码"
        default: return ""
        }
    }

    var needsInput: Bool { self == .vipTime || self == .balance || self == .pwd }
}

struct WebUsersView: View {
    @State private var users: [WebUser] = []
    @State private var total = 0
    @State private var page = 1
    @State private var keyword = ""
    @State private var vipType = "all"
    @State private var hasQueryToday = false
    @State private var loading = false
    @State private var error: String?
    @State private var actionTarget: WebUser?
    @State private var action: WebUserAction?
    @State private var input = ""
    @State private var toast: String?
    @State private var toastTask: Task<Void, Never>?
    @State private var vipSheetTarget: WebUser?

    private let vipTypeOptions = [
        ("all", "全部用户"), ("vip", "VIP用户"), ("super_vip", "超级VIP"), ("normal_vip", "普通VIP")
    ]
    private let queryOptions = [("0", "全部用户"), ("1", "今日有查询")]

    private var totalPages: Int { max(1, (total + 19) / 20) }

    var body: some View {
        VStack(spacing: 10) {
            searchBar
            filterBar

            if loading && users.isEmpty {
                LoadingBox()
            } else if let error, users.isEmpty {
                ErrorBox(message: error) { load() }
            } else {
                List {
                    ForEach(users) { u in
                        WebUserRow(user: u) { act in
                            actionTarget = u
                            input = ""
                            if act == .superVip {
                                vipSheetTarget = u
                                action = nil
                            } else {
                                action = act
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .refreshable { load() }

                PagerRow(page: page, total: total, totalPages: totalPages) {
                    page = $0; load()
                }
            }
        }
        .padding(16)
        .onAppear { load() }
        // 超级VIP/设VIP完整表单（对齐 Vue setSuperVipForm）
        .sheet(item: $vipSheetTarget) { u in
            SuperVipSheet(user: u) { result in
                vipSheetTarget = nil
                Task {
                    do {
                        try await APIClient.shared.setSuperVip(SetVipReq(
                            userId: result.userId, isSuperVip: result.isSuperVip,
                            vipType: result.vipType, dailyLimit: result.dailyLimit,
                            startDate: result.startDate, endDate: result.endDate))
                        showToast("VIP设置成功")
                        load()
                    } catch {
                        showToast(error.localizedDescription)
                    }
                }
            }
            .presentationDetents([.large])
        }
        // 确认类操作（关闭/删除）
        .alert(item: confirmAlertItem) { item in
            switch item {
            case .close:
                return Alert(
                    title: Text("关闭VIP"),
                    message: Text("确认关闭 \(actionTarget?.username ?? "") 的VIP？"),
                    primaryButton: .default(Text("确认")) { runAction(.close) },
                    secondaryButton: .cancel { action = nil }
                )
            case .delete:
                return Alert(
                    title: Text("删除用户"),
                    message: Text("确认删除 \(actionTarget?.username ?? "")？此操作不可恢复"),
                    primaryButton: .destructive(Text("删除")) { runAction(.delete) },
                    secondaryButton: .cancel { action = nil }
                )
            default:
                return Alert(title: Text(""))
            }
        }
        // 输入类操作
        .sheet(item: inputSheetItem) { item in
            InputActionSheet(
                title: item.inputLabel,
                subtitle: "用户：\(actionTarget?.username ?? "-")",
                secure: item == .pwd,
                keyboard: item == .balance ? .decimalPad : .numberPad,
                text: $input,
                onConfirm: { runAction(item) }
            )
            .presentationDetents([.medium])
        }
        .overlay(toastOverlay)
    }

    // 只有确认类操作走 alert；输入类走 sheet
    private var confirmAlertItem: Binding<WebUserAction?> {
        Binding(
            get: { action.map { $0.needsInput ? nil : $0 } ?? nil },
            set: { action = $0 }
        )
    }

    private var inputSheetItem: Binding<WebUserAction?> {
        Binding(
            get: { action.map { $0.needsInput ? $0 : nil } ?? nil },
            set: { action = $0 }
        )
    }

    private var toastOverlay: some View {
        Group {
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
                        .padding(.bottom, 30)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
            }
        }
        .animation(.spring(), value: toast)
    }

    // MARK: - 搜索/筛选

    private var searchBar: some View {
        HStack(spacing: 8) {
            TextField("搜索用户名", text: $keyword)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.search)
                .onSubmit { page = 1; load() }
            Button { page = 1; load() } label: {
                Image(systemName: "magnifyingglass").foregroundColor(Tech.cyan)
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            FilterDropdown(label: "用户类型", selected: vipType, options: vipTypeOptions) {
                vipType = $0; page = 1; load()
            }
            FilterDropdown(label: "今日查询", selected: hasQueryToday ? "1" : "0", options: queryOptions) {
                hasQueryToday = $0 == "1"; page = 1; load()
            }
            Spacer()
        }
    }

    // MARK: - 操作执行

    private func runAction(_ type: WebUserAction) {
        guard let u = actionTarget, let id = u.id else { return }
        action = nil
        Task {
            do {
                switch type {
                case .superVip:
                    // 已改走 SuperVipSheet 完整表单
                    return
                case .vipTime:
                    try await APIClient.shared.updateVipTime(UpdateVipTimeReq(userId: id, days: Int(input.trimmingCharacters(in: .whitespaces)), vipType: "normal"))
                case .balance:
                    try await APIClient.shared.updateBalance(UpdateBalanceReq(userId: id, balance: Double(input.trimmingCharacters(in: .whitespaces)), action: "set"))
                case .pwd:
                    try await APIClient.shared.changeUserPassword(ChangeUserPasswordReq(userId: id, newPassword: input, confirmPassword: input))
                case .close:
                    try await APIClient.shared.closeVip(CloseVipReq(userId: id, vipType: "normal"))
                case .delete:
                    try await APIClient.shared.deleteUser(UserIdReq(userId: id))
                }
                showToast("操作成功")
                load()
            } catch {
                showToast(error.localizedDescription)
            }
        }
    }

    private func showToast(_ msg: String) {
        toastTask?.cancel()
        withAnimation(.spring()) { toast = msg }
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if !Task.isCancelled {
                withAnimation(.spring()) { toast = nil }
            }
        }
    }

    private func load() {
        loading = true; error = nil
        Task {
            do {
                let r = try await APIClient.shared.webUsers(
                    page: page, keyword: keyword.isEmpty ? nil : keyword,
                    vipType: vipType == "all" ? nil : vipType,
                    hasQueryToday: hasQueryToday ? true : nil
                )
                users = r.rows
                total = r.totalCount
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }
}

// MARK: - 行

struct WebUserRow: View {
    let user: WebUser
    var onAction: (WebUserAction) -> Void

    var body: some View {
        GlassCard(accent: Tech.cyan, borderAlpha: 0.2, glowAlpha: 0.12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.username ?? "-")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text("余额: \(fmt(user.balance)) | \(user.vipLabel)\(superVipLimitSuffix) | 今日查询: \(user.todayQueryCount ?? 0)")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                    Text("注册: \(user.createdAt ?? "-")\(locationSuffix)")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.45))
                }
                Spacer()
                Menu {
                    Button(user.vipInfo?.isVip == true || user.isSuperVip == 1 ? "续费VIP时长" : "设为超级VIP") { onAction(.superVip) }
                    Button("关闭VIP") { onAction(.close) }
                    Button("改VIP时长") { onAction(.vipTime) }
                    Button("改余额") { onAction(.balance) }
                    Button("改密码") { onAction(.pwd) }
                    Button("删除", role: .destructive) { onAction(.delete) }
                } label: {
                    HStack(spacing: 2) {
                        Text("操作").font(.system(size: 14)).foregroundColor(Tech.cyan)
                        Image(systemName: "ellipsis").font(.system(size: 13)).foregroundColor(Tech.cyan)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Tech.cyan.opacity(0.12)))
                    .overlay(Capsule().strokeBorder(Tech.cyan.opacity(0.4), lineWidth: 1))
                }
            }
        }
    }

    private var locationSuffix: String {
        if let loc = user.registerLocation, !loc.isEmpty, loc != "未知" { return " | \(loc)" }
        return ""
    }

    private var superVipLimitSuffix: String {
        guard let limit = user.superVipDailyLimit, limit > 0, user.isSuperVip == 1 || user.vipInfo?.isSuperVip == 1 else { return "" }
        return "(限额\(limit))"
    }
}

// MARK: - 超级VIP/设VIP完整表单（对齐 Vue setSuperVipForm：vip_type/is_super_vip/daily_limit/start_date/end_date）

struct SuperVipFormResult {
    let userId: Int
    let isSuperVip: Int
    let vipType: String
    var dailyLimit: Int?
    var startDate: String?
    var endDate: String?
}

struct SuperVipSheet: View {
    let user: WebUser
    var onConfirm: (SuperVipFormResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var vipType = "super"
    @State private var enabled = true
    @State private var dailyLimit = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(30 * 86400)
    @State private var hasStart = false
    @State private var hasEnd = false

    private static let display: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("用户：\(user.username ?? "-")")
                        .font(.system(size: 13)).foregroundColor(.white.opacity(0.6))

                    HStack(spacing: 12) {
                        pickerChip("super", "超级VIP")
                        pickerChip("normal", "普通VIP")
                    }

                    SwitchRow(label: "启用VIP状态", checked: $enabled)

                    LabeledField(label: "每日查询限额（留空=不限制）", text: $dailyLimit, keyboard: .numberPad)

                    Toggle(hasStart ? "清除起始时间" : "设置起始时间", isOn: $hasStart).tint(Tech.cyan)
                    if hasStart {
                        DatePicker("开始时间", selection: $startDate)
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                    }
                    Toggle(hasEnd ? "清除结束时间" : "设置结束时间", isOn: $hasEnd).tint(Tech.cyan)
                    if hasEnd {
                        DatePicker("结束时间", selection: $endDate)
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                    }

                    Button("确认设置") {
                        var result = SuperVipFormResult(
                            userId: user.id ?? 0,
                            isSuperVip: enabled ? 1 : 0,
                            vipType: vipType)
                        if let n = Int(dailyLimit.trimmingCharacters(in: .whitespaces)), n > 0 {
                            result.dailyLimit = n
                        }
                        result.startDate = hasStart ? Self.display.string(from: startDate) : nil
                        result.endDate = hasEnd ? Self.display.string(from: endDate) : nil
                        onConfirm(result)
                    }
                    .buttonStyle(TechButtonStyle()).padding(.top, 8)
                }
                .padding(20)
            }
            .background(Tech.bgBottom.ignoresSafeArea())
            .navigationTitle("设置VIP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundColor(Tech.cyan)
                }
            }
        }
    }

    private func pickerChip(_ value: String, _ label: String) -> some View {
        Button {
            vipType = value
        } label: {
            Text(label)
                .font(.system(size: 14, weight: vipType == value ? .semibold : .regular))
                .foregroundColor(vipType == value ? .black : .white.opacity(0.75))
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Capsule().fill(vipType == value ? AnyShapeStyle(Tech.accentGradient) : AnyShapeStyle(Color.white.opacity(0.08))))
                .overlay(Capsule().strokeBorder(vipType == value ? Color.clear : Tech.cyan.opacity(0.25), lineWidth: 1))
        }
    }
}

// MARK: - 输入类操作 Sheet

struct InputActionSheet: View {
    let title: String
    let subtitle: String
    var secure = false
    var keyboard: UIKeyboardType = .default
    @Binding var text: String
    var onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text(subtitle).font(.system(size: 13)).foregroundColor(.white.opacity(0.6))
                LabeledField(label: title, text: $text, secure: secure, keyboard: keyboard)
                    .focused($focused)
                Spacer()
            }
            .padding(20)
            .background(Tech.bgBottom.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundColor(Tech.cyan)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        onConfirm()
                        dismiss()
                    }
                    .foregroundColor(Tech.cyan)
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
    }
}
