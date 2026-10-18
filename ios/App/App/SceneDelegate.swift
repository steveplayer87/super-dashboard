import UIKit
import Capacitor
import ActivityKit
import UserNotifications
import WebKit
import LocalAuthentication
import AudioToolbox

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

    enum CodingKeys: String, CodingKey {
        case id, label, name, text, isLink
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        let textVal = (try? container.decodeIfPresent(String.self, forKey: .text)) ?? ""
        self.text = textVal
        let lbl = (try? container.decodeIfPresent(String.self, forKey: .label))
        let nm = (try? container.decodeIfPresent(String.self, forKey: .name))
        self.label = lbl ?? nm ?? (textVal.isEmpty ? "項目" : String(textVal.prefix(12)))
        self.isLink = (try? container.decodeIfPresent(Bool.self, forKey: .isLink)) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(text, forKey: .text)
        try container.encode(isLink, forKey: .isLink)
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

        // 清理所有已存在或過期的第二動態島，保證重新乾淨啟動
        for activity in Activity<QuickCopyAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        var activeItems = items
        if activeItems.isEmpty {
            activeItems = [
                QuickCopyItemData(id: "c1", label: "三山羊長老", text: "三山羊長老", isLink: false),
                QuickCopyItemData(id: "c2", label: "我屁股好痛", text: "我屁股好痛", isLink: false),
                QuickCopyItemData(id: "c3", label: "9879-2456", text: "9879-2456", isLink: false)
            ]
        }
        let attributes = QuickCopyAttributes(title: "常用速貼庫")
        let contentState = QuickCopyAttributes.ContentState(
            items: Array(activeItems.prefix(5)),
            lastCopiedText: nil,
            updateTimestamp: Date().timeIntervalSince1970
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil)
            )
            DispatchQueue.main.async {
                NotificationManager.evaluateNotificationFeedback("常用速貼動態島已開啟！退回桌面即可直接點擊複製")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    // Suspend removed
                }
            }
        } catch {
            DispatchQueue.main.async {
                NotificationManager.evaluateNotificationFeedback("啟動動態島失敗：\(error.localizedDescription)")
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

// MARK: - 原生真實 Face ID 生物辨識管理器
class BiometricManager {
    static func authenticate(reason: String = "靠近掃碼器或讀卡機", completion: @escaping (Bool, String?) -> Void) {
        let context = LAContext()
        context.localizedCancelTitle = "取消"
        context.localizedFallbackTitle = "使用密碼"
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        AudioServicesPlaySystemSound(1519) // 輕微成功觸覺震動
                        completion(true, nil)
                    } else {
                        AudioServicesPlaySystemSound(1521) // 錯誤震動
                        completion(false, authError?.localizedDescription ?? "Face ID 認證未通過")
                    }
                }
            }
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        AudioServicesPlaySystemSound(1519)
                        completion(true, nil)
                    } else {
                        completion(false, authError?.localizedDescription ?? "密碼驗證未通過")
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                completion(false, error?.localizedDescription ?? "裝置未啟用 Face ID 或密碼保護")
            }
        }
    }
}

// MARK: - Notification Manager (完整支援自訂動作選項、圖片貼圖與文字即時回覆)
class NotificationManager {

    static func parseDelay(_ val: Any?) -> Double {
        if let num = val as? NSNumber {
            return num.doubleValue
        } else if let d = val as? Double {
            return d
        } else if let i = val as? Int {
            return Double(i)
        } else if let s = val as? String, let parsed = Double(s) {
            return parsed
        }
        return 0.0
    }

    // 當收到使用者的文字回覆時，即時派發系統反饋通知
    static func scheduleFeedbackNotification(replyText: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "阿鵝管家"
        content.subtitle = "已接收您的指令"
        content.body = "「收到您的回覆：『\(replyText)』！行程與備忘已為您同步記錄。」"
        content.sound = .default
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .active
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let req = UNNotificationRequest(identifier: "reply_feedback_\(UUID().uuidString)", content: content, trigger: trigger)
        center.add(req, withCompletionHandler: nil)
    }

