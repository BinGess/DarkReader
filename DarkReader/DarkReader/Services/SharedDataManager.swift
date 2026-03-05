//
//  SharedDataManager.swift
//  DarkReader
//
//  核心数据管理器：通过 App Groups UserDefaults 在宿主 App 和 Safari 扩展之间共享数据
//  这是整个产品的数据枢纽，所有配置的读写均经过此类
//
//  通信机制：
//  - 宿主 App ↔ Safari 扩展：UserDefaults(suiteName: SharedKeys.appGroupSuite)
//  - 数据变更通知：使用 @Published 驱动 SwiftUI 视图更新
//

import Foundation
import Combine
import os.log
import SafariServices
#if canImport(UIKit)
import UIKit
#endif

// MARK: - UserDefaults 键名常量（两端共享，必须完全一致）
enum SharedKeys {
    static let appGroupSuite  = "group.com.darkreader.shared"
    static let globalConfig   = "DarkReader_GlobalConfig"
    static let themes         = "DarkReader_CustomThemes"   // 仅自定义主题，内置主题硬编码
    static let siteRules      = "DarkReader_SiteRules"
    static let visitedSites   = "DarkReader_VisitedSites"
    static let auxData        = "DarkReader_AuxData"
    static let errorLogs      = "DarkReader_ErrorLogs"
    static let feedbackRecords = "DarkReader_Feedback"
    static let eyeCareDailyRecords = "DarkReader_EyeCareDailyRecords"
    static let eyeCareSiteDurations = "DarkReader_EyeCareSiteDurations"
}

// MARK: - 错误日志模型（最多保留10条）
struct ErrorLog: Codable, Identifiable, Equatable {
    var id = UUID()
    var domain: String
    var errorMsg: String
    var time: Date
}

// MARK: - 用户反馈模型（最多保留20条）
struct FeedbackRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    var domain: String
    var themeId: String
    var content: String
    var time: Date
}

// MARK: - 护眼日报模型（按天聚合）
struct DailyEyeCareRecord: Codable, Identifiable, Equatable {
    var id: Date { Calendar.current.startOfDay(for: date) }
    var date: Date
    var darkModeDuration: TimeInterval
    var sitesCount: Int
    var dominantThemeId: String
}

// MARK: - SharedDataManager

class SharedDataManager: ObservableObject {
    // MARK: 单例（宿主 App 使用）
    static let shared = SharedDataManager()

    private let logger = Logger(subsystem: "com.timmy.darkreader", category: "SharedDataManager")

    // App Groups 共享 UserDefaults（两端均通过此访问数据）
    private let defaults: UserDefaults
    private var defaultsReloadWorkItem: DispatchWorkItem?
    private var sharedSyncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var isApplyingCloudMerge = false
    private var isApplyingExternalSync = false

    private var lastGlobalConfigData: Data?
    private var lastThemesData: Data?
    private var lastSiteRulesData: Data?
    private var lastVisitedSitesData: Data?
    private var lastErrorLogsData: Data?
    private var lastFeedbackData: Data?
    private var lastEyeCareDailyRecordsData: Data?
    private var lastEyeCareSiteDurationsData: Data?

    // MARK: - 发布的数据属性（SwiftUI 视图通过这些属性读取数据）

    @Published var globalConfig: GlobalConfig = GlobalConfig() {
        didSet {
            if !isApplyingExternalSync {
                persistGlobalConfig()
            }
        }
    }

    // 所有主题（内置4个 + 自定义）
    @Published var themes: [DarkTheme] = DarkTheme.builtins

    // 站点规则字典
    @Published var siteRules: SiteRules = [:]

    // 访问过的网站（domain -> 最后访问时间）
    @Published var visitedSites: [String: Date] = [:]

    // 错误日志（本地只读，由扩展写入）
    @Published var errorLogs: [ErrorLog] = []

    // 用户反馈记录
    @Published var feedbackRecords: [FeedbackRecord] = []

    // 护眼日报记录（按天）
    @Published var eyeCareDailyRecords: [DailyEyeCareRecord] = []
    // 站点分布（dateKey -> [domain: seconds]）
    @Published var eyeCareSiteDurations: [String: [String: TimeInterval]] = [:]

