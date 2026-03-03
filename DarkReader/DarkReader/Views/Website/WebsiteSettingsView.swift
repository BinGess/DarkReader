//
//  WebsiteSettingsView.swift
//  DarkReader
//
//  网站设置：展示访问过的网站，并支持按站点配置启用状态、主题和主题颜色
//

import SwiftUI

struct WebsiteSettingsView: View {
    @EnvironmentObject var dataManager: SharedDataManager

    var body: some View {
        ZStack {
            SustainabilityBackground()

            ScrollView {
                VStack(spacing: 16) {
                    overviewCard

                    if dataManager.visitedDomainsSorted.isEmpty {
                        emptyState
                    } else {
                        domainsCard
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
            .font(SustainabilityTypography.body)
        }
        .navigationTitle("网站设置")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var overviewCard: some View {
        SustainabilityCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    SustainabilitySectionTitle("站点规则中心", subtitle: "访问过的网站会在这里集中管理")
                    Spacer()
                    SustainabilityStatusPill(
                        icon: "globe.asia.australia.fill",
                        text: String(
                            format: NSLocalizedString("website.visitedCount", comment: ""),
                            dataManager.visitedDomainsSorted.count
                        ),
                        color: SustainabilityPalette.cta
                    )
                }

                HStack(spacing: 12) {
                    websiteMetricCard(title: "已访问站点", value: "\(dataManager.visitedDomainsSorted.count)")
                    websiteMetricCard(title: "已自定义规则", value: "\(dataManager.siteRules.count)")
                }

                Text("点击任意站点即可覆盖默认设置，单独配置启用状态、主题与颜色。")
                    .font(SustainabilityTypography.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var domainsCard: some View {
        SustainabilityCard {
            VStack(alignment: .leading, spacing: 14) {
                SustainabilitySectionTitle("全部网站", subtitle: "按最近访问顺序排列")

                ForEach(dataManager.visitedDomainsSorted, id: \.self) { domain in
                    NavigationLink {
                        WebsiteSettingDetailView(domain: domain)
                            .environmentObject(dataManager)
                    } label: {
                        WebsiteDomainRow(domain: domain)
                            .environmentObject(dataManager)
                    }
                    .buttonStyle(.plain)

                    if domain != dataManager.visitedDomainsSorted.last {
                        Divider()
                            .overlay(Color.primary.opacity(0.09))
                            .padding(.leading, 54)
                    }
                }
            }
        }
    }

    private func websiteMetricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(title))
                .font(SustainabilityTypography.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(SustainabilityTypography.title)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var emptyState: some View {
        SustainabilityCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(SustainabilityTypography.subBodyStrong)
                        .foregroundColor(SustainabilityPalette.info)
                    Text("暂无访问记录")
                        .font(SustainabilityTypography.bodyStrong)
                }

                Text("在 Safari 浏览网页后，这里会自动显示已访问网站，支持按站点单独设置。")
                    .font(SustainabilityTypography.subBody)
                    .foregroundColor(.secondary)

                Text("建议先访问 1-2 个常用网站，再回来配置。")
                    .font(SustainabilityTypography.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct WebsiteSettingDetailView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @Environment(\.colorScheme) private var colorScheme

    let domain: String

    @State private var selectedMode: SiteMode = .follow
    @State private var selectedThemeId = ""
    @State private var useCustomColors = false
    @State private var showColorEditor = false
    @State private var justApplied = false

    @State private var backgroundColor: Color = Color(hex: "#1e1e1e")!
    @State private var textColor: Color = Color(hex: "#e0e0e0")!
    @State private var secondaryTextColor: Color = Color(hex: "#999999")!
    @State private var linkColor: Color = Color(hex: "#4da6ff")!
    @State private var borderColor: Color = Color(hex: "#444444")!
    @State private var lastRuleSnapshot = ""

    private var dedicatedThemeId: String {
        let normalized = String(
            domain.lowercased().map { ch in
                (ch.isLetter || ch.isNumber) ? ch : "_"
            }
        )
        return "site_theme_\(normalized)"
    }

    var body: some View {
        ZStack {
            SustainabilityBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerBlock
                    defaultSettingCard

                    if useCustomColors {
                        colorPreviewCard
                    }
                }
                .padding(.top, 14)
                .padding(.bottom, 98)
            }
            .font(SustainabilityTypography.body)
        }
        .navigationTitle("网站设置")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            bottomActionBar
        }
        .sheet(isPresented: $showColorEditor) {
            siteColorEditorSheet
        }
        .onAppear {
            setupInitialState()
        }
        .onChange(of: dataManager.siteRules) { _ in
            // 扩展侧改了站点规则后，详情页保持与共享容器一致。
            if ruleSnapshot() != lastRuleSnapshot {
                setupInitialState()
            }
        }
        .onChange(of: dataManager.globalConfig.defaultThemeId) { _ in
            if selectedThemeId.isEmpty && !useCustomColors {
                refreshColorFromTheme()
            }
        }
        .onChange(of: dataManager.themes) { _ in
            if selectedThemeId.isEmpty || selectedThemeId == dedicatedThemeId {
                refreshColorFromTheme()
            }
        }
    }

    private var headerBlock: some View {
        SustainabilityCard {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(SustainabilityPalette.cta.opacity(0.2))
                        .frame(width: 50, height: 50)
                    Text(String(domain.prefix(1)).uppercased())
                        .font(SustainabilityTypography.title)
                        .foregroundColor(SustainabilityPalette.cta)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(domain)
                        .font(SustainabilityTypography.title)
                        .lineLimit(1)

                    Text("站点级策略将覆盖全局设置。")
                        .font(SustainabilityTypography.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 6) {
                        siteBadge(text: modeBadgeText, color: modeBadgeColor)
                        if !selectedThemeId.isEmpty {
                            siteBadge(text: selectedThemeDisplayName, color: SustainabilityPalette.info)
                        }
                    }
                }

                Spacer()
            }
        }
        .padding(.horizontal, 18)
    }

    private var defaultSettingCard: some View {
        SustainabilityCard {
            VStack(alignment: .leading, spacing: 0) {
                SustainabilitySectionTitle(
                    "网站策略",
                    subtitle: String(format: NSLocalizedString("website.subtitle.onlyForDomain", comment: ""), domain)
                )
                Divider()
                    .overlay(Color.primary.opacity(0.09))
                    .padding(.vertical, 14)
                modeRow
                Divider()
                    .overlay(Color.primary.opacity(0.09))
                    .padding(.vertical, 14)
                themeRow
                Divider()
                    .overlay(Color.primary.opacity(0.09))
                    .padding(.vertical, 14)
                colorRow
            }
        }
        .padding(.horizontal, 18)
    }

    private var modeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                SiteSettingIconBadge(icon: "power", color: SustainabilityPalette.cta)
                Text("启用模式")
                    .font(SustainabilityTypography.bodyStrong)
                Spacer()
            }

