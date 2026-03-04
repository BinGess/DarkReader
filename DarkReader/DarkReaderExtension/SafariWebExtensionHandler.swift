//
//  SafariWebExtensionHandler.swift
//  DarkReaderExtension
//
//  Safari 扩展原生桥接层：接收来自 background.js 的消息，
//  读取/写入 App Groups 共享容器，并将结果返回给 JS 端
//
//  通信方向：
//    background.js → (native messaging) → SafariWebExtensionHandler → App Groups → response → background.js
//
//  重要：此类运行在 Safari Extension 进程中（WebKit Sandbox）
//        与宿主 App 通过 App Groups UserDefaults 共享数据
//

import Foundation
import SafariServices
import os.log

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    private let logger = Logger(
        subsystem: "com.timmy.darkreader.extension",
        category: "ExtensionHandler"
    )

    // 与宿主 App 共享的数据管理器（只读取 App Groups，不依赖 @Published）
    private lazy var dataStore = ExtensionDataStore()

    // MARK: - 入口

    func beginRequest(with context: NSExtensionContext) {
        // 解析传入消息
        guard
            let item = context.inputItems.first as? NSExtensionItem,
            let messageDict = item.userInfo?[SFExtensionMessageKey] as? [String: Any],
            let action = messageDict["action"] as? String
        else {
            logger.warning("收到无效消息，格式错误")
            context.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        logger.debug("收到消息：action=\(action)")

        // openApp 需要异步处理，避免先 completeRequest 导致 open 失效
        if action == "openApp" {
            let target = messageDict["target"] as? String ?? "settings"
            handleOpenAppRequest(target: target, context: context)
            return
        }

        // 根据 action 分发处理
        let responseData: Any
        switch action {

        case "getConfig":
            let domain = messageDict["domain"] as? String ?? ""
            responseData = dataStore.buildConfigResponse(for: domain)

        case "getThemes":
            responseData = ["themes": dataStore.allThemesAsDicts()]

        case "saveRule":
            let domain = messageDict["domain"] as? String ?? ""
            let rule   = messageDict["rule"]   as? [String: Any] ?? [:]
            // brightness/contrast/focusMode 为 nil 时保留 App Groups 中的现有值（popup 不传这些字段）
            dataStore.saveSiteRule(
                domain: domain,
                modeRaw: rule["mode"] as? String,
                themeId: rule["themeId"] as? String,
                brightness: rule["brightness"] as? Double,
                contrast: rule["contrast"] as? Double,
                focusMode: rule["focusMode"] as? Bool
            )
            responseData = ["ok": true]

        case "saveGlobalConfig":
            let config = messageDict["config"] as? [String: Any] ?? [:]
            dataStore.saveGlobalConfig(from: config)
            responseData = ["ok": true]

        case "logError":
            let domain  = messageDict["domain"]   as? String ?? ""
            let errMsg  = messageDict["errorMsg"] as? String ?? ""
            let time    = messageDict["time"]     as? String ?? ""
            dataStore.appendErrorLog(domain: domain, errorMsg: errMsg, timeStr: time)
            responseData = ["ok": true]

        case "submitFeedback":
            let feedback = messageDict["feedback"] as? [String: Any] ?? [:]
            dataStore.appendFeedback(feedback)
            responseData = ["ok": true]

        case "reportEyeCareUsage":
            let domain = messageDict["domain"] as? String ?? ""
            let themeId = messageDict["themeId"] as? String ?? ""
            let durationSeconds = messageDict["durationSeconds"] as? Double ?? 0
            let time = messageDict["time"] as? String
            dataStore.appendEyeCareUsage(
                domain: domain,
                durationSeconds: durationSeconds,
                themeId: themeId,
                timeStr: time
            )
            responseData = ["ok": true]

        default:
            logger.warning("未知 action: \(action)")
            responseData = ["error": "unknown action: \(action)"]
        }

        // 返回响应
        completeRequest(context: context, responseData: responseData)
    }

    private func handleOpenAppRequest(target: String, context: NSExtensionContext) {
        let safeTarget: String
        switch target.lowercased() {
        case "dashboard", "themes", "settings":
            safeTarget = target.lowercased()
        default:
            safeTarget = "settings"
        }

        let candidates = [
            URL(string: "darkreader://\(safeTarget)"),
            URL(string: "darkreader://open?target=\(safeTarget)"),
            URL(string: "darkreader://")
        ].compactMap { $0 }

        guard !candidates.isEmpty else {
            completeRequest(context: context, responseData: ["ok": false, "error": "invalid_deeplink"])
            return
        }

        func tryOpen(_ index: Int) {
            guard index < candidates.count else {
                completeRequest(context: context, responseData: ["ok": false, "error": "open_failed"])
                return
            }
            let url = candidates[index]
            context.open(url) { [weak self] success in
                if success {
                    self?.logger.info("已触发打开宿主 App：\(url.absoluteString, privacy: .public)")
                    self?.completeRequest(context: context, responseData: ["ok": true, "url": url.absoluteString])
                } else {
                    self?.logger.error("打开宿主 App 失败：\(url.absoluteString, privacy: .public)")
                    tryOpen(index + 1)
                }
            }
        }

        DispatchQueue.main.async {
            tryOpen(0)
        }
    }

    private func completeRequest(context: NSExtensionContext, responseData: Any) {
        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: responseData]
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
}

