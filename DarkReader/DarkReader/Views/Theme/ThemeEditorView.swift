//
//  ThemeEditorView.swift
//  DarkReader
//
//  自定义主题编辑器：5个颜色选择器 + 实时预览
//

import SwiftUI

struct ThemeEditorView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @Environment(\.dismiss) private var dismiss

    // 如果是编辑现有主题则传入，否则为 nil（新建）
    let existingTheme: DarkTheme?

    // 编辑中的颜色值
    @State private var name: String = ""
    @State private var backgroundColor: Color = Color(hex: "#1e1e1e")!
    @State private var textColor: Color = Color(hex: "#e0e0e0")!
    @State private var secondaryTextColor: Color = Color(hex: "#999999")!
    @State private var linkColor: Color = Color(hex: "#4da6ff")!
    @State private var borderColor: Color = Color(hex: "#444444")!

    // 校验
    @State private var nameError: String? = nil
    @State private var colorError: String? = nil

    var isEditing: Bool { existingTheme != nil }

    var body: some View {
        NavigationView {
            ZStack {
                SustainabilityBackground()

                Form {
                    // ── 主题名称
                    Section("主题名称") {
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("输入主题名称（最多15字）", text: $name)
                                .font(SustainabilityTypography.body)
                                .onChange(of: name) { _ in
                                    if name.count > 15 { name = String(name.prefix(15)) }
                                    nameError = nil
                                }
                            if let err = nameError {
                                Text(err).font(SustainabilityTypography.caption).foregroundColor(SustainabilityPalette.danger)
                            }
                        }
                    }

                    // ── 实时预览
                    Section("效果预览") {
                        ThemePreviewCard(
                            backgroundColor: backgroundColor,
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                            linkColor: linkColor,
                            borderColor: borderColor
                        )
                        .listRowInsets(EdgeInsets())
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // ── 颜色配置
                    Section("颜色配置") {
                        ColorPickerRow(title: "背景色", description: "网页主背景颜色", color: $backgroundColor)
                        ColorPickerRow(title: "主要文本色", description: "标题、正文等主要文字", color: $textColor)
                        ColorPickerRow(title: "次级文本色", description: "说明文字、时间戳等", color: $secondaryTextColor)
                        ColorPickerRow(title: "链接颜色", description: "超链接和强调元素", color: $linkColor)
                        ColorPickerRow(title: "边框颜色", description: "分割线、表格边框等", color: $borderColor)
                        Button {
                            applyRecommendedPalette()
                        } label: {
                            Label("基于背景自动推荐配色", systemImage: "wand.and.stars")
                                .font(SustainabilityTypography.bodyStrong)
                        }
                        Text(
                            String(
                                format: NSLocalizedString("themeEditor.contrastLabel", comment: ""),
                                currentContrastRatio
                            )
                        )
                            .font(SustainabilityTypography.caption)
                            .foregroundColor(currentContrastRatio >= 4.5 ? .secondary : SustainabilityPalette.warm)
                        if let err = colorError {
                            Text(err)
                                .font(SustainabilityTypography.caption)
                                .foregroundColor(SustainabilityPalette.danger)
                        }
                    }
                }
                .font(SustainabilityTypography.body)
                .tint(SustainabilityPalette.primary)
                .applyListBackgroundClear()
            }
            .navigationTitle(isEditing ? "编辑主题" : "新建主题")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { save() }
                        .font(SustainabilityTypography.bodyStrong)
                        .foregroundColor(SustainabilityPalette.primary)
                }
            }
            .onAppear { prefill() }
            .onChange(of: backgroundColor) { _ in colorError = nil }
            .onChange(of: textColor) { _ in colorError = nil }
            .onChange(of: secondaryTextColor) { _ in colorError = nil }
            .onChange(of: linkColor) { _ in colorError = nil }
            .onChange(of: borderColor) { _ in colorError = nil }
        }
        .sustainabilityChrome()
    }

    // MARK: - 初始化与保存

    private func prefill() {
        if let theme = existingTheme {
            name = theme.name
            backgroundColor      = Color(hex: theme.backgroundColor)      ?? backgroundColor
            textColor            = Color(hex: theme.textColor)            ?? textColor
            secondaryTextColor   = Color(hex: theme.secondaryTextColor)   ?? secondaryTextColor
            linkColor            = Color(hex: theme.linkColor)            ?? linkColor
            borderColor          = Color(hex: theme.borderColor)          ?? borderColor
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        colorError = nil
        guard !trimmedName.isEmpty else {
            nameError = NSLocalizedString("themeEditor.nameRequired", comment: "")
            return
        }
        guard currentContrastRatio >= 4.5 else {
            colorError = String(
                format: NSLocalizedString("themeEditor.colorError", comment: ""),
                currentContrastRatio
            )
            return
        }

        let newTheme = DarkTheme(
            id: existingTheme?.id ?? DarkTheme.generateCustomId(),
            name: trimmedName,
            backgroundColor:    backgroundColor.toHexString()    ?? "#1e1e1e",
            textColor:          textColor.toHexString()          ?? "#e0e0e0",
            secondaryTextColor: secondaryTextColor.toHexString() ?? "#999999",
            linkColor:          linkColor.toHexString()          ?? "#4da6ff",
            borderColor:        borderColor.toHexString()        ?? "#444444",
            isBuiltin: false,
            createdAt: existingTheme?.createdAt ?? Date(),
            updatedAt: Date()
        )

        if isEditing {
            dataManager.updateTheme(newTheme)
        } else {
            dataManager.addCustomTheme(newTheme)
        }

        dismiss()
    }

    private var currentContrastRatio: Double {
        contrastRatio(backgroundColor, textColor)
    }

    private func contrastRatio(_ background: Color, _ foreground: Color) -> Double {
        guard let bg = rgbComponents(background), let fg = rgbComponents(foreground) else { return 1.0 }
        let bgLum = relativeLuminance(bg)
        let fgLum = relativeLuminance(fg)
        let lighter = max(bgLum, fgLum)
        let darker = min(bgLum, fgLum)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func rgbComponents(_ color: Color) -> (Double, Double, Double)? {
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return (Double(r), Double(g), Double(b))
    }

    private func relativeLuminance(_ rgb: (Double, Double, Double)) -> Double {
        func linearize(_ c: Double) -> Double {
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let r = linearize(rgb.0)
        let g = linearize(rgb.1)
        let b = linearize(rgb.2)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    private func applyRecommendedPalette() {
        guard let bg = rgbComponents(backgroundColor) else { return }
        let bgLum = relativeLuminance(bg)

        var baseText = bgLum < 0.4 ? mix(bg, (1, 1, 1), amount: 0.86) : mix(bg, (0, 0, 0), amount: 0.84)
        baseText = ensuredContrastText(base: baseText, background: bg, threshold: 4.5)
        let secondary = mix(baseText, bg, amount: 0.35)
        let link = bgLum < 0.4 ? (0.36, 0.70, 1.0) : (0.12, 0.32, 0.78)
        let border = bgLum < 0.4 ? mix(bg, (1, 1, 1), amount: 0.18) : mix(bg, (0, 0, 0), amount: 0.14)

        textColor = colorFromRGB(baseText)
        secondaryTextColor = colorFromRGB(secondary)
        linkColor = colorFromRGB(link)
        borderColor = colorFromRGB(border)
    }

    private func ensuredContrastText(
        base: (Double, Double, Double),
        background: (Double, Double, Double),
        threshold: Double
    ) -> (Double, Double, Double) {
        let bgLum = relativeLuminance(background)
        let target: (Double, Double, Double) = bgLum < 0.5 ? (1, 1, 1) : (0, 0, 0)
        var ratio = contrastRatio(colorFromRGB(background), colorFromRGB(base))
        if ratio >= threshold { return base }

        var factor = 0.1
        while factor <= 1.0 {
            let candidate = mix(base, target, amount: factor)
            ratio = contrastRatio(colorFromRGB(background), colorFromRGB(candidate))
            if ratio >= threshold { return candidate }
            factor += 0.1
        }
        return target
    }

    private func mix(
        _ a: (Double, Double, Double),
        _ b: (Double, Double, Double),
        amount: Double
    ) -> (Double, Double, Double) {
        let t = min(max(amount, 0), 1)
        return (
            a.0 + (b.0 - a.0) * t,
            a.1 + (b.1 - a.1) * t,
            a.2 + (b.2 - a.2) * t
        )
    }

    private func colorFromRGB(_ rgb: (Double, Double, Double)) -> Color {
        Color(.sRGB, red: rgb.0, green: rgb.1, blue: rgb.2, opacity: 1)
    }
}

// MARK: - 颜色选择器行

struct ColorPickerRow: View {
    let title: String
    let description: String
    @Binding var color: Color

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title)).font(SustainabilityTypography.body)
                Text(LocalizedStringKey(description)).font(SustainabilityTypography.caption).foregroundColor(.secondary)
            }
            Spacer()
            ColorPicker("", selection: $color, supportsOpacity: false)
                .labelsHidden()
        }
        .sustainabilityInteractiveRow()
    }
}

