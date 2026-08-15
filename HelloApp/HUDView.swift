import UIKit

/// 顶部 HUD(紧凑): 头像/等级/血条/经验/金币/钻石
final class HUDView: UIView {

    private let avatarView = UIView()
    private let levelLabel = UILabel.make("Lv.1", font: .systemFont(ofSize: 10, weight: .bold), color: .white, alignment: .center)
    private let nickLabel = UILabel.make("玩家", font: .systemFont(ofSize: 12, weight: .medium), color: UIColor(hex: 0xcfd8e3))
    private let hpBar = ProgressBar(color: UIColor(hex: 0xef5350), bgColor: UIColor(hex: 0x2a1212), height: 9)
    private let hpText = UILabel.make("", font: .systemFont(ofSize: 9, weight: .semibold), color: .white, alignment: .center)
    private let expBar = ProgressBar(color: UIColor(hex: 0xffd54f), bgColor: UIColor(hex: 0x2a2412), height: 7)
    private let expLabel = UILabel.make("EXP", font: .systemFont(ofSize: 8, weight: .bold), color: UIColor(hex: 0xffd54f), alignment: .left)
    private let goldLabel = UILabel.make("", font: .systemFont(ofSize: 11, weight: .bold), color: .gold)
    private let diamondLabel = UILabel.make("", font: .systemFont(ofSize: 11, weight: .bold), color: .diamond)
    private let goldIcon = UIImageView(image: UIImage(systemName: "dollarsign.circle.fill"))
    private let diamondIcon = UIImageView(image: UIImage(systemName: "diamond.fill"))
    private let vipBadge = UILabel.make("V0", font: .systemFont(ofSize: 9, weight: .bold), color: UIColor(hex: 0xffd54f), alignment: .center)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        backgroundColor = UIColor.bgDark.withAlphaComponent(0.78)
        layer.cornerRadius = 12
        layer.borderColor = UIColor.primary.withAlphaComponent(0.25).cgColor
        layer.borderWidth = 1
        layer.applyShadow(opacity: 0.35, radius: 6)

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.backgroundColor = UIColor.primary.withAlphaComponent(0.25)
        avatarView.layer.cornerRadius = 17
        avatarView.layer.borderColor = UIColor.primary.withAlphaComponent(0.7).cgColor
        avatarView.layer.borderWidth = 1.2
        avatarView.makeGlow(.primary, radius: 6, opacity: 0.35)
        let avatarImg = UIImageView(image: UIImage(systemName: "person.crop.circle.fill"))
        avatarImg.tintColor = .primary
        avatarImg.translatesAutoresizingMaskIntoConstraints = false
        avatarView.addSubview(avatarImg)

        let lvlBg = UIView()
        lvlBg.translatesAutoresizingMaskIntoConstraints = false
        lvlBg.backgroundColor = UIColor.accent
        lvlBg.layer.cornerRadius = 7
        lvlBg.makeGlow(UIColor.accent, radius: 5, opacity: 0.5)
        lvlBg.addSubview(levelLabel)
        levelLabel.translatesAutoresizingMaskIntoConstraints = false

        goldIcon.translatesAutoresizingMaskIntoConstraints = false
        goldIcon.tintColor = .gold
        goldIcon.contentMode = .scaleAspectFit
        diamondIcon.translatesAutoresizingMaskIntoConstraints = false
        diamondIcon.tintColor = .diamond
        diamondIcon.contentMode = .scaleAspectFit

        addSubview(avatarView)
        addSubview(lvlBg)
        addSubview(nickLabel)
        addSubview(vipBadge)
        addSubview(hpBar)
        addSubview(hpText)
        addSubview(expBar)
        addSubview(expLabel)
        addSubview(goldIcon)
        addSubview(goldLabel)
        addSubview(diamondIcon)
        addSubview(diamondLabel)

        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            avatarView.centerYAnchor.constraint(equalTo: centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 34),
            avatarView.heightAnchor.constraint(equalToConstant: 34),
            avatarImg.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarImg.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            avatarImg.widthAnchor.constraint(equalTo: avatarView.widthAnchor, multiplier: 0.8),
            avatarImg.heightAnchor.constraint(equalTo: avatarView.heightAnchor, multiplier: 0.8),

