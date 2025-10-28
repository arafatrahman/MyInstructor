import SwiftUI
import MapKit
import Combine

// Flow Item 10: Driving Session (Active Lesson)
struct DrivingSessionView: View {
    @State var lesson: Lesson
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var lessonManager: LessonManager
    
    @State private var isActive: Bool = true
    @State private var timeElapsed: TimeInterval = 0
    @State private var isShowingSummary = false
    @State private var quickNote: String = ""
    
    // Mock Map setup
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.515, longitude: -0.125),
        span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
    ))

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .top) {
            // Using the modern Map initializer
            Map(position: $position) {
                // Map content goes here
            }
            .ignoresSafeArea()
            
            // Top Bar: Lesson topic | Timer | End Lesson
            VStack(spacing: 0) {
                HStack {
                    Text(lesson.topic)
                        .font(.title3).bold()
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Timer
                    Text(timeString(from: timeElapsed))
                        .font(.title2).bold()
                        .foregroundColor(.white)
                }
                .padding(.horizontal)
                .padding(.top, 50)
                
                // End Lesson Button
                Button {
                    isActive = false // Pause timer
                    isShowingSummary = true // Show summary popup
                } label: {
                    Text("End Lesson")
                        .font(.headline).bold()
                        .padding(.vertical, 8)
                        .padding(.horizontal, 15)
                        .background(Color.warningRed)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            .background(Color.textDark.opacity(0.85))
            
            // Notes Input at the Bottom
            VStack {
                Spacer()
                NoteInputView(quickNote: $quickNote)
                    .padding(.bottom, 20)
            }
        }
        .onReceive(timer) { _ in
            if isActive {
                timeElapsed += 1
            }
        }
        .fullScreenCover(isPresented: $isShowingSummary) {
            LessonSummaryView(lesson: lesson, duration: timeElapsed) {
                dismiss()
            }
        }
    }
    
    // MARK: - Helper Functions
    
    func timeString(from totalSeconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: totalSeconds) ?? "00:00"
    }
}

// MARK: - SUPPORTING STRUCTS

// Quick Add Notes Input
struct NoteInputView: View {
    @Binding var quickNote: String
    
    var body: some View {
        HStack(spacing: 15) {
            TextField("Voice/text quick add notes...", text: $quickNote)
                .padding(10)
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(radius: 2)
            
            Button {
                print("Voice note activated")
            } label: {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 35))
                    .foregroundColor(.primaryBlue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.systemBackground).opacity(0.95))
    }
}

// Lesson Summary Popup
struct LessonSummaryView: View {
    @EnvironmentObject var lessonManager: LessonManager
    let lesson: Lesson
    let duration: TimeInterval
    let onComplete: () -> Void
    
    @State private var paymentStatus: PaymentStatus = .pending
    @State private var distanceTraveled: Double = 0.0 // Default to 0
    @State private var selectedSkills: Set<String> = [] // Default to empty
    
    // TODO: This skill list should come from a central manager
    let allSkills = ["Junctions", "Clutch Control", "Speed Control", "Parking", "Roundabouts"]
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Lesson Overview
                Section("Lesson Overview") {
                    // Duration is handled by the String initializer
                    SummaryRow(title: "Duration", duration: duration)
                    
                    // Distance uses FloatingPointFormatStyle<Double>.number
                    SummaryRow(title: "Distance Traveled", number: distanceTraveled, format: .number.precision(.fractionLength(1)))
                    
                    // Fee uses .currency
                    SummaryRow(title: "Fee", currency: lesson.fee)
                }
                
                // MARK: - Progress Update Checklist
                Section("Skills Covered & Improved") {
                    ForEach(allSkills, id: \.self) { skill in
                        HStack {
                            Text(skill)
                            Spacer()
                            Image(systemName: selectedSkills.contains(skill) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedSkills.contains(skill) ? .accentGreen : .textLight)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedSkills.contains(skill) {
                                selectedSkills.remove(skill)
                            } else {
                                selectedSkills.insert(skill)
                            }
                        }
                    }
                    Text("Select skills that showed significant progress.")
                        .font(.caption)
                        .foregroundColor(.textLight)
                }
                
                // MARK: - Payment Status
                Section("Payment & Finalization") {
                    Picker("Payment Status", selection: $paymentStatus) {
                        Text("Payment Pending").tag(PaymentStatus.pending)
                        Text("Mark Paid").tag(PaymentStatus.paid)
                    }
                    .pickerStyle(.segmented)
                }
                
                // MARK: - Finalize Button
                Button("Finalize & Complete Lesson") {
                    Task {
                        // 1. Update Lesson Status
                        guard let lessonID = lesson.id else {
                            print("Error: Lesson ID is nil, cannot complete lesson.")
                            return
                        }
                        try? await lessonManager.updateLessonStatus(lessonID: lessonID, status: .completed)
                        
                        // 2. Save progress/notes/payment status (TODO)
                        
                        // 3. Call completion handler
                        onComplete()
                    }
                }
                .buttonStyle(.primaryDrivingApp)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Lesson Summary")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

enum PaymentStatus {
    case paid, pending
}

// Universal Summary Row (Corrected with separate handling for currency)
struct SummaryRow: View {
    let title: String
    let duration: TimeInterval?
    let number: Double?
    let format: FloatingPointFormatStyle<Double>?
    let currencyValue: Double?
    let currencyCode: String?
    
    // Initializer 1: For Duration (TimeInterval)
    init(title: String, duration: TimeInterval) {
        self.title = title
        self.duration = duration
        self.number = nil
        self.format = nil
        self.currencyValue = nil
        self.currencyCode = nil
    }
    
    // Initializer 2: For Double values (Distance) with a specific format
    init(title: String, number: Double, format: FloatingPointFormatStyle<Double>) {
        self.title = title
        self.duration = nil
        self.number = number
        self.format = format
        self.currencyValue = nil
        self.currencyCode = nil
    }
    
    // Initializer 3: For Currency values
    init(title: String, currency: Double, code: String = "GBP") {
        self.title = title
        self.duration = nil
        self.number = nil
        self.format = nil
        self.currencyValue = currency
        self.currencyCode = code
    }
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.textDark)
            Spacer()
            
            Group {
                if let duration = duration {
                    Text(durationFormatted(duration))
                        .font(.headline)
                        .foregroundColor(.primaryBlue)
                } else if let number = number, let format = format {
                    Text(number, format: format)
                        .font(.headline)
                        .foregroundColor(.primaryBlue)
                } else if let currencyValue = currencyValue {
                    Text(currencyValue, format: .currency(code: currencyCode ?? "GBP"))
                        .font(.headline)
                        .foregroundColor(.primaryBlue)
                }
            }
        }
    }
    
    private func durationFormatted(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "N/A"
    }
}
