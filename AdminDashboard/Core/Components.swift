import SwiftUI

// MARK: - 科技背景（渐变 + 光晕 + 网格）

struct TechBackground: View {
    @State private var phase = 0.0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [Tech.bgTop, Tech.bgBottom, Tech.bgTop],
                               startPoint: .top, endPoint: .bottom)
                // 流动光晕
                Circle()
                    .fill(RadialGradient(colors: [Tech.blue.opacity(0.22), .clear],
                                         center: .center,
                                         startRadius: 0,
                                         endRadius: 230))
                    .frame(width: 460, height: 460)
                    .offset(x: -geo.size.width / 3 + CGFloat(phase) * 60,
                            y: -geo.size.height / 4)
                Circle()
                    .fill(RadialGradient(colors: [Tech.purple.opacity(0.20), .clear],
                                         center: .center,
                                         startRadius: 0,
                                         endRadius: 210))
                    .frame(width: 420, height: 420)
                    .offset(x: geo.size.width / 3 - CGFloat(phase) * 50,
                            y: geo.size.height / 3)
                // 网格
                GridLines()
                    .opacity(0.6)
            }
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }
}

/// 半透明科技网格
struct GridLines: View {
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 46
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
            ctx.stroke(path, with: .color(.white.opacity(0.055)), lineWidth: 1)
        }
    }
}

// MARK: - 玻璃卡片

struct GlassCard<Content: View>: View {
    var accent: Color = Tech.cyan
    var borderAlpha: Double = 0.35
    var glowAlpha: Double = 0.22
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(Tech.glass.opacity(0.62).blur(radius: 8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(accent.opacity(borderAlpha), lineWidth: 1)
            )
            .shadow(color: accent.opacity(glowAlpha), radius: 10, x: 0, y: 4)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - 区块标题（霓虹指示条）

struct SectionTitle: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(colors: [Tech.cyan, Tech.blue], startPoint: .top, endPoint: .bottom))
                .frame(width: 4, height: 20)
                .shadow(color: Tech.cyan, radius: 4)
            Text(text)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.top, 14)
        .padding(.bottom, 8)
    }
}

// MARK: - 统计卡片

struct StatCard: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        GlassCard(accent: accent, borderAlpha: 0.3, glowAlpha: 0.18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(accent)
                        .frame(width: 9, height: 9)
                        .shadow(color: accent, radius: 5)
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.72))
                }
                Text(value)
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [.white, accent], startPoint: .leading, endPoint: .trailing))
            }
        }
    }
}

// MARK: - API 统计卡片

struct ApiStatCard: View {
    let title: String
    let success: Int?
    let failed: Int?
    let total: Int?

    private var totalV: Int { total ?? 0 }
    private var sV: Int { success ?? 0 }
    private var fV: Int { failed ?? 0 }
    private var rate: Double { totalV > 0 ? Double(sV) / Double(totalV) : 0 }

    var body: some View {
        GlassCard(borderAlpha: 0.25, glowAlpha: 0.16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.white.opacity(0.9))
                Text("\(totalV)")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [.white, Tech.cyan], startPoint: .leading, endPoint: .trailing))
                HStack {
                    Text("成功 \(sV)").font(.system(size: 12)).foregroundColor(Tech.green)
                    Spacer()
                    Text("失败 \(fV)").font(.system(size: 12)).foregroundColor(Tech.red)
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Tech.track).frame(height: 8)
                        Capsule()
                            .fill(LinearGradient(colors: [Tech.green, Tech.cyan], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(0, g.size.width * rate), height: 8)
                    }
                }
                .frame(height: 8)
                Text(String(format: "%.1f%%", rate * 100))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

// MARK: - 迷你统计（小方块）

