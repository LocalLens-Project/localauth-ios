import SwiftUI

struct ContentView: View {
    var tokenStore: TokenStore
    @Binding var hasCompletedOnboarding: Bool
    @Binding var showPrivacyOverlay: Bool

    var body: some View {
        ZStack {
            if hasCompletedOnboarding {
                TokenListView(tokenStore: tokenStore)
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            }

            if showPrivacyOverlay {
                PrivacyOverlayView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showPrivacyOverlay)
    }
}