            Picker("模式", selection: $selectedMode) {
                Text("自动").tag(SiteMode.follow)
                Text("开启").tag(SiteMode.on)
                Text("关闭").tag(SiteMode.off)
            }
            .pickerStyle(.segmented)

            Text(LocalizedStringKey(modeDescription))
                .font(SustainabilityTypography.caption)
                .foregroundColor(.secondary)
        }
        .sustainabilityInteractiveRow()
    }

    private var themeRow: some View {
        HStack(spacing: 12) {
            SiteSettingIconBadge(icon: "paintbrush.fill", color: SustainabilityPalette.success)
            VStack(alignment: .leading, spacing: 4) {
                Text("主题")
                    .font(SustainabilityTypography.bodyStrong)
                Text(String(format: NSLocalizedString("website.currentThemeFormat", comment: ""), selectedThemeDisplayName))
                    .font(SustainabilityTypography.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Menu {
                Button("跟随默认主题") {
                    selectedThemeId = ""
                    if !useCustomColors {
                        refreshColorFromTheme()
                    }
                }

                ForEach(dataManager.themes) { theme in
                    Button(theme.localizedDisplayName) {
                        selectedThemeId = theme.id
                        if theme.id != dedicatedThemeId {
                            useCustomColors = false
                        }
                        refreshColorFromTheme()
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedThemeDisplayName)
                        .font(SustainabilityTypography.subBodyStrong)
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(SustainabilityTypography.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(SustainabilityPalette.elevated(colorScheme))
                .clipShape(Capsule())
            }
        }
        .sustainabilityInteractiveRow()
    }

    private var colorRow: some View {
        Button {
            showColorEditor = true
        } label: {
            HStack(spacing: 12) {
                SiteSettingIconBadge(icon: "slider.horizontal.3", color: SustainabilityPalette.warm)
                VStack(alignment: .leading, spacing: 2) {
                    Text("主题颜色")
                        .font(SustainabilityTypography.bodyStrong)
                    Text(useCustomColors ? "已启用网站独立颜色" : "跟随主题默认颜色")
                        .font(SustainabilityTypography.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 6) {
                        ForEach(0..<previewSwatches.count, id: \.self) { index in
                            Circle()
                                .fill(previewSwatches[index])
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.45), lineWidth: 0.5)
                                )
                        }
                    }
                    .padding(.top, 2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .sustainabilityInteractiveRow()
        }
        .buttonStyle(.plain)
    }

    private var colorPreviewCard: some View {
        SustainabilityCard {
            VStack(alignment: .leading, spacing: 10) {
                SustainabilitySectionTitle("颜色预览", subtitle: "当前站点独立颜色效果")
                ThemePreviewCard(
                    backgroundColor: backgroundColor,
                    textColor: textColor,
                    secondaryTextColor: secondaryTextColor,
                    linkColor: linkColor,
                    borderColor: borderColor
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(.horizontal, 18)
    }

    private var siteColorEditorSheet: some View {
        NavigationView {
            Form {
                Section("网站独立颜色") {
                    Toggle("启用网站独立颜色", isOn: $useCustomColors)
                        .font(SustainabilityTypography.body)
                        .onChange(of: useCustomColors) { enabled in
                            if enabled {
                                selectedThemeId = dedicatedThemeId
                            } else if selectedThemeId == dedicatedThemeId {
                                selectedThemeId = ""
                                refreshColorFromTheme()
                            }
                        }

                    Text(String(format: NSLocalizedString("website.dedicatedTheme.hint", comment: ""), domain))
                        .font(SustainabilityTypography.caption)
                        .foregroundColor(.secondary)
                }

                if useCustomColors {
                    Section("颜色编辑") {
                        ColorPickerRow(title: "背景色", description: "该网站页面背景", color: $backgroundColor)
                        ColorPickerRow(title: "主要文本色", description: "标题与正文", color: $textColor)
                        ColorPickerRow(title: "次级文本色", description: "说明文字", color: $secondaryTextColor)
                        ColorPickerRow(title: "链接颜色", description: "超链接与强调元素", color: $linkColor)
                        ColorPickerRow(title: "边框颜色", description: "分割线/边框", color: $borderColor)

                        Button {
                            applyRecommendedPalette()
                        } label: {
                            Label("推荐配色", systemImage: "wand.and.stars")
                                .font(SustainabilityTypography.bodyStrong)
                        }
                    }
                }
            }
            .font(SustainabilityTypography.body)
            .tint(SustainabilityPalette.primary)
            .navigationTitle("主题颜色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        showColorEditor = false
                    }
                }
            }
        }
    }

    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            Button {
                resetToDefault()
            } label: {
                Text("恢复默认")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 46)
            }
            .buttonStyle(.bordered)

            Button {
                saveSiteSettings()
                withAnimation(.easeInOut(duration: 0.2)) {
                    justApplied = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        justApplied = false
                    }
                }
            } label: {
                Label(justApplied ? "已应用" : "应用设置", systemImage: justApplied ? "checkmark.circle.fill" : "checkmark")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 46)
            }
            .buttonStyle(.borderedProminent)
            .tint(SustainabilityPalette.primary)
        }
        .padding(14)
        .background(
            Color(.systemBackground).opacity(colorScheme == .dark ? 0.9 : 0.96),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.14),
            radius: 20,
            x: 0,
            y: 10
        )
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }

    private var selectedThemeDisplayName: String {
        if selectedThemeId.isEmpty { return NSLocalizedString("website.theme.followDefault", comment: "") }
        if selectedThemeId == dedicatedThemeId { return NSLocalizedString("website.theme.siteSpecific", comment: "") }
        return dataManager.themes.first(where: { $0.id == selectedThemeId })?.localizedDisplayName
            ?? NSLocalizedString("website.theme.selected", comment: "")
    }

    private var modeDescription: String {
        switch selectedMode {
        case .follow:
            return "website.modeDescription.follow"
        case .on:
            return "website.modeDescription.on"
        case .off:
            return "website.modeDescription.off"
        }
    }

    private var modeBadgeText: String {
        switch selectedMode {
        case .follow:
            return "website.modeBadge.follow"
        case .on:
            return "website.modeBadge.on"
        case .off:
            return "website.modeBadge.off"
        }
    }

    private var modeBadgeColor: Color {
        switch selectedMode {
        case .follow:
            return .secondary
        case .on:
            return SustainabilityPalette.success
        case .off:
            return SustainabilityPalette.neutral
        }
    }

    private var previewSwatches: [Color] {
        [backgroundColor, textColor, secondaryTextColor, linkColor, borderColor]
    }

    private func setupInitialState() {
        let rule = dataManager.siteRules[domain]
        selectedMode = rule?.mode ?? .follow
        selectedThemeId = rule?.themeId ?? ""
        useCustomColors = selectedThemeId == dedicatedThemeId
        refreshColorFromTheme()
        lastRuleSnapshot = ruleSnapshot()
    }

    private func refreshColorFromTheme() {
        let themeId = selectedThemeId.isEmpty ? dataManager.globalConfig.defaultThemeId : selectedThemeId
        let theme = dataManager.theme(id: themeId)
        backgroundColor = Color(hex: theme.backgroundColor) ?? backgroundColor
        textColor = Color(hex: theme.textColor) ?? textColor
        secondaryTextColor = Color(hex: theme.secondaryTextColor) ?? secondaryTextColor
        linkColor = Color(hex: theme.linkColor) ?? linkColor
        borderColor = Color(hex: theme.borderColor) ?? borderColor
    }

    private func saveSiteSettings() {
        var modeForRule: SiteMode? = selectedMode == .follow ? nil : selectedMode
        var themeIdForRule: String? = selectedThemeId.isEmpty ? nil : selectedThemeId

        if useCustomColors {
            let existing = dataManager.themes.first(where: { $0.id == dedicatedThemeId })
            let siteTheme = DarkTheme(
                id: dedicatedThemeId,
                name: String(format: NSLocalizedString("website.dedicatedTheme.name", comment: ""), domain),
                backgroundColor: backgroundColor.toHexString() ?? "#1e1e1e",
                textColor: textColor.toHexString() ?? "#e0e0e0",
                secondaryTextColor: secondaryTextColor.toHexString() ?? "#999999",
                linkColor: linkColor.toHexString() ?? "#4da6ff",
                borderColor: borderColor.toHexString() ?? "#444444",
                imageBrightness: existing?.imageBrightness ?? 0.75,
                imageGrayscale: existing?.imageGrayscale ?? 0.0,
                isBuiltin: false,
                createdAt: existing?.createdAt ?? Date(),
                updatedAt: Date()
            )
            if existing == nil {
                dataManager.addCustomTheme(siteTheme)
            } else {
                dataManager.updateTheme(siteTheme)
            }
            modeForRule = selectedMode == .follow ? nil : selectedMode
            themeIdForRule = dedicatedThemeId
        }

        dataManager.save(siteRule: SiteRule(mode: modeForRule, themeId: themeIdForRule), forDomain: domain)
        lastRuleSnapshot = ruleSnapshot()
    }

    private func resetToDefault() {
        selectedMode = .follow
        selectedThemeId = ""
        useCustomColors = false
        refreshColorFromTheme()
        saveSiteSettings()
    }

    private func ruleSnapshot() -> String {
        let rule = dataManager.siteRules[domain]
        let modeRaw = rule?.mode?.rawValue ?? "follow"
        let themeId = rule?.themeId ?? ""
        let updatedAt = rule?.updatedAt.timeIntervalSince1970 ?? 0
        return "\(modeRaw)|\(themeId)|\(updatedAt)"
    }

    private func applyRecommendedPalette() {
        guard let bg = rgbComponents(backgroundColor) else { return }
        let bgLum = relativeLuminance(bg)
        let baseText = bgLum < 0.4 ? (0.92, 0.93, 0.95) : (0.12, 0.14, 0.18)
        textColor = colorFromRGB(baseText)
        secondaryTextColor = colorFromRGB(mix(baseText, bg, amount: 0.35))
        linkColor = colorFromRGB(bgLum < 0.4 ? (0.36, 0.70, 1.0) : (0.12, 0.32, 0.78))
        borderColor = colorFromRGB(bgLum < 0.4 ? mix(bg, (1, 1, 1), amount: 0.18) : mix(bg, (0, 0, 0), amount: 0.14))
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
        return 0.2126 * linearize(rgb.0) + 0.7152 * linearize(rgb.1) + 0.0722 * linearize(rgb.2)
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

    private func siteBadge(text: String, color: Color) -> some View {
        Text(LocalizedStringKey(text))
            .font(SustainabilityTypography.captionStrong)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }
}

