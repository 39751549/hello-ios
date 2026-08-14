import UIKit

/// 战斗结果展示
final class BattleResultView: UIViewController {

    private let result: BattleResult
    private let onClose: () -> Void
    private let backdrop = UIView()
    private let cardView = UIView()
    private let onCloseHandler: () -> Void

    init(result: BattleResult, onClose: @escaping () -> Void) {
        self.result = result
        self.onClose = onClose
        self.onCloseHandler = onClose
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        backdrop.translatesAutoresizingMaskIntoConstraints = false
        backdrop.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        view.addSubview(backdrop)

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = UIColor.bgDark.withAlphaComponent(0.96)
        cardView.layer.cornerRadius = 18
        cardView.layer.borderColor = (result.win ? UIColor.gold : UIColor.danger).withAlphaComponent(0.6).cgColor
        cardView.layer.borderWidth = 1.5
        cardView.layer.applyShadow(opacity: 0.6, radius: 30)
        view.addSubview(cardView)

        let titleLabel = UILabel.make(result.win ? "胜  利" : "失  败", font: .systemFont(ofSize: 40, weight: .heavy), color: result.win ? .gold : .danger, alignment: .center)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.layer.shadowColor = titleLabel.textColor.cgColor
        titleLabel.layer.shadowRadius = 14
        titleLabel.layer.shadowOpacity = 0.7
        titleLabel.layer.shadowOffset = .zero
        cardView.addSubview(titleLabel)

        let enemyLabel = UILabel.make("vs \(result.enemyName)", font: .systemFont(ofSize: 13), color: UIColor(hex: 0xcfd8e3), alignment: .center)
        enemyLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(enemyLabel)

        let roundsLabel = UILabel.make("\(result.rounds) 回合", font: .systemFont(ofSize: 11), color: UIColor(hex: 0x8b9bb4), alignment: .center)
        roundsLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(roundsLabel)

        // 奖励区
        let rewardsStack = UIStackView()
        rewardsStack.translatesAutoresizingMaskIntoConstraints = false
        rewardsStack.axis = .horizontal
        rewardsStack.spacing = 14
        rewardsStack.alignment = .center
        rewardsStack.distribution = .fillEqually

        if result.win {
            rewardsStack.addArrangedSubview(makeRewardBox(icon: "⭐", text: "经验", amount: "+\(result.expGain)", color: .gold))
            rewardsStack.addArrangedSubview(makeRewardBox(icon: "💰", text: "金币", amount: "+\(result.goldGain)", color: .gold))
            if result.diamondGain > 0 {
                rewardsStack.addArrangedSubview(makeRewardBox(icon: "💎", text: "钻石", amount: "+\(result.diamondGain)", color: .diamond))
            }
        } else {
            let lostLabel = UILabel.make("血量已损失一半,请及时回血", font: .systemFont(ofSize: 13), color: .danger, alignment: .center)
            lostLabel.numberOfLines = 0
            rewardsStack.addArrangedSubview(lostLabel)
        }
        cardView.addSubview(rewardsStack)

        // 掉落
        let dropsLabel = UILabel.make("", font: .systemFont(ofSize: 12), color: UIColor(hex: 0xcfd8e3), alignment: .center)
        dropsLabel.translatesAutoresizingMaskIntoConstraints = false
        dropsLabel.numberOfLines = 0
        if result.win && !result.drops.isEmpty {
            // 拿掉落物品名(需要异步查 item 信息,简化:只显示数量)
            dropsLabel.text = "获得掉落物品 \(result.drops.count) 件"
        } else if result.win {
            dropsLabel.text = "本次无掉落"
        } else {
            dropsLabel.text = ""
        }
        cardView.addSubview(dropsLabel)

        // 升级提示
        let lvlUpLabel = UILabel.make("", font: .systemFont(ofSize: 14, weight: .bold), color: .myth, alignment: .center)
        lvlUpLabel.translatesAutoresizingMaskIntoConstraints = false
        if !result.leveledUp.isEmpty {
            lvlUpLabel.text = "🎉 升级到 Lv.\(result.leveledUp.last!) !"
            lvlUpLabel.layer.shadowColor = UIColor.myth.cgColor
            lvlUpLabel.layer.shadowRadius = 10
            lvlUpLabel.layer.shadowOpacity = 0.7
            lvlUpLabel.layer.shadowOffset = .zero
        }
        cardView.addSubview(lvlUpLabel)

        // 战斗日志(可滚动)
        let logTextView = UITextView()
        logTextView.translatesAutoresizingMaskIntoConstraints = false
        logTextView.backgroundColor = UIColor(hex: 0x0f141e).withAlphaComponent(0.5)
        logTextView.layer.cornerRadius = 8
        logTextView.isEditable = false
        logTextView.font = .systemFont(ofSize: 11)
        logTextView.textColor = UIColor(hex: 0xcfd8e3)
        logTextView.text = result.log.joined(separator: "\n")
        cardView.addSubview(logTextView)

        let okBtn = UIButton.makeGradient("确  定", height: 44)
        okBtn.translatesAutoresizingMaskIntoConstraints = false
        okBtn.addTarget(self, action: #selector(close), for: .touchUpInside)
        cardView.addSubview(okBtn)

        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.widthAnchor.constraint(equalToConstant: 460),
            cardView.heightAnchor.constraint(equalToConstant: 480),

            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 28),
            titleLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            enemyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            enemyLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            roundsLabel.topAnchor.constraint(equalTo: enemyLabel.bottomAnchor, constant: 2),
            roundsLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),

