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
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("[Notification] Notification permission granted: \(granted), error: \(String(describing: error))")
            NotificationManager.checkAndReportStatus()
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
                NotificationManager.evaluateJS("if(typeof window.navigateToWallet==='function') window.navigateToWallet('悠遊卡');")
            }
        } else if actionId == "ACTION_OPEN_WALLET" {
            DispatchQueue.main.async {
                NotificationManager.evaluateJS("if(typeof window.navigateToWallet==='function') window.navigateToWallet();")
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
    }
    func applicationDidBecomeActive(_ application: UIApplication) {
        NotificationManager.checkAndReportStatus()
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
