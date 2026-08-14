import UIKit

/// 所有面板基类: 全屏半透明背景 + 卡片 + 标题 + 关闭按钮
class BasePanel: UIViewController {

    let titleText: String
    let cardView = UIView()
    private let backdrop = UIView()
    private let titleLabel = UILabel()
    private let closeBtn = UIButton(type: .system)

    init(title: String) {
        self.titleText = title
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        backdrop.translatesAutoresizingMaskIntoConstraints = false
        backdrop.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        view.addSubview(backdrop)
        let tap = UITapGestureRecognizer(target: self, action: #selector(close))
        backdrop.addGestureRecognizer(tap)

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = UIColor.bgDark.withAlphaComponent(0.95)
        cardView.layer.cornerRadius = 16
        cardView.layer.borderColor = UIColor.primary.withAlphaComponent(0.3).cgColor
        cardView.layer.borderWidth = 1
        cardView.layer.applyShadow(opacity: 0.6, radius: 24)
        cardView.clipsToBounds = true
        view.addSubview(cardView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = titleText
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.layer.shadowColor = UIColor.primary.cgColor
        titleLabel.layer.shadowRadius = 10
        titleLabel.layer.shadowOpacity = 0.5
        titleLabel.layer.shadowOffset = .zero

        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeBtn.tintColor = UIColor(hex: 0x8b9bb4)
        closeBtn.addTarget(self, action: #selector(close), for: .touchUpInside)

        cardView.addSubview(titleLabel)
        cardView.addSubview(closeBtn)

        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.86),
            cardView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.82),

            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            closeBtn.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            closeBtn.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeBtn.widthAnchor.constraint(equalToConstant: 32),
            closeBtn.heightAnchor.constraint(equalToConstant: 32),
        ])
        setupContent()
    }

    /// 子类重写: 在卡片上添加内容(已自动有 titleLabel 和 closeBtn)
    func setupContent() {}

    /// 内容区域 top anchor (供子类使用)
    var contentTopAnchor: NSLayoutYAxisAnchor {
        return titleLabel.bottomAnchor
    }

    @objc func close() {
        dismiss(animated: true)
    }

    // 便捷 toast
    func toast(_ msg: String, isError: Bool = false) {
        guard let window = view.window else { return }
        let t = UILabel.make(msg, font: .systemFont(ofSize: 13, weight: .medium), color: .white, alignment: .center)
        t.backgroundColor = isError ? UIColor.danger : UIColor.primary
        t.layer.cornerRadius = 8; t.layer.masksToBounds = true
        t.textAlignment = .center; t.alpha = 0
        t.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(t)
        NSLayoutConstraint.activate([
            t.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            t.bottomAnchor.constraint(equalTo: window.bottomAnchor, constant: -60),
            t.heightAnchor.constraint(equalToConstant: 32),
            t.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
        ])
        UIView.animate(withDuration: 0.2) { t.alpha = 1 } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 1.2, options: []) { t.alpha = 0 } completion: { _ in t.removeFromSuperview() }
        }
    }
}

// MARK: - 加载指示器
extension UIViewController {
    func showLoading(_ text: String = "加载中...") -> UIView {
        let overlay = UIView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        let label = UILabel.make(text, font: .systemFont(ofSize: 14, weight: .medium), color: .white, alignment: .center)
        label.translatesAutoresizingMaskIntoConstraints = false
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = .primary
        spinner.startAnimating()
        overlay.addSubview(spinner)
        overlay.addSubview(label)
        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            spinner.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: overlay.centerYAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 8),
            label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
        ])
        return overlay
    }
    func hideLoading(_ overlay: UIView) {
        overlay.removeFromSuperview()
    }
}

// MARK: - 物品卡片(网格单元)
final class ItemCell: UICollectionViewCell {
    static let id = "ItemCell"
    private let iconLabel = UILabel.make("", font: .systemFont(ofSize: 28), color: .white, alignment: .center)
    private let countLabel = UILabel.make("", font: .systemFont(ofSize: 11, weight: .bold), color: .white, alignment: .center)
    private let nameLabel = UILabel.make("", font: .systemFont(ofSize: 10, weight: .medium), color: UIColor(hex: 0xcfd8e3), alignment: .center)
    private let rarityBar = UIView()
    private let equippedTag = UILabel.make("装", font: .systemFont(ofSize: 9, weight: .bold), color: .white, alignment: .center)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(hex: 0x1a2030)
        layer.cornerRadius = 8
        layer.borderWidth = 1
        contentView.addSubview(iconLabel)
        contentView.addSubview(nameLabel)
        contentView.addSubview(countLabel)
        contentView.addSubview(rarityBar)
        contentView.addSubview(equippedTag)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        rarityBar.translatesAutoresizingMaskIntoConstraints = false
        equippedTag.translatesAutoresizingMaskIntoConstraints = false
        equippedTag.backgroundColor = UIColor.gold
        equippedTag.layer.cornerRadius = 4
        equippedTag.isHidden = true
        NSLayoutConstraint.activate([
            iconLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            iconLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconLabel.widthAnchor.constraint(equalToConstant: 40),
            iconLabel.heightAnchor.constraint(equalToConstant: 40),
            nameLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 2),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            countLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            countLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            rarityBar.topAnchor.constraint(equalTo: contentView.topAnchor),
            rarityBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            rarityBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rarityBar.heightAnchor.constraint(equalToConstant: 3),
            equippedTag.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            equippedTag.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            equippedTag.widthAnchor.constraint(equalToConstant: 18),
            equippedTag.heightAnchor.constraint(equalToConstant: 14),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(item: ItemInfo, count: Int? = nil, isEquipped: Bool = false) {
        let typeIcon: String
        switch item.type {
        case "weapon": typeIcon = "⚔️"
        case "armor":  typeIcon = "🛡️"
        case "skin":   typeIcon = "✨"
        case "consumable": typeIcon = "🧪"
        case "material":   typeIcon = "📦"
        default: typeIcon = "❔"
        }
        iconLabel.text = typeIcon
        nameLabel.text = item.name
        countLabel.text = count != nil && count! > 1 ? "x\(count!)" : ""
        let c = UIColor.rarity(item.rarity)
        layer.borderColor = c.withAlphaComponent(0.6).cgColor
        rarityBar.backgroundColor = c
        equippedTag.isHidden = !isEquipped
    }
}
