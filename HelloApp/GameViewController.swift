import UIKit
import SceneKit

/// 游戏主界面
final class GameViewController: UIViewController, SCNSceneRendererDelegate {

    private let scnView = SCNView()
    private let scene = GameScene()
    private let hudView = HUDView()
    private let joystick = JoystickView()
    private let attackBtn = UIButton(type: .system)
    private let flameBtn = UIButton(type: .system)
    private let healBtn = UIButton(type: .system)
    private let aoeBtn = UIButton(type: .system)
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

        // 烈焰斩(单体爆发, CD 8s)
        flameBtn.translatesAutoresizingMaskIntoConstraints = false
        flameBtn.setTitle("🔥", for: .normal)
        flameBtn.titleLabel?.font = .systemFont(ofSize: 24, weight: .bold)
        flameBtn.backgroundColor = UIColor.epic.withAlphaComponent(0.85)
        flameBtn.layer.cornerRadius = 30
        flameBtn.layer.borderColor = UIColor.epic.cgColor
        flameBtn.layer.borderWidth = 2
        flameBtn.makeGlow(.epic, radius: 10, opacity: 0.5)
        flameBtn.addTarget(self, action: #selector(flameSkill), for: .touchUpInside)
        view.addSubview(flameBtn)

        // 旋风斩(AOE 群攻, CD 10s)
        aoeBtn.translatesAutoresizingMaskIntoConstraints = false
        aoeBtn.setTitle("🌀", for: .normal)
        aoeBtn.titleLabel?.font = .systemFont(ofSize: 24, weight: .bold)
        aoeBtn.backgroundColor = UIColor.legend.withAlphaComponent(0.85)
        aoeBtn.layer.cornerRadius = 30
        aoeBtn.layer.borderColor = UIColor.legend.cgColor
        aoeBtn.layer.borderWidth = 2
        aoeBtn.makeGlow(.legend, radius: 10, opacity: 0.5)
        aoeBtn.addTarget(self, action: #selector(aoeSkill), for: .touchUpInside)
        view.addSubview(aoeBtn)

        // 治疗术(CD 15s)
        healBtn.translatesAutoresizingMaskIntoConstraints = false
        healBtn.setTitle("✨", for: .normal)
        healBtn.titleLabel?.font = .systemFont(ofSize: 24, weight: .bold)
        healBtn.backgroundColor = UIColor(hex: 0x66bb6a).withAlphaComponent(0.85)
        healBtn.layer.cornerRadius = 30
        healBtn.layer.borderColor = UIColor(hex: 0x66bb6a).cgColor
        healBtn.layer.borderWidth = 2
        healBtn.makeGlow(UIColor(hex: 0x66bb6a), radius: 10, opacity: 0.5)
        healBtn.addTarget(self, action: #selector(healSkill), for: .touchUpInside)
        view.addSubview(healBtn)

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
            flameBtn.trailingAnchor.constraint(equalTo: attackBtn.leadingAnchor, constant: -12),
            flameBtn.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -32),
            flameBtn.widthAnchor.constraint(equalToConstant: 60),
            flameBtn.heightAnchor.constraint(equalToConstant: 60),
            aoeBtn.trailingAnchor.constraint(equalTo: flameBtn.leadingAnchor, constant: -12),
            aoeBtn.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -32),
            aoeBtn.widthAnchor.constraint(equalToConstant: 60),
            aoeBtn.heightAnchor.constraint(equalToConstant: 60),
            healBtn.trailingAnchor.constraint(equalTo: aoeBtn.leadingAnchor, constant: -12),
            healBtn.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -32),
            healBtn.widthAnchor.constraint(equalToConstant: 60),
            healBtn.heightAnchor.constraint(equalToConstant: 60),
        ])
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
        let yaw = Float(t.x) * 0.005
        scene.orbitCamera(deltaYaw: yaw)
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
        if m.isBoss, let bid = m.bossId {
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

    @objc private func openInventory() { SoundManager.shared.play(.button); presentPanel(InventoryPanel { [weak self] p in self?.applyPlayer(p) }) }
    @objc private func openGacha()    { SoundManager.shared.play(.button); presentPanel(GachaPanel { [weak self] p in self?.applyPlayer(p) }) }
    @objc private func openShop()     { SoundManager.shared.play(.button); presentPanel(ShopPanel { [weak self] p in self?.applyPlayer(p) }) }
    @objc private func openRecharge() { SoundManager.shared.play(.button); presentPanel(RechargePanel()) }
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
        // 顺序结算每只
        var remaining = targets
        func nextKill() {
            guard let self = self else { return }
            guard !remaining.isEmpty else {
                self.aoeInProgress = false
                return
            }
            let idx = remaining.removeFirst()
            // 二次校验: 怪物仍存活且索引有效
            guard self.scene.monsters.indices.contains(idx), self.scene.monsters[idx].alive else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { nextKill() }
                return
            }
            self.inBattle = true
            let m = self.scene.monsters[idx]
            let mColor = m.color
            APIClient.shared.fightWild(level: m.level) { [weak self] res in
                guard let self = self else { return }
                switch res {
                case .success(let r):
                    guard self.scene.monsters.indices.contains(idx) else {
                        self.inBattle = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { nextKill() }
                        return
                    }
                    let mp = self.scene.monsters[idx].node.position
                    if r.win {
                        self.scene.showFloatText("\(r.expGain)EXP", color: .gold, at: SCNVector3(mp.x, 2.6, mp.z))
                        self.scene.setMonsterHp(idx: idx, pct: 0)
                        self.scene.spawnDeathBurst(at: SCNVector3(mp.x, 1.4, mp.z), color: mColor)
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
                        self.showKillBubble("击杀 \(r.enemyName)", color: .gold, icon: "🌀")
                    }
                    if let p = r.player { self.applyPlayer(p) }
                case .failure(_):
                    break
                }
                self.inBattle = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { nextKill() }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard self != nil else { return }
            nextKill()
        }
    }

    @objc private func healSkill() {
        guard isReady("heal") else { return }
        SoundManager.shared.play(.heal)
        let pp = scene.playerNode.position
        scene.spawnHealEffect(at: SCNVector3(pp.x, 0.5, pp.z))
        startCooldown(btn: healBtn, key: "heal", duration: RemoteConfig.shared.healCD)
        showKillBubble("治疗术!", color: UIColor(hex: 0x66bb6a), icon: "✨")
        APIClient.shared.heal { [weak self] res in
            switch res {
            case .success(let p): self?.applyPlayer(p)
            case .failure(let err): self?.showToast(err.errorDescription ?? "失败", isError: true)
            }
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
            // 优先 AOE(多怪且就绪)
            if nearCount >= 2 && self.isReady("aoe") {
                self.aoeSkill(); return
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
