import SwiftUI

struct ScanView: View {
    @State private var viewModel = ScanViewModel()
    @ObservedObject private var scanLimit = ScanLimitManager.shared
    @AppStorage("scan_tips_shown") private var scanTipsShown = false
    @State private var showScanTips = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    NavBarCurve()
                    Spacer()
                    illustrationArea
                    Spacer(minLength: 40)
                    bottomPanel
                }
            }
            .greenNavTitle("Scan Receipt")
        }
        .fullScreenCover(isPresented: $viewModel.isShowingCamera) {
            DocumentCameraView(
                onScan: { viewModel.processScannedImages($0) },
                onCancel: { viewModel.isShowingCamera = false }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $viewModel.isShowingReview) {
            if let receipt = viewModel.parsedReceipt {
                ReviewReceiptView(viewModel: viewModel, receipt: receipt)
            }
        }
        // Scan quality error sheet
        .sheet(isPresented: Binding(
            get: { viewModel.scanValidationError != nil },
            set: { if !$0 { viewModel.scanValidationError = nil } }
        )) {
            if let reason = viewModel.scanValidationError {
                ScanErrorSheet(reason: reason) {
                    viewModel.scanValidationError = nil
                    viewModel.isShowingCamera = true
                } onManualEntry: {
                    viewModel.scanValidationError = nil
                    viewModel.isShowingReview = true
                    viewModel.parsedReceipt = ParsedReceipt(storeName: "", items: [], isManualEntry: true)
                }
            }
        }
        // First-use tips sheet
        .sheet(isPresented: $showScanTips) {
            ScanTipsView {
                showScanTips = false
                viewModel.isShowingCamera = true
            }
        }
        .alert("Scan Failed", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Illustration area

    private var illustrationArea: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(Theme.mint.opacity(0.08))
                    .frame(width: 120, height: 120)
                Circle()
                    .fill(Theme.mint.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Theme.primary)
                    .accessibilityHidden(true)
            }

            VStack(spacing: 8) {
                Text("Scan a Receipt")
                    .font(.system(size: 26, weight: .bold, design: .rounded))

                Text("Point your camera at a grocery receipt.\nItems and prices are detected automatically.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }

    // MARK: - Bottom panel

    private var bottomPanel: some View {
        VStack(spacing: 16) {
            if viewModel.isProcessing {
                processingView
            } else {
                actionButtons
            }
            tipText
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }

    private var processingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.3)
                .tint(Theme.mint)
            Text(viewModel.isUsingAI ? "Analyzing with AI…" : "Reading receipt…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(height: 54)
        .accessibilityLabel("Processing receipt, please wait")
    }

    private var actionButtons: some View {
        VStack(spacing: 14) {
            Button("Open Camera") {
                if scanTipsShown {
                    viewModel.isShowingCamera = true
                } else {
                    scanTipsShown = true
                    showScanTips = true
                }
            }
            .buttonStyle(.mint)
            .accessibilityLabel("Open camera to scan receipt")

            Button {
                viewModel.isShowingReview = true
                viewModel.parsedReceipt = ParsedReceipt(storeName: "", items: [], isManualEntry: true)
            } label: {
                Text("Enter Manually")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Enter receipt items manually")

            scanStatusView
                .padding(.top, 8)
        }
    }

    private var scanStatusView: some View {
        VStack(spacing: 6) {
            Text(scanLimit.statusText)
                .font(.caption)
                .foregroundStyle(scanLimit.hasAIScansRemaining ? Color.secondary : Color.orange)
                .multilineTextAlignment(.center)
            ProgressView(value: scanLimit.progressValue)
                .tint(scanLimit.hasAIScansRemaining ? Theme.mint : .orange)
                .frame(width: 180)
        }
    }

    private var tipText: some View {
        Label("Works best with printed receipts in good lighting", systemImage: "lightbulb.fill")
            .font(.caption)
            .foregroundStyle(Color(.tertiaryLabel))
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }
}

// MARK: - Scan Error Sheet

private struct ScanErrorSheet: View {
    let reason: ReceiptScanValidator.FailureReason
    let onRetry: () -> Void
    let onManualEntry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "viewfinder.trianglebadge.2.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)
            }
            .padding(.top, 8)

            VStack(spacing: 8) {
                Text("Scan Quality Issue")
                    .font(.title3.weight(.bold))
                Text(reason.userMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 12) {
                Button(reason.retryButtonText) {
                    onRetry()
                }
                .buttonStyle(.mint)

                Button("Enter Manually") {
                    onManualEntry()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.primary)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 0)
        }
        .padding(.top, 32)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Scan Tips View (first use only)

private struct ScanTipsView: View {
    let onDismiss: () -> Void

    private let tips: [(icon: String, text: String)] = [
        ("iphone",          "Hold phone directly above receipt"),
        ("lightbulb.fill",  "Good lighting helps accuracy"),
        ("doc.text.fill",   "Capture the full receipt in frame"),
        ("hand.raised.fill","Keep phone steady while scanning"),
    ]

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 6) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Theme.primary)
                Text("Scanning Tips")
                    .font(.title3.weight(.bold))
                Text("For best results:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)

            VStack(alignment: .leading, spacing: 18) {
                ForEach(tips, id: \.text) { tip in
                    HStack(spacing: 14) {
                        Image(systemName: tip.icon)
                            .font(.body)
                            .foregroundStyle(Theme.mint)
                            .frame(width: 24)
                        Text(tip.text)
                            .font(.subheadline)
                    }
                }
            }
            .padding(.horizontal, 32)

            Text("Opening camera…")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                onDismiss()
            }
        }
    }
}

#Preview {
    ScanView()
}
