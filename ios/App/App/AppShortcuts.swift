import AppIntents
import UIKit

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
