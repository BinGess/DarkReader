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
    var darkShieldPoints: Int

    static let empty = EyeCareWidgetSnapshot(
        todayDuration: 0,
        todaySitesCount: 0,
        weeklyTotalDuration: 0,
        weeklyActiveDays: 0,
        darkShieldPoints: 0
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
                darkShieldPoints: 380
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

        let darkShieldPoints = estimateDarkShieldPoints(
            defaults: defaults,
            record: todayRecord,
            fallbackThemeId: defaultThemeId(defaults: defaults)
        )

        return EyeCareWidgetSnapshot(
            todayDuration: todayRecord?.darkModeDuration ?? 0,
            todaySitesCount: todayRecord?.sitesCount ?? 0,
            weeklyTotalDuration: weeklyDuration,
            weeklyActiveDays: weeklyActiveDays,
            darkShieldPoints: darkShieldPoints
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

    private static func estimateDarkShieldPoints(
        defaults: UserDefaults,
        record: WidgetDailyEyeCareRecord?,
        fallbackThemeId: String
    ) -> Int {
        guard let record, record.darkModeDuration > 0 else { return 0 }

        let effectiveThemeId = record.dominantThemeId.isEmpty ? fallbackThemeId : record.dominantThemeId
        let (eyeCareScore, warmthLevel) = themeMeta(defaults: defaults, themeId: effectiveThemeId)

        let base = 0.30 + Double(max(eyeCareScore - 1, 0)) * 0.04
        let warmBonus = warmthLevel >= 4 ? 0.10 : 0.0
        let reductionRatio = min(max(base + warmBonus, 0.30), 0.60)
        let weightedHours = (record.darkModeDuration / 3600) * reductionRatio
        return max(Int((weightedHours * 1000).rounded()), 0)
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

private extension Color {
    init(rgb: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

private enum WidgetPalette {
    static let primary = Color(rgb: 0xF59E0B)
    static let cta = Color(rgb: 0x8B5CF6)
    static let info = Color(rgb: 0x38BDF8)

    static func backgroundTop(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(rgb: 0x0B1020) : Color(rgb: 0xF8FAFC)
    }

    static func backgroundBottom(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(rgb: 0x141B34) : Color(rgb: 0xE2E8F0)
    }

    static func elevated(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }

    static func title(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(rgb: 0xF8FAFC) : Color(rgb: 0x0F172A)
    }

    static func body(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(rgb: 0xCBD5E1) : Color(rgb: 0x475569)
    }
}

private enum WidgetTypography {
    static let title = Font.system(size: 13, weight: .semibold, design: .rounded)
    static let metric = Font.system(size: 26, weight: .bold, design: .rounded)
    static let subtitle = Font.system(size: 12, weight: .medium, design: .rounded)
    static let statTitle = Font.system(size: 11, weight: .medium, design: .rounded)
    static let statValue = Font.system(size: 14, weight: .semibold, design: .rounded)
}

private struct WidgetSurfaceBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    WidgetPalette.backgroundTop(colorScheme),
                    WidgetPalette.backgroundBottom(colorScheme)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(WidgetPalette.primary.opacity(colorScheme == .dark ? 0.16 : 0.2))
                .frame(width: 180)
                .blur(radius: 18)
                .offset(x: -86, y: -90)

            Circle()
                .fill(WidgetPalette.cta.opacity(colorScheme == .dark ? 0.14 : 0.16))
                .frame(width: 160)
                .blur(radius: 16)
                .offset(x: 96, y: 90)

            Circle()
                .fill(WidgetPalette.info.opacity(colorScheme == .dark ? 0.08 : 0.1))
                .frame(width: 120)
                .blur(radius: 14)
                .offset(x: 70, y: -72)
        }
    }
}

private struct EyeCareWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    var entry: EyeCareTimelineProvider.Entry

    var body: some View {
        if family == .systemSmall {
            smallBody
        } else {
            mediumBody
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(WidgetPalette.primary)
                Text("今日护眼")
                    .font(WidgetTypography.title)
                    .foregroundColor(WidgetPalette.title(colorScheme))
                Spacer(minLength: 0)
            }

            Text(formatDuration(entry.snapshot.todayDuration))
                .font(WidgetTypography.metric)
                .foregroundColor(WidgetPalette.title(colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(darkShieldDescription)
                .font(WidgetTypography.subtitle)
                .foregroundColor(WidgetPalette.body(colorScheme))
                .lineLimit(1)

            HStack(spacing: 8) {
                compactStat(title: "网站", value: "\(entry.snapshot.todaySitesCount)")
                compactStat(title: "活跃", value: "\(entry.snapshot.weeklyActiveDays)/7")
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .widgetBackground
    }

    private var mediumBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("今日护眼")
                        .font(WidgetTypography.title)
                        .foregroundColor(WidgetPalette.title(colorScheme))
                    Text(formatDuration(entry.snapshot.todayDuration))
                        .font(WidgetTypography.metric)
                        .foregroundColor(WidgetPalette.title(colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Spacer()
                accentPill(
                    icon: "globe",
                    text: "\(entry.snapshot.todaySitesCount) 个网站",
                    tint: WidgetPalette.info
                )
            }

            Text(darkShieldDescription)
                .font(WidgetTypography.subtitle)
                .foregroundColor(WidgetPalette.body(colorScheme))
                .lineLimit(1)

            HStack(spacing: 8) {
                statChip(
                    title: "本周时长",
                    value: formatDuration(entry.snapshot.weeklyTotalDuration),
                    icon: "clock.fill",
                    tint: WidgetPalette.primary
                )
                statChip(
                    title: "护眼天数",
                    value: "\(entry.snapshot.weeklyActiveDays)/7",
                    icon: "calendar",
                    tint: WidgetPalette.cta
                )
                statChip(
                    title: "暗色保护分",
                    value: entry.snapshot.darkShieldPoints > 0 ? "\(entry.snapshot.darkShieldPoints) 点" : "--",
                    icon: "sun.max.trianglebadge.exclamationmark",
                    tint: WidgetPalette.info
                )
            }
        }
        .padding(14)
        .widgetBackground
    }

    private var darkShieldDescription: String {
        entry.snapshot.darkShieldPoints > 0
            ? "今日暗色保护指数 \(entry.snapshot.darkShieldPoints) 点"
            : "开启夜览后自动统计"
    }

    private func compactStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(WidgetTypography.statTitle)
                .foregroundColor(WidgetPalette.body(colorScheme))
            Text(value)
                .font(WidgetTypography.statValue)
                .foregroundColor(WidgetPalette.title(colorScheme))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .background(WidgetPalette.elevated(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func accentPill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(WidgetTypography.subtitle)
                .lineLimit(1)
        }
        .foregroundColor(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tint.opacity(colorScheme == .dark ? 0.2 : 0.14))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.45), lineWidth: 0.8)
        )
    }

    private func statChip(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(WidgetTypography.statTitle)
                    .lineLimit(1)
            }
            .foregroundColor(WidgetPalette.body(colorScheme))
            .frame(maxWidth: .infinity, alignment: .center)
            Text(value)
                .font(WidgetTypography.statValue)
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(WidgetPalette.elevated(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
            self.containerBackground(for: .widget) {
                WidgetSurfaceBackground()
            }
        } else {
            self
                .background(WidgetSurfaceBackground())
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
        .description("展示今日护眼时长、本周趋势与暗色保护指数。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct DarkReaderWidgetBundle: WidgetBundle {
    var body: some Widget {
        DarkReaderWidget()
    }
}
