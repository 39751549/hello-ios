import UIKit

/// 抽奖面板: 奖池选择 + 单抽/十连抽 + 动画展示
final class GachaPanel: BasePanel {

    private var pools: [GachaPool] = []
    private var selectedPool: GachaPool?
    private let poolStack = UIStackView()
    private let drawBtn1 = UIButton.makeGradient("单抽", height: 44)
    private let drawBtn10 = UIButton.makeGradient("十连抽", color1: .accent, color2: .legend, height: 44)
    private let resultView = UIView()
    private let resultCollection: UICollectionView
    private let onPlayerUpdated: (PlayerInfo) -> Void

    init(onUpdate: @escaping (PlayerInfo) -> Void) {
        self.onPlayerUpdated = onUpdate
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 110, height: 140)
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 10
        layout.scrollDirection = .horizontal
        self.resultCollection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(title: "神圣召唤 · 抽奖")
    }
    required init?(coder: NSCoder) { fatalError() }

    override func setupContent() {
        super.setupContent()
        poolStack.translatesAutoresizingMaskIntoConstraints = false
        poolStack.axis = .vertical
        poolStack.spacing = 10
        cardView.addSubview(poolStack)

        drawBtn1.translatesAutoresizingMaskIntoConstraints = false
        drawBtn1.addTarget(self, action: #selector(draw1), for: .touchUpInside)
        drawBtn10.translatesAutoresizingMaskIntoConstraints = false
        drawBtn10.addTarget(self, action: #selector(draw10), for: .touchUpInside)
        let btnStack = UIStackView(arrangedSubviews: [drawBtn1, drawBtn10])
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        btnStack.axis = .horizontal
        btnStack.spacing = 12
        btnStack.distribution = .fillEqually
        cardView.addSubview(btnStack)

        resultCollection.translatesAutoresizingMaskIntoConstraints = false
        resultCollection.backgroundColor = UIColor(hex: 0x0f141e).withAlphaComponent(0.5)
        resultCollection.layer.cornerRadius = 12
        resultCollection.layer.borderColor = UIColor.primary.withAlphaComponent(0.2).cgColor
        resultCollection.layer.borderWidth = 1
        resultCollection.dataSource = self
        resultCollection.delegate = self
        resultCollection.register(GachaResultCell.self, forCellWithReuseIdentifier: GachaResultCell.id)
        resultCollection.alwaysBounceVertical = false
        cardView.addSubview(resultCollection)

        let hintLabel = UILabel.make("点击下方奖池选择,抽到的物品会显示在右侧", font: .systemFont(ofSize: 11), color: UIColor(hex: 0x6b7a8f))
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(hintLabel)

        NSLayoutConstraint.activate([
            hintLabel.topAnchor.constraint(equalTo: contentTopAnchor, constant: 8),
            hintLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            poolStack.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 10),
            poolStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            poolStack.widthAnchor.constraint(equalToConstant: 280),

            btnStack.topAnchor.constraint(equalTo: poolStack.bottomAnchor, constant: 20),
            btnStack.leadingAnchor.constraint(equalTo: poolStack.leadingAnchor),
            btnStack.trailingAnchor.constraint(equalTo: poolStack.trailingAnchor),

            resultCollection.topAnchor.constraint(equalTo: contentTopAnchor, constant: 10),
            resultCollection.leadingAnchor.constraint(equalTo: poolStack.trailingAnchor, constant: 24),
            resultCollection.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            resultCollection.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20),
        ])
        loadPools()
    }

    private func loadPools() {
        APIClient.shared.getGachaPools { [weak self] res in
            guard let self = self else { return }
            switch res {
            case .success(let pools):
                self.pools = pools
                self.renderPools()
                if let first = pools.first { self.selectPool(first) }
            case .failure(let e): self.toast(e.errorDescription ?? "加载失败", isError: true)
            }
        }
    }

    private func renderPools() {
        poolStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for pool in pools {
            let b = UIButton(type: .system)
            b.translatesAutoresizingMaskIntoConstraints = false
            b.titleLabel?.numberOfLines = 2
            b.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
            b.contentHorizontalAlignment = .left
            b.titleEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
            let costColor = pool.costType == "gold" ? UIColor.gold : UIColor.diamond
            let attr = NSMutableAttributedString()
            attr.append(NSAttributedString(string: pool.name + "\n", attributes: [.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 14, weight: .bold)]))
            attr.append(NSAttributedString(string: "单抽 \(pool.costOnce) · 十连 \(pool.costTen) " + (pool.costType == "gold" ? "💰" : "💎"), attributes: [.foregroundColor: costColor, .font: UIFont.systemFont(ofSize: 11, weight: .medium)]))
            attr.append(NSAttributedString(string: "\n\(pool.desc)", attributes: [.foregroundColor: UIColor(hex: 0x8b9bb4), .font: UIFont.systemFont(ofSize: 10)]))
            b.setAttributedTitle(attr, for: .normal)
            b.backgroundColor = UIColor(hex: 0x1a2030)
            b.layer.cornerRadius = 10
            b.layer.borderWidth = 1.5
            b.layer.borderColor = UIColor.clear.cgColor
            b.heightAnchor.constraint(equalToConstant: 70).isActive = true
            b.tag = pool.id
            b.addTarget(self, action: #selector(poolTapped(_:)), for: .touchUpInside)
            poolStack.addArrangedSubview(b)
        }
    }

    @objc private func poolTapped(_ sender: UIButton) {
        guard let p = pools.first(where: { $0.id == sender.tag }) else { return }
        selectPool(p)
    }

    private func selectPool(_ pool: GachaPool) {
        selectedPool = pool
        for v in poolStack.arrangedSubviews {
            if let b = v as? UIButton {
                let isSel = b.tag == pool.id
                b.layer.borderColor = isSel ? UIColor.primary.cgColor : UIColor.clear.cgColor
                b.backgroundColor = isSel ? UIColor.primary.withAlphaComponent(0.15) : UIColor(hex: 0x1a2030)
            }
        }
    }

    @objc private func draw1() { draw(times: 1) }
    @objc private func draw10() { draw(times: 10) }

    private var drawResults: [GachaResultItem] = []
    private func draw(times: Int) {
        guard let pool = selectedPool else { toast("请选择奖池", isError: true); return }
        let loading = showLoading(times >= 10 ? "十连召唤中..." : "召唤中...")
        APIClient.shared.draw(poolId: pool.id, times: times) { [weak self] res in
            guard let self = self else { return }
            self.hideLoading(loading)
            switch res {
            case .success(let data):
                self.drawResults = data.results
                if let np = data.player { self.onPlayerUpdated(np) }
                self.resultCollection.reloadData()
                self.playRevealAnimation()
            case .failure(let e): self.toast(e.errorDescription ?? "召唤失败", isError: true)
            }
        }
    }

    private func playRevealAnimation() {
        // 简单的卡片亮起动画
        let cells = resultCollection.visibleCells
        for (i, c) in cells.enumerated() {
            c.alpha = 0
            c.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
            UIView.animate(withDuration: 0.4, delay: TimeInterval(i) * 0.08, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: []) {
                c.alpha = 1
                c.transform = .identity
            }
        }
        // 十连最稀有物品提示
        if let best = drawResults.max(by: { rarityRank($0.item.rarity) < rarityRank($1.item.rarity) }) {
            let r = best.item.rarityName
            if ["传说", "神话"].contains(r) {
                toast("🎉 获得 \(r): \(best.item.name) x\(best.count)")
            }
        }
    }
    private func rarityRank(_ r: String) -> Int {
        switch r { case "common":0; case "rare":1; case "epic":2; case "legend":3; case "myth":4; default:0 }
    }
}

