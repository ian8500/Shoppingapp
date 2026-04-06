import SwiftUI

struct InventoryView: View {
    var body: some View {
        NavigationStack {
            List {
                Text("Inventory items will appear here")
                Text("Barcode entry flow plugs into this module")
            }
            .navigationTitle("Inventory")
        }
    }
}
