//
//  ContentView.swift
//  DarkReader
//
//  主界面：TabView 布局，包含控制台、主题、设置三个标签页
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @EnvironmentObject var appNavigation: AppNavigationState

    var body: some View {
        ZStack {
            SustainabilityBackground()

            TabView(selection: $appNavigation.selectedTab) {
                // 标签1：控制台（全局开关、扩展状态）
                DashboardView()
                    .tabItem {
                        Label("控制台", systemImage: "creditcard.and.123")
                    }
                    .tag(0)

                // 标签2：主题管理
                ThemeManagerView()
                    .tabItem {
                        Label("主题", systemImage: "swatchpalette")
                    }
                    .tag(1)

                // 标签3：设置
                SettingsView()
                    .tabItem {
                        Label("设置", systemImage: "slider.horizontal.3")
                    }
                    .tag(2)
            }
            .font(SustainabilityTypography.body)
            .background(Color.clear)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(SustainabilityPalette.cta)
        .sustainabilityChrome()
    }
}

#Preview {
    let manager = SharedDataManager.shared
    ContentView()
        .environmentObject(manager)
        .environmentObject(EyeCareNotificationManager(dataManager: manager))
        .environmentObject(AppNavigationState())
}
