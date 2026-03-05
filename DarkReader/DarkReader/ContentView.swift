//
//  ContentView.swift
//  DarkReader
//
//  主界面：单页首页，主题/设置通过导航跳转
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @EnvironmentObject var appNavigation: AppNavigationState
    @State private var showThemesPage = false
    @State private var showSettingsPage = false

    var body: some View {
        ZStack {
            SustainabilityBackground()

            DashboardView(
                showThemesPage: $showThemesPage,
                showSettingsPage: $showSettingsPage
            )
            .sustainabilityReadableContent()
            .background(Color.clear)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(SustainabilityPalette.cta)
        .sustainabilityChrome()
        .onAppear {
            handleRoute(appNavigation.selectedTab)
        }
        .onChange(of: appNavigation.selectedTab) { target in
            handleRoute(target)
        }
    }

    private func handleRoute(_ target: Int) {
        switch target {
        case 1:
            showThemesPage = true
        case 2:
            showSettingsPage = true
        default:
            return
        }
        DispatchQueue.main.async {
            appNavigation.selectedTab = 0
        }
    }
}

#Preview {
    let manager = SharedDataManager.shared
    ContentView()
        .environmentObject(manager)
        .environmentObject(EyeCareNotificationManager(dataManager: manager))
        .environmentObject(AppNavigationState())
}
