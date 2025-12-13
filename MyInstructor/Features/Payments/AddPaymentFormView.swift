// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Payments/AddPaymentFormView.swift
// --- UPDATED: Made Student selection optional; Added Note field for custom income ---

import SwiftUI

struct AddPaymentFormView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var paymentManager: PaymentManager
    @EnvironmentObject var dataService: DataService
    @EnvironmentObject var authManager: AuthManager

    var paymentToEdit: Payment? // Optional: If provided, we are in "Edit" mode
    var onPaymentAdded: () -> Void
    
    // --- NEW: Read Only Mode ---
    var isReadOnly: Bool = false

    // Form State
    @State private var availableStudents: [Student] = []
    @State private var selectedStudent: Student? = nil
    @State private var amount: String = "45.00"
    @State private var date = Date()
    @State private var isPaid = false
    @State private var selectedMethod: PaymentMethod = .cash // Default
    @State private var note: String = "" // Added Note field
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private var isEditing: Bool { paymentToEdit != nil }

    var body: some View {
        NavigationView {
            Form {
                // MARK: - Transaction Details
                Section("Transaction Details") {
                    Picker("Student", selection: $selectedStudent) {
                        Text("None (Personal/Other)").tag(nil as Student?) // Made optional
                        ForEach(availableStudents) { student in
                            Text(student.name).tag(student as Student?)
                        }
                    }
                    .disabled(isReadOnly)
                    
                    HStack {
                        Text("Amount (£)")
                        Spacer()
                        TextField("Amount", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .disabled(isReadOnly)
                    }
                    
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .disabled(isReadOnly)
                    
                    Toggle("Mark as Paid", isOn: $isPaid)
                        .tint(.accentGreen)
                        .disabled(isReadOnly)
                    
                    // Conditionally show Payment Method Picker
                    if isPaid {
                        Picker("Payment Method", selection: $selectedMethod) {
                            ForEach(PaymentMethod.allCases) { method in
                                Text(method.rawValue).tag(method)
                            }
                        }
                        .pickerStyle(.segmented)
                        .disabled(isReadOnly)
                    }
                }
                
                // MARK: - Notes (Added)
                Section("Notes") {
                    TextField("Description (Optional)", text: $note)
                        .disabled(isReadOnly)
                }
                
                // Show Error Message
                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.warningRed)
                    }
                }
            }
            // Dynamic Title
            .navigationTitle(isReadOnly ? "Payment Details" : (isEditing ? "Edit Payment" : "Record New Payment"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Cancel/Close Button
                ToolbarItem(placement: .cancellationAction) {
                    Button(isReadOnly ? "Close" : "Cancel") { dismiss() }
                }
                
                // Save Button (Only if not read-only)
                if !isReadOnly {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            savePayment()
                        }
                        .bold()
                        .disabled(!isFormValid || isLoading)
                    }
                }
            }
            .task {
                await fetchStudents()
                // If editing or viewing, populate fields
                if let payment = paymentToEdit {
                    self.amount = String(format: "%.2f", payment.amount)
                    self.date = payment.date
                    self.isPaid = payment.isPaid
                    if let method = payment.paymentMethod {
                        self.selectedMethod = method
                    }
                    self.note = payment.note ?? "" // Populate note
                    
                    // Find the student object that matches the ID
                    if !payment.studentID.isEmpty {
                        if let foundStudent = availableStudents.first(where: { $0.id == payment.studentID }) {
                            self.selectedStudent = foundStudent
                        }
                    } else {
                        self.selectedStudent = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Validation & Actions
    
    private var isFormValid: Bool {
        // Validation: Amount must be valid. Student is now optional.
        (Double(amount) ?? 0 > 0)
    }
    
    private func fetchStudents() async {
        guard let instructorID = authManager.user?.id else {
            errorMessage = "Could not find instructor ID."
            return
        }
        
        do {
            availableStudents = try await dataService.fetchAllStudents(for: instructorID)
            
            // Re-bind selected student if editing and student list wasn't ready
            if let payment = paymentToEdit, selectedStudent == nil, !payment.studentID.isEmpty {
                 if let foundStudent = availableStudents.first(where: { $0.id == payment.studentID }) {
                    self.selectedStudent = foundStudent
                }
            }
            
        } catch {
            errorMessage = "Failed to load students."
        }
    }
    
    private func savePayment() {
        guard let finalAmount = Double(amount) else { return }
        guard let instructorID = authManager.user?.id else {
            errorMessage = "Instructor not identified."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let payment = Payment(
            id: paymentToEdit?.id,
            instructorID: instructorID,
            studentID: selectedStudent?.id ?? "", // Handle optional student
            amount: finalAmount,
            date: date,
            isPaid: isPaid,
            paymentMethod: isPaid ? selectedMethod : nil,
            note: note.isEmpty ? nil : note // Save note
        )
        
        Task {
            do {
                if isEditing {
                    try await paymentManager.updatePayment(payment)
                } else {
                    try await paymentManager.recordPayment(newPayment: payment)
                }
                onPaymentAdded()
                dismiss()
            } catch {
                errorMessage = "Failed to save: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}
