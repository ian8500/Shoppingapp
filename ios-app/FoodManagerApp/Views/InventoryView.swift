import SwiftUI

struct InventoryView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @State private var draft = InventoryItemDraft(rawName: "", quantity: 1, unit: .count, location: nil, lowStockThreshold: nil, notes: nil)
    @State private var isPresentingAdd = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.items) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(item.rawName)
                                .font(.headline)
                            if item.isLowStock {
                                Label("Low", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            Spacer()
                            Text("\(item.quantity.formatted()) \(item.unit.rawValue)")
                                .font(.title3.weight(.semibold))
                        }

                        HStack(spacing: 10) {
                            Button("+1") { Task { await viewModel.increment(item: item) } }
                            Button("-1") { Task { await viewModel.decrement(item: item) } }
                            if item.unit.supportsHalfUsage {
                                Button("Use half") { Task { await viewModel.useHalf(item: item) } }
                            }
                            Button("Finished", role: .destructive) { Task { await viewModel.markFinished(item: item) } }
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)

                        HStack {
                            Text("Low stock at")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField(
                                "Threshold",
                                value: Binding(
                                    get: { item.lowStockThreshold },
                                    set: { newValue in
                                        Task { await viewModel.updateThreshold(item: item, threshold: newValue) }
                                    }
                                ),
                                format: .number
                            )
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            Text(item.unit.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .overlay {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView("Loading inventory")
                }
            }
            .refreshable { await viewModel.loadItems() }
            .navigationTitle("Inventory")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingAdd = true
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingAdd) {
                addItemSheet
            }
            .task { await viewModel.loadItems() }
            .alert("Inventory update failed", isPresented: .constant(viewModel.errorMessage != nil), actions: {
                Button("OK") { viewModel.errorMessage = nil }
            }, message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            })
        }
    }

    private var addItemSheet: some View {
        NavigationStack {
            Form {
                TextField("Item name", text: $draft.rawName)
                TextField("Quantity", value: $draft.quantity, format: .number)
                    .keyboardType(.decimalPad)
                Picker("Unit", selection: $draft.unit) {
                    ForEach(InventoryUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                Picker("Location", selection: Binding(get: { draft.location ?? .other }, set: { draft.location = $0 })) {
                    ForEach(InventoryLocation.allCases) { location in
                        Text(location.rawValue.capitalized).tag(location)
                    }
                }
                TextField("Low stock threshold", value: $draft.lowStockThreshold, format: .number)
                    .keyboardType(.decimalPad)
                TextField("Notes", text: Binding(get: { draft.notes ?? "" }, set: { draft.notes = $0.isEmpty ? nil : $0 }))
            }
            .navigationTitle("Add Inventory")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresentingAdd = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.addItem(draft: draft)
                            draft = InventoryItemDraft(rawName: "", quantity: 1, unit: .count, location: nil, lowStockThreshold: nil, notes: nil)
                            isPresentingAdd = false
                        }
                    }
                    .disabled(draft.rawName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
