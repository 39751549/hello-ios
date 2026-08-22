import UIKit

/// Old Money 炫酷开屏动画
final class SplashViewController: UIViewController {

    private let bgGradient = GradientView()
    private let vignette = UIView()
    private let logoContainer = UIView()
    private let logoImage = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let taglineLabel = UILabel()
    private let shimmerLayer = CAGradientLayer()
    private let particleHost = UIView()
    private var goldEmitter: CAEmitterLayer?
    private var sparkEmitter: CAEmitterLayer?

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackground()
        setupParticles()
        setupLogo()
        setupTitles()
        setupShimmer()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startAnimation()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        shimmerLayer.frame = titleLabel.frame.insetBy(dx: -40, dy: -8)
        goldEmitter?.emitterPosition = CGPoint(x: view.bounds.midX, y: -20)
        goldEmitter?.emitterSize = CGSize(width: view.bounds.width, height: 1)
        sparkEmitter?.emitterPosition = CGPoint(x: view.bounds.midX, y: view.bounds.height + 10)
        sparkEmitter?.emitterSize = CGSize(width: view.bounds.width * 0.6, height: 1)
    }

    private func setupBackground() {
        bgGradient.translatesAutoresizingMaskIntoConstraints = false
        bgGradient.colors = [
            UIColor(hex: 0x0d1f17),
            UIColor(hex: 0x0a0e14),
            UIColor(hex: 0x14100a),
        ]
        bgGradient.angle = .pi / 3
        view.addSubview(bgGradient)

        vignette.translatesAutoresizingMaskIntoConstraints = false
        vignette.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        view.addSubview(vignette)

        particleHost.translatesAutoresizingMaskIntoConstraints = false
        particleHost.isUserInteractionEnabled = false
        view.addSubview(particleHost)

        NSLayoutConstraint.activate([
            bgGradient.topAnchor.constraint(equalTo: view.topAnchor),
            bgGradient.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bgGradient.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bgGradient.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            vignette.topAnchor.constraint(equalTo: view.topAnchor),
            vignette.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            vignette.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            vignette.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            particleHost.topAnchor.constraint(equalTo: view.topAnchor),
            particleHost.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            particleHost.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            particleHost.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        // 远景光晕
        let glow1 = makeGlow(color: UIColor(hex: 0xc9a227), size: 320, alpha: 0.22)
        glow1.center = CGPoint(x: view.bounds.width * 0.28, y: view.bounds.height * 0.35)
        view.insertSubview(glow1, aboveSubview: bgGradient)

        let glow2 = makeGlow(color: UIColor(hex: 0x2e5e3a), size: 400, alpha: 0.28)
        glow2.center = CGPoint(x: view.bounds.width * 0.72, y: view.bounds.height * 0.55)
        view.insertSubview(glow2, aboveSubview: bgGradient)
    }

    private func makeGlow(color: UIColor, size: CGFloat, alpha: CGFloat) -> UIView {
        let v = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        v.backgroundColor = color.withAlphaComponent(alpha)
        v.layer.cornerRadius = size / 2
        v.makeGlow(color, radius: size * 0.35, opacity: 0.7)
        return v
    }

    private func setupParticles() {
        let gold = CAEmitterLayer()
        gold.emitterShape = .line
        gold.birthRate = 1
        let coin = CAEmitterCell()
        coin.birthRate = 8
        coin.lifetime = 6
        coin.velocity = 40
        coin.velocityRange = 30
        coin.emissionLongitude = .pi
        coin.emissionRange = .pi / 6
        coin.spin = 1.5
        coin.spinRange = 2
        coin.scale = 0.06
        coin.scaleRange = 0.03
        coin.alphaSpeed = -0.12
        coin.contents = makeParticleImage(color: UIColor(hex: 0xffd54f), size: 24).cgImage
        gold.emitterCells = [coin]
        particleHost.layer.addSublayer(gold)
        goldEmitter = gold

        let sparks = CAEmitterLayer()
        sparks.emitterShape = .line
        sparks.birthRate = 1
        let spark = CAEmitterCell()
        spark.birthRate = 14
        spark.lifetime = 2.5
        spark.velocity = -60
        spark.velocityRange = 40
        spark.yAcceleration = -20
        spark.emissionRange = .pi / 4
        spark.scale = 0.04
        spark.scaleRange = 0.02
        spark.alphaSpeed = -0.35
        spark.contents = makeParticleImage(color: UIColor(hex: 0xfff8e1), size: 12).cgImage
        sparks.emitterCells = [spark]
        particleHost.layer.addSublayer(sparks)
        sparkEmitter = sparks
    }

    private func makeParticleImage(color: UIColor, size: CGFloat) -> UIImage {
        let s = CGSize(width: size, height: size)
        return UIGraphicsImageRenderer(size: s).image { ctx in
            color.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: s))
        }
    }

    private func setupLogo() {
        logoContainer.translatesAutoresizingMaskIntoConstraints = false
        logoContainer.alpha = 0
        logoContainer.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        view.addSubview(logoContainer)

        logoImage.translatesAutoresizingMaskIntoConstraints = false
        logoImage.contentMode = .scaleAspectFill
        logoImage.clipsToBounds = true
        logoImage.layer.cornerRadius = 28
        logoImage.layer.borderWidth = 3
        logoImage.layer.borderColor = UIColor(hex: 0xc9a227).cgColor
        logoImage.image = UIImage(named: "AppLogo") ?? UIImage(named: "AppIcon-1024")
        logoImage.makeGlow(UIColor.gold, radius: 24, opacity: 0.85)
        logoContainer.addSubview(logoImage)

        NSLayoutConstraint.activate([
            logoContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -36),
            logoImage.widthAnchor.constraint(equalToConstant: 112),
            logoImage.heightAnchor.constraint(equalToConstant: 112),
            logoImage.topAnchor.constraint(equalTo: logoContainer.topAnchor),
            logoImage.bottomAnchor.constraint(equalTo: logoContainer.bottomAnchor),
            logoImage.leadingAnchor.constraint(equalTo: logoContainer.leadingAnchor),
            logoImage.trailingAnchor.constraint(equalTo: logoContainer.trailingAnchor),
        ])
    }

    private func setupTitles() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "OLD MONEY"
        titleLabel.font = UIFont(name: "Didot-Bold", size: 52) ?? .systemFont(ofSize: 48, weight: .heavy)
        titleLabel.textColor = UIColor(hex: 0xf5e6c8)
        titleLabel.textAlignment = .center
        titleLabel.alpha = 0
        titleLabel.layer.shadowColor = UIColor.gold.cgColor
        titleLabel.layer.shadowRadius = 16
        titleLabel.layer.shadowOpacity = 0.9
        titleLabel.layer.shadowOffset = .zero
        view.addSubview(titleLabel)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "WEALTH · POWER · LEGACY"
        subtitleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        subtitleLabel.textColor = UIColor(hex: 0xc9a227).withAlphaComponent(0.85)
        subtitleLabel.textAlignment = .center
        subtitleLabel.alpha = 0
        view.addSubview(subtitleLabel)

        taglineLabel.translatesAutoresizingMaskIntoConstraints = false
        taglineLabel.text = "豪门征途 · 单机冒险"
        taglineLabel.font = .systemFont(ofSize: 14, weight: .medium)
        taglineLabel.textColor = UIColor(hex: 0x8ba88e)
        taglineLabel.textAlignment = .center
        taglineLabel.alpha = 0
        view.addSubview(taglineLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: logoContainer.bottomAnchor, constant: 22),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            taglineLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 14),
            taglineLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    private func setupShimmer() {
        shimmerLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(0.55).cgColor,
            UIColor.clear.cgColor,
        ]
        shimmerLayer.startPoint = CGPoint(x: 0, y: 0.5)
        shimmerLayer.endPoint = CGPoint(x: 1, y: 0.5)
        shimmerLayer.locations = [0, 0.5, 1]
        titleLabel.layer.addSublayer(shimmerLayer)
        shimmerLayer.isHidden = true
    }

    private func startAnimation() {
        UIView.animate(withDuration: 0.9, delay: 0.1, usingSpringWithDamping: 0.72, initialSpringVelocity: 0.6) {
            self.logoContainer.alpha = 1
            self.logoContainer.transform = .identity
        }

        UIView.animate(withDuration: 0.7, delay: 0.55, options: .curveEaseOut) {
            self.titleLabel.alpha = 1
            self.titleLabel.transform = CGAffineTransform(translationX: 0, y: -4)
        } completion: { _ in
            self.titleLabel.transform = .identity
            self.shimmerLayer.isHidden = false
            let anim = CABasicAnimation(keyPath: "locations")
            anim.fromValue = [-0.4, -0.15, 0.1]
            anim.toValue = [0.9, 1.15, 1.4]
            anim.duration = 1.4
            anim.repeatCount = 2
            self.shimmerLayer.add(anim, forKey: "shimmer")
        }

        UIView.animate(withDuration: 0.6, delay: 0.85) {
            self.subtitleLabel.alpha = 1
        }
        UIView.animate(withDuration: 0.6, delay: 1.05) {
            self.taglineLabel.alpha = 1
        }

        // 脉冲光环
        let ring = UIView(frame: CGRect(x: 0, y: 0, width: 140, height: 140))
        ring.center = logoContainer.center
        ring.layer.cornerRadius = 70
        ring.layer.borderWidth = 2
        ring.layer.borderColor = UIColor.gold.withAlphaComponent(0.6).cgColor
        ring.alpha = 0
        view.insertSubview(ring, belowSubview: logoContainer)
        UIView.animate(withDuration: 1.2, delay: 0.4) {
            ring.alpha = 0.8
            ring.transform = CGAffineTransform(scaleX: 2.2, y: 2.2)
        } completion: { _ in
            UIView.animate(withDuration: 0.5) { ring.alpha = 0 }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { [weak self] in
            self?.goToMainMenu()
        }
    }

    private func goToMainMenu() {
        let menu = MainMenuViewController()
        menu.modalPresentationStyle = .fullScreen
        menu.modalTransitionStyle = .crossDissolve
        present(menu, animated: true)
    }
}
