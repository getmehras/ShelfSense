import SwiftUI
import SwiftData

@main
struct ShelfSenseApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Receipt.self,
            GroceryItem.self,
            Store.self,
            PriceEntry.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = .white

        // Active tab - mint green
        let activeColor = UIColor(
            red: 0/255,
            green: 200/255,
            blue: 83/255,
            alpha: 1.0)

        // Inactive tab - gray
        let inactiveColor = UIColor(
            red: 142/255,
            green: 142/255,
            blue: 147/255,
            alpha: 1.0)

        tabBarAppearance.stackedLayoutAppearance
            .selected.iconColor = activeColor
        tabBarAppearance.stackedLayoutAppearance
            .selected.titleTextAttributes = [
            .foregroundColor: activeColor]

        tabBarAppearance.stackedLayoutAppearance
            .normal.iconColor = inactiveColor
        tabBarAppearance.stackedLayoutAppearance
            .normal.titleTextAttributes = [
            .foregroundColor: inactiveColor]

        UITabBar.appearance().standardAppearance =
            tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance =
            tabBarAppearance
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
