import SwiftUI

struct AlipayUsersView: View {
    @State private var users: [AlipayUser] = []
    @State private var packages: [VipPackage] = []
    @State private var total = 0
    @State private var page = 1
    @State private var keyword = ""
    @State private var vipType = "all"
    @State private var loading = false
    @State private var error: String?
    @State private var vipTarget: AlipayUser?
    @State private var closeTarget: AlipayUser?
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
                        AlipayUserRow(user: u, onVip: { vipTarget = u }, onClose: { closeTarget = u })
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
            MiniVipSheet(user: MiniUser(id: nil, openid: nil, userId: u.userId, nickname: u.nickname, avatarUrl: nil, vipExpireTime: nil, createdAt: nil, lastLoginAt: nil, todayQueryCount: nil, vipInfo: nil), packages: packages) { pkg, days in
                Task {
                    do {
                        let dates = vipDates(days)
                        try await APIClient.shared.alipaySetVip(MiniSetVipReq(
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
        .alert(item: $closeTarget) { u in
            Alert(
                title: Text("关闭VIP"),
                message: Text("确认关闭 \(u.nickname ?? u.alipayUserId ?? "-") 的VIP？"),
                primaryButton: .default(Text("确认")) {
                    Task {
                        do {
                            try await APIClient.shared.alipaySetVip(MiniSetVipReq(userId: u.userId ?? "", isVip: 0))
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
            TextField("搜索昵称/userId", text: $keyword)
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
                        .background(Capsule().fill(Color.black.opacity(0.85)).overlay(Capsule().strokeBorder(Tech.cyan.opacity(0.5), lineWidth: 1)))
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
                let r = try await APIClient.shared.alipayUsers(
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
            if let data = try? await APIClient.shared.alipayPackages().data {
                packages = data.filter { ($0.status ?? 1) == 1 }
            }
        }
    }
}

// MARK: - 行

struct AlipayUserRow: View {
    let user: AlipayUser
    var onVip: () -> Void
    var onClose: () -> Void

    private var isVip: Bool { user.vipInfo?.isVip == true }

    var body: some View {
        GlassCard(accent: Tech.cyan, borderAlpha: 0.2, glowAlpha: 0.12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.nickname ?? user.alipayUserId ?? user.userId ?? "-")
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    Text("\(user.vipLabel) | 今日查询: \(user.todayQueryCount ?? 0)")
                        .font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
                    Text("注册: \(user.createdAt ?? "-")")
                        .font(.system(size: 11)).foregroundColor(.white.opacity(0.45))
                }
                Spacer()
                ActionMenuButton(isVip: isVip, onVip: onVip, onClose: onClose)
            }
        }
    }
}
