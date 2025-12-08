// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/LocationManager.swift
// --- UPDATED: Ensures consistent writes with debug logs ---

import Foundation
import CoreLocation
import Combine
import FirebaseFirestore

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let db = Firestore.firestore()
    
    @Published var location: CLLocation? = nil
    @Published var authorizationStatus: CLAuthorizationStatus
    
    @Published var isSharing: Bool = false
    private var activeLessonID: String?
    private var activeUserRole: UserRole?

    override init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone
        
        // Ensure this is enabled if Background Modes is on in Xcode
        // locationManager.allowsBackgroundLocationUpdates = true
    }

    func requestLocation() async {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        locationManager.startUpdatingLocation()
    }
    
    func startSharing(lessonID: String, role: UserRole) {
        print("LocationManager: START sharing. ID: \(lessonID) Role: \(role.rawValue)")
        self.activeLessonID = lessonID
        self.activeUserRole = role
        
        DispatchQueue.main.async { self.isSharing = true }
        
        locationManager.startUpdatingLocation()
        
        // Immediate status update
        db.collection("lessons").document(lessonID).setData(["isLocationActive": true], merge: true)
        
        // Force immediate update if location exists
        if let loc = locationManager.location {
            locationManager(locationManager, didUpdateLocations: [loc])
        }
    }
    
    func stopSharing() {
        print("LocationManager: STOP sharing.")
        DispatchQueue.main.async { self.isSharing = false }
        locationManager.stopUpdatingLocation()
        
        if let lessonID = activeLessonID {
            db.collection("lessons").document(lessonID).setData(["isLocationActive": false], merge: true)
        }
        activeLessonID = nil
        activeUserRole = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async { self.location = location }
        
        if isSharing, let lessonID = activeLessonID, let role = activeUserRole {
            let lat = location.coordinate.latitude
            let lng = location.coordinate.longitude
            
            var data: [String: Any] = [:]
            if role == .instructor {
                data = ["instructorLat": lat, "instructorLng": lng]
            } else if role == .student {
                data = ["studentLat": lat, "studentLng": lng]
            }
            
            // WRITE
            db.collection("lessons").document(lessonID).setData(data, merge: true) { error in
                if let error = error {
                    print("LocationManager Write ERROR: \(error.localizedDescription)")
                } else {
                    // Success log (optional)
                    // print("LocationManager: Wrote \(role) loc: \(lat), \(lng)")
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager Error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { self.authorizationStatus = manager.authorizationStatus }
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}
