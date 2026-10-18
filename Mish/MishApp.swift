import SwiftUI

@main
struct MishApp: App {
    @StateObject private var player = PlayerModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
                .preferredColorScheme(.dark)
        }
    }
}
