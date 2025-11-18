// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Lessons/LessonDetailsView.swift
// --- UPDATED: "Edit Lesson" button in toolbar is now plain text (default style) ---

import SwiftUI

// Flow Item 8: Lesson Details View
struct LessonDetailsView: View {
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var dataService: DataService
    @Environment(\.dismiss) var dismiss
    
    @State var lesson: Lesson
    
    @State private var student: AppUser? = nil
    @State private var isShowingEditSheet = false
    @State private var isShowingCancelAlert = false
    
    // --- Computed Properties ---
    private var studentName: String {
        student?.name ?? "Student"
    }
    
    private var studentInitials: String {
        guard let student = student, let name = student.name else { return "S" }
        let components = name.split(separator: " ").map { String($0) }
        if components.count >= 2 {
            return "\(components[0].first ?? " ")\(components[1].first ?? " ")"
        } else if let first = components.first {
            return "\(first.first ?? " ")"
        }
        return "S"
    }
    
    private var studentPhotoURL: URL? {
        guard let urlString = student?.photoURL, !urlString.isEmpty else { return nil }
        return URL(string: urlString)
    }
    
    private var topics: [String] {
        lesson.topic.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // --- Header Section ---
                HStack(spacing: 12) {
                    // Avatar
                    AsyncImage(url: studentPhotoURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure, .empty:
                            Text(studentInitials.uppercased())
                                .font(.title3).bold()
                                .foregroundColor(.textDark)
                        @unknown default:
                            ProgressView()
                        }
                    }
                    .frame(width: 50, height: 50)
                    .background(Color.secondaryGray)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(studentName)
                            .font(.title2).bold()
                            .foregroundColor(.textDark)
                        
                        LessonStatusBadge(status: lesson.status)
                    }
                    
                    Spacer()
                    
                    // Call Button
                    Button(action: callStudent) {
                        Image(systemName: "phone.fill")
                            .font(.title2)
                            .foregroundColor(.primaryBlue)
                            .padding(10)
                            .background(Color.primaryBlue.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .disabled(student?.phone == nil)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                
                // MARK: - Key Details Card
                VStack(alignment: .leading, spacing: 15) {
                    DetailRow(icon: "calendar", title: "Date", dateValue: lesson.startTime, dateStyle: .date)
                    DetailRow(icon: "clock", title: "Time", dateValue: lesson.startTime, dateStyle: .time)
                    DetailRow(icon: "hourglass", title: "Duration", stringValue: lesson.duration?.formattedDuration() ?? "N/A")
                    DetailRow(icon: "mappin.and.ellipse", title: "Location", stringValue: lesson.pickupLocation)
                    
                    HStack(alignment: .top) {
                        Image(systemName: "creditcard")
                            .foregroundColor(.primaryBlue)
                            .font(.body)
                            .frame(width: 25)
                        
                        VStack(alignment: .leading) {
                            Text("Fee")
                                .font(.caption).foregroundColor(.textLight)
                            Text(lesson.fee, format: .currency(code: "GBP"))
                                .font(.headline).bold()
                                .foregroundColor(.primaryBlue)
                        }
                        Spacer()
                    }
                }
                .padding()
                .background(Color.secondaryGray)
                .cornerRadius(15)
                .padding(.horizontal, 20)
                
                
                // MARK: - Actions
                VStack(spacing: 15) {
                    // "Cancel" Button
                    Button("Cancel Lesson") {
                        isShowingCancelAlert = true
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(RedBorderedButtonStyle()) // Red style
                    .disabled(lesson.status != .scheduled)
                }
                .padding(.horizontal, 20)
                
                
                // --- Topics ---
                FlowLayout(alignment: .leading, spacing: 8) {
                    ForEach(topics, id: \.self) { topic in
                        Text(topic)
                            .font(.subheadline).bold()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.primaryBlue.opacity(0.1))
                            .foregroundColor(.primaryBlue)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .padding(.top)
            .padding(.bottom, 40) // Add padding to bottom
        }
        .background(Color.white) // Use plain white
        .navigationTitle("Lesson Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // --- *** THIS IS THE FIX *** ---
                // Removed .buttonStyle, .tint, and .controlSize
                // to use the default toolbar button style (plain text)
                Button("Edit Lesson") {
                    isShowingEditSheet = true
                }
                .disabled(lesson.status != .scheduled)
                // --- *** END OF FIX *** ---
            }
        }
        .alert("Cancel Lesson?", isPresented: $isShowingCancelAlert) {
            Button("No", role: .cancel) { }
            Button("Yes, Cancel", role: .destructive) {
                Task { await cancelLesson() }
            }
        } message: {
            Text("Are you sure you want to cancel the lesson with \(studentName)? This action cannot be undone.")
        }
        .sheet(isPresented: $isShowingEditSheet) {
            AddLessonFormView(
                lessonToEdit: lesson,
                onLessonAdded: { updatedLesson in
                    self.lesson = updatedLesson
                    isShowingEditSheet = false
                }
            )
        }
        .task {
            if self.student == nil {
                do {
                    self.student = try await dataService.fetchUser(withId: lesson.studentID)
                } catch {
                    print("Failed to fetch student for details view: \(error)")
                }
            }
        }
    }
    
    private func callStudent() {
        guard let phone = student?.phone,
              let url = URL(string: "tel:\(phone.filter("0123456789+".contains))") else {
            print("Cannot call student: Phone number not available or invalid.")
            return
        }
        
        print("Attempting to call student at \(url.absoluteString)...")
        UIApplication.shared.open(url)
    }
    
    private func cancelLesson() async {
        guard let lessonID = lesson.id else { return }
        
        do {
            try await lessonManager.updateLessonStatus(lessonID: lessonID, status: .cancelled)
            self.lesson.status = .cancelled
        } catch {
            print("Failed to cancel lesson: \(error.localizedDescription)")
        }
    }
}

// MARK: - New Button Styles

/// A button style with a white background and red border/text.
struct RedBorderedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.white) // Use white background
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.warningRed, lineWidth: 2) // Red border
            )
            .foregroundColor(.warningRed) // Red text
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}


// MARK: - SUPPORTING STRUCTS (Unchanged)

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
            .cornerRadius(10)
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    
    let stringValue: String?
    let dateValue: Date?
    let dateStyle: DateStyle?
    let currencyValue: Double?
    let currencyCode: String?
    
    enum DateStyle {
        case date, time
    }
    
    init(icon: String, title: String, stringValue: String) {
        self.icon = icon
        self.title = title
        self.stringValue = stringValue
        self.dateValue = nil
        self.dateStyle = nil
        self.currencyValue = nil
        self.currencyCode = nil
    }
    
    init(icon: String, title: String, dateValue: Date, dateStyle: DateStyle) {
        self.icon = icon
        self.title = title
        self.dateValue = dateValue
        self.dateStyle = dateStyle
        self.stringValue = nil
        self.currencyValue = nil
        self.currencyCode = nil
    }
    
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
                        Text(date, style: style == .date ? .date : .time)
                    } else if let value = stringValue {
                        Text(value)
                    } else if let currency = currencyValue, let code = currencyCode {
                        Text(currency, format: .currency(code: code))
                    }
                }
                .font(.headline)
                .foregroundColor(.textDark)
            }
        }
    }
}
