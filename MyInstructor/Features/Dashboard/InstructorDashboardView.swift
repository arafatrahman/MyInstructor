// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Dashboard/InstructorDashboardView.swift
// --- UPDATED: Includes Service Book and My Vehicles features ---
// --- UPDATED: Next Lesson and Weekly Earnings cards have equal height ---

import SwiftUI

// Definition for the active sheet
enum DashboardSheet: Identifiable {
    case addLesson
    case addStudent
    case recordPayment
    case quickOverview
    case trackIncome
    case trackExpense
    case serviceBook  // New
    case myVehicles   // New
    
    var id: Int { self.hashValue }
}

// Flow Item 5: Instructor Dashboard
struct InstructorDashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var dataService: DataService
    @EnvironmentObject var communityManager: CommunityManager
    @EnvironmentObject var chatManager: ChatManager
    
    // --- NEW: Single State for Sheet Management ---
    @State private var activeSheet: DashboardSheet?

    @State private var nextLesson: Lesson?
    @State private var weeklyEarnings: Double = 0
    @State private var avgStudentProgress: Double = 0
    @State private var isLoading = true
    
    @State private var notificationCount: Int = 0

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    DashboardHeader(notificationCount: notificationCount)
                    
                    if isLoading {
                        ProgressView("Loading Dashboard...")
                            .padding(.top, 50)
                            .frame(maxWidth: .infinity)
                    } else {
                        // MARK: - Main Cards (Equal Height)
                        HStack(spacing: 15) {
                            
                            // 1. Next Lesson
                            if let lesson = nextLesson {
                                NavigationLink(destination: LessonDetailsView(lesson: lesson)) {
                                    DashboardCard(title: "Next Lesson", systemIcon: "calendar.badge.clock", accentColor: .primaryBlue, fixedHeight: 150, content: {
                                        NextLessonContent(lesson: lesson)
                                    })
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity) // Ensure Link fills space
                            } else {
                                DashboardCard(title: "Next Lesson", systemIcon: "calendar.badge.clock", accentColor: .primaryBlue, fixedHeight: 150, content: {
                                    NextLessonContent(lesson: nextLesson)
                                })
                                .frame(maxWidth: .infinity)
                            }
                            
                            // 2. Earnings
                            DashboardCard(title: "Weekly Earnings", systemIcon: "dollarsign.circle.fill", accentColor: .accentGreen, fixedHeight: 150, content: {
                                EarningsSummaryContent(earnings: weeklyEarnings)
                            })
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal)

                        // 3. Students Overview
                        Button {
                            activeSheet = .quickOverview
                        } label: {
                            DashboardCard(title: "Students Overview", systemIcon: "person.3.fill", accentColor: .orange, content: {
                                StudentsOverviewContent(progress: avgStudentProgress)
                            })
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        
                        // MARK: - Quick Actions
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Quick Actions")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                                QuickActionButton(title: "Add Lesson", icon: "plus.circle.fill", color: .primaryBlue, action: {
                                    activeSheet = .addLesson
                                })
                                
                                QuickActionButton(title: "Add Student", icon: "person.badge.plus.fill", color: .accentGreen, action: {
                                    activeSheet = .addStudent
                                })
                                
                                QuickActionButton(title: "Record Payment", icon: "creditcard.fill", color: .purple, action: {
                                    activeSheet = .recordPayment
                                })
                                
                                QuickActionButton(title: "Track Income", icon: "chart.line.uptrend.xyaxis", color: .orange, action: {
                                    activeSheet = .trackIncome
                                })
                                
                                // --- Track Expense Action ---
                                QuickActionButton(title: "Track Expense", icon: "chart.line.downtrend.xyaxis", color: .warningRed, action: {
                                    activeSheet = .trackExpense
                                })
                                
                                // --- Service Book Action ---
                                QuickActionButton(title: "Service Book", icon: "wrench.and.screwdriver.fill", color: .gray, action: {
                                    activeSheet = .serviceBook
                                })
                                
                                // --- My Vehicles Action ---
                                QuickActionButton(title: "My Vehicles", icon: "car.circle.fill", color: .primaryBlue, action: {
                                    activeSheet = .myVehicles
                                })
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 15)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarHidden(true)
            .task {
                guard let instructorID = authManager.user?.id else { return }
                chatManager.listenForConversations(for: instructorID)
                await fetchData()
            }
            .refreshable {
                await fetchData()
            }
            // --- UNIFIED SHEET HANDLING ---
            .sheet(item: $activeSheet) { item in
                switch item {
                case .addLesson:
                    AddLessonFormView(onLessonAdded: { _ in Task { await fetchData() } })
                case .addStudent:
                    OfflineStudentFormView(studentToEdit: nil, onStudentAdded: { Task { await fetchData() } })
                case .recordPayment:
                    AddPaymentFormView(onPaymentAdded: { Task { await fetchData() } })
                case .quickOverview:
                    StudentQuickOverviewSheet()
                case .trackIncome:
                    PaymentsView()
                case .trackExpense:
                    ExpensesView()
                case .serviceBook:
                    ServiceBookView()
                case .myVehicles:
                    MyVehiclesView()
                }
            }
        }
    }
    
    func fetchData() async {
        guard let instructorID = authManager.user?.id else {
            isLoading = false
            return
        }
        isLoading = true
        async let dashboardDataTask = dataService.fetchInstructorDashboardData(for: instructorID)
        async let notificationCountTask = communityManager.fetchRequests(for: instructorID)

        do {
            let data = try await dashboardDataTask
            self.nextLesson = data.nextLesson
            self.weeklyEarnings = data.earnings
            self.avgStudentProgress = data.avgProgress
            self.notificationCount = (try await notificationCountTask).count
        } catch {
            print("Failed to fetch instructor data: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Redesigned Quick View Sheet (Same as before)
struct StudentQuickOverviewSheet: View {
    @EnvironmentObject var dataService: DataService
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var onlineStudents: [Student] = []
    @State private var offlineStudents: [OfflineStudent] = []
    @State private var isLoading = true
    @State private var searchText = ""
    
    var filteredOnline: [Student] {
        if searchText.isEmpty { return onlineStudents }
        return onlineStudents.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var filteredOffline: [OfflineStudent] {
        if searchText.isEmpty { return offlineStudents }
        return offlineStudents.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField("Search students...", text: $searchText)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) }
                        }
                    }
                    .padding(10).background(Color(.secondarySystemGroupedBackground)).cornerRadius(10).padding(.horizontal).padding(.bottom, 10)
                    
                    if isLoading { Spacer(); ProgressView("Loading Students..."); Spacer() }
                    else if filteredOnline.isEmpty && filteredOffline.isEmpty { Spacer(); Text("No students found.").foregroundColor(.secondary); Spacer() }
                    else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                if !filteredOnline.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("ONLINE").font(.caption).bold().foregroundColor(.secondary).padding(.leading, 4)
                                        ForEach(filteredOnline) { s in NavigationLink(destination: StudentProfileView(student: s)) { StudentCardRow(student: s, isOffline: false) }.buttonStyle(.plain) }
                                    }.padding(.horizontal)
                                }
                                if !filteredOffline.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("OFFLINE").font(.caption).bold().foregroundColor(.secondary).padding(.leading, 4)
                                        ForEach(filteredOffline) { o in NavigationLink(destination: StudentProfileView(student: convertToStudent(o))) { StudentCardRow(student: convertToStudent(o), isOffline: true) }.buttonStyle(.plain) }
                                    }.padding(.horizontal)
                                }
                            }.padding(.vertical)
                        }
                    }
                }.padding(.top, 10)
            }
            .navigationTitle("Your Students").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() }.bold() } }
            .task { await loadStudents() }
        }
    }
    private func loadStudents() async {
        guard let id = authManager.user?.id else { return }
        isLoading = true
        do {
            async let online = dataService.fetchStudents(for: id)
            async let offline = dataService.fetchOfflineStudents(for: id)
            self.onlineStudents = try await online
            self.offlineStudents = try await offline
        } catch { print("Error: \(error)") }
        isLoading = false
    }
    private func convertToStudent(_ o: OfflineStudent) -> Student {
        Student(id: o.id, userID: o.id ?? UUID().uuidString, name: o.name, email: o.email ?? "", phone: o.phone, address: o.address, isOffline: true, averageProgress: o.progress ?? 0.0)
    }
}

