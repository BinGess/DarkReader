//
//  ThemeManagerView.swift
//  DarkReader
//
//  Sustainability Platform 风格主题管理：展示内置与自定义主题并支持配置管理
//

import SwiftUI

struct ThemeManagerView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @State private var showEditor = false
    @State private var showThemeLibrary = false
    @State private var editingTheme: DarkTheme? = nil
    @State private var themeToDelete: DarkTheme? = nil
    @State private var showDeleteConfirm = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationView {
            ZStack {
                SustainabilityBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 当前激活主题大展示卡
                        activeThemeShowcase
                            .padding(.horizontal)
                            .padding(.top, 8)

                        // 内置主题网格
                        sectionHeader("内置主题")
                            .padding(.horizontal)
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(dataManager.themes.filter { $0.isBuiltin }) { theme in
                                ThemeCard(
                                    theme: theme,
                                    isDefault: theme.id == dataManager.globalConfig.defaultThemeId,
                                    appLanguage: dataManager.globalConfig.appLanguage,
                                    onSetDefault: { setDefault(theme) },
                                    onEdit: { editTheme(theme) },
                                    onDelete: nil
                                )
                            }
                        }
                        .padding(.horizontal)

                        // 自定义主题网格（有时才显示）
                        let customThemes = dataManager.themes
                            .filter { !$0.isBuiltin }
                            .sorted { $0.updatedAt > $1.updatedAt }
                        if !customThemes.isEmpty {
                            sectionHeader("自定义主题")
                                .padding(.horizontal)
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(customThemes) { theme in
                                    ThemeCard(
                                        theme: theme,
                                        isDefault: theme.id == dataManager.globalConfig.defaultThemeId,
                                        appLanguage: dataManager.globalConfig.appLanguage,
                                        onSetDefault: { setDefault(theme) },
                                        onEdit: { editTheme(theme) },
                                        onDelete: { requestDelete(theme) }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.bottom, 90)
                }
                .font(SustainabilityTypography.body)
            }
            .overlay(alignment: .bottomTrailing) {
                floatingAddButton
            }
            .navigationTitle("主题")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sustainabilityChrome()
        .sheet(isPresented: $showEditor) {
            ThemeEditorView(existingTheme: editingTheme)
                .environmentObject(dataManager)
        }
        .sheet(isPresented: $showThemeLibrary) {
            ThemeLibraryView(presets: DarkTheme.libraryPresets) { preset in
                addThemeFromLibrary(preset)
            }
            .environmentObject(dataManager)
        }
        .alert("删除主题", isPresented: $showDeleteConfirm, presenting: themeToDelete) { theme in
            Button("删除", role: .destructive) {
                dataManager.deleteTheme(id: theme.id)
            }
            Button("取消", role: .cancel) {}
        } message: { theme in
            Text(
                String(
                    format: NSLocalizedString("theme.delete.message", comment: ""),
                    theme.localizedDisplayName(language: dataManager.globalConfig.appLanguage)
                )
            )
        }
    }

    // MARK: - 当前激活主题大展示

    private var activeThemeShowcase: some View {
        let activeTheme = dataManager.defaultTheme
        return SustainabilityCard {
            VStack(alignment: .leading, spacing: 14) {
                // 标题行
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("当前默认主题")
                            .font(SustainabilityTypography.caption)
                            .foregroundColor(.secondary)
                        Text(activeTheme.localizedDisplayName(language: dataManager.globalConfig.appLanguage))
                            .font(SustainabilityTypography.title)
                    }
                    Spacer()
                    SustainabilityStatusPill(
                        icon: "checkmark.seal.fill",
                        text: "默认",
                        color: SustainabilityPalette.primary
                    )
                }

                // 大尺寸颜色预览
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(activeTheme.backgroundSwiftUIColor)
                        .frame(height: 110)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke((Color(hex: activeTheme.borderColor) ?? .gray).opacity(0.4), lineWidth: 1)
                        )

                    VStack(spacing: 8) {
                        Text("夜览 · 护眼深色阅读")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(activeTheme.textSwiftUIColor)
                        HStack(spacing: 16) {
                            swatch(activeTheme.backgroundSwiftUIColor, label: "背景")
                            swatch(activeTheme.textSwiftUIColor, label: "文字")
                            swatch(activeTheme.linkSwiftUIColor, label: "链接")
                            swatch(Color(hex: activeTheme.borderColor) ?? .gray, label: "边框")
                        }
                    }
                }

                // 统计行 + 切换提示
                HStack(spacing: 12) {
                    statChip(
                        icon: "paintpalette.fill",
                        label: "共 \(dataManager.themes.count) 套主题",
                        color: SustainabilityPalette.primary
                    )
                    statChip(
                        icon: "square.and.pencil",
                        label: "自定义 \(dataManager.themes.filter { !$0.isBuiltin }.count) 套",
                        color: SustainabilityPalette.cta
                    )
                    Spacer()
                    Text("点击卡片切换")
                        .font(SustainabilityTypography.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func swatch(_ color: Color, label: String) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 20, height: 20)
                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
            Text(label)
                .font(.system(size: 9))
                .foregroundColor((Color(hex: "#e0e0e0") ?? .white).opacity(0.7))
        }
    }

    private func statChip(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
            Text(label)
                .font(SustainabilityTypography.caption)
                .foregroundColor(.secondary)
        }
    }

    private var floatingAddButton: some View {
        Menu {
            Button("新建主题", systemImage: "square.and.pencil") {
                editingTheme = nil
                showEditor = true
            }
            Button("主题库", systemImage: "books.vertical") {
                showThemeLibrary = true
            }
        } label: {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [SustainabilityPalette.primary, SustainabilityPalette.cta],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 58, height: 58)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
                .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
                .padding(.trailing, 20)
                .padding(.bottom, 20)
        }
        .accessibilityLabel("添加主题")
    }

    private func setDefault(_ theme: DarkTheme) {
        dataManager.globalConfig.defaultThemeId = theme.id
        dataManager.saveConfig()
    }

    private func editTheme(_ theme: DarkTheme) {
        editingTheme = theme
        showEditor = true
    }

    private func requestDelete(_ theme: DarkTheme) {
        themeToDelete = theme
        showDeleteConfirm = true
    }

    private func addThemeFromLibrary(_ preset: ThemeLibraryPreset) {
        var themeName = preset.name
        let existingNames = Set(dataManager.themes.map { $0.name })
        var index = 2
        while existingNames.contains(themeName) {
            themeName = "\(preset.name) \(index)"
            index += 1
        }

        var newId = DarkTheme.generateCustomId()
        while dataManager.themes.contains(where: { $0.id == newId }) {
            newId = DarkTheme.generateCustomId()
        }

        let mappedCategory = mappedThemeCategory(from: preset.category)
        let theme = DarkTheme(
            id: newId,
            name: themeName,
            backgroundColor: preset.backgroundColor,
            textColor: preset.textColor,
            secondaryTextColor: preset.secondaryTextColor,
            linkColor: preset.linkColor,
            borderColor: preset.borderColor,
            isBuiltin: false,
            category: mappedCategory,
            eyeCareScore: mappedCategory.typicalEyeCareScore,
            warmthLevel: mappedCategory.typicalWarmthLevel,
            createdAt: Date(),
            updatedAt: Date()
        )
        dataManager.addCustomTheme(theme)
    }

    private func mappedThemeCategory(from rawCategory: String) -> ThemeCategory {
        switch rawCategory {
        case "默认主题", "六色", "作者作品":
            return .reading
        case "颜色情绪":
            return .nature
        case "果味满满":
            return .warmLight
        case "其他":
            return .eyeCare
        default:
            return .reading
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStringKey(title))
                .font(SustainabilityTypography.title)
        }
    }
}

