import SwiftUI
import SwiftData

struct SplashView: View {
    @Binding var isActive: Bool

    @State private var logoScale: CGFloat = 0.55
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var taglineOffset: CGFloat = 16
    @State private var glowOpacity: Double = 0

    var body: some View {
        ZStack {
            // Background — same hero gradient used throughout the app
            Theme.heroGradient
                .ignoresSafeArea()

            // Decorative ambient circles
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 360, height: 360)
                .offset(x: 140, y: -220)
                .blur(radius: 2)

            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 240, height: 240)
                .offset(x: -150, y: 260)
                .blur(radius: 2)

            Circle()
                .fill(Theme.mint.opacity(0.08))
                .frame(width: 180, height: 180)
                .offset(x: 60, y: 180)
                .blur(radius: 40)

            // Center content
            VStack(spacing: 0) {
                Spacer()

                // Logo mark
                ZStack {
                    // Outer glow ring
                    Circle()
                        .fill(Theme.mint.opacity(0.18))
                        .frame(width: 130, height: 130)
                        .blur(radius: 20)
                        .opacity(glowOpacity)

                    // Icon container
                    Circle()
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 108, height: 108)

                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 88, height: 88)

                    Image(systemName: "cart.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(Theme.mint)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                Spacer().frame(height: 32)

                // App name
                Text("ShelfSense")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(textOpacity)

                Spacer().frame(height: 10)

                // Tagline
                Text("Track prices. Save more.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
                    .opacity(textOpacity)
                    .offset(y: taglineOffset)

                Spacer()

                // Animated loading dots
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        PulseDot(delay: Double(i) * 0.18)
                    }
                }
                .opacity(textOpacity)
                .padding(.bottom, 56)
            }
        }
        .onAppear {
            // Logo springs in
            withAnimation(.spring(response: 0.65, dampingFraction: 0.62).delay(0.08)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            // Glow blooms slightly after the logo
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                glowOpacity = 1.0
            }
            // Text slides up and fades in
            withAnimation(.easeOut(duration: 0.5).delay(0.42)) {
                textOpacity = 1.0
                taglineOffset = 0
            }
            // Dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                withAnimation(.easeInOut(duration: 0.45)) {
                    isActive = false
                }
            }
        }
    }
}

// MARK: - Pulsing dot

private struct PulseDot: View {
    let delay: Double
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.25

    var body: some View {
        Circle()
            .fill(Theme.mint)
            .frame(width: 7, height: 7)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.55)
                    .repeatForever(autoreverses: true)
                    .delay(delay + 0.9)
                ) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
    }
}

// MARK: - Root wrapper

struct RootView: View {
    @State private var container: ModelContainer?
    @State private var showSplash = true

    var body: some View {
        ZStack {
            // Solid green renders on frame 1 — no blocking work, no database I/O.
            // This is the first pixel the GPU draws, covering any gap between the
            // system launch screen and SwiftUI becoming ready.
            Color(red: 27/255, green: 94/255, blue: 32/255)
                .ignoresSafeArea()

            // ContentView is only added to the hierarchy once the container is ready.
            if let container {
                ContentView()
                    .modelContainer(container)
            }

            if showSplash {
                SplashView(isActive: $showSplash)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            // Create ModelContainer on a background thread so the main thread stays
            // free to render the splash immediately. The splash lasts 2.4 s —
            // far longer than database setup typically takes, so ContentView is
            // always ready before the splash dismisses.
            container = await Task.detached(priority: .userInitiated) {
                let schema = Schema([Receipt.self, GroceryItem.self, Store.self, PriceEntry.self])
                let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                return try? ModelContainer(for: schema, configurations: [config])
            }.value
        }
    }
}

// MARK: - Preview

#Preview {
    SplashView(isActive: .constant(true))
}
