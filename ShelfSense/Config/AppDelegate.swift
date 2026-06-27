import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Controls which orientations the app allows at any given moment.
    /// Default is portrait; the chart view temporarily unlocks landscape.
    static var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Earliest possible UIKit hook — fires before UIWindow is created.
        // Eliminates the black flash between system launch screen and first SwiftUI frame.
        UIWindow.appearance().backgroundColor = UIColor(
            red: 27/255, green: 94/255, blue: 32/255, alpha: 1
        )
        return true
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        AppDelegate.orientationLock
    }
}
