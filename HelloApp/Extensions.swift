import UIKit

// MARK: - UIColor 主题色
extension UIColor {
    static let bgDark = UIColor(hex: 0x0a0e1a)
    static let bgCard = UIColor(hex: 0x141a26)
    static let primary = UIColor(hex: 0x4a9eff)
    static let primaryEnd = UIColor(hex: 0x6b5bff)
    static let accent = UIColor(hex: 0x9c6bff)
    static let gold = UIColor(hex: 0xffd54f)
    static let diamond = UIColor(hex: 0x26c6da)
    static let danger = UIColor(hex: 0xef5350)
    static let epic = UIColor(hex: 0xff7043)
    static let legend = UIColor(hex: 0xab47bc)
    static let myth = UIColor(hex: 0xffd54f)
    static let rare = UIColor(hex: 0x4a9eff)
    static let common = UIColor(hex: 0x9aa0a6)

    static func rarity(_ r: String) -> UIColor {
        switch r {
        case "common": return .common
        case "rare":   return .rare
        case "epic":   return .epic
        case "legend": return .legend
        case "myth":   return .myth
        default:       return .common
        }
    }

    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        let r = CGFloat((hex >> 16) & 0xff) / 255
        let g = CGFloat((hex >> 8) & 0xff) / 255
        let b = CGFloat(hex & 0xff) / 255
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}

// MARK: - UIView 样式扩展
extension UIView {
    func addGradient(_ colors: [UIColor], angle: CGFloat = 0, locations: [NSNumber]? = nil) {
        let g = CAGradientLayer()
        g.frame = bounds
        g.colors = colors.map { $0.cgColor }
        g.locations = locations
        g.startPoint = CGPoint(x: 0, y: 0.5)
        g.endPoint = CGPoint(x: 1, y: 0.5)
        if angle != 0 {
            g.transform = CATransform3DMakeRotation(angle, 0, 0, 1)
        }
        g.name = "gradient"
        layer.insertSublayer(g, at: 0)
    }

    func setCardStyle(cornerRadius: CGFloat = 14, border: UIColor = .primary, borderWidth: CGFloat = 0.6, alpha: CGFloat = 0.7) {
        backgroundColor = UIColor.bgCard.withAlphaComponent(alpha)
        layer.cornerRadius = cornerRadius
        layer.borderWidth = borderWidth
        layer.borderColor = border.withAlphaComponent(0.25).cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: 4)
        clipsToBounds = false
    }

    func makeGlow(_ color: UIColor, radius: CGFloat = 12, opacity: Float = 0.6) {
        layer.shadowColor = color.cgColor
        layer.shadowRadius = radius
        layer.shadowOpacity = opacity
        layer.shadowOffset = .zero
    }
}

// MARK: - UILabel/UIButton 便捷构造
extension UILabel {
    static func make(_ text: String = "", font: UIFont = .systemFont(ofSize: 14), color: UIColor = .white, alignment: NSTextAlignment = .left) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = font
        l.textColor = color
        l.textAlignment = alignment
        l.numberOfLines = 0
        return l
    }
}

extension UIButton {
    static func makeGradient(_ title: String, color1: UIColor = .primary, color2: UIColor = .primaryEnd, height: CGFloat = 46) -> UIButton {
        let b = GradientButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 12
        b.clipsToBounds = true
        b.setGradient(colors: [color1, color2])
        b.heightAnchor.constraint(equalToConstant: height).isActive = true
        return b
    }
}

/// 自适应尺寸的渐变按钮
final class GradientButton: UIButton {
    private var gradientLayer: CAGradientLayer?
    func setGradient(colors: [UIColor]) {
        let g = CAGradientLayer()
        g.colors = colors.map { $0.cgColor }
        g.startPoint = CGPoint(x: 0, y: 0.5)
        g.endPoint = CGPoint(x: 1, y: 0.5)
        layer.insertSublayer(g, at: 0)
        gradientLayer = g
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer?.frame = bounds
    }
}

/// 自适应尺寸的渐变视图
final class GradientView: UIView {
    var colors: [UIColor] = [] { didSet { updateGradient() } }
    var angle: CGFloat = 0 { didSet { updateGradient() } }
    private var gradientLayer: CAGradientLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        let g = CAGradientLayer()
        gradientLayer = g
        layer.insertSublayer(g, at: 0)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func updateGradient() {
        guard let g = gradientLayer else { return }
        g.colors = colors.map { $0.cgColor }
        if angle != 0 {
            g.transform = CATransform3DMakeRotation(angle, 0, 0, 1)
        }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer?.frame = bounds
        if angle != 0, let g = gradientLayer {
            // 旋转后 frame 仍以 bounds 为基准,使用更大的 frame 避免边角空白
            let s = max(bounds.width, bounds.height) * 1.5
            g.frame = CGRect(x: (bounds.width - s)/2, y: (bounds.height - s)/2, width: s, height: s)
        }
    }
}

// MARK: - 字符串工具
extension String {
    var isValidUsername: Bool {
        return count >= 3 && range(of: "[^a-zA-Z0-9_]", options: .regularExpression) == nil
    }
}

// MARK: - 数字格式化
extension Int {
    /// 10000 -> 1万
    var shortString: String {
        if self >= 100_000_000 { return String(format: "%.2f亿", Double(self)/1_0000_0000) }
        if self >= 10_000 { return String(format: "%.2f万", Double(self)/10_000) }
        return String(self)
    }
}
