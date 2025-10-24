import SwiftUI
import Combine
import MapKit

// Flow Item 21: Instructor Directory (Student/Public View)
struct InstructorDirectoryView: View {
    @EnvironmentObject var communityManager: CommunityManager
    
    @State private var instructors: [Student] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var isShowingMapView = false
    
    var filteredInstructors: [Student] {
        instructors.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationView {
            VStack {
                // Search + Filter bar
                HStack {
                    SearchBar(text: $searchText, placeholder: "Search instructors by name")
                    
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
                                // TODO: Navigate to Instructor Public Profile (Flow 22)
                                Text("Instructor Public Profile for \(instructor.name)").navigationTitle(instructor.name)
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
            .task { await fetchInstructors() }
        }
    }
    
    func fetchInstructors() async {
        isLoading = true
        do {
            self.instructors = try await communityManager.fetchInstructorDirectory(filters: [:])
        } catch {
            print("Failed to fetch directory: \(error)")
        }
        isLoading = false
    }
}

// Instructor Directory Card (Flow Item 21 detail)
struct InstructorDirectoryCard: View {
    let instructor: Student
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "person.fill.viewfinder")
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundColor(.primaryBlue)
            
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(instructor.name).font(.headline)
                    Image(systemName: "star.fill").foregroundColor(.yellow)
                    Text("4.8").font(.subheadline) // Stars ⭐
                }
                Text("From £35/hr").font(.subheadline).bold().foregroundColor(.accentGreen)
                Text("Manual, Automatic | Speaks Spanish").font(.caption).foregroundColor(.textLight)
            }
            
            Spacer()
            
            Button("Book Lesson") {
                // TODO: Open booking modal
            }
            .buttonStyle(.borderedProminent)
            .tint(.primaryBlue)
        }
        .padding(10)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.textDark.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
