// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Dashboard/InstructorDashboardView.swift
// --- FULLY UPDATED: Added Sheet Navigation Wrapper for Quick Actions ---

import SwiftUI

enum DashboardSheet: Identifiable {
    case addLesson, addStudent, studentsList, recordPayment, quickOverview, trackIncome, trackExpense, serviceBook, myVehicles, contacts
    case notes
    case trackExam
    case liveMap
    case analytics
    case allLessons
    case digitalVault
    case mileageLog
    
    var id: Int { self.hashValue }
}

struct InstructorDashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var dataService: DataService
    @EnvironmentObject var communityManager: CommunityManager
    @EnvironmentObject var chatManager: ChatManager
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var vehicleManager: VehicleManager
    @EnvironmentObject var paymentManager: PaymentManager
    
    // --- PERSISTED GOAL SETTING ---
    @AppStorage("weeklyEarningsGoal") private var weeklyEarningsGoal: Double = 500.0
    
    @State private var activeSheet: DashboardSheet?
    @State private var nextLesson: Lesson?
    @State private var nextLessonStudentName: String = "Loading..."
    @State private var weeklyEarnings: Double = 0
    @State private var avgStudentProgress: Double = 0
    @State private var isLoading = true
    @State private var showGoalAlert = false
    
    var notificationCount: Int {
        let unreadAlerts = notificationManager.notifications.filter { !$0.isRead }.count
        return unreadAlerts + pendingRequestCount
    }
    
    @State private var pendingRequestCount: Int = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - Fixed Header
                DashboardHeader(notificationCount: notificationCount)
                    .padding(.bottom, 10)
                
                // MARK: - Scrollable Content
                ScrollView {
                    VStack(spacing: 20) {
                        
                        if isLoading {
                            ProgressView("Loading Dashboard...").padding(.top, 50).frame(maxWidth: .infinity)
                        } else {
                            // Main Cards
                            HStack(spacing: 15) {
                                // 1. Next Lesson Card
                                if let lesson = nextLesson {
                                    NavigationLink(destination: LessonDetailsView(lesson: lesson)) {
                                        DashboardCard(
                                            title: "Next Lesson",
                                            systemIcon: "calendar.badge.clock",
                                            accentColor: .primaryBlue,
                                            fixedHeight: 150,
                                            content: { NextLessonContent(lesson: lesson, studentName: nextLessonStudentName) }
                                        )
                                    }.buttonStyle(.plain).frame(maxWidth: .infinity)
                                } else {
                                    DashboardCard(
                                        title: "Next Lesson",
                                        systemIcon: "calendar.badge.clock",
                                        accentColor: .primaryBlue,
                                        fixedHeight: 150,
                                        content: { NextLessonContent(lesson: nil, studentName: nil) }
                                    ).frame(maxWidth: .infinity)
                                }
                                
                                // 2. Weekly Earnings Card (Dynamic, No Decimals, Edit Icon)
                                NavigationLink(destination: PaymentsView()) {
                                    DashboardCard(
                                        title: "Weekly Goal",
                                        systemIcon: "dollarsign.circle.fill",
                                        accentColor: .accentGreen,
                                        fixedHeight: 150,
                                        headerAction: {
                                            // --- Edit Icon Button ---
                                            Button {
                                                showGoalAlert = true
                                            } label: {
                                                Image(systemName: "pencil")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .padding(6)
                                                    .background(Color(.systemGray6))
                                                    .clipShape(Circle())
                                            }
                                            .buttonStyle(.borderless) // Important to prevent triggering NavigationLink
                                        },
                                        content: {
                                            EarningsSummaryContent(earnings: weeklyEarnings, goal: weeklyEarningsGoal)
                                        }
                                    )
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.horizontal)

                            // "Students Overview" card
                            Button { activeSheet = .studentsList } label: {
                                DashboardCard(title: "Students Overview", systemIcon: "person.3.fill", accentColor: .orange, content: { StudentsOverviewContent(progress: avgStudentProgress) })
                            }.buttonStyle(.plain).padding(.horizontal)
                            
                            // Quick Actions
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Quick Actions").font(.headline).padding(.horizontal)
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                                    
                                    // 1. Lessons
                                    QuickActionButton(title: "Lessons", icon: "list.bullet.clipboard.fill", color: .primaryBlue, action: { activeSheet = .allLessons })
                                    
                                    // 2. Track Exam
                                    QuickActionButton(title: "Track Exam", icon: "flag.checkered", color: .indigo, action: { activeSheet = .trackExam })
                                    
                                    // 3. Track Income
                                    QuickActionButton(title: "Track Income", icon: "chart.line.uptrend.xyaxis", color: .orange, action: { activeSheet = .trackIncome })
                                    
                                    // 4. Track Expense
                                    QuickActionButton(title: "Track Expense", icon: "chart.line.downtrend.xyaxis", color: .warningRed, action: { activeSheet = .trackExpense })
                                    
                                    // 5. Overall Analytics
                                    QuickActionButton(title: "Analytics", icon: "chart.bar.xaxis", color: .accentGreen, action: { activeSheet = .analytics })
                                    
                                    // 6. Record Payment
                                    QuickActionButton(title: "Record Payment", icon: "creditcard.fill", color: .purple, action: { activeSheet = .recordPayment })
                                    
                                    // 7. My Vehicles
                                    QuickActionButton(title: "My Vehicles", icon: "car.circle.fill", color: .primaryBlue, action: { activeSheet = .myVehicles })
                                    // 8. Service Book
                                    QuickActionButton(title: "Service Book", icon: "wrench.and.screwdriver.fill", color: .yellow, action: { activeSheet = .serviceBook })
                                    
                                    // 9. Mileage Log
                                    QuickActionButton(title: "Mileage Log", icon: "speedometer", color: .cyan, action: { activeSheet = .mileageLog })
                                    
                                    // 10. Digital Vault
                                    QuickActionButton(title: "Digital Vault", icon: "lock.shield.fill", color: .accentGreen, action: { activeSheet = .digitalVault })
                                    
                                    // 11. Notes
                                    QuickActionButton(title: "Notes", icon: "note.text", color: .pink, action: { activeSheet = .notes })
                                    // 12. Contacts
                                    QuickActionButton(title: "Contacts", icon: "phone.circle.fill", color: .indigo, action: { activeSheet = .contacts })
                                    
                                    // 13. Live Map
                                    QuickActionButton(title: "Live Map", icon: "map.fill", color: .teal, action: { activeSheet = .liveMap })
                                    
                                    
                                }.padding(.horizontal)
                            }.padding(.top, 15)
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("Dashboard").navigationBarHidden(true)
            .task {
                guard let instructorID = authManager.user?.id else { return }
                chatManager.listenForConversations(for: instructorID)
                notificationManager.listenForNotifications(for: instructorID)
                await fetchData()
            }
            .refreshable { await fetchData() }
            .sheet(item: $activeSheet) { item in
                switch item {
                case .addLesson: AddLessonFormView(onLessonAdded: { _ in Task { await fetchData() } })
                
                case .liveMap:
                    LiveLocationView(lesson: Lesson(instructorID: "", studentID: "", topic: "Live Tracking", startTime: Date(), pickupLocation: "Map View", fee: 0))
                        .environmentObject(locationManager)
                        .environmentObject(lessonManager)
                        .environmentObject(authManager)
                        .environmentObject(dataService)
                    
                case .addStudent: OfflineStudentFormView(studentToEdit: nil, onStudentAdded: { Task { await fetchData() } })
                case .studentsList: StudentsListView()
                case .contacts: ContactsView()
                case .recordPayment: AddPaymentFormView(onPaymentAdded: { Task { await fetchData() } })
                case .quickOverview: StudentQuickOverviewSheet()
                
                // UPDATED: Wrap in NavigationView so we can add a Close button (since we removed the back button)
                case .trackIncome:
                    NavigationView {
                        PaymentsView()
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button("Close") { activeSheet = nil }
                                }
                            }
                    }
                    
                case .trackExpense: ExpensesView()
                case .serviceBook: ServiceBookView()
                case .myVehicles: MyVehiclesView()
                case .digitalVault: DigitalVaultView()
                case .notes: NotesListView()
                case .trackExam: ExamListView()
                case .analytics: InstructorAnalyticsView()
                case .allLessons: InstructorLessonsListView()
                case .mileageLog: MileageLogView()
                }
            }
            // --- ALERT TO SET GOAL ---
            .alert("Set Weekly Goal", isPresented: $showGoalAlert) {
                TextField("Amount", value: $weeklyEarningsGoal, format: .currency(code: "GBP"))
                    .keyboardType(.decimalPad)
                Button("Save") { }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Enter your target earnings for the week.")
            }
        }
    }
    
    func fetchData() async {
        guard let instructorID = authManager.user?.id else { isLoading = false; return }
        isLoading = true
        
        async let dashboardDataTask = dataService.fetchInstructorDashboardData(for: instructorID)
        async let requestsTask = communityManager.fetchRequests(for: instructorID)
        // Fetch payments for accurate weekly calculation
        async let paymentsTask = paymentManager.fetchInstructorPayments(for: instructorID)

        do {
            let data = try await dashboardDataTask
            self.nextLesson = data.nextLesson
            self.avgStudentProgress = data.avgProgress
            
            // Calculate Weekly Earnings (Current Week)
            let allPayments = try await paymentsTask
            let calendar = Calendar.current
            if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) {
                let weeklyPayments = allPayments.filter { $0.date >= weekInterval.start && $0.date < weekInterval.end }
                self.weeklyEarnings = weeklyPayments.reduce(0) { $0 + $1.amount }
            } else {
                self.weeklyEarnings = 0.0
            }
            
            // Resolve Next Lesson Student Name
            if let lesson = self.nextLesson {
                self.nextLessonStudentName = await dataService.resolveStudentName(studentID: lesson.studentID)
            } else {
                self.nextLessonStudentName = "Unknown"
            }
            
            let requests = try await requestsTask
            self.pendingRequestCount = requests.count
        } catch { print("Failed: \(error)") }
        isLoading = false
    }
}

