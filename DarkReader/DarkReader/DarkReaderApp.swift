//
//  DarkReaderApp.swift
//  DarkReader
//
//  App 入口点
//

import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

final class AppNavigationState: ObservableObject {
    @Published var selectedTab: Int = 0
}

#if canImport(UIKit)
final class BatteryEyeCareManager: ObservableObject {
    private let dataManager: SharedDataManager
    private var restoreMode: DarkMode?
    private var restoreThemeId: String?
    private var isMonitoring = false

    init(dataManager: SharedDataManager) {
        self.dataManager = dataManager
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBatteryEvent),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBatteryEvent),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )
        evaluateBatteryState()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleBatteryEvent() {
        evaluateBatteryState()
    }

    private func evaluateBatteryState() {
        var config = dataManager.globalConfig
        guard config.lowBatteryEyeCareEnabled else {
            if config.lowBatteryModeActive {
                config.lowBatteryModeActive = false
                dataManager.globalConfig = config
                dataManager.saveConfig()
            }
            return
        }

        let batteryLevel = UIDevice.current.batteryLevel
        let batteryState = UIDevice.current.batteryState
        guard batteryLevel >= 0 else { return }

        let threshold = Float(config.lowBatteryThreshold) / 100.0
        let shouldActivate = batteryLevel <= threshold && batteryState != .charging && batteryState != .full
        if shouldActivate {
            activateLowBatteryModeIfNeeded()
            return
        }

        if config.lowBatteryModeActive && (batteryState == .charging || batteryLevel > threshold + 0.03) {
            if config.lowBatteryRestoreOnCharging {
                restorePreviousModeIfPossible()
            } else {
                config.lowBatteryModeActive = false
                dataManager.globalConfig = config
                dataManager.saveConfig()
            }
        }
    }

    private func activateLowBatteryModeIfNeeded() {
        var config = dataManager.globalConfig
        guard !config.lowBatteryModeActive else { return }

        restoreMode = config.mode
        restoreThemeId = config.defaultThemeId
        config.mode = .on
        config.defaultThemeId = "theme_001"
        config.lowBatteryModeActive = true
        dataManager.globalConfig = config
        dataManager.saveConfig()
    }

    private func restorePreviousModeIfPossible() {
        var config = dataManager.globalConfig
        guard config.lowBatteryModeActive else { return }

        if let mode = restoreMode {
            config.mode = mode
        }
        if let themeId = restoreThemeId {
            config.defaultThemeId = themeId
        }
        config.lowBatteryModeActive = false
        dataManager.globalConfig = config
        dataManager.saveConfig()

        restoreMode = nil
        restoreThemeId = nil
    }
}
#endif

@main
struct DarkReaderApp: App {
    // 共享数据管理器（全局单例，注入所有视图）
    @StateObject private var dataManager: SharedDataManager
    @StateObject private var iCloudSync = iCloudSyncManager.shared
    @StateObject private var appNavigation = AppNavigationState()
    @StateObject private var notificationManager: EyeCareNotificationManager
#if canImport(UIKit)
    @StateObject private var batteryManager: BatteryEyeCareManager
#endif
    @State private var showSplash = true

    // 判断是否为首次启动（需要展示 Onboarding）
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init() {
        let manager = SharedDataManager.shared
        _dataManager = StateObject(wrappedValue: manager)
        _notificationManager = StateObject(wrappedValue: EyeCareNotificationManager(dataManager: manager))
#if canImport(UIKit)
        _batteryManager = StateObject(wrappedValue: BatteryEyeCareManager(dataManager: manager))
#endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    LaunchSplashView()
                } else {
                    if hasCompletedOnboarding {
                        ContentView()
                            .environmentObject(dataManager)
                            .environmentObject(notificationManager)
                    } else {
                        OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                            .environmentObject(dataManager)
                            .environmentObject(notificationManager)
                    }
                }
            }
            .environmentObject(appNavigation)
            .environment(\.locale, dataManager.globalConfig.appLanguage.locale)
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .onAppear {
#if canImport(UIKit)
                batteryManager.startMonitoring()
#endif
                notificationManager.start()
                dataManager.refreshSunScheduleIfNeeded()
                guard showSplash else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
                    withAnimation(.easeOut(duration: 0.28)) {
                        showSplash = false
                    }
                }
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == "darkreader" else { return }
        let route = url.host?.lowercased() ?? ""
        switch route {
        case "dashboard":
            appNavigation.selectedTab = 0
        case "themes":
            appNavigation.selectedTab = 1
        case "settings":
            appNavigation.selectedTab = 2
        default:
            appNavigation.selectedTab = 2
        }
    }
}

private struct LaunchSplashView: View {
    @State private var isNight = false
    @State private var starTwinkle = false

    private let dayTop = Color(red: 0.96, green: 0.98, blue: 1.0)
    private let dayBottom = Color(red: 0.88, green: 0.94, blue: 1.0)
    private let nightTop = Color(red: 0.05, green: 0.09, blue: 0.18)
    private let nightBottom = Color(red: 0.09, green: 0.14, blue: 0.30)

    var body: some View {
        ZStack {
            LinearGradient(colors: [dayTop, dayBottom], startPoint: .top, endPoint: .bottom)
                .opacity(isNight ? 0 : 1)
                .ignoresSafeArea()

            LinearGradient(colors: [nightTop, nightBottom], startPoint: .top, endPoint: .bottom)
                .opacity(isNight ? 1 : 0)
                .ignoresSafeArea()

            sunMoonLayer
            starLayer

            VStack(spacing: 14) {
                Image("Logo")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: Color.black.opacity(isNight ? 0.22 : 0.08), radius: 12, x: 0, y: 6)

                Text(LocalizedStringKey("brand.appName"))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(isNight ? .white : .primary)

                Text(LocalizedStringKey("launch.tagline"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor((isNight ? Color.white : Color.primary).opacity(0.86))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .animation(.easeInOut(duration: 1.2), value: isNight)
        .animation(.easeInOut(duration: 1.0), value: starTwinkle)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.15)) {
                isNight = true
            }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true).delay(0.5)) {
                starTwinkle = true
            }
        }
        .transition(.opacity)
    }

    private var sunMoonLayer: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.98, green: 0.80, blue: 0.24))
                .frame(width: 76, height: 76)
                .shadow(color: Color(red: 0.98, green: 0.80, blue: 0.24).opacity(0.35), radius: 20, x: 0, y: 0)
                .opacity(isNight ? 0 : 1)
                .offset(x: isNight ? 140 : -110, y: isNight ? -320 : -230)

            Circle()
                .fill(Color.white.opacity(0.95))
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .fill(nightTop)
                        .frame(width: 32, height: 32)
                        .offset(x: 8, y: -4)
                )
                .opacity(isNight ? 1 : 0)
                .offset(x: isNight ? 118 : 150, y: isNight ? -305 : -255)
        }
    }

    private var starLayer: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(Color.white)
                    .frame(width: index.isMultiple(of: 2) ? 3 : 2, height: index.isMultiple(of: 2) ? 3 : 2)
                    .offset(starOffset(for: index))
            }
        }
        .opacity(isNight ? (starTwinkle ? 1 : 0.65) : 0)
    }

    private func starOffset(for index: Int) -> CGSize {
        let offsets: [CGSize] = [
            CGSize(width: -120, height: -300),
            CGSize(width: -60, height: -340),
            CGSize(width: 18, height: -295),
            CGSize(width: 72, height: -332),
            CGSize(width: 132, height: -286),
            CGSize(width: 160, height: -324)
        ]
        return offsets[index]
    }
}
