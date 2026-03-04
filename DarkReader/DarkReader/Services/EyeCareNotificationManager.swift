import Foundation
import UserNotifications
import Combine

@MainActor
final class EyeCareNotificationManager: ObservableObject {
    static let dailyIdentifier = "darkreader.eyecare.daily"
    static let weeklyIdentifier = "darkreader.eyecare.weekly"

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center: UNUserNotificationCenter
    private let dataManager: SharedDataManager
    private var cancellables = Set<AnyCancellable>()
    private var hasStarted = false

    init(dataManager: SharedDataManager, center: UNUserNotificationCenter = .current()) {
        self.dataManager = dataManager
        self.center = center
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        dataManager.$globalConfig
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.syncSchedule()
            }
            .store(in: &cancellables)

        syncSchedule()
    }

    func syncSchedule() {
        Task {
            await syncScheduleInternal()
        }
    }

    private func syncScheduleInternal() async {
        let config = dataManager.globalConfig
        let shouldSchedule = config.dailyEyeCareNotificationEnabled || config.weeklyEyeCareNotificationEnabled

        if !shouldSchedule {
            center.removePendingNotificationRequests(withIdentifiers: [Self.dailyIdentifier, Self.weeklyIdentifier])
            center.removeDeliveredNotifications(withIdentifiers: [Self.dailyIdentifier, Self.weeklyIdentifier])
            authorizationStatus = await fetchAuthorizationStatus()
            return
        }

        var status = await fetchAuthorizationStatus()
        if status == .notDetermined {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            status = await fetchAuthorizationStatus()
            if !granted {
                disableReportNotifications()
                return
            }
        }

        authorizationStatus = status
        guard status == .authorized || status == .provisional || status == .ephemeral else {
            disableReportNotifications()
            return
        }

        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyIdentifier, Self.weeklyIdentifier])

        if config.dailyEyeCareNotificationEnabled {
            let request = buildDailyRequest(config: config)
            await addRequest(request)
        }

        if config.weeklyEyeCareNotificationEnabled {
            let request = buildWeeklyRequest(config: config)
            await addRequest(request)
        }
    }

    private func disableReportNotifications() {
        guard dataManager.globalConfig.dailyEyeCareNotificationEnabled || dataManager.globalConfig.weeklyEyeCareNotificationEnabled else {
            return
        }
        dataManager.globalConfig.dailyEyeCareNotificationEnabled = false
        dataManager.globalConfig.weeklyEyeCareNotificationEnabled = false
        dataManager.saveConfig()
    }

    private func buildDailyRequest(config: GlobalConfig) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "每日护眼报告"

        let today = dataManager.todayEyeCareRecord
        if today.darkModeDuration > 0 {
            let reduction = Int(dataManager.estimatedBlueLightReduction(for: today) * 100)
            content.body = "今日已护眼 \(formatDuration(today.darkModeDuration))，蓝光减少估算约 \(reduction)%。点开查看完整报告。"
        } else {
            content.body = "今天还没有护眼数据，开启夜览后会自动累计统计。"
        }

        content.sound = .default
        content.userInfo = ["route": "dashboard"]

        var components = DateComponents()
        components.hour = config.dailyEyeCareNotificationHour
        components.minute = config.dailyEyeCareNotificationMinute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        return UNNotificationRequest(identifier: Self.dailyIdentifier, content: content, trigger: trigger)
    }

    private func buildWeeklyRequest(config: GlobalConfig) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "每周护眼报告"

        let weekRecords = dataManager.currentWeekEyeCareRecords
        let activeDays = weekRecords.filter { $0.darkModeDuration > 0 }.count
        let totalDuration = weekRecords.reduce(0) { $0 + $1.darkModeDuration }

        if totalDuration > 0 {
            content.body = "本周护眼 \(activeDays)/7 天，总时长 \(formatDuration(totalDuration))。继续保持好习惯。"
        } else {
            content.body = "本周还没有护眼记录，今晚开始自动护眼吧。"
        }

        content.sound = .default
        content.userInfo = ["route": "dashboard"]

        var components = DateComponents()
        components.weekday = config.weeklyEyeCareNotificationWeekday
        components.hour = config.weeklyEyeCareNotificationHour
        components.minute = config.weeklyEyeCareNotificationMinute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        return UNNotificationRequest(identifier: Self.weeklyIdentifier, content: content, trigger: trigger)
    }

    private func fetchAuthorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    private func addRequest(_ request: UNNotificationRequest) async {
        await withCheckedContinuation { continuation in
            center.add(request) { _ in
                continuation.resume(returning: ())
            }
        }
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
