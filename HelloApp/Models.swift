import Foundation

// MARK: - 通用响应
struct ApiResponse<T: Decodable>: Decodable {
    let code: Int
    let msg: String
    let data: T?
}

// MARK: - 物品
struct ItemInfo: Codable {
    let id: Int
    let code: String
    let name: String
    let type: String          // weapon/armor/skin/consumable
    let rarity: String        // common/rare/epic/legend/myth
    let atk: Int
    let df: Int
    let hp: Int
    let priceGold: Int
    let priceDiamond: Int
    let color: String
    let desc: String

    enum CodingKeys: String, CodingKey {
        case id, code, name, type, rarity, atk, df, hp, color, desc
        case priceGold = "price_gold"
        case priceDiamond = "price_diamond"
    }

    var rarityName: String {
        switch rarity {
        case "common": return "普通"
        case "rare":   return "稀有"
        case "epic":   return "史诗"
        case "legend": return "传说"
        case "myth":   return "神话"
        default: return rarity
        }
    }
    var typeName: String {
        switch type {
        case "weapon": return "武器"
        case "armor":  return "防具"
        case "skin":   return "皮肤"
        case "consumable": return "消耗品"
        case "material":   return "材料"
        default: return type
        }
    }
    var rarityColor: UIColor {
        return UIColor.rarity(rarity)
    }
}

struct PlayerItemInfo: Codable {
    let id: Int
    let item: ItemInfo
    let count: Int
}

// MARK: - 玩家信息
struct PlayerInfo: Codable {
    let id: Int
    let nickname: String
    let level: Int
    let exp: Int
    let expNext: Int
    let gold: Int
    let diamond: Int
    let vip: Int
    let hp: Int
    let atk: Int
    let df: Int
    let curHp: Int
    let totalAtk: Int
    let totalDf: Int
    let totalHp: Int
    let killCount: Int
    let bossKillCount: Int
    let gachaCount: Int
    let equip: [String: Int?]
    let items: [PlayerItemInfo]

    enum CodingKeys: String, CodingKey {
        case id, nickname, level, exp, gold, diamond, vip, hp, atk, df, equip, items
        case expNext = "exp_next"
        case curHp = "cur_hp"
        case totalAtk = "total_atk"
        case totalDf = "total_df"
        case totalHp = "total_hp"
        case killCount = "kill_count"
        case bossKillCount = "boss_kill_count"
        case gachaCount = "gacha_count"
    }

    var equipWeapon: Int? { equip["weapon"].flatMap { $0 } }
    var equipArmor:  Int? { equip["armor"].flatMap { $0 } }
    var equipSkin:   Int? { equip["skin"].flatMap { $0 } }
}

// MARK: - 登录/注册
struct AuthData: Codable {
    let token: String
    let player_id: Int?
}

// MARK: - 战斗结果
struct BattleResult: Codable {
    let win: Bool
    let rounds: Int
    let hpLeft: Int
    let expGain: Int
    let goldGain: Int
    let diamondGain: Int
    let drops: [DropItem]
    let log: [String]
    let leveledUp: [Int]
    let enemyName: String
    let player: PlayerInfo?

    enum CodingKeys: String, CodingKey {
        case win, rounds, log, player, drops
        case hpLeft = "hp_left"
        case expGain = "exp_gain"
        case goldGain = "gold_gain"
        case diamondGain = "diamond_gain"
        case leveledUp = "leveled_up"
        case enemyName = "enemy_name"
    }
}

struct DropItem: Codable {
    let item_id: Int
    let count: Int
}

// MARK: - 抽奖
struct GachaPoolItem: Codable {
    let item: ItemInfo
    let weight: Int
}
struct GachaPool: Codable {
    let id: Int
    let name: String
    let costType: String
    let costOnce: Int
    let costTen: Int
    let desc: String
    let totalWeight: Int
    let items: [GachaPoolItem]

    enum CodingKeys: String, CodingKey {
        case id, name, desc, items
        case costType = "cost_type"
        case costOnce = "cost_once"
        case costTen = "cost_ten"
        case totalWeight = "total_weight"
    }
}

struct GachaResultItem: Codable {
    let item: ItemInfo
    let count: Int
    let isNew: Bool
    enum CodingKeys: String, CodingKey {
        case item, count
        case isNew = "is_new"
    }
}
struct GachaDrawData: Codable {
    let results: [GachaResultItem]
    let costType: String
    let costAmount: Int
    let player: PlayerInfo?
    enum CodingKeys: String, CodingKey {
        case results, player
        case costType = "cost_type"
        case costAmount = "cost_amount"
    }
}

// MARK: - Boss
struct BossInfo: Codable {
    let id: Int
    let name: String
    let level: Int
    let hp: Int
    let atk: Int
    let df: Int
    let expReward: Int
    let goldReward: Int
    let diamondReward: Int
    let color: String
    let desc: String
    let tier: Int

    enum CodingKeys: String, CodingKey {
        case id, name, level, hp, atk, df, color, desc, tier
        case expReward = "exp_reward"
        case goldReward = "gold_reward"
        case diamondReward = "diamond_reward"
    }
}
