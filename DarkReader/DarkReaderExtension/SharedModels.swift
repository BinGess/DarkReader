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

struct GlobalConfig: Codable, Equatable {
    var mode: DarkMode
    var defaultThemeId: String
    var dimImages: Bool
    var ignoreNativeDarkMode: Bool
    var performanceMode: Bool
    var extensionEnabled: Bool
    var appLanguage: AppLanguageOption

    init() {
        self.mode = .auto
        self.defaultThemeId = "theme_002"
        self.dimImages = true
        self.ignoreNativeDarkMode = false
        self.performanceMode = false
        self.extensionEnabled = true
        self.appLanguage = .system
    }

    private enum CodingKeys: String, CodingKey {
        case mode
        case defaultThemeId
        case dimImages
        case ignoreNativeDarkMode
        case performanceMode
        case extensionEnabled
        case appLanguage
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

struct DarkTheme: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var backgroundColor: String
    var textColor: String
    var secondaryTextColor: String
    var linkColor: String
    var borderColor: String
    let isBuiltin: Bool
    var createdAt: Date
    var updatedAt: Date

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

extension DarkTheme {
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
            createdAt: Date(timeIntervalSince1970: 0),
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
}

struct SiteRule: Codable, Equatable {
    var mode: SiteMode?
    var themeId: String?
    var updatedAt: Date

    init(mode: SiteMode? = nil, themeId: String? = nil, updatedAt: Date = Date()) {
        self.mode = mode
        self.themeId = themeId
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case mode
        case themeId
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.mode = try container.decodeIfPresent(SiteMode.self, forKey: .mode)
        self.themeId = try container.decodeIfPresent(String.self, forKey: .themeId)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date(timeIntervalSince1970: 0)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(mode, forKey: .mode)
        try container.encodeIfPresent(themeId, forKey: .themeId)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

enum SiteMode: String, Codable {
    case follow
    case on
    case off
}

typealias SiteRules = [String: SiteRule]

extension String {
    var mainDomain: String {
        let parts = self.split(separator: ".").map(String.init)
        guard parts.count > 2 else { return self }
        return parts.suffix(2).joined(separator: ".")
    }
}
