import Foundation
import UIKit

/// 全局配置
enum Config {
    /// 服务器地址(部署后改为公网 IP)
    static let serverBaseURL = "http://180.184.41.230:9888"

    /// 本地调试时可用 127.0.0.1:9888(需启动 server/start.bat)
    static let localBaseURL = "http://127.0.0.1:9888"

    /// 当前使用的基础地址
    static var baseURL: String {
        // 优先用 UserDefault 保存的(便于调试切换),默认用公网
        return UserDefaults.standard.string(forKey: "cfg_base_url") ?? serverBaseURL
    }

    static func setBaseURL(_ url: String) {
        UserDefaults.standard.set(url, forKey: "cfg_base_url")
    }

    static let tokenKey = "auth_token"
    static let usernameKey = "auth_username"

    /// 客户端版本号(整数,每次发版+1)
    /// 与服务端 force_update_version 比较:当 force_update_version > versionCode 时弹更新提示
    static let versionCode: Int = 4
    /// 版本显示字符串
    static let versionString = "1.1.0"
}
