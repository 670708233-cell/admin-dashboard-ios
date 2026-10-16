import SwiftUI
import Charts

struct DashboardView: View {
    @State private var data: DashboardData?
    @State private var loading = true
    @State private var error: String?
    @State private var refreshSec = RefreshIntervalStore.get()
    @State private var lastUpdate: String?
    @State private var refreshTask: Task<Void, Never>?

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        Group {
            if loading, data == nil {
                LoadingBox()
            } else if let error, data == nil {
                ErrorBox(message: error) { load() }
            } else if let data {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        autoRefreshRow
                        webSection(data)
                        miniSection(data)
                        alipaySection(data)
                        apiSection(data)
                        cookieSection
                        growthSection(data)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
        }
        .onAppear {
            load()
            startAutoRefresh()
        }
        .onDisappear { refreshTask?.cancel() }
        .onChange(of: refreshSec) { _ in startAutoRefresh() }
    }

    // MARK: 头部

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("仪表盘")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [.white, Tech.cyan], startPoint: .leading, endPoint: .trailing))
                Text("REAL-TIME DATA CONSOLE")
                    .font(.system(size: 10))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.4))
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(Tech.green).frame(width: 7, height: 7).shadow(color: Tech.green, radius: 4)
                Text("在线V2").font(.system(size: 11)).foregroundColor(Tech.green)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Tech.green.opacity(0.15)))
            .overlay(Capsule().strokeBorder(Tech.green.opacity(0.5), lineWidth: 1))
            Button { load() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Tech.cyan)
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.top, 12)
    }

    // MARK: 自动刷新行

    private var autoRefreshRow: some View {
        HStack(spacing: 10) {
            AutoRefreshChip(sec: $refreshSec)
            if let lastUpdate {
                Text(refreshSec > 0 ? "自动刷新 \(RefreshIntervalStore.label(refreshSec)) · 上次更新 \(lastUpdate)" : "上次更新 \(lastUpdate)")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
            }
            Spacer()
        }
        .padding(.top, 10)
    }

    // MARK: 各数据区

    private func webSection(_ d: DashboardData) -> some View {
        Group {
            SectionTitle(text: "网页端数据概览")
            LazyVGrid(columns: columns, spacing: 12) {
                StatCard(title: "网页端API总请求数", value: fmt(d.webTotalRequests), accent: Tech.accent(0))
                StatCard(title: "今日注册数", value: fmt(d.todayRegistrations), accent: Tech.accent(1))
                StatCard(title: "今日充值数", value: "￥\(fmt(d.todayRecharge))", accent: Tech.accent(2))
                StatCard(title: "总用户数", value: fmt(d.totalUsers), accent: Tech.accent(3))
                StatCard(title: "总充值额", value: "￥\(fmt(d.totalRecharge))", accent: Tech.accent(4))
            }
        }
    }

    private func miniSection(_ d: DashboardData) -> some View {
        Group {
            SectionTitle(text: "微信小程序数据概览")
            LazyVGrid(columns: columns, spacing: 12) {
                StatCard(title: "小程序API总请求数", value: fmt(d.miniProgramTotalRequests), accent: Tech.accent(0))
                StatCard(title: "今日注册数", value: fmt(d.miniProgramTodayRegistrations), accent: Tech.accent(1))
                StatCard(title: "总用户数", value: fmt(d.miniProgramTotalUsers), accent: Tech.accent(3))
                StatCard(title: "今日看广告次数", value: fmt(d.miniProgramTodayAdViews), accent: Tech.accent(2))
                StatCard(title: "AI作品优化分析", value: fmt(d.miniProgramTodayAiWorkAnalysis), accent: Tech.accent(4))
                StatCard(title: "AI账号权重分析", value: fmt(d.miniProgramTodayAiWeightAnalysis), accent: Tech.accent(5))
            }
        }
    }

    private func alipaySection(_ d: DashboardData) -> some View {
        Group {
            SectionTitle(text: "支付宝小程序数据概览")
            LazyVGrid(columns: columns, spacing: 12) {
                StatCard(title: "小程序API总请求数", value: fmt(d.alipayTotalRequests), accent: Tech.accent(0))
                StatCard(title: "今日注册数", value: fmt(d.alipayTodayRegistrations), accent: Tech.accent(1))
                StatCard(title: "总用户数", value: fmt(d.alipayTotalUsers), accent: Tech.accent(3))
                StatCard(title: "今日看广告次数", value: fmt(d.alipayTodayAdViews), accent: Tech.accent(2))
                StatCard(title: "AI作品优化分析", value: fmt(d.alipayTodayAiWorkAnalysis), accent: Tech.accent(4))
                StatCard(title: "AI账号权重分析", value: fmt(d.alipayTodayAiWeightAnalysis), accent: Tech.accent(5))
            }
        }
    }

    private func apiSection(_ d: DashboardData) -> some View {
        Group {
            SectionTitle(text: "网页端API分类统计")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                ApiStatCard(title: "查询", success: d.webRequests?.query?.success, failed: d.webRequests?.query?.failed, total: d.webRequests?.query?.total)
                ApiStatCard(title: "刷新", success: d.webRequests?.refresh?.success, failed: d.webRequests?.refresh?.failed, total: d.webRequests?.refresh?.total)
                ApiStatCard(title: "权重", success: d.webRequests?.weight?.success, failed: d.webRequests?.weight?.failed, total: d.webRequests?.weight?.total)
                ApiStatCard(title: "公开查询", success: d.webRequests?.publicQuery?.success, failed: d.webRequests?.publicQuery?.failed, total: d.webRequests?.publicQuery?.total)
                ApiStatCard(title: "API查询", success: d.webRequests?.apiQuery?.success, failed: d.webRequests?.apiQuery?.failed, total: d.webRequests?.apiQuery?.total)
                ApiStatCard(title: "总计", success: d.webRequests?.total?.success, failed: d.webRequests?.total?.failed, total: d.webRequests?.total?.total)
            }

            SectionTitle(text: "小程序API分类统计")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                ApiStatCard(title: "视频", success: d.miniProgramRequests?.video?.success, failed: d.miniProgramRequests?.video?.failed, total: d.miniProgramRequests?.video?.total)
                ApiStatCard(title: "权重", success: d.miniProgramRequests?.weight?.success, failed: d.miniProgramRequests?.weight?.failed, total: d.miniProgramRequests?.weight?.total)
                ApiStatCard(title: "素材", success: d.miniProgramRequests?.material?.success, failed: d.miniProgramRequests?.material?.failed, total: d.miniProgramRequests?.material?.total)
                ApiStatCard(title: "总计", success: d.miniProgramRequests?.total?.success, failed: d.miniProgramRequests?.total?.failed, total: d.miniProgramRequests?.total?.total)
            }

            SectionTitle(text: "支付宝API分类统计")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                ApiStatCard(title: "视频", success: d.alipayRequests?.video?.success, failed: d.alipayRequests?.video?.failed, total: d.alipayRequests?.video?.total)
                ApiStatCard(title: "权重", success: d.alipayRequests?.weight?.success, failed: d.alipayRequests?.weight?.failed, total: d.alipayRequests?.weight?.total)
                ApiStatCard(title: "素材", success: d.alipayRequests?.material?.success, failed: d.alipayRequests?.material?.failed, total: d.alipayRequests?.material?.total)
                ApiStatCard(title: "总计", success: d.alipayRequests?.total?.success, failed: d.alipayRequests?.total?.failed, total: d.alipayRequests?.total?.total)
            }

            SectionTitle(text: "今日请求")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                ApiStatCard(title: "成功", success: d.todayRequests?.success, failed: 0, total: d.todayRequests?.total)
                ApiStatCard(title: "失败", success: 0, failed: d.todayRequests?.failed, total: d.todayRequests?.total)
            }
        }
    }

    private var cookieSection: some View {
        Group {
            SectionTitle(text: "Cookie 池统计")
            LazyVGrid(columns: columns, spacing: 12) {
                StatCard(title: "Cookie总数", value: fmt(data?.totalCookies), accent: Tech.accent(0))
                StatCard(title: "有效Cookie", value: fmt(data?.validCookies), accent: Tech.accent(1))
                StatCard(title: "失效Cookie", value: fmt(data?.invalidCookies), accent: Tech.accent(2))
            }
        }
    }

    private func growthSection(_ d: DashboardData) -> some View {
        Group {
            SectionTitle(text: "增长趋势")
            GrowthChart(title: "近7天用户增长趋势", points: d.userGrowth ?? [], color: Color(red: 0.4, green: 0.494, blue: 0.918))
            Spacer().frame(height: 12)
            GrowthChart(title: "微信小程序近7天用户增长趋势", points: d.miniProgramUserGrowth ?? [], color: Tech.accent(0))
            Spacer().frame(height: 12)
            GrowthChart(title: "支付宝小程序近7天用户增长趋势", points: d.alipayUserGrowth ?? [], color: Color(red: 0.086, green: 0.467, blue: 1.0))
        }
    }

    // MARK: 数据加载

    private func load() {
        Task {
            do {
                let d = try await APIClient.shared.dashboard()
                data = d
                error = nil
                lastUpdate = Self.timeText()
            } catch {
                if data == nil { self.error = error.localizedDescription }
            }
            loading = false
        }
    }

    private func startAutoRefresh() {
        refreshTask?.cancel()
        guard refreshSec > 0 else { return }
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(refreshSec) * 1_000_000_000)
                if Task.isCancelled { return }
                load()
            }
        }
    }

    static func timeText() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }
}

