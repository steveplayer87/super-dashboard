import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents
import UIKit

// MARK: - 複製動作（點動態島 / 鎖定螢幕按鈕時執行，不開啟 App）
// LiveActivityIntent 會交給主 App 的行程在背景執行；主 App 端 (AppShortcuts.swift) 有同名實作。
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

private enum QuickCopyStyle {
    static let teal = Color(red: 0.25, green: 0.66, blue: 0.64)
    static let gold = Color(red: 0.94, green: 0.77, blue: 0.38)
    static let cardBg = Color(red: 0.08, green: 0.09, blue: 0.11)
    static let maxItems = 6
    static let columns = 3
}

// 兩排、每排三格的可複製項目（最多 6 個）
private struct QuickCopyGrid: View {
    let items: [QuickCopyItemData]
    let chipHeight: CGFloat

    private var rows: [[QuickCopyItemData]] {
        let capped = Array(items.prefix(QuickCopyStyle.maxItems))
        return stride(from: 0, to: capped.count, by: QuickCopyStyle.columns).map {
            Array(capped[$0..<min($0 + QuickCopyStyle.columns, capped.count)])
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 6) {
                    ForEach(rows[r], id: \.id) { item in
                        Button(intent: CopyQuickItemIntent(text: item.text, label: item.label)) {
                            HStack(spacing: 4) {
                                Image(systemName: item.isLink ? "link" : "doc.on.clipboard.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(item.isLink ? QuickCopyStyle.gold : QuickCopyStyle.teal)
                                Text(item.label)
                                    .font(.system(size: 11, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity, minHeight: chipHeight)
                            .padding(.horizontal, 6)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(9)
                        }
                        .buttonStyle(.plain)
                    }
                    // 不足三格時補空位，讓每格寬度一致
                    ForEach(0..<(QuickCopyStyle.columns - rows[r].count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, minHeight: 1, maxHeight: 1)
                    }
                }
            }
        }
    }
}

struct QuickCopyLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: QuickCopyAttributes.self) { context in
            // Lock Screen 鎖定螢幕橫幅
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "doc.on.doc.fill")
                        .foregroundColor(QuickCopyStyle.teal)
                        .font(.system(size: 13))
                    Text("Super Dashboard · 常用項目")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    if let copied = context.state.lastCopiedText {
                        Text("已複製「\(copied.prefix(8))」")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(QuickCopyStyle.gold)
                    }
                }
                QuickCopyGrid(items: context.state.items, chipHeight: 30)
            }
            .padding(14)
            .background(QuickCopyStyle.cardBg)
            .widgetURL(URL(string: "superdashboard://dashboard"))
        } dynamicIsland: { context in
            DynamicIsland {
                // 展開態 Expanded
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 12))
                            .foregroundColor(QuickCopyStyle.teal)
                        Text("常用速貼")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.leading, 6)
                    .padding(.top, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if let copied = context.state.lastCopiedText {
                        Text("已複製「\(copied.prefix(6))」")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(QuickCopyStyle.gold)
                            .padding(.trailing, 6)
                            .padding(.top, 4)
                    } else {
                        Text("點擊即複製")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.6))
                            .padding(.trailing, 6)
                            .padding(.top, 4)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    // 兩排格子；明確給最小高度，讓動態島展開到足夠高並避開底部圓角
                    QuickCopyGrid(items: context.state.items, chipHeight: 32)
                        .padding(.horizontal, 4)
                        .padding(.top, 6)
                        .padding(.bottom, 12)
                        .frame(minHeight: 88)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 10))
                        .foregroundColor(QuickCopyStyle.teal)
                    Text("速貼")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.white)
                }
                .padding(.leading, 4)
            } compactTrailing: {
                Text("\(min(context.state.items.count, QuickCopyStyle.maxItems))項")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundColor(QuickCopyStyle.gold)
                    .padding(.trailing, 4)
            } minimal: {
                Image(systemName: "doc.on.doc.fill")
                    .foregroundColor(QuickCopyStyle.teal)
            }
            .widgetURL(URL(string: "superdashboard://dashboard"))
            .keylineTint(QuickCopyStyle.teal)
        }
    }
}
