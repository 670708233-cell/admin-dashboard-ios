import SwiftUI

struct AiKeysView: View {
    @State private var keys: [AiKey] = []
    @State private var stats: AiKeyStats?
    @State private var config: AiKeyConfig?
    @State private var loading = false
    @State private var error: String?
    @State private var editing: AiKey?
    @State private var adding = false
    @State private var editingConfig = false
    @State private var toast: String?
    @State private var toastTask: Task<Void, Never>?

    private var now: Int64 { Int64(Date().timeIntervalSince1970 * 1000) }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                MiniStat(title: "总数", value: fmt(stats?.total))
                MiniStat(title: "启用", value: fmt(stats?.active), color: Tech.green)
                MiniStat(title: "禁用", value: fmt(stats?.disabled), color: Tech.red)
                MiniStat(title: "冷却中", value: fmt(stats?.cooling), color: Tech.yellow)
            }

            // 熔断配置
            GlassCard(borderAlpha: 0.25, glowAlpha: 0.12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("限流熔断配置").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                        Text("冷却时长: \(fmt(config?.cooldownSeconds)) 秒")
                            .font(.system(size: 13)).foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    Button("修改") { editingConfig = true }
                        .buttonStyle(TechButtonStyle(compact: true))
                }
            }

            if loading && keys.isEmpty {
                LoadingBox()
            } else if let error, keys.isEmpty {
                ErrorBox(message: error) { load() }
            } else {
                List {
                    ForEach(keys) { k in
                        AiKeyCard(
                            key: k,
                            cooling: (k.cooldownUntil ?? 0) > now,
                            onTest: { run({ try await APIClient.shared.aiKeyTest(AiKeyTestReq(id: k.id ?? 0)) }, msg: "测试完成") },
                            onToggle: { run({ try await APIClient.shared.aiKeyToggle(AiKeyToggleReq(id: k.id ?? 0, status: (k.status == 1) ? 0 : 1)) }, msg: "状态已切换") },
                            onReset: { run({ try await APIClient.shared.aiKeyResetCooldown(AiKeyCooldownReq(id: k.id ?? 0)) }, msg: "已重置熔断") },
                            onEdit: { editing = k },
                            onDelete: { run({ try await APIClient.shared.aiKeyDelete(AiKeyDeleteReq(id: k.id ?? 0)) }, msg: "已删除") }
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .refreshable { load() }
            }
        }
        .padding(16)
        .overlay(alignment: .bottomTrailing) {
            Button { adding = true } label: {
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
        .sheet(isPresented: $adding) {
            AiKeyEditSheet(key: nil) { name, provider, apiKey, remark in
                run({ try await APIClient.shared.aiKeyAdd(AiKeyAddReq(name: name, provider: provider, apiKey: apiKey, remark: remark)) }, msg: "已添加")
            }
        }
        .sheet(item: $editing) { k in
            AiKeyEditSheet(key: k) { name, provider, apiKey, remark in
                run({ try await APIClient.shared.aiKeyUpdate(AiKeyUpdateReq(id: k.id ?? 0, name: name, provider: provider, apiKey: apiKey, remark: remark, status: k.status)) }, msg: "已保存")
            }
        }
        .sheet(isPresented: $editingConfig) {
            ConfigSheet(current: config?.cooldownSeconds ?? 0) { sec in
                run({ try await APIClient.shared.aiKeySaveConfig(AiKeySaveConfigReq(cooldownSeconds: sec)) }, msg: "已保存配置")
            }
        }
        .overlay(toastOverlay)
    }

    private func run(_ op: @escaping () async throws -> Void, msg: String) {
        Task {
            do { try await op(); showToast(msg); load() }
            catch { showToast(error.localizedDescription) }
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
                keys = try await APIClient.shared.aiKeys()
                stats = try? await APIClient.shared.aiKeyStats()
                config = try? await APIClient.shared.aiKeyConfig()
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }
}

// MARK: - Key 卡片

struct AiKeyCard: View {
    let key: AiKey
    let cooling: Bool
    var onTest: () -> Void
    var onToggle: () -> Void
    var onReset: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        GlassCard(accent: Tech.cyan, borderAlpha: 0.2, glowAlpha: 0.12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(key.name ?? "-")
                            .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                        Text("厂商: \(key.provider ?? "-") | 状态: \((key.status == 1) ? "启用" : "禁用") | \(cooling ? "冷却中" : "正常")")
                            .font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
                        Text("调用: \(key.usedCount ?? 0) | 失败: \(key.failCount ?? 0)")
                            .font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    Button("测试", action: onTest)
                        .buttonStyle(TechButtonStyle(compact: true))
                }
                HStack(spacing: 8) {
                    Button((key.status == 1) ? "禁用" : "启用", action: onToggle)
                        .buttonStyle(TechButtonStyle(compact: true))
                    Button("重置熔断", action: onReset)
                        .buttonStyle(TechButtonStyle(compact: true))
                    Button("编辑", action: onEdit)
                        .buttonStyle(TechButtonStyle(compact: true))
                    Button("删除", action: onDelete)
                        .buttonStyle(TechButtonStyle(compact: true))
                        .tint(Tech.red)
                }
            }
        }
    }
}

// MARK: - 新增/编辑 Sheet

struct AiKeyEditSheet: View {
    let key: AiKey?
    var onConfirm: (String, String?, String?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var provider = ""
    @State private var apiKey = ""
    @State private var remark = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                LabeledField(label: "名称", text: $name)
                LabeledField(label: "厂商", text: $provider)
                LabeledField(label: "API Key", text: $apiKey)
                LabeledField(label: "备注(可选)", text: $remark)
                Spacer()
            }
            .padding(20)
            .background(Tech.bgBottom.ignoresSafeArea())
            .navigationTitle(key == nil ? "新增 AI Key" : "编辑 AI Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundColor(Tech.cyan)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onConfirm(name, provider.isEmpty ? nil : provider, apiKey, remark.isEmpty ? nil : remark)
                        dismiss()
                    }
                    .foregroundColor(Tech.cyan)
                    .disabled(name.isEmpty || apiKey.isEmpty)
                }
            }
            .onAppear {
                if let key {
                    name = key.name ?? ""
                    provider = key.provider ?? ""
                    apiKey = key.apiKey ?? ""
                    remark = key.remark ?? ""
                }
            }
        }
    }
}

// MARK: - 熔断配置 Sheet

struct ConfigSheet: View {
    let current: Int
    var onConfirm: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var sec = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                LabeledField(label: "冷却秒数", text: $sec, keyboard: .numberPad)
                Spacer()
            }
            .padding(20)
            .background(Tech.bgBottom.ignoresSafeArea())
            .navigationTitle("修改熔断冷却时长")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundColor(Tech.cyan)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onConfirm(Int(sec) ?? 0)
                        dismiss()
                    }
                    .foregroundColor(Tech.cyan)
                }
            }
            .onAppear { sec = "\(current)" }
        }
    }
}
