import SwiftUI

// Shared Empty State View (Flow 17)
struct EmptyStateView: View {
    let icon: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(icon: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.textLight)
            
            Text(message)
                .font(.headline)
                .foregroundColor(.textLight)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let title = actionTitle, let action = action {
                Button(title, action: action)
                    .buttonStyle(.primaryDrivingApp)
                    .frame(width: 200)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}