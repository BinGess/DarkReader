//
//  DashboardView.swift
//  DarkReader
//
//  Sustainability Platform 风格控制台：状态、模式、主题和渲染策略集中展示
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
                        overviewCard

                        if extensionEnabled == false {
                            extensionWarningCard
                        }

                        advancedEntryCard
                        websiteSettingsCard

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
                            ProgressView()
                                .progressViewStyle(.circular)
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

    private var overviewCard: some View {
        SustainabilityCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("系统运行与模式")
                            .font(SustainabilityTypography.bodyStrong)
                        Text("扩展连接与全局深色策略")
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

                Divider()

                defaultThemeMetricButton

                Divider()

                SustainabilitySectionTitle("全局模式策略", subtitle: "决定所有站点默认深色行为")

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
            }
        }
    }

    private var extensionWarningCard: some View {
        SustainabilityCard {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(SustainabilityTypography.subBodyStrong)
                    .foregroundColor(SustainabilityPalette.warm)

                VStack(alignment: .leading, spacing: 4) {
                    Text("扩展未启用")
                        .font(SustainabilityTypography.bodyStrong)
                    Text("请在 Safari 扩展设置中开启 DarkReader，才能将策略应用到网页。")
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

    private var advancedEntryCard: some View {
        NavigationLink {
            AdvancedStrategyView()
        } label: {
            SustainabilityCard {
                HStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(SustainabilityPalette.cta)
                        .font(SustainabilityTypography.title)

                    VStack(alignment: .leading, spacing: 3) {
                        SustainabilitySectionTitle("高级策略", subtitle: "管理渲染策略与视觉干预")
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(SustainabilityTypography.captionStrong)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

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

    private var websiteSettingsCard: some View {
        let domains = dataManager.visitedDomainsSorted
        return SustainabilityCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SustainabilitySectionTitle("网站设置", subtitle: "按站点单独配置启用、主题和颜色")
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
                    Text("暂无访问记录。先在 Safari 浏览网站，随后可在这里逐站点设置。")
                        .font(SustainabilityTypography.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(domains, id: \.self) { domain in
                        NavigationLink {
                            WebsiteSettingDetailView(domain: domain)
                        } label: {
                            HStack {
                                Text(domain)
                                    .font(SustainabilityTypography.bodyStrong)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(LocalizedStringKey(siteModeLabelKey(for: domain)))
                                    .font(SustainabilityTypography.caption)
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(SustainabilityTypography.captionStrong)
                                    .foregroundColor(.secondary)
                            }
                            .sustainabilityInteractiveRow()
                        }
                        .buttonStyle(.plain)
                        if domain != domains.last {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func dashboardMetric(titleKey: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(titleKey))
                .font(SustainabilityTypography.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(SustainabilityTypography.bodyStrong)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(SustainabilityPalette.elevated(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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

    private var defaultThemeMetricButton: some View {
        Button {
            appNavigation.selectedTab = 1
        } label: {
            HStack(spacing: 10) {
                dashboardMetric(
                    titleKey: "dashboard.metric.defaultTheme",
                    value: dataManager.defaultTheme.localizedDisplayName(
                        language: dataManager.globalConfig.appLanguage
                    )
                )
                Image(systemName: "chevron.right")
                    .font(SustainabilityTypography.captionStrong)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 4)
            }
        }
        .buttonStyle(.plain)
    }

    private func siteModeLabelKey(for domain: String) -> String {
        guard let rule = dataManager.siteRules[domain] else { return "dashboard.siteMode.followDefault" }
        switch rule.mode {
        case .off:
            return "dashboard.siteMode.off"
        case .on:
            return "dashboard.siteMode.on"
        case .follow, .none:
            return "dashboard.siteMode.followDefault"
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
                                    detail: "强制使用 DarkReader 规则，保持跨站点一致体验。"
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

#Preview {
    DashboardView()
        .environmentObject(SharedDataManager.shared)
}
