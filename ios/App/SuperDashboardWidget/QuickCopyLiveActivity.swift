import ActivityKit
import WidgetKit
import SwiftUI

struct QuickCopyLiveActivity: Widget {
    let tealGlow = Color(red: 0.25, green: 0.66, blue: 0.64)
    let darkCardBg = Color(red: 0.08, green: 0.09, blue: 0.11)
    let goldAccent = Color(red: 0.94, green: 0.77, blue: 0.38)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: QuickCopyAttributes.self) { context in
            // Lock Screen 鎖定螢幕橫幅通知
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "doc.on.doc.fill")
                        .foregroundColor(tealGlow)
                        .font(.system(size: 13))
                    Text("Super Dashboard · 前五常用項目")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    if let copied = context.state.lastCopiedText {
                        Text("已複製: \(copied.prefix(8))...")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(goldAccent)
                    }
                }
                
                HStack(spacing: 6) {
                    ForEach(context.state.items.prefix(5), id: \.id) { item in
                        Link(destination: URL(string: "superdashboard://copy?text=\(item.text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!) {
                            VStack(spacing: 2) {
                                Image(systemName: item.isLink ? "link" : "text.bubble.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(item.isLink ? goldAccent : tealGlow)
                                Text(item.label)
                                    .font(.system(size: 10, weight: .medium))
                                    .lineLimit(1)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .padding(14)
            .background(darkCardBg)
            .widgetURL(URL(string: "superdashboard://dashboard"))
        } dynamicIsland: { context in
            DynamicIsland {
                // 展開態 Expanded
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 12))
                            .foregroundColor(tealGlow)
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
                            .foregroundColor(goldAccent)
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
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            ForEach(context.state.items.prefix(5), id: \.id) { item in
                                Link(destination: URL(string: "superdashboard://copy?text=\(item.text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!) {
                                    HStack(spacing: 4) {
                                        Image(systemName: item.isLink ? "link" : "doc.on.clipboard.fill")
                                            .font(.system(size: 9))
                                            .foregroundColor(item.isLink ? goldAccent : tealGlow)
                                        Text(item.label)
                                            .font(.system(size: 11, weight: .semibold))
                                            .lineLimit(1)
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 7)
                                    .background(Color.white.opacity(0.12))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 6)
                    .padding(.bottom, 6)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 10))
                        .foregroundColor(tealGlow)
                    Text("速貼")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.white)
                }
                .padding(.leading, 4)
            } compactTrailing: {
                Text("\(min(context.state.items.count, 5))項")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundColor(goldAccent)
                    .padding(.trailing, 4)
            } minimal: {
                Image(systemName: "doc.on.doc.fill")
                    .foregroundColor(tealGlow)
            }
            .widgetURL(URL(string: "superdashboard://dashboard"))
            .keylineTint(tealGlow)
        }
    }
}
