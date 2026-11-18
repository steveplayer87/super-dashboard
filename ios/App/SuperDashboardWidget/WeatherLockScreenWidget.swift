import SwiftUI
import WidgetKit

private struct WeatherEntry: TimelineEntry {
    let date: Date
    let temperature: String
    let weather: String
    let rainProbability: Int
    let updatedAt: Date?

    var lunarDate: String {
        var calendar = Calendar(identifier: .chinese)
        calendar.timeZone = .current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.calendar = calendar
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    var symbol: String {
        if rainProbability >= 35 || weather.contains("雨") || weather.contains("雷") { return "cloud.rain.fill" }
        if weather.contains("晴") { return "sun.max.fill" }
        if weather.contains("陰") { return "cloud.fill" }
        return "cloud.sun.fill"
    }
}

private struct WeatherProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeatherEntry {
        WeatherEntry(date: .now, temperature: "--°", weather: "多雲", rainProbability: 0, updatedAt: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> Void) { completion(load()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        let entry = load()
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30 * 60))))
    }
    private func load() -> WeatherEntry {
        let defaults = UserDefaults(suiteName: "group.com.steveplayer87.superdashboard")
        let temp = defaults?.string(forKey: "cwaTemperature") ?? "--"
        let weather = defaults?.string(forKey: "cwaWeather") ?? "多雲"
        let rain = defaults?.integer(forKey: "cwaRainProbability") ?? 0
        let updated = defaults?.double(forKey: "cwaUpdatedAt") ?? 0
        return WeatherEntry(date: .now, temperature: temp, weather: weather, rainProbability: rain, updatedAt: updated > 0 ? Date(timeIntervalSince1970: updated) : nil)
    }
}

private struct WeatherRectangularView: View {
    let entry: WeatherEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Text(entry.date.formatted(.dateTime.day())).font(.system(size: 15, weight: .bold, design: .rounded)).lineLimit(1)
                Text(entry.date.formatted(.dateTime.weekday(.abbreviated))).font(.system(size: 11, weight: .medium)).lineLimit(1)
                Spacer(minLength: 2)
                Image(systemName: entry.symbol).symbolRenderingMode(.multicolor).font(.system(size: 14))
                Text(entry.temperature == "--" ? "--°C" : "\(entry.temperature)°C").font(.system(size: 12, weight: .semibold, design: .rounded)).lineLimit(1)
            }
            HStack(spacing: 4) {
                Text(entry.lunarDate).font(.system(size: 11, weight: .medium)).lineLimit(1)
                Spacer(minLength: 0)
                Text(entry.weather).font(.system(size: 9, weight: .regular)).lineLimit(1)
            }
            .foregroundStyle(.secondary)
        }
        .minimumScaleFactor(0.75)
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct WeatherLockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WeatherLockScreenWidget", provider: WeatherProvider()) { entry in
            WeatherRectangularView(entry: entry)
        }
        .configurationDisplayName("日期與天氣")
        .description("顯示日期、農曆與台北天氣。")
        .supportedFamilies([.accessoryRectangular])
    }
}