    // MARK: - 初始化

    private init() {
        // 初始化 App Groups 共享容器
        guard let sharedDefaults = UserDefaults(suiteName: SharedKeys.appGroupSuite) else {
            fatalError("[DarkReader] App Groups 未配置！请检查 Xcode Capabilities 中的 App Groups 设置")
        }
        self.defaults = sharedDefaults

        // 从共享容器加载数据
        loadAll()

        // 监听 UserDefaults 变更（其他进程写入时触发）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(defaultsChanged),
            name: UserDefaults.didChangeNotification,
            object: sharedDefaults
        )

        logger.info("SharedDataManager 初始化完成")
        setupCloudAutoSyncBindings()
        setupCrossProcessSync()
    }

    // MARK: - 扩展端专用初始化（非 ObservableObject，轻量读写）
    // SafariWebExtensionHandler 使用此方法，不需要 @Published
    static func forExtension() -> SharedDataManager {
        return SharedDataManager()
    }

    private func setupCloudAutoSyncBindings() {
        $themes
            .dropFirst()
            .sink { [weak self] themes in
                guard let self else { return }
                self.syncToCloudIfNeeded(themes: themes, rules: self.siteRules)
            }
            .store(in: &cancellables)

        $siteRules
            .dropFirst()
            .sink { [weak self] rules in
                guard let self else { return }
                self.syncToCloudIfNeeded(themes: self.themes, rules: rules)
            }
            .store(in: &cancellables)
    }

    private func syncToCloudIfNeeded(themes: [DarkTheme], rules: SiteRules) {
        let cloud = iCloudSyncManager.shared
        guard cloud.isSyncEnabled, !isApplyingCloudMerge else { return }
        cloud.scheduleUpload(themes: themes, siteRules: rules)
    }
}

// MARK: - 数据加载

extension SharedDataManager {
    /// 从 App Groups 共享容器加载所有数据
    private func loadAll() {
        globalConfig = loadGlobalConfig()
        themes = loadThemes()
        siteRules = loadSiteRules()
        visitedSites = loadVisitedSites()
        errorLogs = loadErrorLogs()
        feedbackRecords = loadFeedbackRecords()
        eyeCareDailyRecords = loadEyeCareDailyRecords()
        eyeCareSiteDurations = loadEyeCareSiteDurations()
        refreshSunScheduleIfNeeded()
        captureSharedSnapshots()
    }

    private func loadGlobalConfig() -> GlobalConfig {
        guard let data = defaults.data(forKey: SharedKeys.globalConfig),
              let config = try? JSONDecoder().decode(GlobalConfig.self, from: data) else {
            return GlobalConfig()  // 默认配置
        }
        return config
    }

    private func loadThemes() -> [DarkTheme] {
        // 始终包含内置主题，再追加自定义主题
        var all = DarkTheme.builtins
        if let data = defaults.data(forKey: SharedKeys.themes),
           let custom = try? JSONDecoder().decode([DarkTheme].self, from: data) {
            all.append(contentsOf: custom)
        }
        return all
    }

    private func loadSiteRules() -> SiteRules {
        guard let data = defaults.data(forKey: SharedKeys.siteRules),
              let rules = try? JSONDecoder().decode(SiteRules.self, from: data) else {
            return [:]
        }
        return rules
    }

    private func loadVisitedSites() -> [String: Date] {
        guard let data = defaults.data(forKey: SharedKeys.visitedSites),
              let visited = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return [:]
        }
        return visited
    }

    private func loadErrorLogs() -> [ErrorLog] {
        guard let data = defaults.data(forKey: SharedKeys.errorLogs),
              let logs = try? JSONDecoder().decode([ErrorLog].self, from: data) else {
            return []
        }
        return logs
    }

    private func loadFeedbackRecords() -> [FeedbackRecord] {
        guard let data = defaults.data(forKey: SharedKeys.feedbackRecords),
              let records = try? JSONDecoder().decode([FeedbackRecord].self, from: data) else {
            return []
        }
        return records
    }

    private func loadEyeCareDailyRecords() -> [DailyEyeCareRecord] {
        guard let data = defaults.data(forKey: SharedKeys.eyeCareDailyRecords),
              let records = try? JSONDecoder().decode([DailyEyeCareRecord].self, from: data) else {
            return []
        }
        return records.sorted { $0.date < $1.date }
    }

    private func loadEyeCareSiteDurations() -> [String: [String: TimeInterval]] {
        guard let data = defaults.data(forKey: SharedKeys.eyeCareSiteDurations),
              let records = try? JSONDecoder().decode([String: [String: TimeInterval]].self, from: data) else {
            return [:]
        }
        return records
    }

    // 其他进程（Safari 扩展）修改数据后，重新加载
    @objc private func defaultsChanged() {
        defaultsReloadWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            // 跨进程通知并不总可靠，统一走全量比对刷新，避免漏掉 globalConfig/themes 变更。
            self.forceReloadFromShared()
        }
        defaultsReloadWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: workItem)
    }
}

