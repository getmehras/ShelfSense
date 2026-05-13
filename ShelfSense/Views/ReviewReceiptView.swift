import SwiftUI
import SwiftData

struct ReviewReceiptView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: ScanViewModel
    @State private var receipt: ParsedReceipt

    init(viewModel: ScanViewModel, receipt: ParsedReceipt) {
        self.viewModel = viewModel
        self._receipt = State(initialValue: receipt)
    }

    private var includedItems: [ParsedReceiptItem] { receipt.items.filter(\.isIncluded) }
    private var computedTotal: Double { includedItems.reduce(0) { $0 + $1.price * $1.quantity } }

    var body: some View {
        NavigationStack {
            List {
                if receipt.items.isEmpty && !receipt.isManualEntry {
                    emptyItemsBanner
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))
                }
                storeSection
                itemsSection
                totalSection
            }
            .scrollContentBackground(.hidden)
            .background(Theme.appBackground)
            .greenNavTitle("Review Receipt")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { viewModel.dismissReview() }
                        .foregroundStyle(.white)
                        .tint(Color(red: 20/255, green: 70/255, blue: 25/255))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        viewModel.saveReceipt(receipt, context: modelContext)
                    }
                    .foregroundStyle(includedItems.isEmpty ? .white.opacity(0.5) : .white)
                    .tint(includedItems.isEmpty
                        ? Color(red: 20/255, green: 70/255, blue: 25/255)
                        : Color(red: 0, green: 200/255, blue: 83/255))
                    .disabled(includedItems.isEmpty)
                }
            }
        }
    }

    // MARK: - Empty banner

    private var emptyItemsBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.counterclockwise.circle.fill")
                .font(.title3)
                .foregroundStyle(Theme.primary)
            Text("No items detected — try scanning again or enter items manually")
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 232/255, green: 245/255, blue: 233/255)) // #E8F5E9
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.primary)
                .frame(width: 4)
        }
    }

    // MARK: - Sections

    private var storeSection: some View {
        Section("Receipt Details") {
            HStack {
                Image(systemName: "storefront.fill")
                    .foregroundStyle(Theme.primary)
                    .accessibilityHidden(true)
                TextField("Store name", text: $receipt.storeName)
                    .accessibilityLabel("Store name")
            }
            DatePicker("Date", selection: $receipt.date, displayedComponents: [.date])
                .accessibilityLabel("Receipt date")
        }
    }

    private var itemsSection: some View {
        Section {
            if receipt.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("No items found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach($receipt.items) { $item in
                    ItemReviewRow(item: $item)
                }
                .onDelete { receipt.items.remove(atOffsets: $0) }
            }

            Button {
                receipt.items.append(ParsedReceiptItem(name: "", price: 0))
            } label: {
                Label("Add Item", systemImage: "plus.circle.fill")
                    .foregroundStyle(Theme.mint)
                    .font(.subheadline.weight(.medium))
            }
            .accessibilityLabel("Add a new item manually")
        } header: {
            HStack {
                Text("Items")
                Spacer()
                if !receipt.items.isEmpty {
                    Text("\(includedItems.count) of \(receipt.items.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
        } footer: {
            if !receipt.items.isEmpty {
                Text("Swipe to delete. Tap the checkmark to exclude an item.")
                    .font(.caption)
            }
        }
    }

    private var totalSection: some View {
        Section("Summary") {
            HStack {
                Text("Items total")
                Spacer()
                Text(computedTotal, format: .currency(code: "USD"))
                    .fontWeight(.semibold)
            }
            if let detected = receipt.detectedTotal {
                HStack {
                    Text("Receipt total").foregroundStyle(.secondary)
                    Spacer()
                    Text(detected, format: .currency(code: "USD")).foregroundStyle(.secondary)
                }
                if abs(computedTotal - detected) > 0.02 {
                    Label("Totals don't match — some items may be missing.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

// MARK: - Item Review Row

private struct ItemReviewRow: View {
    @Binding var item: ParsedReceiptItem

    var body: some View {
        HStack(spacing: 12) {
            Button {
                item.isIncluded.toggle()
            } label: {
                Image(systemName: item.isIncluded ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isIncluded ? Theme.mint : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isIncluded ? "Included" : "Excluded")
            .accessibilityHint("Tap to \(item.isIncluded ? "exclude" : "include") this item")

            VStack(alignment: .leading, spacing: 2) {
                TextField("Item name", text: $item.name)
                    .font(.subheadline)
                    .accessibilityLabel("Item name")
                if item.quantity > 1 {
                    Text("Qty: \(item.quantity, specifier: "%.0f")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            TextField("0.00", value: $item.price, format: .currency(code: "USD"))
                .multilineTextAlignment(.trailing)
                .font(.subheadline.weight(.semibold))
                .frame(width: 72)
                .accessibilityLabel("Item price")
        }
        .opacity(item.isIncluded ? 1 : 0.4)
    }
}

// MARK: - Preview

#Preview {
    let vm = ScanViewModel()
    let sample = ParsedReceipt(
        storeName: "Whole Foods",
        date: .now,
        items: [
            ParsedReceiptItem(name: "Organic Milk", price: 6.89),
            ParsedReceiptItem(name: "Free Range Eggs", price: 5.29),
            ParsedReceiptItem(name: "Sourdough Bread", price: 4.49),
            ParsedReceiptItem(name: "Baby Spinach", price: 3.99, quantity: 2),
        ],
        detectedTotal: 20.66
    )
    return ReviewReceiptView(viewModel: vm, receipt: sample)
        .modelContainer(for: [Receipt.self, GroceryItem.self, Store.self, PriceEntry.self], inMemory: true)
}