// MARK: - ExtensionDataStore（轻量级数据访问层，专为 Extension 进程设计）

/// 扩展进程内的数据存储访问器
/// 直接读写 App Groups UserDefaults，不使用 ObservableObject
private class ExtensionDataStore {

    private let logger = Logger(subsystem: "com.timmy.darkreader.extension", category: "DataStore")

    private let defaults: UserDefaults

    init() {
        guard let d = UserDefaults(suiteName: SharedKeys.appGroupSuite) else {
            fatalError("[DarkReaderExt] App Groups 未配置！")
        }
        self.defaults = d
    }

    @discardableResult
    private func persistDataWithRetry(_ data: Data, key: String, retries: Int = 2) -> Bool {
        for attempt in 0...retries {
            defaults.set(data, forKey: key)
            if defaults.data(forKey: key) == data {
                return true
            }
            if attempt < retries {
                Thread.sleep(forTimeInterval: 0.02 * Double(attempt + 1))
            }
        }
        logger.error("写入共享容器失败：key=\(key, privacy: .public)")
        return false
    }

    // MARK: - 读取

    var globalConfig: GlobalConfig {
        guard let data = defaults.data(forKey: SharedKeys.globalConfig),
              let config = try? JSONDecoder().decode(GlobalConfig.self, from: data)
        else { return GlobalConfig() }
        return config
    }

    var customThemes: [DarkTheme] {
        guard let data = defaults.data(forKey: SharedKeys.themes),
              let themes = try? JSONDecoder().decode([DarkTheme].self, from: data)
        else { return [] }
        return themes
    }

    var allThemes: [DarkTheme] {
        DarkTheme.builtins + customThemes
    }

    var siteRules: SiteRules {
        guard let data = defaults.data(forKey: SharedKeys.siteRules),
              let rules = try? JSONDecoder().decode(SiteRules.self, from: data)
        else { return [:] }
        return rules
    }