            rewardsStack.topAnchor.constraint(equalTo: roundsLabel.bottomAnchor, constant: 22),
            rewardsStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            rewardsStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            rewardsStack.heightAnchor.constraint(equalToConstant: 70),

            dropsLabel.topAnchor.constraint(equalTo: rewardsStack.bottomAnchor, constant: 10),
            dropsLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            dropsLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),

            lvlUpLabel.topAnchor.constraint(equalTo: dropsLabel.bottomAnchor, constant: 8),
            lvlUpLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),

            logTextView.topAnchor.constraint(equalTo: lvlUpLabel.bottomAnchor, constant: 10),
            logTextView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            logTextView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            logTextView.heightAnchor.constraint(equalToConstant: 120),

            okBtn.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -22),
            okBtn.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            okBtn.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
        ])
        // 入场动画
        cardView.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        cardView.alpha = 0
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: []) {
            self.cardView.transform = .identity
            self.cardView.alpha = 1
        }
    }

    private func makeRewardBox(icon: String, text: String, amount: String, color: UIColor) -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor(hex: 0x1a2030)
        v.layer.cornerRadius = 10
        v.layer.borderColor = color.withAlphaComponent(0.5).cgColor
        v.layer.borderWidth = 1
        let iconL = UILabel.make(icon, font: .systemFont(ofSize: 22), color: .white, alignment: .center)
        let txtL = UILabel.make(text, font: .systemFont(ofSize: 10), color: UIColor(hex: 0x8b9bb4), alignment: .center)
        let amtL = UILabel.make(amount, font: .systemFont(ofSize: 13, weight: .bold), color: color, alignment: .center)
        for s in [iconL, txtL, amtL] {
            s.translatesAutoresizingMaskIntoConstraints = false
            v.addSubview(s)
        }
        NSLayoutConstraint.activate([
            iconL.topAnchor.constraint(equalTo: v.topAnchor, constant: 8),
            iconL.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            txtL.topAnchor.constraint(equalTo: iconL.bottomAnchor, constant: 2),
            txtL.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            amtL.topAnchor.constraint(equalTo: txtL.bottomAnchor, constant: 4),
            amtL.centerXAnchor.constraint(equalTo: v.centerXAnchor),
        ])
        return v
    }

    @objc private func close() {
        onCloseHandler()
        dismiss(animated: true)
    }
}
