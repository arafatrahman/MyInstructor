// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Community/InstructorDirectoryView.swift
// --- UPDATED: Removed redundant NavigationView and fixed CLLocationCoordinateD typo ---

import SwiftUI
import Combine
import MapKit
import CoreLocation

// Flow Item 21: Instructor Directory (Student/Public View)
struct InstructorDirectoryView: View {
    @EnvironmentObject var communityManager: CommunityManager
    @EnvironmentObject var locationManager: LocationManager
    
    @State private var allInstructors: [Student] = [] // This is the master list
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var isShowingMapView = false
    
    // Computed property for filtering
    var filteredInstructors: [Student] {
        if searchText.isEmpty {
            // Return the master list, already sorted by distance (if available)
            return allInstructors
        }
        
        let lowercasedSearch = searchText.lowercased()
        return allInstructors.filter { instructor in
            let nameMatch = instructor.name.lowercased().contains(lowercasedSearch)
            let emailMatch = instructor.email.lowercased().contains(lowercasedSearch)
            let phoneMatch = (instructor.phone ?? "").lowercased().contains(lowercasedSearch)
            let schoolMatch = (instructor.drivingSchool ?? "").lowercased().contains(lowercasedSearch)
            
            return nameMatch || emailMatch || phoneMatch || schoolMatch
        }
    }
    