// MARK: - Instructor Lessons List View
struct InstructorLessonsListView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var authManager: AuthManager
    
    @State private var lessons: [Lesson] = []
    @State private var isLoading = true
    @State private var isAddSheetPresented = false
    
    // --- Filters ---
    @State private var selectedFilter: AnalyticsFilter = .monthly
    @State private var currentDate: Date = Date()
    @State private var customStartDate: Date = Date().addingTimeInterval(-86400 * 30)
    @State private var customEndDate: Date = Date()
    
    private let calendar = Calendar.current
    
    var totalLessons: Int { lessons.count }
    var completedLessons: Int { lessons.filter { $0.status == .completed }.count }
    var cancelledLessons: Int { lessons.filter { $0.status == .cancelled }.count }
    var totalHours: Double {
        lessons.reduce(0) { $0 + ($1.duration ?? 3600) / 3600.0 }
    }
    
    var dateRangeDisplay: String {
        switch selectedFilter {
        case .daily: return currentDate.formatted(date: .abbreviated, time: .omitted)
        case .weekly:
            guard let start = calendar.dateInterval(of: .weekOfYear, for: currentDate)?.start,
                  let end = calendar.dateInterval(of: .weekOfYear, for: currentDate)?.end.addingTimeInterval(-1) else { return "" }
            return "\(start.formatted(.dateTime.day().month())) - \(end.formatted(.dateTime.day().month()))"
        case .monthly: return currentDate.formatted(.dateTime.month(.wide).year())
        case .yearly: return currentDate.formatted(.dateTime.year())
        case .custom: return "Custom Range"
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Section
                VStack(spacing: 12) {
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(AnalyticsFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    if selectedFilter == .custom {
                        HStack {
                            DatePicker("Start", selection: $customStartDate, displayedComponents: .date)
                                .labelsHidden()
                            Text("-")
                            DatePicker("End", selection: $customEndDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                        .padding(.horizontal)
                    } else {
                        HStack {
                            Button { shiftDate(by: -1) } label: {
                                Image(systemName: "chevron.left")
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .clipShape(Circle())
                            }
                            
                            Spacer()
                            Text(dateRangeDisplay)
                                .font(.headline)
                            Spacer()
                            
                            Button { shiftDate(by: 1) } label: {
                                Image(systemName: "chevron.right")
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 10)
                .background(Color(.systemGroupedBackground))
                
                // Analytics Header
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        AnalyticsStatCard(title: "Total Lessons", value: Double(totalLessons), type: .number, color: .primaryBlue, icon: "list.bullet.clipboard.fill")
                            .frame(width: 160)
                        
                        AnalyticsStatCard(title: "Total Hours", value: totalHours, type: .number, color: .orange, icon: "clock.fill")
                            .frame(width: 160)
                        
                        AnalyticsStatCard(title: "Completed", value: Double(completedLessons), type: .number, color: .accentGreen, icon: "checkmark.circle.fill")
                            .frame(width: 160)
                        
                        AnalyticsStatCard(title: "Cancelled", value: Double(cancelledLessons), type: .number, color: .warningRed, icon: "xmark.circle.fill")
                            .frame(width: 160)
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
                
                if isLoading {
                    Spacer(); ProgressView("Loading Lessons..."); Spacer()
                } else if lessons.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "steeringwheel",
                        message: "No lessons found for this period.",
                        actionTitle: "Schedule Lesson",
                        action: { isAddSheetPresented = true }
                    )
                    Spacer()
                } else {
                    List {
                        ForEach(lessons.sorted(by: { $0.startTime > $1.startTime })) { lesson in
                            NavigationLink(destination: LessonDetailsView(lesson: lesson)) {
                                ModernLessonCard(lesson: lesson)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("All Lessons")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddSheetPresented = true
                    } label: {
                        Image(systemName: "plus").font(.headline.bold())
                    }
                }
            }
            .sheet(isPresented: $isAddSheetPresented) {
                AddLessonFormView(onLessonAdded: { _ in
                    Task { await fetchLessons() }
                })
            }
            .task {
                await fetchLessons()
            }
            .onChange(of: selectedFilter) { _ in Task { await fetchLessons() } }
            .onChange(of: currentDate) { _ in Task { await fetchLessons() } }
            .onChange(of: customStartDate) { _ in if selectedFilter == .custom { Task { await fetchLessons() } } }
            .onChange(of: customEndDate) { _ in if selectedFilter == .custom { Task { await fetchLessons() } } }
        }
    }
    
    private func shiftDate(by value: Int) {
        let component: Calendar.Component
        switch selectedFilter {
        case .daily: component = .day
        case .weekly: component = .weekOfYear
        case .monthly: component = .month
        case .yearly: component = .year
        default: component = .day
        }
        if let newDate = calendar.date(byAdding: component, value: value, to: currentDate) {
            currentDate = newDate
        }
    }
    
    private func getRange() -> (start: Date, end: Date) {
        switch selectedFilter {
        case .daily:
            let start = calendar.startOfDay(for: currentDate)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return (start, end)
        case .weekly:
            let interval = calendar.dateInterval(of: .weekOfYear, for: currentDate)!
            return (interval.start, interval.end)
        case .monthly:
            let interval = calendar.dateInterval(of: .month, for: currentDate)!
            return (interval.start, interval.end)
        case .yearly:
            let interval = calendar.dateInterval(of: .year, for: currentDate)!
            return (interval.start, interval.end)
        case .custom:
            return (calendar.startOfDay(for: customStartDate), calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: customEndDate))!)
        }
    }
    
    private func fetchLessons() async {
        guard let instructorID = authManager.user?.id else { return }
        isLoading = true
        let range = getRange()
        
        do {
            self.lessons = try await lessonManager.fetchLessons(for: instructorID, start: range.start, end: range.end)
        } catch {
            print("Error fetching lessons: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Instructor Analytics View
enum AnalyticsFilter: String, CaseIterable, Identifiable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
    case custom = "Custom"
    
    var id: String { self.rawValue }
}

struct TransactionItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let amount: Double
    let date: Date
    let type: TransactionType
    
    enum TransactionType { case income, expense }
}

struct InstructorAnalyticsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var paymentManager: PaymentManager
    @EnvironmentObject var expenseManager: ExpenseManager
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var authManager: AuthManager
    // --- Inject VehicleManager for Mileage ---
    @EnvironmentObject var vehicleManager: VehicleManager
    
    // --- Filters ---
    @State private var selectedFilter: AnalyticsFilter = .monthly
    @State private var currentDate: Date = Date()
    @State private var customStartDate: Date = Date().addingTimeInterval(-86400 * 30)
    @State private var customEndDate: Date = Date()
    
    // --- Data ---
    @State private var totalIncome: Double = 0.0
    @State private var totalExpenses: Double = 0.0
    @State private var netProfit: Double = 0.0
    @State private var recentTransactions: [TransactionItem] = []
    
    @State private var totalLessonsCount: Int = 0
    @State private var passRate: Double = 0.0
    @State private var totalExams: Int = 0
    @State private var passedExams: Int = 0
    
    // --- Mileage Stats ---
    @State private var totalMiles: Int = 0
    @State private var businessMiles: Int = 0
    
    // --- Breakdown Data ---
    @State private var expensesByCategory: [(label: String, amount: Double, color: Color)] = []
    @State private var incomeByMethod: [(label: String, amount: Double, color: Color)] = []
    
    @State private var isLoading = true
    
    // --- Helpers ---
    private let calendar = Calendar.current
    
    var dateRangeDisplay: String {
        switch selectedFilter {
        case .daily: return currentDate.formatted(date: .abbreviated, time: .omitted)
        case .weekly:
            guard let start = calendar.dateInterval(of: .weekOfYear, for: currentDate)?.start,
                  let end = calendar.dateInterval(of: .weekOfYear, for: currentDate)?.end.addingTimeInterval(-1) else { return "" }
            return "\(start.formatted(.dateTime.day().month())) - \(end.formatted(.dateTime.day().month()))"
        case .monthly: return currentDate.formatted(.dateTime.month(.wide).year())
        case .yearly: return currentDate.formatted(.dateTime.year())
        case .custom: return "Custom Range"
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Filter Control
                    filterSection
                    
                    if isLoading {
                        VStack(spacing: 20) {
                            ProgressView()
                            Text("Crunching Numbers...")
                                .foregroundColor(.secondary)
                        }
                        .frame(height: 300)
                    } else {
                        VStack(spacing: 24) {
                            financialOverview
                            
                            // --- Mileage Stats Card ---
                            mileageStats
                            
                            performanceStats
                            financialBreakdown
                            recentActivitySection
                            Spacer(minLength: 30)
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await fetchData() }
            .onChange(of: selectedFilter) { _ in Task { await fetchData() } }
            .onChange(of: currentDate) { _ in Task { await fetchData() } }
            .onChange(of: customStartDate) { _ in if selectedFilter == .custom { Task { await fetchData() } } }
            .onChange(of: customEndDate) { _ in if selectedFilter == .custom { Task { await fetchData() } } }
        }
    }
    
    // MARK: - Subviews
    
    private var filterSection: some View {
        VStack(spacing: 12) {
            Picker("Filter", selection: $selectedFilter) {
                ForEach(AnalyticsFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            if selectedFilter == .custom {
                HStack {
                    DatePicker("Start", selection: $customStartDate, displayedComponents: .date)
                        .labelsHidden()
                    Text("-")
                    DatePicker("End", selection: $customEndDate, displayedComponents: .date)
                        .labelsHidden()
                }
            } else {
                HStack {
                    Button { shiftDate(by: -1) } label: { Image(systemName: "chevron.left").padding() }
                    Spacer()
                    Text(dateRangeDisplay).font(.headline)
                    Spacer()
                    Button { shiftDate(by: 1) } label: { Image(systemName: "chevron.right").padding() }
                }
                .padding(.horizontal)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
            }
        }
        .padding(.top, 10)
    }
    
    private var financialOverview: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                NavigationLink(destination: PaymentsView()) {
                    AnalyticsStatCard(title: "Income", value: totalIncome, type: .currency, color: .accentGreen, icon: "arrow.down.left.circle.fill", clickable: true)
                }
                .buttonStyle(.plain)
                
                NavigationLink(destination: ExpensesView()) {
                    AnalyticsStatCard(title: "Expenses", value: totalExpenses, type: .currency, color: .warningRed, icon: "arrow.up.right.circle.fill", clickable: true)
                }
                .buttonStyle(.plain)
            }
            AnalyticsStatCard(title: "Net Profit", value: netProfit, type: .currency, color: .primaryBlue, icon: "banknote.fill", isLarge: true)
        }
        .padding(.horizontal)
    }
    
    // --- Mileage Stats View ---
    private var mileageStats: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 15) {
                Text("Mileage Log").font(.headline)
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("\(totalMiles)").font(.title).bold().foregroundColor(.primary)
                        Text("Total Miles").font(.caption).foregroundColor(.secondary)
                    }
                    
                    Divider().frame(height: 30)
                    
                    VStack(alignment: .leading) {
                        Text("\(businessMiles)").font(.title).bold().foregroundColor(.cyan)
                        Text("Business").font(.caption).foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "car.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.cyan.opacity(0.3))
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .padding(.horizontal)
    }
    
    private var performanceStats: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Performance")
                .font(.headline)
                .padding(.horizontal)
            
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(lineWidth: 12)
                        .opacity(0.1)
                        .foregroundColor(.purple)
                    
                    Circle()
                        .trim(from: 0.0, to: CGFloat(min(passRate / 100, 1.0)))
                        .stroke(style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
                        .foregroundColor(.purple)
                        .rotationEffect(Angle(degrees: 270.0))
                    
                    VStack(spacing: 2) {
                        Text("\(Int(passRate))%")
                            .font(.title2).bold()
                        Text("Pass Rate")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                }
                .frame(width: 120, height: 120)
                
                VStack(alignment: .leading, spacing: 12) {
                    StatRow(label: "Exams", value: "\(totalExams)", icon: "flag.checkered", color: .indigo)
                    StatRow(label: "Passed", value: "\(passedExams)", icon: "checkmark.seal.fill", color: .accentGreen)
                    StatRow(label: "Lessons", value: "\(totalLessonsCount)", icon: "steeringwheel", color: .orange)
                }
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            .padding(.horizontal)
        }
    }
    
    private var financialBreakdown: some View {
        Group {
            if !expensesByCategory.isEmpty || !incomeByMethod.isEmpty {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Financial Breakdown")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 20) {
                        if !incomeByMethod.isEmpty {
                            BreakdownView(title: "Income by Method", items: incomeByMethod)
                        }
                        if !expensesByCategory.isEmpty {
                            BreakdownView(title: "Expense Breakdown", items: expensesByCategory)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Recent Activity")
                .font(.headline)
                .padding(.horizontal)
            
            if recentTransactions.isEmpty {
                Text("No recent activity for this period.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 0) {
                    ForEach(recentTransactions) { item in
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(item.type == .income ? Color.accentGreen.opacity(0.15) : Color.warningRed.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: item.type == .income ? "arrow.down.left" : "arrow.up.right")
                                    .foregroundColor(item.type == .income ? .accentGreen : .warningRed)
                                    .font(.system(size: 14, weight: .bold))
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline).bold()
                                    .foregroundColor(.primary)
                                Text(item.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(item.amount, format: .currency(code: "GBP"))
                                    .font(.subheadline).bold()
                                    .foregroundColor(item.type == .income ? .accentGreen : .warningRed)
                                Text(item.date.formatted(date: .numeric, time: .omitted))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        
                        if item.id != recentTransactions.last?.id {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Logic Helpers
    
    private func shiftDate(by value: Int) {
        let component: Calendar.Component
        switch selectedFilter {
        case .daily: component = .day
        case .weekly: component = .weekOfYear
        case .monthly: component = .month
        case .yearly: component = .year
        default: component = .day
        }
        if let newDate = calendar.date(byAdding: component, value: value, to: currentDate) {
            currentDate = newDate
        }
    }
    
    private func getRange() -> (start: Date, end: Date) {
        switch selectedFilter {
        case .daily:
            let start = calendar.startOfDay(for: currentDate)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return (start, end)
        case .weekly:
            let interval = calendar.dateInterval(of: .weekOfYear, for: currentDate)!
            return (interval.start, interval.end)
        case .monthly:
            let interval = calendar.dateInterval(of: .month, for: currentDate)!
            return (interval.start, interval.end)
        case .yearly:
            let interval = calendar.dateInterval(of: .year, for: currentDate)!
            return (interval.start, interval.end)
        case .custom:
            return (calendar.startOfDay(for: customStartDate), calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: customEndDate))!)
        }
    }
    
    private func fetchData() async {
        guard let instructorID = authManager.user?.id else { return }
        isLoading = true
        
        let range = getRange()
        
        do {
            async let paymentsTask = paymentManager.fetchInstructorPayments(for: instructorID)
            async let expensesTask = expenseManager.fetchExpenses(for: instructorID)
            async let examsTask = lessonManager.fetchExamsForInstructor(instructorID: instructorID)
            async let lessonsTask = lessonManager.fetchLessons(for: instructorID, start: range.start, end: range.end)
            // --- NEW: Fetch Mileage Logs ---
            async let mileageTask = vehicleManager.fetchMileageLogs(for: instructorID)
            
            let allPayments = try await paymentsTask
            let allExpenses = try await expensesTask
            let allExams = try await examsTask
            let rangeLessons = try await lessonsTask
            let allMileage = try await mileageTask
            
            let rangePayments = allPayments.filter { $0.date >= range.start && $0.date < range.end }
            let rangeExpenses = allExpenses.filter { $0.date >= range.start && $0.date < range.end }
            let rangeExams = allExams.filter { $0.date >= range.start && $0.date < range.end }
            let rangeMileage = allMileage.filter { $0.date >= range.start && $0.date < range.end }
            
            self.totalIncome = rangePayments.reduce(0) { $0 + $1.amount }
            self.totalExpenses = rangeExpenses.reduce(0) { $0 + $1.amount }
            self.netProfit = totalIncome - totalExpenses
            self.totalLessonsCount = rangeLessons.count
            
            let completedExams = rangeExams.filter { $0.status == .completed }
            self.totalExams = completedExams.count
            self.passedExams = completedExams.filter { $0.isPass == true }.count
            self.passRate = totalExams > 0 ? (Double(passedExams) / Double(totalExams)) * 100.0 : 0.0
            
            // --- Calculate Mileage Stats ---
            self.totalMiles = rangeMileage.reduce(0) { $0 + $1.distance }
            self.businessMiles = rangeMileage
                .filter { $0.purpose == "Lesson" || $0.purpose == "Commute" || $0.purpose == "Fuel Run" }
                .reduce(0) { $0 + $1.distance }
            
            generateBreakdowns(payments: rangePayments, expenses: rangeExpenses)
            prepareRecentActivity(payments: rangePayments, expenses: rangeExpenses)
            
        } catch { print("Analytics Error: \(error)") }
        
        isLoading = false
    }
    
    private func generateBreakdowns(payments: [Payment], expenses: [Expense]) {
        // Expense by Category
        var expMap: [ExpenseCategory: Double] = [:]
        for e in expenses { expMap[e.category, default: 0] += e.amount }
        
        let sortedExp = expMap.sorted { $0.value > $1.value }
        
        self.expensesByCategory = sortedExp.map { (cat, amt) in
            // Assign color based on category
            let color: Color
            switch cat {
            case .fuel: color = .orange
            case .maintenance: color = .warningRed
            case .insurance: color = .purple
            case .tax: color = .blue
            case .marketing: color = .teal
            case .other: color = .gray
            }
            return (label: cat.rawValue, amount: amt, color: color)
        }
        
        // Income by Method
        var incMap: [String: Double] = [:]
        for p in payments {
            let method = p.paymentMethod?.rawValue ?? "Unknown"
            incMap[method, default: 0] += p.amount
        }
        
        self.incomeByMethod = incMap.sorted { $0.value > $1.value }.map { (method, amt) in
            return (label: method, amount: amt, color: method == "Cash" ? Color.accentGreen : Color.primaryBlue)
        }
    }
    
    private func prepareRecentActivity(payments: [Payment], expenses: [Expense]) {
        var items: [TransactionItem] = []
        
        for p in payments {
            // Note: studentID is just an ID here. In a real app we'd fetch names,
            // but for "recent activity" overview, "Payment" is sufficient.
            // subtitle can show payment method or note.
            let subtitle = p.note?.isEmpty == false ? p.note! : (p.paymentMethod?.rawValue ?? "Student Payment")
            items.append(TransactionItem(title: "Payment Received", subtitle: subtitle, amount: p.amount, date: p.date, type: .income))
        }
        
        for e in expenses {
            items.append(TransactionItem(title: e.title, subtitle: e.category.rawValue, amount: e.amount, date: e.date, type: .expense))
        }
        
        self.recentTransactions = Array(items.sorted(by: { $0.date > $1.date }).prefix(5))
    }
}

// MARK: - Breakdown View
struct BreakdownView: View {
    let title: String
    let items: [(label: String, amount: Double, color: Color)]
    
    var total: Double { items.reduce(0) { $0 + $1.amount } }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline).bold().foregroundColor(.secondary)
            ForEach(items, id: \.label) { item in
                VStack(spacing: 5) {
                    HStack {
                        Text(item.label).font(.caption).fontWeight(.medium)
                        Spacer()
                        Text(item.amount, format: .currency(code: "GBP")).font(.caption).bold()
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(.systemGray6))
                            Capsule().fill(item.color).frame(width: total > 0 ? (item.amount / total) * geo.size.width : 0)
                        }
                    }.frame(height: 6)
                }
            }
        }
    }
}

// MARK: - Analytics Components

struct AnalyticsStatCard: View {
    let title: String
    let value: Double
    let type: ValueType
    let color: Color
    let icon: String
    var isLarge: Bool = false
    var clickable: Bool = false
    
    enum ValueType { case currency, number }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundColor(color).font(isLarge ? .title2 : .body)
                Spacer()
                if clickable { Image(systemName: "chevron.right").font(.caption2).foregroundColor(.secondary.opacity(0.5)) }
            }
            if type == .currency {
                Text(value, format: .currency(code: "GBP")).font(isLarge ? .title : .title3).bold().foregroundColor(.primary).minimumScaleFactor(0.8)
            } else {
                Text(value.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(value))" : String(format: "%.1f", value)).font(isLarge ? .title : .title3).bold().foregroundColor(.primary)
            }
            Text(title).font(.caption).foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct StatRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(color).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.headline)
                Text(label).font(.caption).foregroundColor(.secondary)
            }
        }
    }
}