// MARK: - 数据持久化

extension SharedDataManager {
    @discardableResult
    private func persistDataWithRetry(_ data: Data, key: String, retries: Int = 2) -> Bool {
        for attempt in 0...retries {
            defaults.set(data, forKey: key)
            if defaults.data(forKey: key) == data {
                captureSharedSnapshots()
                return true
            }
            if attempt < retries {
                Thread.sleep(forTimeInterval: 0.02 * Double(attempt + 1))
            }
        }
        logger.error("数据持久化失败：key=\(key, privacy: .public)")
        return false
    }

    /// 保存全局配置到共享容器
    func saveConfig() {
        persistGlobalConfig()
    }

    private func persistGlobalConfig() {
        guard let data = try? JSONEncoder().encode(globalConfig) else { return }
        _ = persistDataWithRetry(data, key: SharedKeys.globalConfig)
        logger.debug("全局配置已保存：mode=\(self.globalConfig.mode.rawValue)")
    }

    /// 保存站点规则
    func save(siteRule: SiteRule, forDomain domain: String) {
        var normalizedRule = siteRule
        normalizedRule.updatedAt = Date()
        if !siteRule.hasCustomSettings {
            // 规则全部恢复默认时删除该域名条目（节省存储）
            siteRules.removeValue(forKey: domain)
        } else {
            siteRules[domain] = normalizedRule
        }
        persistSiteRules()
    }

    /// 删除某个域名的站点规则
    func removeSiteRule(forDomain domain: String) {
        siteRules.removeValue(forKey: domain)
        persistSiteRules()
    }

    private func persistSiteRules() {
        guard let data = try? JSONEncoder().encode(siteRules) else { return }
        _ = persistDataWithRetry(data, key: SharedKeys.siteRules)
    }

    private func persistVisitedSites() {
        guard let data = try? JSONEncoder().encode(visitedSites) else { return }
        _ = persistDataWithRetry(data, key: SharedKeys.visitedSites)
    }

    private func persistEyeCareDailyRecords() {
        guard let data = try? JSONEncoder().encode(eyeCareDailyRecords) else { return }
        _ = persistDataWithRetry(data, key: SharedKeys.eyeCareDailyRecords)
    }

    private func persistEyeCareSiteDurations() {
        guard let data = try? JSONEncoder().encode(eyeCareSiteDurations) else { return }
        _ = persistDataWithRetry(data, key: SharedKeys.eyeCareSiteDurations)
    }

    func markVisited(domain: String, at date: Date = Date()) {
        visitedSites[domain.mainDomain] = date
        if visitedSites.count > 200 {
            let sorted = visitedSites.sorted { $0.value > $1.value }
            visitedSites = Dictionary(
                uniqueKeysWithValues: sorted.prefix(200).map { ($0.key, $0.value) }
            )
        }
        persistVisitedSites()
    }

