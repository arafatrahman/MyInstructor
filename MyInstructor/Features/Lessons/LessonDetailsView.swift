// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Lessons/LessonDetailsView.swift
// --- UPDATED: Fixed Combine import and non-optional binding error ---

import SwiftUI
import Combine // Added to support ObservableObject and @Published

// MARK: - View Model
@MainActor
class LessonDetailsViewModel: ObservableObject {
    @Published var student: Student?
    
    func loadStudent(id: String, dataService: DataService) async {
        // If we already have the correct student loaded, we don't need to set it to nil
        // or re-fetch immediately unless necessary. This stability prevents UI glitches.
        if let current = student, current.id == id {
            return
        }
        
        let fetchedStudent = await dataService.fetchStudent(withID: id)
        // Only update if we got a valid result
        if let validStudent = fetchedStudent {
            self.student = validStudent
        }
    }
}

// Flow Item 8: Lesson Details View
struct LessonDetailsView: View {
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var dataService: DataService
    @EnvironmentObject var paymentManager: PaymentManager
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State var lesson: Lesson
    
    // CHANGED: Use StateObject instead of @State to persist student data across parent updates
    @StateObject private var viewModel = LessonDetailsViewModel()
    
    // Changed to Student model to support both Online and Offline students
    // We use a computed property to maintain compatibility with existing code
    private var student: Student? { viewModel.student }
    
    @State private var isShowingEditSheet = false
    @State private var isShowingCancelAlert = false
    @State private var isShowingFinishSheet = false
    
    // --- Computed Properties ---
    private var studentName: String {
        student?.name ?? "Loading..."
    }
    
