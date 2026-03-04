//
//  DashboardView.swift
//  DarkReader
//
//  Sustainability Platform 风格控制台（重构版）
//  信息架构：状态总览 → 特色功能 → 模式策略 → 网站列表 → 高级/日志
//

import SwiftUI
import SafariServices

struct DashboardView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @EnvironmentObject var appNavigation: AppNavigationState
    @Environment(\.colorScheme) private var colorScheme

    @State private var extensionEnabled: Bool? = nil
    @State private var isCheckingExtension = false

    var body: some View {
        NavigationView {
            ZStack {
                SustainabilityBackground()
                ScrollView {
                    VStack(spacing: 12) {
                        // 1. 核心控制（模式 + 运行状态）
                        coreControlCard

                        // 2. 扩展未启用提示
                        if extensionEnabled == false {
                            extensionWarningCard
                        }

                        // 3. 快速操作区
                        quickActionsCard

                        // 4. 最近访问网站
                        websiteSettingsCard

                        // 5. 错误日志（有记录时显示）
                        if !dataManager.errorLogs.isEmpty {
                            errorLogsCard
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
                .font(SustainabilityTypography.body)
            }
            .navigationTitle("控制台")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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

    // MARK: - 1. 核心控制区

    private var coreControlCard: some View {
        SustainabilityCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("核心控制")
                            .font(SustainabilityTypography.title)
                        Text("先选全局模式，再按站点精调")
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

                HStack(spacing: 10) {
                    Button {
                        appNavigation.selectedTab = 1
                    } label: {
                        metricBlock(
                            icon: "paintpalette.fill",
                            iconColor: SustainabilityPalette.cta,
                            title: "默认主题",
                            value: dataManager.defaultTheme.localizedDisplayName(
                                language: dataManager.globalConfig.appLanguage
                            )
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ScheduleView().environmentObject(dataManager)
                    } label: {
                        metricBlock(
                            icon: dataManager.globalConfig.scheduleEnabled ? "timer.circle.fill" : "timer",
                            iconColor: dataManager.globalConfig.scheduleEnabled
                                ? SustainabilityPalette.primary : .secondary,
                            title: "定时模式",
                            value: scheduleStatusText
                        )
                    }
                    .buttonStyle(.plain)
                }

                Text(LocalizedStringKey(dataManager.globalConfig.mode.descriptionKey))
                    .font(SustainabilityTypography.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                if dataManager.globalConfig.mode != .auto && dataManager.globalConfig.scheduleEnabled {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(SustainabilityTypography.caption)
                            .foregroundColor(SustainabilityPalette.warm)
                        Text("当前模式会覆盖定时设置。定时模式需在“跟随系统”下生效。")
                            .font(SustainabilityTypography.caption)
                            .foregroundColor(SustainabilityPalette.warm)
                            .lineLimit(2)
                    }
                    .padding(10)
                    .background(SustainabilityPalette.warm.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private var statusSubtitle: String {
        if isCheckingExtension { return "检测扩展连接状态..." }
        switch extensionEnabled {
        case .some(true): return "扩展已连接，策略正在生效"
        case .some(false): return "扩展未启用，请前往 Safari 开启"
        case .none: return "点击刷新检测扩展状态"
        }
    }

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

    private var todayReportSubtitle: String {
        let duration = dataManager.todayEyeCareRecord.darkModeDuration
        guard duration > 0 else { return "今日暂无数据" }
        let minutes = Int(duration / 60)
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }

    private func metricBlock(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(SustainabilityTypography.subBodyStrong)
                .foregroundColor(iconColor)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SustainabilityTypography.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(SustainabilityTypography.captionStrong)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 11)
        .padding(.horizontal, 12)
        .background(SustainabilityPalette.elevated(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 2. 扩展未启用警告

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

    // MARK: - 3. 快速操作区

    private let actionColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var quickActionsCard: some View {
        SustainabilityCard {
            VStack(alignment: .leading, spacing: 10) {
                SustainabilitySectionTitle("快速操作", subtitle: "常用功能集中入口")
                LazyVGrid(columns: actionColumns, spacing: 10) {
                    NavigationLink {
                        ScheduleView().environmentObject(dataManager)
                    } label: {
                        quickActionTile(
                            icon: "clock.badge.checkmark.fill",
                            iconColor: SustainabilityPalette.primary,
                            title: "定时深色",
                            subtitle: dataManager.globalConfig.scheduleEnabled ? "已启用" : "未启用",
                            emphasize: dataManager.globalConfig.scheduleEnabled
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        WebsiteSettingsView().environmentObject(dataManager)
                    } label: {
                        quickActionTile(
                            icon: "slider.horizontal.3",
                            iconColor: SustainabilityPalette.cta,
                            title: "网站精调",
                            subtitle: localizedCount("settings.count.sites", dataManager.siteRules.count),
                            emphasize: dataManager.siteRules.values.contains { $0.hasCustomSettings }
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        appNavigation.selectedTab = 1
                    } label: {
                        quickActionTile(
                            icon: "swatchpalette.fill",
                            iconColor: SustainabilityPalette.info,
                            title: "主题管理",
                            subtitle: dataManager.defaultTheme.localizedDisplayName(
                                language: dataManager.globalConfig.appLanguage
                            ),
                            emphasize: true
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        EyeCareReportView()
                    } label: {
                        quickActionTile(
                            icon: "chart.bar.xaxis",
                            iconColor: SustainabilityPalette.success,
                            title: "护眼报告",
                            subtitle: todayReportSubtitle,
                            emphasize: dataManager.todayEyeCareRecord.darkModeDuration > 0
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        AdvancedStrategyView()
                    } label: {
                        quickActionTile(
                            icon: "gearshape.2.fill",
                            iconColor: SustainabilityPalette.neutral,
                            title: "高级策略",
                            subtitle: "性能/图片/覆盖",
                            emphasize: dataManager.globalConfig.performanceMode || dataManager.globalConfig.ignoreNativeDarkMode
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func quickActionTile(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        emphasize: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(SustainabilityTypography.subBodyStrong)
                    .foregroundColor(emphasize ? iconColor : .secondary)
                Spacer()
                if emphasize {
                    Circle()
                        .fill(iconColor)
                        .frame(width: 6, height: 6)
                }
            }

            Text(title)
                .font(SustainabilityTypography.captionStrong)
                .foregroundColor(.primary)
                .lineLimit(1)

            Text(subtitle)
                .font(SustainabilityTypography.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(SustainabilityPalette.elevated(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func localizedCount(_ key: String, _ count: Int) -> String {
        String(format: NSLocalizedString(key, comment: ""), count)
    }

    // MARK: - 5. 网站设置快捷卡

    private var websiteSettingsCard: some View {
        let domains = dataManager.visitedDomainsSorted
        return SustainabilityCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SustainabilitySectionTitle("网站设置", subtitle: "按站点配置启用状态、主题与精调")
                    Spacer()
                    if !domains.isEmpty {
                        NavigationLink {
                            WebsiteSettingsView()
                        } label: {
                            Text("全部")
                                .font(SustainabilityTypography.captionStrong)
                                .foregroundColor(SustainabilityPalette.cta)
                        }
                    }
                }

                if domains.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("先在 Safari 浏览几个网站，随后可在这里逐站点配置深色策略和精细调节。")
                            .font(SustainabilityTypography.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // 最多展示 4 个最近站点
                    ForEach(domains.prefix(4), id: \.self) { domain in
                        NavigationLink {
                            WebsiteSettingDetailView(domain: domain)
                        } label: {
                            HStack {
                                // 域名首字母图标
                                Text(String(domain.prefix(1)).uppercased())
                                    .font(SustainabilityTypography.captionStrong)
                                    .foregroundColor(siteColor(for: domain))
                                    .frame(width: 30, height: 30)
                                    .background(siteColor(for: domain).opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(domain)
                                        .font(SustainabilityTypography.captionStrong)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Text(siteStatusLabel(for: domain))
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(SustainabilityTypography.captionStrong)
                                    .foregroundColor(.secondary)
                            }
                            .sustainabilityInteractiveRow()
                        }
                        .buttonStyle(.plain)

                        if domain != domains.prefix(4).last {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - 5. 错误日志入口

    private var errorLogsCard: some View {
        NavigationLink {
            ErrorLogsView()
        } label: {
            SustainabilityCard {
                HStack(spacing: 12) {
                    Image(systemName: "waveform.path.ecg.rectangle.fill")
                        .foregroundColor(SustainabilityPalette.warm)
                        .font(SustainabilityTypography.subBodyStrong)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("异常诊断")
                            .font(SustainabilityTypography.bodyStrong)
                        Text("查看最近渲染错误日志")
                            .font(SustainabilityTypography.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text("\(dataManager.errorLogs.count)")
                        .font(SustainabilityTypography.captionStrong)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())

                    Image(systemName: "chevron.right")
                        .font(SustainabilityTypography.captionStrong)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 辅助方法

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

    private func siteColor(for domain: String) -> Color {
        switch dataManager.siteRules[domain]?.mode {
        case .some(.on):  return SustainabilityPalette.success
        case .some(.off): return SustainabilityPalette.neutral
        default:          return SustainabilityPalette.cta
        }
    }

    private func siteStatusLabel(for domain: String) -> String {
        guard let rule = dataManager.siteRules[domain] else { return "跟随默认" }
        var parts: [String] = []
        switch rule.mode {
        case .on:  parts.append("强制开启")
        case .off: parts.append("已关闭")
        case .follow, .none: parts.append("跟随默认")
        }
        if rule.focusMode { parts.append("专注") }
        if abs(rule.brightness - 1.0) > 0.01 { parts.append("亮度 \(Int(rule.brightness * 100))%") }
        if abs(rule.contrast - 1.0) > 0.01 { parts.append("对比 \(Int(rule.contrast * 100))%") }
        return parts.joined(separator: " · ")
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
