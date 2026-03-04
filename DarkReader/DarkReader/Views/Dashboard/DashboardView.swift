//
//  DashboardView.swift
//  DarkReader
//
//  首页重构：顶部护眼报告 + 块状操作区（2 列）+ 右上角设置入口
//

import SwiftUI
import SafariServices

struct DashboardView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @Environment(\.colorScheme) private var colorScheme
    let onOpenThemes: () -> Void
    let onOpenSettings: () -> Void

    @State private var extensionEnabled: Bool? = nil
    @State private var isCheckingExtension = false

    private let actionColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    init(
        onOpenThemes: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {}
    ) {
        self.onOpenThemes = onOpenThemes
        self.onOpenSettings = onOpenSettings
    }

    var body: some View {
        NavigationView {
            ZStack {
                SustainabilityBackground()
                ScrollView {
                    VStack(spacing: 12) {
                        eyeCareReportCard

                        if extensionEnabled == false {
                            extensionWarningCard
                        }

                        operationBoardCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
                .font(SustainabilityTypography.body)
            }
            .navigationTitle("首页")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await checkExtensionStateAsync() }
                    } label: {
                        if isCheckingExtension {
                            ProgressView().progressViewStyle(.circular)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .accessibilityLabel("刷新扩展状态")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("打开设置")
                }
            }
            .refreshable {
                await checkExtensionStateAsync()
            }
            .task {
                await checkExtensionStateAsync()
            }
        }
        .sustainabilityChrome()
    }

    // MARK: - 1. 护眼报告

    private var eyeCareReportCard: some View {
        let today = dataManager.todayEyeCareRecord
        let reduction = dataManager.estimatedBlueLightReduction(for: today)
        let weekActiveDays = dataManager.currentWeekEyeCareRecords.filter { $0.darkModeDuration > 0 }.count

        return SustainabilityCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("护眼报告")
                            .font(SustainabilityTypography.title)
                        Text("当前状态与今日效果总览")
                            .font(SustainabilityTypography.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    SustainabilityStatusPill(
                        icon: extensionStatus.icon,
                        text: extensionStatus.text,
                        color: extensionStatus.color
                    )
                }

                HStack(spacing: 10) {
                    reportMetric(
                        icon: "moon.stars.fill",
                        title: "今日深色时长",
                        value: formatDuration(today.darkModeDuration),
                        tint: SustainabilityPalette.primary
                    )
                    reportMetric(
                        icon: "sun.max.trianglebadge.exclamationmark",
                        title: "蓝光减少估算",
                        value: "约 \(Int(reduction * 100))%",
                        tint: SustainabilityPalette.info
                    )
                }

                HStack(spacing: 10) {
                    reportMetric(
                        icon: "calendar.badge.clock",
                        title: "本周活跃天数",
                        value: "\(weekActiveDays) / 7",
                        tint: SustainabilityPalette.success
                    )
                    reportMetric(
                        icon: "globe",
                        title: "今日护眼站点",
                        value: "\(today.sitesCount)",
                        tint: SustainabilityPalette.cta
                    )
                }

                NavigationLink {
                    EyeCareReportView().environmentObject(dataManager)
                } label: {
                    HStack {
                        Text("查看详细报告")
                            .font(SustainabilityTypography.captionStrong)
                            .foregroundColor(SustainabilityPalette.cta)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(SustainabilityTypography.captionStrong)
                            .foregroundColor(.secondary)
                    }
                    .sustainabilityInteractiveRow()
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func reportMetric(icon: String, title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(SustainabilityTypography.subBodyStrong)
                .foregroundColor(tint)
            Text(title)
                .font(SustainabilityTypography.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            Text(value)
                .font(SustainabilityTypography.bodyStrong)
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(SustainabilityPalette.elevated(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 2. 操作区

    private var operationBoardCard: some View {
        SustainabilityCard {
            VStack(alignment: .leading, spacing: 12) {
                SustainabilitySectionTitle("操作区域", subtitle: "核心功能集中在一个面板内")

                modeControlBlock

                LazyVGrid(columns: actionColumns, spacing: 12) {
                    NavigationLink {
                        ScheduleView().environmentObject(dataManager)
                    } label: {
                        operationTile(
                            icon: "sparkles",
                            title: "智能打开护眼模式",
                            subtitle: scheduleStatusText,
                            tint: SustainabilityPalette.primary,
                            emphasize: dataManager.globalConfig.scheduleEnabled
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: onOpenThemes) {
                        operationTile(
                            icon: "paintpalette.fill",
                            title: "选择护眼效果",
                            subtitle: dataManager.defaultTheme.localizedDisplayName(
                                language: dataManager.globalConfig.appLanguage
                            ),
                            tint: SustainabilityPalette.cta,
                            emphasize: true
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        WebsiteSettingsView().environmentObject(dataManager)
                    } label: {
                        operationTile(
                            icon: "slider.horizontal.3",
                            title: "点对点护眼模式",
                            subtitle: siteModeStatusText,
                            tint: SustainabilityPalette.info,
                            emphasize: dataManager.siteRules.values.contains { $0.hasCustomSettings }
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        AdvancedStrategyView().environmentObject(dataManager)
                    } label: {
                        operationTile(
                            icon: "gearshape.2.fill",
                            title: "更多高级操作",
                            subtitle: advancedStatusText,
                            tint: SustainabilityPalette.warm,
                            emphasize: activeStrategyCount > 0 || !dataManager.errorLogs.isEmpty
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var modeControlBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("打开护眼开关")
                    .font(SustainabilityTypography.captionStrong)
                Spacer()
                Text(NSLocalizedString(dataManager.globalConfig.mode.displayNameKey, comment: ""))
                    .font(SustainabilityTypography.caption)
                    .foregroundColor(.secondary)
            }

            Picker("模式", selection: $dataManager.globalConfig.mode) {
                ForEach(DarkMode.allCases) { mode in
                    Label(LocalizedStringKey(mode.displayNameKey), systemImage: mode.systemImageName)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: dataManager.globalConfig.mode) { _ in
                dataManager.saveConfig()
            }

            Text(LocalizedStringKey(dataManager.globalConfig.mode.descriptionKey))
                .font(SustainabilityTypography.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .background(SustainabilityPalette.elevated(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func operationTile(
        icon: String,
        title: String,
        subtitle: String,
        tint: Color,
        emphasize: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(SustainabilityTypography.subBodyStrong)
                    .foregroundColor(emphasize ? tint : .secondary)
                Spacer()
                if emphasize {
                    Circle()
                        .fill(tint)
                        .frame(width: 6, height: 6)
                }
            }

            Text(title)
                .font(SustainabilityTypography.captionStrong)
                .foregroundColor(.primary)
                .lineLimit(2)

            Text(subtitle)
                .font(SustainabilityTypography.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 106, alignment: .topLeading)
        .padding(12)
        .background(SustainabilityPalette.elevated(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 3. 扩展未启用警告

    private var extensionWarningCard: some View {
        SustainabilityCard {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(SustainabilityTypography.subBodyStrong)
                    .foregroundColor(SustainabilityPalette.warm)

                VStack(alignment: .leading, spacing: 4) {
                    Text("扩展未启用")
                        .font(SustainabilityTypography.bodyStrong)
                    Text("请在 Safari 扩展设置中开启夜览，策略才能应用到网页。")
                        .font(SustainabilityTypography.caption)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 8)

                Button("去开启") {
                    openSafariExtensionSettings()
                }
                .buttonStyle(.borderedProminent)
                .tint(SustainabilityPalette.primary)
            }
        }
    }

    // MARK: - 辅助方法

    private var scheduleStatusText: String {
        let cfg = dataManager.globalConfig
        guard cfg.scheduleEnabled else { return "未启用" }
        switch cfg.scheduleTriggerSource {
        case .system:
            return colorScheme == .dark ? "跟随系统（深色）" : "跟随系统（浅色）"
        case .manual, .sunsetSunrise:
            return cfg.isInScheduledTime ? "深色进行中" : cfg.scheduleTimeDescription
        }
    }

    private var siteModeStatusText: String {
        let customCount = dataManager.siteRules.values.filter { $0.hasCustomSettings }.count
        if customCount > 0 {
            return "已配置 \(customCount) 个站点"
        }
        let visited = dataManager.visitedDomainsSorted.count
        return visited > 0 ? "已记录 \(visited) 个站点" : "暂无站点规则"
    }

    private var activeStrategyCount: Int {
        [
            dataManager.globalConfig.performanceMode,
            dataManager.globalConfig.ignoreNativeDarkMode,
            dataManager.globalConfig.dimImages,
            dataManager.globalConfig.lowBatteryEyeCareEnabled,
            dataManager.globalConfig.hideCookieBanners
        ]
        .filter { $0 }
        .count
    }

    private var advancedStatusText: String {
        if !dataManager.errorLogs.isEmpty {
            return "有 \(dataManager.errorLogs.count) 条异常记录"
        }
        if activeStrategyCount > 0 {
            return "已开启 \(activeStrategyCount) 项策略"
        }
        return "性能/图片/覆盖策略"
    }

    private func formatDuration(_ value: TimeInterval) -> String {
        guard value > 0 else { return "0m" }
        let totalMinutes = Int(value / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private var extensionStatus: (icon: String, text: String, color: Color) {
        if isCheckingExtension {
            return ("clock.fill", "dashboard.extensionStatus.checking", SustainabilityPalette.warm)
        }
        switch extensionEnabled {
        case .some(true):
            return ("checkmark.seal.fill", "dashboard.extensionStatus.connected", SustainabilityPalette.success)
        case .some(false):
            return ("xmark.seal.fill", "dashboard.extensionStatus.disabled", SustainabilityPalette.danger)
        case .none:
            return ("questionmark.circle.fill", "dashboard.extensionStatus.unknown", .secondary)
        }
    }

    @MainActor
    private func checkExtensionStateAsync() async {
        isCheckingExtension = true
        defer { isCheckingExtension = false }

#if os(iOS)
        extensionEnabled = true
#else
        await withCheckedContinuation { continuation in
            SFSafariExtensionManager.getStateOfSafariExtension(
                withIdentifier: "com.timmy.darkreader.extension"
            ) { state, _ in
                DispatchQueue.main.async {
                    self.extensionEnabled = state?.isEnabled ?? false
                    continuation.resume()
                }
            }
        }
#endif
    }

    private func openSafariExtensionSettings() {
#if os(iOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
#else
        SFSafariApplication.showPreferencesForExtension(
            withIdentifier: "com.timmy.darkreader.extension"
        ) { error in
            if let error { print("[DarkReader] 无法打开扩展设置：\(error)") }
        }
#endif
    }
}

// MARK: - 错误日志视图

struct ErrorLogsView: View {
    @EnvironmentObject var dataManager: SharedDataManager

    var body: some View {
        ZStack {
            SustainabilityBackground()
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(dataManager.errorLogs.reversed()) { log in
                        SustainabilityCard {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(log.domain)
                                    .font(SustainabilityTypography.bodyStrong)
                                Text(log.errorMsg)
                                    .font(SustainabilityTypography.caption)
                                    .foregroundColor(.secondary)
                                Text(log.time.formatted(date: .abbreviated, time: .shortened))
                                    .font(SustainabilityTypography.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("错误日志")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("清除") {
                    UserDefaults(suiteName: SharedKeys.appGroupSuite)?.removeObject(forKey: SharedKeys.errorLogs)
                    dataManager.errorLogs = []
                }
                .foregroundColor(SustainabilityPalette.danger)
            }
        }
        .sustainabilityChrome()
    }
}

// MARK: - 高级策略视图

struct AdvancedStrategyView: View {
    @EnvironmentObject var dataManager: SharedDataManager

    var body: some View {
        ZStack {
            SustainabilityBackground()
            ScrollView {
                VStack(spacing: 12) {
                    SustainabilityCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SustainabilitySectionTitle("渲染策略", subtitle: "增强可读性并控制视觉干预程度")

                            Toggle(isOn: $dataManager.globalConfig.dimImages) {
                                strategyLabel(
                                    icon: "photo.fill",
                                    iconColor: SustainabilityPalette.cta,
                                    title: "降低网页图片亮度",
                                    detail: "对图片应用 75% 亮度滤镜，不执行反色。"
                                )
                            }
                            .onChange(of: dataManager.globalConfig.dimImages) { _ in
                                dataManager.saveConfig()
                            }

                            Divider()

                            Toggle(isOn: $dataManager.globalConfig.ignoreNativeDarkMode) {
                                strategyLabel(
                                    icon: "eye.slash.fill",
                                    iconColor: SustainabilityPalette.primary,
                                    title: "忽略网站原生深色模式",
                                    detail: "强制使用夜览规则，保持跨站点一致体验。"
                                )
                            }
                            .onChange(of: dataManager.globalConfig.ignoreNativeDarkMode) { _ in
                                dataManager.saveConfig()
                            }

                            Divider()

                            Toggle(isOn: $dataManager.globalConfig.performanceMode) {
                                strategyLabel(
                                    icon: "speedometer",
                                    iconColor: SustainabilityPalette.warm,
                                    title: "性能模式",
                                    detail: "降低动态监听与增量渲染开销，适配低配设备。"
                                )
                            }
                            .onChange(of: dataManager.globalConfig.performanceMode) { _ in
                                dataManager.saveConfig()
                            }

                            Divider()

                            Toggle(isOn: $dataManager.globalConfig.lowBatteryEyeCareEnabled) {
                                strategyLabel(
                                    icon: "battery.25",
                                    iconColor: SustainabilityPalette.success,
                                    title: "低电量自动护眼",
                                    detail: "电量低于阈值时自动切换深色 + OLED 主题。"
                                )
                            }
                            .onChange(of: dataManager.globalConfig.lowBatteryEyeCareEnabled) { _ in
                                dataManager.saveConfig()
                            }

                            if dataManager.globalConfig.lowBatteryEyeCareEnabled {
                                Picker("低电量阈值", selection: $dataManager.globalConfig.lowBatteryThreshold) {
                                    Text("10%").tag(10)
                                    Text("20%").tag(20)
                                    Text("30%").tag(30)
                                }
                                .pickerStyle(.segmented)
                                .onChange(of: dataManager.globalConfig.lowBatteryThreshold) { _ in
                                    dataManager.saveConfig()
                                }
                                .sustainabilityInteractiveRow()

                                Toggle(isOn: $dataManager.globalConfig.lowBatteryRestoreOnCharging) {
                                    strategyLabel(
                                        icon: "bolt.batteryblock.fill",
                                        iconColor: SustainabilityPalette.info,
                                        title: "充电后恢复原模式",
                                        detail: "充电或电量恢复后自动还原此前配置。"
                                    )
                                }
                                .onChange(of: dataManager.globalConfig.lowBatteryRestoreOnCharging) { _ in
                                    dataManager.saveConfig()
                                }
                            }

                            Divider()

                            Toggle(isOn: $dataManager.globalConfig.hideCookieBanners) {
                                strategyLabel(
                                    icon: "hand.raised.slash.fill",
                                    iconColor: SustainabilityPalette.cta,
                                    title: "自动隐藏 Cookie 横幅",
                                    detail: "仅注入 CSS 进行 display:none，不模拟点击。"
                                )
                            }
                            .onChange(of: dataManager.globalConfig.hideCookieBanners) { _ in
                                dataManager.saveConfig()
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("高级策略")
        .navigationBarTitleDisplayMode(.inline)
        .sustainabilityChrome()
    }

    private func strategyLabel(icon: String, iconColor: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SustainabilityTypography.bodyStrong)
                Text(detail)
                    .font(SustainabilityTypography.caption)
                    .foregroundColor(.secondary)
            }
        }
        .sustainabilityInteractiveRow()
    }
}

// MARK: - 护眼报告视图
struct EyeCareReportView: View {
    @EnvironmentObject var dataManager: SharedDataManager

    var body: some View {
        ZStack {
            SustainabilityBackground()
            ScrollView {
                VStack(spacing: 12) {
                    todaySummaryCard
                    weeklyTrendCard
                    siteDistributionCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("护眼报告")
        .navigationBarTitleDisplayMode(.inline)
        .sustainabilityChrome()
    }

    private var todaySummaryCard: some View {
        let today = dataManager.todayEyeCareRecord
        let reduction = dataManager.estimatedBlueLightReduction(for: today)
        let weekActiveDays = dataManager.currentWeekEyeCareRecords.filter { $0.darkModeDuration > 0 }.count

        return SustainabilityCard {
            VStack(alignment: .leading, spacing: 10) {
                SustainabilitySectionTitle("今日护眼报告", subtitle: "效果可见，持续积累")
                summaryRow(icon: "moon.stars.fill", title: "深色浏览时长", value: formatDuration(today.darkModeDuration))
                summaryRow(icon: "sun.max.trianglebadge.exclamationmark", title: "蓝光减少估算", value: "约 \(Int(reduction * 100))%")
                summaryRow(icon: "globe", title: "护眼网站数", value: "\(today.sitesCount) 个")
                summaryRow(icon: "calendar.badge.clock", title: "本周护眼天数", value: "\(weekActiveDays) / 7 天")

                Text("蓝光减少为估算值，仅用于护眼效果感知，不构成医学结论。")
                    .font(SustainabilityTypography.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var weeklyTrendCard: some View {
        let records = dataManager.currentWeekEyeCareRecords
        let maxDuration = max(records.map(\.darkModeDuration).max() ?? 0, 1)

        return SustainabilityCard {
            VStack(alignment: .leading, spacing: 10) {
                SustainabilitySectionTitle("本周趋势", subtitle: "每日深色浏览时长")
                ForEach(records, id: \.date) { record in
                    HStack(spacing: 10) {
                        Text(record.date.formatted(.dateTime.weekday(.short)))
                            .font(SustainabilityTypography.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 34, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.secondary.opacity(0.14))
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(SustainabilityPalette.primary.opacity(0.85))
                                    .frame(width: max(6, geo.size.width * CGFloat(record.darkModeDuration / maxDuration)))
                            }
                        }
                        .frame(height: 10)

                        Text(formatDuration(record.darkModeDuration))
                            .font(SustainabilityTypography.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 72, alignment: .trailing)
                    }
                    .frame(height: 18)
                }
            }
        }
    }

    private var siteDistributionCard: some View {
        let topSites = Array(dataManager.siteDistribution(for: Date()).prefix(8))

        return SustainabilityCard {
            VStack(alignment: .leading, spacing: 10) {
                SustainabilitySectionTitle("站点护眼分布", subtitle: "今日各站点深色时长")

                if topSites.isEmpty {
                    Text("今日还没有可统计的护眼站点数据。")
                        .font(SustainabilityTypography.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(topSites, id: \.domain) { site in
                        HStack {
                            Text(site.domain)
                                .font(SustainabilityTypography.bodyStrong)
                                .lineLimit(1)
                            Spacer()
                            Text(formatDuration(site.duration))
                                .font(SustainabilityTypography.caption)
                                .foregroundColor(.secondary)
                        }
                        .sustainabilityInteractiveRow()
                    }
                }
            }
        }
    }

    private func summaryRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(SustainabilityTypography.body)
            Spacer()
            Text(value)
                .font(SustainabilityTypography.bodyStrong)
        }
    }

    private func formatDuration(_ value: TimeInterval) -> String {
        guard value > 0 else { return "0m" }
        let totalMinutes = Int(value / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

#Preview {
    DashboardView()
        .environmentObject(SharedDataManager.shared)
}
