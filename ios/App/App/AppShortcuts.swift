import AppIntents
import ActivityKit
import UIKit
import ImageIO

// MARK: - App Intent: 開啟超級錢包
@available(iOS 16.0, *)
struct OpenWalletIntent: AppIntent {
    static var title: LocalizedStringResource = "開啟超級錢包"
    static var description = IntentDescription("直接開啟 Super Dashboard 並切換至數位卡夾")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
            sceneDelegate.handleDeepLink(url: URL(string: "superdashboard://wallet")!)
        }
        return .result()
    }
}

// MARK: - App Intent: 出示悠遊卡乘車
@available(iOS 16.0, *)
struct ShowTransitCardIntent: AppIntent {
    static var title: LocalizedStringResource = "出示悠遊卡乘車"
    static var description = IntentDescription("開啟 Super Dashboard 並直接出示極致黑金悠遊卡準備感應")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
            sceneDelegate.handleDeepLink(url: URL(string: "superdashboard://wallet?card=easycard")!)
        }
        return .result()
    }
}

// MARK: - App Intent: 複製第一筆速貼
@available(iOS 16.0, *)
struct CopyTopItemIntent: AppIntent {
    static var title: LocalizedStringResource = "複製第一筆常用速貼"
    static var description = IntentDescription("直接將第一筆常用速貼項目內容複製至剪貼簿")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let text = UIPasteboard.general.string ?? "三山羊長老"
        UIPasteboard.general.string = text
        return .result(value: text)
    }
}

// MARK: - App Intent: 啟動桃園捷運即時動態島
@available(iOS 16.2, *)
struct StartMetroLiveActivityIntent: AppIntent {
    static var title: LocalizedStringResource = "啟動桃園捷運即時動態島"
    static var description = IntentDescription("在 iPhone 動態島與鎖定畫面常駐桃園捷運搭乘即時進度")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        LiveActivityManager.startTaoyuanMetroActivity()
        return .result()
    }
}

// MARK: - 捷徑 AppShortcuts 提供者 (出現在 iOS「捷徑」App 中的「此 App 的動作」)
@available(iOS 16.2, *)
struct SuperDashboardShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenWalletIntent(),
            phrases: [
                "開啟 \(.applicationName) 錢包",
                "在 \(.applicationName) 打開錢包"
            ],
            shortTitle: "開啟錢包",
            systemImageName: "wallet.pass.fill"
        )
        AppShortcut(
            intent: ShowTransitCardIntent(),
            phrases: [
                "出示 \(.applicationName) 悠遊卡",
                "用 \(.applicationName) 感應乘車"
            ],
            shortTitle: "出示悠遊卡",
            systemImageName: "tram.fill"
        )
        AppShortcut(
            intent: CopyTopItemIntent(),
            phrases: [
                "複製 \(.applicationName) 第一筆速貼",
                "在 \(.applicationName) 複製常用項目"
            ],
            shortTitle: "複製速貼",
            systemImageName: "doc.on.doc.fill"
        )
        AppShortcut(
            intent: AddQuickCopyIntent(),
            phrases: [
                "在 \(.applicationName) 加入常用文字",
                "把內容記錄到 \(.applicationName) 常用文字"
            ],
            shortTitle: "加入常用文字",
            systemImageName: "square.and.pencil"
        )
        AppShortcut(
            intent: StartMetroLiveActivityIntent(),
            phrases: [
                "啟動 \(.applicationName) 捷運即時動態",
                "在 \(.applicationName) 追蹤捷運"
            ],
            shortTitle: "捷運即時動態",
            systemImageName: "airplane"
        )
    }
}

// MARK: - Live Activity 按鈕：複製常用項目（背景執行，不開啟 App）
// 與 SuperDashboardWidget/QuickCopyLiveActivity.swift 內的同名 Intent 對應，
// 系統會把動態島按鈕的動作交給主 App 行程執行。
@available(iOS 17.0, *)
struct CopyQuickItemIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "複製常用項目"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "內容")
    var text: String

    @Parameter(title: "名稱")
    var label: String

    init() {}

    init(text: String, label: String) {
        self.text = text
        self.label = label
    }

    func perform() async throws -> some IntentResult {
        await MainActor.run { UIPasteboard.general.string = text }
        if let activity = Activity<QuickCopyAttributes>.activities.first {
            var state = activity.content.state
            state.lastCopiedText = label
            state.updateTimestamp = Date().timeIntervalSince1970
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
        return .result()
    }
}

// MARK: - 動態島呈現：退回主畫面後，用「帶提醒的更新」讓動態島自動展開數秒
enum IslandPresenter {
    private final class BackgroundTaskBox {
        var id: UIBackgroundTaskIdentifier = .invalid
    }

    /// 退回主畫面。使用私有 selector，僅適用於自行簽署安裝的版本，不能上架 App Store。
    static func sendAppToBackground() {
        UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
    }

