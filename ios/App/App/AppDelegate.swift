import UIKit
import Capacitor
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 設定通知中心代理為 AppDelegate
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        // 註冊自訂互動式通知分類（長按選項、文字即時回覆）
        NotificationManager.setupCategories()
        
        // 請求通知權限
        if !ProcessInfo.processInfo.arguments.contains("--no-prompt") {
            center.requestAuthorization(options: [.alert, .sound, .badge, .provisional]) { granted, error in
                print("[Notification] Notification permission granted: \(granted), error: \(String(describing: error))")
                NotificationManager.checkAndReportStatus()
                InstallationExpiryReminder.scheduleIfNeeded()
            }
        }
        return true
    }

    // 前台展示推播通知（在 App 內時依然彈出頂部橫幅、聲音與角標）
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("[Notification] AppDelegate willPresent called for: \(notification.request.identifier)")
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    // 點擊通知橫幅或互動式操作按鈕時的處理
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let actionId = response.actionIdentifier
        print("[Notification] userNotificationCenter didReceive action: \(actionId)")

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
        } else if let urlStr = response.notification.request.content.userInfo["url"] as? String, let url = URL(string: urlStr) {
            DispatchQueue.main.async {
                if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
                    sceneDelegate.handleDeepLink(url: url)
                }
            }
        }
        
        completionHandler()
    }

    func applicationWillResignActive(_ application: UIApplication) {}
    func applicationDidEnterBackground(_ application: UIApplication) {}
    func applicationWillEnterForeground(_ application: UIApplication) {
        NotificationManager.checkAndReportStatus()
        InstallationExpiryReminder.scheduleIfNeeded()
    }
    func applicationDidBecomeActive(_ application: UIApplication) {
        application.applicationIconBadgeNumber = 0
        NotificationManager.checkAndReportStatus()
        InstallationExpiryReminder.scheduleIfNeeded()
    }
    func applicationWillTerminate(_ application: UIApplication) {}

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration",
                                          sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}


/// 全新安裝後 6.5 天提醒重新安裝，避開 7 天開發簽章到期前最後半天。
/// UserDefaults 隨 App 刪除而清除，因此完整刪除再安裝會重新計時；一般更新不會重設。
enum InstallationExpiryReminder {
    private static let requestID = "superdashboard.install-expiry-6-5-days"
    private static let scheduledKey = "superdashboard.install-expiry-reminder-scheduled"

    static func scheduleIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: scheduledKey) else { return }

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized ||
                  settings.authorizationStatus == .provisional ||
                  settings.authorizationStatus == .ephemeral else { return }

            let content = UNMutableNotificationContent()
            content.title = "超級儀表板重裝提醒"
            content.body = "再不重裝就要過期了"
            content.sound = .default

            // 6 天 12 小時 = 561,600 秒
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 561600, repeats: false)
            let request = UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)
            center.add(request) { error in
                if let error = error {
                    print("[InstallExpiry] Failed to schedule: \(error.localizedDescription)")
                } else {
                    defaults.set(true, forKey: scheduledKey)
                    print("[InstallExpiry] Reminder scheduled for 6.5 days after install.")
                }
            }
        }
    }
}
