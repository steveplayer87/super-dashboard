import WidgetKit
import SwiftUI
import AppIntents

// MARK: - 卡片資料模型
struct WalletCardItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let value: String
    let detail: String
    let theme: CardTheme
    let type: String
    
    enum CardTheme: String {
        case boarding = "boarding"
        case gold = "gold"
        case emerald = "emerald"
        case titanium = "titanium"
        case obsidian = "obsidian"
        
        var gradient: LinearGradient {
            switch self {
            case .boarding:
                return LinearGradient(
                    colors: [Color(red: 0.07, green: 0.14, blue: 0.24), Color(red: 0.03, green: 0.07, blue: 0.12)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            case .gold:
                return LinearGradient(
                    colors: [Color(red: 0.16, green: 0.14, blue: 0.10), Color(red: 0.08, green: 0.07, blue: 0.05)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            case .emerald:
                return LinearGradient(
                    colors: [Color(red: 0.07, green: 0.15, blue: 0.11), Color(red: 0.04, green: 0.09, blue: 0.06)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            case .titanium:
                return LinearGradient(
                    colors: [Color(red: 0.15, green: 0.16, blue: 0.18), Color(red: 0.08, green: 0.09, blue: 0.10)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            case .obsidian:
                return LinearGradient(
                    colors: [Color(red: 0.10, green: 0.10, blue: 0.12), Color(red: 0.04, green: 0.04, blue: 0.05)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }
        }
        
        var accentColor: Color {
            switch self {
            case .boarding, .gold:
                return Color(red: 0.83, green: 0.69, blue: 0.22) // 香檳金
            case .emerald:
                return Color(red: 0.36, green: 0.84, blue: 0.54) // 翡翠綠
            case .titanium:
                return Color(red: 0.80, green: 0.82, blue: 0.85) // 鈦金
            case .obsidian:
                return Color(red: 0.88, green: 0.76, blue: 0.45) // 曜石金
            }
        }
    }
}

// 內建錢包卡片資料庫（涵蓋 App 中的各種卡片類型）
struct WalletCardsVault {
    static let cards: [WalletCardItem] = [
        WalletCardItem(
            id: "starlux",
            title: "STARLUX AIRLINES",
            subtitle: "JX800 · TPE ➔ NRT",
            value: "GATE B7 · SEAT 02K",
            detail: "登機時間 08:30 · 頭等商務",
            theme: .boarding,
            type: "airplane"
        ),
        WalletCardItem(
            id: "easycard",
            title: "TITANIUM EASYCARD",
            subtitle: "No. 0824-381",
            value: "NT$ 1,280",
            detail: "自動加值就緒 · 進出站模擬",
            theme: .gold,
            type: "tram.fill"
        ),
        WalletCardItem(
            id: "starbucks",
            title: "STARBUCKS COFFEE",
            subtitle: "平鎮文化門市",
            value: "叫號 #87",
            detail: "特選大杯燕麥拿鐵 · 準備中",
            theme: .emerald,
            type: "cup.and.saucer.fill"
        ),
        WalletCardItem(
            id: "citycafe",
            title: "7-ELEVEN CITY CAFE",
            subtitle: "提貨券兌換",
            value: "大杯熱拿鐵 × 5",
            detail: "OPEN POINT 條碼已同步",
            theme: .titanium,
            type: "giftcard.fill"
        ),
        WalletCardItem(
            id: "custom_credit",
            title: "SUPER PASS BLACK",
            subtitle: "•••• •••• •••• 8888",
            value: "無限黑卡 VIP",
            detail: "感應支付 · 全功能擬物",
            theme: .obsidian,
            type: "creditcard.fill"
        ),
        WalletCardItem(
            id: "custom_access",
            title: "總部智能門禁卡",
            subtitle: "SECURE ACCESS KEY",
            value: "已授權進入",
            detail: "NFC 智慧感應 · 雙重加密",
            theme: .emerald,
            type: "lock.shield.fill"
        )
    ]
    
    static func getCard(by id: String?) -> WalletCardItem {
        guard let id = id else { return cards[0] }
        return cards.first(where: { $0.id == id }) ?? cards[0]
    }
}

// MARK: - App Intent 配置支援（長按小工具可直接更換展示卡片）
struct CardEntity: AppEntity {
    let id: String
    let name: String
    let subtitle: String
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "展示卡片"
    static var defaultQuery = CardQuery()
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(subtitle)")
    }
}

struct CardQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [CardEntity] {
        return WalletCardsVault.cards
            .filter { identifiers.contains($0.id) }
            .map { CardEntity(id: $0.id, name: $0.title, subtitle: $0.subtitle) }
    }
    
    func suggestedEntities() async throws -> [CardEntity] {
        return WalletCardsVault.cards.map { CardEntity(id: $0.id, name: $0.title, subtitle: $0.subtitle) }
    }
    
    func defaultResult() async -> CardEntity? {
        if let first = WalletCardsVault.cards.first {
            return CardEntity(id: first.id, name: first.title, subtitle: first.subtitle)
        }
        return nil
    }
}

struct SelectCardIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "選擇展示卡片"
    static var description = IntentDescription("選擇您要在桌面小工具中常駐展示的超級錢包卡片。")
    
    @Parameter(title: "展示卡片")
    var card: CardEntity?
}

// MARK: - Timeline Provider
struct SimpleCardEntry: TimelineEntry {
    let date: Date
    let selectedCard: WalletCardItem
}

struct SuperDashboardTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = SimpleCardEntry
    typealias Intent = SelectCardIntent

    func placeholder(in context: Context) -> SimpleCardEntry {
        SimpleCardEntry(date: Date(), selectedCard: WalletCardsVault.cards[0])
    }

    func snapshot(for configuration: SelectCardIntent, in context: Context) async -> SimpleCardEntry {
        let card = WalletCardsVault.getCard(by: configuration.card?.id)
        return SimpleCardEntry(date: Date(), selectedCard: card)
    }

    func timeline(for configuration: SelectCardIntent, in context: Context) async -> Timeline<SimpleCardEntry> {
        let card = WalletCardsVault.getCard(by: configuration.card?.id)
        let entry = SimpleCardEntry(date: Date(), selectedCard: card)
        return Timeline(entries: [entry], policy: .never)
    }
}

// MARK: - Widget View
struct SuperDashboardWidgetEntryView : View {
    var entry: SuperDashboardTimelineProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        let card = entry.selectedCard
        
        ZStack {
            card.theme.gradient
            
            // 擬真金屬高光與邊框
            RoundedRectangle(cornerRadius: 16)
                .stroke(card.theme.accentColor.opacity(0.35), lineWidth: 1)
            
            VStack(alignment: .leading, spacing: 0) {
                // 頂部品牌與類型圖示
                HStack(alignment: .center) {
                    Label(card.title, systemImage: card.type)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(card.theme.accentColor)
                    
                    Spacer()
                    
                    // 擬真晶片圖標
                    RoundedRectangle(cornerRadius: 3)
                        .fill(card.theme.accentColor.opacity(0.85))
                        .frame(width: 18, height: 13)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.black.opacity(0.4), lineWidth: 0.5)
                        )
                }
                
                Spacer()
                
                // 次標題 / 編號
                Text(card.subtitle)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.65))
                
                // 主要資訊 / 餘額 / 叫號
                Text(card.value)
                    .font(.system(size: family == .systemSmall ? 17 : 20, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 2)
                
                // 底部說明文字
                if family != .systemSmall {
                    Text(card.detail)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(card.theme.accentColor.opacity(0.9))
                        .padding(.top, 4)
                }
            }
            .padding(14)
        }
        .containerBackground(for: .widget) {
            Color.black
        }
    }
}

// MARK: - Widget 定義
struct SuperDashboardWidget: Widget {
    let kind: String = "SuperDashboardWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectCardIntent.self, provider: SuperDashboardTimelineProvider()) { entry in
            SuperDashboardWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("超級錢包卡夾")
        .description("在 iPhone 桌面展示您的專屬卡片。長按小工具點選「編輯小工具」即可隨意切換展示的卡片！")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
