import UIKit
import Messages

final class MessagesViewController: MSMessagesAppViewController {
    private let gold = UIColor(red: 0.88, green: 0.66, blue: 0.28, alpha: 1)
    private let panel = UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)
    private var score = 0
    private var selectedGame = "恐龍跳躍"
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let scoreLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    private let walletButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        buildInterface()
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        preferredContentSize = CGSize(width: 0, height: 390)
    }

    private func buildInterface() {
        view.backgroundColor = UIColor(red: 0.055, green: 0.06, blue: 0.07, alpha: 1)
        let header = UILabel()
        header.text = "SUPER DASHBOARD"
        header.font = .systemFont(ofSize: 11, weight: .bold)
        header.textColor = gold
        header.textAlignment = .center

        titleLabel.text = "訊息小遊戲"
        titleLabel.font = .systemFont(ofSize: 23, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center

        subtitleLabel.text = "選一款遊戲，挑戰朋友"
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center

        let gameRow = UIStackView()
        gameRow.axis = .horizontal
        gameRow.spacing = 10
        gameRow.distribution = .fillEqually
        gameRow.addArrangedSubview(makeGameButton("🦖", "恐龍跳躍"))
        gameRow.addArrangedSubview(makeGameButton("🦆", "鴨子跳躍"))

        let gamePanel = UIView()
        gamePanel.backgroundColor = panel
        gamePanel.layer.cornerRadius = 20
        gamePanel.addSubview(gameRow)
        gameRow.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            gameRow.topAnchor.constraint(equalTo: gamePanel.topAnchor, constant: 14),
            gameRow.bottomAnchor.constraint(equalTo: gamePanel.bottomAnchor, constant: -14),
            gameRow.leadingAnchor.constraint(equalTo: gamePanel.leadingAnchor, constant: 14),
            gameRow.trailingAnchor.constraint(equalTo: gamePanel.trailingAnchor, constant: -14),
            gameRow.heightAnchor.constraint(equalToConstant: 76)
        ])

        scoreLabel.text = "目前分數　0"
        scoreLabel.textColor = .white
        scoreLabel.font = .systemFont(ofSize: 19, weight: .semibold)
        scoreLabel.textAlignment = .center

        actionButton.setTitle("跳一下　＋1", for: .normal)
        actionButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        actionButton.backgroundColor = gold
        actionButton.setTitleColor(.black, for: .normal)
        actionButton.layer.cornerRadius = 14
        actionButton.addTarget(self, action: #selector(jump), for: .touchUpInside)

        walletButton.setTitle("▣　分享錢包票卡", for: .normal)
        walletButton.setTitleColor(gold, for: .normal)
        walletButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        walletButton.backgroundColor = panel
        walletButton.layer.cornerRadius = 14
        walletButton.addTarget(self, action: #selector(shareWallet), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [header, titleLabel, subtitleLabel, gamePanel, scoreLabel, actionButton, walletButton])
        stack.axis = .vertical
        stack.spacing = 13
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),
            actionButton.heightAnchor.constraint(equalToConstant: 48),
            walletButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    private func makeGameButton(_ emoji: String, _ name: String) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor(red: 0.19, green: 0.18, blue: 0.16, alpha: 1)
        button.layer.cornerRadius = 14
        button.titleLabel?.numberOfLines = 2
        button.titleLabel?.textAlignment = .center
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        button.setTitle("\(emoji)\n\(name)", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.addAction(UIAction { [weak self] _ in
            self?.selectedGame = name
            self?.score = 0
            self?.titleLabel.text = name
            self?.scoreLabel.text = "目前分數　0"
        }, for: .touchUpInside)
        return button
    }

    @objc private func jump() {
        score += 1
        scoreLabel.text = "目前分數　\(score)"
        subtitleLabel.text = score >= 10 ? "太強了！把成績傳給朋友" : "連續跳躍，看看能拿幾分"
        actionButton.setTitle("再跳一下　＋1", for: .normal)
        if score >= 3 { actionButton.setTitle("分享 \(score) 分成績", for: .normal) }
        if score >= 3 {
            actionButton.removeTarget(self, action: #selector(jump), for: .touchUpInside)
            actionButton.addTarget(self, action: #selector(shareScore), for: .touchUpInside)
        }
    }

    @objc private func shareScore() {
        guard let conversation = activeConversation else { return }
        let message = MSMessage()
        let layout = MSMessageTemplateLayout()
        layout.caption = "我在\(selectedGame)得到 \(score) 分！"
        layout.subcaption = "換你挑戰 Super Dashboard"
        message.layout = layout
        var components = URLComponents()
        components.scheme = "superdashboard"
        components.host = "messages"
        components.queryItems = [URLQueryItem(name: "game", value: selectedGame), URLQueryItem(name: "score", value: String(score))]
        message.url = components.url
        conversation.insert(message) { _ in }
    }

    @objc private func shareWallet() {
        guard let conversation = activeConversation else { return }
        let defaults = UserDefaults(suiteName: "group.com.steveplayer87.superdashboard")
        let entries = defaults?.dictionaryRepresentation().keys.filter { $0.localizedCaseInsensitiveContains("wallet") || $0.localizedCaseInsensitiveContains("card") } ?? []
        guard !entries.isEmpty else {
            conversation.insertText("我的 Super Dashboard 數位錢包：目前尚未找到可供 iMessage 分享的票卡資料。") { _ in }
            return
        }
        conversation.insertText("分享自 Super Dashboard 數位錢包") { _ in }
    }
}