    static let cardCategoryIdentifier = "CARD_ACTION_CATEGORY"
    static let replyCategoryIdentifier = "MESSAGE_REPLY_CATEGORY"

    static func setupCategories() {
        let center = UNUserNotificationCenter.current()

        // 類型 1：長按展開選項（打開卡片、打開錢包、忽略）
        let openCardAction = UNNotificationAction(
            identifier: "ACTION_OPEN_CARD",
            title: "快速出示悠遊卡",
            options: [.foreground]
        )
        let openWalletAction = UNNotificationAction(
            identifier: "ACTION_OPEN_WALLET",
            title: "開啟超級錢包",
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
            title: "回覆訊息",
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

    // 檢查通知授權狀態並同步給前端診斷
    static func checkAndReportStatus() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            print("[Notification] settings.authorizationStatus: \(settings.authorizationStatus.rawValue), alertSetting: \(settings.alertSetting.rawValue)")
            var statusStr = "unknown"
            var desc = ""
            switch settings.authorizationStatus {
            case .authorized:
                statusStr = "authorized"
                desc = "已允許通知 (橫幅狀態: \(settings.alertSetting == .enabled ? "開啟" : "關閉"))"
            case .denied:
                statusStr = "denied"
                desc = "系統權限遭拒，請至 iPhone 設定開啟"
            case .notDetermined:
                statusStr = "notDetermined"
                desc = "尚未請求權限"
            case .provisional:
                statusStr = "provisional"
                desc = "靜音通知模式"
            case .ephemeral:
                statusStr = "ephemeral"
                desc = "臨時授權"
            @unknown default:
                statusStr = "unknown"
                desc = "未知狀態"
            }
            DispatchQueue.main.async {
                evaluateJS("if(typeof window.updateNotificationStatus==='function') window.updateNotificationStatus('\(statusStr)', '\(desc)');")
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
    static func scheduleCardActionNotification(delay: Double = 0.0) {
        print("[Notification] scheduleCardActionNotification requested with delay: \(delay)")
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            let fireNotification = {
                let content = UNMutableNotificationContent()
                content.title = "場景自動感知 · 靠近高鐵桃園站"
                content.subtitle = "長按此通知可展開快速操作"
                content.body = "偵測到您在 桃園高鐵捷運閘門，請選擇快速操作："
                content.sound = .default
                if #available(iOS 15.0, *) {
                    content.interruptionLevel = .active
                    content.relevanceScore = 1.0
                }
                content.categoryIdentifier = cardCategoryIdentifier
                content.userInfo = ["url": "superdashboard://wallet?card=easycard"]

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay > 0 ? delay : 1.0, repeats: false)
                let req = UNNotificationRequest(identifier: "card_action_\(UUID().uuidString)", content: content, trigger: trigger)

                center.add(req) { err in
                    print("[Notification] center.add completed for req: \(req.identifier), error: \(String(describing: err))")
                    DispatchQueue.main.async {
                        AudioServicesPlaySystemSound(1007) // 播放提示音響
                        if let err = err {
                            evaluateNotificationFeedback("排程失敗：\(err.localizedDescription)")
                        } else {
                            if delay > 0 {
                                evaluateNotificationFeedback("已排程 \(Int(delay)) 秒後發送！請現在按電源鍵鎖定螢幕或退回桌面觀看！")
                            } else {
                                evaluateNotificationFeedback("長按選項通知已發送！頂部將立即下彈橫幅")
                            }
                        }
                    }
                }
            }

            if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                fireNotification()
            } else if settings.authorizationStatus == .notDetermined {
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    if granted {
                        fireNotification()
                    } else {
                        DispatchQueue.main.async {
                            evaluateNotificationFeedback("請在系統彈窗點選允許以接收通知")
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    evaluateNotificationFeedback("通知權限遭拒！請至 iPhone「設定 > Super Dashboard > 通知」開啟允許通知。")
                    checkAndReportStatus()
                }
            }
        }
    }

