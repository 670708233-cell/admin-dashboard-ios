import SwiftUI

struct SettingsView: View {
    @State private var tab = 0
    private let tabs = ["通用设置", "站点状态", "微信小程序", "支付宝小程序"]

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(0..<tabs.count, id: \.self) { i in Text(tabs[i]) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Group {
                switch tab {
                case 1: SiteStatusSection()
                case 2: KeyValueSection(title: "微信小程序设置",
                                        load: { try await APIClient.shared.miniProgramSettings() },
                                        save: { try await APIClient.shared.miniProgramUpdateSetting($0) },
                                        delete: { try await APIClient.shared.miniProgramDeleteSetting($0) })
                case 3: KeyValueSection(title: "支付宝小程序设置",
                                        load: { try await APIClient.shared.alipaySettings() },
                                        save: { try await APIClient.shared.alipayUpdateSetting($0) },
                                        delete: { try await APIClient.shared.alipayDeleteSetting($0) })
                default: GeneralSettings()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - 通用设置

struct GeneralSettings: View {
    @State private var map: [(String, String)] = []
    @State private var loaded = false
    @State private var error: String?
    @State private var toast: String?

    var body: some View {
        Group {
            if !loaded, let error {
                ErrorBox(message: error) { load() }
            } else if !loaded {
                LoadingBox()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(map.indices, id: \.self) { i in
                            LabeledField(label: map[i].0, text: binding(i))
                        }
                        Button("保存通用设置") {
                            Task {
                                do {
                                    try await APIClient.shared.settingsSave(Dictionary(uniqueKeysWithValues: map.map { ($0.0, $0.1) }))
                                    toast = "已保存"
                                } catch {
                                    toast = error.localizedDescription
                                }
                            }
                        }
                        .buttonStyle(TechButtonStyle())
                        .padding(.top, 8)
                    }
                    .padding(16)
                }
            }
        }
        .onAppear { load() }
        .overlay(toastOverlay)
    }

    private func binding(_ i: Int) -> Binding<String> {
        Binding(
            get: { map[i].1 },
            set: { map[i].1 = $0 }
        )
    }

    private func load() {
        Task {
            do {
                let m = try await APIClient.shared.settingsGet()
                map = m.map { ($0.key, ($0.value as? String) ?? "\($0.value ?? "")") }
                    .sorted { $0.0 < $1.0 }
                loaded = true
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private var toastOverlay: some View {
        Group {
            if let toast {
                VStack {
                    Spacer()
                    Text(toast).font(.system(size: 14)).foregroundColor(.white)
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .background(Capsule().fill(Tech.glass.opacity(0.95)))
                        .padding(.bottom, 30)
                }
                .frame(maxWidth: .infinity).allowsHitTesting(false)
            }
        }
    }
}

// MARK: - 站点状态

struct SiteStatusSection: View {
    @State private var status = "open"
    @State private var reopen = ""
    @State private var toast: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("站点状态").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)

                Button { status = "open" } label: {
                    HStack {
                        Image(systemName: status == "open" ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(Tech.cyan)
                        Text("正常开放").foregroundColor(.white)
                    }
                }
                Button { status = "maintenance" } label: {
                    HStack {
                        Image(systemName: status == "maintenance" ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(Tech.cyan)
                        Text("维护中").foregroundColor(.white)
                    }
                }
                if status == "maintenance" {
                    LabeledField(label: "预计恢复时间", text: $reopen)
                }
                Button("保存站点状态") {
                    Task {
                        do {
                            try await APIClient.shared.siteStatus(SiteStatus(
                                status: status,
                                expectedReopenTime: reopen.isEmpty ? nil : reopen
                            ))
                            toast = "已更新"
                        } catch {
                            toast = error.localizedDescription
                        }
                    }
                }
                .buttonStyle(TechButtonStyle())
                Spacer()
            }
            .padding(16)
        }
        .task {
            // 站点状态在通用设置里，读取 site_status 键
            if let m = try? await APIClient.shared.settingsGet(),
               let s = m["site_status"] as? String {
                status = s
            }
        }
        .overlay(toastOverlay)
    }

    private var toastOverlay: some View {
        Group {
            if let toast {
                VStack {
                    Spacer()
                    Text(toast).font(.system(size: 14)).foregroundColor(.white)
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .background(Capsule().fill(Tech.glass.opacity(0.95)))
                        .padding(.bottom, 30)
                }
                .frame(maxWidth: .infinity).allowsHitTesting(false)
            }
        }
    }
}

// MARK: - 键值设置（微信/支付宝小程序）

struct KeyValueSection: View {
    let title: String
    let load: () async throws -> [KeyValueSetting]
    let save: (SettingUpdateReq) async throws -> Void
    let delete: (SettingDeleteReq) async throws -> Void

    @State private var items: [KeyValueSetting] = []
    @State private var loading = false
    @State private var adding = false
    @State private var newKey = ""
    @State private var newValue = ""
    @State private var toast: String?

    var body: some View {
        VStack(spacing: 10) {
            Button("新增") { newKey = ""; newValue = ""; adding = true }
                .buttonStyle(TechButtonStyle(compact: true))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)

            if loading, items.isEmpty {
                LoadingBox()
            } else {
                List {
                    ForEach(items) { s in
                        KeyValueRow(item: s,
                                    onSave: { v in
                            Task {
                                do {
                                    try await save(SettingUpdateReq(id: s.id, key: s.key, value: v, remark: nil))
                                    toast = "已保存"
                                    await reload()
                                } catch { toast = error.localizedDescription }
                            }
                        },
                            onDelete: {
                            Task {
                                do {
                                    try await delete(SettingDeleteReq(id: s.id ?? 0))
                                    toast = "已删除"
                                    await reload()
                                } catch { toast = error.localizedDescription }
                            }
                        })
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
            }
        }
        .task { await reload() }
        .sheet(isPresented: $adding) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 14) {
                    LabeledField(label: "键(key)", text: $newKey)
                    LabeledField(label: "值(value)", text: $newValue)
                    HStack {
                        Button("取消") { adding = false }
                            .foregroundColor(Tech.cyan)
                        Spacer()
                        Button("确定") {
                            Task {
                                do {
                                    try await save(SettingUpdateReq(id: nil, key: newKey, value: newValue, remark: nil))
                                    toast = "已保存"
                                    await reload()
                                } catch { toast = error.localizedDescription }
                                adding = false
                            }
                        }
                        .foregroundColor(Tech.cyan)
                        .disabled(newKey.isEmpty)
                    }
                    Spacer()
                }
                .padding(20)
                .background(Tech.bgBottom.ignoresSafeArea())
                .navigationTitle("新增 \(title)")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .overlay(toastOverlay)
    }

    private func reload() async {
        loading = true
        do { items = try await load() } catch { toast = error.localizedDescription }
        loading = false
    }

    private var toastOverlay: some View {
        Group {
            if let toast {
                VStack {
                    Spacer()
                    Text(toast).font(.system(size: 14)).foregroundColor(.white)
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .background(Capsule().fill(Tech.glass.opacity(0.95)))
                        .padding(.bottom, 30)
                }
                .frame(maxWidth: .infinity).allowsHitTesting(false)
            }
        }
    }
}

// MARK: - 键值行

struct KeyValueRow: View {
    let item: KeyValueSetting
    var onSave: (String) -> Void
    var onDelete: () -> Void

    @State private var value = ""

    var body: some View {
        GlassCard(accent: Tech.cyan, borderAlpha: 0.2, glowAlpha: 0.1) {
            VStack(alignment: .leading, spacing: 8) {
                Text(item.key ?? "-")
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                TextField("值", text: $value)
                    .textFieldStyle(.roundedBorder)
                HStack(spacing: 8) {
                    Button("保存") { onSave(value) }
                        .buttonStyle(TechButtonStyle(compact: true))
                    Button("删") { onDelete() }
                        .buttonStyle(TechButtonStyle(compact: true))
                        .tint(Tech.red)
                }
            }
        }
        .onAppear { value = item.value ?? "" }
    }
}
