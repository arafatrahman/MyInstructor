// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Community/InstructorDirectoryView.swift
import SwiftUI
import Combine
import MapKit
import CoreLocation // <-- 1. ADD IMPORT

// Flow Item 21: Instructor Directory (Student/Public View)
struct InstructorDirectoryView: View {
    @EnvironmentObject var communityManager: CommunityManager
    @StateObject private var locationManager = LocationManager() // <-- 2. ADD LOCATION MANAGER
    
    @State private var allInstructors: [Student] = [] // This is the master list
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var isShowingMapView = false
    
    // --- 3. UPDATED FILTERED LIST LOGIC ---
    var filteredInstructors: [Student] {
        if searchText.isEmpty {
            // If no search, return the master list, which is already sorted by distance
            return allInstructors
        }
        
        let lowercasedSearch = searchText.lowercased()
        return allInstructors.filter { instructor in
            let nameMatch = instructor.name.lowercased().contains(lowercasedSearch)
            let emailMatch = instructor.email.lowercased().contains(lowercasedSearch)
            let phoneMatch = (instructor.phone ?? "").lowercased().contains(lowercasedSearch)
            let schoolMatch = (instructor.drivingSchool ?? "").lowercased().contains(lowercasedSearch)
            
            // Return true if any field matches
            return nameMatch || emailMatch || phoneMatch || schoolMatch
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                // Search + Filter bar
                HStack {
                    // SearchBar is now more powerful
                    SearchBar(text: $searchText, placeholder: "Search by name, email, phone...")
                    
                    // Filters (Placeholder)
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
                    // Map View (Placeholder for Flow Item 21 Map Pins)
                    Map(coordinateRegion: .constant(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 51.5, longitude: -0.1), span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2))))
                        .ignoresSafeArea(edges: .bottom)
                        .overlay(Text("Showing nearby instructors on map").font(.caption).padding().background(.thickMaterial).cornerRadius(10), alignment: .center)
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
            .navigationTitle("Find Instructors")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadData() } // <-- 4. USE NEW LOAD FUNCTION
        }
    }
    
    // --- 5. NEW DATA LOADING AND SORTING FUNCTIONS ---
    
    /// Loads instructors, gets the user's location, and sorts the list by proximity.
    func loadData() async {
        isLoading = true
        
        // 1. Fetch all instructors from Firestore
        do {
            self.allInstructors = try await communityManager.fetchInstructorDirectory(filters: [:])
        } catch {
            print("Failed to fetch directory: \(error)")
            self.allInstructors = []
        }
        
        // 2. Request the user's current location
        await locationManager.requestLocation()
        
        // 3. Once location is available, calculate distances and sort the list
        if let userLocation = locationManager.location {
            self.allInstructors = await calculateAndSortDistances(for: allInstructors, from: userLocation)
        } else {
            // Handle case where location is denied or fails
            // Just show the list as-is (default sort)
            print("Location not available. Showing list without distance sorting.")
        }
        
        isLoading = false
    }
    
    /// Geocodes addresses and sorts the instructor list by distance from the user.
    func calculateAndSortDistances(for instructors: [Student], from userLocation: CLLocation) async -> [Student] {
        let geocoder = CLGeocoder()
        
        var instructorsWithDistance: [(student: Student, distance: Double)] = []
        
        // Use a TaskGroup to geocode all addresses concurrently
        await withTaskGroup(of: (Student, Double)?.self) { group in
            for var instructor in instructors {
                group.addTask {
                    guard let address = instructor.address, !address.isEmpty else { return nil }
                    do {
                        // Geocode the instructor's address string
                        let placemarks = try await geocoder.geocodeAddressString(address)
                        if let instructorLocation = placemarks.first?.location {
                            // Calculate distance from user
                            let distanceInMeters = userLocation.distance(from: instructorLocation)
                            instructor.distance = distanceInMeters // Save the distance
                            return (instructor, distanceInMeters)
                        }
                    } catch {
                        // This can happen if an address is invalid
                        print("Geocoding error for \(address): \(error.localizedDescription)")
                    }
                    return nil // Return nil if geocoding fails
                }
            }
            
            // Collect all the successful results
            for await result in group {
                if let (instructor, distance) = result {
                    instructorsWithDistance.append((instructor, distance))
                }
            }
        }
        
        // Sort the list by distance (shortest first)
        instructorsWithDistance.sort { $0.distance < $1.distance }
        
        // Return just the sorted array of Student objects
        return instructorsWithDistance.map { $0.student }
    }
}

// Instructor Directory Card (Flow Item 21 detail)
struct InstructorDirectoryCard: View {
    let instructor: Student
    
    var body: some View {
        HStack(alignment: .top) {
            AsyncImage(url: URL(string: instructor.photoURL ?? "")) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.fill.viewfinder")
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
