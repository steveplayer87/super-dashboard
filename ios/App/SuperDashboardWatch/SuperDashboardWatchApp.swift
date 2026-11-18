import SwiftUI
import WatchConnectivity
import WatchKit
import ImageIO
import CoreGraphics

struct WatchWalletCard: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var code: String
    var format: String
    var image: String?
}

@MainActor
final class WatchWalletStore: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchWalletStore()
    @Published private(set) var cards: [WatchWalletCard] = []

    private override init() {
        super.init()
        cards = (try? JSONDecoder().decode([WatchWalletCard].self, from: UserDefaults.standard.data(forKey: "walletCards") ?? Data())) ?? []
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo["cards"] as? Data,
              let cards = try? JSONDecoder().decode([WatchWalletCard].self, from: data) else { return }
        Task { @MainActor in
            self.cards = cards
            UserDefaults.standard.set(data, forKey: "walletCards")
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
}

@main
struct SuperDashboardWatchApp: App {
    @StateObject private var wallet = WatchWalletStore.shared

    var body: some Scene {
        WindowGroup {
            TabView {
                WatchWalletView().environmentObject(wallet)
                WatchPetView()
            }
            .tabViewStyle(.verticalPage)
        }
    }
}

private struct WatchWalletView: View {
    @EnvironmentObject private var wallet: WatchWalletStore
    @State private var selected: WatchWalletCard?

    var body: some View {
        NavigationStack {
            Group {
                if wallet.cards.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "wallet.pass.fill").font(.system(size: 30)).foregroundStyle(.teal)
                        Text("尚無同步票卡").font(.headline)
                        Text("在 iPhone 開啟錢包即可同步")
                            .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }.padding()
                } else {
                    List(wallet.cards) { card in
                        Button { selected = card } label: {
                            HStack {
                                Image(systemName: card.format == "qr" ? "qrcode" : "barcode")
                                    .foregroundStyle(.teal)
                                Text(card.name).lineLimit(1)
                            }
                        }
                    }
                }
            }
            .navigationTitle("超級錢包")
            .sheet(item: $selected) { card in WatchBarcodeView(card: card) }
        }
    }
}

private struct WatchBarcodeView: View {
    let card: WatchWalletCard

    var body: some View {
        VStack(spacing: 8) {
            Text(card.name).font(.headline).lineLimit(1)
            if let image = barcodeImage {
                Image(decorative: image, scale: 1).interpolation(.none).resizable().scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 105).padding(6).background(.white).clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: card.format == "qr" ? "qrcode" : "barcode")
                    .font(.system(size: 48, weight: .medium)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 82).background(.white).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Text(card.code).font(.system(size: 9, design: .monospaced)).lineLimit(1).foregroundStyle(.secondary)
        }.padding(10)
    }

    private var barcodeImage: CGImage? {
        guard let encoded = card.image, let data = Data(base64Encoded: encoded),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

private struct WatchPetView: View {
    @State private var taps = 0
    @State private var mood = "陪你一下"
    private let moods = ["陪你一下", "再點我看看", "我有精神了", "今天也加油"]

    var body: some View {
        VStack(spacing: 8) {
            Text("阿鵝夥伴").font(.headline)
            Button {
                taps += 1
                mood = moods[taps % moods.count]
                WKInterfaceDevice.current().play(.click)
            } label: {
                Text(taps.isMultiple(of: 3) ? "🦕" : "🪿").font(.system(size: 52))
            }.buttonStyle(.plain)
            Text(mood).font(.caption).foregroundStyle(.secondary)
            Text("互動 (taps) 次").font(.system(size: 10, design: .rounded)).foregroundStyle(.teal)
        }
    }
}
