//
//  Theme.swift
//  DarkReader
//
//  暗色主题模型，包含 22 个内置主题（6 大护眼分类）和自定义主题支持
//  Color(hex:) 扩展允许在 SwiftUI 中直接使用十六进制颜色字符串
//

import Foundation
import SwiftUI

// MARK: - 主题分类

/// 22 个内置主题按护眼场景分为 6 大类
enum ThemeCategory: String, Codable, CaseIterable, Identifiable {
    case eyeCare      = "eye_care"      // 护眼推荐（偏柔和对比与暖色）
    case warmLight    = "warm_light"    // 暖光夜间（偏暖色调，夜晚使用）
    case reading      = "reading"       // 阅读专注（均衡对比，长时阅读）
    case oled         = "oled"          // 极简OLED（纯黑背景，节省 OLED 电量）
    case highContrast = "high_contrast" // 高对比（高对比度，适合特殊视力需求）
    case nature       = "nature"        // 自然舒缓（取自自然色彩，平静舒适）

    var id: String { rawValue }

    /// 分类显示名称
    var displayName: String {
        switch self {
        case .eyeCare:      return "护眼推荐"
        case .warmLight:    return "暖光夜间"
        case .reading:      return "阅读专注"
        case .oled:         return "极简OLED"
        case .highContrast: return "高对比"
        case .nature:       return "自然舒缓"
        }
    }

    /// 分类对应的 SF Symbols 图标
    var icon: String {
        switch self {
        case .eyeCare:      return "eye.circle.fill"
        case .warmLight:    return "flame.fill"
        case .reading:      return "book.fill"
        case .oled:         return "moon.stars.fill"
        case .highContrast: return "circle.lefthalf.filled"
        case .nature:       return "leaf.fill"
        }
    }

    /// 分类代表色十六进制（用于 UI 强调色）
    var accentHexColor: String {
        switch self {
        case .eyeCare:      return "#5db8a0"
        case .warmLight:    return "#d4a95a"
        case .reading:      return "#6b9cc4"
        case .oled:         return "#888888"
        case .highContrast: return "#d0d0d0"
        case .nature:       return "#6ba3c4"
        }
    }

    /// 分类典型护眼评分（1-5，5 最佳）
    var typicalEyeCareScore: Int {
        switch self {
        case .eyeCare:      return 5
        case .warmLight:    return 4
        case .reading:      return 4
        case .oled:         return 3
        case .highContrast: return 3
        case .nature:       return 4
        }
    }

    /// 分类典型暖色程度（1-5，5 最暖）
    var typicalWarmthLevel: Int {
        switch self {
        case .eyeCare:      return 3
        case .warmLight:    return 5
        case .reading:      return 3
        case .oled:         return 2
        case .highContrast: return 2
        case .nature:       return 4
        }
    }
}

// MARK: - 主题模型

