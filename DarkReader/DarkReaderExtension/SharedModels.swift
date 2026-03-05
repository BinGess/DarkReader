//
//  SharedModels.swift
//  DarkReaderExtension
//
//  Extension 侧需要的共享模型定义。字段与宿主 App 保持一致，
//  以确保 App Groups 中 JSON 编解码兼容。
//

import Foundation

enum SharedKeys {
    static let appGroupSuite = "group.com.darkreader.shared"
    static let globalConfig = "DarkReader_GlobalConfig"
    static let themes = "DarkReader_CustomThemes"
    static let siteRules = "DarkReader_SiteRules"
    static let visitedSites = "DarkReader_VisitedSites"
    static let errorLogs = "DarkReader_ErrorLogs"
    static let feedbackRecords = "DarkReader_Feedback"
    static let eyeCareDailyRecords = "DarkReader_EyeCareDailyRecords"
    static let eyeCareSiteDurations = "DarkReader_EyeCareSiteDurations"
}

struct ErrorLog: Codable, Identifiable {
    var id = UUID()
    var domain: String
    var errorMsg: String
    var time: Date
}

struct FeedbackRecord: Codable, Identifiable {
    var id = UUID()
    var domain: String
    var themeId: String
    var content: String
    var time: Date
}

struct DailyEyeCareRecord: Codable, Equatable {
    var date: Date
    var darkModeDuration: TimeInterval
    var sitesCount: Int
    var dominantThemeId: String
}

struct GlobalConfig: Codable, Equatable {
    var mode: DarkMode
    var defaultThemeId: String
    var dimImages: Bool
    var ignoreNativeDarkMode: Bool
    var performanceMode: Bool
    var extensionEnabled: Bool
    var appLanguage: AppLanguageOption
    var scheduleEnabled: Bool
    var scheduleTriggerSource: ScheduleTriggerSource
    var scheduleStartHour: Int
    var scheduleStartMinute: Int
    var scheduleEndHour: Int
    var scheduleEndMinute: Int
    var sunLatitude: Double?
    var sunLongitude: Double?
    var sunScheduleSunriseHour: Int
    var sunScheduleSunriseMinute: Int
    var sunScheduleSunsetHour: Int
    var sunScheduleSunsetMinute: Int
    var sunScheduleUpdatedAt: Date?
    var lowBatteryEyeCareEnabled: Bool
    var lowBatteryThreshold: Int
    var lowBatteryRestoreOnCharging: Bool
    var lowBatteryModeActive: Bool
    var hideCookieBanners: Bool
    var dailyEyeCareNotificationEnabled: Bool
    var dailyEyeCareNotificationHour: Int
    var dailyEyeCareNotificationMinute: Int
    var weeklyEyeCareNotificationEnabled: Bool
    var weeklyEyeCareNotificationWeekday: Int
    var weeklyEyeCareNotificationHour: Int
    var weeklyEyeCareNotificationMinute: Int

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
        self.scheduleStartHour = try container.decodeIfPresent(Int.self, forKey: .scheduleStartHour) ?? 22
        self.scheduleStartMinute = try container.decodeIfPresent(Int.self, forKey: .scheduleStartMinute) ?? 0
        self.scheduleEndHour = try container.decodeIfPresent(Int.self, forKey: .scheduleEndHour) ?? 7
        self.scheduleEndMinute = try container.decodeIfPresent(Int.self, forKey: .scheduleEndMinute) ?? 0
        self.sunLatitude = try container.decodeIfPresent(Double.self, forKey: .sunLatitude)
        self.sunLongitude = try container.decodeIfPresent(Double.self, forKey: .sunLongitude)
        self.sunScheduleSunriseHour = try container.decodeIfPresent(Int.self, forKey: .sunScheduleSunriseHour) ?? 7
        self.sunScheduleSunriseMinute = try container.decodeIfPresent(Int.self, forKey: .sunScheduleSunriseMinute) ?? 0
        self.sunScheduleSunsetHour = try container.decodeIfPresent(Int.self, forKey: .sunScheduleSunsetHour) ?? 18
        self.sunScheduleSunsetMinute = try container.decodeIfPresent(Int.self, forKey: .sunScheduleSunsetMinute) ?? 0
        self.sunScheduleUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .sunScheduleUpdatedAt)
        self.lowBatteryEyeCareEnabled = try container.decodeIfPresent(Bool.self, forKey: .lowBatteryEyeCareEnabled) ?? false
        let threshold = try container.decodeIfPresent(Int.self, forKey: .lowBatteryThreshold) ?? 20
        self.lowBatteryThreshold = [10, 20, 30].contains(threshold) ? threshold : 20
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