struct StudentQuickOverviewSheet: View {
    @EnvironmentObject var dataService: DataService; @EnvironmentObject var authManager: AuthManager; @Environment(\.dismiss) var dismiss
    @State private var onlineStudents: [Student] = []; @State private var offlineStudents: [OfflineStudent] = []; @State private var isLoading = true; @State private var searchText = ""; @State private var isAddingStudent = false
    var filteredOnline: [Student] { if searchText.isEmpty { return onlineStudents }; return onlineStudents.filter { $0.name.localizedCaseInsensitiveContains(searchText) } }
    var filteredOffline: [OfflineStudent] { if searchText.isEmpty { return offlineStudents }; return offlineStudents.filter { $0.name.localizedCaseInsensitiveContains(searchText) } }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack { Image(systemName: "magnifyingglass").foregroundColor(.secondary); TextField("Search students...", text: $searchText); if !searchText.isEmpty { Button(action: { searchText = "" }) { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) } } }.padding(10).background(Color(.secondarySystemGroupedBackground)).cornerRadius(10).padding(.horizontal).padding(.vertical, 10)
                    if isLoading { Spacer(); ProgressView("Loading Students..."); Spacer() } else if filteredOnline.isEmpty && filteredOffline.isEmpty { Spacer(); Text("No students found.").foregroundColor(.secondary); Spacer() } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                if !filteredOnline.isEmpty { VStack(alignment: .leading, spacing: 8) { Text("ONLINE").font(.caption).bold().foregroundColor(.secondary).padding(.leading, 20); ForEach(filteredOnline) { s in NavigationLink(destination: StudentProfileView(student: s)) { StudentCardRow(student: s, isOffline: false) }.buttonStyle(.plain) } } }
                                if !filteredOffline.isEmpty { VStack(alignment: .leading, spacing: 8) { Text("OFFLINE").font(.caption).bold().foregroundColor(.secondary).padding(.leading, 20); ForEach(filteredOffline) { o in NavigationLink(destination: StudentProfileView(student: convertToStudent(o))) { StudentCardRow(student: convertToStudent(o), isOffline: true) }.buttonStyle(.plain) } } }
                            }.padding(.vertical)
                        }
                    }
                }
            }
            .navigationTitle("Your Students").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button(action: { dismiss() }) { HStack(spacing: 5) { Image(systemName: "chevron.left"); Text("Back") }.foregroundColor(.textDark) } }; ToolbarItem(placement: .navigationBarTrailing) { Button(action: { isAddingStudent = true }) { Image(systemName: "plus").font(.headline).foregroundColor(.primaryBlue) } } }
            .task { await loadStudents() }.sheet(isPresented: $isAddingStudent) { OfflineStudentFormView(studentToEdit: nil, onStudentAdded: { Task { await loadStudents() } }) }
        }
    }
    private func loadStudents() async { guard let id = authManager.user?.id else { return }; isLoading = true; do { async let online = dataService.fetchStudents(for: id); async let offline = dataService.fetchOfflineStudents(for: id); self.onlineStudents = try await online; self.offlineStudents = try await offline } catch { print("Error: \(error)") }; isLoading = false }
    private func convertToStudent(_ o: OfflineStudent) -> Student { Student(id: o.id, userID: o.id ?? UUID().uuidString, name: o.name, email: o.email ?? "", phone: o.phone, address: o.address, isOffline: true, averageProgress: o.progress ?? 0.0) }
}

