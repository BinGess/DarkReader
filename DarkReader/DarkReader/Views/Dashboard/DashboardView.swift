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
    @Binding var showThemesPage: Bool
    @Binding var showSettingsPage: Bool

    @State private var extensionEnabled: Bool? = nil
    @State private var isCheckingExtension = false
    @State private var reportPageIndex = 0

    private let actionColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private let modeOptionColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    init(
        showThemesPage: Binding<Bool> = .constant(false),
        showSettingsPage: Binding<Bool> = .constant(false)
    ) {
        self._showThemesPage = showThemesPage
        self._showSettingsPage = showSettingsPage
    }

    var body: some View {
        NavigationView {
            ZStack {
                SustainabilityBackground()
                ScrollView {
                    VStack(spacing: SustainabilityMetrics.sectionGap) {
                        eyeCareReportCard
                        modeBoardCard
                        advancedSettingsCard
                    }
                    .padding(.horizontal, SustainabilityMetrics.pageHorizontalPadding)
                    .padding(.top, SustainabilityMetrics.pageTopPadding)
                    .padding(.bottom, SustainabilityMetrics.pageBottomPadding)
                }
                .font(SustainabilityTypography.body)
            }
            .navigationTitle("首页")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettingsPage = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 28, height: 28)
                    }
                    .accessibilityLabel("打开设置")
                }
            }
            .background(
                Group {
                    NavigationLink(destination: ThemeManagerView(), isActive: $showThemesPage) {
                        EmptyView()
                    }
                    NavigationLink(destination: SettingsView(), isActive: $showSettingsPage) {
                        EmptyView()
                    }
                }
                .hidden()
            )
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
        let weekRecords = dataManager.currentWeekEyeCareRecords
        let maxDuration = max(weekRecords.map(\.darkModeDuration).max() ?? 0, 1)
        let weekAverageDuration = weekRecords.reduce(0) { $0 + $1.darkModeDuration } / Double(max(weekRecords.count, 1))
        let reduction = dataManager.estimatedBlueLightReduction(for: today)
        let displayTodayDuration = formatDuration(max(today.darkModeDuration, 60))
        let displayReductionPercent = max(Int(reduction * 100), 1)
        let weekActiveDays = dataManager.currentWeekEyeCareRecords.filter { $0.darkModeDuration > 0 }.count
        let topSites = Array(dataManager.siteDistribution(for: Date()).prefix(3))

        return ZStack {
            RoundedRectangle(cornerRadius: SustainabilityMetrics.heroCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [
                                SustainabilityPalette.primary.opacity(0.52),
                                SustainabilityPalette.cta.opacity(0.46),
                                SustainabilityPalette.info.opacity(0.36)
                            ]
                            : [
                                SustainabilityPalette.primary.opacity(0.9),
                                SustainabilityPalette.cta.opacity(0.78),
                                SustainabilityPalette.info.opacity(0.65)
                            ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: SustainabilityMetrics.heroCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.26), lineWidth: 1)
            RoundedRectangle(cornerRadius: SustainabilityMetrics.heroCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(colorScheme == .dark ? 0.18 : 0.08),
                            Color.black.opacity(colorScheme == .dark ? 0.24 : 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("护眼报告")
                            .font(SustainabilityTypography.title)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    NavigationLink {
                        EyeCareReportView().environmentObject(dataManager)
                    } label: {
                        HStack(spacing: 4) {
                            Text("详细报告")
                                .font(SustainabilityTypography.captionStrong)
                            Image(systemName: "arrow.right")
                                .font(SustainabilityTypography.captionStrong)
                        }
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }

                TabView(selection: $reportPageIndex) {
                    trendReportPage(
                        weekRecords: weekRecords,
                        maxDuration: maxDuration,
                        todayDurationText: displayTodayDuration,
                        reductionPercent: displayReductionPercent,
                        onHero: true
                    )
                    .tag(0)

                    weeklyReportPage(
                        weekActiveDays: weekActiveDays,
                        weekAverageDuration: weekAverageDuration,
                        todayDurationText: displayTodayDuration,
                        reductionPercent: displayReductionPercent,
                        onHero: true
                    )
                    .tag(1)

                    siteReportPage(
                        sitesCount: today.sitesCount,
                        topSites: topSites,
                        onHero: true
                    )
                    .tag(2)
                }
                .frame(height: 206)
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(index == reportPageIndex ? Color.white : Color.white.opacity(0.4))
                            .frame(width: index == reportPageIndex ? 14 : 6, height: 6)
                    }
                    Spacer()
                    Text("\(reportPageIndex + 1) / 3")
                        .font(SustainabilityTypography.caption)
                        .foregroundColor(Color.white.opacity(0.8))
                }
            }
            .padding(SustainabilityMetrics.cardInnerPadding)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.14), radius: 12, x: 0, y: 8)
    }

    private func trendReportPage(
        weekRecords: [DailyEyeCareRecord],
        maxDuration: TimeInterval,
        todayDurationText: String,
        reductionPercent: Int,
        onHero: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("近 7 天趋势")
                .font(SustainabilityTypography.captionStrong)
                .foregroundColor(onHero ? Color.white.opacity(0.86) : .secondary)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(weekRecords, id: \.date) { record in
                    let ratio = CGFloat(record.darkModeDuration / maxDuration)
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(
                                record.darkModeDuration > 0
                                    ? (onHero ? Color.white.opacity(0.9) : SustainabilityPalette.primary.opacity(0.86))
                                    : (onHero ? Color.white.opacity(0.24) : Color.secondary.opacity(0.22))
                            )
                            .frame(height: max(5, ratio * 46))
                        Text(record.date.formatted(.dateTime.weekday(.narrow)))
                            .font(SustainabilityTypography.caption)
                            .foregroundColor(onHero ? Color.white.opacity(0.72) : .secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .bottom)
                }
            }
            .frame(height: 60, alignment: .bottom)

            HStack(spacing: 8) {
                reportMetricChip(
                    icon: "moon.stars.fill",
                    title: "今日深色时长",
                    value: todayDurationText,
                    tint: onHero ? .white : SustainabilityPalette.primary,
                    onHero: onHero
                )
                reportMetricChip(
                    icon: "sun.max.trianglebadge.exclamationmark",
                    title: "蓝光减少估算",
                    value: "约 \(reductionPercent)%",
                    tint: onHero ? .white : SustainabilityPalette.info,
                    onHero: onHero
                )
            }
        }
        .padding(SustainabilityMetrics.controlCornerRadius)
        .background(onHero ? Color.black.opacity(0.17) : SustainabilityPalette.elevated(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: SustainabilityMetrics.controlCornerRadius, style: .continuous))
    }

    private func weeklyReportPage(
        weekActiveDays: Int,
        weekAverageDuration: TimeInterval,
        todayDurationText: String,
        reductionPercent: Int,
        onHero: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("周维度报告")
                .font(SustainabilityTypography.captionStrong)
                .foregroundColor(onHero ? Color.white.opacity(0.86) : .secondary)

            reportTableRow(
                title: "本周活跃天数",
                value: "\(weekActiveDays) / 7",
                icon: "calendar.badge.clock",
                onHero: onHero
            )

            ProgressView(value: Double(weekActiveDays), total: 7)
                .tint(onHero ? .white : SustainabilityPalette.success)

            reportTableRow(
                title: "周均深色时长",
                value: formatDuration(weekAverageDuration),
                icon: "chart.bar.fill",
                showsDivider: false,
                onHero: onHero
            )

            HStack(spacing: 6) {
                reportCompactMetric(
                    title: "今日深色",
                    value: todayDurationText,
                    tint: onHero ? .white : SustainabilityPalette.primary,
                    onHero: onHero
                )
                reportCompactMetric(
                    title: "蓝光估算",
                    value: "\(reductionPercent)%",
                    tint: onHero ? .white : SustainabilityPalette.info,
                    onHero: onHero
                )
                reportCompactMetric(
                    title: "活跃天数",
                    value: "\(weekActiveDays)/7",
                    tint: onHero ? .white : SustainabilityPalette.success,
                    onHero: onHero
                )
            }
        }
        .padding(SustainabilityMetrics.controlCornerRadius)
        .background(onHero ? Color.black.opacity(0.17) : SustainabilityPalette.elevated(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: SustainabilityMetrics.controlCornerRadius, style: .continuous))
    }

    private func siteReportPage(
        sitesCount: Int,
        topSites: [(domain: String, duration: TimeInterval)],
        onHero: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("站点报告")
                .font(SustainabilityTypography.captionStrong)
                .foregroundColor(onHero ? Color.white.opacity(0.86) : .secondary)

            reportTableRow(
                title: "今日护眼站点",
                value: "\(sitesCount)",
                icon: "globe",
                showsDivider: !topSites.isEmpty,
                onHero: onHero
            )

            if topSites.isEmpty {
                Text("暂无可统计站点")
                    .font(SustainabilityTypography.caption)
                    .foregroundColor(onHero ? Color.white.opacity(0.72) : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            } else {
                ForEach(Array(topSites.enumerated()), id: \.offset) { index, site in
                    reportTableRow(
                        title: "TOP\(index + 1) \(site.domain)",
                        value: formatDuration(site.duration),
                        icon: "dot.scope",
                        showsDivider: index != topSites.count - 1,
                        onHero: onHero
                    )
                }
            }
        }
        .padding(SustainabilityMetrics.controlCornerRadius)
        .background(onHero ? Color.black.opacity(0.17) : SustainabilityPalette.elevated(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: SustainabilityMetrics.controlCornerRadius, style: .continuous))
    }

    private func reportMetricChip(
        icon: String,
        title: String,
        value: String,
        tint: Color,
        onHero: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(SustainabilityTypography.caption)
                .foregroundColor(onHero ? Color.white.opacity(0.78) : .secondary)
                .lineLimit(1)

            Text(value)
                .font(SustainabilityTypography.bodyStrong)
                .foregroundColor(tint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(onHero ? Color.white.opacity(0.14) : Color.white.opacity(colorScheme == .dark ? 0.06 : 0.5))
        .clipShape(RoundedRectangle(cornerRadius: SustainabilityMetrics.controlCornerRadius, style: .continuous))
    }

    private func reportCompactMetric(
        title: String,
        value: String,
        tint: Color,
        onHero: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(SustainabilityTypography.caption)
                .foregroundColor(onHero ? Color.white.opacity(0.74) : .secondary)
                .lineLimit(1)
            Text(value)
                .font(SustainabilityTypography.subBodyStrong)
                .foregroundColor(tint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(onHero ? Color.white.opacity(0.13) : Color.white.opacity(colorScheme == .dark ? 0.05 : 0.48))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func reportTableRow(
        title: String,
        value: String,
        icon: String,
        showsDivider: Bool = true,
        onHero: Bool = false
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(SustainabilityTypography.captionStrong)
                    .foregroundColor(onHero ? Color.white.opacity(0.74) : .secondary)
                    .frame(width: 16)

                Text(title)
                    .font(SustainabilityTypography.caption)
                    .foregroundColor(onHero ? Color.white.opacity(0.9) : .primary)
                    .lineLimit(1)

                Spacer()

                Text(value)
                    .font(SustainabilityTypography.bodyStrong)
                    .foregroundColor(onHero ? .white : .primary)
                    .lineLimit(1)
            }
            .padding(.vertical, SustainabilityMetrics.rowVerticalPadding)

            if showsDivider {
                Divider()
                    .padding(.leading, 26)
                    .overlay((onHero ? Color.white.opacity(0.24) : Color.clear))
            }
        }
    }

    // MARK: - 2. 操作区

    private var modeBoardCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("操作区域")
                        .font(SustainabilityTypography.title)
                    Text("快速切换护眼模式")
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
            modeControlBlock
        }
        .padding(SustainabilityMetrics.cardInnerPadding)
        .background(
            RoundedRectangle(cornerRadius: SustainabilityMetrics.moduleCornerRadius, style: .continuous)
                .fill(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: SustainabilityMetrics.moduleCornerRadius, style: .continuous)
                .stroke(SustainabilityPalette.border(colorScheme).opacity(0.8), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.06), radius: 8, x: 0, y: 4)
    }

    private var advancedSettingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SustainabilitySectionTitle("高级设置区", subtitle: "策略状态与入口")

            VStack(spacing: 0) {
                NavigationLink {
                    ScheduleView().environmentObject(dataManager)
                } label: {
                    advancedPolicyRow(
                        icon: "sparkles",
                        title: "智能护眼模式",
                        subtitle: "按系统/时段自动切换",
                        status: scheduleStatusText,
                        tint: SustainabilityPalette.primary
                    )
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 52)

                Button {
                    showThemesPage = true
                } label: {
                    advancedPolicyRow(
                        icon: "paintpalette.fill",
                        title: "护眼效果",
                        subtitle: "选择主题与色彩策略",
                        status: dataManager.defaultTheme.localizedDisplayName(language: dataManager.globalConfig.appLanguage),
                        tint: SustainabilityPalette.cta
                    )
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 52)

                NavigationLink {
                    WebsiteSettingsView().environmentObject(dataManager)
                } label: {
                    advancedPolicyRow(
                        icon: "slider.horizontal.3",
                        title: "点对点护眼模式",
                        subtitle: "按站点覆盖默认配置",
                        status: siteModeStatusText,
                        tint: SustainabilityPalette.info
                    )
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 52)

                NavigationLink {
                    AdvancedStrategyView().environmentObject(dataManager)
                } label: {
                    advancedPolicyRow(
                        icon: "gearshape.2.fill",
                        title: "更高操作",
                        subtitle: "性能与渲染高级策略",
                        status: advancedStatusText,
                        tint: SustainabilityPalette.warm
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: SustainabilityMetrics.controlCornerRadius, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.03))
            )
        }
        .padding(SustainabilityMetrics.cardInnerPadding)
        .background(
            RoundedRectangle(cornerRadius: SustainabilityMetrics.moduleCornerRadius, style: .continuous)
                .fill(SustainabilityPalette.surface(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: SustainabilityMetrics.moduleCornerRadius, style: .continuous)
                .stroke(SustainabilityPalette.border(colorScheme), lineWidth: 1)
        )
    }

    private func advancedPolicyRow(
        icon: String,
        title: String,
        subtitle: String,
        status: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(colorScheme == .dark ? 0.32 : 0.16))
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: icon)
                        .font(SustainabilityTypography.subBodyStrong)
                        .foregroundColor(tint)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SustainabilityTypography.bodyStrong)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(SustainabilityTypography.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text(status)
                    .font(SustainabilityTypography.captionStrong)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(SustainabilityTypography.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 14)
        .frame(minHeight: 82)
    }

    private var modeControlBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "power")
                    .font(SustainabilityTypography.captionStrong)
                    .foregroundColor(SustainabilityPalette.primary)
                Text("打开护眼开关")
                    .font(SustainabilityTypography.captionStrong)
                Spacer()
            }

            LazyVGrid(columns: modeOptionColumns, spacing: 10) {
                ForEach(ModeQuickOption.allCases) { option in
                    modeOptionButton(option)
                }
            }

            Text(LocalizedStringKey(selectedModeOption.descriptionKey))
                .font(SustainabilityTypography.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(8)
    }

    private func modeOptionButton(_ option: ModeQuickOption) -> some View {
        let isSelected = selectedModeOption == option

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                applyModeOption(option)
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: option.iconName)
                        .font(SustainabilityTypography.captionStrong)
                        .foregroundColor(isSelected ? SustainabilityPalette.primary : .secondary)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(SustainabilityPalette.primary)
                    }
                }

                Text(LocalizedStringKey(option.titleKey))
                    .font(SustainabilityTypography.captionStrong)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(LocalizedStringKey(option.subtitleKey))
                    .font(SustainabilityTypography.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: SustainabilityMetrics.controlCornerRadius, style: .continuous)
                    .fill(
                        isSelected
                            ? SustainabilityPalette.primary.opacity(colorScheme == .dark ? 0.22 : 0.14)
                            : Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: SustainabilityMetrics.controlCornerRadius, style: .continuous)
                    .stroke(
                        isSelected
                            ? SustainabilityPalette.primary.opacity(0.8)
                            : Color.primary.opacity(0.08),
                        lineWidth: isSelected ? 1.2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(option.titleKey)))
        .accessibilityHint(Text(LocalizedStringKey(option.subtitleKey)))
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
        .clipShape(RoundedRectangle(cornerRadius: SustainabilityMetrics.controlCornerRadius, style: .continuous))
    }

    private enum ModeQuickOption: String, CaseIterable, Identifiable {
        case follow
        case on
        case off
        case smart

        var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .follow: return "darkmode.option.auto"
            case .on: return "darkmode.option.on"
            case .off: return "darkmode.option.off"
            case .smart: return "darkmode.option.smart"
            }
        }

        var subtitleKey: String {
            switch self {
            case .follow: return "dashboard.mode.follow.subtitle"
            case .on: return "dashboard.mode.on.subtitle"
            case .off: return "dashboard.mode.off.subtitle"
            case .smart: return "dashboard.mode.smart.subtitle"
            }
        }

        var descriptionKey: String {
            switch self {
            case .follow: return "darkmode.desc.auto"
            case .on: return "darkmode.desc.on"
            case .off: return "darkmode.desc.off"
            case .smart: return "darkmode.desc.smart"
            }
        }

        var iconName: String {
            switch self {
            case .follow: return "circle.lefthalf.filled"
            case .on: return "moon.fill"
            case .off: return "sun.max.fill"
            case .smart: return "sparkles"
            }
        }
    }

    private var selectedModeOption: ModeQuickOption {
        switch dataManager.globalConfig.mode {
        case .on:
            return .on
        case .off:
            return .off
        case .auto:
            return dataManager.globalConfig.scheduleEnabled ? .smart : .follow
        }
    }

    private func applyModeOption(_ option: ModeQuickOption) {
        switch option {
        case .follow:
            dataManager.globalConfig.mode = .auto
            dataManager.globalConfig.scheduleEnabled = false
        case .on:
            dataManager.globalConfig.mode = .on
            dataManager.globalConfig.scheduleEnabled = false
        case .off:
            dataManager.globalConfig.mode = .off
            dataManager.globalConfig.scheduleEnabled = false
        case .smart:
            dataManager.globalConfig.mode = .auto
            dataManager.globalConfig.scheduleEnabled = true
        }

        dataManager.saveConfig()
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
                VStack(spacing: SustainabilityMetrics.sectionGap) {
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
                .padding(.horizontal, SustainabilityMetrics.pageHorizontalPadding)
                .padding(.top, SustainabilityMetrics.pageTopPadding)
                .padding(.bottom, SustainabilityMetrics.pageBottomPadding)
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
                VStack(spacing: SustainabilityMetrics.sectionGap) {
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
                .padding(.horizontal, SustainabilityMetrics.pageHorizontalPadding)
                .padding(.top, SustainabilityMetrics.pageTopPadding)
                .padding(.bottom, SustainabilityMetrics.pageBottomPadding)
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            SustainabilityBackground()
            ScrollView {
                VStack(spacing: SustainabilityMetrics.sectionGap) {
                    todaySummaryCard
                    weeklyTrendCard
                    siteDistributionCard
                }
                .padding(.horizontal, SustainabilityMetrics.pageHorizontalPadding)
                .padding(.top, SustainabilityMetrics.pageTopPadding)
                .padding(.bottom, SustainabilityMetrics.pageBottomPadding)
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
        let weekAverage = dataManager.currentWeekEyeCareRecords.reduce(0) { $0 + $1.darkModeDuration } / Double(max(dataManager.currentWeekEyeCareRecords.count, 1))

        return ZStack {
            RoundedRectangle(cornerRadius: SustainabilityMetrics.heroCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [
                                SustainabilityPalette.primary.opacity(0.44),
                                SustainabilityPalette.cta.opacity(0.42),
                                SustainabilityPalette.info.opacity(0.33)
                            ]
                            : [
                                SustainabilityPalette.primary.opacity(0.86),
                                SustainabilityPalette.cta.opacity(0.74),
                                SustainabilityPalette.info.opacity(0.6)
                            ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: SustainabilityMetrics.heroCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.18 : 0.22), lineWidth: 1)
            RoundedRectangle(cornerRadius: SustainabilityMetrics.heroCornerRadius, style: .continuous)
                .fill(Color.black.opacity(colorScheme == .dark ? 0.18 : 0.1))

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("今日护眼总览")
                        .font(SustainabilityTypography.title)
                        .foregroundColor(.white)
                    Spacer()
                    Text("实时")
                        .font(SustainabilityTypography.captionStrong)
                        .foregroundColor(.white.opacity(0.86))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.16))
                        .clipShape(Capsule())
                }

                HStack(spacing: 8) {
                    detailMetricTile(
                        icon: "moon.stars.fill",
                        title: "深色浏览时长",
                        value: formatDuration(today.darkModeDuration),
                        tint: .white
                    )
                    detailMetricTile(
                        icon: "sun.max.trianglebadge.exclamationmark",
                        title: "蓝光减少估算",
                        value: "约 \(Int(reduction * 100))%",
                        tint: .white
                    )
                }

                HStack(spacing: 8) {
                    detailMetricTile(
                        icon: "globe",
                        title: "护眼网站数",
                        value: "\(today.sitesCount) 个",
                        tint: .white
                    )
                    detailMetricTile(
                        icon: "calendar.badge.clock",
                        title: "本周活跃天数",
                        value: "\(weekActiveDays) / 7",
                        tint: .white
                    )
                }

                Text("周均深色时长 \(formatDuration(weekAverage))，蓝光减少为估算值，仅用于效果感知。")
                    .font(SustainabilityTypography.caption)
                    .foregroundColor(Color.white.opacity(0.82))
                    .lineLimit(2)
            }
            .padding(SustainabilityMetrics.cardInnerPadding)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.26 : 0.14), radius: 11, x: 0, y: 7)
    }

    private func detailMetricTile(icon: String, title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: icon)
                .font(SustainabilityTypography.caption)
                .foregroundColor(Color.white.opacity(0.82))
                .lineLimit(1)
            Text(value)
                .font(SustainabilityTypography.subBodyStrong)
                .foregroundColor(tint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func weeklySummaryBadge(title: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(SustainabilityTypography.caption)
                .foregroundColor(.secondary)
            Spacer(minLength: 4)
            Text(value)
                .font(SustainabilityTypography.captionStrong)
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(SustainabilityPalette.elevated(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func siteRankRow(index: Int, domain: String, duration: TimeInterval, maxDuration: TimeInterval) -> some View {
        HStack(spacing: 10) {
            Text("#\(index + 1)")
                .font(SustainabilityTypography.captionStrong)
                .foregroundColor(SustainabilityPalette.cta)
                .frame(width: 26, height: 26)
                .background(SustainabilityPalette.cta.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(domain)
                        .font(SustainabilityTypography.bodyStrong)
                        .lineLimit(1)
                    Spacer()
                    Text(formatDuration(duration))
                        .font(SustainabilityTypography.captionStrong)
                        .foregroundColor(.secondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.secondary.opacity(0.14))
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(SustainabilityPalette.primary.opacity(0.82))
                            .frame(width: max(8, geo.size.width * CGFloat(duration / maxDuration)))
                    }
                }
                .frame(height: 8)
            }
        }
        .sustainabilityInteractiveRow()
    }

    private var weeklyTrendCard: some View {
        let records = dataManager.currentWeekEyeCareRecords
        let maxDuration = max(records.map(\.darkModeDuration).max() ?? 0, 1)
        let activeDays = records.filter { $0.darkModeDuration > 0 }.count
        let averageDuration = records.reduce(0) { $0 + $1.darkModeDuration } / Double(max(records.count, 1))

        return SustainabilityCard {
            VStack(alignment: .leading, spacing: 12) {
                SustainabilitySectionTitle("周趋势", subtitle: "每日深色浏览时长")

                HStack(spacing: 8) {
                    weeklySummaryBadge(title: "周均时长", value: formatDuration(averageDuration), color: SustainabilityPalette.primary)
                    weeklySummaryBadge(title: "活跃天数", value: "\(activeDays) / 7", color: SustainabilityPalette.success)
                }

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
                            .frame(width: 76, alignment: .trailing)
                    }
                    .frame(height: 22)
                }
            }
        }
    }

    private var siteDistributionCard: some View {
        let topSites = Array(dataManager.siteDistribution(for: Date()).prefix(3))
        let maxDuration = max(topSites.map(\.duration).max() ?? 1, 1)

        return SustainabilityCard {
            VStack(alignment: .leading, spacing: 12) {
                SustainabilitySectionTitle("站点报告", subtitle: "今日深色时长 TOP 3")

                if topSites.isEmpty {
                    Text("今日还没有可统计的护眼站点数据。")
                        .font(SustainabilityTypography.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(topSites.enumerated()), id: \.offset) { index, site in
                        siteRankRow(
                            index: index,
                            domain: site.domain,
                            duration: site.duration,
                            maxDuration: maxDuration
                        )
                        if index < topSites.count - 1 {
                            Divider()
                                .padding(.leading, 36)
                        }
                    }
                }
            }
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
