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
        window.rootViewController = SplashViewController()
        window.makeKeyAndVisible()
        self.window = window
        // 启动后若有上次崩溃, 弹窗显示(崩溃优先,无崩溃才弹公告,避免冲突)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let vc = self?.window?.rootViewController else { return }
            // 1) 优先检查强制更新
            let minVer = RemoteConfig.shared.forceUpdateVersion
            let updateURL = RemoteConfig.shared.updateURL
            if minVer > Config.versionCode {
                let alert = UIAlertController(
                    title: "发现新版本 v\(minVer)",
                    message: "当前版本 v\(Config.versionCode),请更新到最新版本。\n更新后可继续游戏。",
                    preferredStyle: .alert
                )
                if !updateURL.isEmpty, let url = URL(string: updateURL) {
                    alert.addAction(UIAlertAction(title: "去下载更新", style: .default) { _ in
                        UIApplication.shared.open(url)
                    })
                    alert.addAction(UIAlertAction(title: "稍后", style: .cancel))
                } else {
                    alert.addAction(UIAlertAction(title: "知道了", style: .default))
                }
                vc.present(alert, animated: true)
                return
            }
            // 2) 有崩溃日志:弹崩溃弹窗
            if CrashReporter.lastCrash() != nil {
                CrashReporter.reportIfAny(in: vc)
            } else {
                // 3) 无崩溃:弹公告
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