private struct SiteSettingIconBadge: View {
    let icon: String
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(color.opacity(0.2))
            .frame(width: 40, height: 40)
            .overlay(
                Image(systemName: icon)
                    .font(SustainabilityTypography.subBodyStrong)
                    .foregroundColor(color)
            )
    }
}

private struct WebsiteDomainRow: View {
    @EnvironmentObject var dataManager: SharedDataManager
    let domain: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 42, height: 42)
                Text(String(domain.prefix(1)).uppercased())
                    .font(SustainabilityTypography.subBodyStrong)
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(domain)
                    .font(SustainabilityTypography.bodyStrong)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(LocalizedStringKey(statusText))
                        .font(SustainabilityTypography.captionStrong)
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.14))
                        .clipShape(Capsule())

                    Text(themeText)
                        .font(SustainabilityTypography.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(SustainabilityTypography.captionStrong)
                .foregroundColor(.secondary)
        }
        .sustainabilityInteractiveRow()
    }

    private var statusText: String {
        guard let rule = dataManager.siteRules[domain] else {
            return "website.status.followDefault"
        }
        switch rule.mode {
        case .off:
            return "website.status.off"
        case .on:
            return "website.status.on"
        case .follow, .none:
            return "website.status.followDefault"
        }
    }

    private var statusColor: Color {
        switch dataManager.siteRules[domain]?.mode {
        case .some(.on):
            return SustainabilityPalette.success
        case .some(.off):
            return SustainabilityPalette.neutral
        default:
            return SustainabilityPalette.cta
        }
    }

    private var themeText: String {
        let format = NSLocalizedString("website.themePrefix", comment: "")
        guard let themeId = dataManager.siteRules[domain]?.themeId, !themeId.isEmpty else {
            return String(format: format, dataManager.defaultTheme.localizedDisplayName)
        }
        return String(format: format, dataManager.theme(id: themeId).localizedDisplayName)
    }
}
