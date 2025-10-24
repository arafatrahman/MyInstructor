import SwiftUI

// Flow Item 8: Lesson Details View
struct LessonDetailsView: View {
    @EnvironmentObject var lessonManager: LessonManager
    // Assuming DataService is available for student name lookup
    @EnvironmentObject var dataService: DataService
    
    @State var lesson: Lesson
    @State private var isStartingSession = false
    @State private var isShowingEditSheet = false
    @State private var isShowingCancelAlert = false
    
    private var studentName: String {
        // Use DataService to look up the student name from the ID
        dataService.getStudentName(for: lesson.studentID)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                
                // MARK: - Header & Status
                VStack(alignment: .leading, spacing: 5) {
                    Text(lesson.topic)
                        .font(.largeTitle).bold()
                        .foregroundColor(.primaryBlue)
                    
                    HStack {
                        Image(systemName: "person.circle.fill")
                        Text(studentName)
                    }
                    .font(.title3)
                    .foregroundColor(.textDark)
                    
                    LessonStatusBadge(status: lesson.status)
                }
                .padding(.horizontal, 20)
                
                // MARK: - Key Details Card
                VStack(alignment: .leading, spacing: 15) {
                    DetailRow(icon: "calendar", title: "Date", dateValue: lesson.startTime, dateStyle: .date)
                    DetailRow(icon: "clock", title: "Time", dateValue: lesson.startTime, dateStyle: .time)
                    DetailRow(icon: "hourglass", title: "Duration", stringValue: lesson.duration?.formattedDuration() ?? "1 Hour")
                    DetailRow(icon: "mappin.and.ellipse", title: "Location", stringValue: lesson.pickupLocation)
                    
                    // FIX: Changed to use the currency initializer to avoid string interpolation error
                    DetailRow(icon: "creditcard", title: "Fee", currencyValue: lesson.fee, currencyCode: "GBP")
                }
                .padding()
                .background(Color.secondaryGray)
                .cornerRadius(15)
                .padding(.horizontal, 20)
                
                // MARK: - Actions
                VStack(spacing: 15) {
                    // Start Session Button (Main Action) - Leads to Flow 10
                    NavigationLink(destination: DrivingSessionView(lesson: lesson)) {
                        Text("Start Driving Session")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primaryDrivingApp)
                    .disabled(lesson.status != .scheduled)
                    
                    // Secondary Actions
                    HStack {
                        Button("Cancel Lesson", role: .destructive) {
                            isShowingCancelAlert = true
                        }
                        .buttonStyle(.secondaryDrivingApp)
                        .frame(maxWidth: .infinity)
                        .disabled(lesson.status != .scheduled)

                        Button("Edit Details") {
                            isShowingEditSheet = true
                        }
                        .buttonStyle(.secondaryDrivingApp)
                        .frame(maxWidth: .infinity)
                        .disabled(lesson.status != .scheduled)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.top)
        }
        .navigationTitle("Lesson Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Cancel Lesson?", isPresented: $isShowingCancelAlert) {
            Button("Yes, Cancel", role: .destructive) {
                Task {
                    try? await lessonManager.updateLessonStatus(lessonID: lesson.id ?? "", status: .cancelled)
                    // Note: Update @State lesson.status here if needed, but managing state across views can be complex.
                }
            }
        } message: {
            Text("Are you sure you want to cancel the lesson with \(studentName)? This action cannot be undone.")
        }
        // Placeholders for sheet navigation would be here
    }
}

// MARK: - SUPPORTING STRUCTS (Defined previously, assumed available)

struct LessonStatusBadge: View {
    let status: LessonStatus
    
    var color: Color {
        switch status {
        case .scheduled: return .primaryBlue
        case .completed: return .accentGreen
        case .cancelled: return .warningRed
        }
    }
    
    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption).bold()
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(5)
    }
}

// Helper: Custom Detail Row (Unified to handle String, Date, or Currency)
struct DetailRow: View {
    let icon: String
    let title: String
    
    // Optional values for different types
    let stringValue: String?
    let dateValue: Date?
    let dateStyle: DateStyle?
    let currencyValue: Double?
    let currencyCode: String?
    
    enum DateStyle {
        case date, time
    }
    
    // Initializer for String values (e.g., Duration, Location)
    init(icon: String, title: String, stringValue: String) {
        self.icon = icon
        self.title = title
        self.stringValue = stringValue
        self.dateValue = nil
        self.dateStyle = nil
        self.currencyValue = nil
        self.currencyCode = nil
    }
    
    // Initializer for Date values
    init(icon: String, title: String, dateValue: Date, dateStyle: DateStyle) {
        self.icon = icon
        self.title = title
        self.dateValue = dateValue
        self.dateStyle = dateStyle
        self.stringValue = nil
        self.currencyValue = nil
        self.currencyCode = nil
    }
    
    // Initializer for Currency values
    init(icon: String, title: String, currencyValue: Double, currencyCode: String) {
        self.icon = icon
        self.title = title
        self.currencyValue = currencyValue
        self.currencyCode = currencyCode
        self.stringValue = nil
        self.dateValue = nil
        self.dateStyle = nil
    }
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .foregroundColor(.primaryBlue)
                .font(.body)
                .frame(width: 25)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption).foregroundColor(.textLight)
                
                Group {
                    if let date = dateValue, let style = dateStyle {
                        // Display date or time
                        Text(date, style: style == .date ? .date : .time)
                    } else if let value = stringValue {
                        // Display generic string value
                        Text(value)
                    } else if let currency = currencyValue, let code = currencyCode {
                        // Display currency using the official format initializer
                        Text(currency, format: .currency(code: code))
                    }
                }
                .font(.headline)
            }
        }
    }
}
