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

    static let appAccent     = Color(red: 0.0, green: 0.7,  blue: 0.9)
    static let success       = Color(red: 0.2, green: 0.78, blue: 0.35)
    static let warning       = Color(red: 0.9, green: 0.6,  blue: 0.0)
    static let error         = Color(red: 0.9, green: 0.3,  blue: 0.3)

    // MARK: Health Metric Colors

    static let stepsColor     = Color(red: 0.25, green: 0.65, blue: 0.90)
    static let heartRateColor = Color(red: 0.92, green: 0.30, blue: 0.40)
    static let sleepColor     = Color(red: 0.55, green: 0.40, blue: 0.92)
    static let energyColor    = Color(red: 0.95, green: 0.60, blue: 0.20)
}

// MARK: - Card Style

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.secondaryBackground)
            .cornerRadius(12)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
