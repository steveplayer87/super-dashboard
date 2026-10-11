import UIKit
import Capacitor
import ActivityKit
import UserNotifications
import WebKit

// MARK: - Taoyuan Metro Live Activity Data Model
public struct TaoyuanMetroAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var currentStation: String
        public var nextStation: String
        public var destination: String
        public var progress: Double
        public var etaMinutes: Int
        public var fare: String
        public var statusText: String
        
        public init(currentStation: String, nextStation: String, destination: String, progress: Double, etaMinutes: Int, fare: String, statusText: String) {
            self.currentStation = currentStation
            self.nextStation = nextStation
            self.destination = destination
            self.progress = progress
            self.etaMinutes = etaMinutes
            self.fare = fare
            self.statusText = statusText
        }
    }

    public var lineName: String
    public var trainType: String
    
    public init(lineName: String, trainType: String) {
        self.lineName = lineName
        self.trainType = trainType
    }
}

// MARK: - Quick Copy Live Activity Data Model
public struct QuickCopyItemData: Codable, Hashable {
    public var id: String
    public var label: String
    public var text: String
    public var isLink: Bool
    
    public init(id: String, label: String, text: String, isLink: Bool = false) {
        self.id = id
        self.label = label
        self.text = text
        self.isLink = isLink
    }
}

public struct QuickCopyAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var items: [QuickCopyItemData]
        public var lastCopiedText: String?
        public var updateTimestamp: Double
        
        public init(items: [QuickCopyItemData], lastCopiedText: String? = nil, updateTimestamp: Double = Date().timeIntervalSince1970) {
            self.items = items
            self.lastCopiedText = lastCopiedText
            self.updateTimestamp = updateTimestamp
        }
    }

    public var title: String
    
    public init(title: String = "常用速貼庫") {
        self.title = title
    }
}

// MARK: - Live Activity 管理器 (桃園捷運搭乘即時動態)
@available(iOS 16.2, *)
class LiveActivityManager {
    static var currentActivity: Activity<TaoyuanMetroAttributes>?

    static func startTaoyuanMetroActivity() {
        for activity in Activity<TaoyuanMetroAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        let attributes = TaoyuanMetroAttributes(
            lineName: "桃園捷運 機場線",
            trainType: "直達車 112"
        )
        let initialContent = TaoyuanMetroAttributes.ContentState(
            currentStation: "A12 機場一航",
            nextStation: "A18 高鐵桃園站",
            destination: "A21 環北站",
            progress: 0.65,
            etaMinutes: 8,
            fare: "NT$ 35",
            statusText: "即將抵達"
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialContent, staleDate: nil)
            )
            let actId = currentActivity?.id ?? ""
            print("Taoyuan Metro Live Activity started: \(actId)")
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    static func stopActivity() {
        Task {
            for activity in Activity<TaoyuanMetroAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}

// MARK: - QuickCopy Live Activity 管理器 (常用項目動態島)
@available(iOS 16.2, *)
class QuickCopyManager {
    static var currentActivity: Activity<QuickCopyAttributes>?

    static func startOrUpdateQuickCopy(items: [QuickCopyItemData]) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            NotificationManager.evaluateNotificationFeedback("請至 iPhone「設定 > Super Dashboard > 即時動態」開啟權限")
            return
        }

        let attributes = QuickCopyAttributes(title: "常用速貼庫")
        let contentState = QuickCopyAttributes.ContentState(
            items: Array(items.prefix(5)),
            lastCopiedText: nil,
            updateTimestamp: Date().timeIntervalSince1970
        )

        if let existing = Activity<QuickCopyAttributes>.activities.first {
            Task {
                await existing.update(
                    ActivityContent(state: contentState, staleDate: nil),
                    alertConfiguration: nil
                )
                DispatchQueue.main.async {
                    NotificationManager.evaluateNotificationFeedback("常用速貼動態島已更新！")
                }
            }
            currentActivity = existing
        } else {
            do {
                currentActivity = try Activity.request(
                    attributes: attributes,
                    content: .init(state: contentState, staleDate: nil)
                )
                DispatchQueue.main.async {
                    NotificationManager.evaluateNotificationFeedback("常用速貼動態島已開啟！退回桌面或長按島嶼即可點擊複製")
                }
            } catch {
                DispatchQueue.main.async {
                    NotificationManager.evaluateNotificationFeedback("啟動動態島失敗：\(error.localizedDescription)")
                }
            }
        }
    }

