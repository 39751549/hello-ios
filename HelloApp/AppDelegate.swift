import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        CrashReporter.install()   // 最先安装崩溃捕获
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
        // 启动后若有上次崩溃, 弹窗显示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            if let vc = self?.window?.rootViewController {
                CrashReporter.reportIfAny(in: vc)
            }
        }
        return true
    }

    func supportedInterfaceOrientations(for window: UIWindow?) -> UIInterfaceOrientationMask {
        return .landscape
    }
}