    func appendEyeCareUsage(domain: String, duration: TimeInterval, themeId: String, at date: Date = Date()) {
        let day = Calendar.current.startOfDay(for: date)
        let dayKey = Self.dayKey(for: day)
        let normalizedDomain = domain.mainDomain.isEmpty ? "unknown" : domain.mainDomain
        let safeDuration = max(duration, 0)
        guard safeDuration > 0 else { return }

        var dayRecord = eyeCareDailyRecords.first { Calendar.current.isDate($0.date, inSameDayAs: day) }
            ?? DailyEyeCareRecord(
                date: day,
                darkModeDuration: 0,
                sitesCount: 0,
                dominantThemeId: themeId.isEmpty ? globalConfig.defaultThemeId : themeId
            )

        dayRecord.darkModeDuration += safeDuration
        if !themeId.isEmpty {
            dayRecord.dominantThemeId = themeId
        }

        var siteDurations = eyeCareSiteDurations[dayKey] ?? [:]
        siteDurations[normalizedDomain] = (siteDurations[normalizedDomain] ?? 0) + safeDuration
        dayRecord.sitesCount = siteDurations.keys.count
        eyeCareSiteDurations[dayKey] = siteDurations

        if let idx = eyeCareDailyRecords.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: day) }) {
            eyeCareDailyRecords[idx] = dayRecord
        } else {
            eyeCareDailyRecords.append(dayRecord)
        }
        eyeCareDailyRecords.sort { $0.date < $1.date }

        if eyeCareDailyRecords.count > 120 {
            eyeCareDailyRecords.removeFirst(eyeCareDailyRecords.count - 120)
        }

        persistEyeCareDailyRecords()
        persistEyeCareSiteDurations()
    }

    /// 添加自定义主题
    func addCustomTheme(_ theme: DarkTheme) {
        var newTheme = theme
        newTheme.updatedAt = Date()
        themes.append(newTheme)
        persistCustomThemes()
    }

    /// 更新自定义主题
    func updateTheme(_ theme: DarkTheme) {
        guard let index = themes.firstIndex(where: { $0.id == theme.id }),
              !themes[index].isBuiltin else { return }
        var updatedTheme = theme
        updatedTheme.updatedAt = Date()
        themes[index] = updatedTheme
        persistCustomThemes()
    }

    /// 删除自定义主题
    func deleteTheme(id: String) {
        guard let theme = themes.first(where: { $0.id == id }), !theme.isBuiltin else { return }
        themes.removeAll { $0.id == id }
        // 如果删除的是默认主题，切换到内置深灰
        if globalConfig.defaultThemeId == id {
            globalConfig.defaultThemeId = "theme_002"
        }
        persistCustomThemes()
    }

    private func persistCustomThemes() {
        let custom = themes.filter { !$0.isBuiltin }
        guard let data = try? JSONEncoder().encode(custom) else { return }
        _ = persistDataWithRetry(data, key: SharedKeys.themes)
    }

    /// 追加错误日志（最多保留10条，超出自动删除最旧的）
    func appendErrorLog(_ log: ErrorLog) {
        var logs = loadErrorLogs()
        logs.append(log)
        if logs.count > 10 { logs.removeFirst(logs.count - 10) }
        guard let data = try? JSONEncoder().encode(logs) else { return }
        _ = persistDataWithRetry(data, key: SharedKeys.errorLogs)
        DispatchQueue.main.async { self.errorLogs = logs }
    }

    /// 追加用户反馈（最多保留20条）
    func appendFeedback(_ record: FeedbackRecord) {
        var records = loadFeedbackRecords()
        records.append(record)
        if records.count > 20 { records.removeFirst(records.count - 20) }
        guard let data = try? JSONEncoder().encode(records) else { return }
        _ = persistDataWithRetry(data, key: SharedKeys.feedbackRecords)
        DispatchQueue.main.async { self.feedbackRecords = records }
    }

    /// 清除所有本地数据（用户主动清除时调用）
    func clearAllData() {
        defaults.removeObject(forKey: SharedKeys.globalConfig)
        defaults.removeObject(forKey: SharedKeys.themes)
        defaults.removeObject(forKey: SharedKeys.siteRules)
        defaults.removeObject(forKey: SharedKeys.visitedSites)
        defaults.removeObject(forKey: SharedKeys.errorLogs)
        defaults.removeObject(forKey: SharedKeys.feedbackRecords)
        defaults.removeObject(forKey: SharedKeys.eyeCareDailyRecords)
        defaults.removeObject(forKey: SharedKeys.eyeCareSiteDurations)
        // 重置为默认状态
        globalConfig = GlobalConfig()
        themes = DarkTheme.builtins
        siteRules = [:]
        visitedSites = [:]
        errorLogs = []
        feedbackRecords = []
        eyeCareDailyRecords = []
        eyeCareSiteDurations = [:]
        logger.info("所有本地数据已清除")
    }
}

