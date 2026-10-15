import SwiftUI

struct CookieView: View {
    @State private var cookies: [CookieItem] = []
    @State private var stats: CookieStats?
    @State private var total = 0
    @State private var page = 1
    @State private var keyword = ""
    @State private var loading = false
    @State private var error: String?
    @State private var selected: Set<Int> = []
    @State private var addMode: AddMode?
    @State private var toast: String?
    @State private var toastTask: Task<Void, Never>?

    private enum AddMode: Identifiable { case single, batch; var id: Int { hashValue } }
    private var totalPages: Int { max(1, (total + 19) / 20) }

    var body: some View {
        VStack(spacing: 10) {
            // 统计卡片
            HStack(spacing: 12) {
                MiniStat(title: "总数", value: fmt(stats?.total))
                MiniStat(title: "有效", value: fmt(stats?.valid), color: Tech.green)
                MiniStat(title: "失效", value: fmt(stats?.invalid), color: Tech.red)
            }

            // 搜索 + 批量添加
            HStack(spacing: 8) {
                TextField("搜索 cookie/备注", text: $keyword)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onSubmit { page = 1; load() }
                Button { page = 1; load() } label: {
                    Image(systemName: "magnifyingglass").foregroundColor(Tech.cyan)
                }
                Button("批量") { addMode = .batch }
                    .buttonStyle(TechButtonStyle(compact: true))
            }

            // 批量删除
            if !selected.isEmpty {
                Button("删除选中(\(selected.count))") {
                    Task {
                        do {
                            try await APIClient.shared.cookieBatchDelete(CookieBatchDeleteReq(ids: Array(selected)))
                            selected.removeAll()
                            showToast("已删除")
                            load()
                        } catch {
                            showToast(error.localizedDescription)
                        }
                    }
                }
                .buttonStyle(TechButtonStyle(compact: true))
                .tint(Tech.red)
            }

            if loading && cookies.isEmpty {
                LoadingBox()
            } else if let error, cookies.isEmpty {
                ErrorBox(message: error) { load() }
            } else {
                List {
                    ForEach(cookies) { c in
                        CookieRow(
                            cookie: c,
                            checked: selected.contains(c.id ?? -1),
                            onToggle: {
                                let id = c.id ?? -1
                                if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
                            },
                            onToggleStatus: {
                                Task {
                                    do {
                                        try await APIClient.shared.cookieUpdateStatus(CookieUpdateStatusReq(id: c.id ?? 0, isActive: (c.isActive == 1) ? 0 : 1))
                                        showToast("状态已更新")
                                        load()
                                    } catch {
                                        showToast(error.localizedDescription)
                                    }
                                }
                            },
                            onDelete: {
                                Task {
                                    do {
                                        try await APIClient.shared.cookieDelete(IdReq(id: c.id ?? 0))
                                        showToast("已删除")
                                        load()
                                    } catch {
                                        showToast(error.localizedDescription)
                                    }
                                }
                            }
                        )
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
        .overlay(alignment: .bottomTrailing) {
            Button { addMode = .single } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Tech.accentGradient)
                    .clipShape(Circle())
                    .shadow(color: Tech.cyan.opacity(0.5), radius: 12)
            }
            .padding(20)
        }
        .onAppear { load() }
        .sheet(item: $addMode) { mode in
            switch mode {
            case .single:
                CookieAddSheet(mode: .single) { cookie, _, _ in
                    Task {
                        do {
                            try await APIClient.shared.cookieAdd(CookieAddReq(cookieValue: cookie, platform: nil, remark: nil))
                            showToast("已添加")
                            load()
                        } catch { showToast(error.localizedDescription) }
                    }
                }
            case .batch:
                CookieAddSheet(mode: .batch) { text, _, _ in
                    Task {
                        do {
                            try await APIClient.shared.cookieBatchAdd(CookieBatchAddReq(cookies: text))
                            showToast("已批量添加")
                            load()
                        } catch { showToast(error.localizedDescription) }
                    }
                }
            }
        }
        .overlay(toastOverlay)
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
                let r = try await APIClient.shared.cookieList(page: page, keyword: keyword.isEmpty ? nil : keyword)
                cookies = r.rows
                total = r.totalCount
                stats = try? await APIClient.shared.cookieStats()
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }
}

// MARK: - Cookie 行

struct CookieRow: View {
    let cookie: CookieItem
    let checked: Bool
    var onToggle: () -> Void
    var onToggleStatus: () -> Void
    var onDelete: () -> Void

    var body: some View {
        GlassCard(accent: Tech.cyan, borderAlpha: 0.2, glowAlpha: 0.1) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Button(action: onToggle) {
                        Image(systemName: checked ? "checkmark.square.fill" : "square")
                            .foregroundColor(checked ? Tech.cyan : .white.opacity(0.4))
                            .font(.system(size: 20))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(truncated(cookie.cookie))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text("有效性: \((cookie.isValid == 1) ? "有效" : "失效") | 激活: \((cookie.isActive == 1) ? "是" : "否") | 使用: \(cookie.useCount ?? 0) 次")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                        Text("添加: \(cookie.createdAt ?? "-")")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }
                HStack(spacing: 8) {
                    Button("切换", action: onToggleStatus).buttonStyle(TechButtonStyle(compact: true))
                    Button("删", action: onDelete).buttonStyle(TechButtonStyle(compact: true)).tint(Tech.red)
                }
            }
        }
    }

    private func truncated(_ s: String?) -> String {
        guard let s else { return "-" }
        return s.count > 40 ? String(s.prefix(40)) + "…" : s
    }
}

// MARK: - 添加 Cookie Sheet

struct CookieAddSheet: View {
    enum Mode { case single, batch }

    let mode: Mode
    var onConfirm: (String, String?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var cookie = ""
    @State private var platform = ""
    @State private var remark = ""
    @State private var batchText = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                switch mode {
                case .single:
                    LabeledField(label: "Cookie", text: $cookie)
                    LabeledField(label: "平台(可选)", text: $platform)
                    LabeledField(label: "备注(可选)", text: $remark)
                case .batch:
                    LabeledField(label: "Cookies（每行一个）", text: $batchText)
                }
                Spacer()
            }
            .padding(20)
            .background(Color(red: 0.06, green: 0.07, blue: 0.12).ignoresSafeArea())
            .navigationTitle(mode == .single ? "添加 Cookie" : "批量添加 Cookie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundColor(Tech.cyan)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        switch mode {
                        case .single:
                            onConfirm(cookie, platform.isEmpty ? nil : platform, remark.isEmpty ? nil : remark)
                        case .batch:
                            onConfirm(batchText, nil, nil)
                        }
                        dismiss()
                    }
                    .foregroundColor(Tech.cyan)
                    .disabled(mode == .single ? cookie.isEmpty : batchText.isEmpty)
                }
            }
        }
    }
}
