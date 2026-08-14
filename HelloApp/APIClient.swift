import Foundation

/// 简单的网络错误
enum APIError: Error, LocalizedError {
    case invalidURL
    case http(Int, String)
    case decoding(String)
    case network(String)
    case business(String)            // 服务端返回 code != 0

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "地址错误"
        case .http(let c, let m): return "HTTP \(c): \(m)"
        case .decoding(let m): return "数据解析失败: \(m)"
        case .network(let m): return "网络错误: \(m)"
        case .business(let m): return m
        }
    }
}

/// HTTP API 客户端
final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        cfg.timeoutIntervalForResource = 25
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: cfg)
    }()

    var token: String? {
        get { UserDefaults.standard.string(forKey: Config.tokenKey) }
        set { UserDefaults.standard.set(newValue, forKey: Config.tokenKey) }
    }
    var username: String? {
        get { UserDefaults.standard.string(forKey: Config.usernameKey) }
        set { UserDefaults.standard.set(newValue, forKey: Config.usernameKey) }
    }

    // MARK: - 基础请求
    /// 通用请求:返回解析后的 data 字段
    func request<T: Decodable>(_ path: String,
                               method: String = "GET",
                               body: [String: Any]? = nil,
                               responseType: T.Type,
                               completion: @escaping (Result<T, APIError>) -> Void) {
        guard let url = URL(string: Config.baseURL + path) else {
            completion(.failure(.invalidURL)); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = token { req.setValue("Bearer " + t, forHTTPHeaderField: "Authorization") }
        if let b = body {
            do { req.httpBody = try JSONSerialization.data(withJSONObject: b) }
            catch { completion(.failure(.network("body 序列化失败"))); return }
        }
        #if DEBUG
        print("[API] \(method) \(path)")
        #endif
        session.dataTask(with: req) { data, resp, err in
            DispatchQueue.main.async {
                if let err = err { completion(.failure(.network(err.localizedDescription))); return }
                guard let http = resp as? HTTPURLResponse else {
                    completion(.failure(.network("无响应"))); return
                }
                let raw = data ?? Data()
                #if DEBUG
                print("[API] <- \(http.statusCode) \(String(data: raw, encoding: .utf8)?.prefix(300) ?? "")")
                #endif
                if let apiErr = self.decodeApiError(http.statusCode, raw) {
                    completion(.failure(apiErr)); return
                }
                do {
                    let wrapper = try JSONDecoder().decode(ApiResponse<T>.self, from: raw)
                    if wrapper.code != 0 {
                        completion(.failure(.business(wrapper.msg))); return
                    }
                    guard let d = wrapper.data else {
                        completion(.failure(.business("数据为空"))); return
                    }
                    completion(.success(d))
                } catch {
                    completion(.failure(.decoding(error.localizedDescription)))
                }
            }
        }.resume()
    }

    /// 处理 HTTP 4xx/5xx 错误
    private func decodeApiError(_ status: Int, _ data: Data) -> APIError? {
        guard status >= 400 else { return nil }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let detail = obj["detail"] {
            if let arr = detail as? [[String: Any]], let first = arr.first,
               let msg = first["msg"] as? String {
                return .http(status, msg)
            }
            if let s = detail as? String { return .http(status, s) }
        }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let msg = obj["msg"] as? String, msg != "ok" {
            return .http(status, msg)
        }
        return .http(status, "请求失败(\(status))")
    }

    // MARK: - 业务接口
    // 账号
    func register(username: String, password: String, nickname: String?, completion: @escaping (Result<AuthData, APIError>) -> Void) {
        var body: [String: Any] = ["username": username, "password": password]
        if let n = nickname, !n.isEmpty { body["nickname"] = n }
        request("/api/auth/register", method: "POST", body: body, responseType: AuthData.self) { [weak self] res in
            if case .success(let data) = res {
                self?.token = data.token
                self?.username = username
            }
            completion(res)
        }
    }

    func login(username: String, password: String, completion: @escaping (Result<AuthData, APIError>) -> Void) {
        let body: [String: Any] = ["username": username, "password": password]
        request("/api/auth/login", method: "POST", body: body, responseType: AuthData.self) { [weak self] res in
            if case .success(let data) = res {
                self?.token = data.token
                self?.username = username
            }
            completion(res)
        }
    }

    func logout() {
        token = nil
        username = nil
    }

    // 玩家
    func getMe(completion: @escaping (Result<PlayerInfo, APIError>) -> Void) {
        request("/api/player/me", responseType: PlayerInfo.self, completion: completion)
    }
    func heal(completion: @escaping (Result<PlayerInfo, APIError>) -> Void) {
        request("/api/player/heal", method: "POST", body: [:], responseType: PlayerInfo.self, completion: completion)
    }
    func equip(playerItemId: Int, completion: @escaping (Result<PlayerInfo, APIError>) -> Void) {
        request("/api/player/equip", method: "POST", body: ["player_item_id": playerItemId], responseType: PlayerInfo.self, completion: completion)
    }
    func unequip(itemId: Int, completion: @escaping (Result<PlayerInfo, APIError>) -> Void) {
        request("/api/player/unequip", method: "POST", body: ["player_item_id": itemId], responseType: PlayerInfo.self, completion: completion)
    }
    func useItem(playerItemId: Int, count: Int, completion: @escaping (Result<PlayerInfo, APIError>) -> Void) {
        request("/api/player/use_item", method: "POST", body: ["player_item_id": playerItemId, "count": count], responseType: PlayerInfo.self, completion: completion)
    }

    // 战斗
    func fightWild(level: Int, completion: @escaping (Result<BattleResult, APIError>) -> Void) {
        request("/api/battle/fight", method: "POST", body: ["enemy_level": level], responseType: BattleResult.self, completion: completion)
    }
    func fightBoss(bossId: Int, completion: @escaping (Result<BattleResult, APIError>) -> Void) {
        request("/api/battle/fight", method: "POST", body: ["boss_id": bossId], responseType: BattleResult.self, completion: completion)
    }

    // Boss 列表
    func getBossList(completion: @escaping (Result<[BossInfo], APIError>) -> Void) {
        request("/api/boss/list", responseType: [BossInfo].self, completion: completion)
    }

    // 抽奖
    func getGachaPools(completion: @escaping (Result<[GachaPool], APIError>) -> Void) {
        request("/api/gacha/pools", responseType: [GachaPool].self, completion: completion)
    }
    func draw(poolId: Int, times: Int, completion: @escaping (Result<GachaDrawData, APIError>) -> Void) {
        request("/api/gacha/draw", method: "POST", body: ["pool_id": poolId, "times": times], responseType: GachaDrawData.self, completion: completion)
    }

    // 商店
    func getShopItems(completion: @escaping (Result<[ItemInfo], APIError>) -> Void) {
        request("/api/shop/items", responseType: [ItemInfo].self, completion: completion)
    }
    func buy(itemId: Int, count: Int, completion: @escaping (Result<PlayerInfo, APIError>) -> Void) {
        request("/api/shop/buy", method: "POST", body: ["item_id": itemId, "count": count], responseType: PlayerInfo.self, completion: completion)
    }
}
