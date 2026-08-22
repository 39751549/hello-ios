import Foundation

/// 单机模式: 本地存档 + 战斗结算(无需服务器)
final class LocalGameManager {
    static let shared = LocalGameManager()
    private init() {}

    private let saveKey = "old_money_local_player"
    private var player: PlayerInfo?

    private struct BossDef {
        let id: Int
        let name: String
        let hp: Int
        let atk: Int
        let df: Int
        let exp: Int
        let gold: Int
        let diamond: Int
    }

    private let bosses: [BossDef] = [
        BossDef(id: 1, name: "哥布林首领", hp: 800, atk: 25, df: 5, exp: 80, gold: 150, diamond: 0),
    ]

    // MARK: - 存档
    func ensurePlayer() {
        if player == nil { player = load() }
        if player == nil {
            player = defaultPlayer()
            save()
        }
    }

    func getPlayer() -> PlayerInfo {
        ensurePlayer()
        return player!
    }

    private func defaultPlayer() -> PlayerInfo {
        makePlayer(
            nickname: "豪门少主", level: 1, exp: 0, gold: 500, diamond: 10,
            hp: 100, atk: 15, df: 5, curHp: 100,
            killCount: 0, bossKillCount: 0
        )
    }

    private func makePlayer(
        nickname: String, level: Int, exp: Int, gold: Int, diamond: Int,
        hp: Int, atk: Int, df: Int, curHp: Int,
        killCount: Int, bossKillCount: Int
    ) -> PlayerInfo {
        PlayerInfo(
            id: 1, nickname: nickname, level: level, exp: exp, expNext: expToNext(level),
            gold: gold, diamond: diamond, vip: 0,
            hp: hp, atk: atk, df: df, curHp: curHp,
            totalAtk: atk, totalDf: df, totalHp: hp,
            killCount: killCount, bossKillCount: bossKillCount, gachaCount: 0,
            equip: ["weapon": nil, "armor": nil, "skin": nil],
            items: []
        )
    }

