import SwiftUI

@main
struct RockPaperScissorsApp: App {
    @StateObject private var multipeerService = MultipeerService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(multipeerService)
        }
    }
}