    var visitedSites: [String: Date] {
        guard let data = defaults.data(forKey: SharedKeys.visitedSites),
              let visited = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return [:]
        }
        return visited
    }

    // MARK: - 构建响应

    /// 构建给 background.js 的完整配置响应
    func buildConfigResponse(for domain: String) -> [String: Any] {
        markSiteVisited(domain)
        let config = globalConfig
        let rules  = siteRules
        let rule   = rules[domain.mainDomain]

        // 决定使用哪个主题
        let themeId = (rule?.themeId?.isEmpty == false ? rule!.themeId : nil)
                    ?? config.defaultThemeId
        let theme = allThemes.first { $0.id == themeId } ?? DarkTheme.builtins[1]

        return [
            "config": [
                "mode": config.mode.rawValue,
                // ★ 必须传 defaultThemeId，popup 初始化时以此为准
                "defaultThemeId": config.defaultThemeId,
                "dimImages": config.dimImages,
                "ignoreNativeDarkMode": config.ignoreNativeDarkMode,
                "performanceMode": config.performanceMode,
                "appLanguage": config.appLanguage.rawValue,
                "siteMode": rule?.mode?.rawValue ?? "follow",
                "siteThemeId": rule?.themeId ?? "",
                // 定时深色模式
                "scheduleEnabled": config.scheduleEnabled,
                "scheduleTriggerSource": config.scheduleTriggerSource.rawValue,
                "scheduleStartHour": config.scheduleStartHour,
                "scheduleStartMinute": config.scheduleStartMinute,
                "scheduleEndHour": config.scheduleEndHour,
                "scheduleEndMinute": config.scheduleEndMinute,
                "sunScheduleSunriseHour": config.sunScheduleSunriseHour,
                "sunScheduleSunriseMinute": config.sunScheduleSunriseMinute,
                "sunScheduleSunsetHour": config.sunScheduleSunsetHour,
                "sunScheduleSunsetMinute": config.sunScheduleSunsetMinute,
                "hideCookieBanners": config.hideCookieBanners,
                "lowBatteryEyeCareEnabled": config.lowBatteryEyeCareEnabled,
                "lowBatteryThreshold": config.lowBatteryThreshold,
                "lowBatteryRestoreOnCharging": config.lowBatteryRestoreOnCharging,
                "lowBatteryModeActive": config.lowBatteryModeActive,
                "dailyEyeCareNotificationEnabled": config.dailyEyeCareNotificationEnabled,
                "dailyEyeCareNotificationHour": config.dailyEyeCareNotificationHour,
                "dailyEyeCareNotificationMinute": config.dailyEyeCareNotificationMinute,
                "weeklyEyeCareNotificationEnabled": config.weeklyEyeCareNotificationEnabled,
                "weeklyEyeCareNotificationWeekday": config.weeklyEyeCareNotificationWeekday,
                "weeklyEyeCareNotificationHour": config.weeklyEyeCareNotificationHour,
                "weeklyEyeCareNotificationMinute": config.weeklyEyeCareNotificationMinute,
                // 站点精细调节
                "siteBrightness": rule?.brightness ?? 1.0,
                "siteContrast": rule?.contrast ?? 1.0,
                "siteFocusMode": rule?.focusMode ?? false
            ] as [String: Any],
            "theme": [
                "id": theme.id,
                "backgroundColor": theme.backgroundColor,
                "textColor": theme.textColor,
                "secondaryTextColor": theme.secondaryTextColor,
                "linkColor": theme.linkColor,
                "borderColor": theme.borderColor,
                "imageBrightness": theme.imageBrightness,
                "imageGrayscale": theme.imageGrayscale,
                "category": theme.category.rawValue,
                "eyeCareScore": theme.eyeCareScore,
                "warmthLevel": theme.warmthLevel,
                "dimImages": config.dimImages
            ] as [String: Any]
        ]
    }

    /// 将所有主题序列化为 JS 可读的字典数组
    func allThemesAsDicts() -> [[String: Any]] {
        allThemes.map { theme in
            [
                "id": theme.id,
                "name": theme.name,
                "isBuiltin": theme.isBuiltin,
                "backgroundColor": theme.backgroundColor,
                "textColor": theme.textColor,
                "secondaryTextColor": theme.secondaryTextColor,
                "linkColor": theme.linkColor,
                "borderColor": theme.borderColor,
                "imageBrightness": theme.imageBrightness,
                "imageGrayscale": theme.imageGrayscale,
                "category": theme.category.rawValue,
                "eyeCareScore": theme.eyeCareScore,
                "warmthLevel": theme.warmthLevel
            ] as [String: Any]
        }
    }

    // MARK: - 写入

    func saveSiteRule(
        domain: String,
        modeRaw: String?,
        themeId: String?,
        brightness: Double? = nil,   // nil 表示保留现有值
        contrast: Double? = nil,     // nil 表示保留现有值
        focusMode: Bool? = nil       // nil 表示保留现有值
    ) {
        var rules = siteRules
        let mode = modeRaw.flatMap { SiteMode(rawValue: $0) }
        let cleanThemeId = themeId?.isEmpty == false ? themeId : nil
        let domainKey = domain.mainDomain.isEmpty ? "unknown" : domain.mainDomain

        // 读取现有规则，用于保留精调参数（popup 保存时不会传这些值）
        let existing = rules[domainKey]
        let finalBrightness = brightness ?? existing?.brightness ?? 1.0
        let finalContrast = contrast ?? existing?.contrast ?? 1.0
        let finalFocusMode = focusMode ?? existing?.focusMode ?? false

        let hasFinetuning = abs(finalBrightness - 1.0) > 0.01 || abs(finalContrast - 1.0) > 0.01 || finalFocusMode

        if mode == nil && cleanThemeId == nil && !hasFinetuning {
            rules.removeValue(forKey: domainKey)
        } else {
            rules[domainKey] = SiteRule(
                mode: mode,
                themeId: cleanThemeId,
                updatedAt: Date(),
                brightness: finalBrightness,
                contrast: finalContrast,
                focusMode: finalFocusMode
            )
        }

        guard let data = try? JSONEncoder().encode(rules) else { return }
        _ = persistDataWithRetry(data, key: SharedKeys.siteRules)
        logger.debug("已保存站点规则：domain=\(domainKey), mode=\(modeRaw ?? "nil")")
    }

    private func markSiteVisited(_ domain: String) {
        let domainKey = domain.mainDomain
        guard !domainKey.isEmpty else { return }

        var visited = visitedSites
        visited[domainKey] = Date()

        if visited.count > 200 {
            let sorted = visited.sorted { $0.value > $1.value }
            visited = Dictionary(
                uniqueKeysWithValues: sorted.prefix(200).map { ($0.key, $0.value) }
            )
        }

        guard let data = try? JSONEncoder().encode(visited) else { return }
        _ = persistDataWithRetry(data, key: SharedKeys.visitedSites)
    }

    func saveGlobalConfig(from dict: [String: Any]) {
        var config = globalConfig
        if let modeStr = dict["mode"] as? String, let mode = DarkMode(rawValue: modeStr) {
            config.mode = mode
        }
        if let dimImages = dict["dimImages"] as? Bool {
            config.dimImages = dimImages
        }
        if let ignore = dict["ignoreNativeDarkMode"] as? Bool {
            config.ignoreNativeDarkMode = ignore
        }
        if let performanceMode = dict["performanceMode"] as? Bool {
            config.performanceMode = performanceMode
        }
        if let appLanguageRaw = dict["appLanguage"] as? String,
           let appLanguage = AppLanguageOption(rawValue: appLanguageRaw) {
            config.appLanguage = appLanguage
        }
        if let themeId = dict["defaultThemeId"] as? String {
            config.defaultThemeId = themeId
        }
        if let scheduleEnabled = dict["scheduleEnabled"] as? Bool {
            config.scheduleEnabled = scheduleEnabled
        }
        if let sourceRaw = dict["scheduleTriggerSource"] as? String,
           let source = ScheduleTriggerSource(rawValue: sourceRaw) {
            config.scheduleTriggerSource = source
        }
        if let scheduleStartHour = dict["scheduleStartHour"] as? Int {
            config.scheduleStartHour = scheduleStartHour
        }
        if let scheduleStartMinute = dict["scheduleStartMinute"] as? Int {
            config.scheduleStartMinute = scheduleStartMinute
        }
        if let scheduleEndHour = dict["scheduleEndHour"] as? Int {
            config.scheduleEndHour = scheduleEndHour
        }
        if let scheduleEndMinute = dict["scheduleEndMinute"] as? Int {
            config.scheduleEndMinute = scheduleEndMinute
        }
        if let sunriseHour = dict["sunScheduleSunriseHour"] as? Int {
            config.sunScheduleSunriseHour = sunriseHour
        }
        if let sunriseMinute = dict["sunScheduleSunriseMinute"] as? Int {
            config.sunScheduleSunriseMinute = sunriseMinute
        }
        if let sunsetHour = dict["sunScheduleSunsetHour"] as? Int {
            config.sunScheduleSunsetHour = sunsetHour
        }
        if let sunsetMinute = dict["sunScheduleSunsetMinute"] as? Int {
            config.sunScheduleSunsetMinute = sunsetMinute
        }
        if let latitude = dict["sunLatitude"] as? Double {
            config.sunLatitude = latitude
        }
        if let longitude = dict["sunLongitude"] as? Double {
            config.sunLongitude = longitude
        }
        if let lowBatteryEnabled = dict["lowBatteryEyeCareEnabled"] as? Bool {
            config.lowBatteryEyeCareEnabled = lowBatteryEnabled
        }
        if let lowBatteryThreshold = dict["lowBatteryThreshold"] as? Int {
            config.lowBatteryThreshold = [10, 20, 30].contains(lowBatteryThreshold) ? lowBatteryThreshold : config.lowBatteryThreshold
        }
        if let restoreOnCharging = dict["lowBatteryRestoreOnCharging"] as? Bool {
            config.lowBatteryRestoreOnCharging = restoreOnCharging
        }
        if let lowBatteryModeActive = dict["lowBatteryModeActive"] as? Bool {
            config.lowBatteryModeActive = lowBatteryModeActive
        }
        if let hideCookieBanners = dict["hideCookieBanners"] as? Bool {
            config.hideCookieBanners = hideCookieBanners
        }
        if let dailyEnabled = dict["dailyEyeCareNotificationEnabled"] as? Bool {
            config.dailyEyeCareNotificationEnabled = dailyEnabled
        }
        if let dailyHour = dict["dailyEyeCareNotificationHour"] as? Int {
            config.dailyEyeCareNotificationHour = min(max(dailyHour, 0), 23)
        }
        if let dailyMinute = dict["dailyEyeCareNotificationMinute"] as? Int {
            config.dailyEyeCareNotificationMinute = min(max(dailyMinute, 0), 59)
        }
        if let weeklyEnabled = dict["weeklyEyeCareNotificationEnabled"] as? Bool {
            config.weeklyEyeCareNotificationEnabled = weeklyEnabled
        }
        if let weeklyWeekday = dict["weeklyEyeCareNotificationWeekday"] as? Int {
            config.weeklyEyeCareNotificationWeekday = min(max(weeklyWeekday, 1), 7)
        }
        if let weeklyHour = dict["weeklyEyeCareNotificationHour"] as? Int {
            config.weeklyEyeCareNotificationHour = min(max(weeklyHour, 0), 23)
        }
        if let weeklyMinute = dict["weeklyEyeCareNotificationMinute"] as? Int {
            config.weeklyEyeCareNotificationMinute = min(max(weeklyMinute, 0), 59)
        }

        guard let data = try? JSONEncoder().encode(config) else { return }
        _ = persistDataWithRetry(data, key: SharedKeys.globalConfig)
    }

    func appendErrorLog(domain: String, errorMsg: String, timeStr: String) {
        var logs: [ErrorLog]
        if let data = defaults.data(forKey: SharedKeys.errorLogs),
           let existing = try? JSONDecoder().decode([ErrorLog].self, from: data) {
            logs = existing
        } else {
            logs = []
        }

        let formatter = ISO8601DateFormatter()
        let time = formatter.date(from: timeStr) ?? Date()
        logs.append(ErrorLog(domain: domain, errorMsg: errorMsg, time: time))

        // 最多保留10条
        if logs.count > 10 { logs.removeFirst(logs.count - 10) }

        if let data = try? JSONEncoder().encode(logs) {
            _ = persistDataWithRetry(data, key: SharedKeys.errorLogs)
        }
    }

    func appendFeedback(_ dict: [String: Any]) {
        var records: [FeedbackRecord]
        if let data = defaults.data(forKey: SharedKeys.feedbackRecords),
           let existing = try? JSONDecoder().decode([FeedbackRecord].self, from: data) {
            records = existing
        } else {
            records = []
        }

        let formatter = ISO8601DateFormatter()
        let time = (dict["time"] as? String).flatMap { formatter.date(from: $0) } ?? Date()

        records.append(FeedbackRecord(
            domain:  dict["domain"]  as? String ?? "",
            themeId: dict["themeId"] as? String ?? "",
            content: dict["content"] as? String ?? "",
            time: time
        ))

        // 最多保留20条
        if records.count > 20 { records.removeFirst(records.count - 20) }

        if let data = try? JSONEncoder().encode(records) {
            _ = persistDataWithRetry(data, key: SharedKeys.feedbackRecords)
        }
    }

    func appendEyeCareUsage(
        domain: String,
        durationSeconds: Double,
        themeId: String,
        timeStr: String?
    ) {
        let safeDuration = max(durationSeconds, 0)
        guard safeDuration > 0.1 else { return }

        let formatter = ISO8601DateFormatter()
        let eventTime = timeStr.flatMap { formatter.date(from: $0) } ?? Date()
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: eventTime)
        let dayKey = Self.dayKey(for: day)
        let domainKey = domain.mainDomain
        let resolvedThemeId = themeId.isEmpty ? globalConfig.defaultThemeId : themeId

        var dailyRecords: [DailyEyeCareRecord] = []
        if let data = defaults.data(forKey: SharedKeys.eyeCareDailyRecords),
           let decoded = try? JSONDecoder().decode([DailyEyeCareRecord].self, from: data) {
            dailyRecords = decoded
        }

        var siteDurations: [String: [String: TimeInterval]] = [:]
        if let data = defaults.data(forKey: SharedKeys.eyeCareSiteDurations),
           let decoded = try? JSONDecoder().decode([String: [String: TimeInterval]].self, from: data) {
            siteDurations = decoded
        }

        var currentRecord = dailyRecords.first { calendar.isDate($0.date, inSameDayAs: day) }
            ?? DailyEyeCareRecord(date: day, darkModeDuration: 0, sitesCount: 0, dominantThemeId: resolvedThemeId)
        currentRecord.darkModeDuration += safeDuration
        currentRecord.dominantThemeId = resolvedThemeId

        var daySites = siteDurations[dayKey] ?? [:]
        daySites[domainKey] = (daySites[domainKey] ?? 0) + safeDuration
        siteDurations[dayKey] = daySites
        currentRecord.sitesCount = daySites.count

        if let idx = dailyRecords.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: day) }) {
            dailyRecords[idx] = currentRecord
        } else {
            dailyRecords.append(currentRecord)
        }
        dailyRecords.sort { $0.date < $1.date }
        if dailyRecords.count > 120 {
            dailyRecords.removeFirst(dailyRecords.count - 120)
        }

        if let dailyData = try? JSONEncoder().encode(dailyRecords) {
            _ = persistDataWithRetry(dailyData, key: SharedKeys.eyeCareDailyRecords)
        }
        if let siteData = try? JSONEncoder().encode(siteDurations) {
            _ = persistDataWithRetry(siteData, key: SharedKeys.eyeCareSiteDurations)
        }
    }

    private static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
