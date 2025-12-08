// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Session/DrivingSessionView.swift
// --- UPDATED: Sends notification to other party when sharing starts ---

import SwiftUI
import MapKit
import Combine

struct DrivingSessionView: View {
    @State var lesson: Lesson
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var authManager: AuthManager
    
    @State private var timeElapsed: TimeInterval = 0
    @State private var isActive: Bool = true
    @State private var quickNote: String = ""
    
    // Timer
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Map State (Follows user)
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        ZStack(alignment: .top) {
            // Live Map
            Map(position: $position) {
                UserAnnotation() // Shows current user's dot
            }
            .mapControls {
                MapUserLocationButton()
            }
            .ignoresSafeArea()
            
            // Top Overlay
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("LIVE LESSON")
                            .font(.caption).bold().foregroundColor(.accentGreen)
                        Text(lesson.topic)
                            .font(.title3).bold().foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    // Timer Display
                    Text(timeString(from: timeElapsed))
                        .font(.title2).monospacedDigit().bold()
                        .foregroundColor(.white)
                }
                .padding(.horizontal)
                .padding(.top, 60)
                .padding(.bottom, 20)
                
                // End Button
                Button {
                    endSession()
                } label: {
                    Text("End Lesson")
                        .font(.headline).bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.warningRed)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(
                LinearGradient(colors: [Color.black.opacity(0.8), Color.clear], startPoint: .top, endPoint: .bottom)
            )
            .ignoresSafeArea()
            
            // Bottom Note Input
            VStack {
                Spacer()
                NoteInputView(quickNote: $quickNote)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            startSharing()
        }
        .onReceive(timer) { _ in
            if isActive { timeElapsed += 1 }
        }
    }
    
    // MARK: - Actions
    
    func startSharing() {
        guard let lessonID = lesson.id, let user = authManager.user else { return }
        let role = user.role
        
        // 1. Start Sharing Location locally
        locationManager.startSharing(lessonID: lessonID, role: role)
        
        // 2. Notify the other party
        // If I am Instructor -> Notify Student. If I am Student -> Notify Instructor.
        let recipientID = (role == .instructor) ? lesson.studentID : lesson.instructorID
        
        if recipientID != user.id {
            NotificationManager.shared.sendNotification(
                to: recipientID,
                title: "Live Tracking Active",
                message: "\(user.name ?? "User") is now sharing their live location.",
                type: "location",
                relatedID: lessonID
            )
        }
    }
    
    func endSession() {
        isActive = false
        // Stop sharing
        locationManager.stopSharing()
        
        // "Nothing else it can do" -> Just dismiss
        dismiss()
    }
    
    func timeString(from totalSeconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: totalSeconds) ?? "00:00"
    }
}

// MARK: - Subviews

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
        .cornerRadius(15)
        .padding(.horizontal)
    }
}
