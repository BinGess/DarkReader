import SwiftUI

enum SustainabilityPalette {
    static let primary = Color(hex: "#F59E0B") ?? .orange
    static let secondary = Color(hex: "#FBBF24") ?? .yellow
    static let cta = Color(hex: "#6366F1") ?? .indigo
    static let info = Color(hex: "#38BDF8") ?? .blue
    static let neutral = Color(hex: "#94A3B8") ?? .gray
    static let warm = Color(hex: "#F97316") ?? .orange
    static let success = Color(hex: "#22C55E") ?? .green
    static let danger = Color(hex: "#EF4444") ?? .red

    static let backgroundLightTop = Color(hex: "#F7FAFF") ?? Color(.systemGroupedBackground)
    static let backgroundLightBottom = Color(hex: "#E6EDF7") ?? Color(.secondarySystemGroupedBackground)
    static let backgroundDarkTop = Color(hex: "#0C1224") ?? Color(.systemBackground)
    static let backgroundDarkBottom = Color(hex: "#182240") ?? Color(.secondarySystemBackground)

    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.1) : Color.white.opacity(0.9)
    }

    static func border(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.18) : Color(hex: "#D1D9E6") ?? Color.gray.opacity(0.2)
    }

    static func elevated(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.03)
    }

    static func chromeBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? (Color(hex: "#0F172A") ?? .black).opacity(0.92) : Color.white.opacity(0.97)
    }

    static func headline(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#F8FAFC") ?? .white : Color(hex: "#0F172A") ?? .primary
    }

    static func body(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#CBD5E1") ?? .secondary : Color(hex: "#475569") ?? .secondary
    }
}

enum SustainabilityTypography {
    static let title = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 16, weight: .regular, design: .rounded)
    static let bodyStrong = Font.system(size: 16, weight: .semibold, design: .rounded)
    static let subBody = Font.system(size: 14, weight: .regular, design: .rounded)
    static let subBodyStrong = Font.system(size: 14, weight: .semibold, design: .rounded)
    static let caption = Font.system(size: 12, weight: .regular, design: .rounded)
    static let captionStrong = Font.system(size: 12, weight: .semibold, design: .rounded)
}

enum SustainabilityMetrics {
    static let touchMinHeight: CGFloat = 44
    static let rowVerticalPadding: CGFloat = 8
    static let cardInnerPadding: CGFloat = 14
    static let pageHorizontalPadding: CGFloat = 16
    static let pageTopPadding: CGFloat = 12
    static let pageBottomPadding: CGFloat = 28
    static let sectionGap: CGFloat = 14
    static let listRowInsetVertical: CGFloat = 8
    static let listRowInsetHorizontal: CGFloat = 16
    static let heroCornerRadius: CGFloat = 20
    static let moduleCornerRadius: CGFloat = 16
    static let controlCornerRadius: CGFloat = 12
    static let cardCornerRadius: CGFloat = 18
}

struct SustainabilityBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [SustainabilityPalette.backgroundDarkTop, SustainabilityPalette.backgroundDarkBottom]
                    : [SustainabilityPalette.backgroundLightTop, SustainabilityPalette.backgroundLightBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(SustainabilityPalette.primary.opacity(colorScheme == .dark ? 0.15 : 0.18))
                .frame(width: 260)
                .blur(radius: 26)
                .offset(x: -130, y: -230)

            Circle()
                .fill(SustainabilityPalette.cta.opacity(colorScheme == .dark ? 0.12 : 0.14))
                .frame(width: 240)
                .blur(radius: 24)
                .offset(x: 130, y: 230)

            Circle()
                .fill(SustainabilityPalette.info.opacity(colorScheme == .dark ? 0.09 : 0.08))
                .frame(width: 180)
                .blur(radius: 18)
                .offset(x: 160, y: -190)
        }
        .ignoresSafeArea()
    }
}

struct SustainabilityCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(SustainabilityMetrics.cardInnerPadding)
            .background(SustainabilityCardBackground())
    }
}

private struct SustainabilityCardBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: SustainabilityMetrics.cardCornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        SustainabilityPalette.surface(colorScheme),
                        SustainabilityPalette.surface(colorScheme).opacity(colorScheme == .dark ? 0.82 : 0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: SustainabilityMetrics.cardCornerRadius, style: .continuous)
                    .stroke(SustainabilityPalette.border(colorScheme), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.06), radius: 14, x: 0, y: 8)
    }
}

struct SustainabilityStatusPill: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(SustainabilityTypography.caption)
            Text(LocalizedStringKey(text))
                .font(SustainabilityTypography.captionStrong)
                .lineLimit(1)
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.16))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(color.opacity(0.34), lineWidth: 0.8)
        )
    }
}

struct SustainabilitySectionTitle: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(LocalizedStringKey(title))
                .font(SustainabilityTypography.title)
            if let subtitle {
                Text(LocalizedStringKey(subtitle))
                    .font(SustainabilityTypography.caption)
                    .foregroundColor(.secondary)
                    .lineSpacing(1)
            }
        }
    }
}

extension View {
    func sustainabilityChrome() -> some View {
        modifier(SustainabilityChromeModifier())
    }

    func sustainabilityInteractiveRow() -> some View {
        modifier(SustainabilityInteractiveRowModifier())
    }
}

private struct SustainabilityChromeModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(SustainabilityPalette.chromeBackground(colorScheme), for: .navigationBar)
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarBackground(SustainabilityPalette.chromeBackground(colorScheme), for: .tabBar)
        } else {
            content
        }
    }
}

private struct SustainabilityInteractiveRowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, SustainabilityMetrics.rowVerticalPadding)
            .frame(minHeight: SustainabilityMetrics.touchMinHeight)
            .contentShape(Rectangle())
    }
}
