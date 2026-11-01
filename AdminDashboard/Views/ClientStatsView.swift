import SwiftUI
import Charts

/// 客户端数据看板（对齐 Vue ClientStats.vue：下载/安装/注册汇总 + 活跃设备 + 趋势图 + 平台分布）
struct ClientStatsView: View {
    @State private var data: ClientStatsData?
    @State private var loading = false
    @State private var error: String?
    @State private var lastUpdated = ""

    // 筛选：快捷区间 + 平台
    @State private var rangeDays = 30
    @State private var platform = "all"

    private let platformOptions = [
        ("all", "全部平台"), ("pc", "电脑端 (EXE)"), ("android", "安卓端"), ("ios", "iOS 端")
    ]
    private let rangeOptions: [(Int, String)] = [
        (7, "近 7 天"), (30, "近 30 天"), (90, "近 90 天")
    ]

    private var startDate: String {
        Self.fmt.string(from: Calendar.current.date(byAdding: .day, value: -(rangeDays - 1), to: Date()) ?? Date())
    }
    private var endDate: String { Self.fmt.string(from: Date()) }

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                filterBar

                if loading && data == nil {
                    LoadingBox().frame(height: 220)
                } else if let error, data == nil {
                    ErrorBox(message: error) { fetch() }
                } else if let data {
                    summarySection(data)
                    activeSection(data)
                    trendSection(data)
                    platformSection(data)
                    if !lastUpdated.isEmpty {
                        Text("上次更新 \(lastUpdated)")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 30)
        }
        .onAppear { if data == nil { fetch() } }
    }

    // MARK: 筛选栏

    private var filterBar: some View {
        GlassCard(borderAlpha: 0.25, glowAlpha: 0.12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    FilterDropdown(label: "时间范围", selected: "\(rangeDays)", options: rangeOptions.map { ("\($0.0)", $0.1) }) { v in
                        rangeDays = Int(v) ?? 30
                    }
                    FilterDropdown(label: "平台", selected: platform, options: platformOptions) { v in
                        platform = v
                        fetch()
                    }
                    Spacer()
                }
                Text("\(startDate) 至 \(endDate)")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.55))
                HStack(spacing: 10) {
                    Button("查询") { fetch() }.buttonStyle(TechButtonStyle(compact: true))
                    Button("重置") {
                        rangeDays = 30
                        platform = "all"
                        fetch()
                    }
                    .buttonStyle(TechButtonStyle(compact: true, enabled: false))
                    Spacer()
                }
            }
        }
    }

    // MARK: 汇总卡（下载/安装/注册：今日·区间·累计）

    private func summarySection(_ d: ClientStatsData) -> some View {
        Group {
            SectionTitle(text: "数据汇总")
            statCard(title: "下载量", sub: "点击下载按钮 302 跳转", num: d.summary?.download, color: Tech.blue)
            statCard(title: "安装/启动量", sub: "check-update 上报设备", num: d.summary?.install, color: Tech.green)
            statCard(title: "注册数", sub: "按注册来源区分端", num: d.summary?.register, color: Color(red: 0.9, green: 0.64, blue: 0.24))
        }
    }

    private func statCard(title: String, sub: String, num: CSNum?, color: Color) -> some View {
        GlassCard(accent: color, borderAlpha: 0.3, glowAlpha: 0.14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.white.opacity(0.9))
                    Text(sub).font(.system(size: 11)).foregroundColor(.white.opacity(0.4))
                }
                HStack(spacing: 0) {
                    numItem("今日", num?.today ?? 0, color)
                    numItem("区间合计", num?.range ?? 0, color)
                    numItem("累计", num?.total ?? 0, color)
                }
            }
        }
    }

    private func numItem(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.system(size: 11)).foregroundColor(.white.opacity(0.55))
            Text("\(value)").font(.system(size: 22, weight: .bold)).foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 活跃设备

    private func activeSection(_ d: ClientStatsData) -> some View {
        Group {
            SectionTitle(text: "活跃设备（按最近启动时间）")
            HStack(spacing: 10) {
                MiniStat(title: "日活设备", value: "\(d.active?.dau ?? 0)", color: Tech.cyan)
                MiniStat(title: "周活设备", value: "\(d.active?.week ?? 0)", color: Tech.green)
                MiniStat(title: "月活设备", value: "\(d.active?.month ?? 0)", color: Tech.purple)
            }
        }
    }

    // MARK: 趋势图（三线）

    private func trendSection(_ d: ClientStatsData) -> some View {
        Group {
            SectionTitle(text: "趋势图（\(startDate) ~ \(endDate)）")
            GlassCard(borderAlpha: 0.25, glowAlpha: 0.15) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 14) {
                        legendDot("下载", Tech.blue)
                        legendDot("安装", Tech.green)
                        legendDot("注册", Color(red: 0.9, green: 0.64, blue: 0.24))
                        Spacer()
                    }
                    if (d.trend ?? []).isEmpty {
                        Text("当前筛选条件下暂无趋势数据")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.45))
                            .frame(maxWidth: .infinity, minHeight: 140)
                    } else {
                        Chart {
                            ForEach(d.trend ?? [], id: \.date) { p in
                                LineMark(x: .value("日期", p.date ?? ""), y: .value("数量", p.download ?? 0))
                                    .foregroundStyle(Tech.blue)
                                LineMark(x: .value("日期", p.date ?? ""), y: .value("数量", p.install ?? 0))
                                    .foregroundStyle(Tech.green)
                                LineMark(x: .value("日期", p.date ?? ""), y: .value("数量", p.register ?? 0))
                                    .foregroundStyle(Color(red: 0.9, green: 0.64, blue: 0.24))
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
                                AxisValueLabel().foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        .frame(height: 200)
                    }
                }
            }
        }
    }

    private func legendDot(_ label: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 14, height: 3)
            Text(label).font(.system(size: 12)).foregroundColor(.white.opacity(0.65))
        }
    }

    // MARK: 平台分布（下载/安装/注册）

    private func platformSection(_ d: ClientStatsData) -> some View {
        Group {
            SectionTitle(text: "平台分布")
            distCard("下载量分布", rows: d.platform?.download, color: Tech.blue)
            distCard("安装/启动分布", rows: d.platform?.install, color: Tech.green)
            distCard("注册来源分布", rows: d.platform?.register, color: Color(red: 0.9, green: 0.64, blue: 0.24))
        }
    }

    private func distCard(_ title: String, rows: [CSPlatformRow]?, color: Color) -> some View {
        GlassCard(accent: color, borderAlpha: 0.25, glowAlpha: 0.12) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(.white.opacity(0.85))
                let list = rows ?? []
                if list.isEmpty {
                    Text("暂无数据").font(.system(size: 13)).foregroundColor(.white.opacity(0.4))
                } else {
                    let maxCount = max(1, list.compactMap { $0.count }.max() ?? 1)
                    ForEach(list, id: \.platform) { row in
                        HStack(spacing: 8) {
                            Text(Self.platformLabel(row.platform))
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.75))
                                .frame(width: 72, alignment: .leading)
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Tech.track).frame(height: 8)
                                    Capsule().fill(color)
                                        .frame(width: max(6, g.size.width * CGFloat(row.count ?? 0) / CGFloat(maxCount)), height: 8)
                                }
                            }
                            .frame(height: 8)
                            Text("\(row.count ?? 0)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(color)
                                .frame(width: 46, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    static func platformLabel(_ p: String?) -> String {
        switch p {
        case "pc", "exe": return "电脑端"
        case "android": return "安卓端"
        case "ios": return "iOS 端"
        case "web": return "网页端"
        case "mini_wechat": return "微信小程序"
        case "mini_alipay": return "支付宝小程序"
        default: return p ?? "-"
        }
    }

    // MARK: 数据加载

    private func fetch() {
        loading = true; error = nil
        Task {
            do {
                data = try await APIClient.shared.clientStats(
                    startDate: startDate, endDate: endDate,
                    platform: platform == "all" ? nil : platform)
                lastUpdated = { let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f.string(from: Date()) }()
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }
}
