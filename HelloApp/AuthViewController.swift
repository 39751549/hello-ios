import UIKit

/// 登录 / 注册 界面
final class AuthViewController: UIViewController, UITextFieldDelegate {

    private enum Mode { case login, register }
    private var mode: Mode = .login

    private let scrollView = UIScrollView()
    private let cardView = UIView()
    private let titleLabel = UILabel.make("幻域·神兵", font: .systemFont(ofSize: 38, weight: .heavy), color: .white, alignment: .center)
    private let subtitleLabel = UILabel.make("FANTASY REALM", font: .systemFont(ofSize: 12, weight: .medium), color: UIColor(hex: 0x6b7a8f), alignment: .center)
    private let tabSeg = UISegmentedControl(items: ["登录", "注册"])
    private let userField = UITextField()
    private let passField = UITextField()
    private let nickField = UITextField()
    private let nickContainer = UIView()
    private let submitBtn = UIButton.makeGradient("登 录")
    private let errorLabel = UILabel.make("", font: .systemFont(ofSize: 13), color: .danger, alignment: .center)
    private let serverHintLabel = UILabel.make("", font: .systemFont(ofSize: 10), color: UIColor(hex: 0x4a5568), alignment: .center)

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .bgDark
        setupBackground()
        setupUI()
        applyMode()
        serverHintLabel.text = "Server: " + Config.baseURL.replacingOccurrences(of: "http://", with: "")
    }

    // 背景渐变 + 粒子点缀
    private func setupBackground() {
        let bgView = GradientView()
        bgView.translatesAutoresizingMaskIntoConstraints = false
        bgView.colors = [UIColor(hex: 0x1a2333), UIColor(hex: 0x0a0e1a)]
        bgView.angle = .pi/4
        view.addSubview(bgView)
        NSLayoutConstraint.activate([
            bgView.topAnchor.constraint(equalTo: view.topAnchor),
            bgView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bgView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bgView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        // 远景光晕
        let glow = UIView()
        glow.translatesAutoresizingMaskIntoConstraints = false
        glow.backgroundColor = UIColor.primary.withAlphaComponent(0.18)
        glow.layer.cornerRadius = 200
        glow.layer.masksToBounds = true
        glow.makeGlow(UIColor.primary, radius: 80, opacity: 0.6)
        bgView.addSubview(glow)
        NSLayoutConstraint.activate([
            glow.centerXAnchor.constraint(equalTo: bgView.centerXAnchor),
            glow.topAnchor.constraint(equalTo: bgView.topAnchor, constant: -60),
            glow.widthAnchor.constraint(equalToConstant: 400),
            glow.heightAnchor.constraint(equalToConstant: 400),
        ])
    }

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.setCardStyle(cornerRadius: 18, border: .primary, borderWidth: 0.8, alpha: 0.85)
        scrollView.addSubview(cardView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)
        titleLabel.layer.shadowColor = UIColor.primary.cgColor
        titleLabel.layer.shadowRadius = 14
        titleLabel.layer.shadowOpacity = 0.55
        titleLabel.layer.shadowOffset = .zero

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.layer.opacity = 0.7
        cardView.addSubview(subtitleLabel)

        tabSeg.translatesAutoresizingMaskIntoConstraints = false
        tabSeg.selectedSegmentIndex = 0
        tabSeg.backgroundColor = UIColor(hex: 0x0f141e)
        tabSeg.selectedSegmentTintColor = .primary
        tabSeg.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 14, weight: .medium)], for: .normal)
        tabSeg.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 14, weight: .bold)], for: .selected)
        tabSeg.addTarget(self, action: #selector(tabChanged), for: .valueChanged)
        cardView.addSubview(tabSeg)

        configureField(userField, placeholder: "账号 (≥3位,字母数字下划线)")
        configureField(passField, placeholder: "密码 (≥6位)", isPassword: true)
        configureField(nickField, placeholder: "昵称 (选填,默认账号)")

        let userWrap = wrapField(userField, icon: "person.fill")
        let passWrap = wrapField(passField, icon: "lock.fill")
        nickContainer.translatesAutoresizingMaskIntoConstraints = false
        nickContainer.backgroundColor = .clear
        nickContainer.isHidden = true
        let nickWrap = wrapField(nickField, icon: "sparkles")
        nickContainer.addSubview(nickWrap)
        NSLayoutConstraint.activate([
            nickWrap.topAnchor.constraint(equalTo: nickContainer.topAnchor),
            nickWrap.bottomAnchor.constraint(equalTo: nickContainer.bottomAnchor),
            nickWrap.leadingAnchor.constraint(equalTo: nickContainer.leadingAnchor),
            nickWrap.trailingAnchor.constraint(equalTo: nickContainer.trailingAnchor),
        ])

        submitBtn.translatesAutoresizingMaskIntoConstraints = false
        submitBtn.addTarget(self, action: #selector(submit), for: .touchUpInside)

        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.numberOfLines = 0
        errorLabel.preferredMaxLayoutWidth = 320

        serverHintLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [userWrap, passWrap, nickContainer, errorLabel, submitBtn, serverHintLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(10, after: errorLabel)
        cardView.addSubview(stack)

        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            cardView.topAnchor.constraint(greaterThanOrEqualTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            cardView.bottomAnchor.constraint(lessThanOrEqualTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            cardView.centerYAnchor.constraint(equalTo: scrollView.contentLayoutGuide.centerYAnchor),
            cardView.widthAnchor.constraint(equalToConstant: 380),

            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 26),
            titleLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),

            tabSeg.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 18),
            tabSeg.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 28),
            tabSeg.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -28),
            tabSeg.heightAnchor.constraint(equalToConstant: 32),

            stack.topAnchor.constraint(equalTo: tabSeg.bottomAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -28),
            stack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -22),
        ])

        [userField, passField, nickField].forEach { $0.delegate = self }
        let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing))
        view.addGestureRecognizer(tap)
        NotificationCenter.default.addObserver(self, selector: #selector(kbShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(kbHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    private func configureField(_ f: UITextField, placeholder: String, isPassword: Bool = false) {
        f.translatesAutoresizingMaskIntoConstraints = false
        f.placeholder = placeholder
        f.font = .systemFont(ofSize: 15)
        f.textColor = .white
        f.isSecureTextEntry = isPassword
        f.autocapitalizationType = .none
        f.autocorrectionType = .no
        f.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [.foregroundColor: UIColor(hex: 0x6b7a8f)])
    }

    private func wrapField(_ f: UITextField, icon: String) -> UIView {
        let wrap = UIView()
        wrap.translatesAutoresizingMaskIntoConstraints = false
        wrap.backgroundColor = UIColor(hex: 0x0f141e).withAlphaComponent(0.8)
        wrap.layer.cornerRadius = 10
        wrap.layer.borderColor = UIColor.primary.withAlphaComponent(0.2).cgColor
        wrap.layer.borderWidth = 1
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = .primary
        iconView.contentMode = .scaleAspectFit
        wrap.addSubview(iconView)
        wrap.addSubview(f)
        NSLayoutConstraint.activate([
            wrap.heightAnchor.constraint(equalToConstant: 48),
            iconView.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: wrap.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),
            f.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            f.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -14),
            f.topAnchor.constraint(equalTo: wrap.topAnchor),
            f.bottomAnchor.constraint(equalTo: wrap.bottomAnchor),
        ])
        return wrap
    }

    private func applyMode() {
        nickContainer.isHidden = (mode != .register)
        submitBtn.setTitle(mode == .login ? "登 录" : "注 册", for: .normal)
        errorLabel.text = ""
    }

    @objc private func tabChanged() {
        mode = tabSeg.selectedSegmentIndex == 0 ? .login : .register
        applyMode()
    }

    @objc private func submit() {
        guard let u = userField.text?.trimmingCharacters(in: .whitespaces), u.isValidUsername else {
            errorLabel.text = "账号至少3位,仅字母/数字/下划线"; return
        }
        guard let p = passField.text, p.count >= 6 else {
            errorLabel.text = "密码至少6位"; return
        }
        view.endEditing(true)
        errorLabel.text = ""
        submitBtn.isEnabled = false
        submitBtn.alpha = 0.6
        let handler: (Result<AuthData, APIError>) -> Void = { [weak self] res in
            guard let self = self else { return }
            self.submitBtn.isEnabled = true
            self.submitBtn.alpha = 1
            switch res {
            case .success:
                self.enterGame()
            case .failure(let err):
                self.errorLabel.text = err.errorDescription
            }
        }
        if mode == .login {
            APIClient.shared.login(username: u, password: p, completion: handler)
        } else {
            let nick = nickField.text?.trimmingCharacters(in: .whitespaces)
            APIClient.shared.register(username: u, password: p, nickname: nick, completion: handler)
        }
    }

    private func enterGame() {
        let gvc = GameViewController()
        gvc.modalPresentationStyle = .fullScreen
        present(gvc, animated: true) { [weak self] in
            self?.userField.text = nil
            self?.passField.text = nil
            self?.nickField.text = nil
        }
    }

    @objc private func kbShow(_ n: Notification) {
        guard let frame = (n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        let insets = UIEdgeInsets(top: 0, left: 0, bottom: frame.height + 20, right: 0)
        scrollView.contentInset = insets
        scrollView.scrollIndicatorInsets = insets
    }
    @objc private func kbHide() {
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == userField { passField.becomeFirstResponder() }
        else if textField == passField {
            if mode == .register { nickField.becomeFirstResponder() } else { submit() }
        } else { submit() }
        return true
    }
}