// MARK: - Reusable Components (Same as before)
struct StudentCardRow: View {
    let student: Student; let isOffline: Bool
    var body: some View {
        HStack(spacing: 15) {
            AsyncImage(url: URL(string: student.photoURL ?? "")) { p in if let i = p.image { i.resizable().scaledToFill() } else { Image(systemName: "person.crop.circle.fill").resizable().foregroundColor(isOffline ? .gray : .primaryBlue) } }.frame(width: 50, height: 50).clipShape(Circle()).overlay(Circle().stroke(Color.secondary.opacity(0.1), lineWidth: 1))
            VStack(alignment: .leading, spacing: 4) { Text(student.name).font(.headline).foregroundColor(.primary); HStack(spacing: 6) { Circle().fill(isOffline ? Color.gray : Color.accentGreen).frame(width: 8, height: 8); Text(isOffline ? "Offline Student" : "Active Student").font(.subheadline).foregroundColor(.secondary) } }
            Spacer()
            HStack(spacing: 12) { CircularProgressView(progress: student.averageProgress, color: isOffline ? .gray : .primaryBlue, lineWidth: 4, size: 40); Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary.opacity(0.5)) }
        }.padding(16).background(Color(.secondarySystemGroupedBackground)).cornerRadius(16).shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}
struct NextLessonContent: View { let lesson: Lesson?; var body: some View { VStack(alignment: .leading, spacing: 8) { if let l = lesson { Text(l.topic).font(.subheadline).bold().lineLimit(1); HStack { Image(systemName: "clock"); Text("\(l.startTime, style: .time)") }.font(.callout).foregroundColor(.textLight); HStack { Image(systemName: "map.pin.circle.fill"); Text("Pickup: \(l.pickupLocation)").lineLimit(1) }.font(.callout).foregroundColor(.textLight) } else { Text("No Upcoming Lessons").font(.subheadline).bold().foregroundColor(.textLight) } } } }
struct EarningsSummaryContent: View { let earnings: Double; var body: some View { VStack(alignment: .leading, spacing: 4) { Text("£\(earnings, specifier: "%.2f")").font(.title2).bold().foregroundColor(.accentGreen); Text("This Week").font(.subheadline).foregroundColor(.textLight); Rectangle().fill(Color.accentGreen.opacity(0.3)).frame(height: 10).cornerRadius(5) } } }
struct StudentsOverviewContent: View { let progress: Double; var body: some View { HStack { CircularProgressView(progress: progress, color: .orange, size: 60).padding(.trailing, 10); VStack(alignment: .leading) { Text("Average Student Progress").font(.subheadline).foregroundColor(.textLight); Text("\(Int(progress * 100))% Mastery").font(.headline) }; Spacer(); Image(systemName: "chevron.right").foregroundColor(.textLight) } } }

// --- UPDATED DashboardCard with fixedHeight support ---
struct DashboardCard<Content: View>: View {
    let title: String
    let systemIcon: String
    var accentColor: Color = .primaryBlue
    var fixedHeight: CGFloat? = nil // Optional fixed height
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: systemIcon).font(.subheadline).bold().foregroundColor(accentColor);
                Spacer()
            };
            Divider().opacity(0.5);
            content.frame(maxWidth: .infinity, alignment: .leading)
            if fixedHeight != nil { Spacer(minLength: 0) } // Push content up if height is fixed
        }
        .padding(15)
        .frame(height: fixedHeight) // Apply fixed height if set
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.textDark.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

struct QuickActionButton: View { let title: String; let icon: String; let color: Color; let action: () -> Void; var body: some View { Button(action: action) { VStack(spacing: 5) { Image(systemName: icon).font(.title2); Text(title).font(.caption).bold().lineLimit(1) }.frame(maxWidth: .infinity).padding(.vertical, 15).background(color.opacity(0.15)).foregroundColor(color).cornerRadius(12) } } }
