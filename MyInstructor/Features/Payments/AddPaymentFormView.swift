// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Payments/AddPaymentFormView.swift
import SwiftUI

struct AddPaymentFormView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var paymentManager: PaymentManager
    @EnvironmentObject var dataService: DataService
    @EnvironmentObject var authManager: AuthManager

    var paymentToEdit: Payment? // Optional: If provided, we are in "Edit" mode
    var onPaymentAdded: () -> Void

    // Form State
    @State private var availableStudents: [Student] = []
    @State private var selectedStudent: Student? = nil
    @State private var amount: String = "45.00"
    @State private var date = Date()
    @State private var isPaid = false
    @State private var selectedMethod: PaymentMethod = .cash // Default
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private var isEditing: Bool { paymentToEdit != nil }

    var body: some View {
        NavigationView {
            Form {
                // MARK: - Transaction Details
                Section("Transaction Details") {
                    Picker("Student", selection: $selectedStudent) {
                        Text("Select Student").tag(nil as Student?)
                        ForEach(availableStudents) { student in
                            Text(student.name).tag(student as Student?)
                        }
                    }
                    
                    HStack {
                        Text("Amount (£)")
                        Spacer()
                        TextField("Amount", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    
                    Toggle("Mark as Paid", isOn: $isPaid)
                        .tint(.accentGreen)
                    
                    // Conditionally show Payment Method Picker
                    if isPaid {
                        Picker("Payment Method", selection: $selectedMethod) {
                            ForEach(PaymentMethod.allCases) { method in
                                Text(method.rawValue).tag(method)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                // MARK: - Actions
                Section {
                    if let error = errorMessage {
                        Text(error).foregroundColor(.warningRed)
                    }
                    
                    Button {
                        savePayment()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text(isEditing ? "Save Changes" : "Record Payment")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primaryDrivingApp)
                    .disabled(!isFormValid || isLoading)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle(isEditing ? "Edit Payment" : "Record New Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await fetchStudents()
                // If editing, populate fields
                if let payment = paymentToEdit {
                    self.amount = String(format: "%.2f", payment.amount)
                    self.date = payment.date
                    self.isPaid = payment.isPaid
                    if let method = payment.paymentMethod {
                        self.selectedMethod = method
                    }
                    // Find the student object that matches the ID
                    if let foundStudent = availableStudents.first(where: { $0.id == payment.studentID }) {
                        self.selectedStudent = foundStudent
                    }
                }
            }
        }
    }
    
    // MARK: - Validation & Actions
    
    private var isFormValid: Bool {
        selectedStudent != nil && (Double(amount) ?? 0 > 0)
    }
    
    private func fetchStudents() async {
        guard let instructorID = authManager.user?.id else {
            errorMessage = "Could not find instructor ID."
            return
        }
        
        do {
            availableStudents = try await dataService.fetchStudents(for: instructorID)
            
            // Re-check for selected student if we are in edit mode
            if let payment = paymentToEdit, selectedStudent == nil {
                 if let foundStudent = availableStudents.first(where: { $0.id == payment.studentID }) {
                    self.selectedStudent = foundStudent
                }
            }
            
        } catch {
            errorMessage = "Failed to load students."
        }
    }
    
    private func savePayment() {
        guard let student = selectedStudent, let finalAmount = Double(amount) else { return }
        guard let instructorID = authManager.user?.id else {
            errorMessage = "Instructor not identified."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        var payment = Payment(
            id: paymentToEdit?.id, // Keep ID if editing
            instructorID: instructorID,
            studentID: student.id ?? "unknown",
            amount: finalAmount,
            date: date,
            isPaid: isPaid,
            paymentMethod: isPaid ? selectedMethod : nil // Only save method if paid
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
