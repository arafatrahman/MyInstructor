// File: MyInstructor/Features/Expenses/AddExpenseFormView.swift
// --- UPDATED: Safer Amount Parsing ---

import SwiftUI

struct AddExpenseFormView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var expenseManager: ExpenseManager
    @EnvironmentObject var authManager: AuthManager
    
    var expenseToEdit: Expense?
    var onSave: () -> Void
    
    @State private var title: String = ""
    @State private var amount: String = ""
    @State private var date: Date = Date()
    @State private var category: ExpenseCategory = .fuel
    @State private var note: String = ""
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var isEditing: Bool { expenseToEdit != nil }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Expense Details") {
                    TextField("Title (e.g. Shell Station)", text: $title)
                    
                    HStack {
                        Text("Amount (£)")
                        Spacer()
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Picker("Category", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                
                Section("Notes (Optional)") {
                    TextEditor(text: $note)
                        .frame(height: 80)
                }
                
                if let error = errorMessage {
                    Text(error).foregroundColor(.red).font(.caption)
                }
                
                Button {
                    saveExpense()
                } label: {
                    HStack {
                        if isLoading { ProgressView().tint(.white) }
                        else { Text(isEditing ? "Save Changes" : "Add Expense") }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primaryDrivingApp)
                .disabled(title.isEmpty || amount.isEmpty || isLoading)
                .listRowBackground(Color.clear)
            }
            .navigationTitle(isEditing ? "Edit Expense" : "Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if let exp = expenseToEdit {
                    title = exp.title
                    amount = String(format: "%.2f", exp.amount)
                    date = exp.date
                    category = exp.category
                    note = exp.note ?? ""
                }
            }
        }
    }
    
    private func saveExpense() {
        // Safe conversion: Replace comma with dot to handle region differences
        let safeAmountString = amount.replacingOccurrences(of: ",", with: ".")
        guard let instructorID = authManager.user?.id, let amountVal = Double(safeAmountString) else {
            errorMessage = "Invalid amount format."
            return
        }
        
        isLoading = true
        let newExpense = Expense(
            id: expenseToEdit?.id,
            instructorID: instructorID,
            title: title,
            amount: amountVal,
            date: date,
            category: category,
            note: note.isEmpty ? nil : note
        )
        
        Task {
            do {
                if isEditing {
                    try await expenseManager.updateExpense(newExpense)
                } else {
                    try await expenseManager.addExpense(newExpense)
                }
                onSave()
                dismiss()
            } catch {
                errorMessage = "Failed to save: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}