enum AppLanguageOption: String, Codable {
    case system
    case zhHans
    case en
}

enum DarkMode: String, Codable {
    case auto
    case on
    case off
}

enum ScheduleTriggerSource: String, Codable {
    case manual
    case system
    case sunsetSunrise
}

enum ThemeCategory: String, Codable {
    case eyeCare = "eye_care"
    case warmLight = "warm_light"
    case reading = "reading"
    case oled = "oled"
    case highContrast = "high_contrast"
    case nature = "nature"
}

struct DarkTheme: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var backgroundColor: String
    var textColor: String
    var secondaryTextColor: String
    var linkColor: String
    var borderColor: String
    var imageBrightness: Double
    var imageGrayscale: Double
    let isBuiltin: Bool
    var createdAt: Date
    var updatedAt: Date
    var category: ThemeCategory
    var eyeCareScore: Int
    var warmthLevel: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case backgroundColor
        case textColor
        case secondaryTextColor
        case linkColor
        case borderColor
        case imageBrightness
        case imageGrayscale
        case isBuiltin
        case createdAt
        case updatedAt
        case category
        case eyeCareScore
        case warmthLevel
    }

    init(
        id: String,
        name: String,
        backgroundColor: String,
        textColor: String,
        secondaryTextColor: String,
        linkColor: String,
        borderColor: String,
        imageBrightness: Double = 0.75,
        imageGrayscale: Double = 0.0,
        isBuiltin: Bool,
        category: ThemeCategory = .reading,
        eyeCareScore: Int = 4,
        warmthLevel: Int = 3,
        createdAt: Date,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.secondaryTextColor = secondaryTextColor
        self.linkColor = linkColor
        self.borderColor = borderColor
        self.imageBrightness = min(max(imageBrightness, 0.35), 1.0)
        self.imageGrayscale = min(max(imageGrayscale, 0.0), 1.0)
        self.isBuiltin = isBuiltin
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.category = category
        self.eyeCareScore = min(max(eyeCareScore, 1), 5)
        self.warmthLevel = min(max(warmthLevel, 1), 5)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.backgroundColor = try container.decode(String.self, forKey: .backgroundColor)
        self.textColor = try container.decode(String.self, forKey: .textColor)
        self.secondaryTextColor = try container.decode(String.self, forKey: .secondaryTextColor)
        self.linkColor = try container.decode(String.self, forKey: .linkColor)
        self.borderColor = try container.decode(String.self, forKey: .borderColor)
        self.imageBrightness = min(
            max(try container.decodeIfPresent(Double.self, forKey: .imageBrightness) ?? 0.75, 0.35),
            1.0
        )
        self.imageGrayscale = min(
            max(try container.decodeIfPresent(Double.self, forKey: .imageGrayscale) ?? 0.0, 0.0),
            1.0
        )
        self.isBuiltin = try container.decode(Bool.self, forKey: .isBuiltin)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(timeIntervalSince1970: 0)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? self.createdAt
        self.category = try container.decodeIfPresent(ThemeCategory.self, forKey: .category) ?? .reading
        self.eyeCareScore = min(max(try container.decodeIfPresent(Int.self, forKey: .eyeCareScore) ?? 4, 1), 5)
        self.warmthLevel = min(max(try container.decodeIfPresent(Int.self, forKey: .warmthLevel) ?? 3, 1), 5)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(backgroundColor, forKey: .backgroundColor)
        try container.encode(textColor, forKey: .textColor)
        try container.encode(secondaryTextColor, forKey: .secondaryTextColor)
        try container.encode(linkColor, forKey: .linkColor)
        try container.encode(borderColor, forKey: .borderColor)
        try container.encode(imageBrightness, forKey: .imageBrightness)
        try container.encode(imageGrayscale, forKey: .imageGrayscale)
        try container.encode(isBuiltin, forKey: .isBuiltin)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(category, forKey: .category)
        try container.encode(eyeCareScore, forKey: .eyeCareScore)
        try container.encode(warmthLevel, forKey: .warmthLevel)
    }
}

