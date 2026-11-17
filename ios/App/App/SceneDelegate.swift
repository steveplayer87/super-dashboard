import UIKit
import Capacitor
import ActivityKit
import UserNotifications
import WebKit
import Photos
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation
import CoreLocation
import CoreImage
import ImageIO
import FileProvider
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
/// 清理來自網頁的字串：重新以 UTF-16 解碼（落單代理字元會被換成 U+FFFD，避免原生 API 取得 NULL 字串而當機）、
/// 移除控制字元、限制長度、空字串時使用備用文字。
func cleanedString(_ s: String, max: Int, fallback: String = "") -> String {
    let rebuilt = String(decoding: Array(s.utf16), as: UTF16.self)
    let filtered = String(String.UnicodeScalarView(rebuilt.unicodeScalars.filter { $0.value >= 0x20 || $0 == "\n" }))
    let limited = String(filtered.prefix(max))
    return limited.isEmpty ? fallback : limited
}

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
    static var timer: Timer?
    static var startTime: Date?
    
    // 依據桃園捷運官方行車時刻：A12到A21全程約33分鐘(2000秒)，A12到A18約21分鐘(1260秒)
    // 模擬動態演示：將全程加速為動態循環演示(或真實時間演示)
    static var currentTripSeconds: Double = 900 // 初始在 A16-A17 之間，往 A18 高鐵桃園站前進
    
    static func startTaoyuanMetroActivity() {
        for activity in Activity<TaoyuanMetroAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        timer?.invalidate()
        startTime = Date()
        currentTripSeconds = 980 // 距離 A18(1260秒) 還剩約 4.6 分鐘，進度在 49%，指標絕不超前

        let attributes = TaoyuanMetroAttributes(
            lineName: "桃園捷運 機場線",
            trainType: "直達車 112"
        )
        
        let state = calculateMetroState(elapsedSeconds: currentTripSeconds)

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
            print("[Metro] Started with state: progress=\(state.progress), next=\(state.nextStation)")
            expandMetroIsland()
            
            // 每 2.5 秒更新一次即時動態，使動態島與鎖屏保持流暢即時推進
            DispatchQueue.main.async {
                timer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
                    updateMetroProgress()
                }
            }
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }
    
    /// 退回主畫面後，以「帶提醒的更新」讓動態島自動展開數秒
    static func expandMetroIsland() {
        guard let activity = currentActivity else { return }
        IslandPresenter.leaveThenRun {
            let state = activity.content.state
            await activity.update(
                ActivityContent(state: state, staleDate: nil),
                alertConfiguration: AlertConfiguration(
                    title: "桃園捷運",
                    body: "已開始追蹤，下一站 \(state.nextStation)",
                    sound: .default
                )
            )
        }
    }

    static func updateMetroProgress() {
        guard let activity = currentActivity else { return }
        currentTripSeconds += 20 // 每次前進20秒里程
        if currentTripSeconds > 2100 {
            currentTripSeconds = 300 // 循環演示
        }
        let newState = calculateMetroState(elapsedSeconds: currentTripSeconds)
        Task {
            await activity.update(.init(state: newState, staleDate: nil))
        }
    }
    
    // 桃捷官方各站累積秒數 (A12出發: A12=0, A13=180s, A14a=420s, A15=600s, A16=780s, A17=960s, A18=1260s, A19=1380s, A20=1680s, A21=2000s)
    static func calculateMetroState(elapsedSeconds: Double) -> TaoyuanMetroAttributes.ContentState {
        let totalTrip: Double = 2000.0 // A12 到 A21
        let a18Arrival: Double = 1260.0 // A18抵達時間
        
        // 進度比例：A18固定在 63.0% (1260/2000)
        let rawProgress = min(max(elapsedSeconds / totalTrip, 0.05), 0.98)
        
        var nextSt = "A18 高鐵桃園站"
        var curSt = "A12 機場一航"
        var etaMin = 0
        var status = "行駛中"
        
        if elapsedSeconds < a18Arrival - 90 {
            // 還在領航站往高鐵桃園站途中
            curSt = "A17 領航"
            nextSt = "A18 高鐵桃園站"
            etaMin = max(1, Int((a18Arrival - elapsedSeconds) / 60))
            status = "準點行駛"
        } else if elapsedSeconds < a18Arrival {
            // 距離 A18 不到 90 秒
            curSt = "A17 領航"
            nextSt = "A18 高鐵桃園站"
            etaMin = 1
            status = "即將進站"
        } else if elapsedSeconds < a18Arrival + 35 {
            // 正停靠在 A18
            curSt = "A18 高鐵桃園"
            nextSt = "A19 體育園區"
            etaMin = 0
            status = "停靠站中"
        } else {
            // 已出發前往 A19 / A21
            curSt = "A18 高鐵桃園"
            nextSt = "A19 體育園區"
            etaMin = max(1, Int((1380 - elapsedSeconds) / 60))
            status = "往中壢延伸"
        }
        
        return TaoyuanMetroAttributes.ContentState(
            currentStation: curSt,
            nextStation: nextSt,
            destination: "A21 環北站",
            progress: rawProgress,
            etaMinutes: etaMin,
            fare: "NT$ 35",
            statusText: status
        )
    }

    static func stopActivity() {
        timer?.invalidate()
        timer = nil
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
            items: Array(activeItems.prefix(6)),
            lastCopiedText: nil,
            updateTimestamp: Date().timeIntervalSince1970
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil)
            )
            DispatchQueue.main.async {
                NotificationManager.evaluateNotificationFeedback("常用速貼動態島已開啟！")
                expandQuickCopyIsland()
            }
        } catch {
            DispatchQueue.main.async {
                NotificationManager.evaluateNotificationFeedback("啟動動態島失敗：\(error.localizedDescription)")
            }
        }
    }

    /// 退回主畫面後，以「帶提醒的更新」讓動態島自動展開數秒
    static func expandQuickCopyIsland() {
        guard let activity = currentActivity else { return }
        IslandPresenter.leaveThenRun {
            let state = activity.content.state
            await activity.update(
                ActivityContent(state: state, staleDate: nil),
                alertConfiguration: AlertConfiguration(
                    title: "常用速貼",
                    body: "點選項目即可複製",
                    sound: .default
                )
            )
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
    static func authenticate(reason: String = "驗證身分以使用卡片", completion: @escaping (Bool, String?) -> Void) {
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
// MARK: - App 圖示切換（供網頁訊息與網址連結共用）
enum AppIconManager {
    /// name 為 nil / "" / "default" 時還原成主要圖示（AppIcon，也就是恐龍原廠圖示）
    static func apply(name: String?, completion: @escaping (Bool, String) -> Void) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let target: String? = (trimmed.isEmpty || trimmed.lowercased() == "default") ? nil : trimmed
        DispatchQueue.main.async {
            guard UIApplication.shared.supportsAlternateIcons else {
                completion(false, "此裝置不支援更換 App 圖示")
                return
            }
            if UIApplication.shared.alternateIconName == target {
                completion(true, "目前已經是這個圖示")
                return
            }
            UIApplication.shared.setAlternateIconName(target) { err in
                DispatchQueue.main.async {
                    if let err = err {
                        print("[AppIcon] Error setting alternate icon: \(err.localizedDescription)")
                        completion(false, "切換失敗：\(err.localizedDescription)")
                    } else {
                        print("[AppIcon] Successfully set alternate icon to: \(String(describing: target))")
                        completion(true, "已切換 App 圖示")
                    }
                }
            }
        }
    }

    /// 把結果回報給網頁（window.onAppIconResult）
    static func report(success: Bool, message: String) {
        let escaped = message.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
        NotificationManager.evaluateJS("if(typeof window.onAppIconResult==='function') window.onAppIconResult(\(success), '\(escaped)');")
    }
}

class NotificationManager {

    // 全域待跳轉目標，解決冷啟動時 WebKit 還在加載導致 evaluateJS 丟失
    public static var pendingTarget: String? = nil

    public static func executeTargetJump(target: String) {
        pendingTarget = target
        let kw = (target == "WALLET_HOME") ? "" : target
        let js = "if(typeof window.navigateToWallet==='function'){ window.navigateToWallet('" + kw + "'); }"
        
        // 多階梯重試機制 (立即、0.2秒、0.5秒、1.0秒、2.0秒)，保證網頁任何生命週期均能成功收到
        evaluateJS(js)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { evaluateJS(js) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { evaluateJS(js) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { evaluateJS(js) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { evaluateJS(js) }
    }


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
    static func scheduleUpdateNotification(version: String) {
        let defaults = UserDefaults.standard
        let key = "sd-notified-update-version"
        guard defaults.string(forKey: key) != version else { return }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional || settings.authorizationStatus == .ephemeral else { return }
            let content = UNMutableNotificationContent()
            content.title = "超級儀表板已更新至 \(version)"
            content.body = "相機與相片庫有更新，點擊品牌標題或關於版本可查看更新說明。"
            content.sound = .default
            if #available(iOS 15.0, *) { content.interruptionLevel = .active }
            let request = UNNotificationRequest(identifier: "superdashboard-update-\(version)", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false))
            center.add(request) { error in
                if error == nil { defaults.set(version, forKey: key) }
                else { NSLog("[UpdateNotice] schedule failed: %@", error!.localizedDescription) }
            }
        }
    }

    static func scheduleFeedbackNotification(replyText: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
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

        // 類型 2：即時輸入回覆 (長按通知直接呼叫打字框)
        let replyAction = UNTextInputNotificationAction(
            identifier: "ACTION_REPLY",
            title: "輸入回覆",
            options: [],
            textInputButtonTitle: "傳送",
            textInputPlaceholder: "在此鍵入回覆阿鵝管家..."
        )
        let replyCategory = UNNotificationCategory(
            identifier: replyCategoryIdentifier,
            actions: [replyAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        center.setNotificationCategories([cardCategory, replyCategory])
    }

    // MARK: - 通用互動通知引擎
    static func scheduleInteractive(_ payload: [String: Any]) {
        let center = UNUserNotificationCenter.current()
        let workflowID = payload["workflowId"] as? String ?? UUID().uuidString
        let title = payload["title"] as? String ?? "超級儀表板"
        let body = payload["body"] as? String ?? "有一項待處理事項"
        let categoryID = "DASHBOARD_" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let rawActions = payload["actions"] as? [[String: Any]] ?? []
        var actions: [UNNotificationAction] = rawActions.prefix(3).compactMap { item in
            guard let id = item["id"] as? String, let label = item["title"] as? String else { return nil }
            return UNNotificationAction(identifier: "DASH_" + id, title: label, options: [.foreground])
        }
        if payload["allowsTextReply"] as? Bool == true {
            actions.append(UNTextInputNotificationAction(identifier: "DASH_TEXT_REPLY", title: "輸入回覆", options: [.foreground], textInputButtonTitle: "傳送", textInputPlaceholder: payload["replyPlaceholder"] as? String ?? "輸入回覆…"))
        }
        let category = UNNotificationCategory(identifier: categoryID, actions: actions, intentIdentifiers: [], options: [.customDismissAction])
        center.getNotificationCategories { existing in
            center.setNotificationCategories(existing.union([category]))
            let content = UNMutableNotificationContent()
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
            content.title = title; content.body = body; content.sound = .default; content.categoryIdentifier = categoryID
            var info: [String: Any] = ["workflowId": workflowID, "categoryId": categoryID]
            if let data = try? JSONSerialization.data(withJSONObject: payload), let json = String(data: data, encoding: .utf8) { info["dashboardPayload"] = json }
            content.userInfo = info
            let seconds = max(1, (payload["delay"] as? NSNumber)?.doubleValue ?? 1)
            center.add(UNNotificationRequest(identifier: "dashboard_" + workflowID, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)))
        }
    }

    static func recordInteraction(_ response: UNNotificationResponse) {
        let info = response.notification.request.content.userInfo
        guard let workflowID = info["workflowId"] as? String else { return }
        var event: [String: Any] = ["id": UUID().uuidString, "workflowId": workflowID, "actionId": response.actionIdentifier, "timestamp": ISO8601DateFormatter().string(from: Date()), "status": "pending"]
        if let text = response as? UNTextInputNotificationResponse { event["text"] = text.userText }
        if let raw = info["dashboardPayload"] { event["payload"] = raw }
        let defaults = UserDefaults(suiteName: "group.com.steveplayer87.superdashboard")
        var queue = defaults?.array(forKey: "dashboardNotificationEvents") as? [[String: Any]] ?? []
        queue.append(event); defaults?.set(queue, forKey: "dashboardNotificationEvents")
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName("com.steveplayer87.superdashboard.notification-event" as CFString), nil, nil, true)
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
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
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
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
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
class MainViewController: CAPBridgeViewController, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate, PHPickerViewControllerDelegate {
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    override var prefersStatusBarHidden: Bool { false }
    override var canBecomeFirstResponder: Bool { true }
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake,
              UserDefaults.standard.bool(forKey: "shakeReturnsToMore") else { return }
        webView?.evaluateJavaScript("if(typeof window.switchPage==='function'){window.switchPage('more');if(typeof window.showMoreSubView==='function')window.showMoreSubView('hub');}", completionHandler: nil)
    }
    override func capacitorDidLoad() {
        super.capacitorDidLoad()
        setupDelegatesAndHandlers()
        hideFormAccessoryBar()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupDelegatesAndHandlers()
        hideFormAccessoryBar()
        // 鍵盤即將出現時再確認一次（網頁內容檢視可能是之後才建立的）
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { [weak self] _ in
            self?.hideFormAccessoryBar()
        }
    }

    /// 隱藏鍵盤上方的「上一個／下一個／完成」表單工具列：
    /// 讓 WKWebView 的內容檢視改用一個「沒有 inputAccessoryView」的子類別。
    func hideFormAccessoryBar() {
        guard let content = webView?.scrollView.subviews.first(where: { String(describing: type(of: $0)).hasPrefix("WKContent") }) else { return }
        let baseName = String(describing: type(of: content))
        if baseName.hasSuffix("_NoAccessory") { return }
        let subclassName = baseName + "_NoAccessory"
        var subclass: AnyClass? = NSClassFromString(subclassName)
        if subclass == nil {
            guard let base = object_getClass(content),
                  let created = objc_allocateClassPair(base, subclassName, 0) else { return }
            let block: @convention(block) (AnyObject) -> AnyObject? = { _ in nil }
            class_addMethod(created, #selector(getter: UIResponder.inputAccessoryView), imp_implementationWithBlock(block), "@@:")
            objc_registerClassPair(created)
            subclass = created
        }
        if let subclass = subclass {
            object_setClass(content, subclass)
            content.reloadInputViews()
        }
    }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        (UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate)?.drainDashboardNotificationEvents()
        // WebView 完成載入且資料初始化後，由原生端主動要求同步，避免 JS 啟動時序漏掉。
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            webView.evaluateJavaScript("(function(){ if(typeof window.syncKeyboardQuickCopy==='function'){ var n=window.syncKeyboardQuickCopy(); console.log('[QuickCopy] native didFinish sync:', n); return n; } return -1; })()", completionHandler: { result, error in
                if let error = error { NSLog("[QuickCopy] didFinish sync JS error: %@", error.localizedDescription) }
                else { NSLog("[QuickCopy] didFinish sync requested: %@", String(describing: result)) }
            })
        }
        if let target = NotificationManager.pendingTarget {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if target == "WALLET_LAST" {
                    let js = "if(typeof window.navigateToWallet==='function'){ window.navigateToWallet(); setTimeout(function(){ var cards = (typeof visibleCards==='function')?visibleCards():state.cards; if(typeof window.goToCard==='function') window.goToCard(cards.length - 1); }, 350); }"
                    NotificationManager.evaluateJS(js)
                } else if target == "MORE_PAGE" {
                    NotificationManager.evaluateJS("if(typeof window.switchTab==='function') window.switchTab('more');")
                } else if target == "WALLET_ADDCARD" {
                    let js = "if(typeof window.navigateToWallet==='function'){ window.navigateToWallet(); setTimeout(function(){ if(typeof window.openAddModal==='function') window.openAddModal('card'); }, 300); }"
                    NotificationManager.evaluateJS(js)
                } else {
                    NotificationManager.executeTargetJump(target: target)
                }
                NotificationManager.pendingTarget = nil
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
        setupDelegatesAndHandlers()
        NotificationManager.checkAndReportStatus()
        NotificationManager.scheduleUpdateNotification(version: "v24")
    }

    private func setupDelegatesAndHandlers() {
        guard let wv = self.webView else { return }
        wv.navigationDelegate = self
        wv.uiDelegate = self
        hideKeyboardNavigationAccessory(in: wv)

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
            "syncSuperShortcutOptions",
            "saveImageToPhotos",
            "openExternalUrl",
            "superdashboard",
            "keyboardSettings"
        ]
        handlers.forEach { ucc.removeScriptMessageHandler(forName: $0) }
        handlers.forEach { ucc.add(self, name: $0) }
    }

    // 隱藏 WKWebView 輸入時系統自動加入的「上一欄／下一欄／完成」輔助按鈕。
    // 使用 UIKit 公開的 UITextInputAssistantItem，不更動鍵盤本體或文字輸入行為。
    private func hideKeyboardNavigationAccessory(in webView: WKWebView) {
        func visit(_ view: UIView) {
            if NSStringFromClass(type(of: view)).contains("WKContentView") {
                let assistant = (view as UIResponder).inputAssistantItem
                assistant.leadingBarButtonGroups = []
                assistant.trailingBarButtonGroups = []
                assistant.allowsHidingShortcuts = false
            }
            view.subviews.forEach { visit($0) }
        }
        visit(webView)
    }

    // 核心攔截：當 JavaScript 導航或請求 superdashboard:// 時轉發給 handleDeepLink；捷徑 shortcuts:// 與外部連結以系統 Safari 開啟
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            let scheme = url.scheme?.lowercased() ?? ""
            if scheme == "superdashboard" {
                decisionHandler(.cancel)
                DispatchQueue.main.async {
                    (UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate)?.handleDeepLink(url: url)
                }
                return
            }
            // 捷徑 shortcuts:// 或電話、信箱
            if scheme == "shortcuts" || scheme == "itms-apps" || scheme == "tel" || scheme == "mailto" || scheme == "sms" {
                decisionHandler(.cancel)
                DispatchQueue.main.async {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
                return
            }
            // 外部 HTTP/HTTPS 連結點擊時以系統 Safari 開啟，保證連結點擊必有反應
            if navigationAction.navigationType == .linkActivated || navigationAction.targetFrame == nil {
                if scheme == "http" || scheme == "https" {
                    if let host = url.host, host != "localhost" && host != "127.0.0.1" {
                        decisionHandler(.cancel)
                        DispatchQueue.main.async {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        }
                        return
                    }
                }
            }
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: "超級儀表板", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "確定", style: .destructive) { _ in completionHandler(true) })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: "超級儀表板", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
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
        if message.name == "keyboardSettings" {
            let groupID = "group.com.steveplayer87.superdashboard"
            let shared = UserDefaults(suiteName: groupID)
            let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
            let body = message.body as? [String: Any] ?? [:]
            let action = body["action"] as? String ?? "stats"
            if action == "setEmojiBar" {
                shared?.set(body["enabled"] as? Bool ?? true, forKey: "keyboardEmojiBarEnabled")
                shared?.synchronize()
            } else if action == "clear", let kind = body["kind"] as? String {
                if kind == "clipboard" {
                    let historyData = shared?.data(forKey: "keyboardClipboardHistory")
                    if let container, let data = historyData,
                       let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        for item in items { if let file = item["imageFile"] as? String { try? FileManager.default.removeItem(at: container.appendingPathComponent(file)) } }
                    }
                    shared?.removeObject(forKey: "keyboardClipboardHistory")
                } else if kind == "emoji" {
                    shared?.removeObject(forKey: "keyboardRecentEmojis")
                    if let container { try? FileManager.default.removeItem(at: container.appendingPathComponent("keyboardRecentEmojis.json")) }
                }
                shared?.synchronize()
                self.webView?.evaluateJavaScript("if(typeof showToast==='function')showToast('鍵盤資料已清除');", completionHandler: nil)
            } else {
                let counts = shared?.dictionary(forKey: "keyboardRecentEmojis") as? [String: Int] ?? [:]
                let enabled = shared?.object(forKey: "keyboardEmojiBarEnabled") as? Bool ?? true
                if let data = try? JSONSerialization.data(withJSONObject: counts), let json = String(data: data, encoding: .utf8) {
                    self.webView?.evaluateJavaScript("window.__keyboardEmojiCounts = \(json); var t=document.getElementById('keyboardEmojiBarToggle'); if(t)t.checked=\(enabled ? "true" : "false"); if(typeof window.refreshSuperKeyboardStats==='function')window.refreshSuperKeyboardStats();", completionHandler: nil)
                }
            }
            return
        }

        if message.name == "superdashboard" {
            if let body = message.body as? [String: Any], let action = body["action"] as? String {
                if action.lowercased() == "sync-keyboard-quick-copy" {
                    let groupID = "group.com.steveplayer87.superdashboard"
                    let shared = UserDefaults(suiteName: groupID)
                    shared?.set("收到同步訊息，正在解析資料", forKey: "keyboardQuickCopyDiagnostic")
                    shared?.set(Date().timeIntervalSince1970, forKey: "keyboardQuickCopyDiagnosticAt")
                    shared?.synchronize()
                    NSLog("[QuickCopy] message received; params type: %@", String(describing: type(of: body["params"] ?? NSNull())))
                }
                handleUnifiedAction(action: action, params: body["params"])
            } else {
                let shared = UserDefaults(suiteName: "group.com.steveplayer87.superdashboard")
                shared?.set("收到訊息但格式不符", forKey: "keyboardQuickCopyDiagnostic")
                shared?.synchronize()
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
        } else if message.name == "openExternalUrl" {
            if let body = message.body as? [String: Any], let urlStr = body["url"] as? String, let url = URL(string: urlStr) {
                DispatchQueue.main.async {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
        } else if message.name == "authenticateFaceID" {
            handleUnifiedAction(action: "auth-faceid", params: nil)
        } else if message.name == "syncDynamicShortcuts" {
            if let rawList = message.body as? [[String: Any]] {
                let items = rawList.map { dict -> QuickCopyItemData in
                    let id = cleanedString(dict["id"] as? String ?? "", max: 80, fallback: UUID().uuidString)
                    let text = cleanedString(dict["text"] as? String ?? "", max: 2000)
                    let label = cleanedString(dict["label"] as? String ?? dict["name"] as? String ?? "", max: 40, fallback: text.isEmpty ? "項目" : String(text.prefix(12)))
                    let isLink = dict["isLink"] as? Bool ?? false
                    return QuickCopyItemData(id: id, label: label, text: text, isLink: isLink)
                }
                if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
                    sceneDelegate.updateDynamicQuickActions(items: items)
                }
            }
        } else if message.name == "syncSuperShortcutOptions" {
            let selected = message.body as? String ?? "openDashboard"
            let allOptions = ["openDashboard", "openWallet", "showTransitCard", "copyTopItem", "addQuickText", "startMetroLiveActivity", "openWardrobe"]
            if let defaults = UserDefaults(suiteName: "group.com.steveplayer87.superdashboard") {
                defaults.set(selected, forKey: "superShortcutSelectedOption")
                allOptions.forEach { key in
                    defaults.set(key == selected, forKey: "superShortcutEnabled_\(key)")
                }
                defaults.synchronize()
            }
        } else if message.name == "saveImageToPhotos" {
            if let base64Str = message.body as? String {
                saveBase64ToPhotos(base64Str)
            }
        }
    }

    private func handleUnifiedAction(action: String, params: Any?) {
        let act = action.lowercased()
        if act == "open-wardrobe" || act == "openwardrobe" {
            DispatchQueue.main.async { [weak self] in
                self?.presentWardrobeMiniApp()
            }
            return
        }
        if act == "present-photo-picker" || act == "request-photo-library-access" || act == "request-photo-library-assets" {
            presentSystemPhotoPicker()
            return
        }
        if act == "present-native-camera" {
            presentNativePhotoVaultCamera()
            return
        }
        if act == "set-shake-return" {
            let enabled = (params as? [String: Any])?["enabled"] as? Bool ?? false
            UserDefaults.standard.set(enabled, forKey: "shakeReturnsToMore")
            return
        }
        if act == "get-install-expiry-deadline" {
            UNUserNotificationCenter.current().getPendingNotificationRequests { [weak self] requests in
                let stored = UserDefaults.standard.double(forKey: "superdashboard.install-expiry-deadline")
                let hasPending = requests.contains(where: { $0.identifier == "superdashboard.install-expiry-6-5-days" })
                let deadline = stored > 0 ? stored : (hasPending ? 0 : 0)
                DispatchQueue.main.async {
                    self?.webView?.evaluateJavaScript("if(typeof window.onInstallExpiryDeadline==='function')window.onInstallExpiryDeadline(\(deadline), \(hasPending));", completionHandler: nil)
                }
            }
            return
        }
        if act == "store-file-provider-photo", let dict = params as? [String: Any],
           let dataURL = dict["dataUrl"] as? String, let filename = dict["filename"] as? String {
            let payload = dataURL.components(separatedBy: ",").last ?? dataURL
            let domain = NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier("superdashboard.photos"), displayName: "超級儀表板", pathRelativeToDocumentStorage: "SuperDashboardFiles")
            if let data = Data(base64Encoded: payload),
               let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SceneDelegate.sharedGroupID) {
                let folder = container.appendingPathComponent("SuperDashboardFiles", isDirectory: true)
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let manager = NSFileProviderManager(for: domain)
                let safeName = URL(fileURLWithPath: filename).lastPathComponent
                do {
                    try data.write(to: folder.appendingPathComponent(safeName), options: .atomic)
                    manager?.signalEnumerator(for: .rootContainer) { error in
                        if let error { NSLog("[FileProvider] refresh after write: %@", error.localizedDescription) }
                    }
                } catch { NSLog("[FileProvider] write failed: %@", error.localizedDescription) }
            }
            return
        }
        if act == "copy-to-clipboard" {
            let dict = params as? [String: Any]
            let text = dict?["text"] as? String ?? ""
            guard !text.isEmpty else { return }
            DispatchQueue.main.async {
                UIPasteboard.general.string = text
                self.webView?.evaluateJavaScript("if(typeof showToast==='function') showToast('已複製到系統剪貼簿');", completionHandler: nil)
            }
            return
        }
        if act == "auth-faceid" || act == "authfaceid" {
            BiometricManager.authenticate(reason: "驗證身分以使用卡片") { [weak self] success, err in
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

        if act == "sync-keyboard-quick-copy", let dict = params as? [String: Any], let raw = dict["items"] as? [[String: Any]] {
            let keyboardItems: [[String: String]] = raw.compactMap { item in
                guard let text = item["text"] as? String, !text.isEmpty else { return nil }
                return ["id": item["id"] as? String ?? UUID().uuidString,
                        "label": item["label"] as? String ?? item["name"] as? String ?? String(text.prefix(24)),
                        "text": text,
                        "category": item["category"] as? String ?? "未分類",
                        "type": item["type"] as? String ?? (text.hasPrefix("data:image") ? "image" : "text")]
            }
            let groupID = "group.com.steveplayer87.superdashboard"
            let shared = UserDefaults(suiteName: groupID)
            let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
            shared?.set("原生端已收到並完成解析：\(keyboardItems.count) 筆", forKey: "keyboardQuickCopyDiagnostic")
            shared?.set(Date().timeIntervalSince1970, forKey: "keyboardQuickCopyDiagnosticAt")
            if let data = try? JSONSerialization.data(withJSONObject: keyboardItems) {
                shared?.set(data, forKey: "keyboardQuickCopyItems")
                shared?.set(keyboardItems.count, forKey: "keyboardQuickCopyCount")
                shared?.set(Date().timeIntervalSince1970, forKey: "keyboardQuickCopyUpdatedAt")
                shared?.synchronize()
                if let container = container {
                    try? data.write(to: container.appendingPathComponent("keyboardQuick_copy.json"), options: .atomic)
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
                    let id = cleanedString(dict["id"] as? String ?? "", max: 80, fallback: UUID().uuidString)
                    let text = cleanedString(dict["text"] as? String ?? "", max: 2000)
                    let label = cleanedString(dict["label"] as? String ?? dict["name"] as? String ?? "", max: 40, fallback: text.isEmpty ? "項目" : String(text.prefix(12)))
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

        if act == "schedule-interactive-notification", let payload = params as? [String: Any] {
            NotificationManager.scheduleInteractive(payload)
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

        if act == "set-app-icon" || act == "setappicon" {
            let name = (params as? [String: Any])?["name"] as? String
            AppIconManager.apply(name: name) { success, message in
                AppIconManager.report(success: success, message: message)
            }
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


    private func presentNativePhotoVaultCamera() {
        guard presentedViewController == nil else { return }
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SceneDelegate.sharedGroupID) else {
            webView?.evaluateJavaScript("if(typeof showToast==='function')showToast('無法開啟相片庫儲存空間');", completionHandler: nil)
            return
        }
        let folder = container.appendingPathComponent("SuperDashboardFiles", isDirectory: true)
        do { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
        catch {
            webView?.evaluateJavaScript("if(typeof showToast==='function')showToast('無法建立相片儲存資料夾');", completionHandler: nil)
            return
        }
        let camera = DashboardCameraViewController(destinationFolder: folder, onOpenGallery: { [weak self] in
            self?.webView?.evaluateJavaScript("if(window.PhotoVault&&window.PhotoVault.openLatestCapture)window.PhotoVault.openLatestCapture();")
        }) { [weak self] record in
            guard let self, let record,
                  let data = try? JSONSerialization.data(withJSONObject: ["items": [record]]),
                  let json = String(data: data, encoding: .utf8) else { return }
            let domain = NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier("superdashboard.photos"), displayName: "超級儀表板", pathRelativeToDocumentStorage: "SuperDashboardFiles")
            NSFileProviderManager(for: domain)?.signalEnumerator(for: .rootContainer) { error in
                if let error { NSLog("[FileProvider] camera capture refresh: %@", error.localizedDescription) }
            }
            self.webView?.evaluateJavaScript("if(typeof window.onNativePhotoAssets==='function')window.onNativePhotoAssets(\(json),false,0,true);")
        }
        camera.modalPresentationStyle = .fullScreen
        present(camera, animated: true)
    }

    // 使用 Apple 原生 PHPicker；先取得可選的 Photos 讀取授權，才能用 assetIdentifier 還原 Live Photo 配對資源。
    private func presentSystemPhotoPicker() {
        guard presentedViewController == nil else { return }
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] _ in
                DispatchQueue.main.async { self?.presentSystemPhotoPickerController() }
            }
            return
        }
        presentSystemPhotoPickerController()
    }

    private func presentSystemPhotoPickerController() {
        guard presentedViewController == nil else { return }
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .any(of: [.images, .videos, .livePhotos])
        config.selectionLimit = 0
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard !results.isEmpty else { return }
        let group = DispatchGroup()
        let lock = NSLock()
        var records = [[String: Any]]()
        let domain = NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier("superdashboard.photos"), displayName: "超級儀表板", pathRelativeToDocumentStorage: "SuperDashboardFiles")
        let manager = NSFileProviderManager(for: domain)
        let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SceneDelegate.sharedGroupID)?.appendingPathComponent("SuperDashboardFiles", isDirectory: true)
        if let folder { try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }

        for (index, result) in results.enumerated() {
            let provider = result.itemProvider
            let id = "picker-\(UUID().uuidString)"
            // Live Photo 必須由 assetIdentifier 找回 PHAsset，才能取得原始照片與配對 MOV。
            let photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            let selectedAsset: PHAsset? = {
                guard (photoStatus == .authorized || photoStatus == .limited), let assetID = result.assetIdentifier else { return nil }
                return PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject
            }()
            NSLog("[PhotoVaultImport] selection=%d assetID=%@ status=%@ types=%@ resolved=%@ live=%@", index, result.assetIdentifier ?? "nil", String(describing: photoStatus), provider.registeredTypeIdentifiers.joined(separator: ","), selectedAsset == nil ? "false" : "true", selectedAsset?.mediaSubtypes.contains(.photoLive) == true ? "true" : "false")
            if let asset = selectedAsset, asset.mediaSubtypes.contains(.photoLive), let folder {
                group.enter()
                let imageOptions = PHImageRequestOptions()
                imageOptions.version = .original
                imageOptions.deliveryMode = .highQualityFormat
                imageOptions.isNetworkAccessAllowed = true
                PHImageManager.default().requestImageDataAndOrientation(for: asset, options: imageOptions) { data, _, _, _ in
                    guard let data else { group.leave(); return }
                    let originalName = PHAssetResource.assetResources(for: asset).first(where: { $0.type == .photo })?.originalFilename ?? "LivePhoto.heic"
                    let ext = URL(fileURLWithPath: originalName).pathExtension.isEmpty ? "heic" : URL(fileURLWithPath: originalName).pathExtension
                    let name = "Live-\(index + 1)-\(UUID().uuidString.prefix(8)).\(ext)"
                    let destination = folder.appendingPathComponent(name)
                    do { try data.write(to: destination, options: .atomic) }
                    catch { group.leave(); return }
                    let thumbOptions = PHImageRequestOptions()
                    thumbOptions.deliveryMode = .fastFormat
                    thumbOptions.resizeMode = .fast
                    thumbOptions.isNetworkAccessAllowed = true
                    PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 720, height: 720), contentMode: .aspectFit, options: thumbOptions) { image, _ in
                        let thumb = image?.jpegData(compressionQuality: 0.72) ?? data
                        let resources = PHAssetResource.assetResources(for: asset)
                        guard let pairedVideo = resources.first(where: { $0.type == .pairedVideo }) else {
                            NSLog("[PhotoVaultImport] Live Photo has no pairedVideo resource: %@", asset.localIdentifier)
                            group.leave(); return
                        }
                        let movieName = name.replacingOccurrences(of: ".\(ext)", with: "-paired.mov")
                        let movieURL = folder.appendingPathComponent(movieName)
                        let resourceOptions = PHAssetResourceRequestOptions()
                        resourceOptions.isNetworkAccessAllowed = true
                        PHAssetResourceManager.default().writeData(for: pairedVideo, toFile: movieURL, options: resourceOptions) { resourceError in
                            guard resourceError == nil, let movieData = try? Data(contentsOf: movieURL) else {
                                NSLog("[PhotoVaultImport] pairedVideo write failed: %@", resourceError?.localizedDescription ?? "unknown")
                                group.leave(); return
                            }
                            let record: [String: Any] = [
                                "id": id, "filename": name, "mediaType": "image", "isLive": true,
                                "dataUrl": "data:image/jpeg;base64,\((UIImage(data:data)?.jpegData(compressionQuality:0.92) ?? data).base64EncodedString())", "thumbnailUrl": "data:image/jpeg;base64,\(thumb.base64EncodedString())",
                                "liveVideoUrl": "data:video/quicktime;base64,\(movieData.base64EncodedString())",
                                "liveVideoFilename": movieName, "size": data.count,
                                "width": asset.pixelWidth, "height": asset.pixelHeight,
                                "createdAt": (asset.creationDate ?? Date()).timeIntervalSince1970 * 1000, "location": asset.location.map { String(format: "%.5f, %.5f", $0.coordinate.latitude, $0.coordinate.longitude) } ?? "", "album": "全部相片"
                            ]
                            lock.lock(); records.append(record); lock.unlock()
                            group.leave()
                        }
                    }
                }
            } else if let imageType = provider.registeredTypeIdentifiers.first(where: { UTType($0)?.conforms(to: .image) == true }) {
                // 不把原始高解析度 UIImage 載入記憶體；直接處理暫存檔，縮圖限制 720px。
                group.enter()
                provider.loadFileRepresentation(forTypeIdentifier: imageType) { url, _ in
                    defer { group.leave() }
                    guard let url, let folder else { return }
                    let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
                    let name = "Photo-\(index + 1)-\(UUID().uuidString.prefix(8)).\(ext)"
                    let destination = folder.appendingPathComponent(name)
                    do { try FileManager.default.copyItem(at: url, to: destination) } catch { return }
                    guard let source = CGImageSourceCreateWithURL(destination as CFURL, nil),
                          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                          let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                            kCGImageSourceCreateThumbnailFromImageAlways: true,
                            kCGImageSourceThumbnailMaxPixelSize: 720,
                            kCGImageSourceCreateThumbnailWithTransform: true
                          ] as CFDictionary) else { return }
                    let thumb = UIImage(cgImage: thumbnail).jpegData(compressionQuality: 0.72) ?? Data()
                    guard !thumb.isEmpty else { return }
                    let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? thumbnail.width
                    let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? thumbnail.height
                    let fileSize = (try? FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? NSNumber)?.intValue ?? 0
                    let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any]
                    let gpsLat = (gps?[kCGImagePropertyGPSLatitude] as? NSNumber)?.doubleValue
                    let gpsLon = (gps?[kCGImagePropertyGPSLongitude] as? NSNumber)?.doubleValue
                    let gpsLatRef = gps?[kCGImagePropertyGPSLatitudeRef] as? String
                    let gpsLonRef = gps?[kCGImagePropertyGPSLongitudeRef] as? String
                    let exifLocation = (gpsLat != nil && gpsLon != nil) ? String(format: "%.5f, %.5f", gpsLat! * (gpsLatRef == "S" ? -1 : 1), gpsLon! * (gpsLonRef == "W" ? -1 : 1)) : ""
                    let location = selectedAsset?.location.map { String(format: "%.5f, %.5f", $0.coordinate.latitude, $0.coordinate.longitude) } ?? exifLocation
                    let fullImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
                    let fullJPEG = fullImage.flatMap { UIImage(cgImage: $0).jpegData(compressionQuality: 0.92) } ?? thumb
                    let record: [String: Any] = ["id": id, "filename": name, "mediaType": "image", "isLive": false, "dataUrl": "data:image/jpeg;base64,\(fullJPEG.base64EncodedString())", "thumbnailUrl": "data:image/jpeg;base64,\(thumb.base64EncodedString())", "size": fileSize, "width": width, "height": height, "createdAt": (selectedAsset?.creationDate ?? Date()).timeIntervalSince1970 * 1000, "location": location, "album": "全部相片"]
                    lock.lock(); records.append(record); lock.unlock()
                }
            } else if let type = provider.registeredTypeIdentifiers.first(where: { UTType($0)?.conforms(to: .movie) == true }) {
                group.enter()
                provider.loadFileRepresentation(forTypeIdentifier: type) { url, _ in
                    defer { group.leave() }
                    guard let url else { return }
                    let name = "Video-\(index + 1)-\(UUID().uuidString.prefix(8)).mov"
                    var preview = Data()
                    let destination = folder?.appendingPathComponent(name)
                    if let destination { try? FileManager.default.copyItem(at: url, to: destination) }
                    let asset = AVURLAsset(url: url)
                    let seconds=CMTimeGetSeconds(asset.duration)
                    let durationText=seconds.isFinite ? String(format:"%02d:%02d",Int(seconds)/60,Int(seconds)%60) : ""
                    let isoLocation=asset.metadata.compactMap{$0.stringValue}.first(where:{$0.range(of:"[+-]\\d{2,3}\\.\\d+[+-]\\d{2,3}\\.\\d+",options:.regularExpression) != nil})
                    var quickTimeLocation=""
                    if let isoLocation, let regex=try? NSRegularExpression(pattern:"([+-]\\d{2,3}\\.\\d+)([+-]\\d{2,3}\\.\\d+)"), let match=regex.firstMatch(in:isoLocation,range:NSRange(isoLocation.startIndex...,in:isoLocation)), let latRange=Range(match.range(at:1),in:isoLocation), let lonRange=Range(match.range(at:2),in:isoLocation), let lat=Double(isoLocation[latRange]), let lon=Double(isoLocation[lonRange]) { quickTimeLocation=String(format:"%.5f, %.5f",lat,lon) }
                    let importLocation=selectedAsset?.location.map{String(format:"%.5f, %.5f",$0.coordinate.latitude,$0.coordinate.longitude)} ?? quickTimeLocation
                    let generator = AVAssetImageGenerator(asset: asset); generator.appliesPreferredTrackTransform = true
                    if let cg = try? generator.copyCGImage(at: .zero, actualTime: nil) { preview = UIImage(cgImage: cg).jpegData(compressionQuality: 0.72) ?? Data() }
                    let movieData = destination.flatMap { try? Data(contentsOf: $0) } ?? Data()
                    let record: [String: Any] = ["id": id, "filename": name, "mediaType": "video", "isLive": false, "dataUrl": "data:image/jpeg;base64,\(preview.base64EncodedString())", "videoUrl": "data:video/quicktime;base64,\(movieData.base64EncodedString())", "duration": durationText, "size": (try? FileManager.default.attributesOfItem(atPath: destination?.path ?? "")[.size] as? NSNumber)?.intValue ?? 0, "createdAt": (selectedAsset?.creationDate ?? Date()).timeIntervalSince1970 * 1000, "location": importLocation, "album": "全部相片"]
                    lock.lock(); records.append(record); lock.unlock()
                }
            }
        }
        group.notify(queue: .main) { [weak self] in
            if let manager { manager.signalEnumerator(for: .rootContainer) { _ in } }
            // 分批送入 WebView，避免一次建立超大的 JSON/Base64 字串造成記憶體尖峰。
            let chunks = stride(from: 0, to: records.count, by: 3).map { start in
                Array(records[start..<min(start + 3, records.count)])
            }
            guard !chunks.isEmpty else {
                NSLog("[PhotoVaultImport] picker returned %d selections but produced zero importable records", results.count)
                self?.webView?.evaluateJavaScript("if(typeof window.onNativePhotoAssets==='function')window.onNativePhotoAssets({items:[],error:'no_importable_assets',selectedCount:\(results.count)},false,0,true);", completionHandler: nil)
                return
            }
            func deliver(_ index: Int) {
                guard index < chunks.count else { return }
                guard let data = try? JSONSerialization.data(withJSONObject: ["items": chunks[index]]),
                      let json = String(data: data, encoding: .utf8) else { return }
                self?.webView?.evaluateJavaScript("if(typeof window.onNativePhotoAssets==='function')window.onNativePhotoAssets(\(json),false,0,\(index == chunks.count - 1));") { _, _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { deliver(index + 1) }
                }
            }
            deliver(0)
        }
    }

    /// 從 Photos 讀取圖庫：原始檔直接寫入 File Provider 儲存區，僅將縮圖送到 WebView，避免大量 Base64 導致記憶體暴增。
    private func importPhotoLibraryAssets(params: Any?) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            webView?.evaluateJavaScript("if(typeof window.onNativePhotoAssets==='function')window.onNativePhotoAssets({error:'photo_permission_required'});", completionHandler: nil)
            return
        }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let assets = PHAsset.fetchAssets(with: options)
        let dict = params as? [String: Any] ?? [:]
        let offset = max(0, dict["offset"] as? Int ?? 0)
        let batch = min(1, max(0, assets.count - offset))
        guard batch > 0 else {
            webView?.evaluateJavaScript("if(typeof window.onNativePhotoAssets==='function')window.onNativePhotoAssets({items:[]},false,\(offset));", completionHandler: nil)
            return
        }
        let domain = NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier("superdashboard.photos"), displayName: "超級儀表板", pathRelativeToDocumentStorage: "SuperDashboardFiles")
        guard let manager = NSFileProviderManager(for: domain),
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SceneDelegate.sharedGroupID) else {
            webView?.evaluateJavaScript("if(typeof window.onNativePhotoAssets==='function')window.onNativePhotoAssets({error:'file_provider_unavailable'});", completionHandler: nil)
            return
        }
        let folder = container.appendingPathComponent("SuperDashboardFiles", isDirectory: true)
        do { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
        catch {
            webView?.evaluateJavaScript("if(typeof window.onNativePhotoAssets==='function')window.onNativePhotoAssets({error:'file_storage_unavailable'});", completionHandler: nil)
            return
        }
        let asset = assets.object(at: offset)
        let isLive = asset.mediaSubtypes.contains(.photoLive)
        let safeID = asset.localIdentifier.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
        let fileExt = asset.mediaType == .video ? "mov" : "jpg"
        let filename = "\(safeID).\(fileExt)"
        let destination = folder.appendingPathComponent(filename)
        let finish: ([String: Any]?, String?) -> Void = { [weak self] record, errorText in
            DispatchQueue.main.async {
                guard let self else { return }
                if let errorText {
                    let escaped = errorText.replacingOccurrences(of: "'", with: "\\'")
                    self.webView?.evaluateJavaScript("if(typeof window.onNativePhotoAssets==='function')window.onNativePhotoAssets({error:'\(escaped)'});", completionHandler: nil)
                    return
                }
                manager.signalEnumerator(for: .rootContainer) { error in
                    if let error { NSLog("[FileProvider] refresh after Photos import: %@", error.localizedDescription) }
                }
                let items = record.map { [$0] } ?? []
                guard let jsonData = try? JSONSerialization.data(withJSONObject: ["items": items]), let json = String(data: jsonData, encoding: .utf8) else { return }
                let hasMore = offset + 1 < assets.count
                self.webView?.evaluateJavaScript("if(typeof window.onNativePhotoAssets==='function')window.onNativePhotoAssets(\(json),\(hasMore),\(offset + 1));", completionHandler: nil)
            }
        }
        if asset.mediaType == .image {
            let request = PHImageRequestOptions()
            request.version = .original
            request.deliveryMode = .highQualityFormat
            request.isNetworkAccessAllowed = true
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: request) { data, _, _, info in
                guard let data else { finish(nil, "無法讀取相片原始檔"); return }
                do { try data.write(to: destination, options: .atomic) }
                catch { finish(nil, "無法儲存相片：\(error.localizedDescription)"); return }
                let thumbOptions = PHImageRequestOptions()
                thumbOptions.deliveryMode = .fastFormat
                thumbOptions.resizeMode = .fast
                thumbOptions.isNetworkAccessAllowed = true
                PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 720, height: 720), contentMode: .aspectFit, options: thumbOptions) { image, _ in
                    let thumb = image?.jpegData(compressionQuality: 0.72) ?? data
                    var liveMovieName = ""
                    var liveMovieDataURL = ""
                    let deliver: () -> Void = {
                        // 檢視器資料必須是完整原圖；720px thumb 僅供相簿列表使用。
                        let fullImageData = UIImage(data: data)?.jpegData(compressionQuality: 0.94) ?? data
                        let record: [String: Any] = [
                            "id": "phasset-\(asset.localIdentifier)", "filename": filename,
                            "mediaType": "image", "isLive": isLive, "dataUrl": "data:image/jpeg;base64,\(fullImageData.base64EncodedString())", "thumbnailUrl": "data:image/jpeg;base64,\(thumb.base64EncodedString())",
                            "liveVideoUrl": liveMovieDataURL, "liveVideoFilename": liveMovieName,
                            "createdAt": (asset.creationDate ?? Date()).timeIntervalSince1970 * 1000,
                            "width": asset.pixelWidth, "height": asset.pixelHeight, "size": data.count, "location": asset.location.map { String(format: "%.5f, %.5f", $0.coordinate.latitude, $0.coordinate.longitude) } ?? "", "album": "全部相片"
                        ]
                        finish(record, nil)
                    }
                    guard isLive else { deliver(); return }
                    let videoOptions = PHVideoRequestOptions()
                    videoOptions.version = .original
                    videoOptions.deliveryMode = .highQualityFormat
                    videoOptions.isNetworkAccessAllowed = true
                    PHImageManager.default().requestAVAsset(forVideo: asset, options: videoOptions) { avAsset, _, _ in
                        guard let avAsset, let export = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetPassthrough) else { deliver(); return }
                        liveMovieName = "\(safeID)-paired.mov"
                        let movieURL = folder.appendingPathComponent(liveMovieName)
                        export.outputURL = movieURL
                        export.outputFileType = .mov
                        export.exportAsynchronously {
                            if export.status == .completed, let movieData = try? Data(contentsOf: movieURL) {
                                liveMovieDataURL = "data:video/quicktime;base64,\(movieData.base64EncodedString())"
                            } else { liveMovieName = "" }
                            deliver()
                        }
                    }
                }
            }
        } else if asset.mediaType == .video {
            let videoOptions = PHVideoRequestOptions()
            videoOptions.version = .original
            videoOptions.deliveryMode = .highQualityFormat
            videoOptions.isNetworkAccessAllowed = true
            PHImageManager.default().requestAVAsset(forVideo: asset, options: videoOptions) { avAsset, _, _ in
                guard let avAsset, let export = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetPassthrough) else { finish(nil, "無法讀取影片原始檔"); return }
                export.outputURL = destination
                export.outputFileType = .mov
                export.exportAsynchronously {
                    guard export.status == .completed else { finish(nil, "影片匯出失敗"); return }
                    let thumbOptions = PHImageRequestOptions()
                    thumbOptions.deliveryMode = .fastFormat
                    thumbOptions.isNetworkAccessAllowed = true
                    PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 720, height: 720), contentMode: .aspectFit, options: thumbOptions) { image, _ in
                        let thumb = image?.jpegData(compressionQuality: 0.72) ?? Data()
                        let record: [String: Any] = [
                            "id": "phasset-\(asset.localIdentifier)", "filename": filename,
                            "mediaType": "video", "isLive": false, "dataUrl": "data:image/jpeg;base64,\(thumb.base64EncodedString())",
                            "videoUrl": "data:video/quicktime;base64,\((try? Data(contentsOf: destination))?.base64EncodedString() ?? "")", "liveVideoUrl": "", "createdAt": (asset.creationDate ?? Date()).timeIntervalSince1970 * 1000,
                            "width": asset.pixelWidth, "height": asset.pixelHeight, "size": (try? FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? NSNumber)?.intValue ?? 0, "location": asset.location.map { String(format: "%.5f, %.5f", $0.coordinate.latitude, $0.coordinate.longitude) } ?? "", "album": "全部相片"
                        ]
                        finish(record, nil)
                    }
                }
            }
        } else { finish(nil, "不支援的媒體格式") }
    }

    func presentWardrobeMiniApp() {
        guard presentedViewController == nil else { return }
        let miniApp = WardrobeMiniAppViewController()
        miniApp.modalPresentationStyle = .fullScreen
        present(miniApp, animated: true)
    }
}

