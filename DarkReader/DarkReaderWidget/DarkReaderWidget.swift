import WidgetKit
import SwiftUI

private enum WidgetSharedKeys {
    static let appGroupSuite = "group.com.darkreader.shared"
    static let eyeCareDailyRecords = "DarkReader_EyeCareDailyRecords"
    static let globalConfig = "DarkReader_GlobalConfig"
    static let themes = "DarkReader_CustomThemes"
}

private struct WidgetDailyEyeCareRecord: Codable {
    var date: Date
    var darkModeDuration: TimeInterval
    var sitesCount: Int
    var dominantThemeId: String
}

private struct WidgetGlobalConfig: Codable {
    var defaultThemeId: String
}

private struct WidgetTheme: Codable {
    var id: String
    var category: String?
    var eyeCareScore: Int?
    var warmthLevel: Int?
}

private struct EyeCareWidgetSnapshot {
    var todayDuration: TimeInterval
    var todaySitesCount: Int
    var weeklyTotalDuration: TimeInterval
    var weeklyActiveDays: Int
    var estimatedReduction: Int

    static let empty = EyeCareWidgetSnapshot(
        todayDuration: 0,
        todaySitesCount: 0,
        weeklyTotalDuration: 0,
        weeklyActiveDays: 0,
        estimatedReduction: 0
    )
}

private struct EyeCareWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: EyeCareWidgetSnapshot
}

private struct EyeCareTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> EyeCareWidgetEntry {
        EyeCareWidgetEntry(
            date: Date(),
            snapshot: EyeCareWidgetSnapshot(
                todayDuration: 2.5 * 3600,
                todaySitesCount: 8,
                weeklyTotalDuration: 12 * 3600,
                weeklyActiveDays: 4,
                estimatedReduction: 38
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (EyeCareWidgetEntry) -> Void) {
        let snapshot = EyeCareWidgetStore.loadSnapshot()
        completion(EyeCareWidgetEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EyeCareWidgetEntry>) -> Void) {
        let now = Date()
        let snapshot = EyeCareWidgetStore.loadSnapshot(at: now)
        let entry = EyeCareWidgetEntry(date: now, snapshot: snapshot)

        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: now)
            ?? now.addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

private enum EyeCareWidgetStore {
    static func loadSnapshot(at referenceDate: Date = Date()) -> EyeCareWidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: WidgetSharedKeys.appGroupSuite) else {
            return .empty
        }

        let records: [WidgetDailyEyeCareRecord]
        if let data = defaults.data(forKey: WidgetSharedKeys.eyeCareDailyRecords),
           let decoded = try? JSONDecoder().decode([WidgetDailyEyeCareRecord].self, from: data) {
            records = decoded
        } else {
            records = []
        }

        let today = Calendar.current.startOfDay(for: referenceDate)
        let todayRecord = records.first { Calendar.current.isDate($0.date, inSameDayAs: today) }

        let weekDates = (0..<7).compactMap {
            Calendar.current.date(byAdding: .day, value: -$0, to: today)
        }
        let weekRecords = weekDates.compactMap { date in
            records.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
        }

        let weeklyDuration = weekRecords.reduce(0.0) { $0 + $1.darkModeDuration }
        let weeklyActiveDays = weekRecords.filter { $0.darkModeDuration > 0 }.count

        let reduction = estimateBlueLightReduction(
            defaults: defaults,
            record: todayRecord,
            fallbackThemeId: defaultThemeId(defaults: defaults)
        )

        return EyeCareWidgetSnapshot(
            todayDuration: todayRecord?.darkModeDuration ?? 0,
            todaySitesCount: todayRecord?.sitesCount ?? 0,
            weeklyTotalDuration: weeklyDuration,
            weeklyActiveDays: weeklyActiveDays,
            estimatedReduction: reduction
        )
    }