struct StudentCardRow: View { let student: Student; let isOffline: Bool; var body: some View { HStack(spacing: 15) { AsyncImage(url: URL(string: student.photoURL ?? "")) { p in if let i = p.image { i.resizable().scaledToFill() } else { Image(systemName: "person.crop.circle.fill").resizable().foregroundColor(isOffline ? .gray : .primaryBlue) } }.frame(width: 50, height: 50).clipShape(Circle()).overlay(Circle().stroke(Color.secondary.opacity(0.1), lineWidth: 1)); VStack(alignment: .leading, spacing: 4) { Text(student.name).font(.headline).foregroundColor(.primary); HStack(spacing: 6) { Circle().fill(isOffline ? Color.gray : Color.accentGreen).frame(width: 8, height: 8); Text(isOffline ? "Offline Student" : "Active Student").font(.subheadline).foregroundColor(.secondary) } }; Spacer(); ZStack { Circle().stroke(lineWidth: 4).opacity(0.15).foregroundColor(isOffline ? .gray : .primaryBlue); Circle().trim(from: 0.0, to: CGFloat(min(student.averageProgress, 1.0))).stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)).foregroundColor(isOffline ? .gray : .primaryBlue).rotationEffect(Angle(degrees: 270.0)); Text("\(Int(student.averageProgress * 100))%").font(.system(size: 10, weight: .bold)).minimumScaleFactor(0.5).foregroundColor(.primary).padding(2) }.frame(width: 50, height: 50); Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary.opacity(0.5)) }.padding(16).background(Color(.secondarySystemGroupedBackground)).cornerRadius(16).padding(.horizontal).shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2) } }

