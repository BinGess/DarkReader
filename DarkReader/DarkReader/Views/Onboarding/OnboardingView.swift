//
//  OnboardingView.swift
//  DarkReader
//
//  Payment Gateway 风格引导流程：6步启用 Safari 扩展
//

import SwiftUI
import Combine
import SafariServices

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @EnvironmentObject var dataManager: SharedDataManager
    @AppStorage("onboardingStartFromStepOne") private var onboardingStartFromStepOne = false

    @State private var currentStep = 0
    @State private var extensionEnabled = false

    private let extensionCheckTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            SustainabilityBackground()

            if currentStep == 0 {
                welcomePage
            } else if currentStep <= 6 {
                guidePage
            } else {
                completionPage
            }
        }
        .onReceive(extensionCheckTimer) { _ in
            if currentStep >= 1 && currentStep <= 6 {
                checkExtensionState()
            }
        }
        .onAppear {
            if onboardingStartFromStepOne {
                currentStep = 1
                onboardingStartFromStepOne = false
            }
        }
        .animation(.easeInOut(duration: 0.24), value: currentStep)
    }

    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(SustainabilityPalette.primary.opacity(0.2))
                    .frame(width: 120, height: 120)
                Image("Logo")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 78, height: 78)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .padding(.bottom, 24)

            Text(NSLocalizedString("brand.appName", comment: ""))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .padding(.bottom, 4)

            Spacer()

            VStack(spacing: 10) {
                featureRow(icon: "checkmark.seal.fill", color: SustainabilityPalette.primary, title: "高可信策略", desc: "像支付网关一样强调稳定与可验证。")
                featureRow(icon: "bolt.fill", color: SustainabilityPalette.warm, title: "极速注入", desc: "页面开始渲染时就完成深色接管，减少闪白。")
                featureRow(icon: "lock.shield.fill", color: SustainabilityPalette.cta, title: "隐私优先", desc: "所有解析在设备本地完成，不上传浏览内容。")
            }
            .padding(.horizontal, 24)

            Spacer()

            Button {
                withAnimation { currentStep = 1 }
            } label: {
                Text("开始引导")
                    .font(SustainabilityTypography.bodyStrong)
                    .frame(maxWidth: .infinity, minHeight: SustainabilityMetrics.touchMinHeight + 4)
                    .background(SustainabilityPalette.primary)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield")
                Text("零数据收集，配置仅保存在本地和 iCloud（可选）")
            }
            .font(SustainabilityTypography.caption)
            .foregroundColor(.secondary)
            .padding(.bottom, 28)
        }
    }

    private var guidePage: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(1...6, id: \.self) { step in
                    Capsule()
                        .fill(step <= currentStep ? SustainabilityPalette.primary : Color.white.opacity(0.35))
                        .frame(height: 6)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Spacer()

            let step = onboardingSteps[currentStep - 1]
            SustainabilityCard {
                VStack(spacing: 16) {
                    Image(systemName: step.imageName)
                        .font(.system(size: 64))
                        .foregroundColor(step.imageColor)
                        .frame(height: 90)

                    Text(String(format: NSLocalizedString("onboarding.stepProgress", comment: ""), currentStep))
                        .font(SustainabilityTypography.captionStrong)
                        .foregroundColor(.secondary)

                    Text(LocalizedStringKey(step.title))
                        .font(SustainabilityTypography.title)
                        .multilineTextAlignment(.center)

                    Text(LocalizedStringKey(step.description))
                        .font(SustainabilityTypography.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            HStack(spacing: 12) {
                if currentStep > 1 {
                    Button("上一步") {
                        withAnimation { currentStep -= 1 }
                    }
                    .buttonStyle(.bordered)
                    .tint(SustainabilityPalette.cta)
                    .frame(minHeight: SustainabilityMetrics.touchMinHeight)
                    .frame(maxWidth: .infinity)
                }

                Button(currentStep < 6 ? "下一步" : "我已开启扩展") {
                    if currentStep < 6 {
                        withAnimation { currentStep += 1 }
                    } else {
                        checkExtensionState()
                        if extensionEnabled {
                            withAnimation { currentStep = 7 }
                        } else {
                            openSafariExtensionSettings()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(SustainabilityPalette.primary)
                .frame(minHeight: SustainabilityMetrics.touchMinHeight)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
    }

    private var completionPage: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 96))
                .foregroundColor(SustainabilityPalette.primary)
                .padding(.bottom, 20)

            Text("扩展启用成功")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .padding(.bottom, 8)

            Text("已完成配置，深色模式默认跟随系统。现在可以在 Safari 中体验统一的可读性优化。")
                .font(SustainabilityTypography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button {
#if os(iOS)
                    if let url = URL(string: "https://www.apple.com") {
                        UIApplication.shared.open(url)
                    }
#endif
                } label: {
                    Label("立即打开 Safari 体验", systemImage: "safari.fill")
                        .frame(maxWidth: .infinity, minHeight: SustainabilityMetrics.touchMinHeight + 4)
                        .background(SustainabilityPalette.primary)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button {
                    hasCompletedOnboarding = true
                } label: {
                    Text("进入应用")
                        .frame(maxWidth: .infinity, minHeight: SustainabilityMetrics.touchMinHeight + 4)
                        .background(Color.white.opacity(0.7))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    private var onboardingSteps: [OnboardingStep] {[
        OnboardingStep(
            imageName: "safari.fill",
            imageColor: SustainabilityPalette.cta,
            title: "打开 Safari 浏览器",
            description: "在 iPhone 或 iPad 上打开 Safari，并访问任意网页。"
        ),
        OnboardingStep(
            imageName: "textformat",
            imageColor: SustainabilityPalette.warm,
            title: "点击地址栏 AA 按钮",
            description: "点击地址栏左侧 AA 图标，或进入分享/更多菜单。"
        ),
        OnboardingStep(
            imageName: "puzzlepiece.extension.fill",
            imageColor: SustainabilityPalette.primary,
            title: "选择管理扩展",
            description: "在菜单中找到\"管理扩展\"，进入扩展开关页。"
        ),
        OnboardingStep(
            imageName: "shield.lefthalf.filled",
            imageColor: SustainabilityPalette.primary,
            title: "开启 DarkReader 扩展",
            description: "找到 DarkReader 并打开开关，允许扩展在网站上运行。"
        ),
        OnboardingStep(
            imageName: "checkmark.shield.fill",
            imageColor: SustainabilityPalette.success,
            title: "选择始终允许",
            description: "在权限提示中选择\"始终允许\"，保障所有站点可以应用策略。"
        ),
        OnboardingStep(
            imageName: "hand.thumbsup.fill",
            imageColor: SustainabilityPalette.cta,
            title: "确认扩展已生效",
            description: "返回网页后，看到扩展图标即表示 DarkReader 已成功启用。"
        )
    ]}

    private func featureRow(icon: String, color: Color, title: String, desc: String) -> some View {
        SustainabilityCard {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(SustainabilityTypography.title)
                    .foregroundColor(color)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(title))
                        .font(SustainabilityTypography.subBodyStrong)
                    Text(LocalizedStringKey(desc))
                        .font(SustainabilityTypography.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
    }

    private func checkExtensionState() {
#if os(iOS)
        extensionEnabled = true
        if extensionEnabled && currentStep >= 4 {
            withAnimation { currentStep = 7 }
        }
#else
        SFSafariExtensionManager.getStateOfSafariExtension(
            withIdentifier: "com.timmy.darkreader.extension"
        ) { state, _ in
            DispatchQueue.main.async {
                extensionEnabled = state?.isEnabled ?? false
                if extensionEnabled && currentStep >= 4 {
                    withAnimation { currentStep = 7 }
                }
            }
        }
#endif
    }

    private func openSafariExtensionSettings() {
#if os(iOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
#else
        SFSafariApplication.showPreferencesForExtension(
            withIdentifier: "com.timmy.darkreader.extension"
        ) { _ in }
#endif
    }
}

struct OnboardingStep {
    let imageName: String
    let imageColor: Color
    let title: String
    let description: String
}
