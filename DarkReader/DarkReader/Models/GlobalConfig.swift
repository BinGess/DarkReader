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
    // 深色模式开始时间（小时，0-23）
    var scheduleStartHour: Int
    // 深色模式开始时间（分钟，0-59）
    var scheduleStartMinute: Int
    // 深色模式结束时间（小时，0-23）
    var scheduleEndHour: Int
    // 深色模式结束时间（分钟，0-59）
    var scheduleEndMinute: Int

    // 默认初始化（新用户首次启动时使用）
    init() {
        self.mode = .auto
        self.defaultThemeId = "theme_002"   // 默认使用深灰主题
        self.dimImages = true
        self.ignoreNativeDarkMode = false
        self.performanceMode = false
        self.extensionEnabled = true
        self.appLanguage = .system
        self.scheduleEnabled = false
        self.scheduleStartHour = 22    // 默认晚上 22:00 开启
        self.scheduleStartMinute = 0
        self.scheduleEndHour = 7       // 默认早上 7:00 结束
        self.scheduleEndMinute = 0
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
        case scheduleStartHour
        case scheduleStartMinute
        case scheduleEndHour
        case scheduleEndMinute
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
        self.scheduleStartHour = try container.decodeIfPresent(Int.self, forKey: .scheduleStartHour) ?? 22
        self.scheduleStartMinute = try container.decodeIfPresent(Int.self, forKey: .scheduleStartMinute) ?? 0
        self.scheduleEndHour = try container.decodeIfPresent(Int.self, forKey: .scheduleEndHour) ?? 7
        self.scheduleEndMinute = try container.decodeIfPresent(Int.self, forKey: .scheduleEndMinute) ?? 0
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
        try container.encode(scheduleStartHour, forKey: .scheduleStartHour)
        try container.encode(scheduleStartMinute, forKey: .scheduleStartMinute)
        try container.encode(scheduleEndHour, forKey: .scheduleEndHour)
        try container.encode(scheduleEndMinute, forKey: .scheduleEndMinute)
    }

    // MARK: - 定时模式辅助属性

    /// 当前时间是否处于定时深色模式区间内
    var isInScheduledTime: Bool {
        guard scheduleEnabled else { return false }
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let currentMinutes = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        let startMinutes = scheduleStartHour * 60 + scheduleStartMinute
        let endMinutes = scheduleEndHour * 60 + scheduleEndMinute

        if startMinutes < endMinutes {
            // 同日区间，例如 08:00 - 20:00
            return currentMinutes >= startMinutes && currentMinutes < endMinutes
        } else {
            // 跨午夜区间，例如 22:00 - 07:00（开始 > 结束）
            return currentMinutes >= startMinutes || currentMinutes < endMinutes
        }
    }

    /// 格式化时间显示，如 "22:00 - 07:00"
    var scheduleTimeDescription: String {
        String(format: "%02d:%02d – %02d:%02d",
               scheduleStartHour, scheduleStartMinute,
               scheduleEndHour, scheduleEndMinute)
    }
}

enum AppLanguageOption: String, Codable, CaseIterable, Identifiable {
    case system
    case zhHans
    case en

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .system:
            return .autoupdatingCurrent
        case .zhHans:
            return Locale(identifier: "zh-Hans")
        case .en:
            return Locale(identifier: "en")
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
        }
    }
}

// MARK: - 深色模式枚举

enum DarkMode: String, Codable, CaseIterable, Identifiable {
    case auto = "auto"  // 跟随系统 prefers-color-scheme
    case on   = "on"    // 始终开启深色模式
    case off  = "off"   // 始终关闭深色模式

    var id: String { rawValue }

    // 在 UI 中显示的名称 key
    var displayNameKey: String {
        switch self {
        case .auto: return "darkmode.option.auto"
        case .on:   return "darkmode.option.on"
        case .off:  return "darkmode.option.off"
        }
    }

    // SF Symbols 图标名称
    var systemImageName: String {
        switch self {
        case .auto: return "circle.lefthalf.filled"
        case .on:   return "moon.fill"
        case .off:  return "sun.max.fill"
        }
    }

    // 用于展示在 Dashboard 的简短说明 key
    var descriptionKey: String {
        switch self {
        case .auto: return "darkmode.desc.auto"
        case .on:   return "darkmode.desc.on"
        case .off:  return "darkmode.desc.off"
        }
    }
}