// MARK: - Redesigned Next Lesson Content
struct NextLessonContent: View {
    let lesson: Lesson?
    var studentName: String? // Added student name parameter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let l = lesson {
                // Name (Prominent)
                HStack {
                    Image(systemName: "person.fill").foregroundColor(.primaryBlue)
                    Text(studentName ?? "Loading...")
                        .font(.headline)
                        .lineLimit(1)
                }
                
                // Time
                HStack {
                    Image(systemName: "clock.fill").foregroundColor(.secondary)
                    Text(l.startTime.formatted(date: .omitted, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Pickup Location (Icon only, text removed)
                HStack {
                    Image(systemName: "location.fill").foregroundColor(.secondary)
                    Text(l.pickupLocation) // Removed "Pickup: " prefix
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text("No Upcoming Lessons")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - UPDATED Earnings Content (Dynamic)
struct EarningsSummaryContent: View {
    let earnings: Double
    let goal: Double
    
    var progress: Double {
        guard goal > 0 else { return 0 }
        return min(earnings / goal, 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .lastTextBaseline) {
                // UPDATED: Added .precision(.fractionLength(0)) to remove decimals
                Text(earnings, format: .currency(code: "GBP").precision(.fractionLength(0)))
                    .font(.title2).bold()
                    .foregroundColor(.accentGreen)
                
                Spacer()
                
                // UPDATED: Added .precision(.fractionLength(0)) to remove decimals
                Text("/ \(goal.formatted(.currency(code: "GBP").precision(.fractionLength(0))))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("This Week Earnings").font(.subheadline).foregroundColor(.secondary)
            
            // Dynamic Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    Capsule()
                        .fill(Color.accentGreen)
                        .frame(width: max(0, CGFloat(progress) * geometry.size.width), height: 8)
                        .animation(.spring(), value: progress)
                }
            }
            .frame(height: 8)
        }
    }
}

struct StudentsOverviewContent: View { let progress: Double; var body: some View { HStack { CircularProgressView(progress: progress, color: .orange, size: 60).padding(.trailing, 10); VStack(alignment: .leading) { Text("Average Student Progress").font(.subheadline).foregroundColor(.secondary); Text("\(Int(progress * 100))% Mastery").font(.headline) }; Spacer(); Image(systemName: "chevron.right").foregroundColor(.secondary) } } }

// UPDATED: DashboardCard with optional headerAction
struct DashboardCard<Content: View, HeaderAction: View>: View {
    let title: String
    let systemIcon: String
    var accentColor: Color = .primaryBlue
    var fixedHeight: CGFloat? = nil
    @ViewBuilder let headerAction: HeaderAction
    @ViewBuilder let content: Content
    
    // Custom Init to allow optional headerAction
    init(title: String, systemIcon: String, accentColor: Color = .primaryBlue, fixedHeight: CGFloat? = nil, @ViewBuilder headerAction: () -> HeaderAction = { EmptyView() }, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemIcon = systemIcon
        self.accentColor = accentColor
        self.fixedHeight = fixedHeight
        self.headerAction = headerAction()
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: systemIcon)
                    .font(.subheadline).bold()
                    .foregroundColor(accentColor)
                Spacer()
                headerAction // Insert header action here (e.g., Edit Button)
            }
            Divider().opacity(0.5)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
            if fixedHeight != nil {
                Spacer(minLength: 0)
            }
        }
        .padding(15)
        .frame(height: fixedHeight)
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

struct QuickActionButton: View { let title: String; let icon: String; let color: Color; let action: () -> Void; var body: some View { Button(action: action) { VStack(spacing: 5) { Image(systemName: icon).font(.title2); Text(title).font(.caption).bold().lineLimit(1) }.frame(maxWidth: .infinity).padding(.vertical, 15).background(color.opacity(0.15)).foregroundColor(color).cornerRadius(12) } } }