    private func save() {
        guard let p = player else { return }
        if let data = try? JSONEncoder().encode(p) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func load() -> PlayerInfo? {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else { return nil }
        return try? JSONDecoder().decode(PlayerInfo.self, from: data)
    }

    // MARK: - 经验
    private func expToNext(_ level: Int) -> Int {
        Int(100.0 * pow(Double(level), 1.35))
    }

    @discardableResult
    private func addExp(_ amount: Int) -> [Int] {
        guard let p = player else { return [] }
        var exp = p.exp + amount
        var level = p.level
        var hp = p.hp, atk = p.atk, df = p.df
        var leveled: [Int] = []
        while level < 100 && exp >= expToNext(level) {
            exp -= expToNext(level)
            level += 1
            hp += 20; atk += 3; df += 2
            leveled.append(level)
        }
        if level >= 100 { exp = 0 }
        player = makePlayer(
            nickname: p.nickname, level: level, exp: exp, gold: p.gold, diamond: p.diamond,
            hp: hp, atk: atk, df: df, curHp: leveled.isEmpty ? p.curHp : hp,
            killCount: p.killCount, bossKillCount: p.bossKillCount
        )
        save()
        return leveled
    }

    // MARK: - 战斗接口
    func fightWild(level: Int, completion: @escaping (Result<BattleResult, APIError>) -> Void) {
        ensurePlayer()
        let lvl = max(level, 1)
        let result = resolveBattle(
            enemyName: wildName(for: lvl), eHp: 120 * lvl + 80, eAtk: 10 * lvl + 5, eDf: 3 * lvl + 2,
            expReward: 35 * lvl, goldReward: 50 * lvl, diamondReward: 0, isBoss: false
        )
        DispatchQueue.main.async { completion(.success(result)) }
    }

    func fightBoss(bossId: Int, completion: @escaping (Result<BattleResult, APIError>) -> Void) {
        ensurePlayer()
        guard let boss = bosses.first(where: { $0.id == bossId }) else {
            DispatchQueue.main.async { completion(.failure(.business("Boss 不存在"))) }
            return
        }
        let result = resolveBattle(
            enemyName: boss.name, eHp: boss.hp, eAtk: boss.atk, eDf: boss.df,
            expReward: boss.exp, goldReward: boss.gold, diamondReward: boss.diamond, isBoss: true
        )
        DispatchQueue.main.async { completion(.success(result)) }
    }

    func heal(completion: @escaping (Result<PlayerInfo, APIError>) -> Void) {
        ensurePlayer()
        guard let p = player else { return }
        player = makePlayer(
            nickname: p.nickname, level: p.level, exp: p.exp, gold: p.gold, diamond: p.diamond,
            hp: p.hp, atk: p.atk, df: p.df, curHp: p.totalHp,
            killCount: p.killCount, bossKillCount: p.bossKillCount
        )
        save()
        DispatchQueue.main.async { completion(.success(player!)) }
    }

    // MARK: - 战斗核心
    private func resolveBattle(enemyName: String, eHp: Int, eAtk: Int, eDf: Int,
                               expReward: Int, goldReward: Int, diamondReward: Int,
                               isBoss: Bool) -> BattleResult {
        guard let p = player else {
            return BattleResult(win: false, rounds: 0, hpLeft: 0, expGain: 0, goldGain: 0,
                                diamondGain: 0, drops: [], log: [], leveledUp: [],
                                enemyName: enemyName, player: nil)
        }
        let curHp = max(p.curHp, 1)
        let (win, rounds, hpLeft, log) = calcBattle(
            pAtk: p.totalAtk, pDf: p.totalDf, pHp: curHp, eAtk: eAtk, eDf: eDf, eHp: eHp
        )
        var leveled: [Int] = []
        if win {
            leveled = addExp(expReward)
            let updated = getPlayer()
            player = makePlayer(
                nickname: updated.nickname, level: updated.level, exp: updated.exp,
                gold: updated.gold + goldReward, diamond: updated.diamond + diamondReward,
                hp: updated.hp, atk: updated.atk, df: updated.df,
                curHp: min(max(hpLeft, 1), updated.totalHp),
                killCount: updated.killCount + 1,
                bossKillCount: updated.bossKillCount + (isBoss ? 1 : 0)
            )
            save()
        } else {
            player = makePlayer(
                nickname: p.nickname, level: p.level, exp: p.exp, gold: p.gold, diamond: p.diamond,
                hp: p.hp, atk: p.atk, df: p.df, curHp: max(p.curHp / 2, 1),
                killCount: p.killCount, bossKillCount: p.bossKillCount
            )
            save()
        }
        return BattleResult(
            win: win, rounds: rounds, hpLeft: max(hpLeft, 0),
            expGain: win ? expReward : 0, goldGain: win ? goldReward : 0,
            diamondGain: win ? diamondReward : 0, drops: [],
            log: log, leveledUp: leveled, enemyName: enemyName, player: getPlayer()
        )
    }

    private func wildName(for level: Int) -> String {
        let names = ["史莱姆", "野鼠", "野狼", "哥布林", "蜘蛛", "骷髅兵", "石巨人", "暗影骑士", "冰霜巨魔", "烈焰恶魔"]
        return names[min(max(level - 1, 0), names.count - 1)]
    }

    private func calcBattle(pAtk: Int, pDf: Int, pHp: Int, eAtk: Int, eDf: Int, eHp: Int) -> (Bool, Int, Int, [String]) {
        var pHpCur = pHp, eHpCur = eHp
        var combo = 0
        for r in 1...80 {
            var base = max(Int(Double(pAtk) * Double.random(in: 0.85...1.25)) - eDf, 1)
            let crit = Double.random(in: 0...1) < 0.25
            if Double.random(in: 0...1) >= 0.05 {
                if crit { base = Int(Double(base) * 2.2); combo += 1 } else { combo = 0 }
                if combo >= 2 { base = Int(Double(base) * (1 + 0.15 * Double(combo))) }
                eHpCur -= base
                if eHpCur <= 0 { return (true, r, pHpCur, []) }
            }
            let edmg = max(Int(Double(eAtk) * Double.random(in: 0.85...1.1)) - pDf, 1)
            if Double.random(in: 0...1) >= 0.08 {
                pHpCur -= edmg
                if pHpCur <= 0 { return (false, r, 0, []) }
            }
        }
        return (false, 80, pHpCur, [])
    }
}