    static func notifyItemCopied(text: String) {
        if let existing = Activity<QuickCopyAttributes>.activities.first {
            var updatedState = existing.content.state
            updatedState.lastCopiedText = text
            updatedState.updateTimestamp = Date().timeIntervalSince1970
            Task {
                await existing.update(
                    ActivityContent(state: updatedState, staleDate: nil),
                    alertConfiguration: nil
                )
            }
        }
    }
}

// MARK: - Notification Manager (完整支援自訂動作選項、圖片貼圖與文字即時回覆)
class NotificationManager {
    static let cardCategoryIdentifier = "CARD_ACTION_CATEGORY"
    static let replyCategoryIdentifier = "MESSAGE_REPLY_CATEGORY"

    static func setupCategories() {
        let center = UNUserNotificationCenter.current()

        // 類型 1：長按展開選項（打開卡片、打開錢包、忽略）
        let openCardAction = UNNotificationAction(
            identifier: "ACTION_OPEN_CARD",
            title: "💳 快速出示悠遊卡",
            options: [.foreground]
        )
        let openWalletAction = UNNotificationAction(
            identifier: "ACTION_OPEN_WALLET",
            title: "👛 開啟超級錢包",
            options: [.foreground]
        )
        let dismissAction = UNNotificationAction(
            identifier: "ACTION_DISMISS",
            title: "✕ 忽略",
            options: [.destructive]
        )
        let cardCategory = UNNotificationCategory(
            identifier: cardCategoryIdentifier,
            actions: [openCardAction, openWalletAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // 類型 2：即時輸入回覆與貼圖
        let replyAction = UNTextInputNotificationAction(
            identifier: "ACTION_REPLY",
            title: "💬 回覆訊息",
            options: [],
            textInputButtonTitle: "傳送",
            textInputPlaceholder: "輸入回覆阿鵝管家..."
        )
        let openAppAction = UNNotificationAction(
            identifier: "ACTION_OPEN_CHAT",
            title: "開啟對話",
            options: [.foreground]
        )
        let replyCategory = UNNotificationCategory(
            identifier: replyCategoryIdentifier,
            actions: [replyAction, openAppAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([cardCategory, replyCategory])
    }

    // 檢查通知授權狀態與診斷
    static func checkAndRequestPermission(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                completion(true)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    DispatchQueue.main.async {
                        completion(granted)
                    }
                }
            case .denied:
                DispatchQueue.main.async {
                    evaluateNotificationFeedback("⚠️ 通知權限遭拒！請至 iPhone「設定 > Super Dashboard > 通知」開啟允許通知。")
                    completion(false)
                }
            @unknown default:
                completion(true)
            }
        }
    }

    // 前往系統設定
    static func openSystemSettings() {
        DispatchQueue.main.async {
            if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }

    // 測試 1：長按選項卡片通知
    static func scheduleCardActionNotification() {
        checkAndRequestPermission { granted in
            guard granted else { return }

            let center = UNUserNotificationCenter.current()
            let content = UNMutableNotificationContent()
            content.title = "場景自動感知 · 靠近高鐵桃園站"
            content.subtitle = "長按此通知可展開快速操作"
            content.body = "偵測到您在 桃園高鐵捷運閘門，請選擇快速操作："
            content.sound = .default
            content.categoryIdentifier = cardCategoryIdentifier
            content.userInfo = ["url": "superdashboard://wallet?card=easycard"]

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
            let req = UNNotificationRequest(identifier: "card_action_\(UUID().uuidString)", content: content, trigger: trigger)

            center.add(req) { err in
                DispatchQueue.main.async {
                    if let err = err {
                        evaluateNotificationFeedback("排程失敗：\(err.localizedDescription)")
                    } else {
                        evaluateNotificationFeedback("「長按展開選項通知」已發送！長按頂部橫幅即可出示卡片或開啟錢包")
                    }
                }
            }
        }
    }

    // 測試 2：帶貼圖圖片 + 可回覆文字通知
    static func scheduleReplyWithStickerNotification() {
        checkAndRequestPermission { granted in
            guard granted else { return }

            let center = UNUserNotificationCenter.current()
            let content = UNMutableNotificationContent()
            content.title = "阿鵝管家 💬"
            content.subtitle = "傳送了一張貼圖給您"
            content.body = "「早安！今天的行程票卡與高鐵憑證已準備好，長按即可直接輸入文字回覆我喔！」"
            content.sound = .default
            content.categoryIdentifier = replyCategoryIdentifier
            content.userInfo = ["type": "chat_reply"]

            // 附加貼圖圖片
            if let attachment = createStickerAttachment() {
                content.attachments = [attachment]
            }

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
            let req = UNNotificationRequest(identifier: "reply_sticker_\(UUID().uuidString)", content: content, trigger: trigger)

            center.add(req) { err in
                DispatchQueue.main.async {
                    if let err = err {
                        evaluateNotificationFeedback("排程失敗：\(err.localizedDescription)")
                    } else {
                        evaluateNotificationFeedback("「貼圖可回覆通知」已發送！下拉或長按通知條即可直接輸入回覆")
                    }
                }
            }
        }
    }

    // 準備貼圖附件 (複製現有頭像或產生貼圖至暫存區)
    private static func createStickerAttachment() -> UNNotificationAttachment? {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let stickerUrl = tempDir.appendingPathComponent("goose_sticker.jpg")

        var sourceUrl: URL? = nil
        let candidates = [
            Bundle.main.url(forResource: "goose_avatar", withExtension: "jpg"),
            Bundle.main.url(forResource: "public/assets/goose_avatar", withExtension: "jpg"),
            Bundle.main.bundleURL.appendingPathComponent("public/assets/goose_avatar.jpg"),
            Bundle.main.bundleURL.appendingPathComponent("assets/goose_avatar.jpg")
        ]
        for candidate in candidates {
            if let candidate = candidate, fileManager.fileExists(atPath: candidate.path) {
                sourceUrl = candidate
                break
            }
        }

        do {
            if let src = sourceUrl, fileManager.fileExists(atPath: src.path) {
                if fileManager.fileExists(atPath: stickerUrl.path) {
                    try? fileManager.removeItem(at: stickerUrl)
                }
                try fileManager.copyItem(at: src, to: stickerUrl)
            } else {
                // 若找不到實體檔案，自繪一張精緻阿鵝貼圖
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 320))
                let image = renderer.image { ctx in
                    let bounds = CGRect(x: 0, y: 0, width: 320, height: 320)
                    UIColor(red: 0.12, green: 0.16, blue: 0.22, alpha: 1.0).setFill()
                    ctx.fill(bounds)

                    let circle = UIBezierPath(ovalIn: CGRect(x: 30, y: 30, width: 260, height: 260))
                    UIColor(red: 0.83, green: 0.69, blue: 0.22, alpha: 0.25).setFill()
                    circle.fill()

                    let text = "🦆\n阿鵝管家"
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.alignment = .center
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 52, weight: .bold),
                        .foregroundColor: UIColor.white,
                        .paragraphStyle: paragraphStyle
                    ]
                    (text as NSString).draw(in: CGRect(x: 20, y: 80, width: 280, height: 180), withAttributes: attrs)
                }
                if let data = image.jpegData(compressionQuality: 0.9) {
                    try data.write(to: stickerUrl)
                }
            }