    // 測試 2：帶貼圖圖片 + 可回覆文字通知
    static func scheduleReplyWithStickerNotification(delay: Double = 0.0) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            let fireNotification = {
                let content = UNMutableNotificationContent()
                content.title = "阿鵝管家"
                content.subtitle = "傳送了一張貼圖給您"
                content.body = "「早安！今天的行程票卡與高鐵憑證已準備好，長按即可直接輸入文字回覆我喔！」"
                content.sound = .default
                if #available(iOS 15.0, *) {
                    content.interruptionLevel = .active
                    content.relevanceScore = 1.0
                }
                content.categoryIdentifier = replyCategoryIdentifier
                content.userInfo = ["type": "chat_reply"]

                if let attachment = createStickerAttachment() {
                    content.attachments = [attachment]
                }

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay > 0 ? delay : 1.0, repeats: false)
                let req = UNNotificationRequest(identifier: "reply_sticker_\(UUID().uuidString)", content: content, trigger: trigger)

                center.add(req) { err in
                    DispatchQueue.main.async {
                        AudioServicesPlaySystemSound(1007)
                        if let err = err {
                            evaluateNotificationFeedback("排程失敗：\(err.localizedDescription)")
                        } else {
                            if delay > 0 {
                                evaluateNotificationFeedback("已排程 \(Int(delay)) 秒後發送！請現在按電源鍵鎖屏或退回桌面觀看！")
                            } else {
                                evaluateNotificationFeedback("貼圖回覆通知已發送！長按頂部通知條即可直接回覆輸入")
                            }
                        }
                    }
                }
            }

            if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                fireNotification()
            } else if settings.authorizationStatus == .notDetermined {
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    if granted {
                        fireNotification()
                    }
                }
            } else {
                DispatchQueue.main.async {
                    evaluateNotificationFeedback("通知權限遭拒！請至 iPhone「設定 > Super Dashboard > 通知」開啟允許通知。")
                    checkAndReportStatus()
                }
            }
        }
    }

    private static func createStickerAttachment() -> UNNotificationAttachment? {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let stickerUrl = tempDir.appendingPathComponent("goose_sticker.jpg")

        var sourceUrl: URL? = nil
        let candidates = [
            Bundle.main.url(forResource: "goose_avatar", withExtension: "jpg"),
            Bundle.main.url(forResource: "public/assets/goose_avatar", withExtension: "jpg"),
            Bundle.main.bundleURL.appendingPathComponent("public/assets/goose_avatar.jpg"),
            Bundle.main.bundleURL.appendingPathComponent("assets/goose_avatar.jpg"),
            Bundle.main.bundleURL.appendingPathComponent("goose_avatar.jpg")
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
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 320))
                let image = renderer.image { ctx in
                    let bounds = CGRect(x: 0, y: 0, width: 320, height: 320)
                    UIColor(red: 0.12, green: 0.16, blue: 0.22, alpha: 1.0).setFill()
                    ctx.fill(bounds)

                    let circle = UIBezierPath(ovalIn: CGRect(x: 30, y: 30, width: 260, height: 260))
                    UIColor(red: 0.83, green: 0.69, blue: 0.22, alpha: 0.25).setFill()
                    circle.fill()

                    let text = "阿鵝管家"
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
            evaluateJS("if(typeof showToast==='function') showToast('\(escaped)');")
        }
    }

    public static func evaluateJS(_ js: String) {
        DispatchQueue.main.async {
            for scene in UIApplication.shared.connectedScenes {
                if let winScene = scene as? UIWindowScene {
                    for win in winScene.windows {
                        if let bridgeVC = win.rootViewController as? CAPBridgeViewController {
                            bridgeVC.webView?.evaluateJavaScript(js, completionHandler: nil)
                        } else if let mainVC = win.rootViewController as? MainViewController {
                            mainVC.webView?.evaluateJavaScript(js, completionHandler: nil)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 自訂 Bridge ViewController (支援 JavaScript MessageHandler、URL Scheme 與原生 Face ID)
class MainViewController: CAPBridgeViewController, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
    override func capacitorDidLoad() {
        super.capacitorDidLoad()
        setupDelegatesAndHandlers()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupDelegatesAndHandlers()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupDelegatesAndHandlers()
        NotificationManager.checkAndReportStatus()
    }

    private func setupDelegatesAndHandlers() {
        guard let wv = self.webView else { return }
        wv.navigationDelegate = self
        wv.uiDelegate = self

        let ucc = wv.configuration.userContentController
        let handlers = [
            "startLiveActivity",
            "updateQuickCopyActivity",
            "scheduleSceneNotification",
            "scheduleCardActionNotification",
            "scheduleReplyNotification",
            "openSystemSettings",
            "checkNotificationStatus",
            "authenticateFaceID",
            "syncDynamicShortcuts",
            "saveImageToPhotos",
            "superdashboard"
        ]
        handlers.forEach { ucc.removeScriptMessageHandler(forName: $0) }
        handlers.forEach { ucc.add(self, name: $0) }
    }

    // 核心攔截：當 JavaScript 導航或請求 superdashboard:// 時，100% 捕獲並轉發給 handleDeepLink
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, url.scheme == "superdashboard" {
            decisionHandler(.cancel)
            DispatchQueue.main.async {
                (UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate)?.handleDeepLink(url: url)
            }
            return
        }
        decisionHandler(.allow)
    }

    // 備援通道：攔截 window.prompt("superdashboard:...")
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        if prompt.hasPrefix("superdashboard:") {
            let command = String(prompt.dropFirst("superdashboard:".count))
            DispatchQueue.main.async {
                if let url = URL(string: "superdashboard://" + command) {
                    (UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate)?.handleDeepLink(url: url)
                }
            }
            completionHandler("OK")
            return
        }
        completionHandler(defaultText)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "superdashboard" {
            if let body = message.body as? [String: Any], let action = body["action"] as? String {
                handleUnifiedAction(action: action, params: body["params"])
            }
            return
        }

        if message.name == "startLiveActivity" {
            handleUnifiedAction(action: "start-mrt", params: nil)
        } else if message.name == "updateQuickCopyActivity" {
            handleUnifiedAction(action: "sync-quick-copy", params: message.body)
        } else if message.name == "scheduleSceneNotification" || message.name == "scheduleCardActionNotification" {
            let delay = (message.body as? [String: Any])?["delay"] as? Double ?? 0.0
            NotificationManager.scheduleCardActionNotification(delay: delay)
        } else if message.name == "scheduleReplyNotification" {
            let delay = (message.body as? [String: Any])?["delay"] as? Double ?? 0.0
            NotificationManager.scheduleReplyWithStickerNotification(delay: delay)
        } else if message.name == "openSystemSettings" {
            NotificationManager.openSystemSettings()
        } else if message.name == "checkNotificationStatus" {
            NotificationManager.checkAndReportStatus()
        } else if message.name == "authenticateFaceID" {
            handleUnifiedAction(action: "auth-faceid", params: nil)
        } else if message.name == "syncDynamicShortcuts" {
            if let rawList = message.body as? [[String: Any]] {
                let items = rawList.map { dict -> QuickCopyItemData in
                    let id = dict["id"] as? String ?? UUID().uuidString
                    let text = dict["text"] as? String ?? ""
                    let label = dict["label"] as? String ?? dict["name"] as? String ?? (text.isEmpty ? "項目" : text)
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

    private func handleUnifiedAction(action: String, params: Any?) {
        let act = action.lowercased()
        if act == "auth-faceid" || act == "authfaceid" {
            BiometricManager.authenticate(reason: "靠近掃碼器或讀卡機") { [weak self] success, err in
                if success {
                    self?.webView?.evaluateJavaScript("if(typeof window.onFaceIDSuccess==='function') window.onFaceIDSuccess();", completionHandler: nil)
                } else {
                    let msg = (err ?? "驗證未通過").replacingOccurrences(of: "'", with: "\'")
                    self?.webView?.evaluateJavaScript("if(typeof window.onFaceIDFailure==='function') window.onFaceIDFailure('\(msg)');", completionHandler: nil)
                }
            }
            return
        }

        if act == "start-mrt" || act == "startmrt" {
            if #available(iOS 16.2, *) {
                LiveActivityManager.startTaoyuanMetroActivity()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    // Suspend removed
                }
            }
            return
        }

        if act == "sync-quick-copy" || act == "syncquickcopy" {
            if #available(iOS 16.2, *) {
                var list: [QuickCopyItemData] = []
                var rawList: [[String: Any]] = []
                if let arr = params as? [[String: Any]] {
                    rawList = arr
                } else if let dict = params as? [String: Any], let arr = dict["items"] as? [[String: Any]] {
                    rawList = arr
                }
                list = rawList.map { dict in
                    let id = dict["id"] as? String ?? UUID().uuidString
                    let text = dict["text"] as? String ?? ""
                    let label = dict["label"] as? String ?? dict["name"] as? String ?? (text.isEmpty ? "項目" : text)
                    let isLink = dict["isLink"] as? Bool ?? false
                    return QuickCopyItemData(id: id, label: label, text: text, isLink: isLink)
                }
                QuickCopyManager.startOrUpdateQuickCopy(items: list)
            }
            return
        }

        if act == "suspend" || act == "suspend-app" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Suspend removed
            }
            return
        }

        if act == "schedule-card-action" {
            let delay = NotificationManager.parseDelay((params as? [String: Any])?["delay"])
            NotificationManager.scheduleCardActionNotification(delay: delay)
            return
        }

        if act == "schedule-reply-notification" {
            let delay = NotificationManager.parseDelay((params as? [String: Any])?["delay"])
            NotificationManager.scheduleReplyWithStickerNotification(delay: delay)
            return
        }

        if act == "open-settings" {
            NotificationManager.openSystemSettings()
            return
        }

        if act == "check-status" || act == "checknotificationstatus" {
            NotificationManager.checkAndReportStatus()
            return
        }
    }

    private func saveBase64ToPhotos(_ str: String) {
        let cleanStr = str.components(separatedBy: ",").last ?? str
        if let data = Data(base64Encoded: cleanStr), let image = UIImage(data: data) {
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(imageSaved(_:didFinishSavingWithError:contextInfo:)), nil)
        } else {
            self.webView?.evaluateJavaScript("if(typeof showToast==='function') showToast('圖片格式解析失敗');", completionHandler: nil)
        }
    }

    @objc func imageSaved(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        DispatchQueue.main.async {
            if let error = error {
                self.webView?.evaluateJavaScript("if(typeof showToast==='function') showToast('儲存至照片失敗：\(error.localizedDescription)');", completionHandler: nil)
            } else {
                self.webView?.evaluateJavaScript("if(typeof showToast==='function') showToast('已成功儲存圖片至系統照片！');", completionHandler: nil)
            }
        }
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate, UNUserNotificationCenterDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // 保證通知代理為 AppDelegate
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            UNUserNotificationCenter.current().delegate = self
        } else {
            UNUserNotificationCenter.current().delegate = self
        }

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

        if urlStr.contains("wallet") {
            let cardKeyword = urlStr.contains("easycard") ? "悠遊卡" : ""
            let js = "if(typeof window.navigateToWallet==='function') window.navigateToWallet('\(cardKeyword)');"
            self.evaluateJS(js)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.evaluateJS(js) }
            return
        }


        if urlStr.contains("start-mrt") {
            if #available(iOS 16.2, *) {
                LiveActivityManager.startTaoyuanMetroActivity()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    // Suspend removed
                }
            }
            return
        }

        if urlStr.contains("schedule-notification") || urlStr.contains("schedule-card-action") {
            let delay = urlStr.contains("delay=4") ? 4.0 : (urlStr.contains("delay=3") ? 3.0 : 0.0)
            NotificationManager.scheduleCardActionNotification(delay: delay)
            return
        }

        if urlStr.contains("schedule-reply-notification") {
            let delay = urlStr.contains("delay=4") ? 4.0 : (urlStr.contains("delay=3") ? 3.0 : 0.0)
            NotificationManager.scheduleReplyWithStickerNotification(delay: delay)
            return
        }

        if urlStr.contains("check-notification-status") {
            NotificationManager.checkAndReportStatus()
            return
        }

        if urlStr.contains("auth-faceid") {
            BiometricManager.authenticate(reason: "靠近掃碼器或讀卡機") { [weak self] success, err in
                if success {
                    self?.evaluateJS("if(typeof window.onFaceIDSuccess==='function') window.onFaceIDSuccess();")
                } else {
                    let msg = (err ?? "認證取消").replacingOccurrences(of: "'", with: "\\'")
                    self?.evaluateJS("if(typeof window.onFaceIDFailure==='function') window.onFaceIDFailure('\(msg)');")
                }
            }
            return
        }

        if urlStr.contains("open-settings") {
            NotificationManager.openSystemSettings()
            return
        }

        if urlStr.contains("sync-quick-copy") {
            if #available(iOS 16.2, *) {
                var list: [QuickCopyItemData] = []
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let itemsParam = components.queryItems?.first(where: { $0.name == "items" })?.value,
                   let data = itemsParam.data(using: .utf8) {
                    list = (try? JSONDecoder().decode([QuickCopyItemData].self, from: data)) ?? []
                }
                QuickCopyManager.startOrUpdateQuickCopy(items: list)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    // Suspend removed
                }
            }
            return
        }

        if urlStr.contains("suspend") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Suspend removed
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

        // 精確匹配 copy?text=，排除 add-copy
        if urlStr.contains("/copy?text=") || (urlStr.contains("copy?text=") && !urlStr.contains("add-copy")) {
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
            let dispatchJs = { [weak self] in
                self?.evaluateJS("if(typeof window.handleDeepLink==='function'){ window.handleDeepLink(decodeURIComponent('\(encoded)')); }")
            }
            dispatchJs()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { dispatchJs() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dispatchJs() }
        }
    }

    // 前台接收通知時仍然以橫幅彈出 (直接保證下彈橫幅)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("[Notification] Foreground banner triggered for: \(notification.request.identifier)")
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    // 點擊通知跳轉與互動回覆處理
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let actionId = response.actionIdentifier
        print("[Notification] SceneDelegate didReceive action: \(actionId)")

        if actionId == "ACTION_REPLY", let textResponse = response as? UNTextInputNotificationResponse {
            let replyText = textResponse.userText
            print("[Notification] Received inline reply: \(replyText)")
            NotificationManager.scheduleFeedbackNotification(replyText: replyText)
            DispatchQueue.main.async {
                let escaped = replyText.replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\n", with: " ")
                NotificationManager.evaluateJS("if(typeof window.onNotificationReply==='function'){ window.onNotificationReply('\(escaped)'); }")
            }
        } else if actionId == "ACTION_OPEN_CARD" {
            DispatchQueue.main.async {
                NotificationManager.evaluateJS("if(typeof window.navigateToWallet==='function') window.navigateToWallet('悠遊卡');")
            }
        } else if actionId == "ACTION_OPEN_WALLET" {
            DispatchQueue.main.async {
                NotificationManager.evaluateJS("if(typeof window.navigateToWallet==='function') window.navigateToWallet();")
            }
        } else if let urlStr = response.notification.request.content.userInfo["url"] as? String, let url = URL(string: urlStr) {
            handleDeepLink(url: url)
        }

        completionHandler()
    }

    func evaluateJS(_ js: String) {
        NotificationManager.evaluateJS(js)
    }
}