// MARK: - 跨进程同步（宿主 App <-> Safari 扩展）

extension SharedDataManager {
    private func setupCrossProcessSync() {
        startSharedSyncTimer()
#if canImport(UIKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
#endif
    }

    @objc private func appDidBecomeActive() {
        forceReloadFromShared()
        startSharedSyncTimer()
    }

    @objc private func appWillResignActive() {
        stopSharedSyncTimer()
    }

    private func startSharedSyncTimer() {
        guard sharedSyncTimer == nil else { return }
        sharedSyncTimer = Timer.scheduledTimer(
            withTimeInterval: 1.2,
            repeats: true
        ) { [weak self] _ in
            self?.reloadFromSharedIfNeeded()
        }
        RunLoop.main.add(sharedSyncTimer!, forMode: .common)
    }

    private func stopSharedSyncTimer() {
        sharedSyncTimer?.invalidate()
        sharedSyncTimer = nil
    }

    private func captureSharedSnapshots() {
        lastGlobalConfigData = defaults.data(forKey: SharedKeys.globalConfig)
        lastThemesData = defaults.data(forKey: SharedKeys.themes)
        lastSiteRulesData = defaults.data(forKey: SharedKeys.siteRules)
        lastVisitedSitesData = defaults.data(forKey: SharedKeys.visitedSites)
        lastErrorLogsData = defaults.data(forKey: SharedKeys.errorLogs)
        lastFeedbackData = defaults.data(forKey: SharedKeys.feedbackRecords)
        lastEyeCareDailyRecordsData = defaults.data(forKey: SharedKeys.eyeCareDailyRecords)
        lastEyeCareSiteDurationsData = defaults.data(forKey: SharedKeys.eyeCareSiteDurations)
    }

    private func forceReloadFromShared() {
        let currentGlobalConfig = loadGlobalConfig()
        let currentThemes = loadThemes()
        let currentSiteRules = loadSiteRules()
        let currentVisitedSites = loadVisitedSites()
        let currentErrorLogs = loadErrorLogs()
        let currentFeedback = loadFeedbackRecords()
        let currentEyeCareDailyRecords = loadEyeCareDailyRecords()
        let currentEyeCareSiteDurations = loadEyeCareSiteDurations()

        isApplyingExternalSync = true
        defer { isApplyingExternalSync = false }

        if globalConfig != currentGlobalConfig {
            globalConfig = currentGlobalConfig
        }
        if themes != currentThemes {
            themes = currentThemes
        }
        if siteRules != currentSiteRules {
            siteRules = currentSiteRules
        }
        if visitedSites != currentVisitedSites {
            visitedSites = currentVisitedSites
        }
        if errorLogs != currentErrorLogs {
            errorLogs = currentErrorLogs
        }
        if feedbackRecords != currentFeedback {
            feedbackRecords = currentFeedback
        }
        if eyeCareDailyRecords != currentEyeCareDailyRecords {
            eyeCareDailyRecords = currentEyeCareDailyRecords
        }
        if eyeCareSiteDurations != currentEyeCareSiteDurations {
            eyeCareSiteDurations = currentEyeCareSiteDurations
        }

        captureSharedSnapshots()
    }

    private func reloadFromSharedIfNeeded() {
        let globalData = defaults.data(forKey: SharedKeys.globalConfig)
        let themesData = defaults.data(forKey: SharedKeys.themes)
        let rulesData = defaults.data(forKey: SharedKeys.siteRules)
        let visitedData = defaults.data(forKey: SharedKeys.visitedSites)
        let logsData = defaults.data(forKey: SharedKeys.errorLogs)
        let feedbackData = defaults.data(forKey: SharedKeys.feedbackRecords)
        let eyeCareDailyData = defaults.data(forKey: SharedKeys.eyeCareDailyRecords)
        let eyeCareSitesData = defaults.data(forKey: SharedKeys.eyeCareSiteDurations)

        let changed =
            globalData != lastGlobalConfigData ||
            themesData != lastThemesData ||
            rulesData != lastSiteRulesData ||
            visitedData != lastVisitedSitesData ||
            logsData != lastErrorLogsData ||
            feedbackData != lastFeedbackData ||
            eyeCareDailyData != lastEyeCareDailyRecordsData ||
            eyeCareSitesData != lastEyeCareSiteDurationsData

        guard changed else { return }
        forceReloadFromShared()
    }
}