extension DarkTheme {
    static let builtins: [DarkTheme] = [
        DarkTheme(
            id: "theme_003",
            name: "护眼绿",
            backgroundColor: "#1a1f1a",
            textColor: "#c8d8c8",
            secondaryTextColor: "#7a9a7a",
            linkColor: "#5db8a0",
            borderColor: "#2a402a",
            isBuiltin: true,
            category: .eyeCare,
            eyeCareScore: 5,
            createdAt: Date(timeIntervalSince1970: 2),
            updatedAt: Date(timeIntervalSince1970: 2)
        ),
        DarkTheme(
            id: "theme_005",
            name: "苔藓森林",
            backgroundColor: "#162016",
            textColor: "#b8d4a8",
            secondaryTextColor: "#6a9058",
            linkColor: "#72b85a",
            borderColor: "#203820",
            isBuiltin: true,
            category: .eyeCare,
            eyeCareScore: 5,
            createdAt: Date(timeIntervalSince1970: 4),
            updatedAt: Date(timeIntervalSince1970: 4)
        ),
        DarkTheme(
            id: "theme_006",
            name: "茶褪护眼",
            backgroundColor: "#1c2018",
            textColor: "#c4d4a8",
            secondaryTextColor: "#7a9060",
            linkColor: "#90b86a",
            borderColor: "#303820",
            isBuiltin: true,
            category: .eyeCare,
            eyeCareScore: 5,
            createdAt: Date(timeIntervalSince1970: 5),
            updatedAt: Date(timeIntervalSince1970: 5)
        ),
        DarkTheme(
            id: "theme_007",
            name: "深岩舒目",
            backgroundColor: "#141c14",
            textColor: "#aac09a",
            secondaryTextColor: "#6a8060",
            linkColor: "#7aaa80",
            borderColor: "#203020",
            isBuiltin: true,
            category: .eyeCare,
            eyeCareScore: 5,
            createdAt: Date(timeIntervalSince1970: 6),
            updatedAt: Date(timeIntervalSince1970: 6)
        ),
        DarkTheme(
            id: "theme_004",
            name: "暖棕色",
            backgroundColor: "#2c2015",
            textColor: "#e8d5b0",
            secondaryTextColor: "#a08060",
            linkColor: "#d4a95a",
            borderColor: "#4a3520",
            isBuiltin: true,
            category: .warmLight,
            eyeCareScore: 4,
            createdAt: Date(timeIntervalSince1970: 3),
            updatedAt: Date(timeIntervalSince1970: 3)
        ),
        DarkTheme(
            id: "theme_008",
            name: "琥珀夜灯",
            backgroundColor: "#2a1e0a",
            textColor: "#e8c880",
            secondaryTextColor: "#b09050",
            linkColor: "#d4b048",
            borderColor: "#503c18",
            isBuiltin: true,
            category: .warmLight,
            eyeCareScore: 4,
            createdAt: Date(timeIntervalSince1970: 7),
            updatedAt: Date(timeIntervalSince1970: 7)
        ),
        DarkTheme(
            id: "theme_009",
            name: "橙光护目",
            backgroundColor: "#281808",
            textColor: "#f0c870",
            secondaryTextColor: "#b08040",
            linkColor: "#e0a840",
            borderColor: "#503018",
            isBuiltin: true,
            category: .warmLight,
            eyeCareScore: 4,
            createdAt: Date(timeIntervalSince1970: 8),
            updatedAt: Date(timeIntervalSince1970: 8)
        ),
        DarkTheme(
            id: "theme_010",
            name: "烛火书房",
            backgroundColor: "#2e1c0c",
            textColor: "#e8c060",
            secondaryTextColor: "#a88040",
            linkColor: "#d0a838",
            borderColor: "#503020",
            isBuiltin: true,
            category: .warmLight,
            eyeCareScore: 4,
            createdAt: Date(timeIntervalSince1970: 9),
            updatedAt: Date(timeIntervalSince1970: 9)
        ),
        DarkTheme(
            id: "theme_002",
            name: "深灰（默认）",
            backgroundColor: "#1e1e1e",
            textColor: "#e0e0e0",
            secondaryTextColor: "#999999",
            linkColor: "#4da6ff",
            borderColor: "#444444",
            isBuiltin: true,
            category: .reading,
            eyeCareScore: 4,
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1)
        ),
        DarkTheme(
            id: "theme_011",
            name: "暗夜纸书",
            backgroundColor: "#24201a",
            textColor: "#ddd0b8",
            secondaryTextColor: "#9a9080",
            linkColor: "#b8a880",
            borderColor: "#403830",
            isBuiltin: true,
            category: .reading,
            eyeCareScore: 4,
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 10)
        ),
        DarkTheme(
            id: "theme_012",
            name: "深夜书房",
            backgroundColor: "#1e1e28",
            textColor: "#d0cce0",
            secondaryTextColor: "#9898b0",
            linkColor: "#9090c8",
            borderColor: "#303048",
            isBuiltin: true,
            category: .reading,
            eyeCareScore: 4,
            createdAt: Date(timeIntervalSince1970: 11),
            updatedAt: Date(timeIntervalSince1970: 11)
        ),
        DarkTheme(
            id: "theme_013",
            name: "米纸深读",
            backgroundColor: "#222018",
            textColor: "#dcd4c0",
            secondaryTextColor: "#989068",
            linkColor: "#b8a870",
            borderColor: "#403c28",
            isBuiltin: true,
            category: .reading,
            eyeCareScore: 4,
            createdAt: Date(timeIntervalSince1970: 12),
            updatedAt: Date(timeIntervalSince1970: 12)
        ),
        DarkTheme(
            id: "theme_001",
            name: "纯黑 OLED",
            backgroundColor: "#000000",
            textColor: "#ffffff",
            secondaryTextColor: "#aaaaaa",
            linkColor: "#4ea1f3",
            borderColor: "#333333",
            isBuiltin: true,
            category: .oled,
            eyeCareScore: 3,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        ),
        DarkTheme(
            id: "theme_014",
            name: "深空黑",
            backgroundColor: "#070707",
            textColor: "#e8e8e8",
            secondaryTextColor: "#a0a0a0",
            linkColor: "#6090e0",
            borderColor: "#282828",
            isBuiltin: true,
            category: .oled,
            eyeCareScore: 3,
            createdAt: Date(timeIntervalSince1970: 13),
            updatedAt: Date(timeIntervalSince1970: 13)
        ),
        DarkTheme(
            id: "theme_015",
            name: "炭黑简约",
            backgroundColor: "#111111",
            textColor: "#dedede",
            secondaryTextColor: "#909090",
            linkColor: "#5888d8",
            borderColor: "#303030",
            isBuiltin: true,
            category: .oled,
            eyeCareScore: 3,
            createdAt: Date(timeIntervalSince1970: 14),
            updatedAt: Date(timeIntervalSince1970: 14)
        ),
        DarkTheme(
            id: "theme_016",
            name: "石墨深色",
            backgroundColor: "#1a1a1a",
            textColor: "#e0e0e0",
            secondaryTextColor: "#888888",
            linkColor: "#5080cc",
            borderColor: "#383838",
            isBuiltin: true,
            category: .oled,
            eyeCareScore: 3,
            createdAt: Date(timeIntervalSince1970: 15),
            updatedAt: Date(timeIntervalSince1970: 15)
        ),
        DarkTheme(
            id: "theme_017",
            name: "高对比纯白",
            backgroundColor: "#000000",
            textColor: "#ffffff",
            secondaryTextColor: "#cccccc",
            linkColor: "#60b0ff",
            borderColor: "#444444",
            isBuiltin: true,
            category: .highContrast,
            eyeCareScore: 3,
            createdAt: Date(timeIntervalSince1970: 16),
            updatedAt: Date(timeIntervalSince1970: 16)
        ),
        DarkTheme(
            id: "theme_018",
            name: "黄字夜视",
            backgroundColor: "#000000",
            textColor: "#fff176",
            secondaryTextColor: "#c0b050",
            linkColor: "#f0e000",
            borderColor: "#404000",
            isBuiltin: true,
            category: .highContrast,
            eyeCareScore: 3,
            createdAt: Date(timeIntervalSince1970: 17),
            updatedAt: Date(timeIntervalSince1970: 17)
        ),
        DarkTheme(
            id: "theme_019",
            name: "青字护目",
            backgroundColor: "#000000",
            textColor: "#b2fef7",
            secondaryTextColor: "#80c8c0",
            linkColor: "#40e0d0",
            borderColor: "#004040",
            isBuiltin: true,
            category: .highContrast,
            eyeCareScore: 3,
            createdAt: Date(timeIntervalSince1970: 18),
            updatedAt: Date(timeIntervalSince1970: 18)
        ),
        DarkTheme(
            id: "theme_020",
            name: "深蓝海洋",
            backgroundColor: "#0d1a2a",
            textColor: "#a0c8e8",
            secondaryTextColor: "#607898",
            linkColor: "#68b0e0",
            borderColor: "#1e3a58",
            isBuiltin: true,
            category: .nature,
            eyeCareScore: 4,
            createdAt: Date(timeIntervalSince1970: 19),
            updatedAt: Date(timeIntervalSince1970: 19)
        ),
        DarkTheme(
            id: "theme_021",
            name: "紫暮薰衣草",
            backgroundColor: "#1a1228",
            textColor: "#c8a8e8",
            secondaryTextColor: "#907898",
            linkColor: "#b888e0",
            borderColor: "#302050",
            isBuiltin: true,
            category: .nature,
            eyeCareScore: 4,
            createdAt: Date(timeIntervalSince1970: 20),
            updatedAt: Date(timeIntervalSince1970: 20)
        ),
        DarkTheme(
            id: "theme_022",
            name: "深岩石板",
            backgroundColor: "#1a1e22",
            textColor: "#b8c8d4",
            secondaryTextColor: "#788898",
            linkColor: "#80a8c0",
            borderColor: "#283440",
            isBuiltin: true,
            category: .nature,
            eyeCareScore: 4,
            createdAt: Date(timeIntervalSince1970: 21),
            updatedAt: Date(timeIntervalSince1970: 21)
        )
    ]
}

