import SwiftUI
import Combine

// Flow Item 25: Report / Moderation Flow
struct ReportFlowView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedReason: String? = nil
    @State private var detailText: String = ""
    @State private var isSubmitting = false
    
    let reasons = ["Spam", "Harassment", "Hate Speech", "Privacy Concern", "Other"]
    
    var body: some View {
        NavigationView {
            Form {
                // Report Reason Dropdown
                Section("What are you reporting this content for?") {
                    Picker("Select a reason", selection: $selectedReason) {
                        Text("— Choose Reason —").tag(nil as String?)
                        ForEach(reasons, id: \.self) { reason in
                            Text(reason).tag(Optional(reason))
                        }
                    }
                }
                
                // Optional text box
                Section("Details (Optional)") {
                    TextEditor(text: $detailText)
                        .frame(minHeight: 100)
                        .overlay(alignment: .topLeading) {
                            if detailText.isEmpty {
                                Text("Provide any additional information here...")
                                    .foregroundColor(Color(.placeholderText))
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                        }
                }
                
                // Submit Button
                Section {
                    Button {
                        submitReport()
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView().tint(.white)
                            } else {
                                Text("Submit Report")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primaryDrivingApp)
                    .disabled(selectedReason == nil || isSubmitting)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Report Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Action
    
    private func submitReport() {
        isSubmitting = true
        
        // TODO: Send report data (Post ID, Reason, Details, User ID) to moderation backend.
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSubmitting = false
            dismiss()
        }
    }
}
