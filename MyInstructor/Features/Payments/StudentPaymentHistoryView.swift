// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Payments/StudentPaymentHistoryView.swift

import SwiftUI

struct StudentPaymentHistoryView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var paymentManager: PaymentManager
    @EnvironmentObject var dataService: DataService
    @Environment(\.dismiss) var dismiss
    
    @State private var payments: [Payment] = []
    @State private var isLoading = true
    
    // Sheet States
    @State private var isAddingPayment = false
    @State private var paymentToEdit: Payment?
    
    // Computed Total
    var totalPaid: Double {
        payments.filter { $0.isPaid }.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                // MARK: - Summary Card
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Total Paid")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text(totalPaid, format: .currency(code: "GBP"))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.2))
                }
                .padding(20)
                .background(Color.primaryBlue)
                .cornerRadius(16)
                .padding([.horizontal, .top], 16)
                .padding(.bottom, 10)
                .shadow(color: Color.primaryBlue.opacity(0.3), radius: 8, x: 0, y: 4)
                
                // MARK: - List Content
                if isLoading {
                    Spacer()
                    ProgressView("Loading History...")
                    Spacer()
                } else if payments.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "list.bullet.rectangle.portrait",
                        message: "No payment history found.",
                        actionTitle: "Add Payment",
                        action: { isAddingPayment = true }
                    )
                    Spacer()
                } else {
                    List {
                        ForEach(payments) { payment in
                            Button {
                                // Tap to Edit
                                paymentToEdit = payment
                            } label: {
                                StudentPaymentRow(payment: payment)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                // Delete Action
                                Button(role: .destructive) {
                                    Task { await deletePayment(payment) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                // Edit Action
                                Button {
                                    paymentToEdit = payment
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await loadData()
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Payment History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingPayment = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                    }
                }
            }
            // Load Data
            .task {
                await loadData()
            }
            // Add Sheet
            .sheet(isPresented: $isAddingPayment) {
                StudentAddPaymentView(onSave: {
                    Task { await loadData() }
                })
            }
            // Edit Sheet
            .sheet(item: $paymentToEdit) { payment in
                StudentAddPaymentView(paymentToEdit: payment, onSave: {
                    paymentToEdit = nil
                    Task { await loadData() }
                })
            }
        }
    }
    
    // MARK: - Logic
    
    func loadData() async {
        guard let studentID = authManager.user?.id else { return }
        isLoading = true
        do {
            self.payments = try await paymentManager.fetchStudentPayments(for: studentID)
        } catch {
            print("Error loading payments: \(error)")
        }
        isLoading = false
    }
    
    func deletePayment(_ payment: Payment) async {
        guard let id = payment.id else { return }
        do {
            try await paymentManager.deletePayment(paymentID: id)
            // Optimistic update or reload
            withAnimation {
                payments.removeAll(where: { $0.id == id })
            }
        } catch {
            print("Error deleting payment: \(error)")
        }
    }
}

// MARK: - Row Component

struct StudentPaymentRow: View {
    let payment: Payment
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon Background
            ZStack {
                Circle()
                    .fill(payment.isPaid ? Color.accentGreen.opacity(0.15) : Color.warningRed.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: payment.isPaid ? "checkmark" : "clock.arrow.circlepath")
                    .font(.subheadline.bold())
                    .foregroundColor(payment.isPaid ? .accentGreen : .warningRed)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Title (Note or Fallback)
                Text(payment.note?.isEmpty == false ? payment.note! : (payment.isPaid ? "Payment Record" : "Lesson Fee"))
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                // Date
                Text(payment.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                // Amount
                Text(payment.amount, format: .currency(code: "GBP"))
                    .font(.headline)
                    .foregroundColor(payment.isPaid ? .primary : .warningRed)
                
                // Status / Method
                if !payment.isPaid {
                    Text("Pending")
                        .font(.caption2).bold()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.warningRed.opacity(0.1))
                        .foregroundColor(.warningRed)
                        .cornerRadius(4)
                } else {
                    Text(payment.paymentMethod?.rawValue ?? "Paid")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
