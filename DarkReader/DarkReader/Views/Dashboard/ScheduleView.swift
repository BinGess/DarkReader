//
//  ScheduleView.swift
//  DarkReader
//
//  定时深色模式：按时间段自动开启/关闭深色模式
//  差异化功能之一，解决 App Store 4.3(a) Spam 问题
//

import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @Environment(\.colorScheme) private var colorScheme

    // 将 config 字段映射到本地 Date，方便 DatePicker 操作
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()

    var body: some View {
        ZStack {
            SustainabilityBackground()

            ScrollView {
                VStack(spacing: 14) {
                    // 功能说明卡片
                    explainCard

                    // 开关 + 时间选择
                    scheduleCard

                    // 当前状态预览
                    statusCard

                    // 使用建议
                    tipsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
            .font(SustainabilityTypography.body)
        }
        .navigationTitle("定时深色模式")
        .navigationBarTitleDisplayMode(.inline)
        .sustainabilityChrome()
        .onAppear { syncFromConfig() }
        .onChange(of: startTime) { _ in applyStartTime() }
        .onChange(of: endTime) { _ in applyEndTime() }
    }

    // MARK: - 功能说明

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
                    Text("自动定时开启")
                        .font(SustainabilityTypography.bodyStrong)
                    Text("设定时间段，每天自动切换深色模式，无需手动操作。跨午夜时段（如 22:00 – 07:00）同样支持。")
                        .font(SustainabilityTypography.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - 开关与时间选择

    private var scheduleCard: some View {
        SustainabilityCard {
            VStack(alignment: .leading, spacing: 0) {

                // 总开关
                HStack {
                    scheduleIcon("timer", color: SustainabilityPalette.cta)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("启用定时模式")
                            .font(SustainabilityTypography.bodyStrong)
                        Text("开启后将按以下时间段自动切换")
                            .font(SustainabilityTypography.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $dataManager.globalConfig.scheduleEnabled)
                        .labelsHidden()
                        .tint(SustainabilityPalette.primary)
                        .onChange(of: dataManager.globalConfig.scheduleEnabled) { _ in
                            dataManager.saveConfig()
                        }
                }
                .sustainabilityInteractiveRow()

                if dataManager.globalConfig.scheduleEnabled {
                    Divider()
                        .overlay(Color.primary.opacity(0.08))
                        .padding(.vertical, 4)

                    // 开始时间
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
                        DatePicker(
                            "",
                            selection: $startTime,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(SustainabilityPalette.primary)
                    }
                    .sustainabilityInteractiveRow()

                    Divider()
                        .overlay(Color.primary.opacity(0.08))
                        .padding(.vertical, 4)

                    // 结束时间
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
                        DatePicker(
                            "",
                            selection: $endTime,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(SustainabilityPalette.warm)
                    }
                    .sustainabilityInteractiveRow()
                }
            }
        }
    }

    // MARK: - 状态预览

    private var statusCard: some View {
        SustainabilityCard {
            VStack(alignment: .leading, spacing: 12) {
                SustainabilitySectionTitle("当前状态", subtitle: "基于定时配置的实时判断")

                HStack(spacing: 14) {
                    // 时间段展示
                    VStack(alignment: .leading, spacing: 4) {
                        Text("定时区间")
                            .font(SustainabilityTypography.caption)
                            .foregroundColor(.secondary)
                        Text(dataManager.globalConfig.scheduleTimeDescription)
                            .font(SustainabilityTypography.bodyStrong)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(SustainabilityPalette.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    // 当前状态
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
                    Text("定时模式未启用。开启后，此区间内将自动激活深色模式（全局模式需设为\"跟随系统\"时定时才生效）。")
                        .font(SustainabilityTypography.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - 使用建议

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

                tipRow(icon: "moon.fill", text: "护眼推荐：设置 22:00 – 07:00，晚间减少蓝光刺激")
                tipRow(icon: "sun.max.fill", text: "日间场景：设置 08:00 – 20:00，在白天也使用深色护眼")
                tipRow(icon: "info.circle.fill", text: "定时仅在全局模式为\"跟随系统\"时生效；\"强制开启/关闭\"会覆盖定时设置")
            }
        }
    }

    // MARK: - 工具视图

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

    // MARK: - 状态属性

    private var currentStatusText: String {
        guard dataManager.globalConfig.scheduleEnabled else { return "未启用" }
        return dataManager.globalConfig.isInScheduledTime ? "深色模式中" : "浅色模式中"
    }

    private var currentStatusColor: Color {
        guard dataManager.globalConfig.scheduleEnabled else { return .secondary }
        return dataManager.globalConfig.isInScheduledTime ? SustainabilityPalette.primary : SustainabilityPalette.warm
    }

    // MARK: - 时间同步

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

    private func timeFromHourMinute(hour: Int, minute: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps) ?? Date()
    }
}

#Preview {
    NavigationView {
        ScheduleView()
            .environmentObject(SharedDataManager.shared)
    }
}