    /// 先退回主畫面，等 App 進入背景後再執行 work（通常是帶 alertConfiguration 的更新）。
    /// 過程中向系統要一小段背景執行時間，避免 App 一退到背景就被凍結而來不及更新。
    static func leaveThenRun(_ work: @escaping () async -> Void) {
        DispatchQueue.main.async {
            let box = BackgroundTaskBox()
            box.id = UIApplication.shared.beginBackgroundTask(withName: "island-expand") {
                if box.id != .invalid {
                    UIApplication.shared.endBackgroundTask(box.id)
                    box.id = .invalid
                }
            }
            sendAppToBackground()
            Task {
                try? await Task.sleep(nanoseconds: 900_000_000)
                await work()
                await MainActor.run {
                    if box.id != .invalid {
                        UIApplication.shared.endBackgroundTask(box.id)
                        box.id = .invalid
                    }
                }
            }
        }
    }
}

// MARK: - App Intent: 加入常用文字（捷徑動作：把輸入項目記錄到常用文字）
// 與「分享選單」共用同一個 App Group 收件匣（key: sharedInbox），
// 主 App 回到前景時會自動投遞到網頁端的常用項目。不需要開啟 App。
enum QuickCopyInbox {
    static let groupID = "group.com.steveplayer87.superdashboard"
    static let inboxKey = "sharedInbox"
    static let inboxFolder = "SharedInbox"

    /// 圖片縮到最長邊 800px 的 JPEG，存進共用容器，回傳檔名
    static func storeImage(_ data: Data) -> String? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID),
              let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 800
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary),
              let jpeg = UIImage(cgImage: cg).jpegData(compressionQuality: 0.8) else { return nil }
        let dir = container.appendingPathComponent(inboxFolder, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let name = UUID().uuidString + ".jpg"
        do { try jpeg.write(to: dir.appendingPathComponent(name), options: .atomic) } catch { return nil }
        return name
    }

    /// 寫入後立刻通知「已在執行的主 App」去取件。
    /// 原因：捷徑會把 App 拉到前景，sceneDidBecomeActive 常常比 perform() 寫入更早，
    /// 那時收件匣還是空的，之後就沒有人再觸發取件。
    static let darwinName = "com.steveplayer87.superdashboard.inbox-updated"
    static func notifyApp() {
        DispatchQueue.main.async { NotificationCenter.default.post(name: .quickCopyInboxUpdated, object: nil) }
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             CFNotificationName(darwinName as CFString), nil, nil, true)
    }

    static func append(_ entries: [[String: String]]) -> Bool {
        // 沒簽到 App Group 時 containerURL 會是 nil；此時寫入會落到私有的偏好檔，分享延伸讀不到，直接視為失敗並回報。
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) != nil,
              let defaults = UserDefaults(suiteName: groupID) else { return false }
        var inbox = (defaults.array(forKey: inboxKey) as? [[String: String]]) ?? []
        inbox.append(contentsOf: entries)
        defaults.set(inbox, forKey: inboxKey)
        let saved = defaults.array(forKey: inboxKey) as? [[String: String]] ?? []
        let ok = saved.count >= inbox.count && Array(saved.suffix(entries.count)) == entries
        if ok { notifyApp() }
        return ok
    }
}

@available(iOS 16.0, *)
enum AddQuickCopyError: Error, CustomLocalizedStringResourceConvertible {
    case empty
    case storageUnavailable

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .empty: return "沒有可加入的內容，請提供文字、網址或圖片"
        case .storageUnavailable: return "無法寫入共用儲存空間，請確認 App Group 已啟用"
        }
    }
}

@available(iOS 16.0, *)
struct AddQuickCopyIntent: AppIntent {
    static var title: LocalizedStringResource = "加入常用文字"
    static var description = IntentDescription("把輸入的文字、網址或圖片記錄到超級儀表板的常用文字")
    // 讓主 App 前景接收收件匣並實際寫入常用文字，而不是只停留在 App Group 暫存。
    static var openAppWhenRun: Bool = true

    static var parameterSummary: some ParameterSummary {
        Summary("將 \(\.$content) 加入常用文字") {
            \.$image
        }
    }

    // 在捷徑裡把「輸入項目」（或任何前一個動作的輸出）拖進這個欄位即可
    @Parameter(title: "內容", description: "要記錄的文字或網址")
    var content: String?

    @Parameter(title: "圖片", description: "（選填）一併記錄的圖片",
               supportedTypeIdentifiers: ["public.image"])
    var image: IntentFile?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        var entries: [[String: String]] = []

        if let text = content?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            entries.append(["kind": "text", "value": text])
        }
        if let file = image, let name = QuickCopyInbox.storeImage(file.data) {
            entries.append(["kind": "image", "value": name])
        }

        guard !entries.isEmpty else { throw AddQuickCopyError.empty }
        guard QuickCopyInbox.append(entries) else { throw AddQuickCopyError.storageUnavailable }

        return .result(dialog: "已加入 \(entries.count) 筆到常用文字")
    }
}

extension Notification.Name {
    static let quickCopyInboxUpdated = Notification.Name("quickCopyInboxUpdated")
}
