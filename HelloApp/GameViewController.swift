import UIKit
import SceneKit

/// 游戏主界面
final class GameViewController: UIViewController, SCNSceneRendererDelegate {

    /// 单机模式(无需登录服务器)
    var isOfflineMode = false

    private let scnView = SCNView()
    private let scene = GameScene()
    private let hudView = HUDView()
    private let joystick = JoystickView()
    private let attackBtn = UIButton(type: .system)
    private let flameBtn = UIButton(type: .system)
    private let healBtn = UIButton(type: .system)
    private let aoeBtn = UIButton(type: .system)
    private let iceBtn = UIButton(type: .system)
    private let thunderBtn = UIButton(type: .system)
    private let meteorBtn = UIButton(type: .system)
    private let skillStack = UIStackView()
    private let autoBtn = UIButton(type: .system)
    private let minimap = MinimapView()
    private let menuStack = UIStackView()
    private let logoutBtn = UIButton(type: .system)
    private let bubbleStack = UIStackView()
    private var displayLink: CADisplayLink?
    private var lastTime: CFTimeInterval = 0
    private var inBattle = false
    private var aoeInProgress = false
    private var playerInfo: PlayerInfo?
    private var autoBattle = false
    private var autoTimer: Timer?
    private var cooldowns: [String: TimeInterval] = [:]   // key -> 可用时间戳
    private var cooldownTimers: [String: Timer] = [:]

    /// 技能配置(图标/颜色/解锁等级)
    private struct SkillConfig {
        let icon: String
        let color: UIColor
        let unlockLevel: Int
    }
    private let skillConfigs: [String: SkillConfig] = [
        "flame":   SkillConfig(icon: "🔥", color: .epic, unlockLevel: 1),
        "aoe":     SkillConfig(icon: "🌀", color: .legend, unlockLevel: 1),
        "heal":    SkillConfig(icon: "✨", color: UIColor(hex: 0x66bb6a), unlockLevel: 1),
        "ice":     SkillConfig(icon: "❄️", color: UIColor(hex: 0x42a5f5), unlockLevel: 5),
        "thunder": SkillConfig(icon: "⚡", color: UIColor(hex: 0xffeb3b), unlockLevel: 10),
        "meteor":  SkillConfig(icon: "☄️", color: UIColor(hex: 0xff5722), unlockLevel: 15),
    ]

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .bgDark
        setupScene()
        setupHUD()
        setupControls()
        setupMenu()
        setupBubbles()
        loadMe()
        if isOfflineMode {
            logoutBtn.setTitle("菜单", for: .normal)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startLoop()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopLoop()
        autoTimer?.invalidate()
        for (_, t) in cooldownTimers { t.invalidate() }
        cooldownTimers.removeAll()
    }

