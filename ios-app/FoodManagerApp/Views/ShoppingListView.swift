import SwiftUI

struct ShoppingListView: View {
    var body: some View {
        NavigationStack {
            List {
                Text("Shopping list items will appear here")
            }
            .navigationTitle("Shopping List")
        }
    }
}
