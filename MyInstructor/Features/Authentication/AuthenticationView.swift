import SwiftUI

// Flow Item 4: Login / Register Container
struct AuthenticationView: View {
    @State private var selection: Int = 0 // 0 for Login, 1 for Sign Up
    
    var body: some View {
        VStack {
            
            // Clean, simplified header
            VStack(spacing: 5) {
                Text(selection == 0 ? "Welcome Back" : "Join My Instructor")
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