struct ThemeCard: View {
    let theme: DarkTheme
    let isDefault: Bool
    let appLanguage: AppLanguageOption
    let onSetDefault: (() -> Void)?
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    var body: some View {
        SustainabilityCard {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(theme.backgroundSwiftUIColor)
                        .frame(height: 82)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke((Color(hex: theme.borderColor) ?? .gray).opacity(0.5), lineWidth: 1)
                        )

                    VStack(spacing: 6) {
                        Text("Aa")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(theme.textSwiftUIColor)
                        HStack(spacing: 5) {
                            Circle().fill(theme.textSwiftUIColor).frame(width: 7, height: 7)
                            Circle().fill(theme.linkSwiftUIColor).frame(width: 7, height: 7)
                            Circle().fill(Color(hex: theme.borderColor) ?? .gray).frame(width: 7, height: 7)
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onSetDefault?()
                }

                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(theme.localizedDisplayName(language: appLanguage))
                            .font(SustainabilityTypography.bodyStrong)
                            .lineLimit(1)
                        Text(eyeCareBadgeText)
                            .font(SustainabilityTypography.caption)
                            .foregroundColor(SustainabilityPalette.primary)
                        Text(LocalizedStringKey(isDefault ? "当前默认主题" : "点击可设为默认"))
                            .font(SustainabilityTypography.caption)
                            .foregroundColor(isDefault ? SustainabilityPalette.primary : .secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSetDefault?()
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        if let onEdit {
                            Button(action: onEdit) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(SustainabilityTypography.subBodyStrong)
                                    .foregroundColor(SustainabilityPalette.cta)
                                    .frame(width: 32, height: 32)
                                    .background(SustainabilityPalette.cta.opacity(0.16))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("主题详情")
                        }

                        if let onDelete {
                            Button(role: .destructive, action: onDelete) {
                                Image(systemName: "trash")
                                    .font(SustainabilityTypography.captionStrong)
                                    .foregroundColor(.secondary)
                                    .frame(width: 32, height: 32)
                                    .background(Color.secondary.opacity(0.14))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("删除主题")
                        }
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                if isDefault {
                    SustainabilityStatusPill(
                        icon: "checkmark.seal.fill",
                        text: "默认",
                        color: SustainabilityPalette.primary
                    )
                    .scaleEffect(0.86)
                    .padding(.top, 4)
                    .padding(.trailing, 4)
                }
            }
        }
    }

    private var eyeCareBadgeText: String {
        let stars = String(repeating: "★", count: max(theme.eyeCareScore, 1))
        let blanks = String(repeating: "☆", count: max(5 - theme.eyeCareScore, 0))
        return "🟢 护眼 \(stars)\(blanks)"
    }
}

struct ThemeLibraryView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @Environment(\.dismiss) private var dismiss
    let presets: [ThemeLibraryPreset]
    let onAdd: (ThemeLibraryPreset) -> Void

