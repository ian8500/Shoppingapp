import SwiftUI

struct ShoppingListView: View {
    @ObservedObject var viewModel: ShoppingListViewModel
    @State private var draft: ShoppingListItemDraft = .empty
    @State private var editingItem: ShoppingListItem?
    @State private var isPresentingComposer = false

    var body: some View {
        List {
            if !viewModel.activeItems.isEmpty {
                Section("Active") {
                    ForEach(viewModel.activeItems) { item in
                        ShoppingListRow(item: item)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("Bought") {
                                    Task { await viewModel.markBought(itemID: item.id) }
                                }
                                .tint(.green)

                                Button("Edit") {
                                    editingItem = item
                                    draft = .fromItem(item)
                                    isPresentingComposer = true
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button("Archive", role: .destructive) {
                                    Task { await viewModel.archiveItem(itemID: item.id) }
                                }
                            }
                    }
                }
            }

            Section("Bought") {
                if viewModel.boughtItems.isEmpty {
                    Text("Nothing bought yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.boughtItems) { item in
                        ShoppingListRow(item: item)
                            .foregroundStyle(.secondary)
                            .swipeActions {
                                Button("Archive", role: .destructive) {
                                    Task { await viewModel.archiveItem(itemID: item.id) }
                                }
                            }
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView("Loading shopping list")
            }
        }
        .refreshable {
            await viewModel.loadItems()
        }
        .navigationTitle("Shopping List")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingItem = nil
                    draft = .empty
                    isPresentingComposer = true
                } label: {
                    Label("Add Item", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingComposer) {
            ShoppingItemComposerView(
                title: editingItem == nil ? "Add Item" : "Edit Item",
                draft: $draft,
                onSave: {
                    await saveDraft()
                }
            )
            .presentationDetents([.medium, .large])
        }
        .alert("Could not update list", isPresented: .constant(viewModel.errorMessage != nil), actions: {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        }, message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        })
        .task {
            viewModel.connectRealtimeIfPossible()
            await viewModel.loadItems()
        }
    }

    private func saveDraft() async {
        let currentDraft = draft
        isPresentingComposer = false
        if let editingItem {
            await viewModel.updateItem(itemID: editingItem.id, draft: currentDraft)
        } else {
            await viewModel.addItem(draft: currentDraft)
        }
    }
}

private struct ShoppingListRow: View {
    let item: ShoppingListItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.status == .bought ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.status == .bought ? .green : .secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.rawName)
                    .font(.body.weight(.medium))

                HStack(spacing: 8) {
                    if let quantity = item.quantity {
                        Text("\(quantity.formatted())")
                    }
                    if let unit = item.unit {
                        Text(unit)
                    }
                    if let category = item.category {
                        Text("• \(category)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ShoppingItemComposerView: View {
    let title: String
    @Binding var draft: ShoppingListItemDraft
    let onSave: () async -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Item name", text: $draft.rawName)
                TextField("Quantity", value: $draft.quantity, format: .number)
                    .keyboardType(.decimalPad)
                TextField("Unit", text: binding(for: \.unit))
                TextField("Category", text: binding(for: \.category))
                TextField("Notes", text: binding(for: \.notes), axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task {
                            await onSave()
                            dismiss()
                        }
                    }
                    .disabled(draft.rawName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func binding(for keyPath: WritableKeyPath<ShoppingListItemDraft, String?>) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath] ?? "" },
            set: { draft[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }
}

private extension ShoppingListItemDraft {
    static var empty: ShoppingListItemDraft {
        ShoppingListItemDraft(rawName: "", quantity: nil, unit: nil, category: nil, notes: nil)
    }

    static func fromItem(_ item: ShoppingListItem) -> ShoppingListItemDraft {
        ShoppingListItemDraft(
            rawName: item.rawName,
            quantity: item.quantity,
            unit: item.unit,
            category: item.category,
            notes: item.notes
        )
    }
}
