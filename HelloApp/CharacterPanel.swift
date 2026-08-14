import UIKit

/// 角色/属性面板: 详细属性 + 装备 + 统计
final class CharacterPanel: BasePanel {

    private var player: PlayerInfo?
    private let onPlayerUpdated: (PlayerInfo) -> Void
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    init(player: PlayerInfo?, onUpdate: @escaping (PlayerInfo) -> Void) {
        self.player = player
        self.onPlayerUpdated = onUpdate
        super.init(title: "角色 · 属性")
    }
    required init?(coder: NSCoder) { fatalError() }

    override func setupContent() {
        super.setupContent()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        cardView.addSubview(scrollView)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 14
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentTopAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])

        if player == nil {
            loadMe()
        } else {
            render(player!)
        }
    }

    private func loadMe() {
        let loading = showLoading()
        APIClient.shared.getMe { [weak self] res in
            self?.hideLoading(loading)
            if case .success(let p) = res {
                self?.player = p
                self?.render(p)
            }
        }
    }

    private func render(_ p: PlayerInfo) {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // 头部: 头像 + 名称 + 等级 + VIP
        contentStack.addArrangedSubview(makeHeader(p))

        // 基础属性
        contentStack.addArrangedSubview(makeSection(title: "基础属性", items: [
            ("生命值", "\(p.curHp.shortString) / \(p.totalHp.shortString)", .danger),
            ("攻击力", "\(p.totalAtk)  (基础 \(p.atk))", .gold),
            ("防御力", "\(p.totalDf)  (基础 \(p.df))", .primary),
            ("经验值", "\(p.exp.shortString) / \(p.expNext.shortString)", .accent),
        ]))

        // 装备
        contentStack.addArrangedSubview(makeEquipSection(p))

        // 战斗统计
        contentStack.addArrangedSubview(makeSection(title: "战斗统计", items: [
            ("击杀怪物", "\(p.killCount)", .gold),
            ("击杀BOSS", "\(p.bossKillCount)", .legend),
            ("抽卡次数", "\(p.gachaCount)", .accent),
            ("VIP等级", "V\(p.vip)", .diamond),
        ]))

        // 货币
        contentStack.addArrangedSubview(makeSection(title: "资产", items: [
            ("💰 金币", "\(p.gold.shortString)", .gold),
            ("💎 钻石", "\(p.diamond.shortString)", .diamond),
        ]))
    }

    private func makeHeader(_ p: PlayerInfo) -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor(hex: 0x0f141e).withAlphaComponent(0.6)
        v.layer.cornerRadius = 12
        v.layer.borderColor = UIColor.primary.withAlphaComponent(0.3).cgColor
        v.layer.borderWidth = 1

        let avatar = UIView()
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.backgroundColor = UIColor.primary.withAlphaComponent(0.25)
        avatar.layer.cornerRadius = 28
        avatar.layer.borderColor = UIColor.primary.cgColor
        avatar.layer.borderWidth = 1.5
        avatar.makeGlow(.primary, radius: 10, opacity: 0.4)
        let avatarImg = UIImageView(image: UIImage(systemName: "person.crop.circle.fill"))
        avatarImg.tintColor = .primary
        avatarImg.translatesAutoresizingMaskIntoConstraints = false
        avatar.addSubview(avatarImg)

        let nameL = UILabel.make(p.nickname, font: .systemFont(ofSize: 18, weight: .bold), color: .white)
        nameL.translatesAutoresizingMaskIntoConstraints = false
        let lvlL = UILabel.make("Lv.\(p.level)", font: .systemFont(ofSize: 13, weight: .bold), color: .gold)
        lvlL.translatesAutoresizingMaskIntoConstraints = false
        let vipL = UILabel.make("V\(p.vip)", font: .systemFont(ofSize: 11, weight: .bold), color: .diamond)
        vipL.translatesAutoresizingMaskIntoConstraints = false
        vipL.backgroundColor = UIColor.diamond.withAlphaComponent(0.2)
        vipL.textAlignment = .center
        vipL.layer.cornerRadius = 6
        vipL.layer.masksToBounds = true

        v.addSubview(avatar)
        v.addSubview(nameL)
        v.addSubview(lvlL)
        v.addSubview(vipL)
        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 16),
            avatar.centerYAnchor.constraint(equalTo: v.centerYAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 56),
            avatar.heightAnchor.constraint(equalToConstant: 56),
            avatarImg.centerXAnchor.constraint(equalTo: avatar.centerXAnchor),
            avatarImg.centerYAnchor.constraint(equalTo: avatar.centerYAnchor),
            avatarImg.widthAnchor.constraint(equalTo: avatar.widthAnchor, multiplier: 0.8),
            avatarImg.heightAnchor.constraint(equalTo: avatar.heightAnchor, multiplier: 0.8),
            nameL.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 14),
            nameL.topAnchor.constraint(equalTo: v.topAnchor, constant: 16),
            lvlL.leadingAnchor.constraint(equalTo: nameL.leadingAnchor),
            lvlL.topAnchor.constraint(equalTo: nameL.bottomAnchor, constant: 4),
            vipL.leadingAnchor.constraint(equalTo: lvlL.trailingAnchor, constant: 8),
            vipL.centerYAnchor.constraint(equalTo: lvlL.centerYAnchor),
            vipL.widthAnchor.constraint(equalToConstant: 32),
            vipL.heightAnchor.constraint(equalToConstant: 18),
            v.heightAnchor.constraint(equalToConstant: 80),
        ])
        return v
    }

    private func makeSection(title: String, items: [(String, String, UIColor)]) -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor(hex: 0x0f141e).withAlphaComponent(0.5)
        v.layer.cornerRadius = 10
        v.layer.borderColor = UIColor.primary.withAlphaComponent(0.15).cgColor
        v.layer.borderWidth = 1

        let titleL = UILabel.make(title, font: .systemFont(ofSize: 12, weight: .bold), color: .primary)
        titleL.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(titleL)

        var prev: UIView = titleL
        for (key, val, col) in items {
            let row = makeRow(key: key, value: val, color: col)
            row.translatesAutoresizingMaskIntoConstraints = false
            v.addSubview(row)
            NSLayoutConstraint.activate([
                row.topAnchor.constraint(equalTo: prev.bottomAnchor, constant: prev === titleL ? 8 : 6),
                row.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 14),
                row.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -14),
            ])
            prev = row
        }
        NSLayoutConstraint.activate([
            titleL.topAnchor.constraint(equalTo: v.topAnchor, constant: 10),
            titleL.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 14),
            prev.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -10),
        ])
        return v
    }

    private func makeRow(key: String, value: String, color: UIColor) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        let kl = UILabel.make(key, font: .systemFont(ofSize: 13), color: UIColor(hex: 0xcfd8e3))
        kl.translatesAutoresizingMaskIntoConstraints = false
        let vl = UILabel.make(value, font: .systemFont(ofSize: 13, weight: .semibold), color: color, alignment: .right)
        vl.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(kl)
        row.addSubview(vl)
        NSLayoutConstraint.activate([
            kl.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            kl.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            vl.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            vl.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            vl.leadingAnchor.constraint(greaterThanOrEqualTo: kl.trailingAnchor, constant: 12),
            row.heightAnchor.constraint(equalToConstant: 22),
        ])
        return row
    }

    private func makeEquipSection(_ p: PlayerInfo) -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor(hex: 0x0f141e).withAlphaComponent(0.5)
        v.layer.cornerRadius = 10
        v.layer.borderColor = UIColor.primary.withAlphaComponent(0.15).cgColor
        v.layer.borderWidth = 1

        let titleL = UILabel.make("当前装备", font: .systemFont(ofSize: 12, weight: .bold), color: .primary)
        titleL.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(titleL)

        let slots: [(String, Int?, String)] = [
            ("⚔️ 武器", p.equipWeapon, "weapon"),
            ("🛡️ 防具", p.equipArmor, "armor"),
            ("✨ 皮肤", p.equipSkin, "skin"),
        ]
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 10
        stack.distribution = .fillEqually
        for (icon, itemId, _) in slots {
            let item = p.items.first { $0.item.id == itemId }?.item
            stack.addArrangedSubview(makeEquipSlot(icon: icon, item: item))
        }
        v.addSubview(stack)

        NSLayoutConstraint.activate([
            titleL.topAnchor.constraint(equalTo: v.topAnchor, constant: 10),
            titleL.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 14),
            stack.topAnchor.constraint(equalTo: titleL.bottomAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -10),
            stack.heightAnchor.constraint(equalToConstant: 80),
            stack.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -10),
        ])
        return v
    }

    private func makeEquipSlot(icon: String, item: ItemInfo?) -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor(hex: 0x1a2030)
        v.layer.cornerRadius = 8
        v.layer.borderWidth = 1
        let c = item != nil ? UIColor.rarity(item!.rarity) : UIColor(hex: 0x3a4050)
        v.layer.borderColor = c.withAlphaComponent(0.5).cgColor

        let iconL = UILabel.make(icon, font: .systemFont(ofSize: 24), color: .white, alignment: .center)
        iconL.translatesAutoresizingMaskIntoConstraints = false
        let nameL = UILabel.make(item?.name ?? "未装备", font: .systemFont(ofSize: 10, weight: .medium), color: item != nil ? c : UIColor(hex: 0x6b7a8f), alignment: .center)
        nameL.translatesAutoresizingMaskIntoConstraints = false
        nameL.numberOfLines = 1
        nameL.adjustsFontSizeToFitWidth = true
        v.addSubview(iconL)
        v.addSubview(nameL)
        NSLayoutConstraint.activate([
            iconL.topAnchor.constraint(equalTo: v.topAnchor, constant: 8),
            iconL.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            iconL.heightAnchor.constraint(equalToConstant: 32),
            nameL.topAnchor.constraint(equalTo: iconL.bottomAnchor, constant: 4),
            nameL.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 4),
            nameL.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -4),
        ])
        return v
    }
}
