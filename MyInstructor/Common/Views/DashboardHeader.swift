import SwiftUI

// Shared Header for Instructor and Student Dashboards (Flow 5 & 6)
struct DashboardHeader: View {
    @EnvironmentObject var authManager: AuthManager
    
    var userName: String {
        authManager.user?.name ?? (authManager.role == .instructor ? "Instructor" : "Student")
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Welcome Back,")
                    .font(.callout)
                    .foregroundColor(.textLight)
                Text(userName)
                    .font(.title2).bold()
                    .foregroundColor(.textDark)
            }
            
            Spacer()
            
            // Notifications Bell (Flow 14)
            NavigationLink(destination: NotificationsView()) {
                ZStack {
                    Image(systemName: "bell.fill")
                        .font(.title2)
                        .foregroundColor(.textDark)
                    
                    // Placeholder for badge count
                    Circle()
                        .fill(Color.warningRed)
                        .frame(width: 10, height: 10)
                        .offset(x: 8, y: -8)
                }
            }
            
            // Profile Avatar/Settings (Flow 15)
            NavigationLink(destination: SettingsView()) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 35, height: 35)
                    .clipShape(Circle())
                    .foregroundColor(.primaryBlue)
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
}