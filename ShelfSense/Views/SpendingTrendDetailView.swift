import SwiftUI
import Charts
import UIKit

// MARK: - Chart range filter

enum ChartRange: String, CaseIterable, Identifiable {
    case threeMonth = "3M"
    case sixMonth   = "6M"
    case oneYear    = "1Y"
    case max        = "Max"
    var id: String { rawValue }
}

// MARK: - Shared bar chart component

struct SpendingBarChart: View {
    let data: [DashboardViewModel.MonthlySpend]
    let height: CGFloat
    let darkMode: Bool
    @Binding var selectedLabel: String?

    init(data: [DashboardViewModel.MonthlySpend],
         height: CGFloat,
         darkMode: Bool = false,
         selectedLabel: Binding<String?> = .constant(nil)) {
        self.data           = data
        self.height         = height
        self.darkMode       = darkMode
        self._selectedLabel = selectedLabel
    }

    var body: some View {
        Chart(data) { spend in
            BarMark(
                x: .value("Month", spend.label),
                y: .value("Amount", spend.total)
            )
            .foregroundStyle(barColor(for: spend))
            .cornerRadius(6)
            .annotation(position: .top, alignment: .center, spacing: 4) {
                if spend.label == selectedLabel, spend.total > 0 {
                    calloutPill(spend: spend)
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    .foregroundStyle(darkMode ? Color.white.opacity(0.12) : Color(.separator))
                AxisValueLabel(format: .currency(code: "USD"))
                    .foregroundStyle(darkMode ? Color.white.opacity(0.5) : Color(.secondaryLabel))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel()
                    .foregroundStyle(darkMode ? Color.white.opacity(0.5) : Color(.secondaryLabel))
            }
        }
        .chartYScale(domain: 0 ... max((data.map(\.total).max() ?? 1) * 1.2, 1))
        // proxy.value(atX:as:String.self) returns nil for ordinal string categories in
        // this Swift Charts version, so we compute bar index directly from fractional
        // tap position instead. Bars are evenly laid out across the plot width.
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                guard let anchor = proxy.plotFrame else { return }
                                let plotFrame = geo[anchor]
                                let xPos = drag.location.x - plotFrame.origin.x
                                guard !data.isEmpty, plotFrame.width > 0 else { return }
                                let fraction = max(0.0, min(1.0, Double(xPos / plotFrame.width)))
                                let index    = min(Int(fraction * Double(data.count)), data.count - 1)
                                selectedLabel = data[index].label
                            }
                        // onEnded intentionally absent — selection stays after finger lifts
                    )
            }
        }
        .frame(height: height)
        .accessibilityLabel("Bar chart showing monthly spending")
    }

    @ViewBuilder
    private func calloutPill(spend: DashboardViewModel.MonthlySpend) -> some View {
        Text("\(spend.label) · \(spend.total, format: .currency(code: "USD"))")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(red: 27/255, green: 94/255, blue: 32/255))
            .clipShape(Capsule())
    }

    private func barColor(for spend: DashboardViewModel.MonthlySpend) -> Color {
        if spend.label == selectedLabel { return Theme.mint }
        if spend.isCurrent             { return Theme.mint.opacity(0.5) }
        return darkMode ? Color.white.opacity(0.22) : Theme.primary.opacity(0.35)
    }
}

// MARK: - Full-screen chart view

