import SwiftUI

enum Theme {
    static let background = Color(red: 0.96, green: 0.965, blue: 0.984)
    static let card = Color.white
    static let primary = Color(red: 0.424, green: 0.361, blue: 0.906)
    static let primaryLight = Color(red: 0.545, green: 0.486, blue: 0.969)
    static let gradientEnd = Color(red: 0.306, green: 0.608, blue: 1.0)
    static let secondary = Color(red: 0.0, green: 0.529, blue: 0.353)
    static let warning = Color(red: 0.706, green: 0.325, blue: 0.035)
    static let danger = Color(red: 0.863, green: 0.149, blue: 0.149)
    static let textPrimary = Color(red: 0.098, green: 0.114, blue: 0.20)
    static let textRegular = Color(red: 0.239, green: 0.259, blue: 0.341)
    static let textSecondary = Color(red: 0.482, green: 0.506, blue: 0.58)
    static let chip = Color(red: 0.933, green: 0.937, blue: 0.965)
    static let softPrimary = Color(red: 0.933, green: 0.922, blue: 1.0)
    static let softSecondary = Color(red: 0.902, green: 0.969, blue: 0.945)
    static let softWarning = Color(red: 1.0, green: 0.953, blue: 0.894)
    static let softDanger = Color(red: 1.0, green: 0.925, blue: 0.925)

    static let heroGradient = LinearGradient(
        colors: [primaryLight, primary, gradientEnd],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let buttonGradient = LinearGradient(
        colors: [primaryLight, primary, gradientEnd],
        startPoint: .leading, endPoint: .trailing)
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                Capsule().fill(Theme.buttonGradient)
                    .shadow(color: Theme.primary.opacity(configuration.isPressed ? 0.12 : 0.32), radius: configuration.isPressed ? 5 : 10, y: 4)
            )
            .opacity(isEnabled ? 1 : 0.55)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

struct AppCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 12, y: 4)
    }
}

struct FilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? .white : Theme.textRegular)
                .padding(.horizontal, 13)
                .frame(minHeight: 34)
                .background(Capsule().fill(selected ? Theme.primary : Theme.chip))
        }
        .buttonStyle(.plain)
    }
}

struct TagPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(color))
    }
}

struct EmptyBlock: View {
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Text("🦉")
                .font(.system(size: 46))
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("刚才遇到一点小问题")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.danger)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.softDanger))
    }
}

struct SectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
