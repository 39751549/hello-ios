import Foundation

/// 远程配置(云更新核心)
///
/// 用途:客户端启动时拉取服务器 `/api/config`,覆盖本地默认值。
/// 这样 GM 在后台调整技能 CD / 移动速度 / 公告 / 强制升级版本 等,
/// 客户端下次启动即可生效,无需重新打包安装。
///
/// 说明:iOS 不允许动态加载可执行代码(Apple 限制),
/// 所以"云更新"指配置/数值/文案层面的热更新,不是二进制热更。
final class RemoteConfig {

    static let shared = RemoteConfig()

    /// 本地默认值(服务器不可达 / 缺 key 时使用)
    private let defaults: [String: String] = [
        "skill_flame_cd": "8",
        "skill_aoe_cd": "10",
        "skill_heal_cd": "15",
        "skill_ice_cd": "10",
        "skill_thunder_cd": "15",
        "skill_meteor_cd": "20",
        "player_move_speed": "4.0",
        "monster_respawn": "5",
        "auto_battle_interval": "1.4",
        "exp_reward_mult": "1.0",
        "gold_reward_mult": "1.0",
        "feature_sound": "1",
        "feature_auto_battle": "1",
        "notice_text": "欢迎来到幻域神兵!",
        "force_update_version": "0",
        "update_url": "",
    ]

    /// 当前生效的配置(默认值 + 服务器覆盖)
    private(set) var values: [String: String] = [:]

    /// 拉取时间戳(用于调试)
    private(set) var fetchedAt: Date?

    private init() {
        values = defaults
        // 先用上次缓存(若有),保证启动即有值
        if let cached = UserDefaults.standard.dictionary(forKey: "remote_config_cache") as? [String: String] {
            for (k, v) in cached { values[k] = v }
        }
    }

    // MARK: - 拉取
    /// 启动时调用:从服务器拉取最新配置(异步,失败用默认/缓存)
    func fetch(completion: (() -> Void)? = nil) {
        guard let url = URL(string: Config.baseURL + "/api/config") else {
            completion?(); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 8
        req.cachePolicy = .reloadIgnoringLocalCacheData
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            defer { DispatchQueue.main.async { completion?() } }
            guard let self = self,
                  let data = data,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let cfg = obj["data"] as? [String: String] else { return }
            // 合并: 服务器值覆盖默认
            var merged = self.defaults
            for (k, v) in cfg { merged[k] = v }
            self.values = merged
            self.fetchedAt = Date()
            // 持久化缓存
            UserDefaults.standard.set(merged, forKey: "remote_config_cache")
        }.resume()
    }

    // MARK: - 取值
    func string(_ key: String) -> String { values[key] ?? defaults[key] ?? "" }
    func int(_ key: String) -> Int { Int(string(key)) ?? 0 }
    func double(_ key: String) -> Double { Double(string(key)) ?? 0 }
    func bool(_ key: String) -> Bool { string(key) == "1" || string(key) == "true" }

    // MARK: - 便捷访问
    var flameCD: TimeInterval { double("skill_flame_cd") }
    var aoeCD: TimeInterval { double("skill_aoe_cd") }
    var healCD: TimeInterval { double("skill_heal_cd") }
    var iceCD: TimeInterval { double("skill_ice_cd") }
    var thunderCD: TimeInterval { double("skill_thunder_cd") }
    var meteorCD: TimeInterval { double("skill_meteor_cd") }
    var moveSpeed: Float { Float(double("player_move_speed")) }
    var monsterRespawnDelay: TimeInterval { double("monster_respawn") }
    var autoBattleInterval: TimeInterval { double("auto_battle_interval") }
    var expRewardMult: Double { double("exp_reward_mult") }
    var goldRewardMult: Double { double("gold_reward_mult") }
    var soundEnabled: Bool { bool("feature_sound") }
    var autoBattleEnabled: Bool { bool("feature_auto_battle") }
    var noticeText: String { string("notice_text") }
    var forceUpdateVersion: Int { int("force_update_version") }
    var updateURL: String { string("update_url") }
}
