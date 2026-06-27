import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Query private var groceryItems: [GroceryItem]
    @AppStorage("selected_tab") private var selectedTab = 0

    init() {
        let mintUIColor = UIColor(red: 0, green: 200/255, blue: 83/255, alpha: 1)   // #00C853
        let grayUIColor = UIColor(red: 142/255, green: 142/255, blue: 147/255, alpha: 1) // #8E8E93

        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.stackedLayoutAppearance.selected.iconColor = mintUIColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: mintUIColor]
        appearance.stackedLayoutAppearance.normal.iconColor = grayUIColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: grayUIColor]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    private var alertCount: Int {
        groceryItems.filter(\.isPriceAlert).count
    }

    var body: some View {
        if hasCompletedOnboarding {
            mainTabView
        } else {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
    }

    private let mintColor = Color(red: 0, green: 200/255, blue: 83/255)
    private let grayColor = Color(red: 142/255, green: 142/255, blue: 147/255)

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(0)
                .badge(alertCount > 0 ? alertCount : 0)
                .accessibilityLabel("Dashboard tab\(alertCount > 0 ? ", \(alertCount) price alerts" : "")")

            ScanView()
                .tabItem {
                    Label("Scan", systemImage: "camera.viewfinder")
                }
                .tag(1)
                .accessibilityLabel("Scan receipt tab")

            PriceHistoryView()
                .tabItem {
                    Label("Prices", systemImage: "tag.fill")
                }
                .tag(2)
                .accessibilityLabel("Price history tab")

            StoresView()
                .tabItem {
                    Label("Stores", systemImage: "storefront.fill")
                }
                .tag(3)
                .accessibilityLabel("Stores tab")
        }
        .tint(mintColor)
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [Receipt.self, GroceryItem.self, Store.self, PriceEntry.self],
            inMemory: true
        )
}
