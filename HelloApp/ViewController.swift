import UIKit

class ViewController: UIViewController {

    private let helloButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("点我", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 22, weight: .semibold)
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "首页"
        view.backgroundColor = .systemBackground

        view.addSubview(helloButton)
        NSLayoutConstraint.activate([
            helloButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            helloButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            helloButton.widthAnchor.constraint(equalToConstant: 200),
            helloButton.heightAnchor.constraint(equalToConstant: 60)
        ])

        helloButton.addTarget(self, action: #selector(showHello), for: .touchUpInside)
    }

    @objc private func showHello() {
        let alert = UIAlertController(title: nil, message: "你好", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好的", style: .default))
        present(alert, animated: true)
    }
}
