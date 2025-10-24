import SwiftUI

// Flow Item 5: Instructor Dashboard
struct InstructorDashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var dataService: DataService
    
    @State private var nextLesson: Lesson?
    @State private var weeklyEarnings: Double = 0
    @State private var avgStudentProgress: Double = 0
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    DashboardHeader() // Shared Component (Profile & Notifications)
                    
                    if isLoading {
                        ProgressView("Loading Dashboard...")
                            .padding(.top, 50)
                            .frame(maxWidth: .infinity)
                    } else {
                        // MARK: - Main Cards (Metrics Grid)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                            
                            // 1. Next Lesson Card
                            DashboardCard(title: "Next Lesson", systemIcon: "calendar.badge.clock", accentColor: .primaryBlue, content: {
                                NextLessonContent(lesson: nextLesson)
                            })
                            
                            // 2. Earnings Summary Card
                            DashboardCard(title: "Weekly Earnings", systemIcon: "dollarsign.circle.fill", accentColor: .accentGreen, content: {
                                EarningsSummaryContent(earnings: weeklyEarnings)
                            })
                        }
                        .padding(.horizontal)

                        // 3. Students Overview Card (Full Width)
                        DashboardCard(title: "Students Overview", systemIcon: "person.3.fill", accentColor: .orange, content: {
                            StudentsOverviewContent(progress: avgStudentProgress)
                        })
                        .padding(.horizontal)
                        
                        // MARK: - Quick Actions
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Quick Actions")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            HStack(spacing: 15) {
                                QuickActionButton(title: "Add Lesson", icon: "plus.circle.fill", color: .primaryBlue, action: {
                                    // TODO: Navigate to Add Lesson Form
                                    print("Add Lesson tapped")
                                })
                                QuickActionButton(title: "Add Student", icon: "person.badge.plus.fill", color: .accentGreen, action: {
                                    // TODO: Open Add Student Modal/Form
                                    print("Add Student tapped")
                                })
                                QuickActionButton(title: "Record Payment", icon: "creditcard.fill", color: .purple, action: {
                                    // TODO: Navigate to Add Payment Form
                                    print("Record Payment tapped")
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
            .navigationBarHidden(true) // Use custom header
            .task {
                await fetchData()
            }
            .refreshable {
                await fetchData()
            }
        }
    }
    
    func fetchData() async {
        guard let instructorID = authManager.user?.id else { 
            isLoading = false
            return 
        }
        isLoading = true
        do {
            let data = try await dataService.fetchInstructorDashboardData(for: instructorID)
            self.nextLesson = data.nextLesson
            self.weeklyEarnings = data.earnings
            self.avgStudentProgress = data.avgProgress
        } catch {
            print("Failed to fetch instructor data: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Sub-Views for Instructor Dashboard

struct NextLessonContent: View {
    let lesson: Lesson?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let lesson = lesson {
                Text(lesson.topic)
                    .font(.subheadline).bold()
                    .lineLimit(1)
                
                HStack {
                    Image(systemName: "clock")
                    Text("\(lesson.startTime, style: .time)")
                }
                .font(.callout)
                .foregroundColor(.textLight)

                HStack {
                    Image(systemName: "map.pin.circle.fill")
                    Text("Pickup: \(lesson.pickupLocation)")
                        .lineLimit(1)
                }
                .font(.callout)
                .foregroundColor(.textLight)
            } else {
                Text("No Upcoming Lessons")
                    .font(.subheadline).bold()
                    .foregroundColor(.textLight)
            }
        }
    }
}

struct EarningsSummaryContent: View {
    let earnings: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("£\(earnings, specifier: "%.2f")")
                .font(.title2).bold()
                .foregroundColor(.accentGreen)
            
            Text("This Week")
                .font(.subheadline)
                .foregroundColor(.textLight)
            
            // Placeholder for Chart (can be a simple bar)
            Rectangle()
                .fill(Color.accentGreen.opacity(0.3))
                .frame(height: 10)
                .cornerRadius(5)
        }
    }
}

struct StudentsOverviewContent: View {
    let progress: Double
    var body: some View {
        HStack {
            CircularProgressView(progress: progress, color: .orange, size: 60)
                .padding(.trailing, 10)
            
            VStack(alignment: .leading) {
                Text("Average Student Progress")
                    .font(.subheadline)
                    .foregroundColor(.textLight)
                Text("\(Int(progress * 100))% Mastery")
                    .font(.headline)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.textLight)
        }
    }
}

// MARK: - Generic Card & Button Structures (Moved from previous steps into DashboardView)

struct DashboardCard<Content: View>: View {
    let title: String
    let systemIcon: String
    var accentColor: Color = .primaryBlue
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: systemIcon)
                    .font(.subheadline).bold()
                    .foregroundColor(accentColor)
                Spacer()
            }
            
            Divider().opacity(0.5)
            
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(15)
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.textDark.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption).bold()
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(12)
        }
    }
}