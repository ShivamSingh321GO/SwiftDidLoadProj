import SwiftUI

struct SpacesView: View {
    @Environment(AppViewModel.self) var viewModel
    @State private var showingCreateSpace = false
    @State private var newSpaceName = ""
    
    var body: some View {
        List {
            ForEach(viewModel.spaces) { space in
                NavigationLink(destination: SpaceDetailView(space: space)) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(AppTheme.Colors.primary)
                            .imageScale(.large)
                        
                        VStack(alignment: .leading) {
                            Text(space.name)
                                .font(.headline)
                            Text("\(space.items.count) items")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                    .padding(.vertical, AppTheme.Spacing.small)
                }
            }
        }
        .navigationTitle("Your Spaces")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingCreateSpace = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("Create New Space", isPresented: $showingCreateSpace) {
            TextField("Space Name", text: $newSpaceName)
            Button("Cancel", role: .cancel) {
                newSpaceName = ""
            }
            Button("Create") {
                viewModel.createSpaceAndTransferCart(name: newSpaceName)
                newSpaceName = ""
            }
        } message: {
            Text("Enter a name for your new space. Current cart items will be moved here.")
        }
    }
}

struct SpaceDetailView: View {
    let space: Space
    
    var body: some View {
        List(space.items) { item in
            HStack {
                Text(item.name)
                Spacer()
                Text("₹\(item.price)")
                    .fontWeight(.bold)
            }
        }
        .navigationTitle(space.name)
        .overlay {
            if space.items.isEmpty {
                Text("No items in this space yet.")
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
    }
}

#Preview {
    NavigationView {
        SpacesView()
            .environment(AppViewModel())
    }
}
