import SwiftUI

// MARK: - Color Palette (cached for performance)

extension Color {
    static let background = Color(red: 0.07, green: 0.07, blue: 0.07)
    static let secondaryBackground = Color(red: 0.12, green: 0.12, blue: 0.12)
    static let tertiaryBackground = Color(red: 0.18, green: 0.18, blue: 0.18)
    static let text = Color(red: 0.95, green: 0.95, blue: 0.95)
    static let secondaryText = Color(red: 0.6, green: 0.6, blue: 0.6)
    static let tertiaryText = Color(red: 0.4, green: 0.4, blue: 0.4)
    static let appAccent = Color(red: 0.0, green: 0.7, blue: 0.9)
    static let success = Color(red: 0.3, green: 0.8, blue: 0.4)
    static let warning = Color(red: 0.9, green: 0.6, blue: 0.0)
    static let error = Color(red: 0.9, green: 0.3, blue: 0.3)
    static let stepsColor = Color(red: 0.3, green: 0.7, blue: 0.9)
    static let heartRateColor = Color(red: 0.9, green: 0.3, blue: 0.4)
    static let sleepColor = Color(red: 0.5, green: 0.4, blue: 0.9)
    static let energyColor = Color(red: 0.9, green: 0.6, blue: 0.2)
}

// MARK: - Card Style (optimized)

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.tertiaryBackground)
            .cornerRadius(12)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