struct SpendingTrendDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let monthlySpends: [DashboardViewModel.MonthlySpend]

    @State private var selectedRange: ChartRange = .sixMonth
    @State private var selectedLabel: String?    = nil

    // MARK: Computed

    private var filteredSpends: [DashboardViewModel.MonthlySpend] {
        switch selectedRange {
        // Fixed windows: exact N months, no trimming — switching tabs always
        // produces a visible change in bar count even with sparse data.
        case .threeMonth: return Array(monthlySpends.suffix(3))
        case .sixMonth:   return Array(monthlySpends.suffix(6))
        case .oneYear:    return Array(monthlySpends.suffix(12))
        // Max only: trim leading zero months so chart starts at first receipt.
        case .max:
            let trimmed = Array(monthlySpends.drop(while: { $0.total == 0 }))
            return trimmed.isEmpty ? monthlySpends : trimmed
        }
    }

    private var selectedSpend: DashboardViewModel.MonthlySpend? {
        guard let label = selectedLabel else { return nil }
        return filteredSpends.first { $0.label == label }
    }

    private var rangeTotal: Double {
        filteredSpends.reduce(0) { $0 + $1.total }
    }

    private var nonZeroCount: Int {
        filteredSpends.filter { $0.total > 0 }.count
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                // compact = landscape on iPhone (height < width, roughly < 500pt)
                let compact = geo.size.height < 500

                Color(red: 18/255, green: 18/255, blue: 20/255)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    headerSection(compact: compact)
                        .padding(.horizontal, 20)
                        .padding(.top,    compact ? 8  : 16)
                        .padding(.bottom, compact ? 10 : 20)

                    rangeTabs
                        .padding(.horizontal, 20)
                        .padding(.bottom, compact ? 8 : 16)

                    chartSection(geo: geo, compact: compact)
                        .padding(.horizontal, 16)

                    Spacer(minLength: 0)

                    totalRow
                        .padding(.horizontal, 20)
                        .padding(.bottom, compact ? 12 : 28)
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("Spending trend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear {
            // Unlock landscape so the user can rotate voluntarily.
            // No requestGeometryUpdate here — don't override the system rotation lock.
            AppDelegate.orientationLock = [.portrait, .landscapeLeft, .landscapeRight]
            if selectedLabel == nil {
                selectedLabel = filteredSpends.last(where: { $0.total > 0 })?.label
            }
        }
        .onDisappear {
            // Re-lock portrait and nudge system back if dismissed while in landscape.
            AppDelegate.orientationLock = .portrait
            if #available(iOS 16.0, *) {
                guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { _ in }
                scene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            } else {
                UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            }
        }
        .onChange(of: selectedRange) { _, _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedLabel = filteredSpends.last(where: { $0.total > 0 })?.label
            }
        }
    }

    // MARK: Header

    private func headerSection(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                if let spend = selectedSpend {
                    Text("Selected: \(spend.label)")
                } else {
                    Text(selectedRange == .max ? "All time" : "Last \(selectedRange.rawValue)")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Text(selectedSpend?.total ?? rangeTotal, format: .currency(code: "USD"))
                .font(.system(size: compact ? 28 : 38, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.mint)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.15), value: selectedLabel)
                .animation(.easeInOut(duration: 0.15), value: selectedRange)

            // Hide subtitle in compact (landscape) to save vertical space
            if !compact {
                Text("\(nonZeroCount) month\(nonZeroCount == 1 ? "" : "s") with spend")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Range tabs

    private var rangeTabs: some View {
        HStack(spacing: 8) {
            ForEach(ChartRange.allCases) { range in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedRange = range
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.subheadline.weight(selectedRange == range ? .semibold : .regular))
                        .foregroundStyle(selectedRange == range ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            selectedRange == range
                                ? Color(red: 27/255, green: 94/255, blue: 32/255)
                                : Color.clear
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    Color.white.opacity(selectedRange == range ? 0 : 0.18),
                                    lineWidth: 1
                                )
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Chart

    @ViewBuilder
    private func chartSection(geo: GeometryProxy, compact: Bool) -> some View {
        // Portrait reserves ~278pt for header + tabs + total + padding.
        // Compact (landscape) reserves ~165pt — header loses subtitle line,
        // paddings shrink, giving the chart as much height as possible.
        let reserved: CGFloat  = compact ? 165 : 278
        let minHeight: CGFloat = compact ? 100 : 160
        let chartH = max(geo.size.height - reserved, minHeight)

        let isWide = filteredSpends.count > 12
        let minBarWidth: CGFloat = 44
        let chartW = isWide
            ? max(CGFloat(filteredSpends.count) * minBarWidth, geo.size.width - 32)
            : geo.size.width - 32

        if isWide {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    SpendingBarChart(
                        data: filteredSpends,
                        height: chartH,
                        darkMode: true,
                        selectedLabel: $selectedLabel
                    )
                    .frame(width: chartW)
                    .id("chartBody")
                }
                .onAppear { proxy.scrollTo("chartBody", anchor: .trailing) }
                .onChange(of: selectedRange) { _, _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        proxy.scrollTo("chartBody", anchor: .trailing)
                    }
                }
            }
        } else {
            SpendingBarChart(
                data: filteredSpends,
                height: chartH,
                darkMode: true,
                selectedLabel: $selectedLabel
            )
            .frame(width: chartW)
        }
    }

    // MARK: Total row

    private var totalRow: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.12))
                .padding(.bottom, 14)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Total")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("(\(selectedRange.rawValue) range)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(rangeTotal, format: .currency(code: "USD"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let cal = Calendar.current
    let now = Date.now
    let fmt = DateFormatter()
    fmt.dateFormat = "MMM ''yy"
    let samples: [DashboardViewModel.MonthlySpend] = (0..<12).reversed().map { offset in
        let date = cal.date(byAdding: .month, value: -offset, to: now)!
        return DashboardViewModel.MonthlySpend(
            month: date,
            label: fmt.string(from: date),
            total: [3, 7].contains(offset) ? 0 : Double.random(in: 60...220),
            isCurrent: offset == 0
        )
    }
    return SpendingTrendDetailView(monthlySpends: samples)
}
