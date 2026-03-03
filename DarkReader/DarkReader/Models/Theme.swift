//
//  Theme.swift
//  DarkReader
//
//  暗色主题模型，包含 4 个内置主题和自定义主题支持
//  Color(hex:) 扩展允许在 SwiftUI 中直接使用十六进制颜色字符串
//

import Foundation
import SwiftUI

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
    // 是否为内置主题（内置主题不可删除/修改）
    let isBuiltin: Bool
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

    var localizedDisplayName: String {
        guard isBuiltin else { return name }

        switch id {
        case "theme_001":
            return NSLocalizedString("theme.theme_001.name", comment: "")
        case "theme_002":
            return NSLocalizedString("theme.theme_002.name", comment: "")
        case "theme_003":
            return NSLocalizedString("theme.theme_003.name", comment: "")
        case "theme_004":
            return NSLocalizedString("theme.theme_004.name", comment: "")
        default:
            return name
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case backgroundColor
        case textColor
        case secondaryTextColor
        case linkColor
        case borderColor
        case isBuiltin
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
        isBuiltin: Bool,
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
        self.isBuiltin = isBuiltin
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
        self.isBuiltin = try container.decode(Bool.self, forKey: .isBuiltin)
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
        try container.encode(isBuiltin, forKey: .isBuiltin)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
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

// MARK: - 内置主题定义

extension DarkTheme {
    // 4 个内置主题，覆盖主流使用场景
    static let builtins: [DarkTheme] = [
        DarkTheme(
            id: "theme_001",
            name: "纯黑 OLED",
            backgroundColor: "#000000",
            textColor: "#ffffff",
            secondaryTextColor: "#aaaaaa",
            linkColor: "#4ea1f3",
            borderColor: "#333333",
            isBuiltin: true,
            createdAt: Date(timeIntervalSince1970: 0),  // 固定时间确保顺序稳定
            updatedAt: Date(timeIntervalSince1970: 0)
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
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1)
        ),
        DarkTheme(
            id: "theme_003",
            name: "护眼绿",
            backgroundColor: "#1a1f1a",
            textColor: "#c8d8c8",
            secondaryTextColor: "#7a9a7a",
            linkColor: "#5db8a0",
            borderColor: "#2a402a",
            isBuiltin: true,
            createdAt: Date(timeIntervalSince1970: 2),
            updatedAt: Date(timeIntervalSince1970: 2)
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
            createdAt: Date(timeIntervalSince1970: 3),
            updatedAt: Date(timeIntervalSince1970: 3)
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
        guard let components = UIColor(self).cgColor.components,
              components.count >= 3 else { return nil }
        let r = Int(components[0] * 255.0)
        let g = Int(components[1] * 255.0)
        let b = Int(components[2] * 255.0)
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}