extension GachaPanel: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { drawResults.count }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let c = collectionView.dequeueReusableCell(withReuseIdentifier: GachaResultCell.id, for: indexPath) as! GachaResultCell
        c.configure(result: drawResults[indexPath.item])
        return c
    }
}

final class GachaResultCell: UICollectionViewCell {
    static let id = "GachaResultCell"
    private let iconLabel = UILabel.make("", font: .systemFont(ofSize: 38), color: .white, alignment: .center)
    private let nameLabel = UILabel.make("", font: .systemFont(ofSize: 11, weight: .semibold), color: .white, alignment: .center)
    private let rarityLabel = UILabel.make("", font: .systemFont(ofSize: 9, weight: .bold), color: .white, alignment: .center)
    private let countLabel = UILabel.make("", font: .systemFont(ofSize: 11, weight: .bold), color: .gold, alignment: .center)
    private let rarityBar = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = UIColor(hex: 0x1a2030)
        contentView.layer.cornerRadius = 10
        contentView.layer.borderWidth = 1
        for v in [iconLabel, nameLabel, rarityLabel, countLabel, rarityBar] {
            v.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(v)
        }
        NSLayoutConstraint.activate([
            rarityBar.topAnchor.constraint(equalTo: contentView.topAnchor),
            rarityBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            rarityBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rarityBar.heightAnchor.constraint(equalToConstant: 4),
            iconLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            iconLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconLabel.widthAnchor.constraint(equalToConstant: 50),
            iconLabel.heightAnchor.constraint(equalToConstant: 50),
            nameLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 6),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            rarityLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            rarityLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            countLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            countLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(result: GachaResultItem) {
        let item = result.item
        let typeIcon: String
        switch item.type {
        case "weapon": typeIcon = "⚔️"
        case "armor":  typeIcon = "🛡️"
        case "skin":   typeIcon = "✨"
        case "consumable": typeIcon = "🧪"
        default: typeIcon = "❔"
        }
        iconLabel.text = typeIcon
        nameLabel.text = item.name
        nameLabel.textColor = UIColor.rarity(item.rarity)
        rarityLabel.text = "[\(item.rarityName)]"
        rarityLabel.textColor = UIColor.rarity(item.rarity)
        countLabel.text = result.count > 1 ? "x\(result.count)" : ""
        let c = UIColor.rarity(item.rarity)
        contentView.layer.borderColor = c.withAlphaComponent(0.6).cgColor
        rarityBar.backgroundColor = c
        // 神话/传说加发光
        if item.rarity == "myth" || item.rarity == "legend" {
            contentView.makeGlow(c, radius: 12, opacity: 0.7)
        } else {
            contentView.layer.shadowOpacity = 0
        }
    }
}
