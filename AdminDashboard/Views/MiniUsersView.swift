import SwiftUI

struct MiniUsersView: View {
    @State private var users: [MiniUser] = []
    @State private var packages: [VipPackage] = []
    @State private var total = 0
    @State private var page = 1
    @State private var keyword = ""
    @State private var vipType = "all"
    @State private var loading = false
    @State private var error: String?
    @State private var vipTarget: MiniUser?
    @State private var closeTarget: MiniUser?
    @State private var detailTarget: MiniUser?
    @State private var toast: String?
    @State private var toastTask: Task<Void, Never>?

    private let vipTypeOptions = [("all", "全部用户"), ("vip", "VIP用户"), ("normal", "普通用户")]
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
                        MiniUserRow(user: u,
                                    onVip: { vipTarget = u },
                                    onClose: { closeTarget = u },
                                    onDetail: { detailTarget = u })
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
        .onAppear { load(); loadPackages() }
        .sheet(item: $vipTarget) { u in
            MiniVipSheet(user: u, packages: packages) { pkg, days in
                Task {
                    do {
                        let dates = vipDates(days)
                        try await APIClient.shared.miniSetVip(MiniSetVipReq(
                            userId: u.userId ?? "", isVip: 1,
                            packageId: pkg?.id, startDate: dates.start, endDate: dates.end
                        ))
                        showToast("已开通VIP")
                        load()
                    } catch {
                        showToast(error.localizedDescription)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $detailTarget) { u in
            MiniVipDetailSheet(user: u)
        }
        .alert(item: $closeTarget) { u in
            Alert(
                title: Text("关闭VIP"),
                message: Text("确认关闭 \(u.nickname ?? u.openid ?? "-") 的VIP？"),
                primaryButton: .default(Text("确认")) {
                    Task {
                        do {
                            try await APIClient.shared.miniSetVip(MiniSetVipReq(userId: u.userId ?? "", isVip: 0))
                            showToast("已关闭VIP")
                            load()
                        } catch {
                            showToast(error.localizedDescription)
                        }
                    }
                },
                secondaryButton: .cancel { closeTarget = nil }
            )
        }
        .overlay(toastOverlay)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            TextField("搜索昵称/openid", text: $keyword)
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
            Spacer()
        }
    }

    private var toastOverlay: some View {
        Group {
            if let toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 14)).foregroundColor(.white)
                        .padding(.horizontal, 18).padding(.vertical, 12)
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

    private func showToast(_ msg: String) {
        toastTask?.cancel()
        withAnimation(.spring()) { toast = msg }
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if !Task.isCancelled { withAnimation(.spring()) { toast = nil } }
        }
    }

    private func load() {
        loading = true; error = nil
        Task {
            do {
                let r = try await APIClient.shared.miniUsers(
                    page: page, keyword: keyword.isEmpty ? nil : keyword,
                    vipType: vipType == "all" ? nil : vipType
                )
                users = r.rows
                total = r.totalCount
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }

    private func loadPackages() {
        Task {
            if let data = try? await APIClient.shared.miniPackages().data {
                packages = data.filter { ($0.status ?? 1) == 1 }
            }
        }
    }
}

// MARK: - 行

struct MiniUserRow: View {
    let user: MiniUser
    var onVip: () -> Void
    var onClose: () -> Void
    var onDetail: () -> Void

    private var isVip: Bool { user.vipInfo?.isVip == true }

    var body: some View {
        GlassCard(accent: Tech.cyan, borderAlpha: 0.2, glowAlpha: 0.12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.nickname ?? user.openid ?? "-")
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    Text("\(user.vipLabel) | 今日查询: \(user.todayQueryCount ?? 0)")
                        .font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
                    Text("注册: \(user.createdAt ?? "-")")
                        .font(.system(size: 11)).foregroundColor(.white.opacity(0.45))
                }
                Spacer()
                ActionMenuButton(isVip: isVip, onVip: onVip, onClose: onClose, onDetail: onDetail)
            }
        }
    }
}

// MARK: - 开通/续费 Sheet

