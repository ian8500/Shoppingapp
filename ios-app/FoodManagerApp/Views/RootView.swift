import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            ShoppingListView()
                .tabItem {
                    Label("Shopping", systemImage: "cart")
                }
                .tag(AppTab.shopping)

            InventoryView()
                .tabItem {
                    Label("Inventory", systemImage: "shippingbox")
                }
                .tag(AppTab.inventory)

            RecipesView()
                .tabItem {
                    Label("Recipes", systemImage: "book")
                }
                .tag(AppTab.recipes)
        }
        .task {
            await appState.performHealthCheck()
        }
    }
}
