import UIKit

/// 背包面板: 装备/卸下/使用消耗品
final class InventoryPanel: BasePanel, UICollectionViewDataSource, UICollectionViewDelegate {

    private var items: [PlayerItemInfo] = []
    private var player: PlayerInfo?
    private var collectionView: UICollectionView!
    private let detailView = UIView()
    private let detailIcon = UILabel.make("", font: .systemFont(ofSize: 36), color: .white, alignment: .center)
    private let detailName = UILabel.make("", font: .systemFont(ofSize: 16, weight: .bold), color: .white)
    private let detailStats = UILabel.make("", font: .systemFont(ofSize: 12), color: UIColor(hex: 0xcfd8e3))
    private let detailDesc = UILabel.make("", font: .systemFont(ofSize: 12), color: UIColor(hex: 0x8b9bb4))
    private let actionBtn = UIButton.makeGradient("装备", height: 40)
    private var selectedItem: PlayerItemInfo?
    private var selectedIdx: Int = -1
    private let onPlayerUpdated: (PlayerInfo) -> Void

    init(onUpdate: @escaping (PlayerInfo) -> Void) {
        self.onPlayerUpdated = onUpdate
        super.init(title: "背包")
    }
    required init?(coder: NSCoder) { fatalError() }

    override func setupContent() {
        super.setupContent()
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 84, height: 96)
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(ItemCell.self, forCellWithReuseIdentifier: ItemCell.id)
        cardView.addSubview(collectionView)

        detailView.translatesAutoresizingMaskIntoConstraints = false
        detailView.backgroundColor = UIColor(hex: 0x0f141e).withAlphaComponent(0.6)
        detailView.layer.cornerRadius = 12
        detailView.layer.borderColor = UIColor.primary.withAlphaComponent(0.2).cgColor
        detailView.layer.borderWidth = 1
        cardView.addSubview(detailView)

