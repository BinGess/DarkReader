//
//  SettingsView.swift
//  DarkReader
//
//  Sustainability Platform 风格设置中心：同步、数据管理、帮助与隐私
//

import SwiftUI
import StoreKit
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: SharedDataManager
    @EnvironmentObject var notificationManager: EyeCareNotificationManager
    @StateObject private var iCloudSync = iCloudSyncManager.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("onboardingStartFromStepOne") private var onboardingStartFromStepOne = false

    @State private var showClearDataConfirm = false
    @State private var showPrivacy = false
    @State private var showSiteSettingsGuide = false
    @State private var showDimImagesGuide = false
    @State private var showHelp = false
    @State private var showFeedbackList = false

    var body: some View {
        ZStack {
            SustainabilityBackground()

            ScrollView {
                VStack(spacing: SustainabilityMetrics.sectionGap) {
                    syncCard
                    eyeCareNotificationCard
                    guideCard
                    dataCard
                    aboutCard
                }
                .padding(.horizontal, SustainabilityMetrics.pageHorizontalPadding)
                .padding(.top, SustainabilityMetrics.pageTopPadding)
                .padding(.bottom, SustainabilityMetrics.pageBottomPadding)
            }
            .font(SustainabilityTypography.body)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
        }
        .sustainabilityChrome()
        .sheet(isPresented: $showPrivacy) { PrivacyView() }
        .sheet(isPresented: $showSiteSettingsGuide) {
            NavigationView {
                SiteSettingsGuideView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("关闭") { showSiteSettingsGuide = false }
                        }
                    }
            }
            .sustainabilityChrome()
        }
        .sheet(isPresented: $showDimImagesGuide) {
            NavigationView {
                DimImagesGuideView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("关闭") { showDimImagesGuide = false }
                        }
                    }
            }
            .sustainabilityChrome()
        }
        .sheet(isPresented: $showHelp) { HelpView() }
        .sheet(isPresented: $showFeedbackList) { FeedbackListView().environmentObject(dataManager) }
        .alert("清除所有数据", isPresented: $showClearDataConfirm) {
            Button("清除", role: .destructive) {
                dataManager.clearAllData()
                iCloudSync.clearAll()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这将删除所有自定义主题和站点规则，恢复默认设置。此操作不可撤销。")
        }
    }

    private var syncCard: some View {
        SustainabilityCard {
            VStack(alignment: .leading, spacing: 12) {
                settingsSectionHeader("云端同步", subtitle: "在同一 Apple ID 设备间同步主题和站点规则")

                Toggle(isOn: $iCloudSync.isSyncEnabled) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "icloud.fill")
                            .foregroundColor(SustainabilityPalette.cta)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("启用 iCloud 同步")
                                .font(SustainabilityTypography.bodyStrong)
                            Text("仅同步主题和站点规则，不同步全局开关状态。")
                                .font(SustainabilityTypography.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .sustainabilityInteractiveRow()
                .tint(SustainabilityPalette.primary)
                .onChange(of: iCloudSync.isSyncEnabled) { enabled in
                    if enabled {
                        iCloudSync.startSync(themes: dataManager.themes, siteRules: dataManager.siteRules)
                    } else {
                        iCloudSync.stopSync()
                    }
                }

                if iCloudSync.isSyncEnabled {
                    HStack {
                        SustainabilityStatusPill(
                            icon: syncIndicator.icon,
                            text: syncIndicator.text,
                            color: syncIndicator.color
                        )
                        Spacer()
                        if let lastSyncDate = iCloudSync.lastSyncDate {
                            Text(lastSyncDate.formatted(date: .omitted, time: .shortened))
                                .font(SustainabilityTypography.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let message = iCloudSync.lastSyncMessage, !message.isEmpty {
                        Text(message)
                            .font(SustainabilityTypography.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var syncIndicator: (icon: String, text: String, color: Color) {
        switch iCloudSync.lastSyncStatus {
        case .idle:
            return ("clock.arrow.circlepath", "等待首次同步", SustainabilityPalette.info)
        case .syncing:
            return ("arrow.triangle.2.circlepath", "正在同步", SustainabilityPalette.info)
        case .pending:
            return ("clock.badge.exclamationmark", "等待系统完成", SustainabilityPalette.warm)
        case .success:
            return ("checkmark.seal.fill", "同步成功", SustainabilityPalette.success)
        case .unavailable:
            return ("icloud.slash.fill", "iCloud 不可用", SustainabilityPalette.warm)
        case .failed:
            return ("exclamationmark.triangle.fill", "同步失败", SustainabilityPalette.danger)
        }
    }

    private var eyeCareNotificationCard: some View {
        SustainabilityCard {
            VStack(alignment: .leading, spacing: 12) {
                settingsSectionHeader("护眼报告通知", subtitle: "每日/每周自动提醒查看护眼数据")

                Toggle(isOn: $dataManager.globalConfig.dailyEyeCareNotificationEnabled) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(SustainabilityPalette.cta)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("每日护眼报告")
                                .font(SustainabilityTypography.bodyStrong)
                            Text("按固定时间推送今日护眼时长与蓝光估算。")
                                .font(SustainabilityTypography.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .sustainabilityInteractiveRow()
                .tint(SustainabilityPalette.primary)
                .onChange(of: dataManager.globalConfig.dailyEyeCareNotificationEnabled) { _ in
                    saveConfigAndReschedule()
                }

                if dataManager.globalConfig.dailyEyeCareNotificationEnabled {
                    notificationTimeRow(
                        title: "每日推送时间",
                        hour: $dataManager.globalConfig.dailyEyeCareNotificationHour,
                        minute: $dataManager.globalConfig.dailyEyeCareNotificationMinute
                    )
                    .onChange(of: dataManager.globalConfig.dailyEyeCareNotificationHour) { _ in
                        saveConfigAndReschedule()
                    }
                    .onChange(of: dataManager.globalConfig.dailyEyeCareNotificationMinute) { _ in
                        saveConfigAndReschedule()
                    }
                }

                Divider()

                Toggle(isOn: $dataManager.globalConfig.weeklyEyeCareNotificationEnabled) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "chart.line.uptrend.xyaxis.circle")
                            .foregroundColor(SustainabilityPalette.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("每周护眼报告")
                                .font(SustainabilityTypography.bodyStrong)
                            Text("按周推送本周护眼天数与累计时长。")
                                .font(SustainabilityTypography.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .sustainabilityInteractiveRow()
                .tint(SustainabilityPalette.primary)
                .onChange(of: dataManager.globalConfig.weeklyEyeCareNotificationEnabled) { _ in
                    saveConfigAndReschedule()
                }

                if dataManager.globalConfig.weeklyEyeCareNotificationEnabled {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .foregroundColor(SustainabilityPalette.cta)
                            .frame(width: 18)
                        Text("周报日")
                            .font(SustainabilityTypography.bodyStrong)
                        Spacer()
                        Picker("周报日", selection: $dataManager.globalConfig.weeklyEyeCareNotificationWeekday) {
                            ForEach(1...7, id: \.self) { weekday in
                                Text(weekdayTitle(weekday)).tag(weekday)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(SustainabilityTypography.subBody)
                    }
                    .sustainabilityInteractiveRow()
                    .onChange(of: dataManager.globalConfig.weeklyEyeCareNotificationWeekday) { _ in
                        saveConfigAndReschedule()
                    }

                    notificationTimeRow(
                        title: "每周推送时间",
                        hour: $dataManager.globalConfig.weeklyEyeCareNotificationHour,
                        minute: $dataManager.globalConfig.weeklyEyeCareNotificationMinute
                    )
                    .onChange(of: dataManager.globalConfig.weeklyEyeCareNotificationHour) { _ in
                        saveConfigAndReschedule()
                    }
                    .onChange(of: dataManager.globalConfig.weeklyEyeCareNotificationMinute) { _ in
                        saveConfigAndReschedule()
                    }
                }

                if notificationManager.authorizationStatus == .denied {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("系统通知权限未开启，无法发送护眼报告提醒。")
                            .font(SustainabilityTypography.caption)
                            .foregroundColor(.secondary)
                        Button("前往系统设置开启通知") {
                            openSystemNotificationSettings()
                        }
                        .font(SustainabilityTypography.captionStrong)
                        .foregroundColor(SustainabilityPalette.cta)
                    }
                }
            }
        }
    }

    private var dataCard: some View {
        SustainabilityCard {
            VStack(alignment: .leading, spacing: 12) {
                settingsSectionHeader("数据管理", subtitle: "查看数据规模并执行清理")

                statRow(
                    icon: "globe.americas.fill",
                    title: "已自定义站点",
                    value: localizedCount("settings.count.sites", dataManager.siteRules.count)
                )
                statRow(
                    icon: "swatchpalette.fill",
                    title: "自定义主题",
                    value: localizedCount("settings.count.themes", dataManager.themes.filter { !$0.isBuiltin }.count)
                )

                if !dataManager.feedbackRecords.isEmpty {
                    Button {
                        showFeedbackList = true
                    } label: {
                        HStack {
                            Label("反馈记录", systemImage: "bubble.left.and.bubble.right.fill")
                                .font(SustainabilityTypography.body)
                            Spacer()
                            Text(localizedCount("settings.count.feedback", dataManager.feedbackRecords.count))
                                .font(SustainabilityTypography.caption)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(SustainabilityTypography.captionStrong)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    .sustainabilityInteractiveRow()
                }

                Button(role: .destructive) {
                    showClearDataConfirm = true
                } label: {
                    Label("清除所有数据", systemImage: "trash.fill")
                        .font(SustainabilityTypography.bodyStrong)
                }
                .sustainabilityInteractiveRow()
            }
        }
    }

    private var aboutCard: some View {
        SustainabilityCard {
            VStack(alignment: .leading, spacing: 12) {
                settingsSectionHeader("支持与合规", subtitle: "隐私政策、评分和版本信息")

                languageSettingRow
                settingsAction(icon: "lock.shield.fill", title: "隐私政策") { showPrivacy = true }
                settingsAction(icon: "star.fill", title: "给我们评分") { requestReview() }

                Divider()
                HStack {
                    Text("版本")
                        .font(SustainabilityTypography.bodyStrong)
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .font(SustainabilityTypography.subBody)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var languageSettingRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .foregroundColor(SustainabilityPalette.cta)
                .frame(width: 18)

            Text("语言")
                .font(SustainabilityTypography.bodyStrong)
                .foregroundColor(.primary)

            Spacer()

            Picker("语言", selection: $dataManager.globalConfig.appLanguage) {
                ForEach(AppLanguageOption.allCases) { language in
                    Text(LocalizedStringKey(language.displayNameKey)).tag(language)
                }
            }
            .pickerStyle(.menu)
            .font(SustainabilityTypography.subBody)
            .onChange(of: dataManager.globalConfig.appLanguage) { _ in
                dataManager.saveConfig()
            }
        }
        .sustainabilityInteractiveRow()
    }

    private var guideCard: some View {
        SustainabilityCard {
            VStack(alignment: .leading, spacing: 12) {
                settingsSectionHeader("指南", subtitle: "常用操作一键直达")

                guideAction(
                    icon: "puzzlepiece.extension.fill",
                    title: "如何启用扩展",
                    subtitle: "点击后直接进入新手引导第 1 步"
                ) {
                    onboardingStartFromStepOne = true
                    hasCompletedOnboarding = false
                }

                Divider()

                guideAction(
                    icon: "globe.badge.chevron.backward",
                    title: "更改网站配置",
                    subtitle: "参考竞品讲解，按步骤在 Safari 中操作"
                ) {
                    showSiteSettingsGuide = true
                }

                Divider()

                guideAction(
                    icon: "photo.fill",
                    title: "在网页上暗化图片",
                    subtitle: "查看简洁步骤，快速开启图片暗化"
                ) {
                    showDimImagesGuide = true
                }

                Divider()

                guideAction(
                    icon: "questionmark.circle.fill",
                    title: "更多帮助和常见问题",
                    subtitle: "查看问题排查和使用建议"
                ) {
                    showHelp = true
                }
            }
        }
    }

    private func statRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(SustainabilityPalette.primary)
                .frame(width: 18)
            Text(LocalizedStringKey(title))
                .font(SustainabilityTypography.bodyStrong)
            Spacer()
            Text(value)
                .font(SustainabilityTypography.subBody)
                .foregroundColor(.secondary)
        }
        .sustainabilityInteractiveRow()
    }

    private func settingsAction(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(SustainabilityPalette.cta)
                    .frame(width: 18)
                Text(LocalizedStringKey(title))
                    .font(SustainabilityTypography.bodyStrong)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(SustainabilityTypography.captionStrong)
                    .foregroundColor(.secondary)
            }
            .sustainabilityInteractiveRow()
        }
        .buttonStyle(.plain)
    }

    private func notificationTimeRow(title: String, hour: Binding<Int>, minute: Binding<Int>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .foregroundColor(SustainabilityPalette.cta)
                .frame(width: 18)
            Text(LocalizedStringKey(title))
                .font(SustainabilityTypography.bodyStrong)
            Spacer()
            Picker("小时", selection: hour) {
                ForEach(0..<24, id: \.self) { value in
                    Text(String(format: "%02d", value)).tag(value)
                }
            }
            .pickerStyle(.menu)
            .font(SustainabilityTypography.subBody)

            Text(":")
                .foregroundColor(.secondary)

            Picker("分钟", selection: minute) {
                ForEach(0..<60, id: \.self) { value in
                    Text(String(format: "%02d", value)).tag(value)
                }
            }
            .pickerStyle(.menu)
            .font(SustainabilityTypography.subBody)
        }
        .sustainabilityInteractiveRow()
    }

    private func guideAction(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(SustainabilityPalette.cta)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(title))
                        .font(SustainabilityTypography.bodyStrong)
                        .foregroundColor(.primary)
                    Text(LocalizedStringKey(subtitle))
                        .font(SustainabilityTypography.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(SustainabilityTypography.captionStrong)
                    .foregroundColor(.secondary)
            }
            .sustainabilityInteractiveRow()
        }
        .buttonStyle(.plain)
    }

    private func settingsSectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(LocalizedStringKey(title))
                .font(SustainabilityTypography.title)
            Text(LocalizedStringKey(subtitle))
                .font(SustainabilityTypography.caption)
                .foregroundColor(.secondary)
        }
    }

    private func localizedCount(_ key: String, _ count: Int) -> String {
        String(format: NSLocalizedString(key, comment: ""), count)
    }

    private func saveConfigAndReschedule() {
        dataManager.saveConfig()
        notificationManager.syncSchedule()
    }

    private func weekdayTitle(_ weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        guard !symbols.isEmpty else { return "Day \(weekday)" }
        let index = min(max(weekday - 1, 0), symbols.count - 1)
        return symbols[index]
    }

    private func openSystemNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func requestReview() {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            if #available(iOS 16.0, *) {
                AppStore.requestReview(in: scene)
            } else {
                SKStoreReviewController.requestReview(in: scene)
            }
        }
    }
}

struct FeedbackListView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                SustainabilityBackground()
                List(dataManager.feedbackRecords.reversed()) { record in
                    SustainabilityCard {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(record.domain)
                                .font(SustainabilityTypography.bodyStrong)
                            Text(record.content)
                                .font(SustainabilityTypography.body)
                                .lineLimit(3)
                            Text(record.time.formatted(date: .abbreviated, time: .shortened))
                                .font(SustainabilityTypography.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(
                        EdgeInsets(
                            top: SustainabilityMetrics.listRowInsetVertical,
                            leading: SustainabilityMetrics.listRowInsetHorizontal,
                            bottom: SustainabilityMetrics.listRowInsetVertical,
                            trailing: SustainabilityMetrics.listRowInsetHorizontal
                        )
                    )
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .applyListBackgroundClear()
            }
            .navigationTitle("反馈记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .sustainabilityChrome()
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
