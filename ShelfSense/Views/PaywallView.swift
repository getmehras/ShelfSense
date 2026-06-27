import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    var onContinue: (() -> Void)? = nil

    private let features: [(icon: String, text: String)] = [
        ("camera.viewfinder",             "Scan receipts from any store"),
        ("globe",                         "Works with any store worldwide"),
        ("storefront.fill",               "Automatic store name detection"),
        ("chart.line.uptrend.xyaxis",     "Price history & inflation tracking"),
        ("bell.badge.fill",               "Price spike notifications"),
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    messageSection
                    featuresSection
                    ctaSection
                }
            }
            .ignoresSafeArea(edges: .top)

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(radius: 4)
            }
            .buttonStyle(.plain)
            .padding(.top, 52)
            .padding(.trailing, 16)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        ZStack {
            Theme.heroGradient

            VStack(spacing: 12) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.top, 72)

                Text("Monthly Limit Reached")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("AI scans reset on \(ScanLimitManager.shared.nextResetDate)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Message

    private var messageSection: some View {
        Text("You've used your \(ScanLimitManager.freeLimit) free AI scans this month. Basic scanning is still available, but it's less accurate — you may need to fix a few item names or prices. Resets on \(ScanLimitManager.shared.nextResetDate).")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(features, id: \.text) { feature in
                HStack(spacing: 14) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.mint)
                        .font(.body)
                        .frame(width: 22)
                    Text(feature.text)
                        .font(.subheadline)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - CTA

    private var ctaSection: some View {
        Button {
            onContinue?()
            dismiss()
        } label: {
            Text("Continue with Basic Scan")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Theme.primary)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 40)
    }
}

#Preview {
    PaywallView()
}
