import SwiftUI

struct AddPaymentFormView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var paymentManager: PaymentManager
    @EnvironmentObject var dataService: DataService

    var onPaymentAdded: () -> Void

    // Form State
    @State private var availableStudents: [Student] = []
    @State private var selectedStudent: Student? = nil
    @State private var amount: String = "45.00"
    @State private var date = Date()
    @State private var isPaid = false
    
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                // MARK: - Transaction Details
                Section("Transaction Details") {
                    // ERROR FIXED: Student now conforms to Hashable
                    Picker("Student", selection: $selectedStudent) {
                        Text("Select Student").tag(nil as Student?)
                        ForEach(availableStudents) { student in
                            Text(student.name).tag(student as Student?) // Student is Hashable
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
                                Text("Record Payment")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primaryDrivingApp)
                    .disabled(!isFormValid || isLoading)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Record New Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await fetchStudents() }
        }
    }
    
    // MARK: - Validation & Actions
    
    private var isFormValid: Bool {
        selectedStudent != nil && (Double(amount) ?? 0 > 0)
    }
    
    private func fetchStudents() async {
        do {
            // NOTE: Mocking instructor ID
            availableStudents = try await dataService.fetchStudents(for: "i_auth_id")
        } catch {
            errorMessage = "Failed to load students."
        }
    }
    
    private func savePayment() {
        guard let student = selectedStudent, let finalAmount = Double(amount) else { return }
        
        isLoading = true
        errorMessage = nil
        
        let newPayment = Payment(
            studentID: student.id ?? "unknown",
            amount: finalAmount,
            date: date,
            isPaid: isPaid
        )
        
        Task {
            do {
                try await paymentManager.recordPayment(newPayment: newPayment)
                onPaymentAdded()
                dismiss()
            } catch {
                errorMessage = "Failed to record payment: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}
