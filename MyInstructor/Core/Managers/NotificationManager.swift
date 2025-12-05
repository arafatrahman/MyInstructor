// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/NotificationManager.swift
// --- UPDATED: Added logic to mark notifications read by relatedID ---

import Foundation
import UserNotifications
import Combine
import FirebaseFirestore

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()
    private let db = Firestore.firestore()
    
    @Published var selectedLessonID: String? = nil
    @Published var notifications: [AppNotification] = []
    
    private var listenerRegistration: ListenerRegistration?

    override init() {
        super.init()
        center.delegate = self
        requestAuthorization()
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: - Firestore: Send & Listen
    
    // --- UPDATED: Now accepts optional relatedID ---
    func sendNotification(to userID: String, title: String, message: String, type: String, relatedID: String? = nil) {
        let newNotification = AppNotification(
            recipientID: userID,
            title: title,
            message: message,
            type: type,
            timestamp: Date(),
            isRead: false,
            relatedID: relatedID
        )
        try? db.collection("users").document(userID).collection("notifications").addDocument(from: newNotification)
    }
    
    // --- NEW: Mark specific notifications as read based on related ID ---
    func markNotificationsAsRead(relatedID: String, userID: String) {
        let ref = db.collection("users").document(userID).collection("notifications")
        
        // Find all unread notifications with this related ID (e.g., specific conversation)
        ref.whereField("relatedID", isEqualTo: relatedID)
           .whereField("isRead", isEqualTo: false)
           .getDocuments { [weak self] snapshot, error in
               guard let self = self, let documents = snapshot?.documents, !documents.isEmpty else { return }
               
               let batch = self.db.batch()
               for doc in documents {
                   batch.updateData(["isRead": true], forDocument: doc.reference)
               }
               batch.commit()
           }
    }
    
    func listenForNotifications(for userID: String) {
        listenerRegistration?.remove()
        
        let query = db.collection("users")
            .document(userID)
            .collection("notifications")
            .order(by: "timestamp", descending: true)
            .limit(to: 20)
            
        listenerRegistration = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let documents = snapshot?.documents else { return }
            
            // Check for new items to trigger banner
            snapshot?.documentChanges.forEach { change in
                if change.type == .added {
                    if let notif = try? change.document.data(as: AppNotification.self), !notif.isRead {
                        self.triggerLocalBanner(title: notif.title, body: notif.message)
                    }
                }
            }
            
            // Update UI on Main Thread
            DispatchQueue.main.async {
                self.notifications = documents.compactMap { try? $0.data(as: AppNotification.self) }
            }
        }
    }
    
    private func triggerLocalBanner(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
    }
    
    func markAllAsRead(userID: String) {
        let batch = db.batch()
        for notif in notifications where !notif.isRead {
            if let id = notif.id {
                let ref = db.collection("users").document(userID).collection("notifications").document(id)
                batch.updateData(["isRead": true], forDocument: ref)
            }
        }
        batch.commit()
    }

    // MARK: - Lesson Reminders
    
    func scheduleLessonReminders(lesson: Lesson) {
        guard let lessonID = lesson.id else { return }
        cancelReminders(for: lessonID)
        
        let userInfo: [AnyHashable: Any] = ["lessonID": lessonID]
        
        // 1 Hr Before
        let date1HrBefore = lesson.startTime.addingTimeInterval(-3600)
        if date1HrBefore > Date() {
            let content = UNMutableNotificationContent()
            content.title = "Upcoming Lesson"
            content.body = "Lesson '\(lesson.topic)' starts in 1 hour."
            content.sound = .default
            content.userInfo = userInfo
            let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date1HrBefore), repeats: false)
            center.add(UNNotificationRequest(identifier: "lesson_1hr_\(lessonID)", content: content, trigger: trigger))
        }
        
        // Exact Time
        if lesson.startTime > Date() {
            let content = UNMutableNotificationContent()
            content.title = "Lesson Starting Now"
            content.body = "Lesson '\(lesson.topic)' is starting."
            content.sound = .default
            content.userInfo = userInfo
            let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: lesson.startTime), repeats: false)
            center.add(UNNotificationRequest(identifier: "lesson_exact_\(lessonID)", content: content, trigger: trigger))
        }
    }
    
    func cancelReminders(for lessonID: String) {
        center.removePendingNotificationRequests(withIdentifiers: ["lesson_1hr_\(lessonID)", "lesson_exact_\(lessonID)"])
    }
    
    // Delegate Methods
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if let lessonID = response.notification.request.content.userInfo["lessonID"] as? String {
            DispatchQueue.main.async { self.selectedLessonID = lessonID }
        }
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
