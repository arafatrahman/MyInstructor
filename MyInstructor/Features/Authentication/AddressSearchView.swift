import SwiftUI
import MapKit
import Combine

// ViewModel to handle address search logic
class AddressSearchViewModel: NSObject, ObservableObject { // <-- 1. Inherit from NSObject
    @Published var searchText: String = ""
    @Published private(set) var searchResults: [MKLocalSearchCompletion] = []
    
    private var searchCompleter = MKLocalSearchCompleter()
    private var cancellable: AnyCancellable?
    
    override init() { // <-- 2. Add override
        super.init() // <-- 3. Call super.init()
        searchCompleter.delegate = self
        
        cancellable = $searchText
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .assign(to: \.queryFragment, on: searchCompleter)
    }
}

extension AddressSearchViewModel: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // Update results on the main thread
        DispatchQueue.main.async {
            self.searchResults = completer.results
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Address completer error: \(error.localizedDescription)")
    }
}

// The SwiftUI View for address selection
struct AddressSearchView: View {
    @StateObject private var viewModel = AddressSearchViewModel()
    @Environment(\.dismiss) var dismiss
    
    // Callback to pass the selected address string back
    var onAddressSelected: (String) -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Search for your address", text: $viewModel.searchText)
                    .formTextFieldStyle()
                    .padding()
                
                List(viewModel.searchResults, id: \.self) { completion in
                    VStack(alignment: .leading) {
                        Text(completion.title)
                            .font(.headline)
                        Text(completion.subtitle)
                            .font(.subheadline)
                    }
                    .onTapGesture {
                        let fullAddress = "\(completion.title), \(completion.subtitle)"
                        onAddressSelected(fullAddress)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Select Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
