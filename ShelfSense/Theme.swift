import SwiftUI

// MARK: - Color hex initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255)
    }
}

// MARK: - Design tokens

enum Theme {
    static let primary         = Color(red: 27/255,  green: 94/255,  blue: 32/255)   // #1B5E20
    static let mint            = Color(red: 0/255,   green: 200/255, blue: 83/255)   // #00C853
    static let appBackground   = Color(.systemGroupedBackground)
    static let cardBackground  = Color(.secondarySystemGroupedBackground)
    static let primaryText     = Color(.label)
    static let secondaryText   = Color(.secondaryLabel)

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 27/255,  green: 94/255,  blue: 32/255),
                Color(red: 46/255,  green: 125/255, blue: 50/255),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - View helpers

extension View {
    /// White card with subtle shadow and 12pt corners.
    func cardStyle(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    /// Deep-green navigation bar with white text.
    func greenNavBar() -> some View {
        self
            .toolbarBackground(Theme.primary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }

    /// Green nav bar + white custom title via .principal placement.
    /// Multiple .toolbar modifiers are additive, so extra toolbar items
    /// (trailing buttons etc.) can be added in a separate .toolbar block.
    func greenNavTitle(_ title: String) -> some View {
        self
            .navigationTitle("")
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.primary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
    }
}

// MARK: - Mint pill button style

struct MintButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Theme.mint.opacity(configuration.isPressed ? 0.80 : 1))
            .clipShape(Capsule())
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == MintButtonStyle {
    static var mint: MintButtonStyle { MintButtonStyle() }
}

// MARK: - Reusable section header

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 4)
    }
}

// MARK: - Stat chip card

struct StatChip: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(iconColor)

            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 120, alignment: .leading)
        .frame(minHeight: 80)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Curved nav bar bottom cap (place at top of each ScrollView VStack)

struct NavBarCurve: View {
    var body: some View {
        Theme.primary
            .frame(height: 32)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 24,
                bottomTrailingRadius: 24,
                topTrailingRadius: 0
            ))
    }
}

// MARK: - Store avatar (initial + deterministic color)

struct StoreAvatar: View {
    let name: String
    let size: CGFloat

    private var color: Color {
        let palette: [Color] = [.blue, .purple, .orange, .teal, .indigo, .pink, .brown]
        return palette[abs(name.hashValue) % palette.count]
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: size, height: size)
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
    }
}
