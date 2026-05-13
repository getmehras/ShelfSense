import SwiftUI
import SwiftData

struct StoreDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: Store
    @State private var isRenaming = false
    @State private var pendingName = ""
    @State private var isConfirmingDelete = false

    private var sortedReceipts: [Receipt] {
        store.receipts.sorted { $0.date > $1.date }
    }

    private var totalSpend: Double { store.receipts.reduce(0) { $0 + $1.totalAmount } }
    private var averageSpend: Double {
        store.receipts.isEmpty ? 0 : totalSpend / Double(store.receipts.count)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                NavBarCurve()
                storeHeaderCard
                    .padding(.horizontal, 16)

                statsCard
                    .padding(.horizontal, 16)

                SectionHeader(title: "Trip History")
                tripHistoryCard
                    .padding(.horizontal, 16)

                deleteButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
            }
        }
        .background(Theme.appBackground)
        .greenNavTitle(store.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Rename") {
                    pendingName = store.name
                    isRenaming = true
                }
                .accessibilityLabel("Rename this store")
            }
        }
        .alert("Delete \(store.name)?", isPresented: $isConfirmingDelete) {
            Button("Delete Store & All Trips", role: .destructive) {
                store.deleteWithCascade(from: modelContext)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            let count = store.receipts.count
            Text("This will permanently delete \(store.name) and \(count) trip\(count == 1 ? "" : "s") with all price data. This cannot be undone.")
        }
        .alert("Rename Store", isPresented: $isRenaming) {
            TextField("Store name", text: $pendingName)
                .accessibilityLabel("New store name")
            Button("Save") {
                let trimmed = pendingName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                store.name = trimmed
                for receipt in store.receipts { receipt.storeName = trimmed }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Store Header Card

    private var storeHeaderCard: some View {
        HStack(spacing: 16) {
            StoreAvatar(name: store.name, size: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(store.name)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                if !store.location.isEmpty {
                    Label(store.location, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .cardStyle()
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        HStack(spacing: 0) {
            StoreStatCell(label: "Trips", value: "\(store.receipts.count)")
            Rectangle().fill(Color(.separator)).frame(width: 1, height: 40)
            StoreStatCell(label: "Total Spent", value: totalSpend.formatted(.currency(code: "USD")))
            Rectangle().fill(Color(.separator)).frame(width: 1, height: 40)
            StoreStatCell(label: "Avg / Trip", value: averageSpend.formatted(.currency(code: "USD")))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(store.receipts.count) trips, total \(totalSpend.formatted(.currency(code: "USD"))), average \(averageSpend.formatted(.currency(code: "USD"))) per trip")
    }

    // MARK: - Trip History Card

    private var tripHistoryCard: some View {
        Group {
            if sortedReceipts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "receipt")
                        .font(.system(size: 36))
                        .foregroundStyle(Theme.mint)
                    Text("No receipts yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(28)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sortedReceipts.enumerated()), id: \.element.id) { index, receipt in
                        ReceiptSummaryRow(receipt: receipt)
                        if index < sortedReceipts.count - 1 {
                            Divider().padding(.horizontal, 16)
                        }
                    }
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            }
        }
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button(role: .destructive) {
            isConfirmingDelete = true
        } label: {
            Label("Delete Store", systemImage: "trash")
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .background(Color.red.opacity(0.08))
        .foregroundStyle(.red)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel("Delete \(store.name) and all its trip history")
    }
}

// MARK: - Subviews

private struct StoreStatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .minimumScaleFactor(0.75)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

private struct ReceiptSummaryRow: View {
    let receipt: Receipt

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.primary.opacity(0.08))
                    .frame(width: 36, height: 36)
                Image(systemName: "receipt.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.primary)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(receipt.date, format: .dateTime.month(.wide).day().year())
                    .font(.subheadline.weight(.medium))
                Text("\(receipt.items.count) item\(receipt.items.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(receipt.totalAmount, format: .currency(code: "USD"))
                .font(.subheadline.weight(.bold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(receipt.date.formatted(.dateTime.month().day().year())), \(receipt.items.count) items, \(receipt.totalAmount.formatted(.currency(code: "USD")))")
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Schema([Store.self, Receipt.self, PriceEntry.self, GroceryItem.self]),
        configurations: config
    )
    let ctx = container.mainContext
    let cal = Calendar.current
    let store = Store(name: "Whole Foods", location: "123 Market St"); ctx.insert(store)

    for (days, total) in [(-1, 87.42), (-8, 94.10), (-22, 73.50), (-35, 101.20)] {
        let r = Receipt(
            storeName: store.name,
            date: cal.date(byAdding: .day, value: days, to: .now)!,
            totalAmount: total
        )
        r.store = store; ctx.insert(r)
    }

    return NavigationStack { StoreDetailView(store: store) }.modelContainer(container)
}
