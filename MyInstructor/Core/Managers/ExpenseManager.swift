// File: MyInstructor/Core/Managers/ExpenseManager.swift
import Foundation
import FirebaseFirestore
import Combine

class ExpenseManager: ObservableObject {
    private let db = Firestore.firestore()
    private var expensesCollection: CollectionReference {
        db.collection("expenses")
    }
    
    // Add Expense
    func addExpense(_ expense: Expense) async throws {
        try expensesCollection.addDocument(from: expense)
        print("Expense added: \(expense.title)")
    }
    
    // Update Expense
    func updateExpense(_ expense: Expense) async throws {
        guard let id = expense.id else { return }
        try expensesCollection.document(id).setData(from: expense)
        print("Expense updated: \(expense.title)")
    }
    
    // Delete Expense
    func deleteExpense(expenseID: String) async throws {
        try await expensesCollection.document(expenseID).delete()
        print("Expense deleted")
    }
    
    // Fetch Expenses
    func fetchExpenses(for instructorID: String) async throws -> [Expense] {
        let snapshot = try await expensesCollection
            .whereField("instructorID", isEqualTo: instructorID)
            .order(by: "date", descending: true)
            .getDocuments()
            
        return snapshot.documents.compactMap { try? $0.data(as: Expense.self) }
    }
}
