import UIKit
import UniformTypeIdentifiers
import ImageIO

/// 分享延伸：把外部分享進來的文字 / 網址 / 圖片，寫進 App Group 收件匣。
/// 主 App 在回到前景（或被 superdashboard://shared-inbox 喚起）時，會讀取並加入。
/// 不再依賴剪貼簿與「extension 開 App」，因為後者在 Share Extension 內會被系統拒絕。
class ShareViewController: UIViewController {

    private let groupID = "group.com.steveplayer87.superdashboard"
    private let inboxKey = "sharedInbox"
    private let inboxFolder = "SharedInbox"

    private let statusLabel = UILabel()
    private let confirmButton = UIButton(type: .system)
    private var didStart = false
    private var pendingEntries: [[String: String]] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        statusLabel.text = ""
        statusLabel.isHidden = true
        statusLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = .label
        view.addSubview(statusLabel)
        confirmButton.setTitle("儲存到超級儀表板", for: .normal)
        confirmButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        confirmButton.backgroundColor = .systemBlue
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.layer.cornerRadius = 12
        confirmButton.contentEdgeInsets = UIEdgeInsets(top: 14, left: 22, bottom: 14, right: 22)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.isHidden = true
        confirmButton.addTarget(self, action: #selector(confirmSave), for: .touchUpInside)
        view.addSubview(confirmButton)
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -32),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
            confirmButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            confirmButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20),
            confirmButton.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            confirmButton.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didStart else { return }
        didStart = true
        collectAndStore()
    }

    // MARK: - 收集分享內容

    private func collectAndStore() {
        guard let defaults = UserDefaults(suiteName: groupID),
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
            finish(message: "App Group 尚未啟用，請重新簽署安裝", success: false)
            return
        }

        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        let providers = items.flatMap { $0.attachments ?? [] }
        if providers.isEmpty {
            finish(message: "沒有可加入的內容", success: false)
            return
        }

        let group = DispatchGroup()
        let lock = NSLock()
        var entries: [[String: String]] = []
        func add(_ entry: [String: String]) {
            lock.lock(); entries.append(entry); lock.unlock()
        }

        let imageProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }

        if !imageProviders.isEmpty {
            // 1. 圖片（最多 5 張）
            for provider in imageProviders.prefix(5) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] item, _ in
                    defer { group.leave() }
                    if let name = self?.storeImage(item: item, container: container) {
                        add(["kind": "image", "value": name])
                    }
                }
            }
        } else if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
            // 2. 網址
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                defer { group.leave() }
                if let url = item as? URL {
                    add(["kind": "text", "value": url.absoluteString])
                } else if let str = item as? String, !str.isEmpty {
                    add(["kind": "text", "value": str])
                }
            }
        } else if let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) ||
            $0.hasItemConformingToTypeIdentifier(UTType.text.identifier)
        }) {
            // 3. 一般文字：載入實際符合的文字型別，不使用 registeredTypeIdentifiers.first
            let typeID = provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
                ? UTType.plainText.identifier
                : UTType.text.identifier
            group.enter()
            provider.loadItem(forTypeIdentifier: typeID, options: nil) { item, error in
                defer { group.leave() }
                var text: String?
                if let s = item as? String {
                    text = s
                } else if let s = item as? NSString {
                    text = s as String
                } else if let a = item as? NSAttributedString {
                    text = a.string
                } else if let d = item as? Data {
                    text = String(data: d, encoding: .utf8)
                } else if let u = item as? URL {
                    text = u.isFileURL ? (try? String(contentsOf: u, encoding: .utf8)) : u.absoluteString
                } else if let error = error {
                    print("[ShareExtension] load text failed: \(error.localizedDescription)")
                } else {
                    print("[ShareExtension] unsupported text item: \(String(describing: item))")
                }
                if let t = text?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                    add(["kind": "text", "value": t])
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            if entries.isEmpty {
                self.finish(message: "無法讀取分享內容", success: false)
                return
            }
            self.pendingEntries = entries
            self.view.backgroundColor = .systemBackground
            self.statusLabel.isHidden = false
            self.statusLabel.textColor = .label
            let count = entries.count
            let firstText = entries.first(where: { $0["kind"] == "text" })?["value"]
            if let text = firstText, !text.isEmpty {
                let preview = text.count > 90 ? String(text.prefix(90)) + "…" : text
                self.statusLabel.text = "要儲存以下內容到常用項目嗎？\n\n\(preview)"
            } else {
                self.statusLabel.text = "準備儲存 \(count) 張圖片到常用項目？"
            }
            self.confirmButton.isHidden = false
        }
    }


    @objc private func confirmSave() {
        guard !pendingEntries.isEmpty,
              let defaults = UserDefaults(suiteName: groupID) else {
            finish(message: "找不到待儲存內容，請重新分享", success: false)
            return
        }
        var inbox = (defaults.array(forKey: inboxKey) as? [[String: String]]) ?? []
        inbox.append(contentsOf: pendingEntries)
        defaults.set(inbox, forKey: inboxKey)
        // synchronize() is deprecated and can report an unreliable failure here;
        // verify the value we just wrote instead of treating its return value as persistence failure.
        let savedInbox = defaults.array(forKey: inboxKey) as? [[String: String]] ?? []
        guard savedInbox.count >= inbox.count,
              Array(savedInbox.suffix(pendingEntries.count)) == pendingEntries else {
            finish(message: "內容未能寫入共享收件匣，請再試一次", success: false)
            return
        }
        pendingEntries.removeAll()
        // 若主 App 正在執行，立刻通知它取件（不必等回到前景）
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             CFNotificationName("com.steveplayer87.superdashboard.inbox-updated" as CFString), nil, nil, true)
        statusLabel.text = "已加入待處理收件匣，開啟超級儀表板即可完成儲存。"
        confirmButton.isHidden = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    // MARK: - 圖片處理（用 ImageIO 縮圖，避免大圖吃光 extension 記憶體上限）

    private func storeImage(item: NSSecureCoding?, container: URL) -> String? {
        var jpeg: Data?
        if let url = item as? URL, let src = CGImageSourceCreateWithURL(url as CFURL, nil) {
            jpeg = jpegThumbnail(from: src)
        } else if let data = item as? Data, let src = CGImageSourceCreateWithData(data as CFData, nil) {
            jpeg = jpegThumbnail(from: src)
        } else if let image = item as? UIImage {
            jpeg = downscaledJPEG(image)
        }
        guard let bytes = jpeg else { return nil }

        let dir = container.appendingPathComponent(inboxFolder, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let name = UUID().uuidString + ".jpg"
        do {
            try bytes.write(to: dir.appendingPathComponent(name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    private func jpegThumbnail(from source: CGImageSource) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 800
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg).jpegData(compressionQuality: 0.6)
    }

    private func downscaledJPEG(_ image: UIImage) -> Data? {
        let maxDim: CGFloat = 800
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let ratio = min(1, maxDim / longest)
        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let out = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return out.jpegData(compressionQuality: 0.6)
    }

    // MARK: - 結束（成功：靜默 + 震動；失敗：顯示原因）

    private func finish(message: String, success: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if success {
                // 不顯示任何畫面、不開 App：存完就收起，用震動代替確認
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                }
            } else {
                // 失敗才顯示原因，避免無聲失敗
                self.view.backgroundColor = .systemBackground
                self.statusLabel.isHidden = false
                self.statusLabel.text = message
                self.statusLabel.textColor = .systemRed
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
                    self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                }
            }
        }
    }
}
