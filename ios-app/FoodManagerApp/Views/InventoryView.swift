import SwiftUI

struct InventoryView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @State private var draft = InventoryItemDraft(rawName: "", quantity: 1, unit: .count, location: nil, lowStockThreshold: nil, notes: nil)
    @State private var isPresentingAdd = false
    @State private var isShowingScanner = false
    @State private var knownScanQuantity: Double = 1

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
                if viewModel.isBarcodeLookupLoading {
                    ProgressView("Looking up barcode…")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .refreshable { await viewModel.loadItems() }
            .navigationTitle("Inventory")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isShowingScanner = true
                    } label: {
                        Label("Scan", systemImage: "barcode.viewfinder")
                    }

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
            .fullScreenCover(isPresented: $isShowingScanner) {
                scannerSheet
            }
            .sheet(item: $viewModel.knownScanState) { state in
                knownProductSheet(state: state)
            }
            .sheet(item: $viewModel.unknownScanState) { _ in
                unknownProductSheet
            }
            .task { await viewModel.loadItems() }
            .alert("Inventory update failed", isPresented: .constant(viewModel.errorMessage != nil), actions: {
                Button("OK") { viewModel.errorMessage = nil }
            }, message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            })
            .alert("Barcode added", isPresented: .constant(viewModel.scanSuccessMessage != nil), actions: {
                Button("OK") { viewModel.scanSuccessMessage = nil }
            }, message: {
                Text(viewModel.scanSuccessMessage ?? "")
            })
        }
    }

    private var scannerSheet: some View {
        ZStack(alignment: .topTrailing) {
            BarcodeScannerView(onCodeScanned: { code in
                isShowingScanner = false
                Task { await viewModel.handleScannedBarcode(code) }
            }, onError: { message in
                isShowingScanner = false
                viewModel.errorMessage = message
            })
            .ignoresSafeArea()

            Button("Close") {
                isShowingScanner = false
            }
            .padding()
            .buttonStyle(.borderedProminent)
        }
    }

    private func knownProductSheet(state: KnownBarcodeScanState) -> some View {
        NavigationStack {
            Form {
                Section("Detected Product") {
                    Text(state.productName)
                    Text("Barcode: \(state.barcode)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Quantity") {
                    Stepper(value: $knownScanQuantity, in: 0.5...100, step: 0.5) {
                        Text("\(knownScanQuantity.formatted())")
                    }
                }
            }
            .onAppear { knownScanQuantity = 1 }
            .navigationTitle("Confirm Product")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { viewModel.knownScanState = nil }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        Task { await viewModel.confirmKnownBarcode(quantity: knownScanQuantity) }
                    }
                }
            }
        }
    }

    private var unknownProductSheet: some View {
        NavigationStack {
            Form {
                Section("Barcode") {
                    Text(viewModel.unknownScanState?.barcode ?? "")
                        .font(.callout.monospaced())
                }

                Section("Create Product") {
                    TextField(
                        "Product name",
                        text: Binding(
                            get: { viewModel.unknownScanState?.productName ?? "" },
                            set: { viewModel.unknownScanState?.productName = $0 }
                        )
                    )
                    Stepper(
                        value: Binding(
                            get: { viewModel.unknownScanState?.quantity ?? 1 },
                            set: { viewModel.unknownScanState?.quantity = $0 }
                        ),
                        in: 0.5...100,
                        step: 0.5
                    ) {
                        Text("Quantity: \((viewModel.unknownScanState?.quantity ?? 1).formatted())")
                    }
                    Toggle(
                        "Remember this barcode",
                        isOn: Binding(
                            get: { viewModel.unknownScanState?.shouldRememberMapping ?? true },
                            set: { viewModel.unknownScanState?.shouldRememberMapping = $0 }
                        )
                    )
                }
            }
            .navigationTitle("Unknown Barcode")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { viewModel.unknownScanState = nil }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task { await viewModel.submitUnknownBarcode() }
                    }
                }
            }
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
