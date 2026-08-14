import UIKit

/// 右上角小地图: 显示玩家(中心) + 怪物/Boss位置
final class MinimapView: UIView {

    /// 外部传入的实体数据
    struct Dot {
        let x: Float       // 世界坐标 x
        let z: Float       // 世界坐标 z
        let color: UIColor
        let size: CGFloat  // 点大小
    }

    private let mapHalf: Float = 18
    private var dots: [Dot] = []
    private var playerPos: SIMD2<Float> = SIMD2(0, 6)
    private let dotsLayer = CALayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.bgDark.withAlphaComponent(0.7)
        layer.cornerRadius = 8
        layer.borderColor = UIColor.primary.withAlphaComponent(0.4).cgColor
        layer.borderWidth = 1
        layer.applyShadow(opacity: 0.5, radius: 8)

        let bg = UIView()
        bg.translatesAutoresizingMaskIntoConstraints = false
        bg.backgroundColor = UIColor(hex: 0x1a2b1a).withAlphaComponent(0.6)
        bg.layer.cornerRadius = 6
        bg.layer.borderColor = UIColor(hex: 0x2a4a2e).cgColor
        bg.layer.borderWidth = 0.5
        addSubview(bg)
        NSLayoutConstraint.activate([
            bg.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            bg.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            bg.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
            bg.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
        ])

        // 标题
        let titleL = UILabel.make("MAP", font: .systemFont(ofSize: 8, weight: .bold), color: UIColor.primary.withAlphaComponent(0.8), alignment: .center)
        titleL.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleL)
        NSLayoutConstraint.activate([
            titleL.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            titleL.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    /// 更新小地图数据
    func update(playerX: Float, playerZ: Float, monsters: [(x: Float, z: Float, color: UIColor, isBoss: Bool, alive: Bool)]) {
        self.playerPos = SIMD2(playerX, playerZ)
        var ds: [Dot] = []
        for m in monsters where m.alive {
            ds.append(Dot(x: m.x, z: m.z, color: m.color, size: m.isBoss ? 6 : 4))
        }
        self.dots = ds
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let drawRect = rect.insetBy(dx: 3, dy: 3)
        let cx = drawRect.midX
        let cy = drawRect.midY
        let scale = Float(min(drawRect.width, drawRect.height)) / (mapHalf * 2)

        // 网格线
        ctx.setStrokeColor(UIColor(hex: 0x2a4a2e).withAlphaComponent(0.4).cgColor)
        ctx.setLineWidth(0.5)
        for i in 0...4 {
            let t = CGFloat(i) / 4
            let x = drawRect.minX + drawRect.width * t
            let y = drawRect.minY + drawRect.height * t
            ctx.move(to: CGPoint(x: x, y: drawRect.minY))
            ctx.addLine(to: CGPoint(x: x, y: drawRect.maxY))
            ctx.move(to: CGPoint(x: drawRect.minX, y: y))
            ctx.addLine(to: CGPoint(x: drawRect.maxX, y: y))
        }
        ctx.strokePath()

        // 怪物点(相对玩家)
        for d in dots {
            let rx = (d.x - playerPos.x) * scale
            let rz = (d.z - playerPos.z) * scale
            let px = cx + CGFloat(rx)
            let py = cy - CGFloat(rz) // z 向上 = 屏幕向上
            // 只画在范围内的
            if drawRect.insetBy(dx: 2, dy: 2).contains(CGPoint(x: px, y: py)) {
                ctx.setFillColor(d.color.cgColor)
                ctx.fillEllipse(in: CGRect(x: px - d.size/2, y: py - d.size/2, width: d.size, height: d.size))
                if d.size > 5 {
                    // Boss 加发光环
                    ctx.setStrokeColor(d.color.withAlphaComponent(0.5).cgColor)
                    ctx.setLineWidth(1)
                    ctx.strokeEllipse(in: CGRect(x: px - d.size, y: py - d.size, width: d.size*2, height: d.size*2))
                }
            }
        }

        // 玩家(中心,三角形朝上)
        ctx.setFillColor(UIColor.primary.cgColor)
        let r: CGFloat = 5
        ctx.move(to: CGPoint(x: cx, y: cy - r))
        ctx.addLine(to: CGPoint(x: cx - r * 0.7, y: cy + r * 0.7))
        ctx.addLine(to: CGPoint(x: cx + r * 0.7, y: cy + r * 0.7))
        ctx.closePath()
        ctx.fillPath()
        // 玩家发光环
        ctx.setStrokeColor(UIColor.primary.withAlphaComponent(0.5).cgColor)
        ctx.setLineWidth(1)
        ctx.strokeEllipse(in: CGRect(x: cx - r - 2, y: cy - r - 2, width: (r+2)*2, height: (r+2)*2))
    }
}