    // Default region for the map (London)
    // --- THIS IS THE FIX for the typo ---
    @State private var mapRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278), // Was CLLocationCoordinateD
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    var body: some View {
        // --- The NavigationView was removed from here to fix the double back button ---
        VStack {
            // Search + Filter bar
            HStack {
                SearchBar(text: $searchText, placeholder: "Search by name, email, phone...")
                
                Button {
                    // TODO: Open advanced filter modal
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title2)
                        .foregroundColor(.primaryBlue)
                }
            }
            .padding(.horizontal)
            
            // Toggle: List ↔ Map
            Picker("View Mode", selection: $isShowingMapView) {
                Text("List").tag(false)
                Text("Map").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 5)
            
            if isLoading {
                ProgressView("Loading Directory...")
                    .padding(.top, 50)
            } else if isShowingMapView {
                // --- UPDATED MAP ANNOTATION ---
                Map(coordinateRegion: $mapRegion, annotationItems: allInstructors.filter { $0.coordinate != nil }) { instructor in
                    MapAnnotation(coordinate: instructor.coordinate!) {
                        NavigationLink(destination: InstructorPublicProfileView(instructorID: instructor.id ?? "")) {
                            VStack(spacing: 4) {
                                // Use AsyncImage to show profile pic, with car icon as fallback
                                AsyncImage(url: URL(string: instructor.photoURL ?? "")) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 35, height: 35) // Pin size
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.primaryBlue, lineWidth: 1.5))
                                    case .failure, .empty:
                                        // Fallback car icon
                                        Image(systemName: "car.circle.fill")
                                            .font(.title)
                                            .foregroundColor(.primaryBlue)
                                            .frame(width: 35, height: 35)
                                    @unknown default:
                                        // Default fallback
                                        Image(systemName: "car.circle.fill")
                                            .font(.title)
                                            .foregroundColor(.primaryBlue)
                                            .frame(width: 35, height: 35)
                                    }
                                }
                                
                                // Show first name
                                Text(instructor.name.split(separator: " ").first.map(String.init) ?? "")
                                    .font(.caption)
                                    .foregroundColor(.textDark)
                                    .lineLimit(1)
                            }
                            .padding(5)
                            .frame(minWidth: 60) // Ensure a minimum width for the tap area
                            .background(Color(.systemBackground).opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(radius: 3)
                        }
                    }
                }
                .ignoresSafeArea(edges: .bottom)
                // --- *** END OF UPDATE *** ---
            } else if filteredInstructors.isEmpty {
                EmptyStateView(icon: "magnifyingglass", message: "No instructors match your search criteria.")
            } else {
                List {
                    ForEach(filteredInstructors) { instructor in
                        NavigationLink {
                            InstructorPublicProfileView(instructorID: instructor.id ?? "")
                        } label: {
                            InstructorDirectoryCard(instructor: instructor)
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Find Instructors") // This title will now appear on the inherited navigation bar
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
        // --- The matching } for the NavigationView was removed from here ---
    }
    
    /// Loads instructors, geocodes them for the map, and *then* sorts by distance if location is available.
    func loadData() async {
        isLoading = true
        
        // 1. Fetch all instructors from Firestore
        var instructors: [Student] = []
        do {
            instructors = try await communityManager.fetchInstructorDirectory(filters: [:])
        } catch {
            print("Failed to fetch directory: \(error)")
        }
        
        // 2. Geocode all instructors to get their coordinates for the map
        // This happens regardless of user location permission
        instructors = await geocodeInstructors(instructors)
        
        // 3. Check for user's location
        if let userLocation = locationManager.location {
            // Location is available! Calculate distances and sort.
            instructors = sortInstructorsByDistance(instructors, from: userLocation)
            // Center the map on the user's location
            withAnimation {
                mapRegion.center = userLocation.coordinate
                mapRegion.span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            }
        } else {
            // Location not available. Center map on the first instructor (if any).
            if let firstCoord = instructors.first(where: { $0.coordinate != nil })?.coordinate {
                withAnimation {
                    mapRegion.center = firstCoord
                }
            }
        }
        
        // 4. Update the main state property to refresh the UI
        self.allInstructors = instructors
        isLoading = false
    }

    /// Takes a list of instructors, finds their coordinates, and returns an updated list.
    func geocodeInstructors(_ instructors: [Student]) async -> [Student] {
        let geocoder = CLGeocoder()
        var geocodedInstructors: [Student] = []

        await withTaskGroup(of: Student.self) { group in
            for var instructor in instructors {
                group.addTask {
                    if let address = instructor.address, !address.isEmpty {
                        do {
                            let placemarks = try await geocoder.geocodeAddressString(address)
                            if let location = placemarks.first?.location {
                                instructor.coordinate = location.coordinate
                            }
                        } catch {
                            // Address is invalid or not found, coordinate remains nil
                        }
                    }
                    return instructor
                }
            }
            
            for await instructor in group {
                geocodedInstructors.append(instructor)
            }
        }
        return geocodedInstructors
    }
    
    /// Calculates distance for each instructor (who has coordinates) and sorts the list.
    func sortInstructorsByDistance(_ instructors: [Student], from userLocation: CLLocation) -> [Student] {
        var sortedInstructors = instructors
        
        // Calculate distance for each
        for i in 0..<sortedInstructors.count {
            if let coord = sortedInstructors[i].coordinate {
                let instructorLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                let distanceInMeters = userLocation.distance(from: instructorLocation)
                sortedInstructors[i].distance = distanceInMeters
            }
        }
        
        // Sort the list by distance (nil distances go to the end)
        sortedInstructors.sort {
            guard let dist1 = $0.distance else { return false } // $0 (lhs) has no distance, move to end
            guard let dist2 = $1.distance else { return true }  // $1 (rhs) has no distance, $0 is closer
            return dist1 < dist2
        }
        
        return sortedInstructors
    }
}

// Instructor Directory Card
struct InstructorDirectoryCard: View {
    let instructor: Student
    
    var body: some View {
        HStack(alignment: .top) {
            AsyncImage(url: URL(string: instructor.photoURL ?? "")) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    // Use a standard person icon for the list view
                    Image(systemName: "person.circle.fill")
                        .resizable().scaledToFit()
                        .foregroundColor(.primaryBlue)
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            .background(Color.secondaryGray)
            .clipShape(Circle())

            
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(instructor.name).font(.headline)
                    Image(systemName: "star.fill").foregroundColor(.yellow)
                    Text("4.8").font(.subheadline) // Stars ⭐
                }
                
                // Show distance if available
                if let distance = instructor.distance {
                    Text(String(format: "%.1f km away", distance / 1000))
                        .font(.subheadline).bold()
                        .foregroundColor(.accentGreen)
                } else {
                    Text(instructor.drivingSchool ?? "Independent")
                        .font(.subheadline).bold()
                        .foregroundColor(.accentGreen)
                }
                
                Text(instructor.address ?? "Location not provided")
                    .font(.caption).foregroundColor(.textLight)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(10)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.textDark.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
