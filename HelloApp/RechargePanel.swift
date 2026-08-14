import UIKit

/// 充值面板: 显示钻石余额 + 联系 GM 充值提示
final class RechargePanel: BasePanel {
    private let balanceLabel = UILabel.make("0", font: .systemFont(ofSize: 48, weight: .heavy), color: .diamond, alignment: .center)
    private let balanceDescLabel = UILabel.make("当前钻石余额", font: .systemFont(ofSize: 13), color: UIColor(hex: 0x8b9bb4), alignment: .center)
    private let infoLabel = UILabel.make("", font: .systemFont(ofSize: 13), color: UIColor(hex: 0xcfd8e3), alignment: .center)
    private let packagesView = UIView()

    init() { super.init(title: "充值中心") }
    required init?(coder: NSCoder) { fatalError() }

    override func setupContent() {
        super.setupContent()
        let gemIcon = UILabel.make("💎", font: .systemFont(ofSize: 64), color: .white, alignment: .center)
        gemIcon.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(gemIcon)
        balanceLabel.translatesAutoresizingMaskIntoConstraints = false
        balanceLabel.layer.shadowColor = UIColor.diamond.cgColor
        balanceLabel.layer.shadowRadius = 16
        balanceLabel.layer.shadowOpacity = 0.6
        balanceLabel.layer.shadowOffset = .zero
        balanceDescLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.numberOfLines = 0
        infoLabel.textAlignment = .center
        cardView.addSubview(balanceLabel)
        cardView.addSubview(balanceDescLabel)
        cardView.addSubview(infoLabel)
        cardView.addSubview(packagesView)
        packagesView.translatesAutoresizingMaskIntoConstraints = false

        // 充值套餐(展示用,实际充值走 GM 后台)
        let packages: [(Int, Int, String, Bool)] = [
            (60, 6, "月卡族", false),
            (300, 30, "小氪怡情", false),
            (980, 98, "中氪养家", false),
            (3280, 328, "重氪玩家", true),
            (6480, 648, "至尊神豪", true),
            (32800, 3280, "霸服巨佬", true),
        ]
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 12
        stack.distribution = .fillEqually
        for (diamond, yuan, name, hot) in packages {
            let c = makePackageCard(diamond: diamond, yuan: yuan, name: name, hot: hot)
            stack.addArrangedSubview(c)
        }
        packagesView.addSubview(stack)
        NSLayoutConstraint.activate([
            gemIcon.topAnchor.constraint(equalTo: contentTopAnchor, constant: 14),
            gemIcon.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            gemIcon.heightAnchor.constraint(equalToConstant: 80),
            balanceLabel.topAnchor.constraint(equalTo: gemIcon.bottomAnchor, constant: 6),
            balanceLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            balanceDescLabel.topAnchor.constraint(equalTo: balanceLabel.bottomAnchor, constant: 4),
            balanceDescLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            infoLabel.topAnchor.constraint(equalTo: balanceDescLabel.bottomAnchor, constant: 20),
            infoLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 30),
            infoLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -30),
            packagesView.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 20),
            packagesView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 30),
            packagesView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -30),
            packagesView.heightAnchor.constraint(equalToConstant: 180),
            stack.topAnchor.constraint(equalTo: packagesView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: packagesView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: packagesView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: packagesView.trailingAnchor),
        ])
        infoLabel.text = "充值说明:\n游戏内钻石(💎充值币)由 GM 后台发放,请联系管理员充值。\nGM 后台地址: " + Config.baseURL.replacingOccurrences(of: "http://", with: "") + "/admin/ (admin/admin)"
        loadMe()
    }

    private func makePackageCard(diamond: Int, yuan: Int, name: String, hot: Bool) -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = UIColor(hex: 0x1a2030)
        card.layer.cornerRadius = 10
        card.layer.borderWidth = 1.5
        card.layer.borderColor = (hot ? UIColor.gold : UIColor.primary).withAlphaComponent(0.5).cgColor
        if hot { card.makeGlow(.gold, radius: 10, opacity: 0.5) }

        let iconL = UILabel.make("💎", font: .systemFont(ofSize: 26), color: .white, alignment: .center)
        iconL.translatesAutoresizingMaskIntoConstraints = false
        let diamondL = UILabel.make("\(diamond)", font: .systemFont(ofSize: 16, weight: .bold), color: .diamond, alignment: .center)
        diamondL.translatesAutoresizingMaskIntoConstraints = false
        let yuanL = UILabel.make("¥\(yuan)", font: .systemFont(ofSize: 13, weight: .semibold), color: .gold, alignment: .center)
        yuanL.translatesAutoresizingMaskIntoConstraints = false
        let nameL = UILabel.make(name, font: .systemFont(ofSize: 10), color: UIColor(hex: 0xcfd8e3), alignment: .center)
        nameL.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(iconL)
        card.addSubview(diamondL)
        card.addSubview(yuanL)
        card.addSubview(nameL)
        NSLayoutConstraint.activate([
            iconL.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            iconL.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            diamondL.topAnchor.constraint(equalTo: iconL.bottomAnchor, constant: 6),
            diamondL.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            yuanL.topAnchor.constraint(equalTo: diamondL.bottomAnchor, constant: 4),
            yuanL.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            nameL.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
            nameL.centerXAnchor.constraint(equalTo: card.centerXAnchor),
        ])
        if hot {
            let hotBadge = UILabel.make("HOT", font: .systemFont(ofSize: 8, weight: .bold), color: .white, alignment: .center)
            hotBadge.translatesAutoresizingMaskIntoConstraints = false
            hotBadge.backgroundColor = .gold
            hotBadge.layer.cornerRadius = 4
            card.addSubview(hotBadge)
            NSLayoutConstraint.activate([
                hotBadge.topAnchor.constraint(equalTo: card.topAnchor, constant: 4),
                hotBadge.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -4),
                hotBadge.widthAnchor.constraint(equalToConstant: 28),
                hotBadge.heightAnchor.constraint(equalToConstant: 14),
            ])
        }
        return card
    }

    private func loadMe() {
        APIClient.shared.getMe { [weak self] res in
            if case .success(let p) = res {
                self?.balanceLabel.text = p.diamond.shortString
            }
        }
    }
}
