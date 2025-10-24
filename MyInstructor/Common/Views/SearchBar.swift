import SwiftUI

// Shared Search Bar Component (Flow 11, 18, 21)
struct SearchBar: View {
    @Binding var text: String
    var placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.textLight)
            
            TextField(placeholder, text: $text)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .foregroundColor(.textDark)
                
            if !text.isEmpty {
                Button(action: { self.text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textLight)
                }
            }
        }
        .padding(10)
        .background(Color.secondaryGray)
        .cornerRadius(12)
        .animation(.default, value: text)
    }
}