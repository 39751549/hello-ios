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
    private let autoBtn = UIButton(type: .system)
    private let minimap = MinimapView()
    private let menuStack = UIStackView()
    private let logoutBtn = UIButton(type: .system)
    private let battleHintLabel = UILabel.make("", font: .systemFont(ofSize: 14, weight: .bold), color: .white, alignment: .center)
    private var displayLink: CADisplayLink?
    private var lastTime: CFTimeInterval = 0
    private var inBattle = false
    private var playerInfo: PlayerInfo?
    private var autoBattle = false
    private var autoTimer: Timer?
    private var flameCooldown = false
    private var healCooldown = false
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
        // 高质量渲染
        if #available(iOS 13.0, *) {
            scnView.contentMode = .scaleAspectFill
        }
        view.addSubview(scnView)

        let tap = UITapGestureRecognizer(target: self, action: #selector(sceneTapped(_:)))
        scnView.addGestureRecognizer(tap)

        NSLayoutConstraint.activate([
            scnView.topAnchor.constraint(equalTo: view.topAnchor),
            scnView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scnView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scnView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    // MARK: - HUD
    private func setupHUD() {
        hudView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hudView)
        hudView.onHeal = { [weak self] in self?.doHeal() }

        NSLayoutConstraint.activate([
            hudView.topAnchor.constraint(equalTo: view.topAnchor, constant: 56),
            hudView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            hudView.widthAnchor.constraint(equalToConstant: 330),
            hudView.heightAnchor.constraint(equalToConstant: 52),
        ])

        battleHintLabel.translatesAutoresizingMaskIntoConstraints = false
        battleHintLabel.backgroundColor = UIColor.bgDark.withAlphaComponent(0.8)
        battleHintLabel.layer.cornerRadius = 8
        battleHintLabel.layer.masksToBounds = true
        battleHintLabel.isHidden = true
        battleHintLabel.alpha = 0
        battleHintLabel.textAlignment = .center
        view.addSubview(battleHintLabel)
        NSLayoutConstraint.activate([
            battleHintLabel.topAnchor.constraint(equalTo: hudView.bottomAnchor, constant: 8),
            battleHintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            battleHintLabel.heightAnchor.constraint(equalToConstant: 28),
            battleHintLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
        ])

        // 小地图(右上角,避开灵动岛区域,下移)
        minimap.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(minimap)
        NSLayoutConstraint.activate([
            minimap.topAnchor.constraint(equalTo: view.topAnchor, constant: 56),
            minimap.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            minimap.widthAnchor.constraint(equalToConstant: 92),
            minimap.heightAnchor.constraint(equalToConstant: 92),
        ])
    }

    // MARK: - 摇杆/攻击按钮/技能按钮
    private func setupControls() {
        joystick.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(joystick)
        joystick.onChange = { [weak self] x, y in
            self?.scene.setMoveVector(SIMD2<Float>(Float(x), Float(y)))
        }
        NSLayoutConstraint.activate([
            joystick.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            joystick.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -24),
            joystick.widthAnchor.constraint(equalToConstant: 130),
            joystick.heightAnchor.constraint(equalToConstant: 130),
        ])

        // 普攻按钮
        attackBtn.translatesAutoresizingMaskIntoConstraints = false
        attackBtn.setTitle("⚔", for: .normal)
        attackBtn.titleLabel?.font = .systemFont(ofSize: 32, weight: .bold)
        attackBtn.setTitleColor(.white, for: .normal)
        attackBtn.backgroundColor = UIColor.danger.withAlphaComponent(0.85)
        attackBtn.layer.cornerRadius = 38
        attackBtn.layer.borderColor = UIColor.danger.cgColor
        attackBtn.layer.borderWidth = 2
        attackBtn.makeGlow(.danger, radius: 12, opacity: 0.6)
        attackBtn.addTarget(self, action: #selector(attackNearest), for: .touchUpInside)
        view.addSubview(attackBtn)

        // 烈焰斩技能
        flameBtn.translatesAutoresizingMaskIntoConstraints = false
        flameBtn.setTitle("🔥", for: .normal)
        flameBtn.titleLabel?.font = .systemFont(ofSize: 26, weight: .bold)
        flameBtn.setTitleColor(.white, for: .normal)
        flameBtn.backgroundColor = UIColor.epic.withAlphaComponent(0.85)
        flameBtn.layer.cornerRadius = 32
        flameBtn.layer.borderColor = UIColor.epic.cgColor
        flameBtn.layer.borderWidth = 2
        flameBtn.makeGlow(.epic, radius: 10, opacity: 0.5)
        flameBtn.addTarget(self, action: #selector(flameSkill), for: .touchUpInside)
        view.addSubview(flameBtn)

        // 治疗术技能
        healBtn.translatesAutoresizingMaskIntoConstraints = false
        healBtn.setTitle("✨", for: .normal)
        healBtn.titleLabel?.font = .systemFont(ofSize: 26, weight: .bold)
        healBtn.setTitleColor(.white, for: .normal)
        healBtn.backgroundColor = UIColor(hex: 0x66bb6a).withAlphaComponent(0.85)
        healBtn.layer.cornerRadius = 32
        healBtn.layer.borderColor = UIColor(hex: 0x66bb6a).cgColor
        healBtn.layer.borderWidth = 2
        healBtn.makeGlow(UIColor(hex: 0x66bb6a), radius: 10, opacity: 0.5)
        healBtn.addTarget(self, action: #selector(healSkill), for: .touchUpInside)
        view.addSubview(healBtn)

        // 自动战斗开关
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

        NSLayoutConstraint.activate([
            attackBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            attackBtn.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -28),
            attackBtn.widthAnchor.constraint(equalToConstant: 76),
            attackBtn.heightAnchor.constraint(equalToConstant: 76),
            flameBtn.trailingAnchor.constraint(equalTo: attackBtn.leadingAnchor, constant: -14),
            flameBtn.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -40),
            flameBtn.widthAnchor.constraint(equalToConstant: 64),
            flameBtn.heightAnchor.constraint(equalToConstant: 64),
            healBtn.trailingAnchor.constraint(equalTo: flameBtn.leadingAnchor, constant: -14),
            healBtn.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -40),
            healBtn.widthAnchor.constraint(equalToConstant: 64),
            healBtn.heightAnchor.constraint(equalToConstant: 64),
            autoBtn.trailingAnchor.constraint(equalTo: healBtn.leadingAnchor, constant: -14),
            autoBtn.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -48),
            autoBtn.widthAnchor.constraint(equalToConstant: 60),
            autoBtn.heightAnchor.constraint(equalToConstant: 32),
        ])
    }

    // MARK: - 顶部菜单栏(横排,避开灵动岛)
    private func setupMenu() {
        let items: [(String, String, UIColor, Selector)] = [
            ("👤", "角色", .diamond, #selector(openCharacter)),
            ("🎒", "背包", .primary, #selector(openInventory)),
            ("🎁", "抽奖", .accent, #selector(openGacha)),
            ("🛒", "商店", .epic, #selector(openShop)),
            ("🐲", "BOSS", .legend, #selector(openBoss)),
            ("💎", "充值", .diamond, #selector(openRecharge)),
        ]
        menuStack.translatesAutoresizingMaskIntoConstraints = false
        menuStack.axis = .horizontal
        menuStack.spacing = 8
        menuStack.alignment = .center
        view.addSubview(menuStack)

        for (icon, label, color, sel) in items {
            let b = makeMenuButton(icon: icon, label: label, color: color)
            b.addTarget(self, action: sel, for: .touchUpInside)
            menuStack.addArrangedSubview(b)
        }

        // 退出按钮(放在菜单末尾)
        logoutBtn.translatesAutoresizingMaskIntoConstraints = false
        logoutBtn.setTitle("退出", for: .normal)
        logoutBtn.titleLabel?.font = .systemFont(ofSize: 10, weight: .medium)
        logoutBtn.setTitleColor(UIColor(hex: 0x8b9bb4), for: .normal)
        logoutBtn.addTarget(self, action: #selector(doLogout), for: .touchUpInside)
        view.addSubview(logoutBtn)

        NSLayoutConstraint.activate([
            menuStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            menuStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            menuStack.heightAnchor.constraint(equalToConstant: 42),
            logoutBtn.centerYAnchor.constraint(equalTo: menuStack.centerYAnchor),
            logoutBtn.leadingAnchor.constraint(equalTo: menuStack.trailingAnchor, constant: 10),
        ])
    }

    private func makeMenuButton(icon: String, label: String, color: UIColor) -> UIButton {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 1
        stack.alignment = .center
        let iconL = UILabel.make(icon, font: .systemFont(ofSize: 16), color: .white, alignment: .center)
        let labelL = UILabel.make(label, font: .systemFont(ofSize: 9, weight: .semibold), color: .white, alignment: .center)
        stack.addArrangedSubview(iconL)
        stack.addArrangedSubview(labelL)
        b.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: b.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: b.centerYAnchor),
            b.widthAnchor.constraint(equalToConstant: 54),
            b.heightAnchor.constraint(equalToConstant: 40),
        ])
        b.backgroundColor = color.withAlphaComponent(0.82)
        b.layer.cornerRadius = 9
        b.layer.borderColor = color.cgColor
        b.layer.borderWidth = 1
        b.makeGlow(color, radius: 6, opacity: 0.4)
        return b
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
        // 更新小地图
        let pp = scene.playerNode.position
        let monsterData = scene.monsters.map { m -> (x: Float, z: Float, color: UIColor, isBoss: Bool, alive: Bool) in
            (m.node.position.x, m.node.position.z, m.color, m.isBoss, m.alive)
        }
        minimap.update(playerX: pp.x, playerZ: pp.z, monsters: monsterData)
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // CADisplayLink 已处理
    }

    // MARK: - 怪物点击
    @objc private func sceneTapped(_ g: UITapGestureRecognizer) {
        guard !inBattle else { return }
        let p = g.location(in: scnView)
        if let idx = scene.hitTestMonster(at: p, in: scnView) {
            startBattleWithMonster(idx: idx)
        }
    }

    @objc private func attackNearest() {
        guard !inBattle else { return }
        if let idx = nearestAliveMonsterIdx() {
            startBattleWithMonster(idx: idx)
        } else {
            showToast("附近没有怪物", isError: true)
        }
    }

    // MARK: - 战斗
    private func startBattleWithMonster(idx: Int) {
        guard scene.monsters.indices.contains(idx), scene.monsters[idx].alive else { return }
        inBattle = true
        let m = scene.monsters[idx]
        showBattleHint("战斗中: \(m.name) Lv.\(m.level)")

        let handler: (Result<BattleResult, APIError>) -> Void = { [weak self] res in
            guard let self = self else { return }
            self.hideBattleHint()
            switch res {
            case .success(let r):
                self.playBattle(result: r, monsterIdx: idx)
            case .failure(let err):
                self.inBattle = false
                self.showToast(err.errorDescription ?? "战斗失败", isError: true)
            }
        }
        if m.isBoss, let bid = m.bossId {
            APIClient.shared.fightBoss(bossId: bid, completion: handler)
        } else {
            APIClient.shared.fightWild(level: m.level, completion: handler)
        }
    }

    private func playBattle(result: BattleResult, monsterIdx: Int) {
        // 模拟玩家剩余血量百分比
        let php = (playerInfo?.totalHp ?? 1) > 0 ? result.hpLeft / (playerInfo?.totalHp ?? 1) : 0
        let monsterHp = result.win ? CGFloat(0) : max(0.05, 1 - CGFloat(result.rounds)/10)
        let pAtk = playerInfo?.totalAtk ?? 20
        scene.playBattleAnimation(monsterIdx: monsterIdx, win: result.win, rounds: result.rounds, monsterHpPct: monsterHp, playerAtk: pAtk) { [weak self] in
            guard let self = self else { return }
            self.inBattle = false
            // 飘字
            if result.win {
                let mp = self.scene.monsters[monsterIdx].node.position
                self.scene.showFloatText("+\(result.expGain) EXP", color: .gold, at: SCNVector3(mp.x, 3, mp.z))
                if result.goldGain > 0 {
                    self.scene.showFloatText("+\(result.goldGain) 金币", color: .gold, at: SCNVector3(mp.x+1, 2.5, mp.z))
                }
                if result.diamondGain > 0 {
                    self.scene.showFloatText("+\(result.diamondGain) 钻石", color: .diamond, at: SCNVector3(mp.x-1, 2.5, mp.z))
                }
                for lv in result.leveledUp {
                    self.scene.showFloatText("升级 Lv.\(lv)!", color: .myth, at: SCNVector3(mp.x, 4, mp.z))
                    // 升级金光粒子(在玩家位置)
                    let pp = self.scene.playerNode.position
                    self.scene.spawnLevelUpBurst(at: SCNVector3(pp.x, 1, pp.z))
                }
            }
            // 更新玩家信息
            if let p = result.player { self.applyPlayer(p) }
            // 战斗结果面板
            let panel = BattleResultView(result: result, onClose: { })
            self.presentPanel(panel)
        }
    }

    private func showBattleHint(_ text: String) {
        battleHintLabel.text = "  " + text + "  "
        battleHintLabel.isHidden = false
        UIView.animate(withDuration: 0.2) { self.battleHintLabel.alpha = 1 }
    }
    private func hideBattleHint() {
        UIView.animate(withDuration: 0.2, animations: { self.battleHintLabel.alpha = 0 }) { _ in
            self.battleHintLabel.isHidden = true
        }
    }

    // MARK: - 回血
    private func doHeal() {
        APIClient.shared.heal { [weak self] res in
            switch res {
            case .success(let p): self?.applyPlayer(p); self?.showToast("已回满血")
            case .failure(let err): self?.showToast(err.errorDescription ?? "失败", isError: true)
            }
        }
    }

    // MARK: - 面板
    private func presentPanel(_ vc: UIViewController) {
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
    }

    @objc private func openInventory() { presentPanel(InventoryPanel { [weak self] p in self?.applyPlayer(p) }) }
    @objc private func openGacha()    { presentPanel(GachaPanel { [weak self] p in self?.applyPlayer(p) }) }
    @objc private func openShop()     { presentPanel(ShopPanel { [weak self] p in self?.applyPlayer(p) }) }
    @objc private func openBoss()     { presentPanel(BossPanel { [weak self] result in
        self?.dismiss(animated: true) {
            // 显示 boss 战斗结果
            self?.presentPanel(BattleResultView(result: result, onClose: {}))
            if let p = result.player { self?.applyPlayer(p) }
        }
    }) }
    @objc private func openRecharge() { presentPanel(RechargePanel()) }
    @objc private func openCharacter() { presentPanel(CharacterPanel(player: playerInfo) { [weak self] p in self?.applyPlayer(p) }) }

    // MARK: - 技能
    @objc private func flameSkill() {
        guard !inBattle, !flameCooldown else { return }
        // 找最近怪
        guard let idx = nearestAliveMonsterIdx() else { showToast("附近没有怪物", isError: true); return }
        // 烈焰特效(在怪物位置)
        let mp = scene.monsters[idx].node.position
        scene.spawnFlameSkill(at: SCNVector3(mp.x, 1, mp.z))
        startCooldown(btn: flameBtn, key: "flame", duration: 8)
        startBattleWithMonster(idx: idx)
    }

    @objc private func healSkill() {
        guard !healCooldown else { return }
        let pp = scene.playerNode.position
        scene.spawnHealEffect(at: SCNVector3(pp.x, 0.5, pp.z))
        startCooldown(btn: healBtn, key: "heal", duration: 15)
        APIClient.shared.heal { [weak self] res in
            switch res {
            case .success(let p): self?.applyPlayer(p); self?.showToast("✨ 治疗术!已回满血")
            case .failure(let err): self?.showToast(err.errorDescription ?? "失败", isError: true)
            }
        }
    }

    private func startCooldown(btn: UIButton, key: String, duration: TimeInterval) {
        btn.isEnabled = false
        btn.alpha = 0.4
        if key == "flame" { flameCooldown = true }
        if key == "heal" { healCooldown = true }
        let t = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            btn.isEnabled = true
            btn.alpha = 1
            if key == "flame" { self?.flameCooldown = false }
            if key == "heal" { self?.healCooldown = false }
            self?.cooldownTimers.removeValue(forKey: key)
        }
        cooldownTimers[key] = t
    }

    // MARK: - 自动战斗
    @objc private func toggleAutoBattle() {
        autoBattle.toggle()
        if autoBattle {
            autoBtn.backgroundColor = UIColor.danger.withAlphaComponent(0.8)
            autoBtn.layer.borderColor = UIColor.danger.cgColor
            showToast("自动战斗: 开启")
            startAutoBattle()
        } else {
            autoBtn.backgroundColor = UIColor(hex: 0x2a3040)
            autoBtn.layer.borderColor = UIColor(hex: 0x4a5568).cgColor
            showToast("自动战斗: 关闭")
            autoTimer?.invalidate()
            autoTimer = nil
        }
    }

    private func startAutoBattle() {
        autoTimer?.invalidate()
        autoTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self, self.autoBattle, !self.inBattle else { return }
            if let idx = self.nearestAliveMonsterIdx() {
                self.startBattleWithMonster(idx: idx)
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