        detailIcon.translatesAutoresizingMaskIntoConstraints = false
        detailName.translatesAutoresizingMaskIntoConstraints = false
        detailStats.translatesAutoresizingMaskIntoConstraints = false
        detailDesc.translatesAutoresizingMaskIntoConstraints = false
        actionBtn.translatesAutoresizingMaskIntoConstraints = false
        actionBtn.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
        detailView.addSubview(detailIcon)
        detailView.addSubview(detailName)
        detailView.addSubview(detailStats)
        detailView.addSubview(detailDesc)
        detailView.addSubview(actionBtn)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: contentTopAnchor, constant: 14),
            collectionView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            collectionView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16),
            collectionView.widthAnchor.constraint(equalToConstant: 360),

            detailView.topAnchor.constraint(equalTo: collectionView.topAnchor),
            detailView.leadingAnchor.constraint(equalTo: collectionView.trailingAnchor, constant: 14),
            detailView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            detailView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),

            detailIcon.topAnchor.constraint(equalTo: detailView.topAnchor, constant: 20),
            detailIcon.leadingAnchor.constraint(equalTo: detailView.leadingAnchor, constant: 20),
            detailIcon.widthAnchor.constraint(equalToConstant: 60),
            detailIcon.heightAnchor.constraint(equalToConstant: 60),

            detailName.topAnchor.constraint(equalTo: detailIcon.topAnchor, constant: 4),
            detailName.leadingAnchor.constraint(equalTo: detailIcon.trailingAnchor, constant: 16),
            detailName.trailingAnchor.constraint(equalTo: detailView.trailingAnchor, constant: -16),

            detailStats.topAnchor.constraint(equalTo: detailName.bottomAnchor, constant: 6),
            detailStats.leadingAnchor.constraint(equalTo: detailName.leadingAnchor),
            detailStats.trailingAnchor.constraint(equalTo: detailName.trailingAnchor),

            detailDesc.topAnchor.constraint(equalTo: detailStats.bottomAnchor, constant: 6),
            detailDesc.leadingAnchor.constraint(equalTo: detailName.leadingAnchor),
            detailDesc.trailingAnchor.constraint(equalTo: detailName.trailingAnchor),

            actionBtn.bottomAnchor.constraint(equalTo: detailView.bottomAnchor, constant: -20),
            actionBtn.leadingAnchor.constraint(equalTo: detailView.leadingAnchor, constant: 20),
            actionBtn.trailingAnchor.constraint(equalTo: detailView.trailingAnchor, constant: -20),
        ])
        showEmpty()
        loadMe()
    }

    private func showEmpty() {
        detailIcon.text = "🎒"
        detailName.text = "未选择物品"
        detailName.textColor = UIColor(hex: 0x6b7a8f)
        detailStats.text = "点击左侧物品查看详情"
        detailDesc.text = ""
        actionBtn.isHidden = true
    }

    private func loadMe() {
        APIClient.shared.getMe { [weak self] res in
            if case .success(let p) = res {
                self?.player = p
                self?.items = p.items.sorted { $0.item.rarity > $1.item.rarity }
                self?.collectionView.reloadData()
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.count }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ItemCell.id, for: indexPath) as! ItemCell
        let pi = items[indexPath.item]
        let isEq = (pi.item.id == player?.equipWeapon) || (pi.item.id == player?.equipArmor) || (pi.item.id == player?.equipSkin)
        cell.configure(item: pi.item, count: pi.count, isEquipped: isEq)
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedIdx = indexPath.item
        selectedItem = items[indexPath.item]
        updateDetail()
    }

    private func updateDetail() {
        guard let pi = selectedItem else { return }
        let item = pi.item
        detailIcon.text = typeIcon(item.type)
        detailName.text = item.name + "  [\(item.rarityName)]"
        detailName.textColor = UIColor.rarity(item.rarity)
        var stats = [String]()
        if item.atk > 0 { stats.append("攻击 +\(item.atk)") }
        if item.df  > 0 { stats.append("防御 +\(item.df)") }
        if item.hp  > 0 { stats.append("生命 +\(item.hp)") }
        stats.append("类型: \(item.typeName)")
        stats.append("数量: \(pi.count)")
        detailStats.text = stats.joined(separator: "\n")
        detailDesc.text = item.desc

        let isEq = (item.id == player?.equipWeapon) || (item.id == player?.equipArmor) || (item.id == player?.equipSkin)
        actionBtn.isHidden = false
        if item.type == "consumable" {
            actionBtn.setTitle("使用", for: .normal)
            actionBtn.setTitleColor(.white, for: .normal)
        } else if ["weapon","armor","skin"].contains(item.type) {
            actionBtn.setTitle(isEq ? "卸下" : "装备", for: .normal)
        } else {
            actionBtn.isHidden = true
        }
    }

    private func typeIcon(_ t: String) -> String {
        switch t {
        case "weapon": return "⚔️"
        case "armor":  return "🛡️"
        case "skin":   return "✨"
        case "consumable": return "🧪"
        case "material":   return "📦"
        default: return "❔"
        }
    }

    @objc private func actionTapped() {
        guard let pi = selectedItem, let p = player else { return }
        let item = pi.item
        let loading = showLoading()
        if item.type == "consumable" {
            APIClient.shared.useItem(playerItemId: pi.id, count: 1) { [weak self] res in
                self?.hideLoading(loading)
                switch res {
                case .success(let np):
                    self?.player = np; self?.items = np.items.sorted { $0.item.rarity > $1.item.rarity }
                    self?.collectionView.reloadData()
                    self?.updateDetail()
                    self?.onPlayerUpdated(np)
                    self?.toast("使用了 \(item.name)")
                case .failure(let e): self?.toast(e.errorDescription ?? "失败", isError: true)
                }
            }
        } else if ["weapon","armor","skin"].contains(item.type) {
            let isEq = (item.id == p.equipWeapon) || (item.id == p.equipArmor) || (item.id == p.equipSkin)
            if isEq {
                APIClient.shared.unequip(itemId: item.id) { [weak self] res in
                    self?.hideLoading(loading)
                    switch res {
                    case .success(let np):
                        self?.player = np; self?.collectionView.reloadData(); self?.updateDetail()
                        self?.onPlayerUpdated(np); self?.toast("已卸下 \(item.name)")
                    case .failure(let e): self?.toast(e.errorDescription ?? "失败", isError: true)
                    }
                }
            } else {
                APIClient.shared.equip(playerItemId: pi.id) { [weak self] res in
                    self?.hideLoading(loading)
                    switch res {
                    case .success(let np):
                        self?.player = np; self?.collectionView.reloadData(); self?.updateDetail()
                        self?.onPlayerUpdated(np); self?.toast("已装备 \(item.name)")
                    case .failure(let e): self?.toast(e.errorDescription ?? "失败", isError: true)
                    }
                }
            }
        }
    }
}
