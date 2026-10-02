import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        handleSharedContent()
    }

    private func handleSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments, !attachments.isEmpty else {
            completeShare()
            return
        }

        // 1. 優先檢查是否為圖片 (Photos / Screenshot / Image)
        for itemProvider in attachments {
            if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                itemProvider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (item, error) in
                    if let url = item as? URL, let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                        self?.processAndShareImage(image)
                    } else if let image = item as? UIImage {
                        self?.processAndShareImage(image)
                    } else if let data = item as? Data, let image = UIImage(data: data) {
                        self?.processAndShareImage(image)
                    } else {
                        self?.completeShare()
                    }
                }
                return
            }
        }

        // 2. 檢查是否為網址 (Safari / Browser URL)
        for itemProvider in attachments {
            if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
                    if let url = item as? URL {
                        self?.openHostApp(withText: url.absoluteString)
                    } else if let str = item as? String {
                        self?.openHostApp(withText: str)
                    } else {
                        self?.completeShare()
                    }
                }
                return
            }
        }

        // 3. 檢查是否為一般文字 (Notes / Text / Clipboard)
        for itemProvider in attachments {
            if itemProvider.hasItemConformingToTypeIdentifier(UTType.text.identifier) ||
               itemProvider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                itemProvider.loadItem(forTypeIdentifier: itemProvider.registeredTypeIdentifiers.first ?? UTType.text.identifier, options: nil) { [weak self] (item, error) in
                    if let text = item as? String {
                        self?.openHostApp(withText: text)
                    } else {
                        self?.completeShare()
                    }
                }
                return
            }
        }

        completeShare()
    }

    private func processAndShareImage(_ image: UIImage) {
        let maxDimension: CGFloat = 800
        var scaledImage = image
        if image.size.width > maxDimension || image.size.height > maxDimension {
            let ratio = min(maxDimension / image.size.width, maxDimension / image.size.height)
            let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
            UIGraphicsBeginImageContextWithOptions(newSize, false, 0.8)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            if let resized = UIGraphicsGetImageFromCurrentImageContext() {
                scaledImage = resized
            }
            UIGraphicsEndImageContext()
        }

        // 寫入剪貼簿，避免 URL 長度限制造成失敗
        UIPasteboard.general.image = scaledImage
        if let url = URL(string: "superdashboard://add-copy-pasteboard") {
            self.extensionContext?.open(url, completionHandler: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.completeShare()
                }
            })
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.completeShare()
            }
        } else {
            completeShare()
        }
    }

    private func openHostApp(withText text: String) {
        // 同步寫入通用剪貼簿作為多重兜底保證
        UIPasteboard.general.string = text

        var comp = URLComponents()
        comp.scheme = "superdashboard"
        comp.host = "add-copy"
        comp.queryItems = [URLQueryItem(name: "text", value: text)]

        guard let url = comp.url else {
            completeShare()
            return
        }

        // 1. 標準且官方支援的 extensionContext.open
        self.extensionContext?.open(url, completionHandler: { [weak self] success in
            DispatchQueue.main.async {
                self?.completeShare()
            }
        })

        // 2. 超時保護，避免介面停滯
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.completeShare()
        }
    }

    private func completeShare() {
        DispatchQueue.main.async { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}