    private var studentInitials: String {
        guard let student = student else { return "S" }
        let components = student.name.split(separator: " ").map { String($0) }
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
    
    private var totalCalculatedFee: Double {
        let hourlyRate = lesson.fee
        let durationSeconds = lesson.duration ?? 3600
        let durationHours = durationSeconds / 3600
        return hourlyRate * durationHours
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // --- Header Section (Now Clickable) ---
                HStack(spacing: 12) {
                    if let student = student {
                        NavigationLink(destination: StudentProfileView(student: student)) {
                            HStack(spacing: 12) {
                                AsyncImage(url: studentPhotoURL) { phase in
                                    switch phase {
                                    case .success(let image): image.resizable().scaledToFill()
                                    case .failure, .empty:
                                        Text(studentInitials.uppercased()).font(.title3).bold().foregroundColor(.textDark)
                                    @unknown default: ProgressView()
                                    }
                                }
                                .frame(width: 50, height: 50)
                                .background(Color.secondaryGray)
                                .clipShape(Circle())
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(studentName).font(.title2).bold().foregroundColor(.textDark)
                                    LessonStatusBadge(status: lesson.status)
                                }
                            }
                        }
                        .buttonStyle(.plain) // Keeps standard text colors inside link
                    } else {
                        // Loading State
                        HStack(spacing: 12) {
                            Circle().fill(Color.secondaryGray).frame(width: 50, height: 50)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Loading...").font(.title2).bold().foregroundColor(.textDark)
                                LessonStatusBadge(status: lesson.status)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: callStudent) {
                        Image(systemName: "phone.fill").font(.title2).foregroundColor(.primaryBlue)
                            .padding(10).background(Color.primaryBlue.opacity(0.1)).clipShape(Circle())
                    }
                    .disabled(student?.phone == nil)
                }
                .padding(.horizontal, 20).padding(.top, 10)

                // MARK: - Key Details Card
                VStack(alignment: .leading, spacing: 15) {
                    DetailRow(icon: "calendar", title: "Date", dateValue: lesson.startTime, dateStyle: .date)
                    DetailRow(icon: "clock", title: "Time", dateValue: lesson.startTime, dateStyle: .time)
                    DetailRow(icon: "hourglass", title: "Duration", stringValue: lesson.duration?.formattedDuration() ?? "N/A")
                    DetailRow(icon: "mappin.and.ellipse", title: "Location", stringValue: lesson.pickupLocation)
                    
                    HStack(alignment: .top) {
                        Image(systemName: "creditcard").foregroundColor(.primaryBlue).font(.body).frame(width: 25)
                        VStack(alignment: .leading) {
                            Text("Total Fee").font(.caption).foregroundColor(.textLight)
                            Text(totalCalculatedFee, format: .currency(code: "GBP")).font(.headline).bold().foregroundColor(.primaryBlue)
                            Text("(Rate: £\(lesson.fee, specifier: "%.2f")/hr)").font(.caption2).foregroundColor(.textLight)
                        }
                        Spacer()
                    }
                }
                .padding().background(Color.secondaryGray).cornerRadius(15).padding(.horizontal, 20)
                
                // MARK: - Actions
                VStack(spacing: 15) {
                    if lesson.status == .scheduled && authManager.role == .instructor {
                        Button { isShowingFinishSheet = true } label: {
                            HStack { Image(systemName: "checkmark.circle.fill"); Text("Finish Lesson") }.frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.primaryDrivingApp).tint(.accentGreen)
                    }
                    
                    // Cancel Button (Available to both)
                    if lesson.status == .scheduled {
                        Button("Cancel Lesson") { isShowingCancelAlert = true }
                            .frame(maxWidth: .infinity).buttonStyle(RedBorderedButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                
                if !topics.isEmpty {
                    FlowLayout(alignment: .leading, spacing: 8) {
                        ForEach(topics, id: \.self) { topic in
                            Text(topic).font(.subheadline).bold().padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color.primaryBlue.opacity(0.1)).foregroundColor(.primaryBlue).cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 10)
                }
            }
            .padding(.top).padding(.bottom, 40)
        }
        .background(Color.white)
        .navigationTitle("Lesson Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if authManager.role == .instructor {
                    Button("Edit Lesson") { isShowingEditSheet = true }.disabled(lesson.status != .scheduled)
                }
            }
        }
        .alert("Cancel Lesson?", isPresented: $isShowingCancelAlert) {
            Button("No", role: .cancel) { }
            Button("Yes, Cancel", role: .destructive) { Task { await cancelLesson() } }
        } message: {
            Text("Are you sure you want to cancel the lesson with \(studentName)? This action cannot be undone.")
        }
        .sheet(isPresented: $isShowingEditSheet) {
            AddLessonFormView(lessonToEdit: lesson, onLessonAdded: { updatedLesson in self.lesson = updatedLesson; isShowingEditSheet = false })
        }
        .sheet(isPresented: $isShowingFinishSheet) {
            FinishLessonSheet(lesson: lesson, onComplete: { self.lesson.status = .completed; isShowingFinishSheet = false; dismiss() })
        }
        // CHANGED: Removed 'if let' because studentID is already a String (not Optional)
        .task(id: lesson.studentID) {
            await viewModel.loadStudent(id: lesson.studentID, dataService: dataService)
        }
    }
    
    private func callStudent() {
        guard let phone = student?.phone, let url = URL(string: "tel:\(phone.filter("0123456789+".contains))") else { return }
        UIApplication.shared.open(url)
    }
    
    private func cancelLesson() async {
        guard let lessonID = lesson.id, let currentUserID = authManager.user?.id else { return }
        do {
            try await lessonManager.updateLessonStatus(lessonID: lessonID, status: .cancelled, initiatorID: currentUserID)
            self.lesson.status = .cancelled
        } catch {
            print("Failed to cancel: \(error)")
        }
    }
}

// MARK: - Finish Lesson Sheet
struct FinishLessonSheet: View {
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var paymentManager: PaymentManager
    
    let lesson: Lesson
    var onComplete: () -> Void
    
    @State private var isPaymentReceived = true
    @State private var paymentMethod: PaymentMethod = .cash
    @State private var note: String = "" // Lesson feedback note
    @State private var isLoading = false
    @State private var amountString: String = ""
    
