//
//  ContentView.swift
//  DarkReader
//
//  主界面：单页首页，主题/设置通过弹层打开
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @EnvironmentObject var appNavigation: AppNavigationState
    @State private var activeSheet: ActiveSheet?

    private enum ActiveSheet: String, Identifiable {
        case themes
        case settings

        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            SustainabilityBackground()

            DashboardView(
                onOpenThemes: { activeSheet = .themes },
                onOpenSettings: { activeSheet = .settings }
            )
            .font(SustainabilityTypography.body)
            .background(Color.clear)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(SustainabilityPalette.cta)
        .sustainabilityChrome()
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .themes:
                ThemeManagerView()
            case .settings:
                SettingsView()
            }
        }
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
            activeSheet = .themes
        case 2:
            activeSheet = .settings
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