struct MiniVipSheet: View {
    let user: MiniUser
    let packages: [VipPackage]
    var onConfirm: (VipPackage?, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected: VipPackage?
    @State private var days = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("用户: \(user.nickname ?? user.openid ?? "-")")
                    .font(.system(size: 13)).foregroundColor(.white.opacity(0.6))

                if packages.isEmpty {
                    Text("套餐加载中或暂无可用套餐…")
                        .font(.system(size: 13)).foregroundColor(.white.opacity(0.5))
                } else {
                    // 套餐选择
                    VStack(alignment: .leading, spacing: 6) {
                        Text("VIP套餐").font(.system(size: 12)).foregroundColor(Tech.cyan)
                        Menu {
                            ForEach(packages) { p in
                                Button(action: { selected = p }) {
                                    Text("\(p.name ?? "") ￥\(p.price ?? "-")")
                                }
                            }
                        } label: {
                            HStack {
                                Text(selected.map { "\($0.name ?? "") ￥\($0.price ?? "-")" } ?? "请选择套餐")
                                    .font(.system(size: 14)).foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.down").foregroundColor(.white.opacity(0.5))
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Tech.glass.opacity(0.5)))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Tech.cyan.opacity(0.3), lineWidth: 1))
                        }
                    }

                    if let selected {
                        Text((selected.duration ?? 0) == 0
                             ? "终生有效 | 每日上限 \(fmt(selected.dailyLimit)) 次"
                             : "时长 \(selected.duration ?? 0) 天 | 每日上限 \(fmt(selected.dailyLimit)) 次")
                            .font(.system(size: 11)).foregroundColor(.white.opacity(0.6))
                    }

                    LabeledField(label: "自定义天数（留空按套餐时长）", text: $days, keyboard: .numberPad)
                }

                Spacer()
            }
            .padding(20)
            .background(Tech.bgBottom.ignoresSafeArea())
            .navigationTitle("开通/续费 VIP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundColor(Tech.cyan)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        onConfirm(selected, days)
                        dismiss()
                    }
                    .foregroundColor(Tech.cyan)
                    .disabled(selected == nil)
                }
            }
        }
    }
}

// MARK: - 套餐详情 Sheet

struct MiniVipDetailSheet: View {
    let user: MiniUser

    @Environment(\.dismiss) private var dismiss
    @State private var loading = true
    @State private var detail: MiniVipDetail?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    LoadingBox()
                } else if let error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle").foregroundColor(Tech.red)
                        Text(error).font(.system(size: 14)).foregroundColor(.white.opacity(0.85))
                    }
                } else if let vi = detail?.vipInfo {
                    List {
                        row("套餐", detail?.packageInfo?.name ?? "ID \(vi.packageId ?? 0)")
                        if detail?.isExpired == true {
                            row("状态", "已过期").foregroundColor(Tech.red)
                        } else {
                            row("状态", "有效")
                        }
                        row("开始", vi.startTime ?? "-")
                        row("到期", (vi.endTime?.isEmpty == false) ? vi.endTime! : "永久")
                        row("今日用量", "视频 \(vi.usedTodayVideo ?? 0) / 权重 \(vi.usedTodayWeight ?? 0)")
                        row("每日上限", "视频 \(fmt(vi.dailyLimitVideo)) / 权重 \(fmt(vi.dailyLimitWeight))")
                        row("订单号", vi.orderNo ?? "-")
                    }
                    .listStyle(.plain)
                } else {
                    Text("当前无有效 VIP")
                        .font(.system(size: 14)).foregroundColor(.white.opacity(0.6))
                }
            }
            .background(Tech.bgBottom.ignoresSafeArea())
            .navigationTitle("套餐详情 - \(user.nickname ?? user.openid ?? "-")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }.foregroundColor(Tech.cyan)
                }
            }
            .task { load() }
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.system(size: 13)).foregroundColor(.white.opacity(0.6))
            Spacer()
            Text(v).font(.system(size: 13)).foregroundColor(.white)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func load() {
        Task {
            do {
                let r = try await APIClient.shared.miniUserVipDetail(userId: user.userId ?? "")
                if r.code == 200 { detail = r.data } else { error = r.msg ?? "查询失败" }
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }
}

// MARK: - 日期工具

/// start_date=当前时间；填了天数→当前+days；未填→nil（后端按套餐时长计算）
func vipDates(_ days: String) -> (start: String, end: String?) {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let start = f.string(from: Date())
    let trimmed = days.trimmingCharacters(in: .whitespaces)
    if let d = Int(trimmed), let end = Calendar.current.date(byAdding: .day, value: d, to: Date()) {
        return (start, f.string(from: end))
    }
    return (start, nil)
}
