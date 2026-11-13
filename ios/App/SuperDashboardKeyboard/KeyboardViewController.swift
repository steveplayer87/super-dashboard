import UIKit

private struct ClipItem: Codable {
    let id: String
    let label: String
    let text: String
    let category: String
    let type: String?
}
private struct HistoryItem: Codable {
    let id: String
    let kind: String
    let text: String?
    let imageFile: String?
    let createdAt: Date
}

final class KeyboardViewController: UIInputViewController {
    private let groupID = "group.com.steveplayer87.superdashboard"
    private let storeKey = "keyboardQuickCopyItems"
    private let historyKey = "keyboardClipboardHistory"
    private let recentEmojiKey = "keyboardRecentEmojis"
    private let recentEmojiFile = "keyboardRecentEmojis.json"
    private let emojiBarEnabledKey = "keyboardEmojiBarEnabled"
    private var emojiBarEnabled = true
    private let contentArea = UIView()
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private var shortcuts: [ClipItem] = []
    private var history: [HistoryItem] = []
    private var recentEmojiCounts: [String: Int] = [:]
    private var selectedSection = "home"
    private var selectedEmojiCategory = 0
    private let root = UIStackView()
    private let header = UIStackView()
    private let contentScroll = UIScrollView()
    private let content = UIStackView()
    private let emojiPager = UIScrollView()
    private let emojiPageStack = UIStackView()
    private var emojiPageCategories: [Int] = []
    private var emojiPageItems: [[String]] = []
    private var isAdjustingEmojiPager = false
    private let dock = UIStackView()
    private var dockButtons: [UIButton] = []
    private let refreshButton = UIButton(type: .system)
    private let titleButton = UIButton(type: .system)
    private let backspaceButton = UIButton(type: .system)
    private var backspaceTimer: Timer?
    private var backspaceInitialDelay: Timer?
    private var emojiPagesBuilt = false
    private let glass = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private let emojiCategories: [(String, String)] = [
        ("face.smiling", "😮 😃 😄 😁 😆 😅 😂 🤣 🥲 ☺️ 😊 😇 🙂 🙃 😉 😌 😍 🥰 😘 😗 😙 😚 😋 😛 😝 😜 🤪 🤨 🧐 🤓 😎 🥸 🤩 🥳 😏 😒 😞 😔 😟 😕 🙁 ☹️ 😣 😖 😫 😩 🥺 😢 😭 😤 😠 😡 🤬 🤯 😳 🥵 🥶 😱 😨 😰 😥 😓 🤗 🤔 🫣 🤭 🫢 🫡 🤫 🫠 🫥 😶‍🌫️ 😴 🥱 🤤 😪"),
        ("pawprint.fill", "🐾 🐶 🐭 🐹 🐰 🦊 🐻 🐼 🐻‍❄️ 🐨 🐯 🦁 🐮 🐷 🐸 🐵 🙈 🙉 🙊 🐔 🐧 🐦 🐤 🦆 🦅 🦉 🦇 🐺 🐗 🐴 🦄 🐝 🪱 🦋 🐌 🐞 🐜 🪰 🪲 🪳 🦟 🦗 🕷️ 🦂 🐢 🐍 🦎 🐙 🦑 🦀 🦞 🦐 🐠 🐟 🐬 🐳 🦈 🐊"),
        ("apple.logo", "🍏 🍎 🍐 🍊 🍋 🍌 🍉 🍇 🍓 🫐 🍈 🍒 🍑 🥭 🍍 🥥 🥝 🍅 🥑 🍆 🥦 🥬 🥒 🌶️ 🫑 🌽 🥕 🧄 🧅 🥔 🍠 🥐 🍞 🥖 🧀 🥚 🍳 🥞 🧇 🥓 🥩 🍗 🍖 🌭 🍔 🍟 🍕 🥪 🌮 🌯 🥗 🍝 🍜 🍣 🍱 🥟 🍦 🍰 🎂 🍪 🍩 🍫 🍿 ☕ 🧋"),
        ("soccerball", "⚽ 🏀 🏈 ⚾ 🎾 🏐 🏉 🎱 🏓 🏸 🥅 🏒 🏑 🥍 🏏 🪃 🥊 🥋 🛹 🛼 ⛸️ 🎿 ⛷️ 🏂 🏋️ 🤼 🤸 ⛹️ 🤺 🏌️ 🏇 🧘 🏄 🏊 🚴 🏆 🥇 🥈 🥉 🏅 🎖️ 🎗️"),
        ("car.fill", "🚗 🚕 🚙 🚌 🚎 🏎️ 🚓 🚑 🚒 🚐 🛻 🚚 🚛 🚜 🛵 🏍️ 🚲 🛴 🚂 🚆 🚄 🚅 🚇 🚈 🚉 ✈️ 🛫 🛬 🚀 🛸 🚁 ⛵ 🚤 🛥️ 🚢 ⚓"),
        ("lightbulb", "⌚ 📱 💻 ⌨️ 🖥️ 🖨️ 🖱️ 🕹️ 💽 💾 📷 📸 📹 🎥 📺 📻 🎙️ 🎧 🎤 🎼 🎹 🥁 🎸 🎺 🎷 🎻 📚 📖 ✏️ 🖊️ 🖋️ 📝 📌 📎 🔒 🔑 🔨 ⚙️ 🧰 💡 🔦 💸 💳 🧾 📦 🎁"),
        ("heart.fill", "❤️ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 💔 ❣️ 💕 💞 💓 💗 💖 💘 💝 💟 💢 💥 💫 💦 💨 🕳️ 💬 🗨️ 🗯️ 💭 💯 🔥 ✨ ⭐ 🌟 ⚡ ☀️ 🌈 ☁️ ❄️ ☃️ 🎉 🎊 🎈 🎀 ✔️ ☑️ ❌ ❎ ➕ ➖ ➗ ♻️ ⚠️ 🚫"),
        ("flag.fill", "🏳️ 🏴 🚩 🏁 🏳️‍🌈 🏳️‍⚧️ 🇹🇼 🇯🇵 🇺🇸 🇬🇧 🇰🇷 🇨🇦 🇦🇺 🇫🇷 🇩🇪 🇮🇹 🇪🇸 🇨🇳 🇭🇰 🇲🇴 🇸🇬 🇹🇭 🇻🇳 🇵🇭 🇮🇩 🇲🇾 🇳🇿 🇧🇷 🇲🇽 🇮🇳 🇺🇳")
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        root.axis = .vertical
        root.spacing = 7
        root.translatesAutoresizingMaskIntoConstraints = false
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 8
        header.heightAnchor.constraint(equalToConstant: 32).isActive = true

        titleButton.setTitle("超級儀表板", for: .normal)
        titleButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        titleButton.setTitleColor(.label, for: .normal)
        titleButton.contentHorizontalAlignment = .leading
        titleButton.addAction(UIAction { [weak self] _ in
            guard let self, let url = URL(string: "superdashboard://dashboard") else { return }
            self.extensionContext?.open(url, completionHandler: nil)
        }, for: .touchUpInside)
        header.addArrangedSubview(titleButton)
        header.addArrangedSubview(UIView())
        refreshButton.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        refreshButton.tintColor = .secondaryLabel
        refreshButton.addAction(UIAction { [weak self] _ in self?.refreshClipboard() }, for: .touchUpInside)
        header.addArrangedSubview(refreshButton)

        contentScroll.translatesAutoresizingMaskIntoConstraints = false
        contentScroll.alwaysBounceVertical = true
        contentScroll.showsVerticalScrollIndicator = false
        content.axis = .vertical
        content.spacing = 7
        content.translatesAutoresizingMaskIntoConstraints = false
        contentScroll.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: contentScroll.contentLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: contentScroll.contentLayoutGuide.trailingAnchor),
            content.topAnchor.constraint(equalTo: contentScroll.contentLayoutGuide.topAnchor, constant: 5),
            content.bottomAnchor.constraint(equalTo: contentScroll.contentLayoutGuide.bottomAnchor),
            content.widthAnchor.constraint(equalTo: contentScroll.frameLayoutGuide.widthAnchor)
        ])

        emojiPager.translatesAutoresizingMaskIntoConstraints = false
        emojiPager.isPagingEnabled = true
        emojiPager.isDirectionalLockEnabled = true
        emojiPager.panGestureRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        emojiPager.showsHorizontalScrollIndicator = false
        emojiPager.showsVerticalScrollIndicator = false
        emojiPager.alwaysBounceHorizontal = true
        emojiPager.delegate = self
        emojiPageStack.axis = .horizontal
        emojiPageStack.alignment = .fill
        emojiPageStack.distribution = .fill
        emojiPageStack.spacing = 0
        emojiPageStack.translatesAutoresizingMaskIntoConstraints = false
        emojiPager.addSubview(emojiPageStack)
        NSLayoutConstraint.activate([
            emojiPageStack.leadingAnchor.constraint(equalTo: emojiPager.contentLayoutGuide.leadingAnchor),
            emojiPageStack.trailingAnchor.constraint(equalTo: emojiPager.contentLayoutGuide.trailingAnchor),
            emojiPageStack.topAnchor.constraint(equalTo: emojiPager.contentLayoutGuide.topAnchor),
            emojiPageStack.bottomAnchor.constraint(equalTo: emojiPager.contentLayoutGuide.bottomAnchor),
            emojiPageStack.heightAnchor.constraint(equalTo: emojiPager.frameLayoutGuide.heightAnchor)
        ])
        emojiPager.isHidden = true
        dock.axis = .horizontal
        dock.alignment = .center
        dock.distribution = .equalSpacing
        dock.spacing = 1
        dock.translatesAutoresizingMaskIntoConstraints = false
        dock.heightAnchor.constraint(equalToConstant: 38).isActive = true
        contentArea.translatesAutoresizingMaskIntoConstraints = false
        contentArea.addSubview(contentScroll)
        contentArea.addSubview(emojiPager)
        NSLayoutConstraint.activate([
            contentScroll.leadingAnchor.constraint(equalTo: contentArea.leadingAnchor), contentScroll.trailingAnchor.constraint(equalTo: contentArea.trailingAnchor),
            contentScroll.topAnchor.constraint(equalTo: contentArea.topAnchor), contentScroll.bottomAnchor.constraint(equalTo: contentArea.bottomAnchor),
            emojiPager.leadingAnchor.constraint(equalTo: contentArea.leadingAnchor), emojiPager.trailingAnchor.constraint(equalTo: contentArea.trailingAnchor),
            emojiPager.topAnchor.constraint(equalTo: contentArea.topAnchor), emojiPager.bottomAnchor.constraint(equalTo: contentArea.bottomAnchor)
        ])
        root.addArrangedSubview(header)
        root.addArrangedSubview(contentArea)
        root.addArrangedSubview(dock)
        view.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -5),
            view.heightAnchor.constraint(equalToConstant: 330),
        ])
        reloadSharedData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadSharedData()
        capturePasteboardIfChanged()
        reloadSharedData()
    }

    private var defaults: UserDefaults? { UserDefaults(suiteName: groupID) }
    private var groupContainer: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) }

    private func reloadSharedData() {
        defaults?.synchronize()
        if let data = groupContainer.flatMap({ try? Data(contentsOf: $0.appendingPathComponent("keyboardQuick_copy.json")) }) ?? defaults?.data(forKey: storeKey) {
            shortcuts = (try? JSONDecoder().decode([ClipItem].self, from: data)) ?? []
        }
        emojiBarEnabled = defaults?.object(forKey: emojiBarEnabledKey) as? Bool ?? true
        if let data = defaults?.data(forKey: historyKey) {
            history = Array(((try? JSONDecoder().decode([HistoryItem].self, from: data)) ?? []).prefix(30))
        }
        let fileURL = groupContainer?.appendingPathComponent(recentEmojiFile)
        let fileCounts = fileURL.flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONDecoder().decode([String: Int].self, from: $0) } ?? [:]
        let defaultsCounts = defaults?.dictionary(forKey: recentEmojiKey) as? [String: Int] ?? [:]
        recentEmojiCounts = fileCounts.merging(defaultsCounts) { max($0, $1) }
        persistEmojiCounts()
        render()
    }

    private func persistEmojiCounts() {
        guard let folder = groupContainer, let data = try? JSONEncoder().encode(recentEmojiCounts) else { return }
        try? data.write(to: folder.appendingPathComponent(recentEmojiFile), options: .atomic)
        defaults?.set(recentEmojiCounts, forKey: recentEmojiKey)
        defaults?.synchronize()
    }

    private func saveHistory() {
        history = Array(history.prefix(30))
        let data = try? JSONEncoder().encode(history)
        defaults?.set(data, forKey: historyKey)
        defaults?.synchronize()
    }

    private func refreshClipboard() {
        capturePasteboardIfChanged(force: true)
        reloadSharedData()
    }

    private func capturePasteboardIfChanged(force: Bool = false) {
        let pasteboard = UIPasteboard.general
        guard let first = pasteboard.items.first else { return }
        if let text = first["public.utf8-plain-text"] as? String ?? first["public.text"] as? String,
           !text.isEmpty {
            if let index = history.firstIndex(where: { $0.kind == "text" && $0.text == text }) {
                let existing = history.remove(at: index)
                if !force && index == 0 { return }
                history.insert(existing, at: 0)
            } else {
                history.insert(HistoryItem(id: UUID().uuidString, kind: "text", text: text, imageFile: nil, createdAt: Date()), at: 0)
            }
            history = Array(history.prefix(30))
            saveHistory()
            return
        }
        if let image = pasteboard.image, let data = image.pngData(), let folder = groupContainer {
            if let index = history.firstIndex(where: { item in
                guard item.kind == "image", let file = item.imageFile,
                      let oldData = try? Data(contentsOf: folder.appendingPathComponent(file)) else { return false }
                return oldData == data
            }) {
                let existing = history.remove(at: index)
                if !force && index == 0 { return }
                history.insert(existing, at: 0)
            } else {
                let name = UUID().uuidString + ".png"
                let url = folder.appendingPathComponent(name)
                guard (try? data.write(to: url, options: .atomic)) != nil else { return }
                history.insert(HistoryItem(id: UUID().uuidString, kind: "image", text: nil, imageFile: name, createdAt: Date()), at: 0)
            }
            let removed = history.dropFirst(30)
            history = Array(history.prefix(30))
            for old in removed { if let file = old.imageFile { try? FileManager.default.removeItem(at: folder.appendingPathComponent(file)) } }
            saveHistory()
        }
    }

    private func clear(_ stack: UIStackView) {
        stack.arrangedSubviews.forEach { stack.removeArrangedSubview($0); $0.removeFromSuperview() }
    }

    private func button(_ symbol: String, selected: Bool, action: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: symbol), for: .normal)
        b.tintColor = selected ? .systemBlue : .secondaryLabel
        b.backgroundColor = selected ? UIColor.systemBlue.withAlphaComponent(0.12) : .clear
        b.layer.cornerRadius = 9
        b.addAction(UIAction { [weak self] _ in self?.haptic.impactOccurred(); action() }, for: .touchUpInside)
        return b
    }

    private func renderDock() {
        clear(dock)
        dockButtons.removeAll()
        func add(_ symbol: String, section: String, isEmoji: Bool = false, action: @escaping () -> Void) {
            let b = UIButton(type: .system)
            b.setImage(UIImage(systemName: symbol), for: .normal)
            b.imageView?.contentMode = .scaleAspectFit
            b.tintColor = .secondaryLabel
            b.backgroundColor = .clear
            b.layer.cornerRadius = 14
            b.translatesAutoresizingMaskIntoConstraints = false
            b.widthAnchor.constraint(equalToConstant: 25).isActive = true
            b.heightAnchor.constraint(equalToConstant: 25).isActive = true
            b.imageView?.contentMode = .scaleAspectFit
            b.imageEdgeInsets = UIEdgeInsets(top: -2, left: -2, bottom: -2, right: -2)
            b.isHidden = !emojiBarEnabled
            b.addAction(UIAction { [weak self] _ in self?.haptic.impactOccurred(); action() }, for: .touchUpInside)
            dock.addArrangedSubview(b)
            dockButtons.append(b)
        }
        add("square.grid.2x2.fill", section: "home") { [weak self] in self?.selectedSection = "home"; self?.render() }
        add("clock", section: "recent") { [weak self] in self?.selectedSection = "recent"; self?.render() }
        for (index, category) in emojiCategories.enumerated() {
            add(category.0, section: "emoji\(index)", isEmoji: true) { [weak self] in self?.showEmojiCategory(index) }
        }
        let erase = UIButton(type: .system)
        erase.setImage(UIImage(systemName: "delete.left"), for: .normal)
        erase.tintColor = .label
        erase.translatesAutoresizingMaskIntoConstraints = false
        erase.widthAnchor.constraint(equalToConstant: 28).isActive = true
        erase.heightAnchor.constraint(equalToConstant: 28).isActive = true
        erase.addTarget(self, action: #selector(backspaceTouchDown), for: .touchDown)
        erase.addTarget(self, action: #selector(backspaceTouchEnded), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        dock.addArrangedSubview(erase)
        dock.gestureRecognizers?.forEach { dock.removeGestureRecognizer($0) }
        let pan = UIPanGestureRecognizer(target: self, action: #selector(dragDockSelection(_:)))
        pan.cancelsTouchesInView = false
        dock.addGestureRecognizer(pan)
        updateDockSelection()
    }

    private func updateDockSelection() {
        let selected = selectedSection == "home" ? 0 : (selectedSection == "recent" ? 1 : (selectedSection.hasPrefix("emoji") ? selectedEmojiCategory + 2 : -1))
        for (i, b) in dockButtons.enumerated() {
            b.backgroundColor = i == selected ? UIColor.label.withAlphaComponent(0.18) : .clear
            b.layer.cornerRadius = 14
            b.layer.masksToBounds = true
            b.widthAnchor.constraint(equalToConstant: 34).isActive = false
            b.tintColor = i == selected ? .label : .secondaryLabel
        }
    }

    @objc private func dragDockSelection(_ gesture: UIPanGestureRecognizer) {
        let x = gesture.location(in: dock).x
        let index = dockButtons.firstIndex(where: { !$0.isHidden && $0.frame.insetBy(dx: -5, dy: -5).contains(gesture.location(in: dock)) })
            ?? max(0, min(dockButtons.count - 1, Int(x / max(1, dock.bounds.width) * CGFloat(dockButtons.count))))
        if gesture.state == .began || gesture.state == .changed {
            if gesture.state == .began { haptic.impactOccurred() }
            if index == 0 { selectedSection = "home" }
            else if index == 1 { selectedSection = "recent" }
            else if index - 2 < emojiCategories.count {
                selectedEmojiCategory = index - 2
                selectedSection = "emoji\(selectedEmojiCategory)"
            }
            updateDockSelection()
        } else if gesture.state == .ended {
            if selectedSection.hasPrefix("emoji") { showEmojiCategory(selectedEmojiCategory) }
            else { render() }
        }
    }

    private func showEmojiCategory(_ index: Int) {
        guard emojiBarEnabled else { selectedSection = "home"; render(); return }
        selectedEmojiCategory = (index + emojiCategories.count) % emojiCategories.count
        selectedSection = "emoji\(selectedEmojiCategory)"
        if !emojiPagesBuilt { buildEmojiPages() }
        updateDockSelection()
        refreshButton.isHidden = true
        emojiPager.isHidden = false
        contentScroll.isHidden = true
        if let page = emojiPageItems.indices.first(where: { $0 > 0 && $0 < emojiPageItems.count - 1 && emojiPageCategories[$0] == selectedEmojiCategory }) {
            emojiPager.setContentOffset(CGPoint(x: CGFloat(page) * emojiPager.bounds.width, y: 0), animated: false)
        }
    }

    private func buildEmojiPages() {
        guard !emojiPagesBuilt else { return }
        clear(emojiPageStack)
        emojiPageCategories.removeAll()
        emojiPageItems.removeAll()
        for (categoryIndex, category) in emojiCategories.enumerated() {
            let all = category.1.split(separator: " ").map(String.init)
            for start in stride(from: 0, to: all.count, by: 28) {
                emojiPageCategories.append(categoryIndex)
                emojiPageItems.append(Array(all[start..<min(start + 28, all.count)]))
            }
        }
        if let firstItems = emojiPageItems.first, let firstCategory = emojiPageCategories.first,
           let lastItems = emojiPageItems.last, let lastCategory = emojiPageCategories.last {
            emojiPageItems.insert(lastItems, at: 0)
            emojiPageCategories.insert(lastCategory, at: 0)
            emojiPageItems.append(firstItems)
            emojiPageCategories.append(firstCategory)
        }
        for (pageIndex, emojis) in emojiPageItems.enumerated() {
            let page = UIStackView()
            page.axis = .vertical
            page.distribution = .fillEqually
            page.spacing = 1
            page.translatesAutoresizingMaskIntoConstraints = false
            for rowIndex in 0..<4 {
                let row = UIStackView()
                row.axis = .horizontal
                row.distribution = .fillEqually
                row.spacing = 1
                for col in 0..<7 {
                    let itemIndex = rowIndex * 7 + col
                    let b = UIButton(type: .system)
                    if itemIndex < emojis.count {
                        let emoji = emojis[itemIndex]
                        b.setTitle(emoji, for: .normal)
                        b.titleLabel?.font = .systemFont(ofSize: 27)
                        b.addAction(UIAction { [weak self] _ in self?.insertEmoji(emoji) }, for: .touchUpInside)
                    }
                    row.addArrangedSubview(b)
                }
                page.addArrangedSubview(row)
            }
            emojiPageStack.addArrangedSubview(page)
            page.widthAnchor.constraint(equalTo: emojiPager.frameLayoutGuide.widthAnchor).isActive = true
            page.heightAnchor.constraint(equalTo: emojiPager.frameLayoutGuide.heightAnchor).isActive = true
            _ = pageIndex
        }
        view.layoutIfNeeded()
        emojiPager.contentOffset = .zero
        emojiPagesBuilt = true
    }

    @objc private func backspaceTouchDown() {
        haptic.impactOccurred()
        textDocumentProxy.deleteBackward()
        backspaceInitialDelay?.invalidate()
        backspaceTimer?.invalidate()
        backspaceInitialDelay = Timer.scheduledTimer(withTimeInterval: 0.38, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.backspaceTimer = Timer.scheduledTimer(withTimeInterval: 0.075, repeats: true) { [weak self] _ in
                self?.textDocumentProxy.deleteBackward()
            }
        }
    }

    @objc private func backspaceTouchEnded() {
        backspaceInitialDelay?.invalidate(); backspaceInitialDelay = nil
        backspaceTimer?.invalidate(); backspaceTimer = nil
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        backspaceTouchEnded()
    }

    private func makeShortcutCell(_ item: ClipItem) -> UIView {
        let isImage = item.type == "image" || item.text.hasPrefix("data:image")
        let cell = makeSharedCell(title: isImage ? (item.label.isEmpty ? "圖片" : item.label) : (item.label.isEmpty ? item.text : item.label),
                                  image: isImage ? decodeImage(item.text) : nil)
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleShortcutSingleTap(_:)))
        singleTap.numberOfTapsRequired = 1
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleShortcutDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        singleTap.require(toFail: doubleTap)
        cell.addGestureRecognizer(singleTap)
        cell.addGestureRecognizer(doubleTap)
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleShortcutLongPress(_:)))
        longPress.minimumPressDuration = 0.45
        longPress.cancelsTouchesInView = true
        cell.addGestureRecognizer(longPress)
        cell.accessibilityIdentifier = item.id
        return cell
    }

    private func shortcut(for gesture: UIGestureRecognizer) -> ClipItem? {
        guard let id = gesture.view?.accessibilityIdentifier else { return nil }
        return shortcuts.first(where: { $0.id == id })
    }

    @objc private func handleShortcutSingleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended, let item = shortcut(for: gesture) else { return }
        haptic.impactOccurred()
        let isImage = item.type == "image" || item.text.hasPrefix("data:image")
        if isImage {
            if let image = decodeImage(item.text), let data = image.pngData() {
                UIPasteboard.general.setItems([["public.png": data]], options: [.localOnly: true])
                showImageCopiedToast()
            }
        } else {
            textDocumentProxy.insertText(item.text)
        }
    }

    @objc private func handleShortcutDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended, let item = shortcut(for: gesture) else { return }
        let isImage = item.type == "image" || item.text.hasPrefix("data:image")
        if isImage {
            guard let image = decodeImage(item.text) else { return }
            showImagePreview(image)
        } else {
            let raw = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: raw),
                  let scheme = url.scheme?.lowercased(),
                  ["http", "https"].contains(scheme) else { return }
            extensionContext?.open(url, completionHandler: nil)
        }
    }

    @objc private func handleShortcutLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let item = shortcut(for: gesture) else { return }
        haptic.impactOccurred()
        showInlineShortcutDeleteConfirmation(for: item)
    }

    private func showImagePreview(_ image: UIImage) {
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.92)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        let close = UIButton(type: .system)
        close.setTitle("關閉", for: .normal)
        close.setTitleColor(.white, for: .normal)
        close.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        close.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(imageView)
        overlay.addSubview(close)
        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 12),
            imageView.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -12),
            imageView.topAnchor.constraint(equalTo: overlay.topAnchor, constant: 12),
            imageView.bottomAnchor.constraint(equalTo: close.topAnchor, constant: -8),
            close.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            close.bottomAnchor.constraint(equalTo: overlay.bottomAnchor, constant: -10),
            close.heightAnchor.constraint(equalToConstant: 36)
        ])
        close.addAction(UIAction { _ in overlay.removeFromSuperview() }, for: .touchUpInside)
    }

    private func showInlineShortcutDeleteConfirmation(for item: ClipItem) {
        let panel = UIView()
        panel.backgroundColor = .secondarySystemBackground
        panel.layer.cornerRadius = 14
        panel.layer.borderWidth = 1
        panel.layer.borderColor = UIColor.separator.cgColor
        panel.translatesAutoresizingMaskIntoConstraints = false
        let title = UILabel()
        title.text = "確認刪除「\(item.label.isEmpty ? "此項目" : item.label)」？"
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.numberOfLines = 1
        let cancel = UIButton(type: .system)
        cancel.setTitle("取消", for: .normal)
        let remove = UIButton(type: .system)
        remove.setTitle("確認刪除", for: .normal)
        remove.setTitleColor(.systemRed, for: .normal)
        let actions = UIStackView(arrangedSubviews: [cancel, remove])
        actions.axis = .horizontal
        actions.spacing = 10
        let row = UIStackView(arrangedSubviews: [title, UIView(), actions])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 6
        row.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(row)
        view.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            panel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            panel.heightAnchor.constraint(equalToConstant: 58),
            row.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 10),
            row.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -10),
            row.topAnchor.constraint(equalTo: panel.topAnchor, constant: 6),
            row.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -6)
        ])
        cancel.addAction(UIAction { _ in panel.removeFromSuperview() }, for: .touchUpInside)
        remove.addAction(UIAction { [weak self] _ in
            guard let self else { panel.removeFromSuperview(); return }
            self.shortcuts.removeAll { $0.id == item.id }
            if let data = try? JSONEncoder().encode(self.shortcuts) {
                self.defaults?.set(data, forKey: self.storeKey)
                self.defaults?.synchronize()
                try? data.write(to: self.groupContainer?.appendingPathComponent("keyboardQuick_copy.json") ?? URL(fileURLWithPath: "/dev/null"), options: .atomic)
            }
            panel.removeFromSuperview()
            self.render()
        }, for: .touchUpInside)
    }

    private func makeSharedCell(title: String, image: UIImage?) -> UIButton {
        let cell = UIButton(type: .system)
        cell.backgroundColor = .tertiarySystemFill
        cell.layer.cornerRadius = 12
        cell.clipsToBounds = true
        cell.contentEdgeInsets = UIEdgeInsets(top: 5, left: 6, bottom: 5, right: 6)
        cell.heightAnchor.constraint(equalToConstant: 58).isActive = true
        cell.titleLabel?.font = .systemFont(ofSize: 11, weight: .medium)
        cell.titleLabel?.numberOfLines = 2
        cell.titleLabel?.textAlignment = .center
        cell.setTitleColor(.label, for: .normal)
        if let image {
            cell.setTitle("", for: .normal)
            let preview = UIImageView(image: image)
            preview.contentMode = .scaleAspectFit
            preview.clipsToBounds = true
            preview.isUserInteractionEnabled = false
            preview.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(preview)
            NSLayoutConstraint.activate([
                preview.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 5),
                preview.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -5),
                preview.topAnchor.constraint(equalTo: cell.topAnchor, constant: 5),
                preview.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -5)
            ])
        } else {
            cell.setTitle(title, for: .normal)
        }
        return cell
    }

    private func decodeImage(_ value: String) -> UIImage? {
        guard let comma = value.firstIndex(of: ",") else { return nil }
        let encoded = String(value[value.index(after: comma)...])
            .components(separatedBy: .whitespacesAndNewlines).joined()
        guard let data = Data(base64Encoded: encoded, options: [.ignoreUnknownCharacters]) else { return nil }
        return UIImage(data: data)
    }

    private func showImageCopiedToast() {
        let toast = UILabel()
        toast.text = "這是圖片已貼上到剪貼簿"
        toast.font = .systemFont(ofSize: 12, weight: .medium)
        toast.textColor = .white
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.78)
        toast.textAlignment = .center
        toast.layer.cornerRadius = 9
        toast.clipsToBounds = true
        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -48),
            toast.heightAnchor.constraint(equalToConstant: 30),
            toast.widthAnchor.constraint(greaterThanOrEqualToConstant: 190)
        ])
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { toast.removeFromSuperview() }
    }

    private func makeHistoryCell(_ item: HistoryItem) -> UIView {
        let image: UIImage? = {
            guard item.kind == "image", let file = item.imageFile, let folder = groupContainer else { return nil }
            return UIImage(contentsOfFile: folder.appendingPathComponent(file).path)
        }()
        let cell = makeSharedCell(title: item.text ?? "圖片", image: image)
        cell.addAction(UIAction { [weak self] _ in self?.haptic.impactOccurred(); self?.handleHistoryItem(item) }, for: .touchUpInside)
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleHistoryLongPress(_:)))
        longPress.minimumPressDuration = 0.45
        longPress.cancelsTouchesInView = true
        cell.addGestureRecognizer(longPress)
        cell.accessibilityIdentifier = item.id
        return cell
    }

    @objc private func handleHistoryLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let cell = gesture.view as? UIButton,
              let id = cell.accessibilityIdentifier, let index = history.firstIndex(where: { $0.id == id }) else { return }
        haptic.impactOccurred()
        let item = history[index]
        showInlineDeleteConfirmation(for: item)
    }

    private func showInlineDeleteConfirmation(for item: HistoryItem) {
        let panel = UIView()
        panel.backgroundColor = .secondarySystemBackground
        panel.layer.cornerRadius = 14
        panel.layer.borderWidth = 1
        panel.layer.borderColor = UIColor.separator.cgColor
        panel.translatesAutoresizingMaskIntoConstraints = false
        let title = UILabel()
        title.text = "刪除這筆剪貼紀錄？"
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        let cancel = UIButton(type: .system)
        cancel.setTitle("取消", for: .normal)
        let remove = UIButton(type: .system)
        remove.setTitle("刪除", for: .normal)
        remove.setTitleColor(.systemRed, for: .normal)
        let actions = UIStackView(arrangedSubviews: [cancel, remove])
        actions.axis = .horizontal
        actions.spacing = 18
        let row = UIStackView(arrangedSubviews: [title, UIView(), actions])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(row)
        view.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            panel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            panel.heightAnchor.constraint(equalToConstant: 54),
            row.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),
            row.topAnchor.constraint(equalTo: panel.topAnchor, constant: 6),
            row.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -6)
        ])
        cancel.addAction(UIAction { _ in panel.removeFromSuperview() }, for: .touchUpInside)
        remove.addAction(UIAction { [weak self] _ in
            guard let self, let i = self.history.firstIndex(where: { $0.id == item.id }) else {
                panel.removeFromSuperview()
                return
            }
            let removed = self.history.remove(at: i)
            if let file = removed.imageFile, let folder = self.groupContainer {
                try? FileManager.default.removeItem(at: folder.appendingPathComponent(file))
            }
            self.saveHistory()
            panel.removeFromSuperview()
            self.render()
        }, for: .touchUpInside)
    }

    private func handleHistoryItem(_ item: HistoryItem) {
        haptic.impactOccurred()
        if item.kind == "image", let file = item.imageFile, let folder = groupContainer,
           let data = try? Data(contentsOf: folder.appendingPathComponent(file)) {
            UIPasteboard.general.setItems([["public.png": data]], options: [.localOnly: true])
            showImageCopiedToast()
        } else if let text = item.text {
            textDocumentProxy.insertText(text)
        }
    }

    private func insertEmoji(_ emoji: String) {
        haptic.impactOccurred()
        textDocumentProxy.insertText(emoji)
        recentEmojiCounts[emoji, default: 0] += 1
        persistEmojiCounts()
    }

    private func render() {
        clear(content)
        renderDock()
        emojiPager.isHidden = !selectedSection.hasPrefix("emoji")
        contentScroll.isHidden = selectedSection.hasPrefix("emoji")
        refreshButton.isHidden = selectedSection.hasPrefix("emoji")
        if selectedSection == "home" {
            let firstSix = Array(shortcuts.filter { shortcut in
                guard !(shortcut.type == "image" && shortcut.text.isEmpty) else { return false }
                return !history.contains { item in
                    if shortcut.type == "image" || shortcut.text.hasPrefix("data:image") {
                        guard item.kind == "image", let file = item.imageFile, let folder = groupContainer,
                              let stored = try? Data(contentsOf: folder.appendingPathComponent(file)),
                              let image = decodeImage(shortcut.text), let shortcutData = image.pngData() else { return false }
                        return stored == shortcutData
                    }
                    return item.kind == "text" && item.text == shortcut.text
                }
            }.prefix(6))
            for start in stride(from: 0, to: firstSix.count, by: 3) {
                let row = UIStackView()
                row.axis = .horizontal
                row.distribution = .fillEqually
                row.spacing = 7
                for item in firstSix[start..<min(start + 3, firstSix.count)] { row.addArrangedSubview(makeShortcutCell(item)) }
                while row.arrangedSubviews.count < 3 { row.addArrangedSubview(UIView()) }
                content.addArrangedSubview(row)
            }
            let heading = UILabel()
            heading.text = "最近剪貼簿"
            heading.font = .systemFont(ofSize: 12, weight: .semibold)
            heading.textColor = .secondaryLabel
            content.addArrangedSubview(heading)
            let recent = Array(history.prefix(30))
            for start in stride(from: 0, to: recent.count, by: 3) {
                let row = UIStackView()
                row.axis = .horizontal
                row.distribution = .fillEqually
                row.alignment = .top
                row.spacing = 9
                for item in recent[start..<min(start + 3, recent.count)] {
                    row.addArrangedSubview(makeHistoryCell(item))
                }
                while row.arrangedSubviews.count < 3 { row.addArrangedSubview(UIView()) }
                content.addArrangedSubview(row)
            }
            if history.isEmpty {
                let empty = UILabel()
                empty.text = "尚無剪貼簿紀錄"
                empty.textColor = .secondaryLabel
                empty.font = .systemFont(ofSize: 12)
                content.addArrangedSubview(empty)
            }
        } else if selectedSection == "recent" {
            let recent = recentEmojiCounts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }.map(\.key)
            addRecentEmojiGrid(recent)
        } else if selectedSection.hasPrefix("emoji") {
            showEmojiCategory(selectedEmojiCategory)
        }
    }

    private func addRecentEmojiGrid(_ emojis: [String]) {
        for start in stride(from: 0, to: emojis.count, by: 7) {
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = 4
            for emoji in emojis[start..<min(start + 7, emojis.count)] {
                let b = UIButton(type: .system)
                b.setTitle(emoji, for: .normal)
                b.titleLabel?.font = .systemFont(ofSize: 27)
                b.addAction(UIAction { [weak self] _ in self?.insertEmoji(emoji) }, for: .touchUpInside)
                row.addArrangedSubview(b)
            }
            content.addArrangedSubview(row)
        }
    }
}


extension KeyboardViewController: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // Scrolling is intentionally silent; haptics are reserved for explicit selections.
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView === emojiPager, emojiPager.bounds.width > 0 else { return }
        var page = max(0, min(emojiPageCategories.count - 1, Int(round(emojiPager.contentOffset.x / emojiPager.bounds.width))))
        if page == 0, emojiPageCategories.count > 2 {
            page = emojiPageCategories.count - 2
            emojiPager.setContentOffset(CGPoint(x: CGFloat(page) * emojiPager.bounds.width, y: 0), animated: false)
        } else if page == emojiPageCategories.count - 1, emojiPageCategories.count > 2 {
            page = 1
            emojiPager.setContentOffset(CGPoint(x: CGFloat(page) * emojiPager.bounds.width, y: 0), animated: false)
        }
        if page < emojiPageCategories.count {
            selectedEmojiCategory = emojiPageCategories[page]
            selectedSection = "emoji\(selectedEmojiCategory)"
            updateDockSelection()
        }
    }
}
