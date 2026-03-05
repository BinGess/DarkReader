//
//  GlobalConfig.swift
//  DarkReader
//
//  全局配置模型，存储用户的暗色模式偏好设置
//  通过 App Groups UserDefaults 在宿主 App 和 Safari 扩展之间共享
//

import Foundation

// 全局配置：控制扩展的整体行为
struct GlobalConfig: Codable, Equatable {
    // 全局模式：auto（跟随系统）/ on（强制开启）/ off（强制关闭）
    var mode: DarkMode
    // 当前默认使用的主题 ID，关联 Theme.builtins 或自定义主题
    var defaultThemeId: String
    // 是否对网页图片进行亮度降低处理（不反色）
    var dimImages: Bool
    // 是否强制覆盖网页自身的 prefers-color-scheme: dark 实现
    var ignoreNativeDarkMode: Bool
    // 性能模式：降低动态监听和增量暗化开销，适配低配设备
    var performanceMode: Bool
    // 扩展整体启用状态（与 Safari 扩展开关同步）
    var extensionEnabled: Bool
    // 语言偏好：跟随系统 / 中文 / 英文
    var appLanguage: AppLanguageOption

    // 定时深色模式开关
    var scheduleEnabled: Bool
    // 定时触发来源：手动时间 / 跟随系统 / 跟随日落日出
    var scheduleTriggerSource: ScheduleTriggerSource
    // 手动定时开始时间（小时，0-23）
    var scheduleStartHour: Int
    // 手动定时开始时间（分钟，0-59）
    var scheduleStartMinute: Int
    // 手动定时结束时间（小时，0-23）
    var scheduleEndHour: Int
    // 手动定时结束时间（分钟，0-59）
    var scheduleEndMinute: Int
    // 智能定时：上次成功定位的纬度
    var sunLatitude: Double?
    // 智能定时：上次成功定位的经度
    var sunLongitude: Double?
    // 智能定时：当日日出时间（小时，0-23）
    var sunScheduleSunriseHour: Int
    // 智能定时：当日日出时间（分钟，0-59）
    var sunScheduleSunriseMinute: Int
    // 智能定时：当日日落时间（小时，0-23）
    var sunScheduleSunsetHour: Int
    // 智能定时：当日日落时间（分钟，0-59）
    var sunScheduleSunsetMinute: Int
    // 智能定时：日出日落上次刷新时间
    var sunScheduleUpdatedAt: Date?

    // 低电量自动护眼开关
    var lowBatteryEyeCareEnabled: Bool
    // 低电量阈值（10 / 20 / 30）
    var lowBatteryThreshold: Int
    // 充电/电量恢复后是否自动恢复之前模式
    var lowBatteryRestoreOnCharging: Bool
    // 当前是否处于低电量接管状态
    var lowBatteryModeActive: Bool

    // Cookie 横幅自动隐藏（默认关闭，需用户主动开启）
    var hideCookieBanners: Bool
    // 每日护眼报告通知
    var dailyEyeCareNotificationEnabled: Bool
    var dailyEyeCareNotificationHour: Int
    var dailyEyeCareNotificationMinute: Int
    // 每周护眼报告通知
    var weeklyEyeCareNotificationEnabled: Bool
    // 1=周日 ... 7=周六（遵循 Calendar weekday）
    var weeklyEyeCareNotificationWeekday: Int
    var weeklyEyeCareNotificationHour: Int
    var weeklyEyeCareNotificationMinute: Int

    // 默认初始化（新用户首次启动时使用）
    init() {
        self.mode = .auto
        self.defaultThemeId = "theme_002"
        self.dimImages = true
        self.ignoreNativeDarkMode = false
        self.performanceMode = false
        self.extensionEnabled = true
        self.appLanguage = .system

        self.scheduleEnabled = false
        self.scheduleTriggerSource = .manual
        self.scheduleStartHour = 22
        self.scheduleStartMinute = 0
        self.scheduleEndHour = 7
        self.scheduleEndMinute = 0
        self.sunLatitude = nil
        self.sunLongitude = nil
        self.sunScheduleSunriseHour = 7
        self.sunScheduleSunriseMinute = 0
        self.sunScheduleSunsetHour = 18
        self.sunScheduleSunsetMinute = 0
        self.sunScheduleUpdatedAt = nil

        self.lowBatteryEyeCareEnabled = false
        self.lowBatteryThreshold = 20
        self.lowBatteryRestoreOnCharging = true
        self.lowBatteryModeActive = false

        self.hideCookieBanners = false
        self.dailyEyeCareNotificationEnabled = false
        self.dailyEyeCareNotificationHour = 21
        self.dailyEyeCareNotificationMinute = 30
        self.weeklyEyeCareNotificationEnabled = false
        self.weeklyEyeCareNotificationWeekday = 2
        self.weeklyEyeCareNotificationHour = 20
        self.weeklyEyeCareNotificationMinute = 0
    }

