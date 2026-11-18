import SwiftUI
import WidgetKit

private struct ShowcaseEntry: TimelineEntry {
    let date: Date
    let slogan: String
    let image: UIImage?
}

private struct ShowcaseProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShowcaseEntry {
        ShowcaseEntry(date: .now, slogan: "把喜歡的日常放在眼前", image: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ShowcaseEntry) -> Void) {
        completion(load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShowcaseEntry>) -> Void) {
        completion(Timeline(entries: [load()], policy: .never))
    }

    private func load() -> ShowcaseEntry {
        let defaults = UserDefaults(suiteName: "group.com.steveplayer87.superdashboard")
        let slogan = defaults?.string(forKey: "homeWidgetSlogan") ?? "把喜歡的日常放在眼前"
        var image: UIImage?
        if let raw = defaults?.string(forKey: "homeWidgetImage"),
           let payload = raw.components(separatedBy: ",").last,
           let data = Data(base64Encoded: payload) {
            image = UIImage(data: data)
        }
        return ShowcaseEntry(date: .now, slogan: slogan, image: image)
    }
}

private struct ShowcaseView: View {
    let entry: ShowcaseEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [Color(red: 0.12, green: 0.11, blue: 0.09), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
            if let image = entry.image {
                Image(uiImage: image).resizable().scaledToFill().frame(maxWidth: .infinity, maxHeight: .infinity).clipped().overlay(Color.black.opacity(0.3))
            }
            VStack(alignment: .leading, spacing: 8) {
                Label("SUPER DASHBOARD", systemImage: "sparkles").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(Color(red: 0.94, green: 0.68, blue: 0.3))
                Spacer(minLength: 0)
                Text(entry.slogan.isEmpty ? "把喜歡的日常放在眼前" : entry.slogan)
                    .font(.system(size: family == .systemSmall ? 17 : 21, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white).lineLimit(family == .systemSmall ? 3 : 2).minimumScaleFactor(0.75)
            }.padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .containerBackground(for: .widget) { Color.black }
    }
}

struct SuperDashboardShowcaseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SuperDashboardShowcaseWidget", provider: ShowcaseProvider()) { entry in
            ShowcaseView(entry: entry)
        }
        .configurationDisplayName("超級儀表板展示")
        .description("展示自訂標語與圖片。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