// MARK: - 主题查询工具

extension SharedDataManager {
    var visitedDomainsSorted: [String] {
        visitedSites
            .sorted { $0.value > $1.value }
            .map { $0.key }
    }

    func visitedDate(for domain: String) -> Date? {
        visitedSites[domain]
    }

    /// 根据 ID 查找主题，不存在时返回默认深灰主题
    func theme(id: String) -> DarkTheme {
        themes.first { $0.id == id } ?? DarkTheme.builtins[1]
    }

    /// 当前默认主题
    var defaultTheme: DarkTheme {
        theme(id: globalConfig.defaultThemeId)
    }

    /// 获取当前配置下适用于指定域名的主题
    func effectiveTheme(forDomain domain: String) -> DarkTheme {
        let rule = siteRules[domain]
        let themeId = rule?.themeId?.isEmpty == false ? rule!.themeId! : globalConfig.defaultThemeId
        return theme(id: themeId)
    }

    /// 扩展用：将当前状态序列化为可发送给 JS 的字典
    func configDictForExtension(domain: String) -> [String: Any] {
        let rule = siteRules[domain]
        let effectiveTheme = self.effectiveTheme(forDomain: domain)
        return [
            "config": [
                "mode": globalConfig.mode.rawValue,
                "defaultThemeId": globalConfig.defaultThemeId,
                "dimImages": globalConfig.dimImages,
                "ignoreNativeDarkMode": globalConfig.ignoreNativeDarkMode,
                "performanceMode": globalConfig.performanceMode,
                "appLanguage": globalConfig.appLanguage.rawValue,
                "siteMode": rule?.mode?.rawValue ?? "smart",
                "siteThemeId": rule?.themeId ?? "",
                "scheduleEnabled": globalConfig.scheduleEnabled,
                "scheduleTriggerSource": globalConfig.scheduleTriggerSource.rawValue,
                "scheduleStartHour": globalConfig.scheduleStartHour,
                "scheduleStartMinute": globalConfig.scheduleStartMinute,
                "scheduleEndHour": globalConfig.scheduleEndHour,
                "scheduleEndMinute": globalConfig.scheduleEndMinute,
                "sunScheduleSunriseHour": globalConfig.sunScheduleSunriseHour,
                "sunScheduleSunriseMinute": globalConfig.sunScheduleSunriseMinute,
                "sunScheduleSunsetHour": globalConfig.sunScheduleSunsetHour,
                "sunScheduleSunsetMinute": globalConfig.sunScheduleSunsetMinute,
                "hideCookieBanners": globalConfig.hideCookieBanners,
                "dailyEyeCareNotificationEnabled": globalConfig.dailyEyeCareNotificationEnabled,
                "dailyEyeCareNotificationHour": globalConfig.dailyEyeCareNotificationHour,
                "dailyEyeCareNotificationMinute": globalConfig.dailyEyeCareNotificationMinute,
                "weeklyEyeCareNotificationEnabled": globalConfig.weeklyEyeCareNotificationEnabled,
                "weeklyEyeCareNotificationWeekday": globalConfig.weeklyEyeCareNotificationWeekday,
                "weeklyEyeCareNotificationHour": globalConfig.weeklyEyeCareNotificationHour,
                "weeklyEyeCareNotificationMinute": globalConfig.weeklyEyeCareNotificationMinute
            ] as [String: Any],
            "theme": [
                "id": effectiveTheme.id,
                "backgroundColor": effectiveTheme.backgroundColor,
                "textColor": effectiveTheme.textColor,
                "secondaryTextColor": effectiveTheme.secondaryTextColor,
                "linkColor": effectiveTheme.linkColor,
                "borderColor": effectiveTheme.borderColor,
                "imageBrightness": effectiveTheme.imageBrightness,
                "imageGrayscale": effectiveTheme.imageGrayscale,
                "category": effectiveTheme.category.rawValue,
                "eyeCareScore": effectiveTheme.eyeCareScore,
                "warmthLevel": effectiveTheme.warmthLevel,
                "dimImages": globalConfig.dimImages
            ] as [String: Any]
        ]
    }

