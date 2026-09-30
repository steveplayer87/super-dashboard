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

// MARK: - Live Activity 管理器 (桃園捷運搭乘即時動態)
@available(iOS 16.2, *)
class LiveActivityManager {
    static var currentActivity: Activity<TaoyuanMetroAttributes>?

    static func startTaoyuanMetroActivity() {
        // 先結束任何舊的即時動態
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

// MARK: - Notification Manager (全域靜態管理，100% 穩定排程與彈出)
class NotificationManager {
    static func scheduleSceneNotification() {
        let center = UNUserNotificationCenter.current()
        
        let sendNotification = {
            let content = UNMutableNotificationContent()
            content.title = "場景自動感知"
            content.body = "偵測到您在 桃園捷運A18高鐵站，按此出示「極致黑金 悠遊卡」"
            content.sound = .default
            content.userInfo = ["url": "superdashboard://wallet?card=easycard"]

            // 0.2 秒後立即彈出通知
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.2, repeats: false)
            let req = UNNotificationRequest(identifier: "sceneAlert_\(UUID().uuidString)", content: content, trigger: trigger)
            
            center.add(req) { err in
                DispatchQueue.main.async {
                    if let err = err {
                        print("Error adding notification request: \(err)")
                        evaluateNotificationFeedback("通知排程失敗：\(err.localizedDescription)")
                    } else {
                        print("Scene notification successfully added!")
                        evaluateNotificationFeedback("場景感知通知已成功發送！")
                    }
                }
            }
        }

        center.getNotificationSettings { settings in
            print("Current notification authorization status: \(settings.authorizationStatus.rawValue)")
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                sendNotification()
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if granted {
                        sendNotification()
                    } else {
                        DispatchQueue.main.async {
                            evaluateNotificationFeedback("請在系統彈窗允許通知權限")
                        }
                    }
                }
            case .denied:
                DispatchQueue.main.async {
                    evaluateNotificationFeedback("通知權限遭拒，請至 iPhone「設定 > Super Dashboard > 通知」開啟允許通知")
                }
            @unknown default:
                sendNotification()
            }
        }
    }

    private static func evaluateNotificationFeedback(_ msg: String) {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = scene.windows.first?.rootViewController as? CAPBridgeViewController {
            rootVC.bridge?.webView?.evaluateJavaScript("if(typeof showToast==='function') showToast('\(msg)');", completionHandler: nil)
        }
    }
}

// MARK: - 自訂 Bridge ViewController (支援 JavaScript MessageHandler 與原生照片儲存)
class MainViewController: CAPBridgeViewController, WKScriptMessageHandler {
    override func viewDidLoad() {
        super.viewDidLoad()
        self.bridge?.webView?.configuration.userContentController.add(self, name: "startLiveActivity")
        self.bridge?.webView?.configuration.userContentController.add(self, name: "scheduleSceneNotification")
        self.bridge?.webView?.configuration.userContentController.add(self, name: "saveImageToPhotos")
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "startLiveActivity" {
            if #available(iOS 16.2, *) {
                LiveActivityManager.startTaoyuanMetroActivity()
            }
        } else if message.name == "scheduleSceneNotification" {
            NotificationManager.scheduleSceneNotification()
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

    private func handleShortcutItem(_ item: UIApplicationShortcutItem) {
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

        if urlStr.contains("schedule-notification") {
            NotificationManager.scheduleSceneNotification()
            return
        }

        // 使用 URL 參數安全編碼注入 JavaScript
        if let encoded = urlStr.addingPercentEncoding(withAllowedCharacters: .alphanumerics) {
            evaluateJS("if(typeof window.handleDeepLink==='function'){ window.handleDeepLink(decodeURIComponent('\(encoded)')); }")
        }
    }

    func scheduleSceneNotification() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            let fireNotification = {
                let content = UNMutableNotificationContent()
                content.title = "場景自動感知"
                content.body = "偵測到您在 桃園捷運A18高鐵站，按此出示「極致黑金 悠遊卡」"
                content.sound = .default
                content.userInfo = ["url": "superdashboard://wallet?card=easycard"]

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.5, repeats: false)
                let req = UNNotificationRequest(identifier: "sceneAlert_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
                center.add(req) { error in
                    if let error = error {
                        print("Failed to schedule notification: \(error)")
                    } else {
                        print("Scene notification successfully scheduled!")
                    }
                }
            }

            if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                fireNotification()
            } else {
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if granted {
                        fireNotification()
                    } else {
                        DispatchQueue.main.async {
                            self?.evaluateJS("if(typeof showToast==='function') showToast('請至 iOS 設定允許通知權限以接收場景提示');")
                        }
                    }
                }
            }
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
        if let urlStr = response.notification.request.content.userInfo["url"] as? String, let url = URL(string: urlStr) {
            handleDeepLink(url: url)
        }
        completionHandler()
    }

    private func evaluateJS(_ js: String) {
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
                print("evaluateJS: webView not found yet, retrying in 0.5s")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.evaluateJS(js)
                }
            }
        }

        if Thread.isMainThread {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: exec)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: exec)
        }
    }
}
