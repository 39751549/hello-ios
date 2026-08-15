import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        CrashReporter.install()   // 最先安装崩溃捕获
        // 拉取远程配置(云更新):用缓存值立即生效,服务器返回后下次启动应用
        RemoteConfig.shared.fetch()
        // 应用音效开关
        SoundManager.shared.setEnabled(RemoteConfig.shared.soundEnabled)

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
        // 启动后若有上次崩溃, 弹窗显示(崩溃优先,无崩溃才弹公告,避免冲突)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let vc = self?.window?.rootViewController else { return }
            if CrashReporter.lastCrash() != nil {
                // 有崩溃日志:只弹崩溃弹窗(用户点"清除并继续"后关闭)
                CrashReporter.reportIfAny(in: vc)
            } else {
                // 无崩溃:弹公告(云更新:GM 可在后台修改)
                let notice = RemoteConfig.shared.noticeText
                if !notice.isEmpty {
                    let alert = UIAlertController(title: "公告", message: notice, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "知道了", style: .default))
                    vc.present(alert, animated: true)
                }
            }
        }
        return true
    }

    func supportedInterfaceOrientations(for window: UIWindow?) -> UIInterfaceOrientationMask {
        return .landscape
    }
}
