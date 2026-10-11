import UIKit
import Capacitor
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 設定通知中心代理
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        // 註冊自訂互動式通知分類（長按選項、文字即時回覆）
        NotificationManager.setupCategories()
        
        // 請求通知權限
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("Notification permission granted: \(granted), error: \(String(describing: error))")
        }
        return true
    }

    // 前台展示推播通知（在 App 內時依然彈出頂部橫幅、聲音與角標）
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge, .list])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    // 點擊通知橫幅或互動式操作按鈕時的處理
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let actionId = response.actionIdentifier
        print("userNotificationCenter didReceive action: \(actionId)")

        if actionId == "ACTION_OPEN_CARD" {
            DispatchQueue.main.async {
                if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
                    sceneDelegate.handleDeepLink(url: URL(string: "superdashboard://wallet?card=easycard")!)
                }
            }
        } else if actionId == "ACTION_OPEN_WALLET" {
            DispatchQueue.main.async {
                if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
                    sceneDelegate.handleDeepLink(url: URL(string: "superdashboard://wallet")!)
                }
            }
        } else if actionId == "ACTION_REPLY", let textResponse = response as? UNTextInputNotificationResponse {
            let replyText = textResponse.userText
            print("Received inline notification reply: \(replyText)")
            DispatchQueue.main.async {
                NotificationManager.evaluateNotificationFeedback("收到通知回覆：「\(replyText)」")
                if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
                    let escaped = replyText.replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\n", with: " ")
                    sceneDelegate.evaluateJS("if(typeof window.onNotificationReply==='function'){ window.onNotificationReply('\(escaped)'); }")
                }
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
    func applicationWillEnterForeground(_ application: UIApplication) {}
    func applicationDidBecomeActive(_ application: UIApplication) {}
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
