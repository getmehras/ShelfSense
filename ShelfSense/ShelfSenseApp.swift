import SwiftUI
import SwiftData

@main
struct ShelfSenseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Always start on the Dashboard tab regardless of where the user was last session.
        UserDefaults.standard.set(0, forKey: "selected_tab")

        // Belt-and-suspenders window background — covers the gap between
        // the system launch screen and SwiftUI's first rendered frame.
        UIWindow.appearance().backgroundColor = UIColor(
            red: 27/255, green: 94/255, blue: 32/255, alpha: 1
        )

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = .white

        let activeColor   = UIColor(red: 0/255,   green: 200/255, blue: 83/255,  alpha: 1.0)
        let inactiveColor = UIColor(red: 142/255, green: 142/255, blue: 147/255, alpha: 1.0)

        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = activeColor
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: activeColor]
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = inactiveColor
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: inactiveColor]

        UITabBar.appearance().standardAppearance    = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance  = tabBarAppearance
    }

    var body: some Scene {
        // ModelContainer is created asynchronously in RootView so the main thread
        // is never blocked — the green background and splash render on frame 1.
        WindowGroup {
            RootView()
        }
    }
}
