import SwiftUI

struct StudentFeedbackListView: View {
    let studentID: String
    @EnvironmentObject var dataService: DataService
    
    @State private var notes: [StudentNote] = []
    @State private var isLoading = true
    
    var body: some View {
        List {
            if isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                    Text("Loading Feedback...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                
            } else if notes.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "note.text")
                        .font(.system(size: 50))
                        .foregroundColor(.textLight)
                    Text("No feedback notes yet.")
                        .font(.headline)
                        .foregroundColor(.textLight)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 50)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                
            } else {
                ForEach(notes) { note in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(note.content)
                            .font(.body)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text(note.timestamp.formatted(date: .long, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("Feedback History")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchNotes()
        }
        .refreshable {
            await fetchNotes()
        }
    }
    
    private func fetchNotes() async {
        isLoading = true
        do {
            self.notes = try await dataService.fetchAllStudentNotes(for: studentID)
        } catch {
            print("Error fetching notes: \(error)")
        }
        isLoading = false
    }
}
