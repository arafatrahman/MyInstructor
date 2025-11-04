// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Common/Styles/CustomStyles.swift
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
            .frame(maxWidth: .infinity) // Ensure label content tries to fill width
            .background(Color.primaryBlue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(color: Color.primaryBlue.opacity(0.3), radius: configuration.isPressed ? 3 : 8, x: 0, y: configuration.isPressed ? 2 : 5) // Subtle shadow change
            // --- ANIMATION MODIFIERS ---
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0) // Slightly shrink when pressed
            .opacity(configuration.isPressed ? 0.9 : 1.0)    // Slightly fade when pressed
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed) // Smooth transition
            // --------------------------
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
            // --- Optional: Add subtle animation here too ---
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            // ------------------------------------------
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
            // Removed overlay as it wasn't doing much
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
            // Apply a consistent background, especially useful outside Forms
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}
