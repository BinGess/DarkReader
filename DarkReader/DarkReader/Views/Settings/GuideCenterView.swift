//
//  GuideCenterView.swift
//  DarkReader
//
//  指南中心：统一承载功能引导和常见问题
//

import SwiftUI

struct GuideCenterView: View {
    @Binding var hasCompletedOnboarding: Bool
    @AppStorage("onboardingStartFromStepOne") private var onboardingStartFromStepOne = false
    @Environment(\.dismiss) private var dismiss

    private let faqs: [FAQItem] = [
        FAQItem(
            icon: "puzzlepiece.extension.fill",
            color: SustainabilityPalette.cta,
            question: "faq.q.extensionNoEffect",
            answer: "faq.a.extensionNoEffect"
        ),
        FAQItem(
            icon: "exclamationmark.triangle.fill",
            color: SustainabilityPalette.warm,
            question: "faq.q.layoutBroken",
            answer: "faq.a.layoutBroken"
        ),
        FAQItem(
            icon: "photo.fill",
            color: SustainabilityPalette.info,
            question: "faq.q.imagesTooDark",
            answer: "faq.a.imagesTooDark"
        ),
        FAQItem(
            icon: "paintbrush.fill",
            color: SustainabilityPalette.success,
            question: "faq.q.siteTheme",
            answer: "faq.a.siteTheme"
        ),
        FAQItem(
            icon: "icloud.fill",
            color: SustainabilityPalette.primary,
            question: "faq.q.icloudPrivacy",
            answer: "faq.a.icloudPrivacy"
        ),
        FAQItem(
            icon: "trash.fill",
            color: SustainabilityPalette.neutral,
            question: "faq.q.clearData",
            answer: "faq.a.clearData"
        )
    ]

    var body: some View {
        NavigationView {
            ZStack {
                SustainabilityBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        guideCard
                        faqCard
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
                .font(SustainabilityTypography.body)
            }
            .navigationTitle("指南")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .sustainabilityChrome()
    }

    private var guideCard: some View {
        SustainabilityCard {
            VStack(alignment: .leading, spacing: 14) {
                SustainabilitySectionTitle("功能指南", subtitle: "参考竞品流程，直接按步骤操作")

                Button {
                    onboardingStartFromStepOne = true
                    hasCompletedOnboarding = false
                } label: {
                    guideRow(
                        icon: "puzzlepiece.extension.fill",
                        color: SustainabilityPalette.primary,
                        title: "如何启用扩展",
                        detail: "点击后直接进入引导第 1 步。"
                    )
                }
                .buttonStyle(.plain)

                Divider()
                    .overlay(Color.primary.opacity(0.09))
                    .padding(.leading, 52)

                NavigationLink {
                    SiteSettingsGuideView()
                } label: {
                    guideRow(
                        icon: "globe.badge.chevron.backward",
                        color: SustainabilityPalette.cta,
                        title: "更改网站配置",
                        detail: "在 Safari 中按步骤修改当前网站设置。"
                    )
                }
                .buttonStyle(.plain)

                Divider()
                    .overlay(Color.primary.opacity(0.09))
                    .padding(.leading, 52)

                NavigationLink {
                    DimImagesGuideView()
                } label: {
                    guideRow(
                        icon: "photo.fill",
                        color: SustainabilityPalette.warm,
                        title: "在网页上优化图片",
                        detail: "按步骤开启图片优化，降低刺眼感。"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var faqCard: some View {
        SustainabilityCard {
            VStack(alignment: .leading, spacing: 12) {
                SustainabilitySectionTitle("帮助与常见问题", subtitle: "点击问题查看详细说明和排查建议")

                ForEach(Array(faqs.enumerated()), id: \.element.id) { index, faq in
                    NavigationLink {
                        FAQDetailView(item: faq)
                    } label: {
                        faqRow(item: faq)
                    }
                    .buttonStyle(.plain)

                    if index < faqs.count - 1 {
                        Divider()
                            .overlay(Color.primary.opacity(0.09))
                            .padding(.leading, 52)
                    }
                }
            }
        }
    }

    private func faqRow(item: FAQItem) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(item.color.opacity(0.2))
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: item.icon)
                        .foregroundColor(item.color)
                        .font(SustainabilityTypography.subBodyStrong)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(item.question))
                    .font(SustainabilityTypography.bodyStrong)
                    .foregroundColor(.primary)
                Text("查看详细说明")
                    .font(SustainabilityTypography.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(SustainabilityTypography.captionStrong)
                .foregroundColor(.secondary)
        }
        .sustainabilityInteractiveRow()
    }

    private func guideRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.2))
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(SustainabilityTypography.subBodyStrong)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title))
                    .foregroundColor(.primary)
                    .font(SustainabilityTypography.bodyStrong)
                Text(LocalizedStringKey(detail))
                    .font(SustainabilityTypography.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(SustainabilityTypography.captionStrong)
                .foregroundColor(.secondary)
        }
        .sustainabilityInteractiveRow()
    }
}

