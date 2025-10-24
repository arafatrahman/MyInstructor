import SwiftUI
import Combine

// MARK: - Color Palette

extension Color {
    // Primary App Colors (Professional and modern feel)
    static let primaryBlue = Color(red: 0.05, green: 0.45, blue: 0.85) // Deep, rich blue
    static let accentGreen = Color(red: 0.15, green: 0.75, blue: 0.35) // Vibrant success color
    static let secondaryGray = Color(.systemGray5) // Light gray for backgrounds
    static let textDark = Color(.label)
    static let textLight = Color(.systemGray)
    static let warningRed = Color(red: 0.9, green: 0.3, blue: 0.3)
}

// MARK: - Custom Button Styles

// Primary Button Style (Used for major actions like Login, Save, Continue)
struct PrimaryDrivingAppButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 14)
            .background(Color.primaryBlue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .shadow(color: Color.primaryBlue.opacity(0.3), radius: 8, x: 0, y: 5)
    }
}

extension ButtonStyle where Self == PrimaryDrivingAppButtonStyle {
    static var primaryDrivingApp: PrimaryDrivingAppButtonStyle {
        PrimaryDrivingAppButtonStyle()
    }
}

// Secondary Button Style (Used for less critical actions like Cancel, Skip)
struct SecondaryDrivingAppButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .padding(.vertical, 10)
            .foregroundColor(Color.textDark)
            .background(Color.secondaryGray)
            .cornerRadius(10)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

extension ButtonStyle where Self == SecondaryDrivingAppButtonStyle {
    static var secondaryDrivingApp: SecondaryDrivingAppButtonStyle {
        SecondaryDrivingAppButtonStyle()
    }
}

// MARK: - Custom Text Field Modifiers

// Standard text field styling for forms
struct FormTextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.secondaryGray)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.clear, lineWidth: 1)
            )
    }
}

extension View {
    func formTextFieldStyle() -> some View {
        modifier(FormTextFieldModifier())
    }
}

// MARK: - App Wide Setup (Theme Application)

// Function to apply theme settings globally
extension View {
    func applyAppTheme() -> some View {
        self
            // Set the global accent color
            .accentColor(.primaryBlue)
            // Apply a subtle background color to form views
            .background(Color(.systemBackground))
    }
}
