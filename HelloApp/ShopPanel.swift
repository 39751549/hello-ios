import UIKit

/// 商店面板: 金币/钻石购买物品
final class ShopPanel: BasePanel, UICollectionViewDataSource, UICollectionViewDelegate {

    private var items: [ItemInfo] = []
    private var collectionView: UICollectionView!
    private let onPlayerUpdated: (PlayerInfo) -> Void

    init(onUpdate: @escaping (PlayerInfo) -> Void) {
        self.onPlayerUpdated = onUpdate
        super.init(title: "商店")
    }
    required init?(coder: NSCoder) { fatalError() }

    override func setupContent() {
        super.setupContent()
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 200, height: 92)
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(ShopItemCell.self, forCellWithReuseIdentifier: ShopItemCell.id)
        cardView.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: contentTopAnchor, constant: 14),
            collectionView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            collectionView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            collectionView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14),
        ])
        loadItems()
    }

    private func loadItems() {
        APIClient.shared.getShopItems { [weak self] res in
            if case .success(let items) = res {
                self?.items = items.sorted { $0.rarity > $1.rarity }
                self?.collectionView.reloadData()
            } else if case .failure(let e) = res {
                self?.toast(e.errorDescription ?? "加载失败", isError: true)
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.count }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let c = collectionView.dequeueReusableCell(withReuseIdentifier: ShopItemCell.id, for: indexPath) as! ShopItemCell
        c.configure(item: items[indexPath.item])
        return c
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = items[indexPath.item]
        buyItem(item)
    }

    private func buyItem(_ item: ItemInfo) {
        let currency = item.priceDiamond > 0 ? "钻石" : "金币"
        let price = item.priceDiamond > 0 ? item.priceDiamond : item.priceGold
        let alert = UIAlertController(title: "购买 \(item.name)", message: "单价: \(price) \(currency)\n请输入数量", preferredStyle: .alert)
        alert.addTextField { tf in tf.text = "1"; tf.keyboardType = .numberPad }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "购买", style: .default) { [weak self] _ in
            let cnt = Int(alert.textFields?[0].text ?? "1") ?? 1
            guard cnt >= 1 else { self?.toast("数量无效", isError: true); return }
            let loading = self?.showLoading("购买中...")
            APIClient.shared.buy(itemId: item.id, count: cnt) { res in
                if let l = loading { self?.hideLoading(l) }
                switch res {
                case .success(let np):
                    self?.onPlayerUpdated(np)
                    self?.toast("购买 \(item.name) x\(cnt) 成功")
                case .failure(let e):
                    self?.toast(e.errorDescription ?? "购买失败", isError: true)
                }
            }
        })
        present(alert, animated: true)
    }
}

final class ShopItemCell: UICollectionViewCell {
    static let id = "ShopItemCell"
    private let iconLabel = UILabel.make("", font: .systemFont(ofSize: 28), color: .white, alignment: .center)
    private let nameLabel = UILabel.make("", font: .systemFont(ofSize: 14, weight: .semibold), color: .white)
    private let statsLabel = UILabel.make("", font: .systemFont(ofSize: 10), color: UIColor(hex: 0xcfd8e3))
    private let priceLabel = UILabel.make("", font: .systemFont(ofSize: 13, weight: .bold), color: .gold)
    private let rarityBar = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = UIColor(hex: 0x1a2030)
        contentView.layer.cornerRadius = 10
        contentView.layer.borderWidth = 1
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        rarityBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rarityBar)
        contentView.addSubview(iconLabel)
        contentView.addSubview(nameLabel)
        contentView.addSubview(statsLabel)
        contentView.addSubview(priceLabel)
        NSLayoutConstraint.activate([
            rarityBar.topAnchor.constraint(equalTo: contentView.topAnchor),
            rarityBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            rarityBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rarityBar.heightAnchor.constraint(equalToConstant: 3),
            iconLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            iconLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconLabel.widthAnchor.constraint(equalToConstant: 40),
            iconLabel.heightAnchor.constraint(equalToConstant: 40),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            nameLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            statsLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            statsLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            statsLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            priceLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            priceLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(item: ItemInfo) {
        let typeIcon: String
        switch item.type {
        case "weapon": typeIcon = "⚔️"
        case "armor":  typeIcon = "🛡️"
        case "skin":   typeIcon = "✨"
        case "consumable": typeIcon = "🧪"
        default: typeIcon = "❔"
        }
        iconLabel.text = typeIcon
        nameLabel.text = item.name + "  [\(item.rarityName)]"
        nameLabel.textColor = UIColor.rarity(item.rarity)
        var stats = [String]()
        if item.atk > 0 { stats.append("攻+\(item.atk)") }
        if item.df > 0 { stats.append("防+\(item.df)") }
        if item.hp > 0 { stats.append("血+\(item.hp)") }
        statsLabel.text = stats.joined(separator: "  ")

        if item.priceDiamond > 0 {
            priceLabel.text = "💎 \(item.priceDiamond)"
            priceLabel.textColor = .diamond
        } else {
            priceLabel.text = "💰 \(item.priceGold)"
            priceLabel.textColor = .gold
        }
        let c = UIColor.rarity(item.rarity)
        contentView.layer.borderColor = c.withAlphaComponent(0.5).cgColor
        rarityBar.backgroundColor = c
    }
}
