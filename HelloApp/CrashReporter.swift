import Foundation
import UIKit
import Darwin

/// 崩溃捕获器: 拦截 NSException + 信号(SIGTRAP/SIGABRT/SIGSEGV...),
/// 把堆栈写入 Documents/last_crash.txt, 下次启动弹窗显示并上报服务器。
/// 这样无需连 Xcode 也能拿到崩溃堆栈。
enum CrashReporter {

    static var crashPath: String {
        let docs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        return (docs as NSString).appendingPathComponent("last_crash.txt")
    }

    /// 安装捕获器(应在 didFinishLaunching 最开始调用)
    static func install() {
        // 1) NSException(ObjC 异常, 部分 SceneKit/UIKit 崩溃)
        NSSetUncaughtExceptionHandler { exc in
            let stack = exc.callStackSymbols.joined(separator: "\n")
            let info = "[NSException] \(exc.name.rawValue)\nReason: \(exc.reason ?? "nil")\nStack:\n\(stack)\n"
            try? info.write(toFile: crashPath, atomically: true, encoding: .utf8)
        }
        // 2) 信号(Swift fatalError / 强解包 / 越界 多为 SIGTRAP/SIGABRT)
        let handler: @convention(c) (Int32) -> Void = { sig in
            let stack = Thread.callStackSymbols.joined(separator: "\n")
            let info = "[Signal \(sig)]\nStack:\n\(stack)\n"
            try? info.write(toFile: CrashReporter.crashPath, atomically: true, encoding: .utf8)
            _exit(sig)
        }
        for s in [SIGABRT, SIGILL, SIGTRAP, SIGSEGV, SIGBUS, SIGFPE, SIGPIPE] {
            signal(s, handler)
        }
    }

    static func lastCrash() -> String? {
        guard FileManager.default.fileExists(atPath: crashPath) else { return nil }
        return try? String(contentsOfFile: crashPath, encoding: .utf8)
    }

    static func clear() {
        try? FileManager.default.removeItem(atPath: crashPath)
    }

    /// 启动时若有上次崩溃, 弹窗显示 + 复制剪贴板 + 上报服务器
    static func reportIfAny(in vc: UIViewController) {
        guard let text = lastCrash(), !text.isEmpty else { return }
        UIPasteboard.general.string = text
        // 上报服务器(失败忽略)
        if let url = URL(string: Config.baseURL + "/api/crash_log") {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.timeoutInterval = 8
            let body: [String: Any] = [
                "crash": text,
                "device": UIDevice.current.model,
                "system": UIDevice.current.systemVersion,
                "app": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
            ]
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            URLSession.shared.dataTask(with: req).resume()
        }
        let short = String(text.prefix(900))
        let alert = UIAlertController(
            title: "检测到上次崩溃(已复制+已上报)",
            message: short,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "清除并继续", style: .default) { _ in clear() })
        vc.present(alert, animated: true)
    }
}
