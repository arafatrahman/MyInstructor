import SwiftUI

// Flow Item 4: Login / Register Container
struct AuthenticationView: View {
    @State private var selection: Int = 0 // 0 for Login, 1 for Sign Up
    
    var body: some View {
        VStack {
            // Tabs: Login | Sign Up (Modern Segmented Picker)
            Picker("Auth Segment", selection: $selection) {
                Text("Login").tag(0)
                Text("Sign Up").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.top, 20)
            .padding(.horizontal, 30)
            
            // Tab Content
            TabView(selection: $selection) {
                LoginForm()
                    .tag(0)
                
                RegisterForm()
                    .tag(1)
            }
            // Hides the default TabView indicator and allows swipe
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: selection)
            
            Spacer()
        }
        .padding(.vertical, 20)
    }
}