struct SiteRule: Codable, Equatable {
    var mode: SiteMode?
    var themeId: String?
    var updatedAt: Date
    var brightness: Double
    var contrast: Double
    var focusMode: Bool

    init(
        mode: SiteMode? = nil,
        themeId: String? = nil,
        updatedAt: Date = Date(),
        brightness: Double = 1.0,
        contrast: Double = 1.0,
        focusMode: Bool = false
    ) {
        self.mode = mode
        self.themeId = themeId
        self.updatedAt = updatedAt
        self.brightness = min(max(brightness, 0.5), 1.5)
        self.contrast = min(max(contrast, 0.5), 1.5)
        self.focusMode = focusMode
    }

    private enum CodingKeys: String, CodingKey {
        case mode
        case themeId
        case updatedAt
        case brightness
        case contrast
        case focusMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let modeRaw = try container.decodeIfPresent(String.self, forKey: .mode) {
            self.mode = SiteMode(rawValue: modeRaw) ?? .smart
        } else {
            self.mode = nil
        }
        self.themeId = try container.decodeIfPresent(String.self, forKey: .themeId)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date(timeIntervalSince1970: 0)
        self.brightness = min(max(try container.decodeIfPresent(Double.self, forKey: .brightness) ?? 1.0, 0.5), 1.5)
        self.contrast = min(max(try container.decodeIfPresent(Double.self, forKey: .contrast) ?? 1.0, 0.5), 1.5)
        self.focusMode = try container.decodeIfPresent(Bool.self, forKey: .focusMode) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(mode, forKey: .mode)
        try container.encodeIfPresent(themeId, forKey: .themeId)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(brightness, forKey: .brightness)
        try container.encode(contrast, forKey: .contrast)
        try container.encode(focusMode, forKey: .focusMode)
    }
}

enum SiteMode: String, Codable {
    case follow
    case system
    case on
    case off
    case smart
}

typealias SiteRules = [String: SiteRule]

extension String {
    var mainDomain: String {
        let parts = self.split(separator: ".").map(String.init)
        guard parts.count > 2 else { return self }
        return parts.suffix(2).joined(separator: ".")
    }
}
