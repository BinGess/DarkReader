//
//  iCloudSyncManager.swift
//  DarkReader
//
//  iCloud 同步管理器：通过 NSUbiquitousKeyValueStore 同步自定义主题和站点规则
//
//  同步范围：
//    ✅ 自定义主题（isBuiltin == false）
//    ✅ 站点规则（SiteRules 字典）
//    ❌ 全局开关状态（仅保存在本地，设备各自独立）
//    ❌ 错误日志（本地专用）
//

import Foundation
import Combine
import SwiftUI
import os.log

enum SyncStatus {
    case idle
    case syncing
    case pending
    case success
    case failed
    case unavailable
}

class iCloudSyncManager: ObservableObject {

    // 全局单例
    static let shared = iCloudSyncManager()

    private let logger = Logger(subsystem: "com.timmy.darkreader", category: "iCloudSync")
    private let kvStore = NSUbiquitousKeyValueStore.default

    // iCloud 同步开关（持久化在本地 UserDefaults）
    @AppStorage("DarkReader_iCloudSyncEnabled") var isSyncEnabled: Bool = true

    @Published var lastSyncDate: Date? = nil
    @Published var lastSyncStatus: SyncStatus = .idle
    @Published var lastSyncMessage: String? = nil

    // MARK: - iCloud Key 常量
    private enum CloudKeys {
        static let customThemes = "dr_cloud_custom_themes"
        static let siteRules    = "dr_cloud_site_rules"
    }

    private var uploadWorkItem: DispatchWorkItem?

    private init() {
        setupObserver()
    }

    // MARK: - 启动/停止监听

    private func setupObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(kvStoreDidChangeExternally),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvStore
        )
    }

    /// 开始同步（上传当前数据到 iCloud）
    func startSync(themes: [DarkTheme], siteRules: SiteRules) {
        guard isSyncEnabled else { return }
        guard ensureICloudAvailable() else { return }
        pullFromCloud()
        scheduleUpload(themes: themes, siteRules: siteRules)
    }

    /// 停止同步（不删除云端数据）
    func stopSync() {
        uploadWorkItem?.cancel()
        uploadWorkItem = nil
        logger.info("iCloud 同步已停止")
    }

    // MARK: - 数据上传

    func scheduleUpload(themes: [DarkTheme], siteRules: SiteRules, debounce: TimeInterval = 0.35) {
        guard isSyncEnabled else { return }
        uploadWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.uploadToCloud(themes: themes, siteRules: siteRules)
        }
        uploadWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + debounce, execute: item)
    }

    func uploadToCloud(themes: [DarkTheme], siteRules: SiteRules) {
        guard isSyncEnabled else { return }
        guard ensureICloudAvailable() else { return }

        // 仅同步自定义主题
        let customThemes = themes.filter { !$0.isBuiltin }

        DispatchQueue.main.async {
            self.lastSyncStatus = .syncing
            self.lastSyncMessage = "正在同步…"
        }

        do {
            let themesData = try JSONEncoder().encode(customThemes)
            let rulesData  = try JSONEncoder().encode(siteRules)

            kvStore.set(themesData, forKey: CloudKeys.customThemes)
            kvStore.set(rulesData,  forKey: CloudKeys.siteRules)
            let syncCommitted = kvStore.synchronize()

            DispatchQueue.main.async {
                self.lastSyncDate = Date()
                self.lastSyncStatus = syncCommitted ? .success : .pending
                self.lastSyncMessage = syncCommitted ? nil : "iCloud 队列繁忙，系统会稍后自动完成。"
            }

            logger.info("iCloud 同步已提交：\(customThemes.count) 个自定义主题，\(siteRules.count) 条站点规则，committed=\(syncCommitted)")
        } catch {
            DispatchQueue.main.async {
                self.lastSyncStatus = .failed
                self.lastSyncMessage = "编码失败：\(error.localizedDescription)"
            }
            logger.error("iCloud 同步失败：\(error)")
        }
    }

    // MARK: - 数据下载（接收远端变更）

    @objc private func kvStoreDidChangeExternally(_ notification: Notification) {
        guard isSyncEnabled else { return }
        guard ensureICloudAvailable() else { return }
        logger.info("收到 iCloud 变更通知，开始拉取最新数据")
        pullFromCloud()
    }

    /// 从 iCloud 拉取数据并合并到本地
    func pullFromCloud() {
        guard isSyncEnabled else { return }
        guard ensureICloudAvailable() else { return }

        _ = kvStore.synchronize()

        var remoteThemes: [DarkTheme] = []
        var remoteRules: SiteRules = [:]

        // 解码远端主题
        if let data = kvStore.data(forKey: CloudKeys.customThemes),
           let themes = try? JSONDecoder().decode([DarkTheme].self, from: data) {
            remoteThemes = themes
        }

        // 解码远端站点规则
        if let data = kvStore.data(forKey: CloudKeys.siteRules),
           let rules = try? JSONDecoder().decode(SiteRules.self, from: data) {
            remoteRules = rules
        }

        // 合并到本地 SharedDataManager
        DispatchQueue.main.async {
            SharedDataManager.shared.mergeFromiCloud(
                customThemes: remoteThemes,
                remoteRules: remoteRules
            )
            self.lastSyncDate = Date()
            self.lastSyncStatus = .success
            self.lastSyncMessage = nil
        }
    }

    // MARK: - 清除云端数据

    func clearAll() {
        kvStore.removeObject(forKey: CloudKeys.customThemes)
        kvStore.removeObject(forKey: CloudKeys.siteRules)
        kvStore.synchronize()
        DispatchQueue.main.async {
            self.lastSyncStatus = .idle
            self.lastSyncDate = nil
            self.lastSyncMessage = nil
        }
        logger.info("iCloud 数据已清除")
    }

    private func ensureICloudAvailable() -> Bool {
        let available = FileManager.default.ubiquityIdentityToken != nil
        if !available {
            DispatchQueue.main.async {
                self.lastSyncStatus = .unavailable
                self.lastSyncMessage = "未检测到 iCloud 账号，请检查系统设置中的 iCloud Drive。"
            }
            logger.warning("iCloud 不可用：ubiquityIdentityToken 为空")
        }
        return available
    }
}
