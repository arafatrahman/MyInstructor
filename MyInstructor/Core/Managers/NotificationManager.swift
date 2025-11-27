// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/NotificationManager.swift
// --- UPDATED: Added Delegate handling to open lesson on tap ---

import Foundation
import UserNotifications
import Combine

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()
    
    // Published property to trigger navigation in RootView
    @Published var selectedLessonID: String? = nil

    override init() {
        super.init()
        center.delegate = self // Set delegate to handle taps
        requestAuthorization()
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            } else if granted {
                print("Notification permission granted.")
            }
        }
    }

    /// Schedules two notifications: One at the exact start time, and one 1 hour before.
    func scheduleLessonReminders(lesson: Lesson) {
        guard let lessonID = lesson.id else { return }
        
        // 1. Cancel any existing reminders for this lesson (to avoid duplicates on update)
        cancelReminders(for: lessonID)
        
        // Prepare User Info for Deep Linking
        let userInfo: [AnyHashable: Any] = ["lessonID": lessonID]
        
        // 2. Schedule "1 Hour Before" Reminder
        let date1HrBefore = lesson.startTime.addingTimeInterval(-3600) // -1 hour
        if date1HrBefore > Date() {
            let content = UNMutableNotificationContent()
            content.title = "Upcoming Lesson"
            content.body = "You have a lesson '\(lesson.topic)' starting in 1 hour."
            content.sound = .default
            content.userInfo = userInfo // Attach ID
            
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date1HrBefore)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: "lesson_1hr_\(lessonID)", content: content, trigger: trigger)
            
            center.add(request) { error in
                if let error = error { print("Error scheduling 1hr notification: \(error)") }
            }
        }
        
        // 3. Schedule "Exact Time" Notification
        if lesson.startTime > Date() {
            let content = UNMutableNotificationContent()
            content.title = "Lesson Starting Now"
            content.body = "Your lesson '\(lesson.topic)' is starting now."
            content.sound = .default
            content.userInfo = userInfo // Attach ID
            
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: lesson.startTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: "lesson_exact_\(lessonID)", content: content, trigger: trigger)
            
            center.add(request) { error in
                if let error = error { print("Error scheduling exact notification: \(error)") }
            }
        }
    }
    
    /// Cancels all notifications associated with a specific lesson ID.
    func cancelReminders(for lessonID: String) {
        let identifiers = ["lesson_1hr_\(lessonID)", "lesson_exact_\(lessonID)"]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        print("Cancelled notifications for lesson \(lessonID)")
    }
    
    // MARK: - UNUserNotificationCenterDelegate Methods
    
    // Handle notification tap (Background/Closed -> App Open)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        if let lessonID = userInfo["lessonID"] as? String {
            print("Notification tapped for lesson ID: \(lessonID)")
            // Update on Main Thread
            DispatchQueue.main.async {
                self.selectedLessonID = lessonID
            }
        }
        
        completionHandler()
    }
    
    // Handle notification while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show banner and sound even if app is open
        completionHandler([.banner, .sound])
    }
}
