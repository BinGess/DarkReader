//
//  PrivacyView.swift
//  DarkReader
//
//  隐私声明页面
//

import SwiftUI

struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                SustainabilityBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        privacySection(
                            icon: "lock.shield.fill",
                            color: SustainabilityPalette.success,
                            title: "零数据收集",
                            content: "DarkReader 不收集、不上传任何用户数据。所有网页解析、颜色计算均在您的设备本地完成，不会发送到任何服务器。"
                        )

                        privacySection(
                            icon: "iphone.and.arrow.forward",
                            color: SustainabilityPalette.cta,
                            title: "iCloud 同步",
                            content: "如果您开启了 iCloud 同步，您的自定义主题和站点规则会通过 Apple 的 iCloud 服务同步到同一 Apple ID 下的其他设备。这些数据由 Apple 加密传输和存储，我们无法访问。"
                        )

                        privacySection(
                            icon: "safari.fill",
                            color: SustainabilityPalette.warm,
                            title: "网页访问权限",
                            content: "Safari 扩展需要「访问所有网站」权限，以便在您浏览时注入深色样式。扩展仅读取网页的 CSS 样式信息用于计算颜色，不读取任何网页文本内容，不记录您的浏览历史。"
                        )

                        privacySection(
                            icon: "internaldrive.fill",
                            color: SustainabilityPalette.primary,
                            title: "本地存储",
                            content: "您的偏好设置（主题配置、站点规则、全局开关状态）存储在设备本地的 App Groups 共享容器中。您可以随时在设置页面清除所有数据。"
                        )

                        privacySection(
                            icon: "person.slash.fill",
                            color: SustainabilityPalette.danger,
                            title: "无需账户",
                            content: "使用 DarkReader 完全不需要注册账户或提供任何个人信息。"
                        )
                    }
                    .padding(16)
                }
                .font(SustainabilityTypography.body)
            }
            .navigationTitle("隐私政策")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .sustainabilityChrome()
    }

    private func privacySection(icon: String, color: Color, title: String, content: String) -> some View {
        SustainabilityCard {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(SustainabilityTypography.subBodyStrong)
                    .foregroundColor(color)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 6) {
                    Text(LocalizedStringKey(title))
                        .font(SustainabilityTypography.bodyStrong)
                    Text(LocalizedStringKey(content))
                        .font(SustainabilityTypography.body)
                        .foregroundColor(.secondary)
                        .lineSpacing(3)
                }
            }
        }
    }
}

// MARK: - 帮助与常见问题

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    private let faqs: [(String, String)] = [
        (
            "faq.q.extensionNoEffect",
            "faq.a.extensionNoEffect"
        ),
        (
            "faq.q.layoutBroken",
            "faq.a.layoutBroken"
        ),
        (
            "faq.q.imagesTooDark",
            "faq.a.imagesTooDark.hostApp"
        ),
        (
            "faq.q.siteTheme",
            "faq.a.siteTheme"
        ),
        (
            "faq.q.icloudPrivacy",
            "faq.a.icloudPrivacy"
        ),
        (
            "faq.q.clearData",
            "faq.a.clearData"
        )
    ]

    var body: some View {
        NavigationView {
            ZStack {
                SustainabilityBackground()
                List {
                    ForEach(faqs, id: \.0) { faq in
                        SustainabilityCard {
                            DisclosureGroup {
                                Text(LocalizedStringKey(faq.1))
                                    .font(SustainabilityTypography.body)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 4)
                            } label: {
                                Text(LocalizedStringKey(faq.0))
                                    .font(SustainabilityTypography.bodyStrong)
                            }
                            .sustainabilityInteractiveRow()
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .applyListBackgroundClear()
            }
            .navigationTitle("帮助中心")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
