//
//  ThemeEditorView.swift
//  DarkReader
//
//  主题详情页：预览、名称、颜色设置、图像设置
//

import SwiftUI

struct ThemeEditorView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @Environment(\.dismiss) private var dismiss

    let existingTheme: DarkTheme?

    @State private var name: String = ""
    @State private var backgroundColor: Color = Color(hex: "#1e1e1e")!
    @State private var textColor: Color = Color(hex: "#e0e0e0")!
    @State private var imageBrightness: Double = 0.75
    @State private var imageGrayscale: Double = 0.0

    @State private var nameError: String? = nil
    @State private var colorError: String? = nil

    private var isEditingCustomTheme: Bool {
        guard let existingTheme else { return false }
        return !existingTheme.isBuiltin
    }

    private var titleText: String {
        existingTheme == nil ? "新建主题" : "主题详情"
    }

    var body: some View {
        NavigationView {
            ZStack {
                SustainabilityBackground()

                Form {
                    Section("预览") {
                        ThemePreviewCard(
                            backgroundColor: backgroundColor,
                            textColor: textColor,
                            secondaryTextColor: derivedSecondaryTextColor,
                            linkColor: derivedLinkColor,
                            borderColor: derivedBorderColor,
                            imageBrightness: imageBrightness,
                            imageGrayscale: imageGrayscale,
                            showsBrandTitle: false,
                            compact: true
                        )
                        .listRowInsets(EdgeInsets())
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Section("名称") {
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("输入主题名称（最多15字）", text: $name)
                                .font(SustainabilityTypography.body)
                                .onChange(of: name) { _ in
                                    if name.count > 15 {
                                        name = String(name.prefix(15))
                                    }
                                    nameError = nil
                                }

                            if let nameError {
                                Text(nameError)
                                    .font(SustainabilityTypography.caption)
                                    .foregroundColor(SustainabilityPalette.danger)
                            }
                        }
                    }

                    Section("图像设置") {
                        ImageAdjustmentSliderRow(
                            title: "亮度",
                            value: $imageBrightness,
                            range: 0.35...1.0,
                            defaultValue: 0.75,
                            displayFormatter: { value in "\(Int(value * 100))%" }
                        )
                        ImageAdjustmentSliderRow(
                            title: "灰度",
                            value: $imageGrayscale,
                            range: 0.0...1.0,
                            defaultValue: 0.0,
                            displayFormatter: { value in "\(Int(value * 100))%" }
                        )

                        if existingTheme?.isBuiltin == true {
                            Text("内置主题保存后会生成一份自定义主题。")
                                .font(SustainabilityTypography.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Section("颜色设置") {
                        ColorPickerRow(title: "背景颜色", description: "网页主背景", color: $backgroundColor)
                        ColorPickerRow(title: "字体颜色", description: "标题与正文", color: $textColor)

                        Button {
                            applyRecommendedTextColor()
                        } label: {
                            Label("自动推荐字体颜色", systemImage: "wand.and.stars")
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

                        if let colorError {
                            Text(colorError)
                                .font(SustainabilityTypography.caption)
                                .foregroundColor(SustainabilityPalette.danger)
                        }
                    }
                }
                .font(SustainabilityTypography.body)
                .tint(SustainabilityPalette.primary)
                .applyListBackgroundClear()
            }
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        save()
                    }
                    .font(SustainabilityTypography.bodyStrong)
                    .foregroundColor(SustainabilityPalette.primary)
                }
            }
            .onAppear {
                prefill()
            }
            .onChange(of: backgroundColor) { _ in
                colorError = nil
            }
            .onChange(of: textColor) { _ in
                colorError = nil
            }
        }
        .sustainabilityChrome()
    }

    private func prefill() {
        guard let existingTheme else {
            applyRecommendedTextColor()
            return
        }

        name = existingTheme.isBuiltin ? existingTheme.localizedDisplayName : existingTheme.name
        backgroundColor = Color(hex: existingTheme.backgroundColor) ?? backgroundColor
        textColor = Color(hex: existingTheme.textColor) ?? textColor
        imageBrightness = clampBrightness(existingTheme.imageBrightness)
        imageGrayscale = clampGrayscale(existingTheme.imageGrayscale)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
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

        let backgroundHex = backgroundColor.toHexString() ?? "#1e1e1e"
        let textHex = textColor.toHexString() ?? "#e0e0e0"
        let secondaryHex = derivedSecondaryTextColor.toHexString() ?? "#999999"
        let linkHex = derivedLinkColor.toHexString() ?? "#4da6ff"
        let borderHex = derivedBorderColor.toHexString() ?? "#444444"

        let newThemeId: String
        let createdAt: Date

        if isEditingCustomTheme {
            newThemeId = existingTheme!.id
            createdAt = existingTheme!.createdAt
        } else {
            var generatedId = DarkTheme.generateCustomId()
            while dataManager.themes.contains(where: { $0.id == generatedId }) {
                generatedId = DarkTheme.generateCustomId()
            }
            newThemeId = generatedId
            createdAt = Date()
        }

        let newTheme = DarkTheme(
            id: newThemeId,
            name: trimmedName,
            backgroundColor: backgroundHex,
            textColor: textHex,
            secondaryTextColor: secondaryHex,
            linkColor: linkHex,
            borderColor: borderHex,
            imageBrightness: clampBrightness(imageBrightness),
            imageGrayscale: clampGrayscale(imageGrayscale),
            isBuiltin: false,
            createdAt: createdAt,
            updatedAt: Date()
        )

        if isEditingCustomTheme {
            dataManager.updateTheme(newTheme)
        } else {
            dataManager.addCustomTheme(newTheme)
        }

        dismiss()
    }

    private var currentContrastRatio: Double {
        contrastRatio(backgroundColor, textColor)
    }

    private var derivedSecondaryTextColor: Color {
        guard let bg = rgbComponents(backgroundColor), let fg = rgbComponents(textColor) else {
            return Color(hex: "#999999") ?? .secondary
        }
        return colorFromRGB(mix(fg, bg, amount: 0.35))
    }

    private var derivedLinkColor: Color {
        guard let bg = rgbComponents(backgroundColor), let fg = rgbComponents(textColor) else {
            return Color(hex: "#4da6ff") ?? .blue
        }
        let bgLum = relativeLuminance(bg)
        let target: (Double, Double, Double) = bgLum < 0.4 ? (0.36, 0.70, 1.0) : (0.12, 0.32, 0.78)
        return colorFromRGB(mix(fg, target, amount: 0.5))
    }

    private var derivedBorderColor: Color {
        guard let bg = rgbComponents(backgroundColor) else {
            return Color(hex: "#444444") ?? .gray
        }
        let bgLum = relativeLuminance(bg)
        let border = bgLum < 0.4
            ? mix(bg, (1, 1, 1), amount: 0.18)
            : mix(bg, (0, 0, 0), amount: 0.14)
        return colorFromRGB(border)
    }

    private func applyRecommendedTextColor() {
        guard let bg = rgbComponents(backgroundColor) else { return }
        let bgLum = relativeLuminance(bg)

        var candidate = bgLum < 0.42 ? (0.92, 0.93, 0.96) : (0.10, 0.11, 0.14)
        candidate = ensuredContrastText(base: candidate, background: bg, threshold: 4.5)
        textColor = colorFromRGB(candidate)
    }

    private func ensuredContrastText(
        base: (Double, Double, Double),
        background: (Double, Double, Double),
        threshold: Double
    ) -> (Double, Double, Double) {
        let bgLum = relativeLuminance(background)
        let target: (Double, Double, Double) = bgLum < 0.5 ? (1, 1, 1) : (0, 0, 0)
        var ratio = contrastRatio(colorFromRGB(background), colorFromRGB(base))
        if ratio >= threshold {
            return base
        }

        var factor = 0.1
        while factor <= 1.0 {
            let candidate = mix(base, target, amount: factor)
            ratio = contrastRatio(colorFromRGB(background), colorFromRGB(candidate))
            if ratio >= threshold {
                return candidate
            }
            factor += 0.1
        }

        return target
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
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }

        let r = linearize(rgb.0)
        let g = linearize(rgb.1)
        let b = linearize(rgb.2)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
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

    private func clampBrightness(_ value: Double) -> Double {
        min(max(value, 0.35), 1.0)
    }

    private func clampGrayscale(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
    }
}

