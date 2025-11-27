// File: MyInstructor/Features/Expenses/ExpensesView.swift
import SwiftUI

struct ExpensesView: View {
    @EnvironmentObject var expenseManager: ExpenseManager
    @EnvironmentObject var authManager: AuthManager
    
    @State private var expenses: [Expense] = []
    @State private var timeFilter: TimeFilter = .monthly // Reusing TimeFilter from PaymentsView
    
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    
    @State private var isAddSheetPresented = false
    @State private var expenseToEdit: Expense? = nil
    @State private var isLoading = true
    
    // MARK: - Computed Properties
    
    var filteredExpenses: [Expense] {
        expenses.filter { expense in
            switch timeFilter {
            case .daily:
                return Calendar.current.isDateInToday(expense.date)
            case .weekly:
                return Calendar.current.isDate(expense.date, equalTo: Date(), toGranularity: .weekOfYear)
            case .monthly:
                return Calendar.current.isDate(expense.date, equalTo: Date(), toGranularity: .month)
            case .yearly:
                return Calendar.current.isDate(expense.date, equalTo: Date(), toGranularity: .year)
            case .custom:
                let start = Calendar.current.startOfDay(for: customStartDate)
                let end = Calendar.current.endOfDay(for: customEndDate)
                return expense.date >= start && expense.date <= end
            }
        }
        .sorted(by: { $0.date > $1.date })
    }
    
    var totalAmount: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 15) {
                // Time Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(TimeFilter.allCases) { filter in
                            Button { withAnimation { timeFilter = filter } } label: {
                                Text(filter.rawValue)
                                    .font(.subheadline).bold()
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(timeFilter == filter ? Color.primaryBlue : Color(.systemGray6))
                                    .foregroundColor(timeFilter == filter ? .white : .secondary)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 10)
                
                if timeFilter == .custom {
                    HStack {
                        DatePicker("From", selection: $customStartDate, displayedComponents: .date).labelsHidden()
                        Spacer()
                        DatePicker("To", selection: $customEndDate, displayedComponents: .date).labelsHidden()
                    }
                    .padding(.horizontal)
                }
                
                // Summary Card
                VStack(alignment: .leading, spacing: 5) {
                    Text("Total Expenses")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                    Text(totalAmount, format: .currency(code: "GBP"))
                        .font(.largeTitle).bold()
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.warningRed) // Red for expenses
                .cornerRadius(16)
                .padding(.horizontal)
                .shadow(color: Color.warningRed.opacity(0.3), radius: 8, x: 0, y: 4)
                
                // List
                if isLoading {
                    Spacer(); ProgressView("Loading..."); Spacer()
                } else if filteredExpenses.isEmpty {
                    Spacer()
                    EmptyStateView(icon: "chart.line.downtrend.xyaxis", message: "No expenses found for this period.")
                    Spacer()
                } else {
                    List {
                        ForEach(filteredExpenses) { expense in
                            Button {
                                expenseToEdit = expense
                            } label: {
                                ExpenseRow(expense: expense)
                            }
                            .buttonStyle(.plain)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await deleteExpense(expense.id!) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Track Expenses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { isAddSheetPresented = true } label: {
                        Image(systemName: "plus").font(.headline.bold())
                    }
                }
            }
            .sheet(isPresented: $isAddSheetPresented) {
                AddExpenseFormView(onSave: { Task { await fetchData() } })
            }
            .sheet(item: $expenseToEdit) { expense in
                AddExpenseFormView(expenseToEdit: expense, onSave: {
                    expenseToEdit = nil
                    Task { await fetchData() }
                })
            }
            .task { await fetchData() }
        }
    }
    
    func fetchData() async {
        guard let id = authManager.user?.id else { return }
        isLoading = true
        do {
            expenses = try await expenseManager.fetchExpenses(for: id)
        } catch { print("Error: \(error)") }
        isLoading = false
    }
    
    func deleteExpense(_ id: String) async {
        try? await expenseManager.deleteExpense(expenseID: id)
        withAnimation { expenses.removeAll { $0.id == id } }
    }
}

struct ExpenseRow: View {
    let expense: Expense
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.warningRed.opacity(0.1)).frame(width: 45, height: 45)
                Image(systemName: getIcon(for: expense.category))
                    .foregroundColor(.warningRed)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title).font(.headline)
                Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(expense.amount, format: .currency(code: "GBP"))
                    .font(.headline)
                Text(expense.category.rawValue)
                    .font(.caption2).padding(4)
                    .background(Color(.systemGray6)).cornerRadius(4)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 5, y: 2)
    }
    
    func getIcon(for category: ExpenseCategory) -> String {
        switch category {
        case .fuel: return "fuelpump.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .insurance: return "shield.fill"
        case .tax: return "doc.text.fill"
        case .marketing: return "megaphone.fill"
        case .other: return "tag.fill"
        }
    }
}
