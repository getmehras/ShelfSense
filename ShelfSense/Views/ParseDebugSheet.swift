import SwiftUI

struct ParseDebugSheet: View {
    let info: ParseDebugInfo
    let itemCount: Int
    let onReview: () -> Void
    let onDismiss: () -> Void

    @State private var showRawOCR = false
    @State private var copied = false

    var body: some View {
        NavigationStack {
            List {
                summarySection
                if !info.acceptedItems.isEmpty { acceptedSection }
                if !info.rejectedLines.isEmpty { rejectedSection }
                rawOCRSection
            }
            .navigationTitle("Parse Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done", action: onDismiss)
                }
                if itemCount > 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Review \(itemCount) Item\(itemCount == 1 ? "" : "s")") {
                            onReview()
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.mint)
                    }
                }
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        Section("Summary") {
            LabeledContent("Store detected", value: info.storeName)
            if let total = info.detectedTotal {
                LabeledContent("Total on receipt",
                               value: total.formatted(.currency(code: "USD")))
            }
            LabeledContent("OCR lines", value: "\(info.rawLines.count)")
            LabeledContent("Items parsed") {
                Text("\(info.itemCount)")
                    .foregroundStyle(info.itemCount > 0 ? Theme.mint : .red)
                    .fontWeight(.semibold)
            }
            LabeledContent("Lines rejected", value: "\(info.rejectedCount)")
        }
    }

    // MARK: - Accepted items

    private var acceptedSection: some View {
        Section("Accepted Items (\(info.acceptedItems.count))") {
            ForEach(info.acceptedItems) { item in
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.cleanedName)
                        .font(.subheadline.weight(.medium))
                    Text(item.originalLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .overlay(alignment: .trailing) {
                    Text(item.price, format: .currency(code: "USD"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.mint)
                }
            }
        }
    }

    // MARK: - Rejected lines

    private var rejectedSection: some View {
        Section("Rejected Lines (\(info.rejectedLines.count))") {
            ForEach(info.rejectedLines) { line in
                VStack(alignment: .leading, spacing: 3) {
                    Text(line.text.isEmpty ? "(empty line)" : line.text)
                        .font(.caption)
                        .foregroundStyle(Color(.label))
                        .lineLimit(2)
                    Text(line.reason)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    // MARK: - Raw OCR

    private var rawOCRSection: some View {
        Section {
            Button {
                UIPasteboard.general.string = info.rawText
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
            } label: {
                Label(copied ? "Copied!" : "Copy Raw OCR Text",
                      systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc")
                    .foregroundStyle(copied ? Theme.mint : Theme.primary)
                    .fontWeight(.medium)
            }

            DisclosureGroup("Show Raw OCR (\(info.rawLines.count) lines)",
                            isExpanded: $showRawOCR) {
                Text(info.rawText)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Color(.secondaryLabel))
                    .textSelection(.enabled)
                    .padding(.vertical, 4)
            }
        } header: {
            Text("Raw OCR Text")
        } footer: {
            Text("Tap \"Copy Raw OCR Text\" and paste it into Claude to analyze why items are being missed.")
                .font(.caption)
        }
    }
}

#Preview {
    ParseDebugSheet(
        info: ParseDebugInfo(
            rawLines: ["WHOLE FOODS MARKET", "ORG MILK 64OZ    6.89 F",
                       "FREE RNG EGGS 12  5.29 F", "TOTAL    12.18",
                       "VISA      12.18"],
            storeName: "Whole Foods Market",
            detectedTotal: 12.18,
            acceptedItems: [
                .init(originalLine: "ORG MILK 64OZ    6.89 F",
                      cleanedName: "Org Milk 64Oz", price: 6.89),
                .init(originalLine: "FREE RNG EGGS 12  5.29 F",
                      cleanedName: "Free Rng Eggs 12", price: 5.29),
            ],
            rejectedLines: [
                .init(text: "TOTAL    12.18", reason: "skip keyword"),
                .init(text: "VISA      12.18", reason: "skip keyword"),
            ]
        ),
        itemCount: 2,
        onReview: {},
        onDismiss: {}
    )
}