            lvlBg.leadingAnchor.constraint(equalTo: avatarView.leadingAnchor, constant: -5),
            lvlBg.bottomAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 5),
            lvlBg.widthAnchor.constraint(equalToConstant: 30),
            lvlBg.heightAnchor.constraint(equalToConstant: 14),
            levelLabel.centerXAnchor.constraint(equalTo: lvlBg.centerXAnchor),
            levelLabel.centerYAnchor.constraint(equalTo: lvlBg.centerYAnchor),

            nickLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 8),
            nickLabel.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            vipBadge.leadingAnchor.constraint(equalTo: nickLabel.trailingAnchor, constant: 5),
            vipBadge.centerYAnchor.constraint(equalTo: nickLabel.centerYAnchor),

            hpBar.leadingAnchor.constraint(equalTo: nickLabel.leadingAnchor),
            hpBar.topAnchor.constraint(equalTo: nickLabel.bottomAnchor, constant: 2),
            hpBar.widthAnchor.constraint(equalToConstant: 150),
            hpBar.heightAnchor.constraint(equalToConstant: 9),
            hpText.centerXAnchor.constraint(equalTo: hpBar.centerXAnchor),
            hpText.centerYAnchor.constraint(equalTo: hpBar.centerYAnchor),
            hpText.widthAnchor.constraint(equalTo: hpBar.widthAnchor),

            expLabel.leadingAnchor.constraint(equalTo: hpBar.leadingAnchor),
            expLabel.topAnchor.constraint(equalTo: hpBar.bottomAnchor, constant: 1),
            expLabel.heightAnchor.constraint(equalToConstant: 8),
            expBar.leadingAnchor.constraint(equalTo: expLabel.trailingAnchor, constant: 3),
            expBar.centerYAnchor.constraint(equalTo: expLabel.centerYAnchor),
            expBar.trailingAnchor.constraint(equalTo: hpBar.trailingAnchor),
            expBar.heightAnchor.constraint(equalToConstant: 7),

            goldIcon.leadingAnchor.constraint(equalTo: hpBar.trailingAnchor, constant: 12),
            goldIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            goldIcon.widthAnchor.constraint(equalToConstant: 14),
            goldIcon.heightAnchor.constraint(equalToConstant: 14),
            goldLabel.leadingAnchor.constraint(equalTo: goldIcon.trailingAnchor, constant: 3),
            goldLabel.centerYAnchor.constraint(equalTo: goldIcon.centerYAnchor),
            goldLabel.widthAnchor.constraint(equalToConstant: 56),

            diamondIcon.leadingAnchor.constraint(equalTo: goldLabel.trailingAnchor, constant: 6),
            diamondIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            diamondIcon.widthAnchor.constraint(equalToConstant: 12),
            diamondIcon.heightAnchor.constraint(equalToConstant: 12),
            diamondLabel.leadingAnchor.constraint(equalTo: diamondIcon.trailingAnchor, constant: 3),
            diamondLabel.centerYAnchor.constraint(equalTo: diamondIcon.centerYAnchor),
            diamondLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
        ])
    }

    func update(_ p: PlayerInfo) {
        levelLabel.text = "Lv.\(p.level)"
        nickLabel.text = p.nickname
        vipBadge.text = "V\(p.vip)"
        let hpPct = p.totalHp > 0 ? CGFloat(p.curHp) / CGFloat(p.totalHp) : 0
        hpBar.setProgress(hpPct, animated: true)
        hpText.text = "\(p.curHp.shortString)/\(p.totalHp.shortString)"
        let expPct = p.expNext > 0 ? CGFloat(p.exp) / CGFloat(p.expNext) : 0
        expBar.setProgress(expPct, animated: true)
        goldLabel.text = p.gold.shortString
        diamondLabel.text = p.diamond.shortString
    }
}

// MARK: - 通用进度条
final class ProgressBar: UIView {
    private let bg = UIView()
    private let fill = UIView()
    private let height: CGFloat
    private let color: UIColor
    private var fillWidth: NSLayoutConstraint!
    private var cur: CGFloat = 0

    init(color: UIColor, bgColor: UIColor, height: CGFloat = 12) {
        self.color = color
        self.height = height
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        bg.translatesAutoresizingMaskIntoConstraints = false
        bg.backgroundColor = bgColor
        bg.layer.cornerRadius = height/2
        bg.layer.masksToBounds = true
        addSubview(bg)
        fill.translatesAutoresizingMaskIntoConstraints = false
        fill.backgroundColor = color
        fill.layer.cornerRadius = height/2
        fill.layer.masksToBounds = true
        fill.makeGlow(color, radius: 4, opacity: 0.5)
        bg.addSubview(fill)

        NSLayoutConstraint.activate([
            bg.topAnchor.constraint(equalTo: topAnchor),
            bg.bottomAnchor.constraint(equalTo: bottomAnchor),
            bg.leadingAnchor.constraint(equalTo: leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: trailingAnchor),
            fill.topAnchor.constraint(equalTo: bg.topAnchor),
            fill.bottomAnchor.constraint(equalTo: bg.bottomAnchor),
            fill.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
        ])
        fillWidth = fill.widthAnchor.constraint(equalToConstant: 0)
        fillWidth.isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }

    func setProgress(_ p: CGFloat, animated: Bool) {
        let target = max(0, min(1, p))
        cur = target
        layoutIfNeeded()
        let w = bounds.width * target
        fillWidth.constant = w
        if animated {
            UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut) {
                self.layoutIfNeeded()
            }
        } else {
            layoutIfNeeded()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        fillWidth.constant = bounds.width * cur
    }
}

extension CALayer {
    func applyShadow(color: CGColor = UIColor.black.cgColor, opacity: Float = 0.4, radius: CGFloat = 8, offset: CGSize = CGSize(width: 0, height: 4)) {
        shadowColor = color
        shadowOpacity = opacity
        shadowRadius = radius
        shadowOffset = offset
    }
}