    enum PaymentMethod: String, CaseIterable, Identifiable {
        case cash = "Cash", card = "Card", bank = "Bank Transfer"
        var id: String { self.rawValue }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Completion Status") {
                    Text("Mark lesson as Completed").font(.headline)
                }
                
                Section("Payment Details") {
                    Toggle("Payment Received", isOn: $isPaymentReceived)
                        .tint(.accentGreen)
                    
                    if isPaymentReceived {
                        Picker("Payment Method", selection: $paymentMethod) {
                            ForEach(PaymentMethod.allCases) { method in
                                Text(method.rawValue).tag(method)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        HStack {
                            Text("Amount (£)")
                            Spacer()
                            TextField("Amount", text: $amountString)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(.accentGreen)
                                .font(.headline)
                        }
                    } else {
                        HStack {
                            Text("Amount Due (£)")
                            Spacer()
                            TextField("Amount", text: $amountString)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(.warningRed)
                        }
                    }
                }
                
                Section("Lesson Notes (Feedback)") {
                    TextField("How did the lesson go?", text: $note)
                }
                
                Section {
                    Button {
                        finalizeLesson()
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Confirm & Finish")
                                .bold()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.primaryDrivingApp)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Finish Lesson")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                let hourlyRate = lesson.fee
                let durationHours = (lesson.duration ?? 3600) / 3600
                amountString = String(format: "%.2f", hourlyRate * durationHours)
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func finalizeLesson() {
        isLoading = true
        Task {
            do {
                guard let lessonID = lesson.id else { return }
                let finalAmount = Double(amountString) ?? 0.0
                
                // 1. Mark Lesson Completed
                try await lessonManager.updateLessonStatus(lessonID: lessonID, status: .completed)
                
                // 2. Create Payment Record (Visible to Student)
                // We add the lesson topic to the note so the student sees "Lesson: Parking" instead of just "Payment"
                let paymentRecord = Payment(
                    instructorID: lesson.instructorID,
                    studentID: lesson.studentID,
                    amount: finalAmount,
                    date: Date(),
                    isPaid: isPaymentReceived,
                    paymentMethod: isPaymentReceived ? convertMethod(paymentMethod) : nil,
                    note: "Lesson: \(lesson.topic)"
                )
                
                try await paymentManager.recordPayment(newPayment: paymentRecord)
                
                isLoading = false
                onComplete()
            } catch {
                print("Error: \(error)")
                isLoading = false
            }
        }
    }
    
    // Helper to convert local enum to model enum
    func convertMethod(_ local: PaymentMethod) -> MyInstructor.PaymentMethod {
        switch local {
        case .cash: return .cash
        case .card: return .card
        case .bank: return .bankTransfer
        }
    }
}

// MARK: - Shared Components

struct RedBorderedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.warningRed, lineWidth: 2))
            .foregroundColor(.warningRed)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

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
    let dateStyle: Text.DateStyle?
    let currencyValue: Double?
    let currencyCode: String?
    
    init(icon: String, title: String, stringValue: String) {
        self.icon = icon; self.title = title; self.stringValue = stringValue
        self.dateValue = nil; self.dateStyle = nil; self.currencyValue = nil; self.currencyCode = nil
    }
    init(icon: String, title: String, dateValue: Date, dateStyle: Text.DateStyle) {
        self.icon = icon; self.title = title; self.dateValue = dateValue; self.dateStyle = dateStyle
        self.stringValue = nil; self.currencyValue = nil; self.currencyCode = nil
    }
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: icon).foregroundColor(.primaryBlue).font(.body).frame(width: 25)
            VStack(alignment: .leading) {
                Text(title).font(.caption).foregroundColor(.textLight)
                if let date = dateValue, let style = dateStyle {
                    Text(date, style: style).font(.headline).foregroundColor(.textDark)
                } else if let val = stringValue {
                    Text(val).font(.headline).foregroundColor(.textDark)
                }
            }
        }
    }
}