    var body: some View {
        NavigationView {
            ZStack {
                SustainabilityBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(groupedPresets, id: \.0) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(LocalizedStringKey(section.0))
                                    .font(SustainabilityTypography.bodyStrong)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)

                                SustainabilityCard {
                                    VStack(spacing: 0) {
                                        ForEach(Array(section.1.enumerated()), id: \.element.id) { index, preset in
                                            ThemeLibraryRow(
                                                preset: preset,
                                                isAdded: isAdded(preset)
                                            ) {
                                                onAdd(preset)
                                            }
                                            if index < section.1.count - 1 {
                                                Divider()
                                                    .padding(.leading, 54)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.bottom, 28)
                    .padding(.top, 8)
                }
                .font(SustainabilityTypography.body)
            }
            .navigationTitle("主题库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .sustainabilityChrome()
    }

    private var groupedPresets: [(String, [ThemeLibraryPreset])] {
        let order = ["默认主题", "六色", "作者作品", "颜色情绪", "果味满满", "其他"]
        return order.compactMap { category in
            let items = presets.filter { $0.category == category }
            return items.isEmpty ? nil : (category, items)
        }
    }

    private func isAdded(_ preset: ThemeLibraryPreset) -> Bool {
        dataManager.themes.contains { $0.name == preset.name }
    }
}

private struct ThemeLibraryRow: View {
    let preset: ThemeLibraryPreset
    let isAdded: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: preset.accentColor) ?? SustainabilityPalette.neutral)
                .frame(width: 36, height: 36)
                .overlay {
                    Text("字")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white.opacity(0.95))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(preset.name))
                    .font(SustainabilityTypography.bodyStrong)
                    .foregroundColor(.primary)
            }

            Spacer()

            if isAdded {
                Image(systemName: "checkmark")
                    .font(SustainabilityTypography.subBodyStrong)
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
            } else {
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(SustainabilityTypography.subBodyStrong)
                        .foregroundColor(SustainabilityPalette.cta)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .sustainabilityInteractiveRow()
    }
}
