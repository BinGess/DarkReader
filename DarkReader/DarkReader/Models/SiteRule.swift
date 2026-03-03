//
//  SiteRule.swift
//  DarkReader
//
//  单个站点的个性化配置，允许用户针对特定域名覆盖全局设置
//  存储在 SiteRules 字典中，Key 为主域名（不含子域名前缀）
//

import Foundation

// 站点规则模型
struct SiteRule: Codable, Equatable {
    // 该域名的模式覆写（nil 表示跟随全局设置）
    var mode: SiteMode?
    // 该域名使用的主题 ID（nil 或空字符串表示跟随全局主题）
    var themeId: String?
    // 规则最近更新时间，用于多端冲突合并（保留最新修改）
    var updatedAt: Date

    // 判断是否有任何自定义设置（用于 UI 展示"已自定义"角标）
    var hasCustomSettings: Bool {
        mode != nil || (themeId != nil && themeId?.isEmpty == false)
    }

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

// 站点级别的模式选项（比全局多一个 "跟随默认"）
enum SiteMode: String, Codable, CaseIterable, Identifiable {
    case follow = "follow"  // 跟随全局设置
    case on     = "on"      // 强制开启深色模式
    case off    = "off"     // 强制关闭深色模式

    var id: String { rawValue }

    var displayNameKey: String {
        switch self {
        case .follow: return "sitemode.option.follow"
        case .on:     return "sitemode.option.on"
        case .off:    return "sitemode.option.off"
        }
    }

    var displayName: String {
        NSLocalizedString(displayNameKey, comment: "")
    }

    var systemImageName: String {
        switch self {
        case .follow: return "arrow.up.arrow.down.circle"
        case .on:     return "moon.fill"
        case .off:    return "sun.max.fill"
        }
    }
}

// SiteRules 类型别名：键为主域名，值为该域名的规则配置
// 例：["github.com": SiteRule(mode: .on, themeId: "theme_002")]
typealias SiteRules = [String: SiteRule]

// MARK: - 域名工具函数

extension String {
    /// 从完整 hostname 中提取主域名（去掉子域名前缀）
    /// 例：mail.google.com → google.com
    ///     www.baidu.com  → baidu.com
    ///     github.com     → github.com
    var mainDomain: String {
        let parts = self.split(separator: ".").map(String.init)
        guard parts.count > 2 else { return self }
        // 保留最后两段（domain.tld）
        return parts.suffix(2).joined(separator: ".")
    }
}
