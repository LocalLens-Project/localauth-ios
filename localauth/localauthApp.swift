import SwiftUI
import SwiftData

@main
struct LocalAuthApp: App {
    @State private var tokenStore: TokenStore?
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPrivacyOverlay = false
    
    let container: ModelContainer

    init() {
        let isDemo = ProcessInfo.processInfo.arguments.contains("-demo-mode")
        let schema = Schema([TokenModel.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isDemo)
        
        do {
            container = try ModelContainer(for: schema, configurations: [config])
            
            if isDemo {
                try DemoDataSeeder.preloadDemoData(modelContext: container.mainContext)
            }
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let tokenStore {
                    ContentView(
                        tokenStore: tokenStore,
                        hasCompletedOnboarding: $hasCompletedOnboarding,
                        showPrivacyOverlay: $showPrivacyOverlay
                    )
                } else {
                    Color.black.ignoresSafeArea()
                        .onAppear {
                            if tokenStore == nil {
                                tokenStore = TokenStore(modelContext: container.mainContext)
                            }
                        }
                }
            }
            .preferredColorScheme(.dark)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background, .inactive:
                showPrivacyOverlay = true
                tokenStore?.lockAll()
            case .active:
                showPrivacyOverlay = false
            @unknown default:
                break
            }
        }
    }
}
