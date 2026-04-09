import SwiftUI
import UIKit

// MARK: - Adaptive Color Palette
//
// All semantic colors automatically switch between light and dark mode.
// Dark values are kept from the original design.
// Light values follow standard iOS grouped-background conventions.

extension Color {

    // MARK: Backgrounds

    /// Page-level background — light gray in light mode, near-black in dark mode.
    static let background = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1)
            : UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)
    })

    /// Card / elevated surface background.
    static let secondaryBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1)
            : UIColor(red: 1.0,  green: 1.0,  blue: 1.0,  alpha: 1)
    })

    /// Inner cells / nested backgrounds.
    static let tertiaryBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1)
            : UIColor(red: 0.90, green: 0.90, blue: 0.92, alpha: 1)
    })

    // MARK: Text

    /// Primary body text.
    static let text = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)
            : UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1)
    })

    /// Secondary / descriptive text.
    static let secondaryText = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.60, green: 0.60, blue: 0.60, alpha: 1)
            : UIColor(red: 0.42, green: 0.42, blue: 0.44, alpha: 1)
    })

    /// Tertiary / placeholder text.
    static let tertiaryText = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.40, green: 0.40, blue: 0.40, alpha: 1)
            : UIColor(red: 0.65, green: 0.65, blue: 0.67, alpha: 1)
    })

    // MARK: Semantic / Status

    static let appAccent     = Color(red: 1.0, green: 0.408, blue: 0.165)
    static let success       = Color(red: 0.2, green: 0.78, blue: 0.35)
    static let warning       = Color(red: 0.9, green: 0.6,  blue: 0.0)
    static let error         = Color(red: 0.9, green: 0.3,  blue: 0.3)

    // MARK: Health Metric Colors

    static let stepsColor     = Color(red: 0.25, green: 0.65, blue: 0.90)
    static let heartRateColor = Color(red: 0.92, green: 0.30, blue: 0.40)
    static let sleepColor     = Color(red: 0.55, green: 0.40, blue: 0.92)
    static let energyColor    = Color(red: 0.95, green: 0.60, blue: 0.20)
}

// MARK: - Ambient Glass Background

struct AmbientBackground: View {
    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            Circle()
                .fill(Color.appAccent.opacity(0.25))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: -80, y: -200)
            Circle()
                .fill(Color(red: 0.4, green: 0.3, blue: 1.0).opacity(0.15))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: 120, y: 100)
            Circle()
                .fill(Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.12))
                .frame(width: 240, height: 240)
                .blur(radius: 70)
                .offset(x: -60, y: 400)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Card Style (Liquid Glass)

struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.08 : 0.11),
                radius: 8,
                x: 0,
                y: 4
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