struct DarkTheme: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    // 背景色（十六进制，如 "#1e1e1e"）
    var backgroundColor: String
    // 主要文本色
    var textColor: String
    // 辅助/次级文本色
    var secondaryTextColor: String
    // 超链接颜色
    var linkColor: String
    // 边框与分割线颜色
    var borderColor: String
    // 网页图片亮度（0.35...1.0）
    var imageBrightness: Double
    // 网页图片灰度（0...1）
    var imageGrayscale: Double
    // 是否为内置主题（内置主题不可删除）
    let isBuiltin: Bool
    // 主题分类（护眼推荐/暖光夜间/阅读专注/极简OLED/高对比/自然舒缓）
    var category: ThemeCategory
    // 护眼评分（1-5，5 最佳）
    var eyeCareScore: Int
    // 暖色程度（1-5，5 最暖）
    var warmthLevel: Int
    // 创建时间（用于排序）
    var createdAt: Date
    // 最近更新时间（用于多端冲突合并）
    var updatedAt: Date

    // MARK: - SwiftUI Color 便捷属性

    var backgroundSwiftUIColor: Color {
        Color(hex: backgroundColor) ?? Color(hex: "#1e1e1e")!
    }

    var textSwiftUIColor: Color {
        Color(hex: textColor) ?? .white
    }

    var linkSwiftUIColor: Color {
        Color(hex: linkColor) ?? Color(hex: "#4ea1f3")!
    }

    var displayNameLocalizationKey: String {
        if isBuiltin {
            switch id {
            case "theme_001": return "theme.theme_001.name"
            case "theme_002": return "theme.theme_002.name"
            case "theme_003": return "theme.theme_003.name"
            case "theme_004": return "theme.theme_004.name"
            case "theme_005": return "theme.theme_005.name"
            case "theme_006": return "theme.theme_006.name"
            case "theme_007": return "theme.theme_007.name"
            case "theme_008": return "theme.theme_008.name"
            case "theme_009": return "theme.theme_009.name"
            case "theme_010": return "theme.theme_010.name"
            case "theme_011": return "theme.theme_011.name"
            case "theme_012": return "theme.theme_012.name"
            case "theme_013": return "theme.theme_013.name"
            case "theme_014": return "theme.theme_014.name"
            case "theme_015": return "theme.theme_015.name"
            case "theme_016": return "theme.theme_016.name"
            case "theme_017": return "theme.theme_017.name"
            case "theme_018": return "theme.theme_018.name"
            case "theme_019": return "theme.theme_019.name"
            case "theme_020": return "theme.theme_020.name"
            case "theme_021": return "theme.theme_021.name"
            case "theme_022": return "theme.theme_022.name"
            default:          return name
            }
        }
        return name
    }

    var localizedDisplayName: String {
        localizedDisplayName(language: .system)
    }

    func localizedDisplayName(language: AppLanguageOption) -> String {
        DarkTheme.localizedString(
            key: displayNameLocalizationKey,
            fallback: name,
            language: language
        )
    }

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
        case category
        case eyeCareScore
        case warmthLevel
        case createdAt
        case updatedAt
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
        eyeCareScore: Int? = nil,
        warmthLevel: Int? = nil,
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
        self.category = category
        self.eyeCareScore = min(max(eyeCareScore ?? category.typicalEyeCareScore, 1), 5)
        self.warmthLevel = min(max(warmthLevel ?? category.typicalWarmthLevel, 1), 5)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
        let decodedCategory = try container.decodeIfPresent(ThemeCategory.self, forKey: .category) ?? .reading
        self.category = decodedCategory
        self.eyeCareScore = min(
            max(try container.decodeIfPresent(Int.self, forKey: .eyeCareScore) ?? decodedCategory.typicalEyeCareScore, 1),
            5
        )
        self.warmthLevel = min(
            max(try container.decodeIfPresent(Int.self, forKey: .warmthLevel) ?? decodedCategory.typicalWarmthLevel, 1),
            5
        )
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(timeIntervalSince1970: 0)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? self.createdAt
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
        try container.encode(category, forKey: .category)
        try container.encode(eyeCareScore, forKey: .eyeCareScore)
        try container.encode(warmthLevel, forKey: .warmthLevel)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - 本地化助手

extension DarkTheme {
    static func localizedString(key: String, fallback: String, language: AppLanguageOption) -> String {
        if let bundle = bundle(for: language) {
            let localized = bundle.localizedString(forKey: key, value: fallback, table: nil)
            return localized == key ? fallback : localized
        }
        let localized = NSLocalizedString(key, comment: "")
        return localized == key ? fallback : localized
    }

    private static func bundle(for language: AppLanguageOption) -> Bundle? {
        let resource: String
        switch language {
        case .system:
            return nil
        case .zhHans:
            resource = "zh-Hans"
        case .en:
            resource = "en"
        case .ja:
            resource = "ja"
        }
        guard let path = Bundle.main.path(forResource: resource, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return nil
        }
        return bundle
    }
}

// MARK: - 主题库预设

struct ThemeLibraryPreset: Identifiable, Equatable {
    let id: String
    let category: String
    let name: String
    let accentColor: String
    let backgroundColor: String
    let textColor: String
    let secondaryTextColor: String
    let linkColor: String
    let borderColor: String
}

// MARK: - 内置主题（22 个，覆盖 6 大护眼场景）

extension DarkTheme {