struct SiteSettingsGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GuideScaffold {
            GuideHeroCard(
                icon: "globe.badge.chevron.backward",
                color: SustainabilityPalette.cta,
                title: "更改网站配置",
                description: "按这个流程操作后，当前网站可以独立设置启用状态、主题和主题颜色。",
                tags: ["约 30 秒", "设置自动保存"]
            )

            GuideBlockCard(title: "操作步骤", subtitle: "在 Safari 中完成") {
                GuideStepRow(index: 1, title: "打开你要配置的网站", detail: "例如 news、论坛、文档站等。")
                GuideStepRow(index: 2, title: "点击地址栏扩展按钮", detail: "在浏览器工具栏找到扩展入口。")
                GuideStepRow(index: 3, title: "选择 DarkReader", detail: "进入当前网站配置面板。")
                GuideStepRow(index: 4, title: "修改站点策略并保存", detail: "支持单站点启用、主题和主题颜色。")
            }

            GuideBlockCard(title: "可单独配置", subtitle: "这些会覆盖全局设置") {
                GuideCapabilityRow(
                    icon: "power",
                    color: SustainabilityPalette.cta,
                    title: "是否启用",
                    detail: "自动 / 开启 / 关闭"
                )
                GuideCapabilityRow(
                    icon: "paintbrush.fill",
                    color: SustainabilityPalette.success,
                    title: "主题",
                    detail: "每个网站可单独指定主题"
                )
                GuideCapabilityRow(
                    icon: "slider.horizontal.3",
                    color: SustainabilityPalette.warm,
                    title: "主题颜色",
                    detail: "可启用网站独立配色"
                )
            }

