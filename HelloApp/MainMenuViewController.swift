import UIKit

/// Old Money 主菜单
final class MainMenuViewController: UIViewController {

    private let bgView = GradientView()
    private let logoView = UIImageView()
    private let titleLabel = UILabel.make("OLD MONEY", font: UIFont(name: "Didot-Bold", size: 44) ?? .systemFont(ofSize: 40, weight: .heavy), color: UIColor(hex: 0xf5e6c8), alignment: .center)
    private let subtitleLabel = UILabel.make("豪门征途", font: .systemFont(ofSize: 16, weight: .medium), color: UIColor(hex: 0xc9a227), alignment: .center)
    private let playBtn = UIButton.makeGradient("开始冒险 · 单机", color1: UIColor(hex: 0xc9a227), color2: UIColor(hex: 0x8b6914), height: 54)
    private let onlineBtn = UIButton(type: .system)
    private let versionLabel = UILabel.make("v\(Config.versionString) 单机版", font: .systemFont(ofSize: 10), color: UIColor(hex: 0x5a6a5e), alignment: .center)
    private var floatingLayers: [CALayer] = []

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        SoundManager.shared.play(.button)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        floatingLayers.forEach { $0.removeFromSuperlayer() }
        floatingLayers.removeAll()
        for _ in 0..<18 {
            let l = CALayer()
            let s = CGFloat.random(in: 2...5)
            l.frame = CGRect(x: CGFloat.random(in: 0...view.bounds.width),
                             y: CGFloat.random(in: 0...view.bounds.height),
                             width: s, height: s)
            l.backgroundColor = UIColor.gold.withAlphaComponent(CGFloat.random(in: 0.15...0.45)).cgColor
            l.cornerRadius = s / 2
            view.layer.insertSublayer(l, above: bgView.layer)
            floatingLayers.append(l)
            animateFloat(l)
        }
    }

    private func setupUI() {
        bgView.translatesAutoresizingMaskIntoConstraints = false
        bgView.colors = [UIColor(hex: 0x0d1f17), UIColor(hex: 0x0a0e14), UIColor(hex: 0x1a1408)]
        view.addSubview(bgView)

        logoView.translatesAutoresizingMaskIntoConstraints = false
        logoView.image = UIImage(named: "AppLogo")
        logoView.contentMode = .scaleAspectFill
        logoView.clipsToBounds = true
        logoView.layer.cornerRadius = 22
        logoView.layer.borderWidth = 2
        logoView.layer.borderColor = UIColor(hex: 0xc9a227).cgColor
        logoView.makeGlow(.gold, radius: 16, opacity: 0.6)
        view.addSubview(logoView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.layer.shadowColor = UIColor.gold.cgColor
        titleLabel.layer.shadowRadius = 12
        titleLabel.layer.shadowOpacity = 0.7
        titleLabel.layer.shadowOffset = .zero
        view.addSubview(titleLabel)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)

        playBtn.translatesAutoresizingMaskIntoConstraints = false
        playBtn.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        playBtn.layer.cornerRadius = 14
        playBtn.makeGlow(UIColor(hex: 0xc9a227), radius: 14, opacity: 0.55)
        playBtn.addTarget(self, action: #selector(startOffline), for: .touchUpInside)
        view.addSubview(playBtn)

        onlineBtn.translatesAutoresizingMaskIntoConstraints = false
        onlineBtn.setTitle("在线联机 · 登录", for: .normal)
        onlineBtn.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        onlineBtn.setTitleColor(UIColor(hex: 0x8ba88e), for: .normal)
        onlineBtn.backgroundColor = UIColor(hex: 0x141a16).withAlphaComponent(0.8)
        onlineBtn.layer.cornerRadius = 10
        onlineBtn.layer.borderWidth = 1
        onlineBtn.layer.borderColor = UIColor(hex: 0x3a4a3e).cgColor
        onlineBtn.addTarget(self, action: #selector(openOnline), for: .touchUpInside)
        view.addSubview(onlineBtn)

        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(versionLabel)

        NSLayoutConstraint.activate([
            bgView.topAnchor.constraint(equalTo: view.topAnchor),
            bgView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bgView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bgView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            logoView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoView.topAnchor.constraint(equalTo: view.topAnchor, constant: 36),
            logoView.widthAnchor.constraint(equalToConstant: 88),
            logoView.heightAnchor.constraint(equalToConstant: 88),

            titleLabel.topAnchor.constraint(equalTo: logoView.bottomAnchor, constant: 14),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            playBtn.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playBtn.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -52),
            playBtn.widthAnchor.constraint(equalToConstant: 280),

            onlineBtn.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            onlineBtn.topAnchor.constraint(equalTo: playBtn.bottomAnchor, constant: 12),
            onlineBtn.widthAnchor.constraint(equalToConstant: 200),
            onlineBtn.heightAnchor.constraint(equalToConstant: 36),

            versionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            versionLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
        ])

        // 入场动画
        playBtn.alpha = 0
        playBtn.transform = CGAffineTransform(translationX: 0, y: 30)
        onlineBtn.alpha = 0
        UIView.animate(withDuration: 0.7, delay: 0.2, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.playBtn.alpha = 1
            self.playBtn.transform = .identity
            self.onlineBtn.alpha = 1
        }
    }

    private func animateFloat(_ layer: CALayer) {
        let anim = CABasicAnimation(keyPath: "position.y")
        anim.fromValue = layer.position.y
        anim.toValue = layer.position.y - CGFloat.random(in: 20...50)
        anim.duration = Double.random(in: 3...6)
        anim.autoreverses = true
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(anim, forKey: "float")
    }

    @objc private func startOffline() {
        SoundManager.shared.play(.button)
        LocalGameManager.shared.ensurePlayer()
        let game = GameViewController()
        game.isOfflineMode = true
        game.modalPresentationStyle = .fullScreen
        game.modalTransitionStyle = .crossDissolve
        present(game, animated: true)
    }

    @objc private func openOnline() {
        SoundManager.shared.play(.button)
        let auth = AuthViewController()
        auth.modalPresentationStyle = .fullScreen
        auth.modalTransitionStyle = .crossDissolve
        present(auth, animated: true)
    }
}
