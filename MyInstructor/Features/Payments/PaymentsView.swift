// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Payments/PaymentsView.swift
// --- UPDATED: Added Back button to upper left corner ---

import SwiftUI

enum TimeFilter: String, CaseIterable, Identifiable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
    case custom = "Specific"
    
    var id: String { self.rawValue }
}

enum PaymentTab {
    case received, pending
}

// Wrapper struct to unify Payments and Lessons for the list
struct IncomeItem: Identifiable {
    let id: String
    let date: Date
    let amount: Double
    let studentID: String
    let isPaid: Bool
    let type: ItemType
    let originalPayment: Payment? // Non-nil if it's a record
    let originalLesson: Lesson? // Non-nil if it's a lesson
    
    enum ItemType {
        case paymentRecord // Actual Payment document
        case upcomingLesson // Scheduled Lesson (Future Income)
    }
}

struct PaymentsView: View {
    @EnvironmentObject var paymentManager: PaymentManager
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var dataService: DataService
    @EnvironmentObject var authManager: AuthManager
    
    // --- NEW: Dismiss environment for Back button ---
    @Environment(\.dismiss) var dismiss
    
    @State private var payments: [Payment] = []
    @State private var upcomingLessons: [Lesson] = []
    
    // Filters
    @State private var selectedTab: PaymentTab = .received
    @State private var timeFilter: TimeFilter = .monthly
    
    // Custom Date Range
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    
    // Sheets & Loading
    @State private var isAddPaymentModalPresented = false
    @State private var paymentToEdit: Payment? = nil
    
    // Read-only state for pending payments
    @State private var paymentToView: Payment? = nil
    
    @State private var isLoading = true
    
    // MARK: - Computed Properties (Unified Logic)
    
    var allItems: [IncomeItem] {
        var items: [IncomeItem] = []
        
        // Add Payments
        for p in payments {
            items.append(IncomeItem(
                id: p.id ?? UUID().uuidString,
                date: p.date,
                amount: p.amount,
                studentID: p.studentID,
                isPaid: p.isPaid,
                type: .paymentRecord,
                originalPayment: p,
                originalLesson: nil
            ))
        }
        
        // Add Upcoming Lessons
        for l in upcomingLessons {
            let durationHours = (l.duration ?? 3600) / 3600
            let estimatedAmount = l.fee * durationHours
            
            items.append(IncomeItem(
                id: l.id ?? UUID().uuidString,
                date: l.startTime,
                amount: estimatedAmount,
                studentID: l.studentID,
                isPaid: false,
                type: .upcomingLesson,
                originalPayment: nil,
                originalLesson: l // Store lesson for navigation
            ))
        }
        
        return items
    }
    
    var timeFilteredItems: [IncomeItem] {
        allItems.filter { item in
            switch timeFilter {
            case .daily:
                return Calendar.current.isDateInToday(item.date)
            case .weekly:
                return Calendar.current.isDate(item.date, equalTo: Date(), toGranularity: .weekOfYear)
            case .monthly:
                return Calendar.current.isDate(item.date, equalTo: Date(), toGranularity: .month)
            case .yearly:
                return Calendar.current.isDate(item.date, equalTo: Date(), toGranularity: .year)
            case .custom:
                let start = Calendar.current.startOfDay(for: customStartDate)
                let end = Calendar.current.endOfDay(for: customEndDate)
                return item.date >= start && item.date <= end
            }
        }
    }
    
    var listDisplayItems: [IncomeItem] {
        timeFilteredItems
            .filter { item in
                if selectedTab == .received {
                    return item.isPaid
                } else {
                    return !item.isPaid
                }
            }
            .sorted(by: { $0.date > $1.date })
    }
    
    var totalReceived: Double {
        timeFilteredItems.filter { $0.isPaid }.reduce(0) { $0 + $1.amount }
    }
    
    var totalPending: Double {
        timeFilteredItems.filter { !$0.isPaid }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 15) {
                
                // MARK: - Time Filter Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(TimeFilter.allCases) { filter in
                            Button {
                                withAnimation { timeFilter = filter }
                            } label: {
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
                        VStack(alignment: .leading) {
                            Text("From").font(.caption).foregroundColor(.secondary)
                            DatePicker("", selection: $customStartDate, displayedComponents: .date).labelsHidden()
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("To").font(.caption).foregroundColor(.secondary)
                            DatePicker("", selection: $customEndDate, displayedComponents: .date).labelsHidden()
                        }
                    }
                    .padding(.horizontal)
                }
                
                // MARK: - Summary Cards
                HStack(spacing: 15) {
                    SummaryCard(
                        title: "Pending",
                        amount: totalPending,
                        icon: "clock.arrow.circlepath",
                        color: .orange,
                        isSelected: selectedTab == .pending
                    )
                    .onTapGesture { withAnimation { selectedTab = .pending } }
                    
                    SummaryCard(
                        title: "Received",
                        amount: totalReceived,
                        icon: "banknote.fill",
                        color: .accentGreen,
                        isSelected: selectedTab == .received
                    )
                    .onTapGesture { withAnimation { selectedTab = .received } }
                }
                .padding(.horizontal)
                