    // MARK: - 3D 场景
    private func setupScene() {
        scnView.translatesAutoresizingMaskIntoConstraints = false
        scnView.scene = scene
        scnView.delegate = self
        scnView.isPlaying = true
        scnView.preferredFramesPerSecond = 60
        scnView.antialiasingMode = .multisampling4X
        scnView.backgroundColor = UIColor(hex: 0x0a0f1c)
        scnView.isMultipleTouchEnabled = true
        scnView.rendersContinuously = true
        view.addSubview(scnView)

        // 点击怪物
        let tap = UITapGestureRecognizer(target: self, action: #selector(sceneTapped(_:)))
        scnView.addGestureRecognizer(tap)

        // 滑动旋转视角(单指拖动)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(scenePanned(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        pan.delegate = self
        scnView.addGestureRecognizer(pan)

        NSLayoutConstraint.activate([
            scnView.topAnchor.constraint(equalTo: view.topAnchor),
            scnView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scnView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scnView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    // MARK: - HUD(缩小)
    private func setupHUD() {
        hudView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hudView)

        NSLayoutConstraint.activate([
            hudView.topAnchor.constraint(equalTo: view.topAnchor, constant: 50),
            hudView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            hudView.widthAnchor.constraint(equalToConstant: 268),
            hudView.heightAnchor.constraint(equalToConstant: 44),
        ])

        // 小地图(右上角,避开灵动岛区域,下移)
        minimap.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(minimap)
        NSLayoutConstraint.activate([
            minimap.topAnchor.constraint(equalTo: view.topAnchor, constant: 50),
            minimap.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            minimap.widthAnchor.constraint(equalToConstant: 84),
            minimap.heightAnchor.constraint(equalToConstant: 84),
        ])
    }

    // MARK: - 摇杆/攻击/技能/AUTO
    private func setupControls() {
        joystick.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(joystick)
        joystick.onChange = { [weak self] x, y in
            self?.scene.setMoveVector(SIMD2<Float>(Float(x), Float(y)))
        }
        NSLayoutConstraint.activate([
            joystick.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            joystick.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -22),
            joystick.widthAnchor.constraint(equalToConstant: 120),
            joystick.heightAnchor.constraint(equalToConstant: 120),
        ])

        // AUTO 自动挂机按钮(放左边,摇杆右上方)
        autoBtn.translatesAutoresizingMaskIntoConstraints = false
        autoBtn.setTitle("AUTO", for: .normal)
        autoBtn.titleLabel?.font = .systemFont(ofSize: 11, weight: .bold)
        autoBtn.setTitleColor(.white, for: .normal)
        autoBtn.backgroundColor = UIColor(hex: 0x2a3040)
        autoBtn.layer.cornerRadius = 16
        autoBtn.layer.borderWidth = 1
        autoBtn.layer.borderColor = UIColor(hex: 0x4a5568).cgColor
        autoBtn.addTarget(self, action: #selector(toggleAutoBattle), for: .touchUpInside)
        view.addSubview(autoBtn)

        // 普攻按钮(右下,大圆)
        attackBtn.translatesAutoresizingMaskIntoConstraints = false
        attackBtn.setTitle("⚔", for: .normal)
        attackBtn.titleLabel?.font = .systemFont(ofSize: 30, weight: .bold)
        attackBtn.setTitleColor(.white, for: .normal)
        attackBtn.backgroundColor = UIColor.danger.withAlphaComponent(0.85)
        attackBtn.layer.cornerRadius = 36
        attackBtn.layer.borderColor = UIColor.danger.cgColor
        attackBtn.layer.borderWidth = 2
        attackBtn.makeGlow(.danger, radius: 12, opacity: 0.6)
        attackBtn.addTarget(self, action: #selector(attackNearest), for: .touchUpInside)
        view.addSubview(attackBtn)

        // 技能按钮容器(横向排列6个技能,每个40x40)
        skillStack.translatesAutoresizingMaskIntoConstraints = false
        skillStack.axis = .horizontal
        skillStack.alignment = .center
        skillStack.spacing = 8
        view.addSubview(skillStack)

        // 配置6个技能按钮: (按钮, key, selector)
        let skillButtons: [(UIButton, String, Selector)] = [
            (flameBtn,   "flame",   #selector(flameSkill)),
            (aoeBtn,     "aoe",     #selector(aoeSkill)),
            (healBtn,    "heal",    #selector(healSkill)),
            (iceBtn,     "ice",     #selector(iceSkill)),
            (thunderBtn, "thunder", #selector(thunderSkill)),
            (meteorBtn,  "meteor",  #selector(meteorSkill)),
        ]
        for (btn, key, sel) in skillButtons {
            guard let cfg = skillConfigs[key] else { continue }
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.setTitle(cfg.icon, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
            btn.backgroundColor = cfg.color.withAlphaComponent(0.85)
            btn.layer.cornerRadius = 20
            btn.layer.borderColor = cfg.color.cgColor
            btn.layer.borderWidth = 1.5
            btn.makeGlow(cfg.color, radius: 8, opacity: 0.5)
            btn.addTarget(self, action: sel, for: .touchUpInside)
            btn.widthAnchor.constraint(equalToConstant: 40).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 40).isActive = true
            skillStack.addArrangedSubview(btn)
        }

        NSLayoutConstraint.activate([
            autoBtn.leadingAnchor.constraint(equalTo: joystick.trailingAnchor, constant: 10),
            autoBtn.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -44),
            autoBtn.widthAnchor.constraint(equalToConstant: 64),
            autoBtn.heightAnchor.constraint(equalToConstant: 32),

            attackBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            attackBtn.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -24),
            attackBtn.widthAnchor.constraint(equalToConstant: 72),
            attackBtn.heightAnchor.constraint(equalToConstant: 72),
            // 技能横排在攻击按钮左侧
            skillStack.trailingAnchor.constraint(equalTo: attackBtn.leadingAnchor, constant: -12),
            skillStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -28),
        ])

        // 初始刷新技能解锁状态
        refreshSkillUnlocks()
    }

    // MARK: - 顶部圆形图标菜单
    private func setupMenu() {
        let items: [(String, UIColor, Selector)] = [
            ("👤", .diamond, #selector(openCharacter)),
            ("🎒", .primary, #selector(openInventory)),
            ("🎁", .accent, #selector(openGacha)),
            ("🛒", .epic, #selector(openShop)),
            ("🐲", .legend, #selector(openBoss)),
            ("💎", .diamond, #selector(openRecharge)),
        ]
        menuStack.translatesAutoresizingMaskIntoConstraints = false
        menuStack.axis = .horizontal
        menuStack.spacing = 10
        menuStack.alignment = .center
        view.addSubview(menuStack)

        for (icon, color, sel) in items {
            let b = makeRoundMenuButton(icon: icon, color: color)
            b.addTarget(self, action: sel, for: .touchUpInside)
            menuStack.addArrangedSubview(b)
        }

        logoutBtn.translatesAutoresizingMaskIntoConstraints = false
        logoutBtn.setTitle("退出", for: .normal)
        logoutBtn.titleLabel?.font = .systemFont(ofSize: 10, weight: .medium)
        logoutBtn.setTitleColor(UIColor(hex: 0x8b9bb4), for: .normal)
        logoutBtn.addTarget(self, action: #selector(doLogout), for: .touchUpInside)
        view.addSubview(logoutBtn)

        NSLayoutConstraint.activate([
            menuStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            menuStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            menuStack.heightAnchor.constraint(equalToConstant: 40),
            logoutBtn.centerYAnchor.constraint(equalTo: menuStack.centerYAnchor),
            logoutBtn.leadingAnchor.constraint(equalTo: menuStack.trailingAnchor, constant: 8),
        ])
    }

    private func makeRoundMenuButton(icon: String, color: UIColor) -> UIButton {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle(icon, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        b.backgroundColor = color.withAlphaComponent(0.85)
        b.layer.cornerRadius = 19
        b.layer.borderColor = color.cgColor
        b.layer.borderWidth = 1.2
        b.makeGlow(color, radius: 6, opacity: 0.4)
        b.widthAnchor.constraint(equalToConstant: 38).isActive = true
        b.heightAnchor.constraint(equalToConstant: 38).isActive = true
        b.addTarget(self, action: #selector(menuTapSound), for: .touchUpInside)
        return b
    }

    @objc private func menuTapSound() { SoundManager.shared.play(.button) }

    // MARK: - 左侧战果小气泡
    private func setupBubbles() {
        bubbleStack.translatesAutoresizingMaskIntoConstraints = false
        bubbleStack.axis = .vertical
        bubbleStack.alignment = .leading
        bubbleStack.spacing = 6
        view.addSubview(bubbleStack)
        NSLayoutConstraint.activate([
            bubbleStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            bubbleStack.topAnchor.constraint(equalTo: hudView.bottomAnchor, constant: 10),
            bubbleStack.widthAnchor.constraint(equalToConstant: 200),
        ])
    }

    /// 显示一条左侧小气泡(自动消失)
    func showKillBubble(_ text: String, color: UIColor = .primary, icon: String = "✦") {
        let b = UILabel.make(" \(icon) \(text) ", font: .systemFont(ofSize: 12, weight: .semibold), color: .white, alignment: .left)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.backgroundColor = UIColor.bgDark.withAlphaComponent(0.82)
        b.layer.cornerRadius = 10
        b.layer.masksToBounds = true
        b.layer.borderColor = color.withAlphaComponent(0.6).cgColor
        b.layer.borderWidth = 1
        b.alpha = 0
        b.heightAnchor.constraint(equalToConstant: 26).isActive = true
        bubbleStack.addArrangedSubview(b)
        UIView.animate(withDuration: 0.2) { b.alpha = 1 } completion: { _ in
            UIView.animate(withDuration: 0.4, delay: 2.2, options: []) { b.alpha = 0 } completion: { _ in
                self.bubbleStack.removeArrangedSubview(b)
                b.removeFromSuperview()
            }
        }
        // 最多保留 5 条
        while bubbleStack.arrangedSubviews.count > 5 {
            let old = bubbleStack.arrangedSubviews.first!
            bubbleStack.removeArrangedSubview(old)
            old.removeFromSuperview()
        }
    }

    // MARK: - 加载玩家
    private func loadMe() {
        if isOfflineMode {
            applyPlayer(LocalGameManager.shared.getPlayer())
            return
        }
        APIClient.shared.getMe { [weak self] res in
            switch res {
            case .success(let p):
                self?.applyPlayer(p)
            case .failure(let err):
                self?.showToast(err.errorDescription ?? "加载失败", isError: true)
            }
        }
    }

    private func applyPlayer(_ p: PlayerInfo) {
        self.playerInfo = p
        hudView.update(p)
        let pct = p.totalHp > 0 ? CGFloat(p.curHp) / CGFloat(p.totalHp) : 0
        scene.setPlayerHp(pct: pct)
        // 玩家等级变化时刷新技能解锁状态
        refreshSkillUnlocks()
    }

    // MARK: - 技能解锁
    /// 检查技能是否已解锁(根据玩家等级)
    private func isSkillUnlocked(_ key: String) -> Bool {
        let playerLv = playerInfo?.level ?? 1
        guard let cfg = skillConfigs[key] else { return false }
        return playerLv >= cfg.unlockLevel
    }

    /// 刷新所有技能按钮的解锁状态(根据玩家等级)
    private func refreshSkillUnlocks() {
        let playerLv = playerInfo?.level ?? 1
        let skillButtons: [(UIButton, String)] = [
            (flameBtn, "flame"), (aoeBtn, "aoe"), (healBtn, "heal"),
            (iceBtn, "ice"), (thunderBtn, "thunder"), (meteorBtn, "meteor")
        ]
        for (btn, key) in skillButtons {
            guard let cfg = skillConfigs[key] else { continue }
            if playerLv >= cfg.unlockLevel {
                // 已解锁: 恢复图标和颜色
                btn.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
                btn.setTitle(cfg.icon, for: .normal)
                btn.backgroundColor = cfg.color.withAlphaComponent(0.85)
                btn.layer.borderColor = cfg.color.cgColor
                // CD 状态由 startCooldown / CD timer 控制,仅就绪时恢复
                if isReady(key) {
                    btn.isEnabled = true
                    btn.alpha = 1.0
                }
            } else {
                // 未解锁: 锁图标 + 解锁等级,灰色不可点
                btn.titleLabel?.font = .systemFont(ofSize: 11, weight: .bold)
                btn.setTitle("🔒\(cfg.unlockLevel)", for: .normal)
                btn.backgroundColor = UIColor(hex: 0x3a3a3a).withAlphaComponent(0.85)
                btn.layer.borderColor = UIColor(hex: 0x555555).cgColor
                btn.alpha = 0.5
                btn.isEnabled = false
            }
        }
    }

    // MARK: - 渲染循环
    private func startLoop() {
        let l = CADisplayLink(target: self, selector: #selector(tick))
        l.preferredFramesPerSecond = 60
        l.add(to: .main, forMode: .common)
        displayLink = l
        lastTime = 0
    }
    private func stopLoop() {
        displayLink?.invalidate()
        displayLink = nil
    }
    @objc private func tick() {
        let now = CACurrentMediaTime()
        let dt = lastTime == 0 ? 1/60 : Float(min(now - lastTime, 0.05))
        lastTime = now
        scene.update(deltaTime: dt)
        let pp = scene.playerNode.position
        let monsterData = scene.monsters.map { m -> (x: Float, z: Float, color: UIColor, isBoss: Bool, alive: Bool) in
            (m.node.position.x, m.node.position.z, m.color, m.isBoss, m.alive)
        }
        minimap.update(playerX: pp.x, playerZ: pp.z, monsters: monsterData)
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {}

    // MARK: - 怪物点击 / 视角旋转
    @objc private func sceneTapped(_ g: UITapGestureRecognizer) {
        guard !inBattle, !aoeInProgress else { return }
        let p = g.location(in: scnView)
        if let idx = scene.hitTestMonster(at: p, in: scnView) {
            startBattleWithMonster(idx: idx)
        }
    }

    @objc private func scenePanned(_ g: UIPanGestureRecognizer) {
        guard g.state == .changed || g.state == .began else { return }
        let t = g.translation(in: scnView)
        // 左右滑动: 向右滑(t.x>0)期望视角向右转 → yaw 减小(摄像机向左绕)
        let yaw = -Float(t.x) * 0.005
        // 上下滑动: 向下滑(t.y>0)期望俯视 → pitch 增加
        let pitch = Float(t.y) * 0.004
        scene.orbitCamera(deltaYaw: yaw, deltaPitch: pitch)
        g.setTranslation(.zero, in: scnView)
    }

    @objc private func attackNearest() {
        guard !inBattle, !aoeInProgress else { return }
        SoundManager.shared.play(.button)
        if let idx = nearestAliveMonsterIdx() {
            startBattleWithMonster(idx: idx)
        } else {
            showToast("附近没有怪物", isError: true)
            SoundManager.shared.play(.error)
        }
    }

    // MARK: - 战斗
    private func startBattleWithMonster(idx: Int) {
        guard scene.monsters.indices.contains(idx), scene.monsters[idx].alive else { return }
        inBattle = true
        let m = scene.monsters[idx]

        let handler: (Result<BattleResult, APIError>) -> Void = { [weak self] res in
            guard let self = self else { return }
            switch res {
            case .success(let r):
                self.playBattle(result: r, monsterIdx: idx)
            case .failure(let err):
                self.inBattle = false
                self.showToast(err.errorDescription ?? "战斗失败", isError: true)
                SoundManager.shared.play(.error)
            }
        }
        if isOfflineMode {
            if m.isBoss, let bid = m.bossId {
                LocalGameManager.shared.fightBoss(bossId: bid, completion: handler)
            } else {
                LocalGameManager.shared.fightWild(level: m.level, completion: handler)
            }
        } else if m.isBoss, let bid = m.bossId {
            APIClient.shared.fightBoss(bossId: bid, completion: handler)
        } else {
            APIClient.shared.fightWild(level: m.level, completion: handler)
        }
    }

    private func playBattle(result: BattleResult, monsterIdx: Int) {
        let monsterHp = result.win ? CGFloat(0) : max(0.05, 1 - CGFloat(result.rounds)/10)
        let pAtk = playerInfo?.totalAtk ?? 20
        // 提前缓存怪物位置,防止动画过程中 monsters 数组变化导致越界
        let cachedMonsterPos: SCNVector3 = scene.monsters.indices.contains(monsterIdx)
            ? scene.monsters[monsterIdx].node.position
            : SCNVector3(0, 0, 0)
        scene.playBattleAnimation(monsterIdx: monsterIdx, win: result.win, rounds: result.rounds, monsterHpPct: monsterHp, playerAtk: pAtk) { [weak self] in
            guard let self = self else { return }
            self.inBattle = false
            // 3D 飘字战果(使用缓存位置,不依赖 monsters[idx] 仍有效)
            if result.win {
                let mp = cachedMonsterPos
                self.scene.showFloatText("+\(result.expGain) EXP", color: .gold, at: SCNVector3(mp.x, 3, mp.z))
                if result.goldGain > 0 {
                    self.scene.showFloatText("+\(result.goldGain) 金币", color: .gold, at: SCNVector3(mp.x+1, 2.5, mp.z))
                    SoundManager.shared.play(.coin)
                }
                if result.diamondGain > 0 {
                    self.scene.showFloatText("+\(result.diamondGain) 钻石", color: .diamond, at: SCNVector3(mp.x-1, 2.5, mp.z))
                }
                for lv in result.leveledUp {
                    self.scene.showFloatText("升级 Lv.\(lv)!", color: .myth, at: SCNVector3(mp.x, 4, mp.z))
                    let pp = self.scene.playerNode.position
                    self.scene.spawnLevelUpBurst(at: SCNVector3(pp.x, 1, pp.z))
                    SoundManager.shared.play(.levelup)
                }
                // 左侧小气泡战果
                self.showKillBubble("击杀 \(result.enemyName)  +\(result.expGain)经验", color: .gold, icon: "⚔")
                if result.goldGain > 0 { self.showKillBubble("金币 +\(result.goldGain)", color: .gold, icon: "💰") }
                if !result.drops.isEmpty { self.showKillBubble("掉落 \(result.drops.count) 件", color: .legend, icon: "🎁") }
            } else {
                self.showKillBubble("战斗失利,注意回血", color: .danger, icon: "⚠")
            }
            if let p = result.player { self.applyPlayer(p) }
        }
    }

    // MARK: - 面板
    private func presentPanel(_ vc: UIViewController) {
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
    }

    @objc private func openInventory() {
        guard onlineFeature("背包") else { return }
        SoundManager.shared.play(.button)
        presentPanel(InventoryPanel { [weak self] p in self?.applyPlayer(p) })
    }
    @objc private func openGacha() {
        guard onlineFeature("抽奖") else { return }
        SoundManager.shared.play(.button)
        presentPanel(GachaPanel { [weak self] p in self?.applyPlayer(p) })
    }
    @objc private func openShop() {
        guard onlineFeature("商店") else { return }
        SoundManager.shared.play(.button)
        presentPanel(ShopPanel { [weak self] p in self?.applyPlayer(p) })
    }
    @objc private func openRecharge() {
        guard onlineFeature("充值") else { return }
        SoundManager.shared.play(.button)
        presentPanel(RechargePanel())
    }

    private func onlineFeature(_ name: String) -> Bool {
        if !isOfflineMode { return true }
        showToast("单机模式暂不支持\(name)", isError: true)
        SoundManager.shared.play(.error)
        return false
    }
    @objc private func openCharacter() { SoundManager.shared.play(.button); presentPanel(CharacterPanel(player: playerInfo) { [weak self] p in self?.applyPlayer(p) }) }

    /// BOSS 跳转: 瞬移到场景内 BOSS 旁, 直接打 3D 战斗(有场景)
    @objc private func openBoss() {
        SoundManager.shared.play(.button)
        guard let bossIdx = scene.monsters.firstIndex(where: { $0.isBoss && $0.alive }) else {
            showToast("暂无可挑战的 BOSS", isError: true)
            return
        }
        scene.teleportToMonster(idx: bossIdx)
        showKillBubble("已传送至 BOSS 领地!", color: .legend, icon: "🐲")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startBattleWithMonster(idx: bossIdx)
        }
    }

    // MARK: - 技能(带 CD)
    @objc private func flameSkill() {
        guard !inBattle, !aoeInProgress, isReady("flame") else { return }
        SoundManager.shared.play(.skill)
        guard let idx = nearestAliveMonsterIdx() else { showToast("附近没有怪物", isError: true); return }
        let mp = scene.monsters[idx].node.position
        scene.spawnFlameSkill(at: SCNVector3(mp.x, 1, mp.z))
        startCooldown(btn: flameBtn, key: "flame", duration: RemoteConfig.shared.flameCD)
        showKillBubble("烈焰斩!", color: .epic, icon: "🔥")
        startBattleWithMonster(idx: idx)
    }

    /// 旋风斩 AOE: 真实命中范围内多只怪(顺序结算)
    @objc private func aoeSkill() {
        guard !inBattle, !aoeInProgress, isReady("aoe") else { return }
        let pp = scene.playerNode.position
        let center = SCNVector3(pp.x, 0.5, pp.z)
        // 收集范围内活怪(最多4只)
        let targets = scene.monsters.enumerated().filter { _, m in
            m.alive && !m.isBoss && sqrt(pow(m.node.position.x - pp.x,2) + pow(m.node.position.z - pp.z,2)) < 5
        }.prefix(4).map { $0.offset }
        if targets.isEmpty {
            showToast("附近没有可群攻的怪物", isError: true)
            SoundManager.shared.play(.error)
            return
        }
        SoundManager.shared.play(.skill)
        scene.playAOESkill(centerPos: center)
        startCooldown(btn: aoeBtn, key: "aoe", duration: RemoteConfig.shared.aoeCD)
        showKillBubble("旋风斩! 命中\(targets.count)只", color: .legend, icon: "🌀")
        aoeInProgress = true
        // 玩家原地小跳劈
        scene.playJumpSlash()
        // 顺序结算每只(用 [weak self] 闭包,避免循环引用)
        var remaining = targets
        // 用 var Optional 让闭包能递归引用自身(let 会在声明前被捕获)
        var nextKill: (() -> Void)?
        nextKill = { [weak self] in
            guard let self = self else { return }
            guard !remaining.isEmpty else {
                self.aoeInProgress = false
                return
            }
            let idx = remaining.removeFirst()
            // 二次校验: 怪物仍存活且索引有效
            guard self.scene.monsters.indices.contains(idx), self.scene.monsters[idx].alive else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { nextKill?() }
                return
            }
            self.inBattle = true
            let m = self.scene.monsters[idx]
            let mColor = m.color
            self.fightWildAtIndex(idx, monsterColor: mColor, skillIcon: "🌀") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { nextKill?() }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { nextKill?() }
    }

    @objc private func healSkill() {
        guard isReady("heal") else { return }
        SoundManager.shared.play(.heal)
        let pp = scene.playerNode.position
        scene.spawnHealEffect(at: SCNVector3(pp.x, 0.5, pp.z))
        startCooldown(btn: healBtn, key: "heal", duration: RemoteConfig.shared.healCD)
        showKillBubble("治疗术!", color: UIColor(hex: 0x66bb6a), icon: "✨")
        let healHandler: (Result<PlayerInfo, APIError>) -> Void = { [weak self] res in
            switch res {
            case .success(let p): self?.applyPlayer(p)
            case .failure(let err): self?.showToast(err.errorDescription ?? "失败", isError: true)
            }
        }
        if isOfflineMode {
            LocalGameManager.shared.heal(completion: healHandler)
        } else {
            APIClient.shared.heal(completion: healHandler)
        }
    }

    // MARK: - 新增技能(冰封术/雷霆术/陨石术)

    /// 冰封术(5级解锁, 法术攻击, 伤害=攻击力*2.5, CD 10s)
    @objc private func iceSkill() {
        guard !inBattle, !aoeInProgress, isReady("ice"), isSkillUnlocked("ice") else { return }
        guard let idx = nearestAliveMonsterIdx() else {
            showToast("附近没有怪物", isError: true)
            SoundManager.shared.play(.error)
            return
        }
        SoundManager.shared.play(.skill)
        let mp = scene.monsters[idx].node.position
        scene.spawnIceSkill(at: SCNVector3(mp.x, 1, mp.z))
        // 本地伤害数字(攻击力 * 2.5)
        let atk = playerInfo?.totalAtk ?? 20
        let dmg = Int(Double(atk) * 2.5)
        scene.showDamageNumber("\(dmg)", color: UIColor(hex: 0x42a5f5), at: SCNVector3(mp.x, 2, mp.z), scale: 1.4)
        startCooldown(btn: iceBtn, key: "ice", duration: RemoteConfig.shared.iceCD)
        showKillBubble("冰封术!", color: UIColor(hex: 0x42a5f5), icon: "❄️")
        startBattleWithMonster(idx: idx)
    }

    /// 雷霆术(10级解锁, 法术攻击, 伤害=攻击力*3.5, CD 15s)
    @objc private func thunderSkill() {
        guard !inBattle, !aoeInProgress, isReady("thunder"), isSkillUnlocked("thunder") else { return }
        guard let idx = nearestAliveMonsterIdx() else {
            showToast("附近没有怪物", isError: true)
            SoundManager.shared.play(.error)
            return
        }
        SoundManager.shared.play(.skill)
        let mp = scene.monsters[idx].node.position
        scene.spawnThunderSkill(at: SCNVector3(mp.x, 1, mp.z))
        // 本地伤害数字(攻击力 * 3.5)
        let atk = playerInfo?.totalAtk ?? 20
        let dmg = Int(Double(atk) * 3.5)
        scene.showDamageNumber("\(dmg)", color: UIColor(hex: 0xffeb3b), at: SCNVector3(mp.x, 2, mp.z), scale: 1.5)
        startCooldown(btn: thunderBtn, key: "thunder", duration: RemoteConfig.shared.thunderCD)
        showKillBubble("雷霆术!", color: UIColor(hex: 0xffeb3b), icon: "⚡")
        startBattleWithMonster(idx: idx)
    }

    /// 陨石术(15级解锁, 法术攻击 AOE, 伤害=攻击力*5, CD 20s)
    @objc private func meteorSkill() {
        guard !inBattle, !aoeInProgress, isReady("meteor"), isSkillUnlocked("meteor") else { return }
        let pp = scene.playerNode.position
        let center = SCNVector3(pp.x, 0.5, pp.z)
        // 陨石术是 AOE,收集范围内怪物(最多5只)
        let targets = scene.monsters.enumerated().filter { _, m in
            m.alive && !m.isBoss && sqrt(pow(m.node.position.x - pp.x,2) + pow(m.node.position.z - pp.z,2)) < 6
        }.prefix(5).map { $0.offset }
        if targets.isEmpty {
            showToast("附近没有可群攻的怪物", isError: true)
            SoundManager.shared.play(.error)
            return
        }
        SoundManager.shared.play(.skill)
        scene.spawnMeteorSkill(at: center)
        // 本地伤害数字(攻击力 * 5)
        let atk = playerInfo?.totalAtk ?? 20
        let dmg = Int(Double(atk) * 5)
        for idx in targets {
            let mp = scene.monsters[idx].node.position
            scene.showDamageNumber("\(dmg)", color: UIColor(hex: 0xff5722), at: SCNVector3(mp.x, 2, mp.z), scale: 1.6)
        }
        startCooldown(btn: meteorBtn, key: "meteor", duration: RemoteConfig.shared.meteorCD)
        showKillBubble("陨石术! 命中\(targets.count)只", color: UIColor(hex: 0xff5722), icon: "☄️")
        aoeInProgress = true
        // 顺序结算每只(复用 AOE 的逐只结算模式)
        settleAOEKills(targets: targets, skillIcon: "☄️") { [weak self] in
            self?.aoeInProgress = false
        }
    }

    /// AOE 技能顺序结算多只怪物(陨石术/旋风斩复用)
    private func settleAOEKills(targets: [Int], skillIcon: String, completion: @escaping () -> Void) {
        var remaining = targets
        // 用 var Optional 让闭包能递归引用自身
        var nextKill: (() -> Void)?
        nextKill = { [weak self] in
            guard let self = self else { return }
            guard !remaining.isEmpty else {
                completion()
                return
            }
            let idx = remaining.removeFirst()
            // 二次校验: 怪物仍存活且索引有效
            guard self.scene.monsters.indices.contains(idx), self.scene.monsters[idx].alive else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { nextKill?() }
                return
            }
            self.inBattle = true
            let m = self.scene.monsters[idx]
            let mColor = m.color
            self.fightWildAtIndex(idx, monsterColor: mColor, skillIcon: skillIcon) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { nextKill?() }
            }
        }
        // 等陨石落地爆炸后再开始结算
        let delay = skillIcon == "☄️" ? 0.6 : 0.4
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { nextKill?() }
    }

    /// AOE 逐只结算(兼容单机/在线)
    private func fightWildAtIndex(_ idx: Int, monsterColor: UIColor, skillIcon: String, completion: @escaping () -> Void) {
        guard scene.monsters.indices.contains(idx) else {
            inBattle = false
            completion()
            return
        }
        let m = scene.monsters[idx]
        let handler: (Result<BattleResult, APIError>) -> Void = { [weak self] res in
            guard let self = self else { return }
            switch res {
            case .success(let r):
                guard self.scene.monsters.indices.contains(idx) else {
                    self.inBattle = false
                    completion()
                    return
                }
                let mp = self.scene.monsters[idx].node.position
                if r.win {
                    self.scene.showFloatText("\(r.expGain)EXP", color: .gold, at: SCNVector3(mp.x, 2.6, mp.z))
                    self.scene.setMonsterHp(idx: idx, pct: 0)
                    self.scene.spawnDeathBurst(at: SCNVector3(mp.x, 1.4, mp.z), color: monsterColor)
                    self.scene.monsters[idx].node.runAction(SCNAction.sequence([
                        SCNAction.rotateTo(x: CGFloat.pi/2, y: 0, z: 0, duration: 0.25),
                        SCNAction.fadeOut(duration: 0.3),
                        SCNAction.run { $0.isHidden = true },
                    ]))
                    self.scene.setMonsterAlive(idx: idx, alive: false)
                    let respawnDelay = RemoteConfig.shared.monsterRespawnDelay
                    DispatchQueue.main.asyncAfter(deadline: .now() + respawnDelay) { [weak self] in
                        guard let self = self, self.scene.monsters.indices.contains(idx) else { return }
                        self.scene.respawnPublic(idx: idx)
                    }
                    self.showKillBubble("击杀 \(r.enemyName)", color: .gold, icon: skillIcon)
                }
                if let p = r.player { self.applyPlayer(p) }
            case .failure(_):
                break
            }
            self.inBattle = false
            completion()
        }
        if isOfflineMode {
            LocalGameManager.shared.fightWild(level: m.level, completion: handler)
        } else {
            APIClient.shared.fightWild(level: m.level, completion: handler)
        }
    }

    private func isReady(_ key: String) -> Bool {
        if let t = cooldowns[key], t > Date().timeIntervalSince1970 { return false }
        return true
    }

    private func startCooldown(btn: UIButton, key: String, duration: TimeInterval) {
        cooldowns[key] = Date().timeIntervalSince1970 + duration
        btn.isEnabled = false
        btn.alpha = 0.4
        let t = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            btn.isEnabled = true
            btn.alpha = 1
            self?.cooldowns.removeValue(forKey: key)
            self?.cooldownTimers.removeValue(forKey: key)
        }
        cooldownTimers[key] = t
    }

    // MARK: - 自动战斗(会用技能)
    @objc private func toggleAutoBattle() {
        autoBattle.toggle()
        SoundManager.shared.play(.button)
        if autoBattle {
            autoBtn.backgroundColor = UIColor.danger.withAlphaComponent(0.8)
            autoBtn.layer.borderColor = UIColor.danger.cgColor
            showKillBubble("自动挂机: 开启", color: .danger, icon: "▶")
            startAutoBattle()
        } else {
            autoBtn.backgroundColor = UIColor(hex: 0x2a3040)
            autoBtn.layer.borderColor = UIColor(hex: 0x4a5568).cgColor
            showKillBubble("自动挂机: 关闭", color: .common, icon: "■")
            autoTimer?.invalidate()
            autoTimer = nil
        }
    }

    private func startAutoBattle() {
        autoTimer?.invalidate()
        let interval = RemoteConfig.shared.autoBattleInterval
        autoTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self, self.autoBattle, !self.inBattle, !self.aoeInProgress else { return }
            // 云端开关:若 GM 关闭了自动挂机,直接停止
            if !RemoteConfig.shared.autoBattleEnabled {
                self.autoBattle = false
                self.autoTimer?.invalidate()
                self.autoTimer = nil
                self.autoBtn.backgroundColor = UIColor(hex: 0x2a3040)
                self.autoBtn.layer.borderColor = UIColor(hex: 0x4a5568).cgColor
                self.showKillBubble("自动挂机已被 GM 关闭", color: .common, icon: "■")
                return
            }
            // 附近怪数量
            let pp = self.scene.playerNode.position
            let nearCount = self.scene.monsters.filter { m in
                m.alive && sqrt(pow(m.node.position.x - pp.x,2) + pow(m.node.position.z - pp.z,2)) < 5
            }.count
            // 优先陨石术(多怪且就绪且解锁)
            if nearCount >= 3 && self.isReady("meteor") && self.isSkillUnlocked("meteor") {
                self.meteorSkill(); return
            }
            // 其次 AOE(多怪且就绪)
            if nearCount >= 2 && self.isReady("aoe") {
                self.aoeSkill(); return
            }
            // 雷霆术(单体高伤,就绪且解锁)
            if self.isReady("thunder") && self.isSkillUnlocked("thunder"), self.nearestAliveMonsterIdx() != nil {
                self.thunderSkill(); return
            }
            // 冰封术(就绪且解锁)
            if self.isReady("ice") && self.isSkillUnlocked("ice"), self.nearestAliveMonsterIdx() != nil {
                self.iceSkill(); return
            }
            // 其次烈焰
            if self.isReady("flame"), self.nearestAliveMonsterIdx() != nil {
                self.flameSkill(); return
            }
            // 普攻
            if let idx = self.nearestAliveMonsterIdx() {
                self.startBattleWithMonster(idx: idx)
            }
            // 血量低自动治疗
            if let p = self.playerInfo, p.totalHp > 0, p.curHp * 3 < p.totalHp, self.isReady("heal") {
                self.healSkill()
            }
        }
    }

    private func nearestAliveMonsterIdx() -> Int? {
        let playerPos = scene.playerNode.position
        var bestIdx: Int? = nil
        var bestDist: Float = .infinity
        for (i, m) in scene.monsters.enumerated() where m.alive {
            let dx = m.node.position.x - playerPos.x
            let dz = m.node.position.z - playerPos.z
            let d = sqrt(dx*dx + dz*dz)
            if d < bestDist { bestDist = d; bestIdx = i }
        }
        return bestIdx
    }

    @objc private func doLogout() {
        if isOfflineMode {
            let alert = UIAlertController(title: "返回主菜单", message: "确认返回主菜单?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "取消", style: .cancel))
            alert.addAction(UIAlertAction(title: "返回", style: .default) { _ in
                self.dismiss(animated: true)
            })
            present(alert, animated: true)
            return
        }
        let alert = UIAlertController(title: "退出登录", message: "确认退出当前账号?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "退出", style: .destructive) { _ in
            APIClient.shared.logout()
            self.dismiss(animated: true) {
                (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
                    .windows.first?.rootViewController = AuthViewController()
            }
        })
        present(alert, animated: true)
    }

    // MARK: - Toast
    func showToast(_ msg: String, isError: Bool = false) {
        guard let window = view.window else { return }
        let t = UILabel.make(msg, font: .systemFont(ofSize: 14, weight: .medium), color: .white, alignment: .center)
        t.backgroundColor = isError ? UIColor.danger : UIColor.primary
        t.layer.cornerRadius = 8
        t.layer.masksToBounds = true
        t.textAlignment = .center
        t.alpha = 0
        t.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(t)
        NSLayoutConstraint.activate([
            t.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            t.bottomAnchor.constraint(equalTo: window.bottomAnchor, constant: -80),
            t.heightAnchor.constraint(equalToConstant: 36),
            t.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
        ])
        UIView.animate(withDuration: 0.2) { t.alpha = 1 } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 1.4, options: []) { t.alpha = 0 } completion: { _ in
                t.removeFromSuperview()
            }
        }
    }
}

// MARK: - 手势并存
extension GameViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ g1: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith g2: UIGestureRecognizer) -> Bool {
        return true
    }
}