    // MARK: - 护眼统计

    var todayEyeCareRecord: DailyEyeCareRecord {
        let today = Calendar.current.startOfDay(for: Date())
        return eyeCareDailyRecords.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
            ?? DailyEyeCareRecord(date: today, darkModeDuration: 0, sitesCount: 0, dominantThemeId: globalConfig.defaultThemeId)
    }

    var currentWeekEyeCareRecords: [DailyEyeCareRecord] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }.reversed()
        return days.map { day in
            eyeCareDailyRecords.first { calendar.isDate($0.date, inSameDayAs: day) }
                ?? DailyEyeCareRecord(date: day, darkModeDuration: 0, sitesCount: 0, dominantThemeId: globalConfig.defaultThemeId)
        }
    }

    func siteDistribution(for date: Date) -> [(domain: String, duration: TimeInterval)] {
        let key = Self.dayKey(for: date)
        let dict = eyeCareSiteDurations[key] ?? [:]
        return dict
            .map { ($0.key, $0.value) }
            .sorted { $0.1 > $1.1 }
    }

    func estimatedBlueLightReduction(for record: DailyEyeCareRecord) -> Double {
        guard record.darkModeDuration > 0 else { return 0 }
        let theme = theme(id: record.dominantThemeId)
        let baseReduction = 0.30 + Double(max(theme.eyeCareScore - 1, 0)) * 0.04
        let warmBonus = theme.warmthLevel >= 4 ? 0.10 : 0.0
        return min(max(baseReduction + warmBonus, 0.30), 0.60)
    }

    func darkShieldPoints(for record: DailyEyeCareRecord) -> Int {
        let reductionRatio = estimatedBlueLightReduction(for: record)
        return Self.darkShieldPoints(durationSeconds: record.darkModeDuration, reductionRatio: reductionRatio)
    }

    static func darkShieldPoints(durationSeconds: TimeInterval, reductionRatio: Double) -> Int {
        guard durationSeconds > 0, reductionRatio > 0 else { return 0 }
        let safeRatio = min(max(reductionRatio, 0), 1)
        let weightedHours = (durationSeconds / 3600) * safeRatio
        return max(Int((weightedHours * 1000).rounded()), 0)
    }

    func refreshSunScheduleIfNeeded(force: Bool = false) {
        guard globalConfig.scheduleTriggerSource == .sunsetSunrise else { return }
        guard let latitude = globalConfig.sunLatitude, let longitude = globalConfig.sunLongitude else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if !force, let updatedAt = globalConfig.sunScheduleUpdatedAt, calendar.isDate(updatedAt, inSameDayAs: today) {
            return
        }

        guard let sun = SunTimeCalculator.sunriseSunset(for: Date(), latitude: latitude, longitude: longitude) else {
            return
        }
        let sunrise = calendar.dateComponents([.hour, .minute], from: sun.sunrise)
        let sunset = calendar.dateComponents([.hour, .minute], from: sun.sunset)
        globalConfig.sunScheduleSunriseHour = sunrise.hour ?? 7
        globalConfig.sunScheduleSunriseMinute = sunrise.minute ?? 0
        globalConfig.sunScheduleSunsetHour = sunset.hour ?? 18
        globalConfig.sunScheduleSunsetMinute = sunset.minute ?? 0
        globalConfig.sunScheduleUpdatedAt = Date()
        persistGlobalConfig()
    }

    static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// iCloud 同步时合并远端数据（保留最新修改）
    func mergeFromiCloud(customThemes: [DarkTheme], remoteRules: SiteRules) {
        isApplyingCloudMerge = true
        defer { isApplyingCloudMerge = false }

        var themesChanged = false
        var rulesChanged = false

        // 合并自定义主题：按 updatedAt 保留最新版本
        for remoteTheme in customThemes {
            if let localIndex = themes.firstIndex(where: { $0.id == remoteTheme.id && !$0.isBuiltin }) {
                if themes[localIndex].updatedAt < remoteTheme.updatedAt {
                    themes[localIndex] = remoteTheme
                    themesChanged = true
                }
            } else if !remoteTheme.isBuiltin {
                themes.append(remoteTheme)
                themesChanged = true
            }
        }
        if themesChanged {
            persistCustomThemes()
        }

        // 合并站点规则：按更新时间保留最新修改
        for (domain, rule) in remoteRules {
            if let localRule = siteRules[domain] {
                if localRule.updatedAt < rule.updatedAt {
                    siteRules[domain] = rule
                    rulesChanged = true
                }
            } else {
                siteRules[domain] = rule
                rulesChanged = true
            }
        }
        if rulesChanged {
            persistSiteRules()
        }
    }
}