            return try UNNotificationAttachment(identifier: "goose_sticker_attachment", url: stickerUrl, options: nil)
        } catch {
            print("Failed to create sticker attachment: \(error)")
            return nil
        }
    }

    public static func evaluateNotificationFeedback(_ msg: String) {
        DispatchQueue.main.async {
            let escaped = msg.replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\n", with: " ")
            for scene in UIApplication.shared.connectedScenes {
                if let winScene = scene as? UIWindowScene {
                    if let mainVC = winScene.windows.first?.rootViewController as? MainViewController {
                        mainVC.bridge?.webView?.evaluateJavaScript("if(typeof showToast==='function') showToast('\(escaped)');", completionHandler: nil)
                    } else if let bridgeVC = winScene.windows.first?.rootViewController as? CAPBridgeViewController {
                        bridgeVC.bridge?.webView?.evaluateJavaScript("if(typeof showToast==='function') showToast('\(escaped)');", completionHandler: nil)
                    }
                }
            }
        }
    }
}

// MARK: - 自訂 Bridge ViewController (支援 JavaScript MessageHandler 與原生照片儲存)
class MainViewController: CAPBridgeViewController, WKScriptMessageHandler {
    override func capacitorDidLoad() {
        super.capacitorDidLoad()
        setupMessageHandlers()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupMessageHandlers()
    }

