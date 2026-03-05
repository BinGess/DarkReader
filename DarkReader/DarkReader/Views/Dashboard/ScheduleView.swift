//
//  ScheduleView.swift
//  DarkReader
//
//  智能定时深色模式：手动时间 / 跟随系统 / 跟随当地日落日出
//

import SwiftUI
import CoreLocation
import Combine

struct ScheduleView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    @StateObject private var locationService = SunScheduleLocationService()

    var body: some View {
        ZStack {
            SustainabilityBackground()

            ScrollView {
                VStack(spacing: SustainabilityMetrics.sectionGap) {
                    explainCard
                    scheduleCard
                    statusCard
                    tipsCard
                }
                .padding(.horizontal, SustainabilityMetrics.pageHorizontalPadding)
                .padding(.top, SustainabilityMetrics.pageTopPadding)
                .padding(.bottom, SustainabilityMetrics.pageBottomPadding)
            }
            .sustainabilityReadableContent()
        }
        .navigationTitle("智能定时")
        .navigationBarTitleDisplayMode(.inline)
        .sustainabilityChrome()
        .onAppear {
            syncFromConfig()
            ensureSunScheduleReady()
        }
        .onChange(of: startTime) { _ in applyStartTime() }
        .onChange(of: endTime) { _ in applyEndTime() }
        .onChange(of: dataManager.globalConfig.scheduleTriggerSource) { _ in
            dataManager.saveConfig()
            ensureSunScheduleReady(forceRefresh: true)
        }
        .onChange(of: locationService.location) { location in
            guard let location else { return }
            dataManager.globalConfig.sunLatitude = location.coordinate.latitude
            dataManager.globalConfig.sunLongitude = location.coordinate.longitude
            dataManager.refreshSunScheduleIfNeeded(force: true)
            dataManager.saveConfig()
        }
    }

    private var explainCard: some View {
        SustainabilityCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(SustainabilityPalette.primary.opacity(0.18))
                        .frame(width: 52, height: 52)
                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.system(size: 22))
                        .foregroundColor(SustainabilityPalette.primary)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("设置一次，自动护眼")
                        .font(SustainabilityTypography.bodyStrong)
                    Text("支持手动时段、跟随系统深色、跟随当地日落日出。开启后每日自动切换，无需反复调整。")
                        .font(SustainabilityTypography.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var scheduleCard: some View {
        SustainabilityCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    scheduleIcon("timer", color: SustainabilityPalette.cta)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("启用智能定时")
                            .font(SustainabilityTypography.bodyStrong)
                        Text("在自动模式下按触发源切换深色")
                            .font(SustainabilityTypography.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $dataManager.globalConfig.scheduleEnabled)
                        .labelsHidden()
                        .tint(SustainabilityPalette.primary)
                        .onChange(of: dataManager.globalConfig.scheduleEnabled) { _ in
                            dataManager.saveConfig()
                            ensureSunScheduleReady()
                        }
                }
                .sustainabilityInteractiveRow()

                if dataManager.globalConfig.scheduleEnabled {
                    Divider()
                        .overlay(Color.primary.opacity(0.08))
                        .padding(.vertical, 4)

                    triggerSourcePicker

                    switch dataManager.globalConfig.scheduleTriggerSource {
                    case .manual:
                        manualTimePickers
                    case .system:
                        systemFollowHint
                    case .sunsetSunrise:
                        sunSchedulePreview
                    }
                }
            }
        }
    }

    private var triggerSourcePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                scheduleIcon("sparkles", color: SustainabilityPalette.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("触发来源")
                        .font(SustainabilityTypography.bodyStrong)
                    Text("选择自动切换的判定依据")
                        .font(SustainabilityTypography.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .sustainabilityInteractiveRow()

            Picker("触发来源", selection: $dataManager.globalConfig.scheduleTriggerSource) {
                ForEach(ScheduleTriggerSource.allCases) { source in
                    Text(source.displayName).tag(source)
                }
            }
            .pickerStyle(.segmented)
            .sustainabilityInteractiveRow()

            Text(dataManager.globalConfig.scheduleTriggerSource.subtitle)
                .font(SustainabilityTypography.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
    }

    private var manualTimePickers: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(Color.primary.opacity(0.08))
                .padding(.vertical, 4)

            HStack {
                scheduleIcon("moon.stars.fill", color: SustainabilityPalette.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("开始时间")
                        .font(SustainabilityTypography.bodyStrong)
                    Text("深色模式开启时间")
                        .font(SustainabilityTypography.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(SustainabilityPalette.primary)
            }
            .sustainabilityInteractiveRow()

            Divider()
                .overlay(Color.primary.opacity(0.08))
                .padding(.vertical, 4)

            HStack {
                scheduleIcon("sun.and.horizon.fill", color: SustainabilityPalette.warm)
                VStack(alignment: .leading, spacing: 2) {
                    Text("结束时间")
                        .font(SustainabilityTypography.bodyStrong)
                    Text("深色模式关闭时间")
                        .font(SustainabilityTypography.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(SustainabilityPalette.warm)
            }
            .sustainabilityInteractiveRow()
        }
    }

    private var systemFollowHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .overlay(Color.primary.opacity(0.08))
                .padding(.vertical, 4)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "circle.lefthalf.filled")
                    .foregroundColor(SustainabilityPalette.info)
                    .font(SustainabilityTypography.subBodyStrong)
                VStack(alignment: .leading, spacing: 4) {
                    Text("将跟随系统深色模式")
                        .font(SustainabilityTypography.bodyStrong)
                    Text("当系统切换到深色时自动启用护眼样式；系统为浅色时自动关闭。")
                        .font(SustainabilityTypography.caption)
                        .foregroundColor(.secondary)
                }
            }
            .sustainabilityInteractiveRow()
        }
    }

    private var sunSchedulePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .overlay(Color.primary.opacity(0.08))
                .padding(.vertical, 4)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sun.horizon.fill")
                    .foregroundColor(SustainabilityPalette.warm)
                    .font(SustainabilityTypography.subBodyStrong)
                VStack(alignment: .leading, spacing: 4) {
                    Text("当地日落日出智能定时")
                        .font(SustainabilityTypography.bodyStrong)

                    if let updated = dataManager.globalConfig.sunScheduleUpdatedAt {
                        Text("今日日落 \(formattedSunset())，日出 \(formattedSunrise())")
                            .font(SustainabilityTypography.caption)
                            .foregroundColor(.secondary)
                        Text("上次更新：\(updated.formatted(date: .abbreviated, time: .shortened))")
                            .font(SustainabilityTypography.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("尚未获取当地日落日出，请授权定位后自动计算。")
                            .font(SustainabilityTypography.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer(minLength: 8)
            }
            .sustainabilityInteractiveRow()

            HStack(spacing: 10) {
                Button {
                    locationService.requestLocation()
                } label: {
                    Label("更新定位", systemImage: "location.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(SustainabilityPalette.primary)

                Button {
                    ensureSunScheduleReady(forceRefresh: true)
                } label: {
                    Label("刷新时刻", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding(.horizontal, 2)

            if let statusText = locationService.statusText {
                Text(statusText)
                    .font(SustainabilityTypography.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var statusCard: some View {
        SustainabilityCard {
            VStack(alignment: .leading, spacing: 12) {
                SustainabilitySectionTitle("当前状态", subtitle: "基于智能定时配置的实时判断")

                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("触发策略")
                            .font(SustainabilityTypography.caption)
                            .foregroundColor(.secondary)
                        Text(dataManager.globalConfig.scheduleTimeDescription)
                            .font(SustainabilityTypography.bodyStrong)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(SustainabilityPalette.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("现在")
                            .font(SustainabilityTypography.caption)
                            .foregroundColor(.secondary)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(currentStatusColor)
                                .frame(width: 8, height: 8)
                            Text(currentStatusText)
                                .font(SustainabilityTypography.bodyStrong)
                                .foregroundColor(currentStatusColor)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(currentStatusColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if !dataManager.globalConfig.scheduleEnabled {
                    Text("智能定时未启用。开启后可自动跟随时间、系统或日落日出切换。")
                        .font(SustainabilityTypography.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var tipsCard: some View {
        SustainabilityCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(SustainabilityPalette.warm)
                        .font(SustainabilityTypography.subBodyStrong)
                    Text("使用建议")
                        .font(SustainabilityTypography.bodyStrong)
                }

                tipRow(icon: "sun.horizon.fill", text: "日落日出模式更智能：无需手动随季节调整时间")
                tipRow(icon: "circle.lefthalf.filled", text: "跟随系统模式适合已经使用 iOS 自动深色的用户")
                tipRow(icon: "info.circle.fill", text: "智能定时仅在全局模式为“跟随系统”时生效")
            }
        }
    }

    private func scheduleIcon(_ name: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(color.opacity(0.18))
            .frame(width: 38, height: 38)
            .overlay(
                Image(systemName: name)
                    .font(SustainabilityTypography.subBodyStrong)
                    .foregroundColor(color)
            )
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(SustainabilityTypography.caption)
                .foregroundColor(SustainabilityPalette.primary)
                .frame(width: 16)
            Text(text)
                .font(SustainabilityTypography.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var currentStatusText: String {
        let config = dataManager.globalConfig
        guard config.scheduleEnabled else { return "未启用" }
        switch config.scheduleTriggerSource {
        case .manual, .sunsetSunrise:
            return config.isInScheduledTime ? "深色模式中" : "浅色模式中"
        case .system:
            return colorScheme == .dark ? "跟随系统：深色" : "跟随系统：浅色"
        }
    }

    private var currentStatusColor: Color {
        let config = dataManager.globalConfig
        guard config.scheduleEnabled else { return .secondary }
        switch config.scheduleTriggerSource {
        case .manual, .sunsetSunrise:
            return config.isInScheduledTime ? SustainabilityPalette.primary : SustainabilityPalette.warm
        case .system:
            return colorScheme == .dark ? SustainabilityPalette.primary : SustainabilityPalette.warm
        }
    }

    private func syncFromConfig() {
        let config = dataManager.globalConfig
        startTime = timeFromHourMinute(hour: config.scheduleStartHour, minute: config.scheduleStartMinute)
        endTime = timeFromHourMinute(hour: config.scheduleEndHour, minute: config.scheduleEndMinute)
    }

    private func applyStartTime() {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: startTime)
        dataManager.globalConfig.scheduleStartHour = comps.hour ?? 22
        dataManager.globalConfig.scheduleStartMinute = comps.minute ?? 0
        dataManager.saveConfig()
    }

    private func applyEndTime() {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: endTime)
        dataManager.globalConfig.scheduleEndHour = comps.hour ?? 7
        dataManager.globalConfig.scheduleEndMinute = comps.minute ?? 0
        dataManager.saveConfig()
    }

    private func ensureSunScheduleReady(forceRefresh: Bool = false) {
        guard dataManager.globalConfig.scheduleTriggerSource == .sunsetSunrise else { return }

        if dataManager.globalConfig.hasSunLocation {
            dataManager.refreshSunScheduleIfNeeded(force: forceRefresh)
            dataManager.saveConfig()
            return
        }

        locationService.requestLocation()
    }

    private func timeFromHourMinute(hour: Int, minute: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps) ?? Date()
    }

    private func formattedSunrise() -> String {
        String(
            format: "%02d:%02d",
            dataManager.globalConfig.sunScheduleSunriseHour,
            dataManager.globalConfig.sunScheduleSunriseMinute
        )
    }

    private func formattedSunset() -> String {
        String(
            format: "%02d:%02d",
            dataManager.globalConfig.sunScheduleSunsetHour,
            dataManager.globalConfig.sunScheduleSunsetMinute
        )
    }
}

private final class SunScheduleLocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    @Published var statusText: String?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func requestLocation() {
        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            statusText = "正在请求定位权限..."
            manager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            statusText = "定位权限被关闭，请在系统设置中允许“使用 App 时”定位。"
        case .authorizedAlways, .authorizedWhenInUse:
            statusText = "正在获取当前位置..."
            manager.requestLocation()
        @unknown default:
            statusText = "定位状态未知，请稍后重试。"
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            statusText = "正在获取当前位置..."
            manager.requestLocation()
        case .denied, .restricted:
            statusText = "未获得定位权限，无法计算当地日落日出。"
        case .notDetermined:
            statusText = "正在等待定位授权..."
        @unknown default:
            statusText = "定位状态未知，请稍后重试。"
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            statusText = "定位失败，请重试。"
            return
        }
        self.location = location
        statusText = String(
            format: "定位成功：%.2f, %.2f",
            location.coordinate.latitude,
            location.coordinate.longitude
        )
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        statusText = "定位失败：\(error.localizedDescription)"
    }
}

#Preview {
    NavigationView {
        ScheduleView()
            .environmentObject(SharedDataManager.shared)
    }
}