// MARK: - 日出日落计算（离线天文算法）
struct SunTimeCalculator {
    static func sunriseSunset(for date: Date, latitude: Double, longitude: Double) -> (sunrise: Date, sunset: Date)? {
        let clampedLatitude = min(max(latitude, -89.8), 89.8)
        guard let sunrise = calculate(for: date, latitude: clampedLatitude, longitude: longitude, sunrise: true),
              let sunset = calculate(for: date, latitude: clampedLatitude, longitude: longitude, sunrise: false) else {
            return nil
        }
        return (sunrise, sunset)
    }

    private static func calculate(for date: Date, latitude: Double, longitude: Double, sunrise: Bool) -> Date? {
        let localCalendar = Calendar.current
        let dayOfYear = localCalendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let lngHour = longitude / 15.0
        let t = Double(dayOfYear) + ((sunrise ? 6.0 : 18.0) - lngHour) / 24.0

        let meanAnomaly = (0.9856 * t) - 3.289
        var trueLongitude = meanAnomaly
            + (1.916 * sinDeg(meanAnomaly))
            + (0.020 * sinDeg(2 * meanAnomaly))
            + 282.634
        trueLongitude = normalizeDegrees(trueLongitude)

        var rightAscension = radToDeg(atan(0.91764 * tanDeg(trueLongitude)))
        rightAscension = normalizeDegrees(rightAscension)

        let lQuadrant = floor(trueLongitude / 90.0) * 90.0
        let raQuadrant = floor(rightAscension / 90.0) * 90.0
        rightAscension = (rightAscension + (lQuadrant - raQuadrant)) / 15.0

        let sinDec = 0.39782 * sinDeg(trueLongitude)
        let cosDec = cos(asin(sinDec))

        let cosH = (cosDeg(90.833) - (sinDec * sinDeg(latitude))) / (cosDec * cosDeg(latitude))
        if cosH > 1 || cosH < -1 {
            return nil
        }

        let hourAngle = sunrise ? (360.0 - radToDeg(acos(cosH))) : radToDeg(acos(cosH))
        let localHour = hourAngle / 15.0
        let localMeanTime = localHour + rightAscension - (0.06571 * t) - 6.622
        let universalTime = normalizeHours(localMeanTime - lngHour)

        let comps = localCalendar.dateComponents([.year, .month, .day], from: date)
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        guard let utcStart = utcCalendar.date(
            from: DateComponents(
                timeZone: TimeZone(secondsFromGMT: 0),
                year: comps.year,
                month: comps.month,
                day: comps.day
            )
        ) else {
            return nil
        }
        return utcStart.addingTimeInterval(universalTime * 3600)
    }

    private static func sinDeg(_ value: Double) -> Double { sin(degToRad(value)) }
    private static func cosDeg(_ value: Double) -> Double { cos(degToRad(value)) }
    private static func tanDeg(_ value: Double) -> Double { tan(degToRad(value)) }
    private static func degToRad(_ value: Double) -> Double { value * .pi / 180.0 }
    private static func radToDeg(_ value: Double) -> Double { value * 180.0 / .pi }

    private static func normalizeDegrees(_ value: Double) -> Double {
        var v = value.truncatingRemainder(dividingBy: 360.0)
        if v < 0 { v += 360.0 }
        return v
    }

    private static func normalizeHours(_ value: Double) -> Double {
        var v = value.truncatingRemainder(dividingBy: 24.0)
        if v < 0 { v += 24.0 }
        return v
    }
}
