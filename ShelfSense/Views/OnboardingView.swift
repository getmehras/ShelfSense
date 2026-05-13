import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    private struct Page {
        let symbol: String
        let title: String
        let subtitle: String
    }

    private let pages: [Page] = [
        Page(
            symbol: "leaf.fill",
            title: "Welcome to ShelfSense",
            subtitle: "Track prices. Outsmart inflation."
        ),
        Page(
            symbol: "camera.fill",
            title: "Scan any grocery receipt in seconds",
            subtitle: "Our OCR engine reads items and prices automatically."
        ),
        Page(
            symbol: "chart.line.uptrend.xyaxis",
            title: "See exactly when prices spike",
            subtitle: "Get alerted when your staples cost more than usual."
        ),
    ]

    var body: some View {
        ZStack {
            Theme.primary.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        pageContent(page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                bottomControls
                    .padding(.bottom, 52)
            }
        }
    }

    // MARK: - Page content

    private func pageContent(_ page: Page) -> some View {
        VStack(spacing: 36) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 180, height: 180)
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 220, height: 220)
                Image(systemName: page.symbol)
                    .font(.system(size: 70, weight: .medium))
                    .foregroundStyle(Theme.mint)
            }

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Bottom controls

    private var bottomControls: some View {
        VStack(spacing: 24) {
            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == currentPage ? Theme.mint : Color.white.opacity(0.30))
                        .frame(width: i == currentPage ? 22 : 8, height: 8)
                        .animation(.spring(duration: 0.35), value: currentPage)
                }
            }

            Button(currentPage < pages.count - 1 ? "Continue" : "Get Started") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    if currentPage < pages.count - 1 {
                        currentPage += 1
                    } else {
                        hasCompletedOnboarding = true
                    }
                }
            }
            .buttonStyle(.mint)
            .padding(.horizontal, 32)
            .accessibilityLabel(currentPage < pages.count - 1 ? "Continue to next page" : "Get started with ShelfSense")
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
