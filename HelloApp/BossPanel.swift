import UIKit

/// BOSS 挑战面板
final class BossPanel: BasePanel, UICollectionViewDataSource, UICollectionViewDelegate {

    private var bosses: [BossInfo] = []
    private var collectionView: UICollectionView!
    private let onBattle: (BattleResult) -> Void

    init(onBattle: @escaping (BattleResult) -> Void) {
        self.onBattle = onBattle
        super.init(title: "BOSS 挑战")
    }
    required init?(coder: NSCoder) { fatalError() }

    override func setupContent() {
        super.setupContent()
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 220, height: 150)
        layout.minimumLineSpacing = 12
        layout.minimumInteritemSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(BossCell.self, forCellWithReuseIdentifier: BossCell.id)
        cardView.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: contentTopAnchor, constant: 14),
            collectionView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            collectionView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            collectionView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14),
        ])
        loadBosses()
    }

    private func loadBosses() {
        APIClient.shared.getBossList { [weak self] res in
            if case .success(let list) = res {
                self?.bosses = list
                self?.collectionView.reloadData()
            } else if case .failure(let e) = res {
                self?.toast(e.errorDescription ?? "加载失败", isError: true)
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { bosses.count }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let c = collectionView.dequeueReusableCell(withReuseIdentifier: BossCell.id, for: indexPath) as! BossCell
        c.configure(boss: bosses[indexPath.item])
        return c
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let boss = bosses[indexPath.item]
        fightBoss(boss)
    }

    private func fightBoss(_ boss: BossInfo) {
        let alert = UIAlertController(title: "挑战 \(boss.name)", message: "Lv.\(boss.level) | HP \(boss.hp.shortString)\n攻 \(boss.atk) 防 \(boss.df)\n\n奖励: \(boss.expReward) 经验 / \(boss.goldReward) 金币\(boss.diamondReward > 0 ? " / \(boss.diamondReward) 钻石" : "")", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "挑战!", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            let loading = self.showLoading("战斗中...")
            APIClient.shared.fightBoss(bossId: boss.id) { res in
                self.hideLoading(loading)
                switch res {
                case .success(let r): self.onBattle(r)
                case .failure(let e): self.toast(e.errorDescription ?? "失败", isError: true)
                }
            }
        })
        present(alert, animated: true)
    }
}

final class BossCell: UICollectionViewCell {
    static let id = "BossCell"
    private let iconLabel = UILabel.make("", font: .systemFont(ofSize: 44), color: .white, alignment: .center)
    private let nameLabel = UILabel.make("", font: .systemFont(ofSize: 15, weight: .bold), color: .white)
    private let lvlLabel = UILabel.make("", font: .systemFont(ofSize: 11, weight: .bold), color: .gold)
    private let statsLabel = UILabel.make("", font: .systemFont(ofSize: 10), color: UIColor(hex: 0xcfd8e3))
    private let tierBadge = UILabel.make("", font: .systemFont(ofSize: 9, weight: .bold), color: .white, alignment: .center)

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = UIColor(hex: 0x1a2030)
        contentView.layer.cornerRadius = 12
        contentView.layer.borderWidth = 1
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        lvlLabel.translatesAutoresizingMaskIntoConstraints = false
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        tierBadge.translatesAutoresizingMaskIntoConstraints = false
        tierBadge.backgroundColor = .legend
        tierBadge.layer.cornerRadius = 4
        contentView.addSubview(tierBadge)
        contentView.addSubview(iconLabel)
        contentView.addSubview(nameLabel)
        contentView.addSubview(lvlLabel)
        contentView.addSubview(statsLabel)
        NSLayoutConstraint.activate([
            iconLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            iconLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            iconLabel.widthAnchor.constraint(equalToConstant: 56),
            iconLabel.heightAnchor.constraint(equalToConstant: 56),
            nameLabel.topAnchor.constraint(equalTo: iconLabel.topAnchor, constant: 6),
            nameLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            lvlLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            lvlLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            statsLabel.topAnchor.constraint(equalTo: lvlLabel.bottomAnchor, constant: 4),
            statsLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            statsLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            tierBadge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            tierBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            tierBadge.widthAnchor.constraint(equalToConstant: 36),
            tierBadge.heightAnchor.constraint(equalToConstant: 16),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(boss: BossInfo) {
        let icon: String
        switch boss.tier {
        case 1: icon = "👹"; tierBadge.backgroundColor = UIColor(hex: 0x8bc34a)
        case 2: icon = "👺"; tierBadge.backgroundColor = UIColor(hex: 0xff7043)
        case 3: icon = "🐉"; tierBadge.backgroundColor = UIColor(hex: 0x5c6bc0)
        case 4: icon = "👿"; tierBadge.backgroundColor = UIColor(hex: 0xab47bc)
        default: icon = "☠️"; tierBadge.backgroundColor = UIColor(hex: 0xffd54f)
        }
        iconLabel.text = icon
        nameLabel.text = boss.name
        lvlLabel.text = "Lv.\(boss.level)"
        statsLabel.text = "血 \(boss.hp.shortString) · 攻 \(boss.atk) · 防 \(boss.df)"
        tierBadge.text = "T\(boss.tier)"
        let c = UIColor(hexString: boss.color) ?? UIColor(hex: 0xff5555)
        contentView.layer.borderColor = c.withAlphaComponent(0.6).cgColor
        contentView.makeGlow(c, radius: 8, opacity: 0.4)
    }
}

extension UIColor {
    /// 从 "#aabbcc" 字符串解析颜色
    convenience init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(hex: v)
    }
}
