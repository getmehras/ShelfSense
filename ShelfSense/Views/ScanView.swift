import SwiftUI

struct ScanView: View {
    @State private var viewModel = ScanViewModel()

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
            Text("Reading receipt…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(height: 54)
        .accessibilityLabel("Processing receipt, please wait")
    }

    private var actionButtons: some View {
        VStack(spacing: 14) {
            Button("Open Camera") {
                viewModel.isShowingCamera = true
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
        }
    }

    private var tipText: some View {
        Label("Works best with printed receipts in good lighting", systemImage: "lightbulb.fill")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }
}

#Preview {
    ScanView()
}
