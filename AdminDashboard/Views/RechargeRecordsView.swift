import SwiftUI

/// 充值明细（对齐 Vue RechargeRecords.vue：平台/关键词/日期范围筛选 + 合计 + 分页列表）
struct RechargeRecordsView: View {
    @State private var page: RechargePage?
    @State private var loading = false
    @State private var error: String?
    @State private var pageNo = 1
    @State private var platform = "all"
    @State private var search = ""
    @State private var rangeKey = "0"
    @State private var hasSearched = false

    private let pageSize = 20

    private let platformOptions = [
        ("all", "全部平台"), ("web", "网页端"), ("mini", "微信小程序"), ("alipay", "支付宝小程序")
    ]
    private let rangeOptions: [(String, String)] = [
        ("0", "全部时间"), ("today", "今天"), ("yesterday", "昨天"), ("7", "近 7 天"), ("30", "近 30 天")
    ]

    private var startDate: String? {
        switch rangeKey {
        case "today": return Self.fmt.string(from: Date())
        case "yesterday": return Self.fmt.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        case "7": return Self.fmt.string(from: Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date())
        case "30": return Self.fmt.string(from: Calendar.current.date(byAdding: .day, value: -29, to: Date()) ?? Date())
        default: return nil
        }
    }

    private var endDate: String? {
        switch rangeKey {
        case "0": return nil
        case "yesterday": return Self.fmt.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        default: return Self.fmt.string(from: Date())
        }
    }

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                summaryBar
                filterBar

                if loading && page == nil {
                    LoadingBox().frame(height: 200)
                } else if let error, page == nil {
                    ErrorBox(message: error) { fetch() }
                } else if let page {
                    if (page.records ?? []).isEmpty {
                        GlassCard {
                            Text("暂无数据")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.45))
                                .frame(maxWidth: .infinity, minHeight: 100)
                        }
                    } else {
                        ForEach(page.records ?? []) { r in
                            recordCard(r)
                        }
                        PagerRow(page: pageNo, total: page.total ?? 0, totalPages: totalPages(page)) { p in
                            pageNo = p
                            fetch()
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 30)
        }
        .onAppear { if page == nil { fetch() } }
    }

    private func totalPages(_ p: RechargePage) -> Int {
        let total = p.total ?? 0
        return max(1, (total + pageSize - 1) / pageSize)
    }

    // MARK: 合计条

    private var summaryBar: some View {
        GlassCard(accent: Tech.green, borderAlpha: 0.25, glowAlpha: 0.12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("充值笔数").font(.system(size: 12)).foregroundColor(.white.opacity(0.55))
                    Text("\(page?.summary?.count ?? 0)").font(.system(size: 24, weight: .bold)).foregroundColor(Tech.cyan)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("充值总额").font(.system(size: 12)).foregroundColor(.white.opacity(0.55))
                    Text(String(format: "¥%.2f", page?.summary?.totalAmount ?? 0))
                        .font(.system(size: 24, weight: .bold)).foregroundColor(Tech.green)
                }
            }
        }
    }

    // MARK: 筛选栏

    private var filterBar: some View {
        GlassCard(borderAlpha: 0.25, glowAlpha: 0.12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    FilterDropdown(label: "平台", selected: platform, options: platformOptions) { v in
                        platform = v
                        pageNo = 1
                        fetch()
                    }
                    FilterDropdown(label: "时间", selected: rangeKey, options: rangeOptions) { v in
                        rangeKey = v
                        pageNo = 1
                        fetch()
                    }
                    Spacer()
                }
                HStack(spacing: 8) {
                    LabeledField(label: "关键词", text: $search)
                        .frame(maxWidth: .infinity)
                    Button("查询") { pageNo = 1; fetch() }.buttonStyle(TechButtonStyle(compact: true))
                    Button("重置") {
                        platform = "all"; rangeKey = "0"; search = ""; pageNo = 1
                        fetch()
                    }
                    .buttonStyle(TechButtonStyle(enabled: false, compact: true))
                }
            }
        }
    }

    // MARK: 记录卡片

    private func recordCard(_ r: RechargeRecord) -> some View {
        GlassCard(accent: Tech.cyan, borderAlpha: 0.22, glowAlpha: 0.1) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(Self.platformLabel(r.platform))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Tech.cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Tech.cyan.opacity(0.14)))
                    Spacer()
                    Text(String(format: "¥%.2f", r.price ?? 0))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Tech.green)
                }
                let isBig = (r.platform ?? "") == "alipay"
                HStack(spacing: 14) {
                    Text(isBig ? "ID: \(r.userId ?? "-")" : "用户: \(r.userName ?? r.userId ?? "-")")
                        .font(.system(size: 13)).foregroundColor(.white.opacity(0.8))
                    if !isBig {
                        Text("ID: \(r.userId ?? "-")")
                            .font(.system(size: 12)).foregroundColor(.white.opacity(0.5))
                    }
                }
                Text("套餐: \(r.packageName ?? "-")")
                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.65))
                Divider().overlay(.white.opacity(0.08))
                HStack {
                    Text("时间: \(r.payTime ?? "-")").font(.system(size: 11)).foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Text("订单: \(r.orderNo ?? String(r.orderId ?? 0))")
                        .font(.system(size: 11)).foregroundColor(.white.opacity(0.5))
                }
            }
        }
    }

    static func platformLabel(_ p: String?) -> String {
        switch p {
        case "web": return "网页端"
        case "mini": return "微信小程序"
        case "alipay": return "支付宝"
        default: return p ?? "-"
        }
    }

    // MARK: 数据加载

    private func fetch() {
        loading = true; error = nil
        Task {
            do {
                page = try await APIClient.shared.rechargeList(
                    page: pageNo, pageSize: pageSize,
                    platform: platform == "all" ? nil : platform,
                    startDate: startDate, endDate: endDate,
                    search: search.isEmpty ? nil : search)
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }
}