// MARK: - 主题预览卡片

struct ThemePreviewCard: View {
    let backgroundColor: Color
    let textColor: Color
    let secondaryTextColor: Color
    let linkColor: Color
    let borderColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 模拟网页标题栏
            HStack {
                Image(systemName: "safari.fill")
                    .foregroundColor(secondaryTextColor)
                Text(NSLocalizedString("themeEditor.preview.title", comment: ""))
                    .font(SustainabilityTypography.caption)
                    .foregroundColor(secondaryTextColor)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(backgroundColor.opacity(0.7))

            Divider().background(borderColor)

            // 模拟网页内容
            VStack(alignment: .leading, spacing: 8) {
                Text("网页标题示例")
                    .font(SustainabilityTypography.bodyStrong)
                    .foregroundColor(textColor)

                Text("这是一段示例正文内容，展示深色模式下文字的可读性和舒适度。")
                    .font(SustainabilityTypography.caption)
                    .foregroundColor(textColor)
                    .lineSpacing(2)

                HStack {
                    Text("次级说明文字")
                        .font(SustainabilityTypography.caption)
                        .foregroundColor(secondaryTextColor)
                    Spacer()
                    Text("阅读更多")
                        .font(SustainabilityTypography.caption)
                        .foregroundColor(linkColor)
                }

                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(borderColor.opacity(0.5))
                        .frame(height: 1)
                }
            }
            .padding(12)
        }
        .background(backgroundColor)
    }
}

private extension View {
    @ViewBuilder
    func applyListBackgroundClear() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}