                // MARK: - Transactions List
                if isLoading {
                    Spacer()
                    ProgressView("Loading Records...")
                    Spacer()
                } else if listDisplayItems.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: selectedTab == .pending ? "checkmark.seal" : "tray",
                        message: selectedTab == .pending
                            ? "No pending payments or upcoming lessons."
                            : "No income recorded for this period."
                    )
                    Spacer()
                } else {
                    List {
                        ForEach(listDisplayItems) { item in
                            
                            // 1. RECEIVED (Editable)
                            if selectedTab == .received, item.type == .paymentRecord, let payment = item.originalPayment {
                                Button {
                                    paymentToEdit = payment // Edit Mode
                                } label: {
                                    IncomeItemCard(item: item)
                                }
                                .buttonStyle(.plain)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task { await deletePayment(payment.id!) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            
                            // 2. UPCOMING LESSON (Navigate to Details)
                            else if item.type == .upcomingLesson, let lesson = item.originalLesson {
                                NavigationLink(destination: LessonDetailsView(lesson: lesson)) {
                                    IncomeItemCard(item: item)
                                }
                                .buttonStyle(.plain)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            }
                            
                            // 3. PENDING RECORD (View Only)
                            else if item.type == .paymentRecord, let payment = item.originalPayment {
                                Button {
                                    paymentToView = payment // View Mode (Read Only)
                                } label: {
                                    IncomeItemCard(item: item)
                                }
                                .buttonStyle(.plain)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .swipeActions(edge: .leading) {
                                    // Mark Paid
                                    Button("Mark Paid") {
                                        Task { await markPaymentAsPaid(payment.id!) }
                                    }
                                    .tint(.accentGreen)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Track Income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // --- NEW: Back Button ---
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isAddPaymentModalPresented = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline).bold()
                    }
                }
            }
            .task { await fetchData() }
            .refreshable { await fetchData() }
            
            // Sheet for Adding
            .sheet(isPresented: $isAddPaymentModalPresented) {
                AddPaymentFormView(onPaymentAdded: { Task { await fetchData() } })
            }
            // Sheet for Editing (Received)
            .sheet(item: $paymentToEdit) { payment in
                AddPaymentFormView(paymentToEdit: payment, onPaymentAdded: {
                    paymentToEdit = nil
                    Task { await fetchData() }
                })
            }
            // Sheet for Viewing (Pending) - Read Only
            .sheet(item: $paymentToView) { payment in
                AddPaymentFormView(
                    paymentToEdit: payment,
                    onPaymentAdded: { }, // No action needed
                    isReadOnly: true // --- Enable Read Only Mode ---
                )
            }
        }
    }
    
    // MARK: - Logic Helpers
    
    func fetchData() async {
        guard let instructorID = authManager.user?.id else { return }
        isLoading = true
        do {
            async let paymentsTask = paymentManager.fetchInstructorPayments(for: instructorID)
            async let lessonsTask = lessonManager.fetchUpcomingLessons(for: instructorID)
            
            self.payments = try await paymentsTask
            self.upcomingLessons = try await lessonsTask
            
        } catch {
            print("Failed to fetch data: \(error)")
        }
        isLoading = false
    }
    
    func markPaymentAsPaid(_ paymentID: String) async {
        try? await paymentManager.updatePaymentStatus(paymentID: paymentID, isPaid: true)
        if let idx = payments.firstIndex(where: { $0.id == paymentID }) {
            payments[idx].isPaid = true
        }
    }
    
    func deletePayment(_ paymentID: String) async {
        try? await paymentManager.deletePayment(paymentID: paymentID)
        withAnimation {
            payments.removeAll(where: { $0.id == paymentID })
        }
    }
}

// MARK: - Components

struct SummaryCard: View {
    let title: String
    let amount: Double
    let icon: String
    let color: Color
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : color)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
            }
            
            Text(amount, format: .currency(code: "GBP"))
                .font(.title2).bold()
                .foregroundColor(isSelected ? .white : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(isSelected ? color : Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: isSelected ? color.opacity(0.3) : Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.clear : color.opacity(0.2), lineWidth: 1)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

struct IncomeItemCard: View {
    let item: IncomeItem
    @EnvironmentObject var dataService: DataService
    @State private var studentName: String = "Loading..."
    
    var statusColor: Color {
        if item.isPaid { return .accentGreen }
        return item.type == .upcomingLesson ? .primaryBlue : .orange
    }
    
    var statusIcon: String {
        if item.isPaid { return "checkmark" }
        return item.type == .upcomingLesson ? "calendar" : "clock"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 45, height: 45)
                
                Image(systemName: statusIcon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(statusColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(studentName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    Text(item.date.formatted(date: .abbreviated, time: .shortened))
                    if item.type == .upcomingLesson {
                        Text("• Scheduled")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.primaryBlue)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(item.amount, format: .currency(code: "GBP"))
                    .font(.headline)
                    .foregroundColor(statusColor)
                
                if item.isPaid, let method = item.originalPayment?.paymentMethod {
                    Text(method.rawValue)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray6))
                        .cornerRadius(4)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
        .task {
            self.studentName = await dataService.resolveStudentName(studentID: item.studentID)
        }
    }
}

extension Calendar {
    func endOfDay(for date: Date) -> Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return self.date(byAdding: components, to: startOfDay(for: date)) ?? date
    }
}