struct ColorPickerRow: View {
    let title: String
    let description: String
    @Binding var color: Color

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title))
                    .font(SustainabilityTypography.body)
                Text(LocalizedStringKey(description))
                    .font(SustainabilityTypography.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            ColorPicker("", selection: $color, supportsOpacity: false)
                .labelsHidden()
        }
        .sustainabilityInteractiveRow()
    }
}

private struct ImageAdjustmentSliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let defaultValue: Double
    let displayFormatter: (Double) -> String

    var body: some View {
        HStack(spacing: 10) {
            Text(LocalizedStringKey(title))
                .font(SustainabilityTypography.bodyStrong)
                .frame(width: 42, alignment: .leading)

            Slider(value: $value, in: range)

            Text(displayFormatter(value))
                .font(SustainabilityTypography.caption)
                .foregroundColor(.secondary)
                .frame(width: 46, alignment: .trailing)

            Button {
                value = defaultValue
            } label: {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.secondary.opacity(0.75))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("重置\(title)")
        }
        .sustainabilityInteractiveRow()
    }
}

struct ThemePreviewCard: View {
    let backgroundColor: Color
    let textColor: Color
    let secondaryTextColor: Color
    let linkColor: Color
    let borderColor: Color
    let imageBrightness: Double
    let imageGrayscale: Double
    let showsBrandTitle: Bool
    let compact: Bool

