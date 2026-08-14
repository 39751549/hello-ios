import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let root: UIViewController
        if APIClient.shared.token != nil {
            root = GameViewController()
        } else {
            root = AuthViewController()
        }
        window.rootViewController = root
        window.makeKeyAndVisible()
        self.window = window
        return true
    }

    func supportedInterfaceOrientations(for window: UIWindow?) -> UIInterfaceOrientationMask {
        return .landscape
    }
}