            GuideBlockCard(title: "界面参考", subtitle: "点击扩展后的菜单布局") {
                GuideMockCard {
                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.gray.opacity(0.25))
                                .frame(width: 28, height: 28)
                                .overlay(Image(systemName: "chevron.left").font(SustainabilityTypography.caption))

                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.95))
                                .frame(height: 28)
                                .overlay(Text("apple.com").font(SustainabilityTypography.caption).foregroundColor(.secondary))

                            Circle()
                                .fill(SustainabilityPalette.cta.opacity(0.2))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(SustainabilityPalette.cta, lineWidth: 2)
                                )
                                .overlay(Image(systemName: "puzzlepiece.extension.fill").font(SustainabilityTypography.caption).foregroundColor(SustainabilityPalette.cta))
                        }

                        VStack(spacing: 8) {
                            guideMockSettingRow(icon: "power", text: "站点启用", value: "自动")
                            guideMockSettingRow(icon: "paintbrush", text: "站点主题", value: "深灰")
                            guideMockSettingRow(icon: "circle.lefthalf.filled", text: "图片优化", value: "开启")
                        }
                    }
                }
            }

            GuideTipCard(
                icon: "checkmark.seal.fill",
                color: SustainabilityPalette.success,
                text: "设置会自动保存。下次访问该网站时，站点规则会优先生效。"
            )
        }
        .navigationTitle("更改网站配置")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            GuideBottomActionBar(
                secondaryTitle: "返回指南",
                primaryTitle: "我去设置",
                secondaryAction: { dismiss() },
                primaryAction: { dismiss() }
            )
        }
        .sustainabilityChrome()
    }

    private func guideMockSettingRow(icon: String, text: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(SustainabilityPalette.cta)
                .frame(width: 18)
            Text(LocalizedStringKey(text))
                .font(SustainabilityTypography.caption)
                .foregroundColor(.primary)
            Spacer()
            Text(LocalizedStringKey(value))
                .font(SustainabilityTypography.captionStrong)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct DimImagesGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GuideScaffold {
            GuideHeroCard(
                icon: "photo.fill",
                color: SustainabilityPalette.warm,
                title: "在网页上优化图片",
                description: "通过图片优化策略降低刺眼感，同时保留主要内容可读性。",
                tags: ["约 20 秒", "支持实时生效"]
            )

            GuideBlockCard(title: "操作步骤", subtitle: "在应用内完成") {
                GuideStepRow(index: 1, title: "打开控制台", detail: "进入首页的设置面板。")
                GuideStepRow(index: 2, title: "进入高级策略", detail: "找到渲染策略相关开关。")
                GuideStepRow(index: 3, title: "开启图片优化", detail: "打开“降低网页图片亮度”。")
                GuideStepRow(index: 4, title: "按需调节主题", detail: "搭配主题亮度和对比度微调。")
            }

            GuideBlockCard(title: "推荐效果", subtitle: "夜间浏览更舒适") {
                GuideCapabilityRow(
                    icon: "moon.stars.fill",
                    color: SustainabilityPalette.info,
                    title: "减少强光刺激",
                    detail: "大面积亮图不再刺眼"
                )
                GuideCapabilityRow(
                    icon: "photo.on.rectangle.angled",
                    color: SustainabilityPalette.cta,
                    title: "保留图片细节",
                    detail: "不会简单粗暴全黑覆盖"
                )
                GuideCapabilityRow(
                    icon: "safari.fill",
                    color: SustainabilityPalette.success,
                    title: "仅影响网页图片",
                    detail: "不影响系统相册和其他 App"
                )
            }

            GuideBlockCard(title: "界面参考", subtitle: "高级策略中的图片优化区域") {
                GuideMockCard {
                    VStack(spacing: 10) {
                        HStack {
                            Text("降低网页图片亮度")
                                .font(SustainabilityTypography.subBodyStrong)
                            Spacer()
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(SustainabilityPalette.success.opacity(0.25))
                                .frame(width: 50, height: 28)
                                .overlay(
                                    Circle()
                                        .fill(SustainabilityPalette.success)
                                        .frame(width: 22, height: 22)
                                        .offset(x: 10)
                                )
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("图片亮度")
                                .font(SustainabilityTypography.caption)
                                .foregroundColor(.secondary)

                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 8)
                                Capsule()
                                    .fill(SustainabilityPalette.warm)
                                    .frame(width: 140, height: 8)
                                Circle()
                                    .fill(SustainabilityPalette.warm)
                                    .frame(width: 18, height: 18)
                                    .offset(x: 130)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.86))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            GuideTipCard(
                icon: "lightbulb.max.fill",
                color: SustainabilityPalette.warm,
                text: "如果你觉得图片仍偏亮，可以在主题编辑器里同步下调链接色和辅助文本亮度。"
            )
        }
        .navigationTitle("在网页上优化图片")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            GuideBottomActionBar(
                secondaryTitle: "返回指南",
                primaryTitle: "去高级策略",
                secondaryAction: { dismiss() },
                primaryAction: { dismiss() }
            )
        }
        .sustainabilityChrome()
    }
}

struct FAQDetailView: View {
    let item: FAQItem