    private func setupMessageHandlers() {
        let ucc = self.webView?.configuration.userContentController ?? self.bridge?.webView?.configuration.userContentController
        let handlers = [
            "startLiveActivity",
            "updateQuickCopyActivity",
            "scheduleSceneNotification",
            "scheduleCardActionNotification",
            "scheduleReplyNotification",
            "openSystemSettings",
            "syncDynamicShortcuts",
            "saveImageToPhotos"
        ]
        handlers.forEach { ucc?.removeScriptMessageHandler(forName: $0) }
        handlers.forEach { ucc?.add(self, name: $0) }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "startLiveActivity" {
            if #available(iOS 16.2, *) {
                LiveActivityManager.startTaoyuanMetroActivity()
            }
        } else if message.name == "updateQuickCopyActivity" {
            if #available(iOS 16.2, *) {
                if let rawList = message.body as? [[String: Any]] {
                    let items = rawList.map { dict -> QuickCopyItemData in
                        let id = dict["id"] as? String ?? UUID().uuidString
                        let text = dict["text"] as? String ?? ""
                        let label = dict["name"] as? String ?? (text.isEmpty ? "項目" : text)
                        let isLink = dict["isLink"] as? Bool ?? false
                        return QuickCopyItemData(id: id, label: label, text: text, isLink: isLink)
                    }
                    QuickCopyManager.startOrUpdateQuickCopy(items: items)
                }
            }
        } else if message.name == "scheduleSceneNotification" || message.name == "scheduleCardActionNotification" {
            NotificationManager.scheduleCardActionNotification()
        } else if message.name == "scheduleReplyNotification" {
            NotificationManager.scheduleReplyWithStickerNotification()
        } else if message.name == "openSystemSettings" {
            NotificationManager.openSystemSettings()
        } else if message.name == "syncDynamicShortcuts" {
            if let rawList = message.body as? [[String: Any]] {
                let items = rawList.map { dict -> QuickCopyItemData in
                    let id = dict["id"] as? String ?? UUID().uuidString
                    let text = dict["text"] as? String ?? ""
                    let label = dict["name"] as? String ?? (text.isEmpty ? "項目" : text)
                    let isLink = dict["isLink"] as? Bool ?? false
                    return QuickCopyItemData(id: id, label: label, text: text, isLink: isLink)
                }
                if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
                    sceneDelegate.updateDynamicQuickActions(items: items)
                }
            }
        } else if message.name == "saveImageToPhotos" {
            if let base64Str = message.body as? String {
                saveBase64ToPhotos(base64Str)
            }
        }
    }

    private func saveBase64ToPhotos(_ str: String) {
        let cleanStr = str.components(separatedBy: ",").last ?? str
        if let data = Data(base64Encoded: cleanStr), let image = UIImage(data: data) {
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(imageSaved(_:didFinishSavingWithError:contextInfo:)), nil)
        } else {
            self.bridge?.webView?.evaluateJavaScript("if(typeof showToast==='function') showToast('圖片格式解析失敗');", completionHandler: nil)
        }
    }

    @objc func imageSaved(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        DispatchQueue.main.async {
            if let error = error {
                self.bridge?.webView?.evaluateJavaScript("if(typeof showToast==='function') showToast('儲存至照片失敗：\(error.localizedDescription)');", completionHandler: nil)
            } else {
                self.bridge?.webView?.evaluateJavaScript("if(typeof showToast==='function') showToast('已成功儲存圖片至系統照片！');", completionHandler: nil)
            }
        }
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate, UNUserNotificationCenterDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // 確保通知代理為 self 或委派給 AppDelegate
        UNUserNotificationCenter.current().delegate = self

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = MainViewController()
        window?.makeKeyAndVisible()

        SceneDelegateProxy.shared.scene(scene, willConnectTo: session, options: connectionOptions)

        // 處理冷啟動時的 Quick Action
        if let shortcutItem = connectionOptions.shortcutItem {
            handleShortcutItem(shortcutItem)
        }
        
        // 處理冷啟動時的 URL Scheme
        if let url = connectionOptions.urlContexts.first?.url {
            handleDeepLink(url: url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        SceneDelegateProxy.shared.scene(scene, openURLContexts: URLContexts)
        guard let url = URLContexts.first?.url else { return }
        handleDeepLink(url: url)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        SceneDelegateProxy.shared.scene(scene, continue: userActivity)
    }

    // MARK: - 處理 3D Touch / 長按 App 圖標快速動作 (Home Screen Quick Actions)
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        handleShortcutItem(shortcutItem)
        completionHandler(true)
    }

    func updateDynamicQuickActions(items: [QuickCopyItemData]) {
        DispatchQueue.main.async {
            var shortcuts: [UIApplicationShortcutItem] = []
            for (idx, item) in items.prefix(3).enumerated() {
                let title = item.label.isEmpty ? (item.text.isEmpty ? "項目 \(idx + 1)" : item.text) : item.label
                let shortcut = UIApplicationShortcutItem(
                    type: "copy_dynamic_\(item.id)",
                    localizedTitle: title,
                    localizedSubtitle: item.text,
                    icon: UIApplicationShortcutIcon(type: .favorite),
                    userInfo: ["text": item.text as NSString]
                )
                shortcuts.append(shortcut)
            }
            shortcuts.append(
                UIApplicationShortcutItem(
                    type: "tab_wallet",
                    localizedTitle: "超級錢包",
                    localizedSubtitle: "出示票卡與感應乘車",
                    icon: UIApplicationShortcutIcon(type: .love),
                    userInfo: nil
                )
            )
            UIApplication.shared.shortcutItems = shortcuts
            print("Dynamic quick actions updated with \(shortcuts.count) items")
        }
    }

    private func handleShortcutItem(_ item: UIApplicationShortcutItem) {
        if item.type.hasPrefix("copy_dynamic_") {
            let text = (item.userInfo?["text"] as? String) ?? item.localizedSubtitle ?? ""
            if !text.isEmpty {
                UIPasteboard.general.string = text
                showCopiedToast(text)
            }
            return
        }

        switch item.type {
        case "copy_c1":
            UIPasteboard.general.string = "三山羊長老"
            showCopiedToast("三山羊長老")
        case "copy_c2":
            UIPasteboard.general.string = "我屁股好痛"
            showCopiedToast("我屁股好痛")
        case "copy_c3":
            UIPasteboard.general.string = "9879-2456"
            showCopiedToast("9879-2456")
        case "tab_wallet":
            evaluateJS("window.switchPage && window.switchPage('wallet')")
        default:
            break
        }
    }

    private func showCopiedToast(_ text: String) {
        evaluateJS("if(typeof showToast === 'function') showToast('已自桌面快捷複製：\(text)');")
    }

    // MARK: - 處理 Deep Link 與情境通知 / 動態島觸發
    func handleDeepLink(url: URL) {
        let urlStr = url.absoluteString
        print("Handling deep link: \(urlStr)")

        if urlStr.contains("start-mrt") {
            if #available(iOS 16.2, *) {
                LiveActivityManager.startTaoyuanMetroActivity()
                showCopiedToast("桃園捷運搭乘動態島已開啟！請退回桌面查看")
            }
            return
        }

        if urlStr.contains("schedule-notification") || urlStr.contains("schedule-card-action") {
            NotificationManager.scheduleCardActionNotification()
            return
        }

        if urlStr.contains("schedule-reply-notification") {
            NotificationManager.scheduleReplyWithStickerNotification()
            return
        }

        if urlStr.contains("open-settings") {
            NotificationManager.openSystemSettings()
            return
        }

        if urlStr.contains("sync-quick-copy") {
            if #available(iOS 16.2, *) {
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let itemsParam = components.queryItems?.first(where: { $0.name == "items" })?.value,
                   let data = itemsParam.data(using: .utf8),
                   let list = try? JSONDecoder().decode([QuickCopyItemData].self, from: data) {
                    QuickCopyManager.startOrUpdateQuickCopy(items: list)
                }
            }
            return
        }

        if urlStr.contains("add-copy-pasteboard") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                if let img = UIPasteboard.general.image, let jpegData = img.jpegData(compressionQuality: 0.6) {
                    let base64 = "data:image/jpeg;base64," + jpegData.base64EncodedString()
                    self?.evaluateJS("if(typeof window.handleSharedPasteboard==='function'){ window.handleSharedPasteboard('\(base64)'); }")
                } else if let txt = UIPasteboard.general.string {
                    if let jsonData = try? JSONSerialization.data(withJSONObject: ["payload": txt]),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        self?.evaluateJS("if(typeof window.handleSharedPasteboardJson==='function'){ window.handleSharedPasteboardJson(\(jsonString)); }")
                    }
                }
            }
            return
        }

        if urlStr.contains("copy?text=") {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let textParam = components.queryItems?.first(where: { $0.name == "text" })?.value {
                UIPasteboard.general.string = textParam
                showCopiedToast(textParam)
                if #available(iOS 16.2, *) {
                    QuickCopyManager.notifyItemCopied(text: textParam)
                }
            }
        }

        if let encoded = urlStr.addingPercentEncoding(withAllowedCharacters: .alphanumerics) {
            evaluateJS("if(typeof window.handleDeepLink==='function'){ window.handleDeepLink(decodeURIComponent('\(encoded)')); }")
        }
    }

    // 前台接收通知時仍然以橫幅彈出
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge, .list])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    // 點擊通知跳轉
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
        } else {
            if let urlStr = response.notification.request.content.userInfo["url"] as? String, let url = URL(string: urlStr) {
                handleDeepLink(url: url)
            }
            completionHandler()
        }
    }

    func evaluateJS(_ js: String) {
        let exec = { [weak self] in
            guard let self = self else { return }
            var webView: WKWebView? = nil
            if let bridgeVC = self.window?.rootViewController as? CAPBridgeViewController {
                webView = bridgeVC.bridge?.webView
            } else if let mainVC = self.window?.rootViewController as? MainViewController {
                webView = mainVC.bridge?.webView
            }
            if let wv = webView {
                wv.evaluateJavaScript(js) { res, err in
                    if let err = err {
                        print("evaluateJS error: \(err)")
                    } else {
                        print("evaluateJS succeeded!")
                    }
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.evaluateJS(js)
                }
            }
        }

        if Thread.isMainThread {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: exec)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: exec)
        }
    }
}