    static let builtins: [DarkTheme] = [

        // ──── 护眼推荐（eyeCare）·  绿色系，偏柔和视觉刺激 ────

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

        // ──── 暖光夜间（warmLight）· 暖棕/琥珀系，夜晚舒适 ────

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

        // ──── 阅读专注（reading）· 中性深灰系，长时阅读 ────

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

        // ──── 极简OLED（oled）· 纯黑/近黑，节省屏幕电量 ────

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

        // ──── 高对比（highContrast）· 超高对比，特殊视力需求 ────

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

        // ──── 自然舒缓（nature）· 取自自然，平静放松 ────

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

    // 生成自定义主题 ID（格式：theme_xxxx，xxxx 为随机4位数）
    static func generateCustomId() -> String {
        let number = Int.random(in: 1000...9999)
        return "theme_\(number)"
    }

    // 判断是否为默认主题
    func isDefault(config: GlobalConfig) -> Bool {
        id == config.defaultThemeId
    }

    // MARK: - 主题库预设（来自"添加主题"功能）

    static let libraryPresets: [ThemeLibraryPreset] = [
        ThemeLibraryPreset(
            id: "lib_default_dark",
            category: "默认主题",
            name: "夜航",
            accentColor: "#111111",
            backgroundColor: "#0f172a",
            textColor: "#e2e8f0",
            secondaryTextColor: "#94a3b8",
            linkColor: "#60a5fa",
            borderColor: "#334155"
        ),
        ThemeLibraryPreset(
            id: "lib_default_black",
            category: "默认主题",
            name: "极夜",
            accentColor: "#000000",
            backgroundColor: "#000000",
            textColor: "#f2f2f2",
            secondaryTextColor: "#a3a3a3",
            linkColor: "#7aa2ff",
            borderColor: "#2a2a2a"
        ),
        ThemeLibraryPreset(
            id: "lib_default_night_black",
            category: "默认主题",
            name: "玄墨",
            accentColor: "#000000",
            backgroundColor: "#000000",
            textColor: "#f2f2f2",
            secondaryTextColor: "#a3a3a3",
            linkColor: "#7aa2ff",
            borderColor: "#2a2a2a"
        ),
        ThemeLibraryPreset(
            id: "lib_default_gray",
            category: "默认主题",
            name: "流银",
            accentColor: "#4b5563",
            backgroundColor: "#1f2937",
            textColor: "#e5e7eb",
            secondaryTextColor: "#9ca3af",
            linkColor: "#60a5fa",
            borderColor: "#374151"
        ),
        ThemeLibraryPreset(
            id: "lib_default_brown",
            category: "默认主题",
            name: "陶土",
            accentColor: "#d6c2a1",
            backgroundColor: "#2a1f17",
            textColor: "#f4e4cf",
            secondaryTextColor: "#c7a98c",
            linkColor: "#f5b35a",
            borderColor: "#4a3425"
        ),
        ThemeLibraryPreset(
            id: "lib_six_green",
            category: "六色",
            name: "苔原",
            accentColor: "#34d399",
            backgroundColor: "#131a16",
            textColor: "#d7f5e7",
            secondaryTextColor: "#89bba2",
            linkColor: "#5ee6b3",
            borderColor: "#264233"
        ),
        ThemeLibraryPreset(
            id: "lib_six_yellow",
            category: "六色",
            name: "琥珀光",
            accentColor: "#facc15",
            backgroundColor: "#18150f",
            textColor: "#f8edc6",
            secondaryTextColor: "#c9b374",
            linkColor: "#f5d96b",
            borderColor: "#3e3421"
        ),
        ThemeLibraryPreset(
            id: "lib_six_orange",
            category: "六色",
            name: "余烬",
            accentColor: "#fb923c",
            backgroundColor: "#1d1510",
            textColor: "#f9e1d0",
            secondaryTextColor: "#cf9f7a",
            linkColor: "#ffa96c",
            borderColor: "#4a2f20"
        ),
        ThemeLibraryPreset(
            id: "lib_six_red",
            category: "六色",
            name: "绯焰",
            accentColor: "#ef4444",
            backgroundColor: "#1c1113",
            textColor: "#f7dfe2",
            secondaryTextColor: "#cd9ba3",
            linkColor: "#ff7b88",
            borderColor: "#4a252b"
        ),
        ThemeLibraryPreset(
            id: "lib_six_purple",
            category: "六色",
            name: "紫曜",
            accentColor: "#a855f7",
            backgroundColor: "#1a1324",
            textColor: "#eee5fb",
            secondaryTextColor: "#bea9df",
            linkColor: "#c48dff",
            borderColor: "#3f2f5d"
        ),
        ThemeLibraryPreset(
            id: "lib_six_blue",
            category: "六色",
            name: "深澜",
            accentColor: "#38bdf8",
            backgroundColor: "#0f1622",
            textColor: "#e3ecfb",
            secondaryTextColor: "#9db2d6",
            linkColor: "#6fb2ff",
            borderColor: "#24364f"
        ),
        ThemeLibraryPreset(
            id: "lib_author_dracula",
            category: "作者作品",
            name: "夜歌",
            accentColor: "#bd93f9",
            backgroundColor: "#282a36",
            textColor: "#f8f8f2",
            secondaryTextColor: "#6272a4",
            linkColor: "#8be9fd",
            borderColor: "#44475a"
        ),
        ThemeLibraryPreset(
            id: "lib_author_gruvbox",
            category: "作者作品",
            name: "麦田暮色",
            accentColor: "#d79921",
            backgroundColor: "#282828",
            textColor: "#ebdbb2",
            secondaryTextColor: "#a89984",
            linkColor: "#83a598",
            borderColor: "#504945"
        ),
        ThemeLibraryPreset(
            id: "lib_author_nord",
            category: "作者作品",
            name: "北境霜蓝",
            accentColor: "#88c0d0",
            backgroundColor: "#2e3440",
            textColor: "#eceff4",
            secondaryTextColor: "#a3be8c",
            linkColor: "#81a1c1",
            borderColor: "#4c566a"
        ),
        ThemeLibraryPreset(
            id: "lib_author_one_dark",
            category: "作者作品",
            name: "单色夜",
            accentColor: "#98c379",
            backgroundColor: "#282c34",
            textColor: "#abb2bf",
            secondaryTextColor: "#7f848e",
            linkColor: "#61afef",
            borderColor: "#3a404c"
        ),
        ThemeLibraryPreset(
            id: "lib_author_solarized",
            category: "作者作品",
            name: "日蚀港湾",
            accentColor: "#2aa198",
            backgroundColor: "#002b36",
            textColor: "#93a1a1",
            secondaryTextColor: "#657b83",
            linkColor: "#268bd2",
            borderColor: "#073642"
        ),
        ThemeLibraryPreset(
            id: "lib_author_catppuccin",
            category: "作者作品",
            name: "奶霜夜曲",
            accentColor: "#cba6f7",
            backgroundColor: "#1e1e2e",
            textColor: "#cdd6f4",
            secondaryTextColor: "#a6adc8",
            linkColor: "#89b4fa",
            borderColor: "#313244"
        ),
        ThemeLibraryPreset(
            id: "lib_mood_forest",
            category: "颜色情绪",
            name: "松影",
            accentColor: "#16a34a",
            backgroundColor: "#1b2b24",
            textColor: "#ddeede",
            secondaryTextColor: "#9cbba4",
            linkColor: "#72d39b",
            borderColor: "#355545"
        ),
        ThemeLibraryPreset(
            id: "lib_mood_ocean",
            category: "颜色情绪",
            name: "潮汐",
            accentColor: "#1d4ed8",
            backgroundColor: "#102a43",
            textColor: "#d9e8ff",
            secondaryTextColor: "#9ab6db",
            linkColor: "#6ea8ff",
            borderColor: "#264b70"
        ),
        ThemeLibraryPreset(
            id: "lib_mood_royal",
            category: "颜色情绪",
            name: "星爵",
            accentColor: "#7e22ce",
            backgroundColor: "#2b1740",
            textColor: "#efdefd",
            secondaryTextColor: "#c9a8e8",
            linkColor: "#cd90ff",
            borderColor: "#4e2f6a"
        ),
        ThemeLibraryPreset(
            id: "lib_mood_firewatch",
            category: "颜色情绪",
            name: "营火",
            accentColor: "#2f7d7c",
            backgroundColor: "#24363a",
            textColor: "#d9eceb",
            secondaryTextColor: "#9abbb9",
            linkColor: "#73d1ce",
            borderColor: "#3d575b"
        ),
        ThemeLibraryPreset(
            id: "lib_mood_sunset",
            category: "颜色情绪",
            name: "晚霞",
            accentColor: "#f97316",
            backgroundColor: "#2a1c1a",
            textColor: "#f7e2d7",
            secondaryTextColor: "#c7a595",
            linkColor: "#ff9a6b",
            borderColor: "#4a302a"
        ),
        ThemeLibraryPreset(
            id: "lib_mood_fog",
            category: "颜色情绪",
            name: "薄暮",
            accentColor: "#737373",
            backgroundColor: "#1f232b",
            textColor: "#e5e7eb",
            secondaryTextColor: "#a4acb8",
            linkColor: "#9fb2d9",
            borderColor: "#3a4250"
        ),
        ThemeLibraryPreset(
            id: "lib_fruit_orange",
            category: "果味满满",
            name: "赤橘",
            accentColor: "#ff4312",
            backgroundColor: "#2a1814",
            textColor: "#fae5df",
            secondaryTextColor: "#cfa49a",
            linkColor: "#ff7a59",
            borderColor: "#503029"
        ),
        ThemeLibraryPreset(
            id: "lib_fruit_dragon",
            category: "果味满满",
            name: "霓果",
            accentColor: "#f472b6",
            backgroundColor: "#271827",
            textColor: "#f8e1f1",
            secondaryTextColor: "#cd9fc2",
            linkColor: "#ff8ad1",
            borderColor: "#4a3150"
        ),
        ThemeLibraryPreset(
            id: "lib_fruit_lemon",
            category: "果味满满",
            name: "晨柠",
            accentColor: "#fde047",
            backgroundColor: "#232114",
            textColor: "#f7f1cf",
            secondaryTextColor: "#c9bd8b",
            linkColor: "#ffe96e",
            borderColor: "#4a4427"
        ),
        ThemeLibraryPreset(
            id: "lib_fruit_lime",
            category: "果味满满",
            name: "青柚",
            accentColor: "#84cc16",
            backgroundColor: "#1b2414",
            textColor: "#e7f3d7",
            secondaryTextColor: "#adc596",
            linkColor: "#b5ea5e",
            borderColor: "#364b29"
        ),
        ThemeLibraryPreset(
            id: "lib_fruit_blueberry",
            category: "果味满满",
            name: "蓝露",
            accentColor: "#2563eb",
            backgroundColor: "#151c2b",
            textColor: "#dce7fb",
            secondaryTextColor: "#9baecc",
            linkColor: "#79a8ff",
            borderColor: "#2f3f62"
        ),
        ThemeLibraryPreset(
            id: "lib_fruit_strawberry",
            category: "果味满满",
            name: "莓红",
            accentColor: "#dc2626",
            backgroundColor: "#2b1515",
            textColor: "#f9dfdf",
            secondaryTextColor: "#cda0a0",
            linkColor: "#ff8080",
            borderColor: "#532b2b"
        ),
        ThemeLibraryPreset(
            id: "lib_misc_noiry",
            category: "其他",
            name: "夜行者",
            accentColor: "#9333ea",
            backgroundColor: "#191026",
            textColor: "#ede3ff",
            secondaryTextColor: "#b4a2db",
            linkColor: "#ca98ff",
            borderColor: "#382d57"
        ),
        ThemeLibraryPreset(
            id: "lib_misc_matrix",
            category: "其他",
            name: "代码雨",
            accentColor: "#22c55e",
            backgroundColor: "#060b06",
            textColor: "#b5f7ba",
            secondaryTextColor: "#6fc37a",
            linkColor: "#4cff75",
            borderColor: "#204227"
        ),
        ThemeLibraryPreset(
            id: "lib_misc_playdate",
            category: "其他",
            name: "游乐场",
            accentColor: "#facc15",
            backgroundColor: "#1c1c16",
            textColor: "#f4ebbe",
            secondaryTextColor: "#c0b987",
            linkColor: "#ffe57f",
            borderColor: "#464235"
        ),
        ThemeLibraryPreset(
            id: "lib_misc_pitch_black",
            category: "其他",
            name: "深井",
            accentColor: "#000000",
            backgroundColor: "#000000",
            textColor: "#e5e5e5",
            secondaryTextColor: "#8a8a8a",
            linkColor: "#5ea2ff",
            borderColor: "#1f1f1f"
        )
    ]
}

// MARK: - Color 十六进制扩展

extension Color {
    /// 从十六进制字符串初始化 Color（支持 "#RRGGBB" 格式）
    init?(hex: String) {
        var hexStr = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        // 支持 3 位简写 (#RGB → #RRGGBB)
        if hexStr.count == 3 {
            hexStr = hexStr.map { "\($0)\($0)" }.joined()
        }
        guard hexStr.count == 6 else { return nil }

        var int: UInt64 = 0
        guard Scanner(string: hexStr).scanHexInt64(&int) else { return nil }

        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8)  & 0xFF) / 255.0
        let b = Double(int         & 0xFF) / 255.0

        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }

    /// 将 Color 转换为十六进制字符串（"#RRGGBB"）
    func toHexString() -> String? {
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        let red = Int(r * 255.0)
        let green = Int(g * 255.0)
        let blue = Int(b * 255.0)
        return String(format: "#%02x%02x%02x", red, green, blue)
    }
}
