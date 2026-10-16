import SwiftUI

struct LogsView: View {
    @State private var logs: [OpLog] = []
    @State private var total = 0
    @State private var page = 1
    @State private var keyword = ""
    @State private var loading = false
    @State private var error: String?
    @State private var detail: OpLog?

    private var totalPages: Int { max(1, (total + 19) / 20) }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                TextField("搜索管理员/操作/目标", text: $keyword)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onSubmit { page = 1; load() }
                Button { page = 1; load() } label: {
                    Image(systemName: "magnifyingglass").foregroundColor(Tech.cyan)
                }
            }

            if loading && logs.isEmpty {
                LoadingBox()
            } else if let error, logs.isEmpty {
                ErrorBox(message: error) { load() }
            } else {
                List {
                    ForEach(logs) { l in
                        Button {
                            Task {
                                if let id = l.id, let full = try? await APIClient.shared.logDetail(id: id) {
                                    detail = full
                                } else {
                                    detail = l
                                }
                            }
                        } label: {
                            GlassCard(accent: Tech.cyan, borderAlpha: 0.2, glowAlpha: 0.1) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(l.username ?? "-") · \(l.actionType ?? "-")")
                                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                                    if let desc = l.description, !desc.isEmpty {
                                        Text(desc).font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
                                            .lineLimit(2)
                                    }
                                    Text("IP: \(l.ipAddress ?? "-") | \(l.createdAt ?? "-")")
                                        .font(.system(size: 12)).foregroundColor(.white.opacity(0.5))
                                }
                                Spacer()
                                Text("详情 ›").font(.system(size: 13)).foregroundColor(Tech.cyan)
                            }
                            }
                        }
                        .buttonStyle(.plain)
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
        .sheet(item: $detail) { l in
            LogDetailSheet(log: l)
        }
    }

    private func load() {
        loading = true; error = nil
        Task {
            do {
                let r = try await APIClient.shared.logsList(page: page, keyword: keyword.isEmpty ? nil : keyword)
                logs = r.rows
                total = r.totalCount
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }
}

// MARK: - 日志详情

struct LogDetailSheet: View {
    let log: OpLog

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                detailRow("ID", "\(log.id ?? 0)")
                detailRow("操作人", log.username ?? "-")
                detailRow("操作类型", log.actionType ?? "-")
                detailRow("描述", log.description ?? "-")
                detailRow("IP", log.ipAddress ?? "-")
                detailRow("UA", log.userAgent ?? "-")
                detailRow("时间", log.createdAt ?? "-")
            }
            .listStyle(.plain)
            .background(Color(red: 0.06, green: 0.07, blue: 0.12).ignoresSafeArea())
            .navigationTitle("日志详情 #\(log.id ?? 0)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }.foregroundColor(Tech.cyan)
                }
            }
        }
    }

    private func detailRow(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k).font(.system(size: 13)).foregroundColor(.white.opacity(0.6)).frame(width: 72, alignment: .leading)
            Text(v).font(.system(size: 13)).foregroundColor(.white)
            Spacer()
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}
