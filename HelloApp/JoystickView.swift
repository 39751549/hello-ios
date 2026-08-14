import UIKit

/// 虚拟摇杆(返回方向向量 -1~1)
final class JoystickView: UIView {
    var onChange: ((CGFloat, CGFloat) -> Void)?  // (x, y) y 向上为正

    private let baseLayer = CAShapeLayer()
    private let stickLayer = CAShapeLayer()
    private let stickView = UIView()
    private var touchId: UITouch?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear

        let r = min(bounds.width, bounds.height) / 2
        baseLayer.path = UIBezierPath(ovalIn: bounds.insetBy(dx: 4, dy: 4)).cgPath
        baseLayer.fillColor = UIColor.white.withAlphaComponent(0.06).cgColor
        baseLayer.strokeColor = UIColor.primary.withAlphaComponent(0.45).cgColor
        baseLayer.lineWidth = 1.5
        layer.addSublayer(baseLayer)

        let stickSize: CGFloat = r * 0.55
        let stickFrame = CGRect(x: bounds.midX - stickSize/2, y: bounds.midY - stickSize/2, width: stickSize, height: stickSize)
        stickView.frame = stickFrame
        stickView.backgroundColor = UIColor.primary.withAlphaComponent(0.45)
        stickView.layer.cornerRadius = stickSize / 2
        stickView.layer.borderColor = UIColor.primary.withAlphaComponent(0.9).cgColor
        stickView.layer.borderWidth = 1.5
        stickView.makeGlow(UIColor.primary, radius: 10, opacity: 0.6)
        addSubview(stickView)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let r = min(bounds.width, bounds.height) / 2
        baseLayer.path = UIBezierPath(ovalIn: bounds.insetBy(dx: 4, dy: 4)).cgPath
        if touchId == nil {
            let stickSize: CGFloat = r * 0.55
            stickView.frame = CGRect(x: bounds.midX - stickSize/2, y: bounds.midY - stickSize/2, width: stickSize, height: stickSize)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touchId == nil, let t = touches.first else { return }
        touchId = t
        updateStick(t)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let t = touches.first, t === touchId { updateStick(t) }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        reset()
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        reset()
    }

    private func updateStick(_ t: UITouch) {
        let p = t.location(in: self)
        let c = CGPoint(x: bounds.midX, y: bounds.midY)
        var dx = p.x - c.x
        var dy = p.y - c.y
        let maxR = min(bounds.width, bounds.height) / 2 - 4
        let dist = sqrt(dx*dx + dy*dy)
        if dist > maxR {
            dx = dx / dist * maxR
            dy = dy / dist * maxR
        }
        stickView.center = CGPoint(x: c.x + dx, y: c.y + dy)
        // y 向上为正
        onChange?(dx / maxR, -dy / maxR)
    }

    private func reset() {
        touchId = nil
        UIView.animate(withDuration: 0.15) {
            self.stickView.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
        }
        onChange?(0, 0)
    }
}
