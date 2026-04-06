import SwiftUI

struct RecipesView: View {
    var body: some View {
        NavigationStack {
            List {
                Text("Recipes will appear here")
                Text("Recipe-to-shopping and inventory matching hooks go here")
            }
            .navigationTitle("Recipes")
        }
    }
}