    private var solutionLines: [String] {
        NSLocalizedString(item.answer, comment: "")
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        GuideScaffold {
            GuideHeroCard(
                icon: item.icon,
                color: item.color,
                title: "常见问题",
                description: item.question,
                tags: ["问题排查", "可立即尝试"]
            )

            GuideBlockCard(title: "解决建议", subtitle: "按顺序尝试以下操作") {
                ForEach(Array(solutionLines.enumerated()), id: \.offset) { index, line in
                    GuideAnswerRow(index: index + 1, text: line)
                }
            }

            GuideTipCard(
                icon: "bubble.left.and.bubble.right.fill",
                color: item.color,
                text: "如果仍未解决，请到「设置 > 报告问题」提交网页域名和现象描述，便于快速定位。"
            )
        }
        .navigationTitle("常见问题")
        .navigationBarTitleDisplayMode(.inline)
        .sustainabilityChrome()
    }
}

private struct GuideScaffold<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            SustainabilityBackground()

            ScrollView {
                VStack(spacing: 16) {
                    content()
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
            .font(SustainabilityTypography.body)
        }
    }
}

private struct GuideHeroCard: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    let tags: [String]

    var body: some View {
        SustainabilityCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 13) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(color.opacity(0.2))
                        .frame(width: 46, height: 46)
                        .overlay(
                            Image(systemName: icon)
                                .font(SustainabilityTypography.title)
                                .foregroundColor(color)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey(title))
                            .font(SustainabilityTypography.title)
                        Text(LocalizedStringKey(description))
                            .font(SustainabilityTypography.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        Text(LocalizedStringKey(tag))
                            .font(SustainabilityTypography.captionStrong)
                            .foregroundColor(color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(color.opacity(0.14))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
}

private struct GuideBlockCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        SustainabilityCard {
            VStack(alignment: .leading, spacing: 12) {
                SustainabilitySectionTitle(title, subtitle: subtitle)
                content()
            }
        }
    }
}

private struct GuideStepRow: View {
    let index: Int
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(SustainabilityTypography.subBodyStrong)
                .foregroundColor(SustainabilityPalette.cta)
                .frame(width: 30, height: 30)
                .overlay(
                    Circle()
                        .stroke(SustainabilityPalette.cta, lineWidth: 2)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title))
                    .font(SustainabilityTypography.subBodyStrong)
                    .foregroundColor(.primary)
                Text(LocalizedStringKey(detail))
                    .font(SustainabilityTypography.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 3)
    }
}

private struct GuideCapabilityRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(color.opacity(0.2))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: icon)
                        .font(SustainabilityTypography.subBodyStrong)
                        .foregroundColor(color)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title))
                    .font(SustainabilityTypography.subBodyStrong)
                Text(LocalizedStringKey(detail))
                    .font(SustainabilityTypography.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

private struct GuideAnswerRow: View {
    let index: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(SustainabilityTypography.captionStrong)
                .foregroundColor(SustainabilityPalette.cta)
                .frame(width: 24, height: 24)
                .background(SustainabilityPalette.cta.opacity(0.14))
                .clipShape(Circle())

            Text(LocalizedStringKey(text))
                .font(SustainabilityTypography.body)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 3)
    }
}

private struct GuideTipCard: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        SustainabilityCard {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(SustainabilityTypography.subBodyStrong)
                Text(LocalizedStringKey(text))
                    .font(SustainabilityTypography.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct GuideBottomActionBar: View {
    @Environment(\.colorScheme) private var colorScheme
    let secondaryTitle: String
    let primaryTitle: String
    let secondaryAction: () -> Void
    let primaryAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(LocalizedStringKey(secondaryTitle), action: secondaryAction)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 46)
                .buttonStyle(.bordered)

            Button(LocalizedStringKey(primaryTitle), action: primaryAction)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 46)
                .buttonStyle(.borderedProminent)
                .tint(SustainabilityPalette.primary)
        }
        .padding(14)
        .background(
            Color(.systemBackground).opacity(colorScheme == .dark ? 0.9 : 0.96),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.14),
            radius: 20,
            x: 0,
            y: 10
        )
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }
}

private struct GuideMockCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(12)
            .background(Color.white.opacity(0.84))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.55), lineWidth: 1)
            )
    }
}

struct FAQItem: Identifiable {
    var id: String { question }
    let icon: String
    let color: Color
    let question: String
    let answer: String
}