    private enum CodingKeys: String, CodingKey {
        case mode
        case defaultThemeId
        case dimImages
        case ignoreNativeDarkMode
        case performanceMode
        case extensionEnabled
        case appLanguage
        case scheduleEnabled
        case scheduleTriggerSource
        case scheduleStartHour
        case scheduleStartMinute
        case scheduleEndHour
        case scheduleEndMinute
        case sunLatitude
        case sunLongitude
        case sunScheduleSunriseHour
        case sunScheduleSunriseMinute
        case sunScheduleSunsetHour
        case sunScheduleSunsetMinute
        case sunScheduleUpdatedAt
        case lowBatteryEyeCareEnabled
        case lowBatteryThreshold
        case lowBatteryRestoreOnCharging
        case lowBatteryModeActive
        case hideCookieBanners
        case dailyEyeCareNotificationEnabled
        case dailyEyeCareNotificationHour
        case dailyEyeCareNotificationMinute
        case weeklyEyeCareNotificationEnabled
        case weeklyEyeCareNotificationWeekday
        case weeklyEyeCareNotificationHour
        case weeklyEyeCareNotificationMinute
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.mode = try container.decodeIfPresent(DarkMode.self, forKey: .mode) ?? .auto
        self.defaultThemeId = try container.decodeIfPresent(String.self, forKey: .defaultThemeId) ?? "theme_002"
        self.dimImages = try container.decodeIfPresent(Bool.self, forKey: .dimImages) ?? true
        self.ignoreNativeDarkMode = try container.decodeIfPresent(Bool.self, forKey: .ignoreNativeDarkMode) ?? false
        self.performanceMode = try container.decodeIfPresent(Bool.self, forKey: .performanceMode) ?? false
        self.extensionEnabled = try container.decodeIfPresent(Bool.self, forKey: .extensionEnabled) ?? true
        self.appLanguage = try container.decodeIfPresent(AppLanguageOption.self, forKey: .appLanguage) ?? .system

        self.scheduleEnabled = try container.decodeIfPresent(Bool.self, forKey: .scheduleEnabled) ?? false
        self.scheduleTriggerSource = try container.decodeIfPresent(ScheduleTriggerSource.self, forKey: .scheduleTriggerSource) ?? .manual
        self.scheduleStartHour = Self.clampHour(try container.decodeIfPresent(Int.self, forKey: .scheduleStartHour) ?? 22)
        self.scheduleStartMinute = Self.clampMinute(try container.decodeIfPresent(Int.self, forKey: .scheduleStartMinute) ?? 0)
        self.scheduleEndHour = Self.clampHour(try container.decodeIfPresent(Int.self, forKey: .scheduleEndHour) ?? 7)
        self.scheduleEndMinute = Self.clampMinute(try container.decodeIfPresent(Int.self, forKey: .scheduleEndMinute) ?? 0)

        self.sunLatitude = try container.decodeIfPresent(Double.self, forKey: .sunLatitude)
        self.sunLongitude = try container.decodeIfPresent(Double.self, forKey: .sunLongitude)
        self.sunScheduleSunriseHour = Self.clampHour(try container.decodeIfPresent(Int.self, forKey: .sunScheduleSunriseHour) ?? 7)
        self.sunScheduleSunriseMinute = Self.clampMinute(try container.decodeIfPresent(Int.self, forKey: .sunScheduleSunriseMinute) ?? 0)
        self.sunScheduleSunsetHour = Self.clampHour(try container.decodeIfPresent(Int.self, forKey: .sunScheduleSunsetHour) ?? 18)
        self.sunScheduleSunsetMinute = Self.clampMinute(try container.decodeIfPresent(Int.self, forKey: .sunScheduleSunsetMinute) ?? 0)
        self.sunScheduleUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .sunScheduleUpdatedAt)