// MARK: - 增长趋势图（Swift Charts）

struct GrowthChart: View {
    let title: String
    let points: [GrowthPoint]
    let color: Color

    var body: some View {
        GlassCard(borderAlpha: 0.25, glowAlpha: 0.15) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))

                if points.isEmpty {
                    Text("暂无数据")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                } else {
                    Chart {
                        ForEach(Array(points.enumerated()), id: \.offset) { idx, p in
                            AreaMark(
                                x: .value("日期", p.date ?? "#\(idx + 1)"),
                                y: .value("数量", p.count ?? 0)
                            )
                            .foregroundStyle(
                                LinearGradient(colors: [color.opacity(0.35), color.opacity(0)], startPoint: .top, endPoint: .bottom)
                            )
                            LineMark(
                                x: .value("日期", p.date ?? "#\(idx + 1)"),
                                y: .value("数量", p.count ?? 0)
                            )
                            .foregroundStyle(color)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            .symbol(.circle)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine().foregroundStyle(.white.opacity(0.08))
                            AxisValueLabel().foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel()
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .frame(height: 180)
                }
            }
        }
    }
}

// MARK: - 自动刷新芯片

struct AutoRefreshChip: View {
    @Binding var sec: Int

    private var active: Bool { sec > 0 }
    @State private var pulse = false

    var body: some View {
        Menu {
            ForEach(RefreshIntervalStore.options, id: \.0) { opt in
                Button(action: { sec = opt.0 }) {
                    HStack {
                        Text(opt.1)
                        if opt.0 == sec { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(active ? Tech.cyan.opacity(pulse ? 1 : 0.25) : Color.white.opacity(0.4))
                    .frame(width: 8, height: 8)
                Text(active ? "自动 \(RefreshIntervalStore.label(sec))" : "自动刷新")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(active ? Tech.cyan : .white.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(active ? Tech.cyan.opacity(0.15) : Color.white.opacity(0.08)))
            .overlay(Capsule().strokeBorder(active ? Tech.cyan.opacity(0.5) : Color.white.opacity(0.18), lineWidth: 1))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
        .onChange(of: sec) { _ in RefreshIntervalStore.save(sec) }
    }
}