/// Wardrobe Master Mini App：使用持久化 WKWebsiteDataStore，讓 localStorage、IndexedDB、Cookie
/// 與網站快取在 App 關閉後仍可保留。這是獨立 WebKit 儲存環境，不會自動與 Safari PWA 共用。
final class WardrobeMiniAppViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, UIGestureRecognizerDelegate {
    override var canBecomeFirstResponder: Bool { true }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake, UserDefaults.standard.bool(forKey: "shakeReturnsToMore") else { return }
        dismiss(animated: true) { [weak self] in
            guard let self else { return }
            for scene in UIApplication.shared.connectedScenes {
                guard let ws = scene as? UIWindowScene else { continue }
                for window in ws.windows {
                    if let main = window.rootViewController as? MainViewController {
                        main.webView?.evaluateJavaScript("if(typeof window.switchPage==='function')window.switchPage('more');", completionHandler: nil)
                    }
                }
            }
        }
    }
    private let wardrobeURL = URL(string: "https://steveplayer87.github.io/wardrobe-master/")!
    private var webView: WKWebView!
    private let loading = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true

        let web = WKWebView(frame: .zero, configuration: configuration)
        web.translatesAutoresizingMaskIntoConstraints = false
        web.navigationDelegate = self
        web.uiDelegate = self
        web.allowsBackForwardNavigationGestures = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.backgroundColor = .systemBackground
        web.isOpaque = false
        webView = web
        view.addSubview(web)

        loading.translatesAutoresizingMaskIntoConstraints = false
        loading.hidesWhenStopped = true
        view.addSubview(loading)

        NSLayoutConstraint.activate([
            web.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            web.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            web.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            web.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            loading.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loading.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        // 只在螢幕最左側起手的原生邊緣手勢；往右滑即可退出 Mini App。
        let edgeBack = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgeBack(_:)))
        edgeBack.edges = .left
        edgeBack.delegate = self
        edgeBack.cancelsTouchesInView = false
        view.addGestureRecognizer(edgeBack)

        loading.startAnimating()
        web.load(URLRequest(url: wardrobeURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30))
    }

    @objc private func handleEdgeBack(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard gesture.state == .ended else { return }
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        if translation.x > 70 || velocity.x > 650 {
            dismiss(animated: true)
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        loading.startAnimating()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loading.stopAnimating()
        print("[MiniApp:Wardrobe] loaded \(webView.url?.absoluteString ?? "unknown URL")")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loading.stopAnimating()
        print("[MiniApp:Wardrobe] navigation failed: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loading.stopAnimating()
        print("[MiniApp:Wardrobe] initial load failed: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
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
        registerInboxObservers()

        SceneDelegateProxy.shared.scene(scene, willConnectTo: session, options: connectionOptions)

        // 處理冷啟動時的 Quick Action
        if let shortcutItem = connectionOptions.shortcutItem {
            handleShortcutItem(shortcutItem)
        }
        
        // 處理命令列測試參數
        if ProcessInfo.processInfo.arguments.contains("--metro") {
            NotificationManager.executeTargetJump(target: "台北捷運")
        } else if ProcessInfo.processInfo.arguments.contains("--lastcard") {
            NotificationManager.pendingTarget = "WALLET_LAST"
            let js = "if(typeof window.navigateToWallet==='function'){ window.navigateToWallet(); setTimeout(function(){ var cards = (typeof visibleCards==='function')?visibleCards():state.cards; if(typeof window.goToCard==='function') window.goToCard(cards.length - 1); }, 350); }"
            NotificationManager.evaluateJS(js)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { NotificationManager.evaluateJS(js) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { NotificationManager.evaluateJS(js) }
        } else if ProcessInfo.processInfo.arguments.contains("--more") {
            NotificationManager.pendingTarget = "MORE_PAGE"
            let js = "if(typeof window.switchTab==='function'){ window.switchTab('more'); }"
            NotificationManager.evaluateJS(js)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { NotificationManager.evaluateJS(js) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { NotificationManager.evaluateJS(js) }
        } else if ProcessInfo.processInfo.arguments.contains("--easycard") {
            NotificationManager.executeTargetJump(target: "悠遊卡")
        } else if ProcessInfo.processInfo.arguments.contains("--wallet") {
            NotificationManager.executeTargetJump(target: "WALLET_HOME")
        } else if ProcessInfo.processInfo.arguments.contains("--addcard") {
            NotificationManager.pendingTarget = "WALLET_ADDCARD"
            let js = "if(typeof window.navigateToWallet==='function'){ window.navigateToWallet(); setTimeout(function(){ if(typeof window.openAddModal==='function') window.openAddModal('card'); }, 350); }"
            NotificationManager.evaluateJS(js)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { NotificationManager.evaluateJS(js) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { NotificationManager.evaluateJS(js) }
        }

        // 處理冷啟動時的 URL Scheme
        if let url = connectionOptions.urlContexts.first?.url {
            handleDeepLink(url: url)
        }

        // 處理冷啟動時的通知回應（快速出示悠遊卡 / 開啟超級錢包）
        if let response = connectionOptions.notificationResponse {
            let actionId = response.actionIdentifier
            print("[Notification] Cold launch notificationResponse action: \(actionId)")
            if actionId == "ACTION_OPEN_CARD" {
                NotificationManager.executeTargetJump(target: "悠遊卡")
            } else if actionId == "ACTION_OPEN_WALLET" {
                NotificationManager.executeTargetJump(target: "WALLET_HOME")
            } else if let urlStr = response.notification.request.content.userInfo["url"] as? String, let url = URL(string: urlStr) {
                handleDeepLink(url: url)
            } else {
                NotificationManager.executeTargetJump(target: "悠遊卡")
            }
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

    func sceneDidBecomeActive(_ scene: UIScene) {
        registerDashboardFileProvider()
        drainSharedInbox()
        drainDashboardNotificationEvents()
    }

    private func registerDashboardFileProvider() {
        let domain = NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier("superdashboard.photos"), displayName: "超級儀表板", pathRelativeToDocumentStorage: "SuperDashboardFiles")
        NSFileProviderManager.add(domain) { error in
            if let error = error { NSLog("[FileProvider] domain registration: %@", error.localizedDescription) }
            else {
                NSLog("[FileProvider] domain registered")
                if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SceneDelegate.sharedGroupID) {
                    let folder = container.appendingPathComponent("SuperDashboardFiles", isDirectory: true)
                    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                }
            }
        }
    }

    fileprivate func drainDashboardNotificationEvents() {
        guard let defaults = UserDefaults(suiteName: SceneDelegate.sharedGroupID),
              let events = defaults.array(forKey: "dashboardNotificationEvents") as? [[String: Any]], !events.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: events) else { return }
        let encoded = data.base64EncodedString()
        guard let web = currentMainWebView() else { return }
        web.evaluateJavaScript("if(typeof window.onDashboardNotificationEvents==='function'){window.onDashboardNotificationEvents(JSON.parse(decodeURIComponent(escape(atob('\(encoded)')))));true}else{false}") { result, error in
            if error == nil, (result as? Bool) == true { defaults.removeObject(forKey: "dashboardNotificationEvents") }
        }
    }

    // 收件匣有新內容時（捷徑動作 / 分享延伸寫入後）立即取件
    private var inboxObserversRegistered = false
    private func registerInboxObservers() {
        guard !inboxObserversRegistered else { return }
        inboxObserversRegistered = true
        NotificationCenter.default.addObserver(forName: .quickCopyInboxUpdated, object: nil, queue: .main) { [weak self] _ in
            self?.drainSharedInbox()
        }
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        Unmanaged.passUnretained(self).toOpaque(),
                                        { _, observer, _, _, _ in
                                            guard let observer = observer else { return }
                                            let me = Unmanaged<SceneDelegate>.fromOpaque(observer).takeUnretainedValue()
                                            DispatchQueue.main.async { me.drainSharedInbox() }
                                        },
                                        QuickCopyInbox.darwinName as CFString, nil, .deliverImmediately)
    }

    deinit {
        CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(), Unmanaged.passUnretained(self).toOpaque())
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - App Group 收件匣（Share Extension 寫入，主 App 取出）
    static let sharedGroupID = "group.com.steveplayer87.superdashboard"
    private static let sharedInboxKey = "sharedInbox"
    private static let sharedInboxFolder = "SharedInbox"

    private func currentMainWebView() -> WKWebView? {
        for scene in UIApplication.shared.connectedScenes {
            guard let winScene = scene as? UIWindowScene else { continue }
            for win in winScene.windows {
                if let vc = win.rootViewController as? MainViewController {
                    return vc.webView
                }
            }
        }
        return nil
    }

    /// 取出分享收件匣並交給網頁。網頁尚未載入完成時會每 0.5 秒重試（最多約 10 秒），
    /// 且只有在確定投遞時才清空收件匣，避免冷啟動時內容遺失。
    // 同時多個觸發（回到前景 + 寫入通知）時只跑一輪，避免同一筆被投遞兩次
    private var draining = false
    private var drainAgain = false

    private func finishDrain() {
        draining = false
        if drainAgain { drainAgain = false; drainSharedInbox() }
    }

    func drainSharedInbox(attempt: Int = 0) {
        if attempt == 0 {
            if draining { drainAgain = true; return }
            draining = true
        }
        guard let defaults = UserDefaults(suiteName: SceneDelegate.sharedGroupID),
              let pending = defaults.array(forKey: SceneDelegate.sharedInboxKey) as? [[String: String]],
              !pending.isEmpty else { finishDrain(); return }

        func retry() {
            guard attempt < 20 else { QuickCopyInbox.logDrain("等待逾時：網頁端尚未就緒（已放棄本輪，下次開啟會再試）"); finishDrain(); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.drainSharedInbox(attempt: attempt + 1)
            }
        }

        guard let web = currentMainWebView() else { retry(); return }

        let probe = "typeof window.handleSharedPasteboard==='function' && typeof window.handleSharedPasteboardJson==='function'"
        web.evaluateJavaScript(probe) { [weak self] ready, _ in
            guard let self = self else { return }
            guard (ready as? Bool) == true else { retry(); return }

            // 重新讀取一次再清空，避免多次觸發造成重複投遞
            guard let d = UserDefaults(suiteName: SceneDelegate.sharedGroupID),
                  let entries = d.array(forKey: SceneDelegate.sharedInboxKey) as? [[String: String]],
                  !entries.isEmpty else { self.finishDrain(); return }
            // 收到網頁端明確回報「已寫入」後才清空收件匣；失敗時保留並重試。
            self.deliverSharedEntries(entries, web: web) { success in
                guard success else {
                    print("[ShareInbox] web handler did not confirm persistence; inbox retained")
                    QuickCopyInbox.logDrain("網頁端未確認寫入，已保留收件匣並重試")
                    retry()
                    return
                }
                if let latest = UserDefaults(suiteName: SceneDelegate.sharedGroupID),
                   let current = latest.array(forKey: SceneDelegate.sharedInboxKey) as? [[String: String]] {
                    // 僅移除本次已處理的項目，保留分享期間新加入的內容。
                    let remaining = Array(current.dropFirst(min(entries.count, current.count)))
                    if remaining.isEmpty { latest.removeObject(forKey: SceneDelegate.sharedInboxKey) }
                    else { latest.set(remaining, forKey: SceneDelegate.sharedInboxKey) }
                }
                print("[ShareInbox] confirmed persisted \(entries.count) entries")
                QuickCopyInbox.logDrain("成功：已把 \(entries.count) 筆存進常用項目")
                // 回報確認：讓捷徑動作知道已真正存進常用項目
                if let ackDefaults = UserDefaults(suiteName: SceneDelegate.sharedGroupID) {
                    var acked = (ackDefaults.array(forKey: QuickCopyInbox.ackKey) as? [String]) ?? []
                    acked.append(contentsOf: entries.compactMap { $0["id"] })
                    ackDefaults.set(Array(acked.suffix(100)), forKey: QuickCopyInbox.ackKey)
                }
                self.finishDrain()
            }
        }
    }

    private func deliverSharedEntries(_ entries: [[String: String]], web: WKWebView, completion: @escaping (Bool) -> Void) {
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SceneDelegate.sharedGroupID)
        let dir = container?.appendingPathComponent(SceneDelegate.sharedInboxFolder, isDirectory: true)
        let validEntries = entries.filter { $0["kind"] != nil && $0["value"] != nil }
        guard !validEntries.isEmpty else { completion(false); return }
        let lock = NSLock()
        var completed = 0
        var allSucceeded = true
        for (index, entry) in validEntries.enumerated() {
            guard let kind = entry["kind"], let value = entry["value"] else { continue }
            var js: String?
            if kind == "text" {
                if let json = try? JSONSerialization.data(withJSONObject: ["payload": value]),
                   let jsonString = String(data: json, encoding: .utf8) {
                    js = "(function(){if(typeof window.handleSharedPasteboardJson==='function'){return window.handleSharedPasteboardJson(\(jsonString))===true;}return false;})()"
                }
            } else if kind == "image", let fileURL = dir?.appendingPathComponent(value) {
                if let data = try? Data(contentsOf: fileURL) {
                    let base64 = "data:image/jpeg;base64," + data.base64EncodedString()
                    if let json = try? JSONSerialization.data(withJSONObject: [base64]),
                       let jsonString = String(data: json, encoding: .utf8) {
                        js = "(function(){if(typeof window.handleSharedPasteboard==='function'){return window.handleSharedPasteboard(\(String(jsonString.dropFirst().dropLast())))===true;}return false;})()"
                    }
                }
            }
            guard let script = js else {
                lock.lock(); allSucceeded = false; completed += 1
                let done = completed == validEntries.count; let success = allSucceeded
                lock.unlock()
                if done { completion(success) }
                continue
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 + Double(index) * 0.6) {
                web.evaluateJavaScript(script) { result, error in
                    lock.lock()
                    if error != nil || (result as? Bool) != true { allSucceeded = false }
                    completed += 1
                    let done = completed == validEntries.count
                    let success = allSucceeded
                    lock.unlock()
                    if let error = error { print("[ShareInbox] delivery failed: \(error.localizedDescription)") }
                    else { print("[ShareInbox] persistence result: \(String(describing: result))") }
                    if done { completion(success) }
                }
            }
        }
    }

    // MARK: - 處理 3D Touch / 長按 App 圖標快速動作 (Home Screen Quick Actions)
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        handleShortcutItem(shortcutItem)
        completionHandler(true)
    }

    func updateDynamicQuickActions(items: [QuickCopyItemData]) {
        DispatchQueue.main.async {
            // 保險：若上一次更新長按選單時當機（旗標還留著），這次先略過並清掉旗標，避免開啟就當機的無限迴圈
            let flags = UserDefaults.standard
            if flags.bool(forKey: "qa_sync_inflight") {
                flags.set(false, forKey: "qa_sync_inflight")
                QuickCopyInbox.logDrain("上次更新長按選單時當機，本次已略過（請回報）")
                return
            }
            // App Group 同步常用速貼，讓「超級快捷鍵」捷徑動作可複製第一筆。
            if let shared = UserDefaults(suiteName: SceneDelegate.sharedGroupID) {
                shared.set(items.map { ["id": $0.id, "label": $0.label, "text": $0.text, "isLink": $0.isLink ? "1" : "0"] }, forKey: "dynamicQuickCopyItems")
            }
            var shortcuts: [UIApplicationShortcutItem] = []
            for (idx, item) in items.prefix(3).enumerated() {
                let title = cleanedString(item.label, max: 40, fallback: "項目 \(idx + 1)")
                let subtitle = cleanedString(item.text, max: 60)
                let shortcut = UIApplicationShortcutItem(
                    type: "copy_dynamic_\(cleanedString(item.id, max: 80, fallback: "\(idx)"))",
                    localizedTitle: title,
                    localizedSubtitle: subtitle.isEmpty ? nil : subtitle,
                    icon: UIApplicationShortcutIcon(type: .favorite),
                    userInfo: ["text": cleanedString(item.text, max: 2000) as NSString]
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
            flags.set(true, forKey: "qa_sync_inflight")
            flags.synchronize()
            UIApplication.shared.shortcutItems = shortcuts
            flags.set(false, forKey: "qa_sync_inflight")
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

        if urlStr.contains("open-wardrobe") {
            DispatchQueue.main.async {
                for scene in UIApplication.shared.connectedScenes {
                    guard let windowScene = scene as? UIWindowScene else { continue }
                    for window in windowScene.windows {
                        if let mainVC = window.rootViewController as? MainViewController {
                            mainVC.presentWardrobeMiniApp()
                            return
                        }
                    }
                }
            }
            return
        }

        if urlStr.contains("set-app-icon") {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let iconName = components?.queryItems?.first(where: { $0.name == "name" })?.value
            AppIconManager.apply(name: iconName) { success, message in
                AppIconManager.report(success: success, message: message)
            }
            return
        }

        if urlStr.contains("shared-inbox") {
            drainSharedInbox()
            return
        }

        if urlStr.contains("wallet") {
            let cardKeyword = urlStr.contains("easycard") ? "悠遊卡" : "WALLET_HOME"
            NotificationManager.executeTargetJump(target: cardKeyword)
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
            BiometricManager.authenticate(reason: "驗證身分以使用卡片") { [weak self] success, err in
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
        if response.notification.request.content.userInfo["workflowId"] != nil {
            NotificationManager.recordInteraction(response)
            if actionId == UNNotificationDefaultActionIdentifier { NotificationManager.pendingTarget = "MORE_PAGE" }
            completionHandler()
            return
        }

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
                NotificationManager.executeTargetJump(target: "悠遊卡")
            }
        } else if actionId == "ACTION_OPEN_WALLET" {
            DispatchQueue.main.async {
                NotificationManager.executeTargetJump(target: "WALLET_HOME")
            }
        } else if actionId == UNNotificationDefaultActionIdentifier {
            // 使用者直接點擊通知條本體（未展開按鈕）
            if let urlStr = response.notification.request.content.userInfo["url"] as? String, let url = URL(string: urlStr) {
                handleDeepLink(url: url)
            } else {
                NotificationManager.executeTargetJump(target: "悠遊卡")
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


private final class CameraLocationProvider: NSObject, CLLocationManagerDelegate {
    static let shared=CameraLocationProvider()
    private let manager=CLLocationManager()
    private var pending=[(CLLocation?)->Void]()
    private var requestInFlight=false
    private override init(){super.init();manager.delegate=self;manager.desiredAccuracy=kCLLocationAccuracyNearestTenMeters}
    func request(_ completion:@escaping(CLLocation?)->Void){
        pending.append(completion)
        switch manager.authorizationStatus {
        case .authorizedAlways,.authorizedWhenInUse: requestLocationIfNeeded()
        case .notDetermined: manager.requestWhenInUseAuthorization()
        default: flush(nil)
        }
    }
    private func requestLocationIfNeeded(){guard !requestInFlight,!pending.isEmpty else{return};requestInFlight=true;manager.requestLocation()}
    private func flush(_ location:CLLocation?){let callbacks=pending;pending.removeAll();requestInFlight=false;callbacks.forEach{$0(location)}}
    func locationManagerDidChangeAuthorization(_ manager:CLLocationManager){if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {requestLocationIfNeeded()}else if manager.authorizationStatus != .notDetermined {flush(nil)}}
    func locationManager(_ manager:CLLocationManager,didUpdateLocations locations:[CLLocation]){flush(locations.last)}
    func locationManager(_ manager:CLLocationManager,didFailWithError error:Error){NSLog("[PhotoVaultCamera] location failed: %@",error.localizedDescription);flush(nil)}
}

// MARK: - PhotoVault 原生相機：直接使用 AVFoundation，原始媒體寫入 App Group，不經過系統照片圖庫。
private final class DualCameraCaptureEngine: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    let session = AVCaptureMultiCamSession()
    let backPreviewLayer: AVCaptureVideoPreviewLayer
    let frontPreviewLayer: AVCaptureVideoPreviewLayer
    private let backOutput = AVCaptureVideoDataOutput()
    private let frontOutput = AVCaptureVideoDataOutput()
    private let audioOutput = AVCaptureAudioDataOutput()
    private var microphoneInput: AVCaptureDeviceInput?
    private let queue = DispatchQueue(label: "com.superdashboard.dual-camera.capture", qos: .userInitiated)
    private let lock = NSLock()
    private var latestBack: CVPixelBuffer?
    private var latestFront: CVPixelBuffer?
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var recordingURL: URL?
    private var isRecording = false
    private var writerStarted = false
    private var recordingCompletion: ((URL?) -> Void)?
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private var backInput: AVCaptureDeviceInput?
    private var frontInput: AVCaptureDeviceInput?
    var backInputDevice: AVCaptureDevice? { backInput?.device }

    override init() {
        backPreviewLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        frontPreviewLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        super.init()
        backPreviewLayer.videoGravity = .resizeAspectFill
        frontPreviewLayer.videoGravity = .resizeAspectFill
    }

    func start(completion: @escaping (Bool, String?) -> Void) {
        queue.async {
            guard AVCaptureMultiCamSession.isMultiCamSupported else { DispatchQueue.main.async { completion(false, "此裝置不支援前後雙鏡頭") }; return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .inputPriority
            guard let back = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let front = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  self.configureMultiCamFormat(back, maxLongEdge: 1920),
                  self.configureMultiCamFormat(front, maxLongEdge: 1280),
                  let backInput = try? AVCaptureDeviceInput(device: back),
                  let frontInput = try? AVCaptureDeviceInput(device: front),
                  self.session.canAddInput(backInput), self.session.canAddInput(frontInput) else {
                self.session.commitConfiguration(); DispatchQueue.main.async { completion(false, "無法建立前後鏡頭輸入") }; return
            }
            self.backInput = backInput; self.frontInput = frontInput
            self.session.addInputWithNoConnections(backInput); self.session.addInputWithNoConnections(frontInput)
            guard let backPort = backInput.ports(for: .video, sourceDeviceType: back.deviceType, sourceDevicePosition: .back).first,
                  let frontPort = frontInput.ports(for: .video, sourceDeviceType: front.deviceType, sourceDevicePosition: .front).first else {
                self.session.commitConfiguration(); DispatchQueue.main.async { completion(false, "無法取得前後鏡頭影像連接埠") }; return
            }
            self.backOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            self.frontOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            self.backOutput.alwaysDiscardsLateVideoFrames = true; self.frontOutput.alwaysDiscardsLateVideoFrames = true
            guard self.session.canAddOutput(self.backOutput), self.session.canAddOutput(self.frontOutput) else {
                self.session.commitConfiguration(); DispatchQueue.main.async { completion(false, "雙鏡頭影像輸出配置失敗") }; return
            }
            self.session.addOutputWithNoConnections(self.backOutput); self.session.addOutputWithNoConnections(self.frontOutput)
            self.backOutput.setSampleBufferDelegate(self, queue: self.queue); self.frontOutput.setSampleBufferDelegate(self, queue: self.queue)
            let backDataConnection = AVCaptureConnection(inputPorts: [backPort], output: self.backOutput)
            let frontDataConnection = AVCaptureConnection(inputPorts: [frontPort], output: self.frontOutput)
            let backPreviewConnection = AVCaptureConnection(inputPort: backPort, videoPreviewLayer: self.backPreviewLayer)
            let frontPreviewConnection = AVCaptureConnection(inputPort: frontPort, videoPreviewLayer: self.frontPreviewLayer)
            guard [backDataConnection, frontDataConnection, backPreviewConnection, frontPreviewConnection].allSatisfy({ self.session.canAddConnection($0) }) else {
                self.session.commitConfiguration(); DispatchQueue.main.async { completion(false, "雙鏡頭預覽連接失敗") }; return
            }
            [backDataConnection, frontDataConnection, backPreviewConnection, frontPreviewConnection].forEach { self.session.addConnection($0) }
            [backDataConnection, backPreviewConnection].forEach { if $0.isVideoOrientationSupported { $0.videoOrientation = .portrait } }
            [frontDataConnection, frontPreviewConnection].forEach { if $0.isVideoOrientationSupported { $0.videoOrientation = .portrait }; $0.automaticallyAdjustsVideoMirroring = false; $0.isVideoMirrored = true }
            self.session.commitConfiguration()
            if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized { _ = self.configureAudioOnQueue() }
            NSLog("[DualCamera] hardwareCost=%.2f systemPressureCost=%.2f", self.session.hardwareCost, self.session.systemPressureCost)
            if self.session.hardwareCost > 1.0 || self.session.systemPressureCost > 1.0 {
                DispatchQueue.main.async { completion(false, "目前裝置負載過高，請稍後再啟用雙鏡頭") }; return
            }
            self.session.startRunning()
            DispatchQueue.main.async { completion(self.session.isRunning, self.session.isRunning ? nil : "雙鏡頭啟動失敗") }
        }
    }

    private func configureMultiCamFormat(_ device: AVCaptureDevice, maxLongEdge: Int32) -> Bool {
        let candidates=device.formats.filter { format in
            guard format.isMultiCamSupported else { return false }
            let d=CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return max(d.width,d.height) <= maxLongEdge && format.videoSupportedFrameRateRanges.contains { $0.minFrameRate <= 30 && $0.maxFrameRate >= 30 }
        }
        guard let chosen=candidates.max(by:{
            let a=CMVideoFormatDescriptionGetDimensions($0.formatDescription), b=CMVideoFormatDescriptionGetDimensions($1.formatDescription)
            return Int64(a.width)*Int64(a.height) < Int64(b.width)*Int64(b.height)
        }) else { NSLog("[DualCamera] no MultiCam format for %@",device.localizedName); return false }
        do {
            try device.lockForConfiguration(); device.activeFormat=chosen
            device.activeVideoMinFrameDuration=CMTime(value:1,timescale:30); device.activeVideoMaxFrameDuration=CMTime(value:1,timescale:30)
            device.unlockForConfiguration(); return true
        } catch { NSLog("[DualCamera] format setup failed %@: %@",device.localizedName,error.localizedDescription); return false }
    }

    func enableAudio(completion: @escaping (Bool) -> Void) {
        queue.async { let success=self.configureAudioOnQueue(); DispatchQueue.main.async { completion(success) } }
    }

    private func configureAudioOnQueue() -> Bool {
        if microphoneInput != nil { return true }
        guard AVCaptureDevice.authorizationStatus(for:.audio) == .authorized,
              let mic=AVCaptureDevice.default(for:.audio),
              let input=try? AVCaptureDeviceInput(device:mic), session.canAddInput(input) else { return false }
        session.beginConfiguration(); defer { session.commitConfiguration() }
        session.addInputWithNoConnections(input)
        guard let port=input.ports(for:.audio,sourceDeviceType:mic.deviceType,sourceDevicePosition:.unspecified).first,
              session.canAddOutput(audioOutput) else { session.removeInput(input); return false }
        session.addOutputWithNoConnections(audioOutput)
        let connection=AVCaptureConnection(inputPorts:[port],output:audioOutput)
        guard session.canAddConnection(connection) else { session.removeOutput(audioOutput);session.removeInput(input);return false }
        session.addConnection(connection);audioOutput.setSampleBufferDelegate(self,queue:queue);microphoneInput=input;return true
    }

    func updatePreviewFrames(bounds: CGRect) {
        backPreviewLayer.frame = bounds
        let pipWidth = bounds.width * 0.27
        let pipHeight = pipWidth * 4.0 / 3.0
        frontPreviewLayer.frame = CGRect(x: bounds.width - pipWidth - 32, y: 90, width: pipWidth, height: pipHeight)
        frontPreviewLayer.cornerRadius = 18; frontPreviewLayer.masksToBounds = true
        frontPreviewLayer.borderWidth = 2; frontPreviewLayer.borderColor = UIColor.white.withAlphaComponent(0.9).cgColor
    }

    func focus(at layerPoint: CGPoint) {
        guard let device=backInput?.device else{return}
        let point=backPreviewLayer.captureDevicePointConverted(fromLayerPoint:layerPoint)
        do{try device.lockForConfiguration();if device.isFocusPointOfInterestSupported{device.focusPointOfInterest=point;device.focusMode = .continuousAutoFocus};if device.isExposurePointOfInterestSupported{device.exposurePointOfInterest=point;device.exposureMode = .continuousAutoExposure};device.unlockForConfiguration()}catch{NSLog("[DualCamera] focus: %@",error.localizedDescription)}
    }

    func setZoom(_ factor: CGFloat) {
        guard let device = backInput?.device else { return }
        let value = min(max(factor, device.minAvailableVideoZoomFactor), min(device.activeFormat.videoMaxZoomFactor, 8))
        queue.async { do { try device.lockForConfiguration(); device.ramp(toVideoZoomFactor: value, withRate: 10); device.unlockForConfiguration() } catch { NSLog("[DualCamera] zoom: %@", error.localizedDescription) } }
    }

    func capturePhoto() -> Data? {
        lock.lock(); let back = latestBack; let front = latestFront; lock.unlock()
        guard let back, let front, let composed = composite(back: back, front: front), let cg = ciContext.createCGImage(composed, from: composed.extent) else { return nil }
        return UIImage(cgImage: cg).jpegData(compressionQuality: 0.94)
    }

    func startRecording(to url: URL, completion: @escaping (Bool) -> Void) {
        queue.async {
            guard !self.isRecording else { DispatchQueue.main.async { completion(false) }; return }
            do {
                let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
                self.writer = writer; self.recordingURL = url; self.writerStarted = false
                self.videoInput = nil; self.audioInput = nil; self.adaptor = nil
                self.isRecording = true
                DispatchQueue.main.async { completion(true) }
            } catch { NSLog("[DualCamera] writer init: %@", error.localizedDescription); DispatchQueue.main.async { completion(false) } }
        }
    }

    func stopRecording(completion: @escaping (URL?) -> Void) {
        queue.async {
            self.isRecording = false
            guard let writer = self.writer, self.writerStarted else { self.writer?.cancelWriting(); self.writer = nil; DispatchQueue.main.async { completion(nil) }; return }
            self.videoInput?.markAsFinished(); self.audioInput?.markAsFinished()
            self.recordingCompletion = completion
            writer.finishWriting { [weak self] in
                guard let self else { return }
                let url = writer.status == .completed ? self.recordingURL : nil
                if writer.status != .completed { NSLog("[DualCamera] writer finish failed: %@", writer.error?.localizedDescription ?? "unknown") }
                self.writer = nil; self.videoInput = nil; self.audioInput = nil; self.adaptor = nil; self.recordingURL = nil; self.writerStarted = false
                let done = self.recordingCompletion; self.recordingCompletion = nil
                DispatchQueue.main.async { done?(url) }
            }
        }
    }

    func stop(completion: (() -> Void)? = nil) {
        queue.async { if self.session.isRunning { self.session.stopRunning() }; self.backOutput.setSampleBufferDelegate(nil, queue: nil); self.frontOutput.setSampleBufferDelegate(nil, queue: nil); self.audioOutput.setSampleBufferDelegate(nil, queue: nil); DispatchQueue.main.async { completion?() } }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output === backOutput, let pixel = CMSampleBufferGetImageBuffer(sampleBuffer) {
            lock.lock(); latestBack = pixel; let front = latestFront; lock.unlock()
            guard let front, let composed = composite(back: pixel, front: front) else { return }
            appendVideo(composed, presentationTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        } else if output === frontOutput, let pixel = CMSampleBufferGetImageBuffer(sampleBuffer) {
            lock.lock(); latestFront = pixel; lock.unlock()
        } else if output === audioOutput {
            appendAudio(sampleBuffer)
        }
    }

    private func composite(back: CVPixelBuffer, front: CVPixelBuffer) -> CIImage? {
        let base = CIImage(cvPixelBuffer: back)
        let overlay = CIImage(cvPixelBuffer: front)
        let extent = base.extent
        let targetWidth = extent.width * 0.27
        let targetHeight = targetWidth * 4.0 / 3.0
        let scale = max(targetWidth / overlay.extent.width, targetHeight / overlay.extent.height)
        let scaled = overlay.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let crop = CGRect(x: scaled.extent.midX - targetWidth/2, y: scaled.extent.midY - targetHeight/2, width: targetWidth, height: targetHeight)
        let pip = scaled.cropped(to: crop).transformed(by: CGAffineTransform(translationX: extent.maxX - targetWidth - 18 - crop.minX, y: extent.maxY - targetHeight - 90 - crop.minY))
        return pip.composited(over: base).cropped(to: extent)
    }

    private func appendVideo(_ image: CIImage, presentationTime: CMTime) {
        guard isRecording, let writer, recordingURL != nil else { return }
        if !writerStarted {
            let width = Int(image.extent.width), height = Int(image.extent.height)
            let settings: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height]
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings); input.expectsMediaDataInRealTime = true
            let attrs: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA), kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height, kCVPixelBufferIOSurfacePropertiesKey as String: [:]]
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attrs)
            guard writer.canAdd(input) else { isRecording = false; return }
            writer.add(input); self.videoInput = input; self.adaptor = adaptor
            if let audioSettings = audioOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mov) as? [String: Any] {
                let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings); audio.expectsMediaDataInRealTime = true
                if writer.canAdd(audio) { writer.add(audio); audioInput = audio }
            }
            guard writer.startWriting() else { isRecording = false; NSLog("[DualCamera] writer start: %@", writer.error?.localizedDescription ?? "unknown"); return }
            writer.startSession(atSourceTime: presentationTime); writerStarted = true
        }
        guard let input = videoInput, input.isReadyForMoreMediaData, let adaptor, let pool = adaptor.pixelBufferPool else { return }
        var buffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer) == kCVReturnSuccess, let buffer else { return }
        ciContext.render(image, to: buffer, bounds: image.extent, colorSpace: CGColorSpaceCreateDeviceRGB())
        if !adaptor.append(buffer, withPresentationTime: presentationTime) { NSLog("[DualCamera] append video failed: %@", writer.error?.localizedDescription ?? "unknown") }
    }

    private func appendAudio(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording, writerStarted, let writer, writer.status == .writing, let audioInput, audioInput.isReadyForMoreMediaData else { return }
        _ = audioInput.append(sampleBuffer)
    }
}

private final class DashboardCameraViewController: UIViewController, AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate {
    private let destinationFolder: URL
    private let onCaptured: ([String: Any]?) -> Void
    private let onOpenGallery: () -> Void
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "com.superdashboard.camera.session")
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var currentInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var isVideoMode = false
    private var isLiveEnabled = true
    private var isRecording = false
    private var pendingPhotoData: Data?
    private var pendingLiveMovieURL: URL?
    private var waitingForLiveMovie = false
    private var pendingFilename = ""
    private var pendingCaptureID = ""
    private var pendingPhotoExtension = "jpg"
    private var flashEnabled = false
    private var pinchStartZoom: CGFloat = 1.0
    private var recordingStartedAt: Date?
    private var recordingTimer: Timer?
    private var latestPreviewURL: URL?
    private var latestPreviewIsVideo = false
    private var dualEngine: DualCameraCaptureEngine?
    private var isDualMode = false
    private var isDualTransitioning = false
    private let recordingTimeLabel = UILabel()
    private let zoomSlider = UISlider()
    private let zoomValueLabel = UILabel()
    private let focalLengthStack = UIStackView()
    private var shutterInnerLayer: CAShapeLayer?

    private let closeButton = UIButton(type: .system)
    private let shutterButton = UIButton(type: .system)
    private let flipButton = UIButton(type: .system)
    private let flashButton = UIButton(type: .system)
    private let liveButton = UIButton(type: .system)
    private let dualButton = UIButton(type: .system)
    private let modeControl = UISegmentedControl(items: ["照片", "影片"])
    private let hintLabel = UILabel()
    private let recentThumbnailButton = UIButton(type: .custom)

    init(destinationFolder: URL, onOpenGallery: @escaping () -> Void, onCaptured: @escaping ([String: Any]?) -> Void) {
        self.destinationFolder = destinationFolder
        self.onOpenGallery = onOpenGallery
        self.onCaptured = onCaptured
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureControls()
        configurePreview()
        let focusTap = UITapGestureRecognizer(target: self, action: #selector(focusAtPoint(_:)))
        view.addGestureRecognizer(focusTap)
        let zoomPinch = UIPinchGestureRecognizer(target: self, action: #selector(zoomWithPinch(_:)))
        view.addGestureRecognizer(zoomPinch)
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(swipeToVideo))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)
        requestCameraAccessAndStart()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.session.isRunning { self.session.startRunning() }
            DispatchQueue.main.async { self.shutterButton.isEnabled = true; self.shutterButton.alpha = 1 }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        dualEngine?.updatePreviewFrames(bounds: view.bounds)
        let inset = shutterButton.bounds.insetBy(dx: 9, dy: 9)
        shutterInnerLayer?.frame = shutterButton.bounds
        if isRecording {
            shutterInnerLayer?.fillColor = UIColor.systemRed.cgColor
            shutterInnerLayer?.path = UIBezierPath(roundedRect: shutterButton.bounds.insetBy(dx: 23, dy: 23), cornerRadius: 5).cgPath
        } else {
            shutterInnerLayer?.fillColor = UIColor.white.cgColor
            shutterInnerLayer?.path = UIBezierPath(ovalIn: inset).cgPath
        }
    }

    private func configurePreview() {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)
    }

    private func configureControls() {
        func style(_ button: UIButton, title: String? = nil, symbol: String? = nil) {
            if let title { button.setTitle(title, for: .normal) }
            if let symbol { button.setImage(UIImage(systemName: symbol), for: .normal) }
            button.tintColor = .white
            button.backgroundColor = UIColor.black.withAlphaComponent(0.38)
            button.layer.cornerRadius = 22
            button.clipsToBounds = true
            button.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(button)
        }
        style(closeButton, symbol: "xmark")
        style(flipButton, symbol: "camera.rotate")
        style(flashButton, symbol: "bolt.slash")
        style(liveButton, title: "● LIVE")
        style(dualButton, title: "雙鏡 OFF")
        dualButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        dualButton.layer.cornerRadius = 14
        dualButton.addTarget(self, action: #selector(openDualCapture), for: .touchUpInside)
        recentThumbnailButton.translatesAutoresizingMaskIntoConstraints = false
        recentThumbnailButton.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        recentThumbnailButton.layer.cornerRadius = 9
        recentThumbnailButton.layer.borderWidth = 1.5
        recentThumbnailButton.layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
        recentThumbnailButton.clipsToBounds = true
        recentThumbnailButton.setImage(UIImage(systemName: "photo"), for: .normal)
        recentThumbnailButton.addTarget(self, action: #selector(openRecentPreview), for: .touchUpInside)
        recentThumbnailButton.tintColor = .white
        recentThumbnailButton.imageView?.contentMode = .scaleAspectFill
        view.addSubview(recentThumbnailButton)
        liveButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        liveButton.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.92)
        liveButton.setTitleColor(.black, for: .normal)
        liveButton.layer.cornerRadius = 16
        style(shutterButton)
        shutterButton.backgroundColor = .clear
        shutterButton.layer.cornerRadius = 37
        shutterButton.layer.borderWidth = 5
        shutterButton.layer.borderColor = UIColor.white.withAlphaComponent(0.95).cgColor
        let innerRing = CAShapeLayer()
        innerRing.fillColor = UIColor.white.cgColor
        innerRing.strokeColor = UIColor.clear.cgColor
        innerRing.lineWidth = 0
        shutterButton.layer.addSublayer(innerRing)
        shutterInnerLayer = innerRing
        shutterButton.layer.shadowColor = UIColor.black.cgColor
        shutterButton.layer.shadowOpacity = 0.35
        shutterButton.layer.shadowRadius = 8
        shutterButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        shutterButton.addTarget(self, action: #selector(shutterPressed), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(closePressed), for: .touchUpInside)
        flipButton.addTarget(self, action: #selector(flipCamera), for: .touchUpInside)
        flashButton.addTarget(self, action: #selector(toggleFlash), for: .touchUpInside)
        liveButton.addTarget(self, action: #selector(toggleLive), for: .touchUpInside)

        modeControl.selectedSegmentIndex = 0
        modeControl.selectedSegmentTintColor = .white
        modeControl.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
        modeControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        modeControl.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        modeControl.translatesAutoresizingMaskIntoConstraints = false
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        view.addSubview(modeControl)

        recordingTimeLabel.text = "00:00"
        recordingTimeLabel.textColor = .white
        recordingTimeLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        recordingTimeLabel.textAlignment = .center
        recordingTimeLabel.isHidden = true
        recordingTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(recordingTimeLabel)

        zoomSlider.minimumValue = 0.5
        zoomSlider.maximumValue = 5
        zoomSlider.value = 1
        zoomSlider.minimumTrackTintColor = .white
        zoomSlider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.35)
        zoomSlider.translatesAutoresizingMaskIntoConstraints = false
        zoomSlider.addTarget(self, action: #selector(zoomSliderChanged), for: .valueChanged)
        zoomSlider.isHidden = false
        view.addSubview(zoomSlider)
        focalLengthStack.axis = .horizontal; focalLengthStack.alignment = .center; focalLengthStack.distribution = .equalSpacing; focalLengthStack.spacing = 10; focalLengthStack.translatesAutoresizingMaskIntoConstraints = false
        [(50,"0.5×"),(100,"1×"),(200,"2×"),(400,"4×"),(800,"8×")].forEach { factor,title in
            let b=UIButton(type:.system); b.setTitle(title,for:.normal); b.setTitleColor(.white,for:.normal); b.titleLabel?.font = .systemFont(ofSize:12,weight:.semibold); b.tag=factor; b.addTarget(self,action:#selector(selectFocalLength(_:)),for:.touchUpInside); focalLengthStack.addArrangedSubview(b)
        }
        view.addSubview(focalLengthStack)
        zoomValueLabel.text = "1×"
        zoomValueLabel.textColor = .white
        zoomValueLabel.font = .systemFont(ofSize: 12, weight: .bold)
        zoomValueLabel.textAlignment = .center
        zoomValueLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(zoomValueLabel)

        hintLabel.text = "原況照片已開啟"
        hintLabel.textColor = .white
        hintLabel.font = .systemFont(ofSize: 12, weight: .medium)
        hintLabel.textAlignment = .center
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hintLabel)

        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 18),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.widthAnchor.constraint(equalToConstant: 44), closeButton.heightAnchor.constraint(equalToConstant: 44),
            flashButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -18),
            flashButton.topAnchor.constraint(equalTo: closeButton.topAnchor),
            flashButton.widthAnchor.constraint(equalToConstant: 44), flashButton.heightAnchor.constraint(equalToConstant: 44),
            liveButton.leadingAnchor.constraint(equalTo: closeButton.trailingAnchor, constant: 12),
            liveButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            liveButton.heightAnchor.constraint(equalToConstant: 32), liveButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 74),
            dualButton.trailingAnchor.constraint(equalTo: flashButton.leadingAnchor, constant: -10), dualButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor), dualButton.heightAnchor.constraint(equalToConstant: 30), dualButton.widthAnchor.constraint(equalToConstant: 66),
            recordingTimeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordingTimeLabel.bottomAnchor.constraint(equalTo: shutterButton.topAnchor, constant: -10),
            recordingTimeLabel.heightAnchor.constraint(equalToConstant: 20),
            zoomSlider.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            zoomSlider.bottomAnchor.constraint(equalTo: focalLengthStack.topAnchor, constant: -5),
            zoomSlider.widthAnchor.constraint(equalToConstant: 220),
            focalLengthStack.centerXAnchor.constraint(equalTo: view.centerXAnchor), focalLengthStack.bottomAnchor.constraint(equalTo: modeControl.topAnchor, constant: -42), focalLengthStack.widthAnchor.constraint(equalToConstant: 224), focalLengthStack.heightAnchor.constraint(equalToConstant: 28),
            zoomValueLabel.trailingAnchor.constraint(equalTo: focalLengthStack.leadingAnchor, constant: -8),
            zoomValueLabel.centerYAnchor.constraint(equalTo: focalLengthStack.centerYAnchor),
            zoomValueLabel.widthAnchor.constraint(equalToConstant: 30),
            modeControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            modeControl.bottomAnchor.constraint(equalTo: shutterButton.topAnchor, constant: -28),
            modeControl.widthAnchor.constraint(equalToConstant: 160), modeControl.heightAnchor.constraint(equalToConstant: 34),
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            shutterButton.widthAnchor.constraint(equalToConstant: 74), shutterButton.heightAnchor.constraint(equalToConstant: 74),
            flipButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -22),
            flipButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
            flipButton.widthAnchor.constraint(equalToConstant: 48), flipButton.heightAnchor.constraint(equalToConstant: 48),
            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintLabel.bottomAnchor.constraint(equalTo: modeControl.topAnchor, constant: -14),
            recentThumbnailButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 22),
            recentThumbnailButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
            recentThumbnailButton.widthAnchor.constraint(equalToConstant: 54), recentThumbnailButton.heightAnchor.constraint(equalToConstant: 54)
        ])
        updateLiveButton()
    }

    private func requestCameraAccessAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted { self.configureSession() } else { self.showCameraError("請在設定中允許超級儀表板使用相機") }
                }
            }
        default: showCameraError("請在 iPhone 設定中允許超級儀表板使用相機")
        }
    }

    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            if let input = self.currentInput { self.session.removeInput(input) }
            let device = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            guard let device,
                  let input = try? AVCaptureDeviceInput(device: device), self.session.canAddInput(input) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async { self.showCameraError("無法啟動相機") }
                return
            }
            self.session.addInput(input)
            self.currentInput = input
            DispatchQueue.main.async {
                self.zoomSlider.minimumValue = Float(device.minAvailableVideoZoomFactor)
                self.zoomSlider.maximumValue = Float(min(device.activeFormat.videoMaxZoomFactor, 8.0))
                self.zoomSlider.value = 1
                self.zoomValueLabel.text = "1×"
            }
            if self.session.canAddOutput(self.photoOutput) && !self.session.outputs.contains(self.photoOutput) { self.session.addOutput(self.photoOutput) }
            if self.session.outputs.contains(self.movieOutput) { self.session.removeOutput(self.movieOutput) }
            if let audio = self.audioInput { self.session.removeInput(audio); self.audioInput = nil }
            self.session.commitConfiguration()
            self.session.startRunning()
            let liveSupported = self.photoOutput.isLivePhotoCaptureSupported
            if liveSupported { self.photoOutput.isLivePhotoCaptureEnabled = true }
            NSLog("[PhotoVaultCamera] livePhotoSupported=%@, enabled=%@, preset=%@, device=%@", String(liveSupported), String(self.photoOutput.isLivePhotoCaptureEnabled), String(describing: self.session.sessionPreset), device.localizedName)
            DispatchQueue.main.async {
                NSLog("[PhotoVaultCamera] photoOutput=%@ movieOutput=%@ multicam=%@", String(describing: self.photoOutput.connections.count), String(describing: self.movieOutput.connections.count), String(AVCaptureMultiCamSession.isMultiCamSupported))
            self.isLiveEnabled = liveSupported
                self.liveButton.isEnabled = liveSupported
                self.liveButton.alpha = liveSupported ? 1 : 0.45
                self.updateLiveButton()
                if !liveSupported { self.hintLabel.text = "此相機配置暫不支援原況拍攝" }
            }
        }
    }

    @objc private func closePressed() {
        if isRecording { shutterPressed(); return }
        dualEngine?.stop(); dualEngine=nil; isDualMode=false
        sessionQueue.async { self.session.stopRunning() }
        dismiss(animated: true)
    }

    @objc private func focusAtPoint(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: view)
        if isDualMode { dualEngine?.focus(at: point); return }
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        guard let device = currentInput?.device else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = devicePoint
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        } catch { NSLog("[PhotoVaultCamera] focus adjustment failed: %@", error.localizedDescription) }
    }

    @objc private func selectFocalLength(_ sender: UIButton) {
        guard let device=(isDualMode ? dualEngine?.backInputDevice : currentInput?.device) else{return}
        let requested=CGFloat(sender.tag)/100
        let zoom=min(max(requested,device.minAvailableVideoZoomFactor),min(device.activeFormat.videoMaxZoomFactor,8.0))
        do{try device.lockForConfiguration();device.ramp(toVideoZoomFactor:zoom,withRate:8);device.unlockForConfiguration()}catch{NSLog("[PhotoVaultCamera] focal selection failed: %@",error.localizedDescription)}
        zoomSlider.value=Float(zoom);zoomValueLabel.text=String(format:"%.1f×",zoom)
        focalLengthStack.arrangedSubviews.compactMap{$0 as? UIButton}.forEach{$0.backgroundColor=$0.tag==sender.tag ? UIColor.white.withAlphaComponent(0.22) : .clear;$0.layer.cornerRadius=10}
    }

    @objc private func zoomSliderChanged() {
        guard let device = isDualMode ? dualEngine?.backInputDevice : currentInput?.device else { return }
        let requested = CGFloat(zoomSlider.value)
        let zoom = min(max(requested, device.minAvailableVideoZoomFactor), min(device.activeFormat.videoMaxZoomFactor, 8.0))
        do { try device.lockForConfiguration(); device.ramp(toVideoZoomFactor: zoom, withRate: 10); device.unlockForConfiguration() }
        catch { NSLog("[PhotoVaultCamera] slider zoom failed: %@", error.localizedDescription) }
        zoomValueLabel.text = String(format: "%.1f×", zoom)
    }

    @objc private func openDualCapture() {
        if isRecording { showCameraError("請先停止錄影，再切換雙鏡頭"); return }
        guard !isDualTransitioning else { return }
        isDualTransitioning = true
        if isDualMode {
            let oldEngine=dualEngine; dualEngine=nil; isDualMode=false
            oldEngine?.stop { [weak self] in
                guard let self else{return}
                oldEngine?.backPreviewLayer.removeFromSuperlayer(); oldEngine?.frontPreviewLayer.removeFromSuperlayer()
                self.previewLayer.isHidden=false; self.dualButton.setTitle("雙鏡 OFF",for:.normal); self.isDualTransitioning=false
                self.sessionQueue.async { [weak self] in guard let self else{return}; if !self.session.isRunning { self.session.startRunning() } }
                self.liveButton.isEnabled=true; self.flashButton.isEnabled=true; self.flipButton.isEnabled=true; self.updateLiveButton()
                if let device=self.currentInput?.device { self.zoomSlider.minimumValue=Float(device.minAvailableVideoZoomFactor);self.zoomSlider.maximumValue=Float(min(device.activeFormat.videoMaxZoomFactor,8));self.zoomSlider.value=Float(device.videoZoomFactor);if let ultra=self.focalLengthStack.arrangedSubviews.first as? UIButton { ultra.isEnabled=device.minAvailableVideoZoomFactor < 0.75;ultra.alpha=ultra.isEnabled ? 1 : 0.35 } }
            }
            return
        }
        guard AVCaptureMultiCamSession.isMultiCamSupported else { isDualTransitioning=false; showCameraError("此裝置不支援前後雙鏡頭同時拍攝"); return }
        sessionQueue.async { [weak self] in
            guard let self else{return}; if self.session.isRunning { self.session.stopRunning() }
            let engine=DualCameraCaptureEngine()
            engine.start { [weak self] success,message in
                guard let self else { engine.stop(); return }
                guard success else { self.isDualTransitioning=false; self.sessionQueue.async { if !self.session.isRunning { self.session.startRunning() } }; self.showCameraError(message ?? "雙鏡頭啟動失敗"); return }
                self.isDualTransitioning=false; self.dualEngine=engine; self.isDualMode=true; self.previewLayer.isHidden=true
                self.view.layer.insertSublayer(engine.backPreviewLayer, above:self.previewLayer)
                self.view.layer.insertSublayer(engine.frontPreviewLayer, above:engine.backPreviewLayer)
                engine.updatePreviewFrames(bounds:self.view.bounds)
                self.dualButton.setTitle("雙鏡 ON",for:.normal); self.liveButton.isEnabled=false; self.flashButton.isEnabled=false; self.flipButton.isEnabled=false
                let minZoom=engine.backInputDevice?.minAvailableVideoZoomFactor ?? 1
                self.zoomSlider.minimumValue=Float(minZoom);self.zoomSlider.maximumValue=Float(min(engine.backInputDevice?.activeFormat.videoMaxZoomFactor ?? 8,8));self.zoomSlider.value=1
                if let ultra=self.focalLengthStack.arrangedSubviews.first as? UIButton { ultra.isEnabled=minZoom < 0.75; ultra.alpha=ultra.isEnabled ? 1 : 0.35 }
                self.hintLabel.text="後鏡頭主畫面・前鏡頭子母畫面"
            }
        }
    }

    @objc private func openRecentPreview() {
        if isRecording { shutterPressed(); return }
        guard latestPreviewURL != nil else { showCameraError("尚未拍攝照片或影片"); return }
        if isDualMode { let old=dualEngine; dualEngine=nil; isDualMode=false; old?.stop { old?.backPreviewLayer.removeFromSuperlayer(); old?.frontPreviewLayer.removeFromSuperlayer(); self.dismiss(animated:true){self.onOpenGallery()} }; return }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async { self.dismiss(animated:true) { self.onOpenGallery() } }
        }
    }

    @objc private func zoomWithPinch(_ gesture: UIPinchGestureRecognizer) {
        guard let device = isDualMode ? dualEngine?.backInputDevice : currentInput?.device else { return }
        if gesture.state == .began { pinchStartZoom = device.videoZoomFactor }
        let desired = min(max(pinchStartZoom * gesture.scale, device.minAvailableVideoZoomFactor), min(device.activeFormat.videoMaxZoomFactor, 8.0))
        do {
            try device.lockForConfiguration()
            device.ramp(toVideoZoomFactor: desired, withRate: 10)
            device.unlockForConfiguration()
        } catch { NSLog("[PhotoVaultCamera] zoom adjustment failed: %@", error.localizedDescription) }
    }

    @objc private func flipCamera() {
        sessionQueue.async { [weak self] in
            guard let self, let old = self.currentInput else { return }
            let nextPosition: AVCaptureDevice.Position = old.device.position == .back ? .front : .back
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: nextPosition),
                  let input = try? AVCaptureDeviceInput(device: device) else { return }
            self.session.beginConfiguration()
            self.session.removeInput(old)
            if self.session.canAddInput(input) { self.session.addInput(input); self.currentInput = input }
            else { self.session.addInput(old) }
            self.session.commitConfiguration()
        }
    }

    @objc private func toggleFlash() {
        flashEnabled.toggle()
        flashButton.setImage(UIImage(systemName: flashEnabled ? "bolt.fill" : "bolt.slash"), for: .normal)
        if isVideoMode, let device = currentInput?.device, device.hasTorch {
            try? device.lockForConfiguration()
            device.torchMode = flashEnabled ? .on : .off
            device.unlockForConfiguration()
        }
    }

    @objc private func toggleLive() {
        guard photoOutput.isLivePhotoCaptureSupported else { showCameraError("此裝置目前不支援原況照片拍攝"); return }
        isLiveEnabled.toggle()
        updateLiveButton()
    }

    private func updateLiveButton() {
        liveButton.isHidden = isVideoMode
        liveButton.alpha = isLiveEnabled ? 1 : 0.55
        liveButton.setTitle(isLiveEnabled ? "● LIVE" : "LIVE 關閉", for: .normal)
        hintLabel.text = isVideoMode ? "影片將直接儲存至儀表板相片庫" : (isLiveEnabled ? "原況照片已開啟" : "原況照片已關閉")
    }

    @objc private func swipeToVideo() {
        guard !isRecording else { return }
        modeControl.selectedSegmentIndex = 1
        modeChanged()
    }

    @objc private func modeChanged() {
        isVideoMode = modeControl.selectedSegmentIndex == 1
        if isDualMode {
            if isVideoMode {
                switch AVCaptureDevice.authorizationStatus(for:.audio) {
                case .authorized:
                    shutterButton.isEnabled=false
                    dualEngine?.enableAudio { [weak self] ok in guard let self else{return};self.shutterButton.isEnabled=true;if !ok { self.showCameraError("無法啟用雙鏡頭錄音") } }
                case .notDetermined:
                    shutterButton.isEnabled=false
                    AVCaptureDevice.requestAccess(for:.audio) { [weak self] granted in
                        guard let self else{return}
                        if granted { self.dualEngine?.enableAudio { ok in self.shutterButton.isEnabled=true;if !ok { self.showCameraError("無法啟用雙鏡頭錄音") } } }
                        else { DispatchQueue.main.async { self.shutterButton.isEnabled=true;self.modeControl.selectedSegmentIndex=0;self.isVideoMode=false;self.showCameraError("未允許麥克風，無法錄製有聲雙鏡影片") } }
                    }
                default: shutterButton.isEnabled=true;modeControl.selectedSegmentIndex=0;isVideoMode=false;showCameraError("請允許麥克風，才能錄製有聲雙鏡影片")
                }
            }
            updateLiveButton(); shutterButton.backgroundColor = .clear; shutterInnerLayer?.fillColor = UIColor.white.cgColor
            hintLabel.text = isVideoMode ? "雙鏡子母畫面錄影" : "雙鏡子母畫面拍照"
            return
        }
        if isVideoMode {
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized: addMicrophoneInput()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                    guard let self else { return }
                    if granted { self.addMicrophoneInput() }
                    else { DispatchQueue.main.async { self.modeControl.selectedSegmentIndex = 0; self.isVideoMode = false; self.updateLiveButton(); self.showCameraError("未允許麥克風，無法錄製有聲影片") } }
                }
            default:
                modeControl.selectedSegmentIndex = 0
                isVideoMode = false
                showCameraError("請在 iPhone 設定中允許麥克風，才能錄製有聲影片")
            }
        }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = self.isVideoMode ? .high : .photo
            if self.isVideoMode {
                if !self.session.outputs.contains(self.movieOutput), self.session.canAddOutput(self.movieOutput) { self.session.addOutput(self.movieOutput) }
            } else if self.session.outputs.contains(self.movieOutput) { self.session.removeOutput(self.movieOutput) }
            self.session.commitConfiguration()
            if !self.isVideoMode {
                let supported=self.photoOutput.isLivePhotoCaptureSupported
                self.photoOutput.isLivePhotoCaptureEnabled=supported
                DispatchQueue.main.async { self.isLiveEnabled=supported; self.updateLiveButton(); if !supported { self.hintLabel.text="目前相機配置無法拍攝原況照片" } }
            }
        }
        updateLiveButton()
        shutterButton.backgroundColor = .clear
        shutterInnerLayer?.fillColor = UIColor.white.cgColor
    }

    private func addMicrophoneInput() {
        sessionQueue.async { [weak self] in
            guard let self, self.audioInput == nil,
                  let microphone = AVCaptureDevice.default(for: .audio),
                  let input = try? AVCaptureDeviceInput(device: microphone), self.session.canAddInput(input) else { return }
            self.session.beginConfiguration(); self.session.addInput(input); self.audioInput = input; self.session.commitConfiguration()
        }
    }

    @objc private func shutterPressed() {
        if isDualMode { handleDualShutter(); return }
        guard !isRecording else { movieOutput.stopRecording(); return }
        if isVideoMode {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("DashboardVideo-\(UUID().uuidString).mov")
            isRecording = true
            modeControl.isEnabled = false
            recordingStartedAt = Date()
            recordingTimeLabel.isHidden = false
            recordingTimeLabel.textColor = .systemRed
            recordingTimeLabel.text = "00:00"
            shutterButton.backgroundColor = .clear
            shutterButton.layer.cornerRadius = 37
            shutterButton.layer.borderWidth = 5
            recordingTimeLabel.textColor = .systemRed
            recordingTimeLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .bold)
            shutterInnerLayer?.isHidden = false
            shutterInnerLayer?.fillColor = UIColor.systemRed.cgColor
            shutterInnerLayer?.path = UIBezierPath(roundedRect: shutterButton.bounds.insetBy(dx: 23, dy: 23), cornerRadius: 5).cgPath
            recordingTimer?.invalidate()
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                guard let self, let started = self.recordingStartedAt else { return }
                let seconds = Int(Date().timeIntervalSince(started))
                self.recordingTimeLabel.text = String(format: "%02d:%02d", seconds / 60, seconds % 60)
            }
            movieOutput.startRecording(to: url, recordingDelegate: self)
            return
        }
        let id = UUID().uuidString
        pendingCaptureID = id
        pendingPhotoData = nil
        pendingLiveMovieURL = nil
        waitingForLiveMovie = isLiveEnabled && photoOutput.isLivePhotoCaptureSupported && photoOutput.isLivePhotoCaptureEnabled
        // Live Photo 使用 JPEG still；避免 HEVC 靜態影像編碼與配對 MOV 的擷取組合造成裝置端失敗。
        let supportsHEVC = !waitingForLiveMovie && photoOutput.availablePhotoCodecTypes.contains(.hevc)
        pendingPhotoExtension = supportsHEVC ? "heic" : "jpg"
        pendingFilename = "IMG_\(Int(Date().timeIntervalSince1970))_\(id.prefix(6)).\(pendingPhotoExtension)"
        let settings: AVCapturePhotoSettings
        if supportsHEVC { settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc]) }
        else { settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg]) }
        if let device = currentInput?.device, device.hasFlash { settings.flashMode = flashEnabled ? .on : .off }
        if waitingForLiveMovie {
            settings.livePhotoMovieFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("Live-\(id).mov")
        }
        shutterButton.alpha = 0.55
        guard photoOutput.connections.contains(where:{$0.isEnabled}) else { waitingForLiveMovie=false; shutterButton.alpha=1; showCameraError("相機輸出尚未就緒，請稍後再拍"); return }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    private func publishCapturedRecord(_ record: [String: Any]) {
        onCaptured(record)
        CameraLocationProvider.shared.request { [weak self] location in
            guard let self, let coordinate=location?.coordinate else { return }
            var updated=record; updated["location"]=String(format:"%.5f, %.5f",coordinate.latitude,coordinate.longitude)
            DispatchQueue.main.async { self.onCaptured(updated) }
        }
    }

    private func handleDualShutter() {
        guard let engine=dualEngine else { showCameraError("雙鏡頭尚未就緒"); return }
        if isVideoMode {
            if !isRecording {
                let url=destinationFolder.appendingPathComponent("DUAL_\(Int(Date().timeIntervalSince1970)).mov")
                engine.startRecording(to:url){[weak self] success in
                    guard let self else{return}; guard success else{self.showCameraError("無法開始雙鏡錄影");return}
                    self.isRecording=true;self.modeControl.isEnabled=false;self.recordingStartedAt=Date();self.recordingTimeLabel.isHidden=false;self.recordingTimeLabel.textColor = .systemRed;self.recordingTimeLabel.text="00:00";self.shutterButton.layer.cornerRadius=37;self.shutterButton.layer.borderWidth=5;self.shutterInnerLayer?.fillColor=UIColor.systemRed.cgColor;self.shutterInnerLayer?.path=UIBezierPath(roundedRect:self.shutterButton.bounds.insetBy(dx:23,dy:23),cornerRadius:5).cgPath
                    self.recordingTimer?.invalidate();self.recordingTimer=Timer.scheduledTimer(withTimeInterval:0.2,repeats:true){[weak self]_ in guard let self,let start=self.recordingStartedAt else{return};let t=Int(Date().timeIntervalSince(start));self.recordingTimeLabel.text=String(format:"%02d:%02d",t/60,t%60)}
                }
            } else {
                engine.stopRecording{[weak self] url in
                    guard let self else{return};self.isRecording=false;self.modeControl.isEnabled=true;self.recordingTimer?.invalidate();self.recordingTimer=nil;self.recordingStartedAt=nil;self.recordingTimeLabel.isHidden=true;self.recordingTimeLabel.textColor = .white;self.shutterInnerLayer?.fillColor=UIColor.white.cgColor;self.shutterInnerLayer?.path=UIBezierPath(ovalIn:self.shutterButton.bounds.insetBy(dx:9,dy:9)).cgPath
                    guard let url else{self.showCameraError("雙鏡影片儲存失敗");return}
                    let filename=url.lastPathComponent;let destination=self.destinationFolder.appendingPathComponent(filename)
                    do{if url != destination { if FileManager.default.fileExists(atPath:destination.path){try FileManager.default.removeItem(at:destination)};try FileManager.default.copyItem(at:url,to:destination) }
                        let asset=AVURLAsset(url:destination);let seconds=CMTimeGetSeconds(asset.duration);let duration=seconds.isFinite ? String(format:"%02d:%02d",Int(seconds)/60,Int(seconds)%60):""
                        let gen=AVAssetImageGenerator(asset:asset);gen.appliesPreferredTrackTransform=true;let frame=try? gen.copyCGImage(at:.zero,actualTime:nil);let thumb=frame.flatMap{UIImage(cgImage:$0).jpegData(compressionQuality:0.75)} ?? Data();let movie=try Data(contentsOf:destination)
                        let record:[String:Any] = ["id":"dual-\(UUID().uuidString)","filename":filename,"mediaType":"video","source":"native-camera","isLive":false,"dataUrl":"data:image/jpeg;base64,\(thumb.base64EncodedString())","videoUrl":"data:video/quicktime;base64,\(movie.base64EncodedString())","duration":duration,"size":movie.count,"createdAt":Date().timeIntervalSince1970*1000,"album":"全部相片"]
                        self.latestPreviewURL=destination;self.latestPreviewIsVideo=true;self.publishCapturedRecord(record);self.recentThumbnailButton.setImage(UIImage(data:thumb),for:.normal);self.hintLabel.text="雙鏡子母影片已儲存"
                    }catch{self.showCameraError("無法儲存雙鏡影片：\(error.localizedDescription)")}
                }
            }
            return
        }
        guard let data=engine.capturePhoto(),let image=UIImage(data:data) else{showCameraError("雙鏡頭畫面尚未就緒");return}
        let filename="DUAL_IMG_\(Int(Date().timeIntervalSince1970)).jpg";let url=destinationFolder.appendingPathComponent(filename)
        do{try data.write(to:url,options:.atomic);let thumb=image.jpegData(compressionQuality:0.78) ?? data;let record:[String:Any] = ["id":"dual-\(UUID().uuidString)","filename":filename,"mediaType":"image","source":"native-camera","isLive":false,"dataUrl":"data:image/jpeg;base64,\(data.base64EncodedString())","thumbnailUrl":"data:image/jpeg;base64,\(thumb.base64EncodedString())","size":data.count,"width":image.cgImage?.width ?? 0,"height":image.cgImage?.height ?? 0,"createdAt":Date().timeIntervalSince1970*1000,"album":"全部相片"]
            latestPreviewURL=url;latestPreviewIsVideo=false;publishCapturedRecord(record);recentThumbnailButton.setImage(UIImage(data:thumb),for:.normal);UIImpactFeedbackGenerator(style:.medium).impactOccurred()
        }catch{showCameraError("無法儲存雙鏡照片：\(error.localizedDescription)")}
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        DispatchQueue.main.async {
            guard error == nil, let data = photo.fileDataRepresentation() else { self.showCameraError("拍攝失敗，請再試一次"); return }
            self.pendingPhotoData = data
            if !self.waitingForLiveMovie { self.finishPhotoCapture() }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL, resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        DispatchQueue.main.async {
            if error == nil { self.pendingLiveMovieURL = outputFileURL }
            self.waitingForLiveMovie = false
            self.finishPhotoCapture()
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        guard let error else { return }
        DispatchQueue.main.async {
            NSLog("[PhotoVaultCamera] capture pipeline failed: %@", error.localizedDescription)
            self.waitingForLiveMovie = false
            self.pendingLiveMovieURL = nil
            if self.pendingPhotoData != nil { self.finishPhotoCapture() }
            else { self.pendingCaptureID = ""; self.pendingFilename = ""; self.shutterButton.alpha = 1; self.showCameraError("原況照片拍攝失敗：\(error.localizedDescription)") }
        }
    }

    private func finishPhotoCapture() {
        guard let data = pendingPhotoData, !waitingForLiveMovie else { return }
        let filename = pendingFilename
        let photoURL = destinationFolder.appendingPathComponent(filename)
        do { try data.write(to: photoURL, options: .atomic) }
        catch { showCameraError("無法儲存照片：\(error.localizedDescription)"); return }
        var liveFilename = ""
        var liveDataURL = ""
        if let movieURL = pendingLiveMovieURL {
            liveFilename = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent + "-paired.mov"
            let movieDestination = destinationFolder.appendingPathComponent(liveFilename)
            do {
                if FileManager.default.fileExists(atPath: movieDestination.path) { try FileManager.default.removeItem(at: movieDestination) }
                try FileManager.default.moveItem(at: movieURL, to: movieDestination)
                liveDataURL = "data:video/quicktime;base64,\(try Data(contentsOf: movieDestination).base64EncodedString())"
            } catch { NSLog("[PhotoVaultCamera] Live Photo paired movie save failed: %@", error.localizedDescription); liveFilename = "" }
        }
        let image = UIImage(data: data)
        let fullViewData = image?.jpegData(compressionQuality: 0.92) ?? data
        let thumb = image?.jpegData(compressionQuality: 0.76) ?? data
        let record: [String: Any] = [
            "id": "camera-\(pendingCaptureID)", "filename": filename, "mediaType": "image", "source": "native-camera",
            "isLive": !liveFilename.isEmpty, "dataUrl": "data:image/jpeg;base64,\(fullViewData.base64EncodedString())", "thumbnailUrl": "data:image/jpeg;base64,\(thumb.base64EncodedString())",
            "liveVideoUrl": liveDataURL, "liveVideoFilename": liveFilename,
            "size": data.count, "width": image?.cgImage?.width ?? 0, "height": image?.cgImage?.height ?? 0,
            "createdAt": Date().timeIntervalSince1970 * 1000, "album": "全部相片"
        ]
        pendingPhotoData = nil; pendingLiveMovieURL = nil; pendingFilename = ""; pendingCaptureID = ""
        shutterButton.alpha = 1
        latestPreviewURL = photoURL
        latestPreviewIsVideo = false
        publishCapturedRecord(record)
        recentThumbnailButton.setImage(UIImage(data: thumb), for: .normal)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        hintLabel.text = "已儲存至儀表板相片庫"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { self.hintLabel.text = self.isLiveEnabled ? "原況照片已開啟" : "原況照片已關閉" }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async {
            self.isRecording = false
            self.modeControl.isEnabled = true
            self.recordingTimer?.invalidate(); self.recordingTimer = nil
            self.recordingStartedAt = nil
            self.recordingTimeLabel.isHidden = true
            self.modeControl.isEnabled = true
            self.recordingTimeLabel.textColor = .white
            self.shutterButton.backgroundColor = .clear
            self.shutterButton.layer.cornerRadius = 37
            self.shutterButton.layer.borderWidth = 5
            self.recordingTimeLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .bold)
            self.shutterInnerLayer?.isHidden = false
            self.shutterInnerLayer?.fillColor = UIColor.white.cgColor
            self.shutterInnerLayer?.path = UIBezierPath(ovalIn: self.shutterButton.bounds.insetBy(dx: 9, dy: 9)).cgPath
            guard error == nil else { self.showCameraError("影片拍攝失敗"); return }
            let filename = "VID_\(Int(Date().timeIntervalSince1970)).mov"
            let destination = self.destinationFolder.appendingPathComponent(filename)
            do {
                try FileManager.default.copyItem(at: outputFileURL, to: destination)
                let asset = AVURLAsset(url: destination)
                let durationSeconds = CMTimeGetSeconds(asset.duration)
                let durationText = durationSeconds.isFinite ? String(format:"%02d:%02d",Int(durationSeconds)/60,Int(durationSeconds)%60) : ""
                let generator = AVAssetImageGenerator(asset: asset); generator.appliesPreferredTrackTransform = true
                let frame = try? generator.copyCGImage(at: .zero, actualTime: nil)
                let thumb = frame.flatMap { UIImage(cgImage: $0).jpegData(compressionQuality: 0.72) } ?? Data()
                let size = (try? FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? NSNumber)?.intValue ?? 0
                let movieData = try Data(contentsOf: destination)
                let record: [String: Any] = [
                    "id": "camera-\(UUID().uuidString)", "filename": filename, "mediaType": "video", "source": "native-camera", "isLive": false,
                    "dataUrl": "data:image/jpeg;base64,\(thumb.base64EncodedString())", "videoUrl": "data:video/quicktime;base64,\(movieData.base64EncodedString())", "size": size, "duration": durationText,
                    "createdAt": Date().timeIntervalSince1970 * 1000, "album": "全部相片"
                ]
                self.latestPreviewURL = destination
                self.latestPreviewIsVideo = true
                self.publishCapturedRecord(record)
                self.recentThumbnailButton.setImage(UIImage(data: thumb), for: .normal)
                self.hintLabel.text = "影片已儲存至儀表板相片庫"
            } catch { self.showCameraError("無法儲存影片：\(error.localizedDescription)") }
        }
    }

    private func showCameraError(_ message: String) {
        let alert = UIAlertController(title: "相機", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }
}
