// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Payments/StudentAddPaymentView.swift
// --- UPDATED: Button moved to Toolbar, Pay To optional, Hours added ---

import SwiftUI

struct StudentAddPaymentView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var paymentManager: PaymentManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var dataService: DataService
    
    var paymentToEdit: Payment?
    var onSave: () -> Void
    
    @State private var amountString = ""
    @State private var hoursString = "" // <--- NEW State for Hours
    @State private var date = Date()
    @State private var paymentMethod: PaymentMethod = .cash
    @State private var note = ""
    @State private var selectedInstructorID: String = ""
    
    // List of instructors to choose from
    @State private var myInstructors: [AppUser] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var isEditing: Bool { paymentToEdit != nil }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Payment Details") {
                    HStack {
                        Text("Amount (£)")
                        Spacer()
                        TextField("0.00", text: $amountString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    // --- NEW: Hours Field ---
                    HStack {
                        Text("Hours (Optional)")
                        Spacer()
                        TextField("e.g. 1.5", text: $hoursString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    
                    Picker("Method", selection: $paymentMethod) {
                        ForEach(PaymentMethod.allCases) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                }
                
                Section("Pay To (Optional)") {
                    Picker("Instructor", selection: $selectedInstructorID) {
                        Text("None").tag("") // <--- NEW: Optional "None" tag
                        ForEach(myInstructors) { instructor in
                            Text(instructor.name ?? "Unknown").tag(instructor.id ?? "")
                        }
                    }
                }
                
                Section("Notes") {
                    TextField("e.g. Lesson Fee, Block Booking...", text: $note)
                }
                
                if let error = errorMessage {
                    Text(error).foregroundColor(.red).font(.caption)
                }
            }
            .navigationTitle(isEditing ? "Edit Payment" : "Add Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Cancel Button (Left)
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                // Save Button (Right) - Moved from bottom
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        savePayment()
                    }
                    .bold()
                    .disabled(amountString.isEmpty || isLoading)
                }
            }
            .task {
                await fetchInstructors()
                if let p = paymentToEdit {
                    amountString = String(format: "%.2f", p.amount)
                    
                    // Populate hours if they exist
                    if let hours = p.hours {
                        hoursString = String(format: "%.1f", hours)
                    }
                    
                    date = p.date
                    paymentMethod = p.paymentMethod ?? .cash
                    note = p.note ?? ""
                    selectedInstructorID = p.instructorID
                }
            }
        }
    }
    
    private func fetchInstructors() async {
        guard let studentID = authManager.user?.id else { return }
        
        let instructorIDs = authManager.user?.instructorIDs ?? []
        
        var loaded: [AppUser] = []
        for id in instructorIDs {
            if let user = try? await dataService.fetchUser(withId: id) {
                loaded.append(user)
            }
        }
        self.myInstructors = loaded
        
        // Only default select if creating new AND not yet selected
        if !isEditing && selectedInstructorID.isEmpty, let first = myInstructors.first?.id {
            selectedInstructorID = first
        }
    }
    
    private func savePayment() {
        guard let studentID = authManager.user?.id else { return }
        guard let amount = Double(amountString) else {
            errorMessage = "Invalid amount"
            return
        }
        
        let hours = Double(hoursString) // Optional, returns nil if invalid/empty
        
        isLoading = true
        
        let payment = Payment(
            id: paymentToEdit?.id,
            instructorID: selectedInstructorID, // Can be empty string
            studentID: studentID,
            amount: amount,
            date: date,
            isPaid: true,
            paymentMethod: paymentMethod,
            note: note.isEmpty ? nil : note,
            hours: hours // Save hours
        )
        
        Task {
            do {
                if isEditing {
                    try await paymentManager.updatePayment(payment)
                } else {
                    try await paymentManager.recordPayment(newPayment: payment)
                }
                onSave()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
