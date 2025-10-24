import SwiftUI

// Flow Item 13: Payments View
struct PaymentsView: View {
    @EnvironmentObject var paymentManager: PaymentManager
    @EnvironmentObject var dataService: DataService
    
    @State private var payments: [Payment] = []
    @State private var selectedTab: PaymentTab = .pending // Tabs: Received | Pending
    @State private var isAddPaymentModalPresented = false
    @State private var isLoading = true
    
    var filteredPayments: [Payment] {
        payments.filter { $0.isPaid == (selectedTab == .received) }
            .sorted(by: { $0.date > $1.date }) // Sort by newest first
    }
    
    // Calculate total earnings for the displayed tab
    var totalAmount: Double {
        filteredPayments.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationView {
            VStack {
                // Tabs: Received | Pending
                Picker("Payment Status", selection: $selectedTab) {
                    Text("🧾 Pending").tag(PaymentTab.pending)
                    Text("💰 Received").tag(PaymentTab.received)
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])
                
                if isLoading {
                    ProgressView("Loading Payments...")
                        .padding(.top, 50)
                } else if payments.isEmpty {
                    EmptyStateView(
                        icon: "dollarsign.circle", 
                        message: "No transactions recorded yet. Start tracking your income easily!",
                        actionTitle: "Record Payment",
                        action: { isAddPaymentModalPresented = true }
                    )
                } else if filteredPayments.isEmpty {
                    EmptyStateView(
                        icon: "hand.thumbsup", 
                        message: selectedTab == .pending ? "No pending payments! You're all caught up." : "No payments received in this period."
                    )
                } else {
                    List {
                        // Summary/Chart Section
                        Section {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("\(selectedTab == .received ? "Total Received" : "Total Pending"): \(totalAmount, format: .currency(code: "GBP"))")
                                    .font(.title2).bold()
                                    .foregroundColor(selectedTab == .received ? .accentGreen : .warningRed)
                                
                                Text("Monthly Earnings Summary (Placeholder Chart)")
                                    .font(.subheadline).foregroundColor(.textLight)
                                
                                Image(systemName: "chart.bar.xaxis") // Chart placeholder
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 80)
                                    .foregroundColor(.primaryBlue.opacity(0.7))
                                    .padding(.vertical, 5)
                            }
                        }
                        
                        // Payment Cards
                        Section("\(selectedTab.rawValue.capitalized) Transactions") {
                            ForEach(filteredPayments) { payment in
                                PaymentCard(payment: payment)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                                    .swipeActions(edge: .leading) {
                                        if !payment.isPaid {
                                            Button("Mark Paid") {
                                                Task { await markPaymentAsPaid(payment.id!) }
                                            }
                                            .tint(.accentGreen)
                                        }
                                    }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Payments")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isAddPaymentModalPresented = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .task { await fetchPayments() }
            .refreshable { await fetchPayments() }
            .sheet(isPresented: $isAddPaymentModalPresented) {
                AddPaymentFormView(onPaymentAdded: { Task { await fetchPayments() } })
            }
        }
    }
    
    // MARK: - Actions & Data Fetch
    
    func fetchPayments() async {
        isLoading = true
        // NOTE: Mocking instructor ID
        do {
            self.payments = try await paymentManager.fetchInstructorPayments(for: "current_instructor_id")
        } catch {
            print("Failed to fetch payments: \(error)")
        }
        isLoading = false
    }
    
    func markPaymentAsPaid(_ paymentID: String) async {
        do {
            try await paymentManager.updatePaymentStatus(paymentID: paymentID, isPaid: true)
            // Update local array instantly
            if let index = payments.firstIndex(where: { $0.id == paymentID }) {
                payments[index].isPaid = true
            }
        } catch {
            print("Error marking payment as paid: \(error)")
        }
    }
}

enum PaymentTab: String {
    case received = "Received"
    case pending = "Pending"
}

// Payment Card Component
struct PaymentCard: View {
    @State var payment: Payment
    @EnvironmentObject var dataService: DataService
    
    var body: some View {
        let studentName = dataService.getStudentName(for: payment.studentID)
        
        HStack {
            Image(systemName: payment.isPaid ? "checkmark.circle.fill" : "clock.fill")
                .foregroundColor(payment.isPaid ? .accentGreen : .warningRed)
                .font(.title)
            
            VStack(alignment: .leading) {
                Text(studentName).font(.headline) // Student name
                Text(payment.isPaid ? "Received" : "Pending")
                    .font(.caption).bold()
                    .foregroundColor(payment.isPaid ? .accentGreen : .warningRed)
                Text(payment.date, style: .date).font(.caption).foregroundColor(.textLight) // Date
            }
            
            Spacer()
            
            Text("£\(payment.amount, specifier: "%.2f")")
                .font(.title3).bold() // Amount
        }
        .padding(10)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.textDark.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}