    init(
        backgroundColor: Color,
        textColor: Color,
        secondaryTextColor: Color,
        linkColor: Color,
        borderColor: Color,
        imageBrightness: Double = 0.75,
        imageGrayscale: Double = 0.0,
        showsBrandTitle: Bool = true,
        compact: Bool = false
    ) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.secondaryTextColor = secondaryTextColor
        self.linkColor = linkColor
        self.borderColor = borderColor
        self.imageBrightness = min(max(imageBrightness, 0.35), 1.0)
        self.imageGrayscale = min(max(imageGrayscale, 0.0), 1.0)
        self.showsBrandTitle = showsBrandTitle
        self.compact = compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "safari.fill")
                    .foregroundColor(secondaryTextColor)
                Text(NSLocalizedString("themeEditor.preview.title", comment: ""))
                    .font(SustainabilityTypography.caption)
                    .foregroundColor(secondaryTextColor)
                Spacer()
            }
            .padding(.horizontal, compact ? 12 : 14)
            .padding(.vertical, compact ? 8 : 10)
            .background(backgroundColor.opacity(0.72))

            Divider().background(borderColor)

            HStack(alignment: .top, spacing: compact ? 8 : 12) {
                VStack(alignment: .leading, spacing: compact ? 6 : 8) {
                    if showsBrandTitle {
                        Text("NoirFeed")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(secondaryTextColor)
                    }

                    Text("新主题正在制作中")
                        .font(SustainabilityTypography.bodyStrong)
                        .foregroundColor(textColor)

                    Text("预览会实时显示背景、字体和图像参数。")
                        .font(SustainabilityTypography.caption)
                        .foregroundColor(textColor)
                        .lineSpacing(compact ? 1 : 2)
                        .lineLimit(compact ? 2 : nil)

                    if compact {
                        Text("图像滤镜已应用")
                            .font(SustainabilityTypography.caption)
                            .foregroundColor(secondaryTextColor)
                    } else {
                        HStack(spacing: 8) {
                            Text("阅读更多")
                                .font(SustainabilityTypography.caption)
                                .foregroundColor(linkColor)
                            Circle()
                                .fill(borderColor.opacity(0.75))
                                .frame(width: 5, height: 5)
                            Text("图像滤镜已应用")
                                .font(SustainabilityTypography.caption)
                                .foregroundColor(secondaryTextColor)
                        }
                    }
                }

                Spacer(minLength: compact ? 4 : 8)

                PreviewMediaTile(
                    brightness: imageBrightness,
                    grayscale: imageGrayscale,
                    size: compact ? 78 : 96
                )
            }
            .padding(compact ? 10 : 14)
        }
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor.opacity(0.45), lineWidth: 1)
        )
    }
}

private struct PreviewMediaTile: View {
    let brightness: Double
    let grayscale: Double
    let size: CGFloat

    init(brightness: Double, grayscale: Double, size: CGFloat = 96) {
        self.brightness = brightness
        self.grayscale = grayscale
        self.size = size
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.15, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#3C8D2F") ?? .green,
                            Color(hex: "#BFC97A") ?? .yellow,
                            Color(hex: "#5C8CD1") ?? .blue
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(Color(hex: "#FDBA16") ?? .yellow)
                .frame(width: size * 0.46, height: size * 0.46)
                .overlay(
                    Circle()
                        .stroke(Color(hex: "#78350F") ?? .brown, lineWidth: max(4, size * 0.06))
                )

            Circle()
                .fill(Color(hex: "#92400E") ?? .brown)
                .frame(width: size * 0.15, height: size * 0.15)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.15, style: .continuous))
        .grayscale(min(max(grayscale, 0.0), 1.0))
        .brightness((min(max(brightness, 0.35), 1.0) - 1.0) * 0.45)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.15, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
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