        self.lowBatteryEyeCareEnabled = try container.decodeIfPresent(Bool.self, forKey: .lowBatteryEyeCareEnabled) ?? false
        let rawThreshold = try container.decodeIfPresent(Int.self, forKey: .lowBatteryThreshold) ?? 20
        self.lowBatteryThreshold = [10, 20, 30].contains(rawThreshold) ? rawThreshold : 20
        self.lowBatteryRestoreOnCharging = try container.decodeIfPresent(Bool.self, forKey: .lowBatteryRestoreOnCharging) ?? true
        self.lowBatteryModeActive = try container.decodeIfPresent(Bool.self, forKey: .lowBatteryModeActive) ?? false

        self.hideCookieBanners = try container.decodeIfPresent(Bool.self, forKey: .hideCookieBanners) ?? false
        self.dailyEyeCareNotificationEnabled = try container.decodeIfPresent(Bool.self, forKey: .dailyEyeCareNotificationEnabled) ?? false
        self.dailyEyeCareNotificationHour = Self.clampHour(
            try container.decodeIfPresent(Int.self, forKey: .dailyEyeCareNotificationHour) ?? 21
        )
        self.dailyEyeCareNotificationMinute = Self.clampMinute(
            try container.decodeIfPresent(Int.self, forKey: .dailyEyeCareNotificationMinute) ?? 30
        )
        self.weeklyEyeCareNotificationEnabled = try container.decodeIfPresent(Bool.self, forKey: .weeklyEyeCareNotificationEnabled) ?? false
        self.weeklyEyeCareNotificationWeekday = Self.clampWeekday(
            try container.decodeIfPresent(Int.self, forKey: .weeklyEyeCareNotificationWeekday) ?? 2
        )
        self.weeklyEyeCareNotificationHour = Self.clampHour(
            try container.decodeIfPresent(Int.self, forKey: .weeklyEyeCareNotificationHour) ?? 20
        )
        self.weeklyEyeCareNotificationMinute = Self.clampMinute(
            try container.decodeIfPresent(Int.self, forKey: .weeklyEyeCareNotificationMinute) ?? 0
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mode, forKey: .mode)
        try container.encode(defaultThemeId, forKey: .defaultThemeId)
        try container.encode(dimImages, forKey: .dimImages)
        try container.encode(ignoreNativeDarkMode, forKey: .ignoreNativeDarkMode)
        try container.encode(performanceMode, forKey: .performanceMode)
        try container.encode(extensionEnabled, forKey: .extensionEnabled)
        try container.encode(appLanguage, forKey: .appLanguage)

        try container.encode(scheduleEnabled, forKey: .scheduleEnabled)
        try container.encode(scheduleTriggerSource, forKey: .scheduleTriggerSource)
        try container.encode(scheduleStartHour, forKey: .scheduleStartHour)
        try container.encode(scheduleStartMinute, forKey: .scheduleStartMinute)
        try container.encode(scheduleEndHour, forKey: .scheduleEndHour)
        try container.encode(scheduleEndMinute, forKey: .scheduleEndMinute)
        try container.encodeIfPresent(sunLatitude, forKey: .sunLatitude)
        try container.encodeIfPresent(sunLongitude, forKey: .sunLongitude)
        try container.encode(sunScheduleSunriseHour, forKey: .sunScheduleSunriseHour)
        try container.encode(sunScheduleSunriseMinute, forKey: .sunScheduleSunriseMinute)
        try container.encode(sunScheduleSunsetHour, forKey: .sunScheduleSunsetHour)
        try container.encode(sunScheduleSunsetMinute, forKey: .sunScheduleSunsetMinute)
        try container.encodeIfPresent(sunScheduleUpdatedAt, forKey: .sunScheduleUpdatedAt)

        try container.encode(lowBatteryEyeCareEnabled, forKey: .lowBatteryEyeCareEnabled)
        try container.encode(lowBatteryThreshold, forKey: .lowBatteryThreshold)
        try container.encode(lowBatteryRestoreOnCharging, forKey: .lowBatteryRestoreOnCharging)
        try container.encode(lowBatteryModeActive, forKey: .lowBatteryModeActive)

