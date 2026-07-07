import SwiftUI
import SwiftData

struct ReviewReceiptView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: ScanViewModel
    @State private var receipt: ParsedReceipt
    @FocusState private var storeNameFocused: Bool
    @State private var focusedNewItemID: UUID?

    init(viewModel: ScanViewModel, receipt: ParsedReceipt) {
        self.viewModel = viewModel
        self._receipt = State(initialValue: receipt)
    }

    private var includedItems: [ParsedReceiptItem] { receipt.items.filter(\.isIncluded) }
    // price already represents the line total for all units of that item
    private var computedTotal: Double { includedItems.reduce(0) { $0 + $1.price } }

    private enum ValidationState {
        case match, appHigher, appLower, noData
    }
    // Compare items total against subtotal (pre-tax) for accurate validation.
    // Fall back to detectedTotal when subtotal is not available.
    private var validationBaseline: Double? { receipt.receiptSubtotal ?? receipt.detectedTotal }
    private var validationState: ValidationState {
        guard let baseline = validationBaseline, baseline > 0 else { return .noData }
        let pct = abs(computedTotal - baseline) / baseline
        if pct <= 0.05 { return .match }
        return computedTotal > baseline ? .appHigher : .appLower
    }

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
            .safeAreaInset(edge: .top, spacing: 0) {
                if !receipt.usedAI && !receipt.items.isEmpty {
                    basicScanWarningBanner
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { viewModel.dismissReview() }
                        .foregroundStyle(.white)
                        .tint(Color(red: 20/255, green: 70/255, blue: 25/255))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        var toSave = receipt
                        toSave.storeName = StoreNameNormalizer.normalize(receipt.storeName)
                        viewModel.saveReceipt(toSave, context: modelContext)
                    }
                    .foregroundStyle(includedItems.isEmpty ? .white.opacity(0.5) : .white)
                    .tint(includedItems.isEmpty
                        ? Color(red: 20/255, green: 70/255, blue: 25/255)
                        : Color(red: 0, green: 200/255, blue: 83/255))
                    .disabled(includedItems.isEmpty)
                }
            }
        }
        .onAppear {
            guard receipt.isManualEntry else { return }
            // Sheet slide-up animation takes ~0.35 s; focus set before it settles is silently dropped.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                storeNameFocused = true
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

    // MARK: - Basic Scan Warning Banner

    private var basicScanWarningBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "pencil.and.list.clipboard")
                .font(.body)
                .foregroundStyle(.orange)
                .padding(.top, 1)
            Text("Quick check needed — basic scan isn't as accurate as AI. Please review items and prices below before saving.")
                .font(.caption)
                .foregroundStyle(Color(.label))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.orange)
                .frame(width: 3)
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
                    .focused($storeNameFocused)
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
                    ItemReviewRow(item: $item, autoFocus: item.id == focusedNewItemID)
                }
                .onDelete { receipt.items.remove(atOffsets: $0) }
            }

            Button {
                let newItem = ParsedReceiptItem(name: "", price: 0)
                focusedNewItemID = newItem.id
                storeNameFocused = false
                receipt.items.append(newItem)
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
            scanBadge

            // Inline warning row when totals differ
            if validationState == .appHigher || validationState == .appLower {
                Label("Totals differ — review items above", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            }

            // Items total (sum of selected items, tax excluded)
            HStack {
                Text("Items Total")
                Spacer()
                Text(computedTotal, format: .currency(code: "USD"))
                    .fontWeight(.semibold)
            }

            // Sales tax row — only shown when backend returned it
            if let tax = receipt.salesTax, tax > 0 {
                HStack {
                    Text("Sales Tax")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(tax, format: .currency(code: "USD"))
                        .foregroundStyle(.secondary)
                }
            }

            // Receipt total (grand total from backend or OCR)
            if let receiptTotal = receipt.detectedTotal {
                HStack {
                    Text("Receipt Total")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(receiptTotal, format: .currency(code: "USD"))
                        .foregroundStyle(.secondary)
                }

                switch validationState {
                case .match:
                    Label("Totals Match", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)

                case .appHigher, .appLower:
                    // Show the signed difference against the baseline (subtotal or total)
                    let diff = computedTotal - (validationBaseline ?? receiptTotal)
                    HStack {
                        Text("Difference")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Spacer()
                        Text(diff, format: .currency(code: "USD").sign(strategy: .always()))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }

                case .noData:
                    EmptyView()
                }
            }
        }
    }

    @ViewBuilder
    private var scanBadge: some View {
        if receipt.usedAI {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption)
                Text("AI Powered ✨")
                    .font(.caption.weight(.medium))
                Spacer()
                Text("\(ScanLimitManager.shared.scansRemaining) scans left")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(Theme.mint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.mint.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .font(.caption)
                Text("Basic Scan")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Item Review Row

private struct ItemReviewRow: View {
    @Binding var item: ParsedReceiptItem
    var autoFocus: Bool = false
    @State private var priceText: String = ""
    @FocusState private var nameFocused: Bool
    @FocusState private var priceFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                item.isIncluded.toggle()
            } label: {
                Image(systemName: item.isIncluded ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isIncluded ? Theme.mint : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
            .accessibilityLabel(item.isIncluded ? "Included" : "Excluded")
            .accessibilityHint("Tap to \(item.isIncluded ? "exclude" : "include") this item")

            VStack(alignment: .leading, spacing: 4) {
                TextField("Item name", text: $item.name)
                    .font(.subheadline)
                    .accessibilityLabel("Item name")
                    .focused($nameFocused)
                    .onAppear {
                        if autoFocus {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                nameFocused = true
                            }
                        }
                        // Auto-classify items that arrive without a category (e.g. from OCR-only scan)
                        guard item.category == nil, !item.name.isEmpty else { return }
                        let result = CategoryTagger.classify(item.name)
                        item.category = result.category
                        item.subCategory = result.subCategory
                    }
                    .onChange(of: item.name) { _, newName in
                        let trimmed = newName.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        let result = CategoryTagger.classify(trimmed)
                        item.category = result.category
                        item.subCategory = result.subCategory
                    }

                HStack(spacing: 6) {
                    categoryMenuButton
                    if item.category == ItemCategory.grocery.rawValue {
                        subCategoryMenuButton
                    }
                }

                if item.quantity > 1 {
                    Text("Qty: \(item.quantity, specifier: "%.0f")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            TextField("0.00", text: $priceText)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .font(.subheadline.weight(.semibold))
                .frame(width: 72)
                .padding(.top, 2)
                .accessibilityLabel("Item price")
                .focused($priceFocused)
                .onAppear {
                    priceText = item.price == 0 ? "" : String(format: "%.2f", item.price)
                }
                .onChange(of: priceText) { _, newVal in
                    let filtered = newVal.filter { $0.isNumber || $0 == "." }
                    if filtered != newVal { priceText = filtered }
                    item.price = Double(filtered) ?? 0
                }
                .onChange(of: priceFocused) { _, focused in
                    if !focused {
                        priceText = item.price == 0 ? "" : String(format: "%.2f", item.price)
                    }
                }
        }
        .opacity(item.isIncluded ? 1 : 0.4)
    }

    // MARK: Category picker

    private var categoryMenuButton: some View {
        Menu {
            ForEach(ItemCategory.allCases, id: \.self) { cat in
                Button(cat.displayName) {
                    item.category = cat.rawValue
                    if cat != .grocery { item.subCategory = nil }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(item.category.flatMap { ItemCategory(rawValue: $0)?.displayName } ?? "Category")
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(item.category == nil ? Color.secondary : categoryColor(item.itemCategory))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background((item.category == nil ? Color.secondary : categoryColor(item.itemCategory)).opacity(0.12))
            .clipShape(Capsule())
        }
    }

    private var subCategoryMenuButton: some View {
        Menu {
            Button("None") { item.subCategory = nil }
            ForEach(CategoryTagger.grocerySubCategories, id: \.self) { sub in
                Button(sub) { item.subCategory = sub }
            }
        } label: {
            HStack(spacing: 3) {
                Text(item.subCategory ?? "Sub-category")
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .font(.caption)
            .foregroundStyle(item.subCategory == nil ? Color.secondary : Color(.label))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(.secondarySystemFill))
            .clipShape(Capsule())
        }
    }

    private func categoryColor(_ cat: ItemCategory) -> Color {
        switch cat {
        case .grocery:      return Theme.mint
        case .household:    return .blue
        case .clothing:     return .purple
        case .electronics:  return .orange
        case .personalCare: return .pink
        case .other:        return Color.secondary
        }
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
        detectedTotal: 21.32,
        receiptSubtotal: 20.66,
        salesTax: 0.66
    )
    return ReviewReceiptView(viewModel: vm, receipt: sample)
        .modelContainer(for: [Receipt.self, GroceryItem.self, Store.self, PriceEntry.self], inMemory: true)
}