struct MiniStat: View {
    let title: String
    let value: String
    var color: Color = Tech.cyan

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
            Text(value).font(.system(size: 20, weight: .bold)).foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Tech.glass.opacity(0.62)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(color.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - 筛选下拉

struct FilterDropdown: View {
    let label: String
    let selected: String
    let options: [(String, String)]
    var onSelect: (String) -> Void

    var body: some View {
        Menu {
            ForEach(options, id: \.0) { opt in
                Button(action: { onSelect(opt.0) }) {
                    HStack {
                        Text(opt.1)
                        if opt.0 == selected { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 11)).foregroundColor(Tech.cyan)
                HStack {
                    Text(options.first { $0.0 == selected }?.1 ?? selected)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.down").font(.system(size: 11)).foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Tech.glass.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Tech.cyan.opacity(0.3), lineWidth: 1))
        }
    }
}

// MARK: - 分页器（上一页/下一页 + 页数信息 + 跳页）

struct PagerRow: View {
    let page: Int
    let total: Int
    let totalPages: Int
    var onChange: (Int) -> Void

    @State private var jump = ""

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button("上一页") { if page > 1 { onChange(page - 1) } }
                    .buttonStyle(TechButtonStyle(enabled: page > 1))
                Spacer()
                Text("第 \(page) / \(totalPages) 页 · 共 \(total) 条")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Button("下一页") { if page < totalPages { onChange(page + 1) } }
                    .buttonStyle(TechButtonStyle(enabled: page < totalPages))
            }
            HStack(spacing: 8) {
                Text("跳到").font(.system(size: 13)).foregroundColor(.white.opacity(0.6))
                TextField("页数", text: $jump)
                    .keyboardType(.numberPad)
                    .modifier(TechFieldStyle())
                    .frame(width: 72)
                Button("跳转") {
                    if let p = Int(jump.trimmingCharacters(in: .whitespaces)) {
                        onChange(min(max(1, p), totalPages))
                    }
                }
                .buttonStyle(TechButtonStyle(compact: true))
                Spacer()
            }
        }
        .onChange(of: page) { _ in jump = "" }
    }
}

// MARK: - 按钮样式

struct TechButtonStyle: ButtonStyle {
    var enabled = true
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 13 : 15, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, compact ? 14 : 18)
            .padding(.vertical, compact ? 7 : 10)
            .background(
                Group {
                    if enabled {
                        Tech.accentGradient
                    } else {
                        LinearGradient(colors: [Color(white: 0.16)], startPoint: .leading, endPoint: .trailing)
                    }
                }
            )
            .clipShape(Capsule())
            .shadow(color: enabled ? Tech.cyan.opacity(configuration.isPressed ? 0.2 : 0.45) : .clear, radius: 8)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// MARK: - 输入框样式（霓虹聚焦）

struct TechFieldStyle: ViewModifier {
    var isFocused = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .foregroundColor(.white)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Tech.glass.opacity(0.5)))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isFocused ? Tech.cyan : Color.white.opacity(0.18), lineWidth: 1)
            )
    }
}

extension View {
    func techFieldStyle(isFocused: Bool = false) -> some View {
        self.modifier(TechFieldStyle(isFocused: isFocused))
    }
}

// MARK: - 标签输入框

struct LabeledField: View {
    let label: String
    @Binding var text: String
    var secure = false
    var keyboard: UIKeyboardType = .default

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 13)).foregroundColor(.white.opacity(0.75))
            Group {
                if secure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                }
            }
            .keyboardType(keyboard)
            .focused($focused)
            .modifier(TechFieldStyle(isFocused: focused))
        }
    }
}

// MARK: - 加载 / 错误

struct LoadingBox: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Tech.cyan))
                .scaleEffect(1.4)
            Text("LOADING")
                .font(.system(size: 13, weight: .medium))
                .tracking(4)
                .foregroundColor(Tech.cyan)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorBox: View {
    let message: String
    var onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("⚠").font(.system(size: 34))
            Text(message).font(.system(size: 14)).foregroundColor(.white.opacity(0.85)).multilineTextAlignment(.center)
            Button("重 试", action: onRetry).buttonStyle(TechButtonStyle())
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Tech.glass.opacity(0.62)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Tech.red.opacity(0.4), lineWidth: 1))
        .padding(24)
    }
}

// MARK: - 行内操作菜单按钮

struct ActionMenuButton: View {
    let isVip: Bool
    var onVip: () -> Void
    var onClose: () -> Void
    var onDetail: (() -> Void)? = nil

    var body: some View {
        Menu {
            Button(isVip ? "续费VIP" : "开通VIP", action: onVip)
            if isVip {
                Button("关闭VIP", action: onClose)
            }
            if let onDetail {
                Button("查看套餐详情", action: onDetail)
            }
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