    private static func defaultThemeId(defaults: UserDefaults) -> String {
        guard let data = defaults.data(forKey: WidgetSharedKeys.globalConfig),
              let config = try? JSONDecoder().decode(WidgetGlobalConfig.self, from: data)
        else {
            return "theme_002"
        }
        return config.defaultThemeId
    }

    private static func estimateBlueLightReduction(
        defaults: UserDefaults,
        record: WidgetDailyEyeCareRecord?,
        fallbackThemeId: String
    ) -> Int {
        guard let record, record.darkModeDuration > 0 else { return 0 }

        let effectiveThemeId = record.dominantThemeId.isEmpty ? fallbackThemeId : record.dominantThemeId
        let (eyeCareScore, warmthLevel) = themeMeta(defaults: defaults, themeId: effectiveThemeId)

        let base = 0.30 + Double(max(eyeCareScore - 1, 0)) * 0.04
        let warmBonus = warmthLevel >= 4 ? 0.10 : 0.0
        let value = min(max(base + warmBonus, 0.30), 0.60)
        return Int((value * 100).rounded())
    }

    private static func themeMeta(defaults: UserDefaults, themeId: String) -> (Int, Int) {
        if let data = defaults.data(forKey: WidgetSharedKeys.themes),
           let themes = try? JSONDecoder().decode([WidgetTheme].self, from: data),
           let theme = themes.first(where: { $0.id == themeId }) {
            return (clampScore(theme.eyeCareScore ?? 4), clampWarmth(theme.warmthLevel ?? 3))
        }

        switch themeId {
        case "theme_001": return (4, 2)
        case "theme_004": return (5, 4)
        case "theme_008": return (5, 5)
        default: return (4, 3)
        }
    }

    private static func clampScore(_ value: Int) -> Int {
        min(max(value, 1), 5)
    }

    private static func clampWarmth(_ value: Int) -> Int {
        min(max(value, 1), 5)
    }
}

private struct EyeCareWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: EyeCareTimelineProvider.Entry

    var body: some View {
        if family == .systemSmall {
            smallBody
        } else {
            mediumBody
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("今日护眼")
                .font(.system(size: 14, weight: .semibold))
            Text(formatDuration(entry.snapshot.todayDuration))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if entry.snapshot.estimatedReduction > 0 {
                Text("蓝光减少约 \(entry.snapshot.estimatedReduction)%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                Text("开启夜览后自动统计")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .widgetBackground
    }

    private var mediumBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("今日护眼")
                        .font(.system(size: 14, weight: .semibold))
                    Text(formatDuration(entry.snapshot.todayDuration))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("网站")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("\(entry.snapshot.todaySitesCount) 个")
                        .font(.system(size: 16, weight: .semibold))
                }
            }

            Divider()

            HStack {
                statChip(
                    title: "本周时长",
                    value: formatDuration(entry.snapshot.weeklyTotalDuration)
                )
                statChip(
                    title: "护眼天数",
                    value: "\(entry.snapshot.weeklyActiveDays)/7"
                )
                statChip(
                    title: "蓝光减少",
                    value: entry.snapshot.estimatedReduction > 0 ? "\(entry.snapshot.estimatedReduction)%" : "--"
                )
            }
        }
        .padding(14)
        .widgetBackground
    }

    private func statChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatDuration(_ value: TimeInterval) -> String {
        guard value > 0 else { return "0m" }
        let totalMinutes = Int(value / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

private extension View {
    @ViewBuilder
    var widgetBackground: some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(.fill.tertiary, for: .widget)
        } else {
            self
                .background(Color(UIColor.secondarySystemBackground))
        }
    }
}

struct DarkReaderWidget: Widget {
    let kind: String = "DarkReaderWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EyeCareTimelineProvider()) { entry in
            EyeCareWidgetView(entry: entry)
        }
        .configurationDisplayName("护眼统计")
        .description("展示今日护眼时长、本周趋势与蓝光减少估算。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct DarkReaderWidgetBundle: WidgetBundle {
    var body: some Widget {
        DarkReaderWidget()
    }
}
