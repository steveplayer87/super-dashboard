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

        UIPasteboard.general.image = scaledImage
        if let url = URL(string: "superdashboard://add-copy-pasteboard") {
            openURLViaResponderChain(url)
        } else {
            completeShare()
        }
    }

    private func openHostApp(withText text: String) {
        UIPasteboard.general.string = text

        guard let url = URL(string: "superdashboard://add-copy-pasteboard") else {
            completeShare()
            return
        }

        openURLViaResponderChain(url)
    }

    private func openURLViaResponderChain(_ url: URL) {
        // 優先使用系統級 extensionContext.open
        if let context = self.extensionContext {
            context.open(url) { [weak self] success in
                print("[ShareExtension] context.open result: \(success)")
                DispatchQueue.main.async {
                    self?.completeShare()
                }
            }
            return
        }

        var responder: UIResponder? = self
        let selector = NSSelectorFromString("openURL:")
        while responder != nil {
            if responder!.responds(to: selector) && responder != self {
                responder!.perform(selector, with: url)
                break
            }
            responder = responder?.next
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.completeShare()
        }
    }

    private func completeShare() {
        DispatchQueue.main.async { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}