        try container.encode(hideCookieBanners, forKey: .hideCookieBanners)
        try container.encode(dailyEyeCareNotificationEnabled, forKey: .dailyEyeCareNotificationEnabled)
        try container.encode(dailyEyeCareNotificationHour, forKey: .dailyEyeCareNotificationHour)
        try container.encode(dailyEyeCareNotificationMinute, forKey: .dailyEyeCareNotificationMinute)
        try container.encode(weeklyEyeCareNotificationEnabled, forKey: .weeklyEyeCareNotificationEnabled)
        try container.encode(weeklyEyeCareNotificationWeekday, forKey: .weeklyEyeCareNotificationWeekday)
        try container.encode(weeklyEyeCareNotificationHour, forKey: .weeklyEyeCareNotificationHour)
        try container.encode(weeklyEyeCareNotificationMinute, forKey: .weeklyEyeCareNotificationMinute)
    }

    // MARK: - 定时模式辅助属性

    var isInScheduledTime: Bool {
        isInScheduledTime(at: Date())
    }

    func isInScheduledTime(at date: Date) -> Bool {
        guard scheduleEnabled else { return false }
        guard let range = activeScheduleRangeMinutes else { return false }

        let now = Calendar.current.dateComponents([.hour, .minute], from: date)
        let currentMinutes = (now.hour ?? 0) * 60 + (now.minute ?? 0)

        if range.start < range.end {
            return currentMinutes >= range.start && currentMinutes < range.end
        }
        return currentMinutes >= range.start || currentMinutes < range.end
    }

    var scheduleTimeDescription: String {
        switch scheduleTriggerSource {
        case .manual:
            return String(
                format: "%02d:%02d – %02d:%02d",
                scheduleStartHour,
                scheduleStartMinute,
                scheduleEndHour,
                scheduleEndMinute
            )
        case .system:
            return "跟随系统深色模式"
        case .sunsetSunrise:
            return String(
                format: "日落 %02d:%02d · 日出 %02d:%02d",
                sunScheduleSunsetHour,
                sunScheduleSunsetMinute,
                sunScheduleSunriseHour,
                sunScheduleSunriseMinute
            )
        }
    }

    var hasSunLocation: Bool {
        sunLatitude != nil && sunLongitude != nil
    }

    private var activeScheduleRangeMinutes: (start: Int, end: Int)? {
        switch scheduleTriggerSource {
        case .manual:
            return (
                scheduleStartHour * 60 + scheduleStartMinute,
                scheduleEndHour * 60 + scheduleEndMinute
            )
        case .system:
            return nil
        case .sunsetSunrise:
            return (
                sunScheduleSunsetHour * 60 + sunScheduleSunsetMinute,
                sunScheduleSunriseHour * 60 + sunScheduleSunriseMinute
            )
        }
    }

    private static func clampHour(_ value: Int) -> Int {
        min(max(value, 0), 23)
    }

    private static func clampMinute(_ value: Int) -> Int {
        min(max(value, 0), 59)
    }

    private static func clampWeekday(_ value: Int) -> Int {
        min(max(value, 1), 7)
    }
}

enum AppLanguageOption: String, Codable, CaseIterable, Identifiable {
    case system
    case zhHans
    case en
    case ja

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .system:
            return .autoupdatingCurrent
        case .zhHans:
            return Locale(identifier: "zh-Hans")
        case .en:
            return Locale(identifier: "en")
        case .ja:
            return Locale(identifier: "ja")
        }
    }

    var displayNameKey: String {
        switch self {
        case .system:
            return "language.option.system"
        case .zhHans:
            return "language.option.zhHans"
        case .en:
            return "language.option.en"
        case .ja:
            return "language.option.ja"
        }
    }
}

// MARK: - 深色模式枚举

enum DarkMode: String, Codable, CaseIterable, Identifiable {
    case auto = "auto"
    case on   = "on"
    case off  = "off"

    var id: String { rawValue }

    var displayNameKey: String {
        switch self {
        case .auto: return "darkmode.option.auto"
        case .on:   return "darkmode.option.on"
        case .off:  return "darkmode.option.off"
        }
    }

    var systemImageName: String {
        switch self {
        case .auto: return "circle.lefthalf.filled"
        case .on:   return "moon.fill"
        case .off:  return "sun.max.fill"
        }
    }

    var descriptionKey: String {
        switch self {
        case .auto: return "darkmode.desc.auto"
        case .on:   return "darkmode.desc.on"
        case .off:  return "darkmode.desc.off"
        }
    }
}

enum ScheduleTriggerSource: String, Codable, CaseIterable, Identifiable {
    case manual
    case system
    case sunsetSunrise

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .manual:
            return "手动设时间"
        case .system:
            return "跟随系统深色"
        case .sunsetSunrise:
            return "跟随当地日落日出"
        }
    }

    var subtitle: String {
        switch self {
        case .manual:
            return "固定时段自动切换"
        case .system:
            return "与系统深色模式同步"
        case .sunsetSunrise:
            return "按当日日落/日出自动变化"
        }
    }
}
