import Foundation
import UIKit
import Darwin

/// 崩溃捕获器: 拦截 NSException + 信号(SIGTRAP/SIGABRT/SIGSEGV...),
/// 把堆栈写入 Documents/last_crash.txt, 下次启动弹窗显示并上报服务器。
/// 这样无需连 Xcode 也能拿到崩溃堆栈。

// 全局变量:供 @convention(c) 回调访问(C 函数指针不能捕获上下文,只能访问全局)
private var g_crashLogPath: String = ""
/// NSException handler 是否已记录详细日志(避免 signal handler 覆盖)
private var g_exceptionLogged: Bool = false

enum CrashReporter {

    static var crashPath: String {
        let docs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        return (docs as NSString).appendingPathComponent("last_crash.txt")
    }

    /// 安装捕获器(应在 didFinishLaunching 最开始调用)
    static func install() {
        // 先把路径存到全局变量,供 C 回调访问
        // 注意:不能在这里清空日志!上次崩溃的日志要留给 reportIfAny() 读取
        g_crashLogPath = crashPath

        // 1) NSException(ObjC 异常, 部分 SceneKit/UIKit/AVAudioEngine 崩溃)
        //    必须是 @convention(c),不能捕获上下文 → 只能访问全局变量
        let exceptionHandler: @convention(c) (NSException) -> Void = { exc in
            let stack = exc.callStackSymbols.joined(separator: "\n")
            let info = """
            [NSException] \(exc.name.rawValue)
            Reason: \(exc.reason ?? "nil")
            Stack:
            \(stack)
            """
            try? info.write(toFile: g_crashLogPath, atomically: true, encoding: .utf8)
            g_exceptionLogged = true
        }
        NSSetUncaughtExceptionHandler(exceptionHandler)

        // 2) 信号(Swift fatalError / 强解包 / 越界 多为 SIGTRAP/SIGABRT)
        //    追加写入,不覆盖 NSException handler 写的详细日志
        let signalHandler: @convention(c) (Int32) -> Void = { sig in
            let stack = Thread.callStackSymbols.joined(separator: "\n")
            let info = "\n\n=== [Signal \(sig)] ===\nStack:\n\(stack)\n"
            // 追加写入:若文件已存在(NSException 已记录),追加 signal 栈
            if FileManager.default.fileExists(atPath: g_crashLogPath),
               let fh = try? FileHandle(forWritingTo: URL(fileURLWithPath: g_crashLogPath)) {
                fh.seekToEndOfFile()
                if let data = info.data(using: .utf8) { fh.write(data) }
                try? fh.close()
            } else {
                // 文件不存在(无 NSException),直接写
                try? info.write(toFile: g_crashLogPath, atomically: true, encoding: .utf8)
            }
            _exit(sig)
        }
        for s in [SIGABRT, SIGILL, SIGTRAP, SIGSEGV, SIGBUS, SIGFPE, SIGPIPE] {
            signal(s, signalHandler)
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
