// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Authentication/AuthenticationView.swift
// --- UPDATED: Defaults to Login tab (Welcome Back) ---

import SwiftUI

// Flow Item 4: Login / Register Container
struct AuthenticationView: View {
    // Change default to 0 so it starts on "Login / Welcome Back"
    @State private var selection: Int = 0
    
    var body: some View {
        VStack {
            
            // Clean, simplified header
            VStack(spacing: 5) {
                Text(selection == 0 ? "Welcome Back" : "Join My LessonPilot")
                    .font(.largeTitle).bold()
                    .foregroundColor(.textDark)
                Text(selection == 0 ? "Sign in to your account." : "Create your new account.")
                    .font(.subheadline)
                    .foregroundColor(.textLight)
            }
            .padding(.top, 40)
            .padding(.horizontal, 30)
            
            // Tab Content (Driven by swipe or internal button actions)
            TabView(selection: $selection) {
                LoginForm(selection: $selection) // Pass selection binding
                    .tag(0)
                
                RegisterForm(selection: $selection) // Pass selection binding
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: selection)
            
            Spacer()
        }
        .padding(.vertical, 20)
    }
}
